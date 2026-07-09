import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/notification_model.dart';
import '../models/ticket.dart';
import '../services/notification_service.dart';
import 'ticket_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Relative time ─────────────────────────────────────────────────────────
  String _relativeTime(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
    final d = ts.toDate();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  // ── Icon per notification type ────────────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case 'new_ticket':    return Icons.inbox_outlined;
      case 'status_change': return Icons.sync_outlined;
      case 'escalation':    return Icons.warning_amber_outlined;
      default:              return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'new_ticket':    return AppColors.navy;
      case 'status_change': return const Color(0xFFFF9800);
      case 'escalation':    return const Color(0xFFF44336);
      default:              return AppColors.slateBlue;
    }
  }

  // ── Navigate to ticket detail ─────────────────────────────────────────────
  Future<void> _openTicket(
      BuildContext context, NotificationModel n) async {
    // Mark as read first
    if (!n.read) await NotificationService.markAsRead(n.notificationId);

    // Fetch the ticket doc
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(n.ticketId)
          .get();
      if (!doc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ticket not found.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final ticket = Ticket.fromFirestore(doc);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TicketDetailScreen(ticket: ticket)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => NotificationService.markAllAsRead(uid),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService.getNotificationsStream(uid),
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
                  Icon(Icons.notifications_none_outlined,
                      size: 64,
                      color:
                          AppColors.slateBlue.withValues(alpha: 0.40)),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.35),
                        fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (_, i) => _notifCard(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _notifCard(BuildContext context, NotificationModel n) {
    final color = _colorFor(n.type);
    final isUnread = !n.read;

    return InkWell(
      onTap: () => _openTicket(context, n),
      child: Container(
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : Colors.transparent,
          border: isUnread
              ? Border(left: BorderSide(color: color, width: 4))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isUnread ? 0.12 : 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(n.type),
                size: 20,
                color: isUnread
                    ? color
                    : color.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 14),

            // Message + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    style: TextStyle(
                      color: isUnread
                          ? AppColors.darkNavy
                          : Colors.black45,
                      fontSize: 14,
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(n.createdAt),
                    style: TextStyle(
                      color: isUnread
                          ? AppColors.slateBlue
                          : Colors.black26,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Unread dot
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5, left: 8),
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
