import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String userId;
  final String type;     // new_ticket | status_change | escalation
  final String ticketId;
  final String message;
  final bool read;
  final Timestamp createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.ticketId,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      notificationId: doc.id,
      userId   : d['userId']    as String?    ?? '',
      type     : d['type']      as String?    ?? '',
      ticketId : d['ticketId']  as String?    ?? '',
      message  : d['message']   as String?    ?? '',
      read     : d['read']      as bool?      ?? false,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'notificationId': notificationId,
        'userId'   : userId,
        'type'     : type,
        'ticketId' : ticketId,
        'message'  : message,
        'read'     : read,
        'createdAt': createdAt,
      };
}
