import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/api_keys.dart';
import '../constants/app_colors.dart';
import '../models/ticket.dart';
import '../widgets/ticket_widgets.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  bool _actionLoading = false;

  // Ensures classification runs at most once per screen open,
  // regardless of StreamBuilder rebuilds.
  bool _classificationTriggered = false;
  bool _classifying = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference get _ref => FirebaseFirestore.instance
      .collection('tickets')
      .doc(widget.ticket.ticketId);

  // ── On first load, trigger classification if needed ──────────────────────────
  @override
  void initState() {
    super.initState();
    // Use the ticket passed in to decide — the stream will keep it fresh.
    if (widget.ticket.category == null) {
      _triggerClassification(widget.ticket.message);
    }
  }

  void _triggerClassification(String message) {
    if (_classificationTriggered) return;
    _classificationTriggered = true;
    // Run async without awaiting in initState
    _classify(message);
  }

  // ── Gemini classification ─────────────────────────────────────────────────────
  Future<void> _classify(String message) async {
    if (!mounted) return;
    setState(() => _classifying = true);

    const allowedCategories = ['billing', 'bug', 'question', 'complaint'];
    const allowedUrgencies = ['low', 'medium', 'high'];
    const allowedSentiments = ['angry', 'neutral', 'happy'];

    // Retry up to 3 times for transient errors (503, 429)
    const maxRetries = 3;
    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // ── Call Gemini REST API ───────────────────────────────────────────────
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-2.5-flash-lite:generateContent?key=${ApiKeys.gemini}',
        );

        final prompt =
            'You are a support ticket classifier. Classify the following '
            'customer support message. Respond ONLY with a valid JSON object, '
            'no markdown, no explanation, exactly in this format: '
            '{"category": "billing" or "bug" or "question" or "complaint", '
            '"urgency": "low" or "medium" or "high", '
            '"sentiment": "angry" or "neutral" or "happy"}. '
            'Message: $message';

        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'maxOutputTokens': 120,
                },
              }),
            )
            .timeout(const Duration(seconds: 20));

        // Retry on transient server errors
        if (response.statusCode == 503 || response.statusCode == 429) {
          lastError = Exception(
              'Gemini HTTP ${response.statusCode}: ${response.body}');
          if (attempt < maxRetries) {
            // Exponential backoff: 2s, 4s, 8s
            await Future.delayed(Duration(seconds: 2 * attempt));
            continue;
          } else {
            throw lastError;
          }
        }

        if (response.statusCode != 200) {
          throw Exception(
              'Gemini HTTP ${response.statusCode}: ${response.body}');
        }

        // ── Parse response ─────────────────────────────────────────────────────
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        String rawText =
            (decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
                    as String?) ??
                '';

        if (rawText.trim().isEmpty) {
          throw Exception('Empty response from Gemini');
        }

        // Strip markdown fences if present
        rawText = rawText.trim();
        final fenceMatch =
            RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(rawText);
        if (fenceMatch != null) rawText = fenceMatch.group(1)!.trim();

        final parsed = jsonDecode(rawText) as Map<String, dynamic>;

        final category = parsed['category'] as String?;
        final urgency = parsed['urgency'] as String?;
        final sentiment = parsed['sentiment'] as String?;

        if (!allowedCategories.contains(category) ||
            !allowedUrgencies.contains(urgency) ||
            !allowedSentiments.contains(sentiment)) {
          throw Exception('Invalid classification values: $parsed');
        }

        // ── Write to Firestore ───────────────────────────────────────────────
        await _ref.update({
          'category': category,
          'urgency': urgency,
          'sentiment': sentiment,
          'aiClassifiedAt': FieldValue.serverTimestamp(),
          'aiClassificationFailed': false,
        });

        // Success — exit the retry loop
        return;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('Classification attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    } // end retry loop

    // All retries exhausted — write fallback defaults
    debugPrint('Classification failed after $maxRetries attempts: $lastError');
    try {
      await _ref.update({
        'category': 'unclassified',
        'urgency': 'medium',
        'sentiment': 'neutral',
        'aiClassificationFailed': true,
        'aiClassifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Classification failed — defaults applied.'),
          backgroundColor: Colors.deepOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) setState(() => _classifying = false);
  }

  // ── Firestore update helpers ─────────────────────────────────────────────────
  Future<void> _update(Map<String, dynamic> data) async {
    setState(() => _actionLoading = true);
    try {
      await _ref.update(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _assignToMe() => _update({
        'assignedTo': _uid,
        'status': 'assigned',
      });

  Future<void> _transition(String newStatus) =>
      _update({'status': newStatus});

  // ── Fetch assigned agent name ────────────────────────────────────────────────
  Future<String> _fetchAgentName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return doc.data()?['name'] as String? ?? uid;
    } catch (_) {
      return uid;
    }
  }

  // ── Date format ───────────────────────────────────────────────────────────────
  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '#${widget.ticket.ticketId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navy));
          }
          if (snap.hasError || !snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Ticket not found.'));
          }

          final ticket = Ticket.fromFirestore(snap.data!);

          // If a fresh stream update shows category is now null again
          // (shouldn't happen, but safety net), don't re-trigger.
          return _body(ticket);
        },
      ),
    );
  }

  Widget _body(Ticket t) {
    final sc = statusColor(t.status);
    final uc = urgencyColor(t.urgency);

    // While classifying show a "Classifying…" badge
    final classifyingBadge = _classifying
        ? _spinnerBadge()
        : null;

    final urgencyLabel = t.urgency != null
        ? t.urgency![0].toUpperCase() + t.urgency!.substring(1)
        : 'Not classified';
    final categoryLabel = t.category != null
        ? t.category![0].toUpperCase() + t.category!.substring(1)
        : 'Not classified';
    final sentimentLabel = t.sentiment != null
        ? t.sentiment![0].toUpperCase() + t.sentiment!.substring(1)
        : 'Not classified';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badges ─────────────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TicketBadge(label: formatStatus(t.status), color: sc),
              if (_classifying) ...[
                classifyingBadge!,
              ] else ...[
                TicketBadge(
                    label: urgencyLabel,
                    color: uc,
                    faint: t.urgency == null),
                TicketBadge(
                    label: categoryLabel,
                    color: AppColors.steelTeal,
                    faint: t.category == null),
                TicketBadge(
                    label: sentimentLabel,
                    color: AppColors.slateBlue,
                    faint: t.sentiment == null),
              ],
              if (t.isEscalated)
                const TicketBadge(
                    label: '⚠ Escalated', color: Color(0xFFF44336)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Meta info card ──────────────────────────────────────────────────
          _infoCard([
            _metaRow('Created', _fmt(t.createdAt)),
            if (t.repliedAt != null) _metaRow('Replied', _fmt(t.repliedAt)),
            if (t.slaDeadline != null)
              _metaRow('SLA deadline', _fmt(t.slaDeadline)),
            _metaRow(
                'Ticket ID', t.ticketId.substring(0, 16).toUpperCase()),
            _assignedRow(t.assignedTo),
          ]),
          const SizedBox(height: 20),

          // ── Message ─────────────────────────────────────────────────────────
          const SectionLabel('MESSAGE'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lightBlue),
            ),
            child: Text(
              t.message,
              style: const TextStyle(
                  color: Colors.black87, fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: 24),

          // ── Assign to me ─────────────────────────────────────────────────────
          if (t.assignedTo == null || t.assignedTo != _uid) ...[
            const SectionLabel('ASSIGNMENT'),
            ActionButton(
              label: 'Assign to me',
              color: AppColors.navy,
              icon: Icons.person_add_outlined,
              isLoading: _actionLoading,
              onTap: _assignToMe,
            ),
            const SizedBox(height: 20),
          ],

          // ── Status machine actions ────────────────────────────────────────
          ..._stateButtons(t.status),
        ],
      ),
    );
  }

  // "Classifying…" animated badge
  Widget _spinnerBadge() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Classifying…',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  // ── State machine ─────────────────────────────────────────────────────────────
  List<Widget> _stateButtons(String status) {
    const transitions = {
      'assigned': [
        ('in_progress', 'Start working', Icons.play_arrow_rounded,
            Color(0xFFFFC107))
      ],
      'in_progress': [
        ('resolved', 'Mark resolved', Icons.check_circle_outline,
            Color(0xFF4CAF50))
      ],
      'resolved': [
        ('reopened', 'Reopen', Icons.replay_rounded, Color(0xFFF44336))
      ],
      'reopened': [
        ('in_progress', 'Start working', Icons.play_arrow_rounded,
            Color(0xFFFFC107))
      ],
    };

    final list = transitions[status];
    if (list == null || list.isEmpty) return [];

    return [
      const SectionLabel('ACTIONS'),
      ...list.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActionButton(
              label: t.$2,
              icon: t.$3,
              color: t.$4,
              isLoading: _actionLoading,
              onTap: () => _transition(t.$1),
            ),
          )),
      const SizedBox(height: 8),
    ];
  }

  // ── Info card ─────────────────────────────────────────────────────────────────
  Widget _infoCard(List<Widget> rows) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightBlue),
        ),
        child: Column(
          children: rows
              .expand((w) => [w, const Divider(height: 16)])
              .toList()
            ..removeLast(),
        ),
      );

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.darkNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _assignedRow(String? uid) {
    if (uid == null) return _metaRow('Assigned to', 'Unassigned');
    return FutureBuilder<String>(
      future: _fetchAgentName(uid),
      builder: (_, snap) =>
          _metaRow('Assigned to', snap.data ?? '…'),
    );
  }
}
