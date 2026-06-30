import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  // Current user
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Live Firestore reference for this ticket
  DocumentReference get _ref => FirebaseFirestore.instance
      .collection('tickets')
      .doc(widget.ticket.ticketId);

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

  Future<void> _transition(String newStatus) => _update({'status': newStatus});

  // ── Fetch assigned agent name from Firestore ─────────────────────────────────
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
    final months = [
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
      // Live listener so card updates without navigator pop
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
          return _body(ticket);
        },
      ),
    );
  }

  Widget _body(Ticket t) {
    final sc = statusColor(t.status);
    final uc = urgencyColor(t.urgency);
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
          // ── Badges ────────────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TicketBadge(label: formatStatus(t.status), color: sc),
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
              if (t.isEscalated)
                const TicketBadge(
                    label: '⚠ Escalated',
                    color: Color(0xFFF44336)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Meta info card ─────────────────────────────────────────────────
          _infoCard([
            _metaRow('Created', _fmt(t.createdAt)),
            if (t.repliedAt != null)
              _metaRow('Replied', _fmt(t.repliedAt)),
            if (t.slaDeadline != null)
              _metaRow('SLA deadline', _fmt(t.slaDeadline)),
            _metaRow('Ticket ID',
                t.ticketId.substring(0, 16).toUpperCase()),
            // Assigned to (async fetch)
            _assignedRow(t.assignedTo),
          ]),
          const SizedBox(height: 20),

          // ── Message ────────────────────────────────────────────────────────
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

          // ── Assign to me ───────────────────────────────────────────────────
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

          // ── Status machine actions ─────────────────────────────────────────
          ..._stateButtons(t.status),
        ],
      ),
    );
  }

  // ── State machine: only valid transitions ────────────────────────────────────
  List<Widget> _stateButtons(String status) {
    // Definitions: (newStatus, label, icon, color)
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

  // ── Info card container ───────────────────────────────────────────────────────
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

  // Async row for assigned user name
  Widget _assignedRow(String? uid) {
    if (uid == null) {
      return _metaRow('Assigned to', 'Unassigned');
    }
    return FutureBuilder<String>(
      future: _fetchAgentName(uid),
      builder: (_, snap) =>
          _metaRow('Assigned to', snap.data ?? '…'),
    );
  }
}
