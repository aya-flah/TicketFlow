import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final _col = FirebaseFirestore.instance.collection('notifications');

  // ── Create a single notification ──────────────────────────────────────────
  static Future<void> createNotification({
    required String userId,
    required String type,
    required String ticketId,
    required String message,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'notificationId': ref.id,
      'userId'   : userId,
      'type'     : type,
      'ticketId' : ticketId,
      'message'  : message,
      'read'     : false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Mark a single notification as read ───────────────────────────────────
  static Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({'read': true});
  }

  // ── Batch-mark all unread notifications for a user as read ───────────────
  static Future<void> markAllAsRead(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Live stream of all notifications for a user ───────────────────────────
  static Stream<List<NotificationModel>> getNotificationsStream(
      String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(NotificationModel.fromFirestore).toList());
  }

  // ── Stream of unread count (for badge) ───────────────────────────────────
  static Stream<int> getUnreadCountStream(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Notify all agents AND managers about a new ticket ────────────────────
  static Future<void> notifyAgentsNewTicket({
    required String ticketId,
    required String message,
    String? submittedBy, // customer uid if submitted via customer portal
  }) async {
    try {
      final agentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .get();
      final managersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();

      final allUsers = [...agentsSnap.docs, ...managersSnap.docs];
      if (allUsers.isEmpty) {
        debugPrint('NotificationService: no users found to notify');
        return;
      }

      final preview = message.length > 50
          ? '${message.substring(0, 50)}…'
          : message;

      // Clearer wording when submitted by a customer
      final notifMessage = submittedBy != null
          ? 'New ticket from customer: $preview'
          : 'New ticket received: $preview';

      final batch = FirebaseFirestore.instance.batch();
      for (final user in allUsers) {
        final ref = _col.doc();
        batch.set(ref, {
          'notificationId': ref.id,
          'userId'   : user.id,
          'type'     : 'new_ticket',
          'ticketId' : ticketId,
          'message'  : notifMessage,
          'read'     : false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint(
          'NotificationService: notified ${allUsers.length} users for ticket $ticketId');
    } catch (e) {
      // Re-throw so callers can surface the error in the UI
      debugPrint('NotificationService.notifyAgentsNewTicket error: $e');
      rethrow;
    }
  }

  // ── Notify assigned agent of status change ───────────────────────────────
  static Future<void> notifyStatusChange({
    required String ticketId,
    required String assignedTo,
    required String newStatus,
  }) async {
    if (assignedTo.isEmpty) return;
    final shortId = ticketId.substring(0, 8).toUpperCase();
    final statusLabel = newStatus.replaceAll('_', ' ');
    await createNotification(
      userId  : assignedTo,
      type    : 'status_change',
      ticketId: ticketId,
      message : 'Ticket #$shortId status changed to $statusLabel',
    );
  }

  // TODO (Week 6): notifyEscalation — wire in when escalation engine is built
}
