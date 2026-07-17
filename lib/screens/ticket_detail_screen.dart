import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/ticket.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../widgets/ticket_widgets.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  // ── Flags ────────────────────────────────────────────────────────────────────
  bool _actionLoading        = false;
  bool _classificationTriggered = false;
  bool _classifying          = false;
  bool _draftTriggered       = false;
  bool _generatingDraft      = false;
  bool _sendingReply         = false;

  // ── Draft reply editor ───────────────────────────────────────────────────────
  final _replyController = TextEditingController();

  /// The original AI-generated text — used to detect edits.
  String? _originalDraft;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference get _ref => FirebaseFirestore.instance
      .collection('tickets')
      .doc(widget.ticket.ticketId);

  // ── initState ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final t = widget.ticket;

    // Trigger classification if needed
    if (t.category == null) {
      _classificationTriggered = true;
      _classify(t.message);
      return; // draft will be triggered after classification via StreamBuilder
    }

    // Ticket already classified — check if draft is needed
    if (t.aiDraftReply == null && t.finalReply == null) {
      _draftTriggered = true;
      _generateDraft(t);
    } else if (t.aiDraftReply != null && t.finalReply == null) {
      // Draft already exists — load it into the editor
      _originalDraft = t.aiDraftReply;
      _replyController.text = t.aiDraftReply!;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  // ── Gemini: Classification ───────────────────────────────────────────────────
  Future<void> _classify(String message) async {
    if (!mounted) return;
    setState(() => _classifying = true);

    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final result = await GeminiService.classify(
          ticketId: widget.ticket.ticketId,
          message: message,
        );

        await _ref.update({
          'category'              : result['category'],
          'urgency'               : result['urgency'],
          'sentiment'             : result['sentiment'],
          'aiClassifiedAt'        : FieldValue.serverTimestamp(),
          'aiClassificationFailed': false,
        });

        if (mounted) setState(() => _classifying = false);
        return;

      } catch (e) {
        debugPrint('Classify attempt $attempt/$maxRetries failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 5 * attempt));
        }
      }
    }

    // All retries failed — write fallback
    try {
      await _ref.update({
        'category'              : 'unclassified',
        'urgency'               : 'medium',
        'sentiment'             : 'neutral',
        'aiClassificationFailed': true,
        'aiClassifiedAt'        : FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _classifying = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Classification failed — defaults applied.'),
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Gemini: Draft reply generation ───────────────────────────────────────────
  Future<void> _generateDraft(Ticket t) async {
    if (!mounted) return;
    setState(() => _generatingDraft = true);

    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final draftText = await GeminiService.generateDraft(
          ticketId : t.ticketId,
          message  : t.message,
          category : t.category ?? 'general',
          urgency  : t.urgency  ?? 'medium',
          sentiment: t.sentiment ?? 'neutral',
        );

        await _ref.update({
          'aiDraftReply'      : draftText,
          'aiDraftGeneratedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _originalDraft = draftText;
          _replyController.text = draftText;
          setState(() => _generatingDraft = false);
        }
        return;

      } catch (e) {
        debugPrint('Draft generation attempt $attempt/$maxRetries failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 5 * attempt));
        }
      }
    }

    if (mounted) {
      setState(() => _generatingDraft = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Draft generation failed. You can write your own reply.'),
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Send final reply ─────────────────────────────────────────────────────────
  Future<void> _sendReply(String originalDraft) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reply cannot be empty.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _sendingReply = true);
    try {
      final wasEdited = text != originalDraft;
      await _ref.update({
        'finalReply'    : text,
        'repliedAt'     : FieldValue.serverTimestamp(),
        'repliedBy'     : _uid,
        'draftWasEdited': wasEdited,
        'status'        : 'resolved',
      });

      // Notify assigned agent that reply was sent and ticket is resolved
      final assignedTo = widget.ticket.assignedTo ?? '';
      if (assignedTo.isNotEmpty && assignedTo != _uid) {
        await NotificationService.notifyStatusChange(
          ticketId  : widget.ticket.ticketId,
          assignedTo: assignedTo,
          newStatus : 'resolved',
        );
      }

      // Notify customer that their ticket has been replied to
      final submittedBy = widget.ticket.submittedBy ?? '';
      if (submittedBy.isNotEmpty) {
        final shortId =
            widget.ticket.ticketId.substring(0, 8).toUpperCase();
        await NotificationService.createNotification(
          userId  : submittedBy,
          type    : 'status_change',
          ticketId: widget.ticket.ticketId,
          message : 'Support team replied to your ticket #$shortId',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reply sent'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  // ── Generic Firestore update ─────────────────────────────────────────────────
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

  Future<void> _assignToMe() => _update({'assignedTo': _uid, 'status': 'assigned'});

  /// Status transition + notify the assigned agent
  Future<void> _transition(String newStatus) async {
    await _update({'status': newStatus});
    // Notify assigned agent (could be self — service handles empty uid gracefully)
    final assignedTo = widget.ticket.assignedTo ?? '';
    if (assignedTo.isNotEmpty) {
      await NotificationService.notifyStatusChange(
        ticketId  : widget.ticket.ticketId,
        assignedTo: assignedTo,
        newStatus : newStatus,
      );
    }
  }

  Future<String> _fetchAgentName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['name'] as String? ?? uid;
    } catch (_) { return uid; }
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
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
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.navy));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Ticket not found.'));
          }

          final ticket = Ticket.fromFirestore(snap.data!);

          // Safety net: trigger classification if not yet done
          if (ticket.category == null && !_classificationTriggered) {
            _classificationTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _classify(ticket.message));
          }

          // Once classification lands (any value, including 'unclassified'),
          // trigger draft generation if not yet done
          if (ticket.category != null &&
              ticket.aiDraftReply == null &&
              ticket.finalReply == null &&
              !_draftTriggered &&
              !_classifying) {
            _draftTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _generateDraft(ticket));
          }

          // Sync draft into editor when Firestore delivers it
          if (ticket.aiDraftReply != null &&
              _originalDraft == null &&
              ticket.finalReply == null) {
            _originalDraft = ticket.aiDraftReply;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _replyController.text = ticket.aiDraftReply!;
            });
          }

          return _body(ticket);
        },
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────────
  Widget _body(Ticket t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badgesSection(t),
          const SizedBox(height: 20),
          _metaCard(t),
          const SizedBox(height: 20),
          _messageSection(t),
          const SizedBox(height: 24),
          if (t.assignedTo == null || t.assignedTo != _uid) ...[
            _assignSection(),
            const SizedBox(height: 20),
          ],
          ..._stateButtons(t.status),
          _replySection(t),
        ],
      ),
    );
  }

  // ── Badges section ───────────────────────────────────────────────────────────
  Widget _badgesSection(Ticket t) {
    final sc = statusColor(t.status);
    final uc = urgencyColor(t.urgency);
    String cap(String? v) => v != null ? v[0].toUpperCase() + v.substring(1) : 'Not classified';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TicketBadge(label: formatStatus(t.status), color: sc),
        if (_classifying)
          _spinnerBadge('Classifying…')
        else ...[
          TicketBadge(label: cap(t.urgency),   color: uc,                  faint: t.urgency   == null),
          TicketBadge(label: cap(t.category),  color: AppColors.steelTeal, faint: t.category  == null),
          TicketBadge(label: cap(t.sentiment), color: AppColors.slateBlue, faint: t.sentiment == null),
        ],
        if (t.isEscalated)
          const TicketBadge(label: '⚠ Escalated', color: Color(0xFFF44336)),
      ],
    );
  }

  Widget _spinnerBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ── Meta card ────────────────────────────────────────────────────────────────
  Widget _metaCard(Ticket t) => _infoCard([
        _metaRow('Created',    _fmt(t.createdAt)),
        if (t.repliedAt   != null) _metaRow('Replied',      _fmt(t.repliedAt)),
        if (t.slaDeadline != null) _metaRow('SLA deadline', _fmt(t.slaDeadline)),
        _metaRow('Ticket ID', t.ticketId.substring(0, 16).toUpperCase()),
        _assignedRow(t.assignedTo),
      ]);

  // ── Message ──────────────────────────────────────────────────────────────────
  Widget _messageSection(Ticket t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('MESSAGE'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lightBlue),
            ),
            child: Text(t.message,
                style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.6)),
          ),
        ],
      );

  // ── Assignment ───────────────────────────────────────────────────────────────
  Widget _assignSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('ASSIGNMENT'),
          ActionButton(
            label: 'Assign to me',
            color: AppColors.navy,
            icon: Icons.person_add_outlined,
            isLoading: _actionLoading,
            onTap: _assignToMe,
          ),
        ],
      );

  // ── Reply section ─────────────────────────────────────────────────────────────
  Widget _replySection(Ticket t) {
    // ── Already sent ─────────────────────────────────────────────────────────
    if (t.finalReply != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const SectionLabel('REPLY SENT'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.finalReply!,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.6)),
                const SizedBox(height: 10),
                Text(
                  'Sent ${_fmt(t.repliedAt)}'
                  '${t.draftWasEdited == true ? '  •  Edited from AI draft' : '  •  Sent as AI draft'}',
                  style: const TextStyle(color: Colors.black38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── Generating draft ──────────────────────────────────────────────────────
    if (_generatingDraft) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('AI DRAFT REPLY'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lightBlue),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.slateBlue),
                  ),
                  const SizedBox(width: 12),
                  Text('Generating draft reply…',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Draft ready or write own ──────────────────────────────────────────────
    // Only show the reply editor if classification has completed
    if (t.category == null) return const SizedBox.shrink();

    final hasDraft = _originalDraft != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('AI DRAFT REPLY'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lightBlue),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Editable reply text
                TextField(
                  controller: _replyController,
                  maxLines: null,
                  minLines: 4,
                  maxLength: 1000,
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 14, height: 1.6),
                  decoration: InputDecoration(
                    hintText: hasDraft
                        ? 'Edit the AI draft or write your own…'
                        : 'Write your reply here…',
                    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                    border: InputBorder.none,
                    counterStyle:
                        const TextStyle(color: Colors.black38, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons row
          Row(
            children: [
              // "Write my own" clears editor without touching Firestore
              if (hasDraft)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _replyController.clear();
                    }),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Write my own'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.slateBlue,
                      side: const BorderSide(color: AppColors.slateBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (hasDraft) const SizedBox(width: 10),

              // "Approve & Send"
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _sendingReply
                      ? null
                      : () => _sendReply(_originalDraft ?? ''),
                  icon: _sendingReply
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(_sendingReply ? 'Sending…' : 'Approve & Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── State machine buttons ────────────────────────────────────────────────────
  List<Widget> _stateButtons(String status) {
    const transitions = {
      'assigned'   : [('in_progress', 'Start working', Icons.play_arrow_rounded,   Color(0xFFFFC107))],
      'in_progress': [('resolved',    'Mark resolved', Icons.check_circle_outline, Color(0xFF4CAF50))],
      'resolved'   : [('reopened',    'Reopen',        Icons.replay_rounded,       Color(0xFFF44336))],
      'reopened'   : [('in_progress', 'Start working', Icons.play_arrow_rounded,   Color(0xFFFFC107))],
    };
    final list = transitions[status];
    if (list == null || list.isEmpty) return [];
    return [
      const SectionLabel('ACTIONS'),
      ...list.map((tr) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActionButton(
              label: tr.$2, icon: tr.$3, color: tr.$4,
              isLoading: _actionLoading,
              onTap: () => _transition(tr.$1),
            ),
          )),
      const SizedBox(height: 8),
    ];
  }

  // ── Shared widgets ───────────────────────────────────────────────────────────
  Widget _infoCard(List<Widget> rows) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightBlue),
        ),
        child: Column(
          children: rows
              .expand((w) => [w, const Divider(height: 16)])
              .toList()..removeLast(),
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
                      color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.darkNavy, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _assignedRow(String? uid) {
    if (uid == null) return _metaRow('Assigned to', 'Unassigned');
    return FutureBuilder<String>(
      future: _fetchAgentName(uid),
      builder: (_, snap) => _metaRow('Assigned to', snap.data ?? '…'),
    );
  }
}





