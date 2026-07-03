import {setGlobalOptions} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {GoogleGenAI} from "@google/genai";

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Secret — set via: firebase functions:secrets:set GEMINI_API_KEY
const geminiApiKey = defineSecret("GEMINI_API_KEY");

setGlobalOptions({maxInstances: 10});

// ── Types ────────────────────────────────────────────────────────────────────
interface GeminiClassification {
  category: "billing" | "bug" | "question" | "complaint";
  urgency: "low" | "medium" | "high";
  sentiment: "angry" | "neutral" | "happy";
}

// ── Validation ───────────────────────────────────────────────────────────────
function validateClassification(obj: unknown): GeminiClassification {
  const validCategories = ["billing", "bug", "question", "complaint"];
  const validUrgencies = ["low", "medium", "high"];
  const validSentiments = ["angry", "neutral", "happy"];

  if (
    !obj ||
    typeof obj !== "object" ||
    !validCategories.includes((obj as Record<string, string>).category) ||
    !validUrgencies.includes((obj as Record<string, string>).urgency) ||
    !validSentiments.includes((obj as Record<string, string>).sentiment)
  ) {
    throw new Error(`Invalid classification values: ${JSON.stringify(obj)}`);
  }

  return obj as GeminiClassification;
}

// ── Gemini classifier ────────────────────────────────────────────────────────
async function classifyWithGemini(
  message: string,
  apiKey: string
): Promise<GeminiClassification> {
  const ai = new GoogleGenAI({apiKey});

  const prompt = `You are a support ticket classifier. Analyze the customer message below and respond ONLY with valid JSON — no markdown, no code fences, no explanation.

Required format:
{"category":"billing"|"bug"|"question"|"complaint","urgency":"low"|"medium"|"high","sentiment":"angry"|"neutral"|"happy"}

Rules:
- category: billing=invoice/charge issues, bug=software errors, question=how-to, complaint=general dissatisfaction
- urgency: high=blocking/urgent, medium=important, low=minor
- sentiment: angry=frustrated/demanding, neutral=calm/factual, happy=satisfied/positive

Customer message:
"""
${message}
"""

JSON response:`;

  const response = await ai.models.generateContent({
    model: "gemini-2.0-flash-lite",
    contents: prompt,
    config: {
      temperature: 0.1,
      maxOutputTokens: 120,
    },
  });

  const rawText = response.text ?? "";

  if (!rawText.trim()) {
    throw new Error("Empty response from Gemini");
  }

  // Strip accidental markdown fences
  let jsonText = rawText.trim();
  const fenceMatch = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenceMatch) {
    jsonText = fenceMatch[1].trim();
  }

  const parsed = JSON.parse(jsonText);
  return validateClassification(parsed);
}

// ── Cloud Function ────────────────────────────────────────────────────────────
export const classifyTicket = onDocumentCreated(
  {
    document: "tickets/{ticketId}",
    secrets: [geminiApiKey],
    region: "us-central1",
    maxInstances: 5,
  },
  async (event) => {
    const ticketId = event.params.ticketId;
    const data = event.data?.data() as Record<string, unknown> | undefined;

    if (!data) {
      logger.warn(`Ticket ${ticketId}: no data, skipping.`);
      return;
    }

    // Skip if already classified
    if (data.category) {
      logger.info(
        `Ticket ${ticketId}: already classified as "${data.category}", skipping.`
      );
      return;
    }

    const message = data.message;
    if (!message || typeof message !== "string") {
      logger.error(`Ticket ${ticketId}: missing message field, skipping.`);
      return;
    }

    logger.info(
      `Ticket ${ticketId}: classifying — "${message.substring(0, 80)}..."`
    );

    try {
      const classification = await classifyWithGemini(
        message,
        geminiApiKey.value()
      );

      await db.collection("tickets").doc(ticketId).update({
        category: classification.category,
        urgency: classification.urgency,
        sentiment: classification.sentiment,
        aiClassifiedAt: FieldValue.serverTimestamp(),
      });

      logger.info(
        `Ticket ${ticketId}: ✓ classified — ${JSON.stringify(classification)}`
      );
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      logger.error(`Ticket ${ticketId}: ✗ classification failed — ${msg}`);

      // Fallback: mark as unclassified so nothing stays null
      await db.collection("tickets").doc(ticketId).update({
        category: "unclassified",
        urgency: "medium",
        sentiment: "neutral",
        aiClassificationFailed: true,
        aiClassifiedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);
