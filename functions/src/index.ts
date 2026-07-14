import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {GoogleGenAI} from "@google/genai";

initializeApp();
const db = getFirestore();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

setGlobalOptions({maxInstances: 10});

// ── Shared: call Gemini ───────────────────────────────────────────────────────
async function callGemini(
  apiKey: string,
  prompt: string,
  temperature: number,
  maxTokens: number
): Promise<string> {
  const ai = new GoogleGenAI({apiKey});
  const response = await ai.models.generateContent({
    model: "gemini-2.0-flash-lite",
    contents: prompt,
    config: {temperature, maxOutputTokens: maxTokens},
  });
  const raw = response.text ?? "";
  if (!raw.trim()) throw new Error("Empty response from Gemini");
  return raw.trim();
}

// ── Callable: classifyTicket ──────────────────────────────────────────────────
export const classifyTicket = onCall(
  {secrets: [geminiApiKey], region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const {ticketId, message} = request.data as {
      ticketId: string;
      message: string;
    };

    if (!ticketId || !message) {
      throw new HttpsError("invalid-argument", "ticketId and message required.");
    }

    // Skip if already classified
    const doc = await db.collection("tickets").doc(ticketId).get();
    const existing = doc.data()?.category;
    if (existing) {
      logger.info(`Ticket ${ticketId}: already classified (${existing})`);
      return {category: existing, urgency: doc.data()?.urgency, sentiment: doc.data()?.sentiment};
    }

    const prompt =
      `You are a support ticket classifier. Classify the following customer support message. ` +
      `Respond ONLY with a valid JSON object, no markdown, no explanation, exactly in this format: ` +
      `{"category": "billing" or "bug" or "question" or "complaint", ` +
      `"urgency": "low" or "medium" or "high", ` +
      `"sentiment": "angry" or "neutral" or "happy"}. ` +
      `Message: ${message}`;

    try {
      let raw = await callGemini(geminiApiKey.value(), prompt, 0.1, 120);

      // Strip markdown fences
      const fence = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (fence) raw = fence[1].trim();

      const parsed = JSON.parse(raw);
      const validCats = ["billing", "bug", "question", "complaint"];
      const validUrg  = ["low", "medium", "high"];
      const validSent = ["angry", "neutral", "happy"];

      if (
        !validCats.includes(parsed.category) ||
        !validUrg.includes(parsed.urgency)   ||
        !validSent.includes(parsed.sentiment)
      ) {
        throw new Error(`Invalid values: ${JSON.stringify(parsed)}`);
      }

      await db.collection("tickets").doc(ticketId).update({
        category: parsed.category,
        urgency:  parsed.urgency,
        sentiment: parsed.sentiment,
        aiClassifiedAt: FieldValue.serverTimestamp(),
        aiClassificationFailed: false,
      });

      logger.info(`Ticket ${ticketId}: classified ${JSON.stringify(parsed)}`);
      return parsed;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      logger.error(`Ticket ${ticketId}: classification failed — ${msg}`);

      await db.collection("tickets").doc(ticketId).update({
        category: "unclassified",
        urgency: "medium",
        sentiment: "neutral",
        aiClassificationFailed: true,
        aiClassifiedAt: FieldValue.serverTimestamp(),
      });

      return {category: "unclassified", urgency: "medium", sentiment: "neutral"};
    }
  }
);

// ── Callable: generateDraft ───────────────────────────────────────────────────
export const generateDraft = onCall(
  {secrets: [geminiApiKey], region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const {ticketId, message, category, urgency, sentiment} = request.data as {
      ticketId: string;
      message: string;
      category: string;
      urgency: string;
      sentiment: string;
    };

    if (!ticketId || !message) {
      throw new HttpsError("invalid-argument", "ticketId and message required.");
    }

    // Skip if draft already exists
    const doc = await db.collection("tickets").doc(ticketId).get();
    if (doc.data()?.aiDraftReply) {
      return {draft: doc.data()?.aiDraftReply};
    }

    const prompt =
      `You are a professional customer support agent. Write a helpful, empathetic reply ` +
      `to the following customer support message. The message has been classified as ` +
      `category: ${category}, urgency: ${urgency}, sentiment: ${sentiment}. ` +
      `Keep the reply concise (2-4 sentences), professional, and directly address the ` +
      `customer's concern. Do not use placeholders like [Name] or [Agent]. ` +
      `Sign off as 'The Support Team'. ` +
      `Respond with ONLY the reply text, no explanation, no subject line, no formatting.`;

    try {
      const draft = await callGemini(geminiApiKey.value(), prompt, 0.7, 300);

      await db.collection("tickets").doc(ticketId).update({
        aiDraftReply: draft,
        aiDraftGeneratedAt: FieldValue.serverTimestamp(),
      });

      logger.info(`Ticket ${ticketId}: draft generated (${draft.length} chars)`);
      return {draft};
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      logger.error(`Ticket ${ticketId}: draft generation failed — ${msg}`);
      throw new HttpsError("internal", `Draft generation failed: ${msg}`);
    }
  }
);
