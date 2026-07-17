import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ticket.dart';
import '../../widgets/ticket_widgets.dart';

class CustomerTicketDetailScreen extends StatelessWidget {
  final Ticket ticket;
  const CustomerTicketDetailScreen({super.key, required this.ticket});

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Live stream so reply appears without user action
    final ref = FirebaseFirestore.instance
        .collection('tickets')
        .doc(ticket.ticketId);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '#${ticket.ticketId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navy));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Ticket not found.'));
          }
          final t = Ticket.fromFirestore(snap.data!);
          return _body(t);
        },
      ),
    );
  }

  Widget _body(Ticket t) {
    final sc = statusColor(t.status);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status + classification badges ──────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TicketBadge(label: formatStatus(t.status), color: sc),
              if (t.urgency != null)
                TicketBadge(
                    label: t.urgency![0].toUpperCase() +
                        t.urgency!.substring(1),
                    color: urgencyColor(t.urgency)),
              if (t.category != null)
                TicketBadge(
                    label: t.category![0].toUpperCase() +
                        t.category!.substring(1),
                    color: AppColors.steelTeal),
              if (t.urgency == null && t.category == null)
                const TicketBadge(
                    label: 'Pending review',
                    color: Colors.grey,
                    faint: true),
            ],
          ),
          const SizedBox(height: 20),

          // ── Submitted date ──────────────────────────────────────────────
          _infoCard([
            _row('Submitted', _fmt(t.createdAt)),
            if (t.repliedAt != null) _row('Replied', _fmt(t.repliedAt)),
          ]),
          const SizedBox(height: 20),

          // ── Your message ────────────────────────────────────────────────
          const SectionLabel('YOUR MESSAGE'),
          _textCard(t.message),
          const SizedBox(height: 24),

          // ── Reply section ───────────────────────────────────────────────
          const SectionLabel('SUPPORT REPLY'),
          if (t.finalReply != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent,
                          color: Color(0xFF4CAF50), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Support Team replied:',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.finalReply!,
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fmt(t.repliedAt),
                    style: const TextStyle(
                        color: Colors.black38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ] else ...[
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
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.slateBlue.withValues(alpha: 0.60),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Awaiting reply from support team…',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
              .expand((w) => [w, const Divider(height: 14)])
              .toList()
            ..removeLast(),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 90,
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

  Widget _textCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightBlue),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.black87, fontSize: 15, height: 1.6)),
      );
}
