import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  final String ticketId;
  final String message;
  final String status; // open | assigned | in_progress | resolved | reopened
  final String? assignedTo; // uid of agent
  final String? category; // billing | bug | question | complaint  (AI)
  final String? urgency; // low | medium | high  (AI)
  final String? sentiment; // angry | neutral | happy  (AI)
  final String? aiDraftReply;
  final String? finalReply;
  final bool isEscalated;
  final Timestamp createdAt;
  final Timestamp? repliedAt;
  final Timestamp? slaDeadline;

  const Ticket({
    required this.ticketId,
    required this.message,
    required this.status,
    this.assignedTo,
    this.category,
    this.urgency,
    this.sentiment,
    this.aiDraftReply,
    this.finalReply,
    this.isEscalated = false,
    required this.createdAt,
    this.repliedAt,
    this.slaDeadline,
  });

  // ── Firestore → Ticket ───────────────────────────────────────────────────────
  factory Ticket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Ticket(
      ticketId: doc.id,
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      assignedTo: data['assignedTo'] as String?,
      category: data['category'] as String?,
      urgency: data['urgency'] as String?,
      sentiment: data['sentiment'] as String?,
      aiDraftReply: data['aiDraftReply'] as String?,
      finalReply: data['finalReply'] as String?,
      isEscalated: data['isEscalated'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      repliedAt: data['repliedAt'] as Timestamp?,
      slaDeadline: data['slaDeadline'] as Timestamp?,
    );
  }

  // ── Ticket → Firestore ───────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'ticketId': ticketId,
        'message': message,
        'status': status,
        'assignedTo': assignedTo,
        'category': category,
        'urgency': urgency,
        'sentiment': sentiment,
        'aiDraftReply': aiDraftReply,
        'finalReply': finalReply,
        'isEscalated': isEscalated,
        'createdAt': createdAt,
        'repliedAt': repliedAt,
        'slaDeadline': slaDeadline,
      };

  // Convenience copy-with for local state updates
  Ticket copyWith({
    String? status,
    String? assignedTo,
    String? category,
    String? urgency,
    String? sentiment,
    String? aiDraftReply,
    String? finalReply,
    bool? isEscalated,
    Timestamp? repliedAt,
    Timestamp? slaDeadline,
  }) =>
      Ticket(
        ticketId: ticketId,
        message: message,
        status: status ?? this.status,
        assignedTo: assignedTo ?? this.assignedTo,
        category: category ?? this.category,
        urgency: urgency ?? this.urgency,
        sentiment: sentiment ?? this.sentiment,
        aiDraftReply: aiDraftReply ?? this.aiDraftReply,
        finalReply: finalReply ?? this.finalReply,
        isEscalated: isEscalated ?? this.isEscalated,
        createdAt: createdAt,
        repliedAt: repliedAt ?? this.repliedAt,
        slaDeadline: slaDeadline ?? this.slaDeadline,
      );
}
