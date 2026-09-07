import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class EscalationService {
  static final _db = FirebaseFirestore.instance;

  // ── a) Set SLA deadline after classification ─────────────────────────────
  static Future<void> setSlaDeadline(
      String ticketId, String urgency) async {
    try {
      final settingsDoc =
          await _db.collection('settings').doc('business').get();
      final thresholds = settingsDoc.data()?['slaThresholds']
          as Map<String, dynamic>?;

      if (thresholds == null) {
        debugPrint('EscalationService: no slaThresholds in settings/business');
        return;
      }

      // Support decimal hours (e.g. 0.033 ≈ 2 minutes for demo)
      final hoursRaw = thresholds[urgency];
      if (hoursRaw == null) {
        debugPrint('EscalationService: no threshold for urgency "$urgency"');
        return;
      }
      final hours = (hoursRaw as num).toDouble();
      final deadline =
          DateTime.now().add(Duration(microseconds: (hours * 3600e6).round()));

      await _db.collection('tickets').doc(ticketId).update({
        'slaDeadline': Timestamp.fromDate(deadline),
      });

      debugPrint(
          'EscalationService: SLA deadline set for $ticketId → $deadline');
    } catch (e) {
      debugPrint('EscalationService.setSlaDeadline error: $e');
    }
  }

  // ── b) Check & escalate overdue tickets (fire-and-forget) ────────────────
  static Future<void> checkAndEscalateOverdueTickets() async {
    try {
      final now = Timestamp.now();

      // Step 1: get all non-escalated tickets (no composite index needed)
      // Then filter slaDeadline client-side to avoid index requirement
      final snap = await _db
          .collection('tickets')
          .where('isEscalated', isEqualTo: false)
          .get();

      // Filter client-side: slaDeadline is set, is in the past, and not resolved
      final overdue = snap.docs.where((d) {
        final data       = d.data();
        final status     = data['status']      as String?    ?? '';
        final slaDeadline = data['slaDeadline'] as Timestamp?;
        if (status == 'resolved' || slaDeadline == null) return false;
        return slaDeadline.compareTo(now) <= 0;
      }).toList();

      debugPrint(
          'EscalationService: found ${snap.docs.length} non-escalated tickets, '
          '${overdue.length} overdue');

      if (overdue.isEmpty) return;

      // Fetch all managers once
      final managersSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();

      final batch         = _db.batch();
      final notifications = <Map<String, dynamic>>[];

      for (final doc in overdue) {
        final ticketId = doc.id;
        final shortId  = ticketId.substring(0, 8).toUpperCase();

        batch.update(doc.reference, {
          'isEscalated': true,
          'escalatedAt': FieldValue.serverTimestamp(),
        });

        for (final manager in managersSnap.docs) {
          notifications.add({
            'userId'  : manager.id,
            'type'    : 'escalation',
            'ticketId': ticketId,
            'message' :
                '⚠️ Ticket #$shortId has exceeded its SLA — no response in time',
          });
        }
      }

      await batch.commit();

      for (final n in notifications) {
        await NotificationService.createNotification(
          userId  : n['userId']   as String,
          type    : n['type']     as String,
          ticketId: n['ticketId'] as String,
          message : n['message']  as String,
        );
      }

      debugPrint(
          'EscalationService: ✓ escalated ${overdue.length} ticket(s)');
    } catch (e) {
      debugPrint('EscalationService.checkAndEscalateOverdueTickets error: $e');
      rethrow; // re-throw so callers can show the error
    }
  }

  // ── c) Stream of all escalated tickets ───────────────────────────────────
  static Stream<List<Map<String, dynamic>>> getEscalatedTicketsStream() {
    return _db
        .collection('tickets')
        .where('isEscalated', isEqualTo: true)
        .orderBy('escalatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  // ── Live count of active escalations (for badge) ─────────────────────────
  static Stream<int> getActiveEscalationCountStream() {
    return _db
        .collection('tickets')
        .where('isEscalated', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .where((d) => d.data()['status'] != 'resolved')
            .length);
  }
}
