import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/ticket.dart';
import '../services/agent_cache.dart';
import '../services/escalation_service.dart';
import '../widgets/ticket_widgets.dart';
import 'ticket_detail_screen.dart';

class EscalationsScreen extends StatelessWidget {
  const EscalationsScreen({super.key});

  String _relativeTime(Timestamp? ts) {
    if (ts == null) return 'Unknown';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Escalations',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: EscalationService.getEscalatedTicketsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navy));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.redAccent)));
          }

          final list = snap.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64,
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.50)),
                  const SizedBox(height: 16),
                  const Text(
                    'No escalated tickets.',
                    style: TextStyle(color: Colors.black45, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final data     = list[i];
              final ticketId = data['id'] as String? ?? '';
              final message  = data['message']  as String? ?? '';
              final status   = data['status']   as String? ?? 'open';
              final urgency  = data['urgency']  as String?;
              final escalatedAt = data['escalatedAt'] as Timestamp?;
              final sc = statusColor(status);
              final uc = urgencyColor(urgency);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shadowColor: const Color(0xFFF44336).withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: const Color(0xFFF44336).withValues(alpha: 0.30),
                      width: 1),
                ),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    // Fetch full ticket then navigate
                    final doc = await FirebaseFirestore.instance
                        .collection('tickets')
                        .doc(ticketId)
                        .get();
                    if (!doc.exists || !context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketDetailScreen(
                            ticket: Ticket.fromFirestore(doc),
                            isManager: true),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Red warning icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF44336)
                                .withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFF44336), size: 22),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Submitter name + escalated time
                              Row(
                                children: [
                                  FutureBuilder<String>(
                                    future: AgentCache.instance.getName(
                                        (data['submittedBy'] as String?) ?? ''),
                                    builder: (_, snap) => Text(
                                      snap.data ?? '…',
                                      style: const TextStyle(
                                        color: AppColors.slateBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Escalated ${_relativeTime(escalatedAt)}',
                                    style: const TextStyle(
                                        color: Color(0xFFF44336),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Message preview
                              Text(
                                message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.darkNavy,
                                    fontSize: 14,
                                    height: 1.4),
                              ),
                              const SizedBox(height: 10),

                              // Badges
                              Wrap(
                                spacing: 8,
                                children: [
                                  TicketBadge(
                                      label: formatStatus(status), color: sc),
                                  if (urgency != null)
                                    TicketBadge(
                                      label: urgency[0].toUpperCase() +
                                          urgency.substring(1),
                                      color: uc,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
