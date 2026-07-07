import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  final String ticketId;
  final String message;
  final String status; // open | assigned | in_progress | resolved | reopened
  final String? assignedTo;
  final String? category;   // billing | bug | question | complaint  (AI)
  final String? urgency;    // low | medium | high  (AI)
  final String? sentiment;  // angry | neutral | happy  (AI)
  final String? aiDraftReply;
  final Timestamp? aiDraftGeneratedAt;
  final String? finalReply;
  final String? repliedBy;        // uid of agent who sent the reply
  final bool? draftWasEdited;     // true if agent modified the AI draft
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
    this.aiDraftGeneratedAt,
    this.finalReply,
    this.repliedBy,
    this.draftWasEdited,
    this.isEscalated = false,
    required this.createdAt,
    this.repliedAt,
    this.slaDeadline,
  });

  factory Ticket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Ticket(
      ticketId            : doc.id,
      message             : data['message']              as String?    ?? '',
      status              : data['status']               as String?    ?? 'open',
      assignedTo          : data['assignedTo']           as String?,
      category            : data['category']             as String?,
      urgency             : data['urgency']              as String?,
      sentiment           : data['sentiment']            as String?,
      aiDraftReply        : data['aiDraftReply']         as String?,
      aiDraftGeneratedAt  : data['aiDraftGeneratedAt']   as Timestamp?,
      finalReply          : data['finalReply']           as String?,
      repliedBy           : data['repliedBy']            as String?,
      draftWasEdited      : data['draftWasEdited']       as bool?,
      isEscalated         : data['isEscalated']          as bool?      ?? false,
      createdAt           : data['createdAt']            as Timestamp? ?? Timestamp.now(),
      repliedAt           : data['repliedAt']            as Timestamp?,
      slaDeadline         : data['slaDeadline']          as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'ticketId'          : ticketId,
        'message'           : message,
        'status'            : status,
        'assignedTo'        : assignedTo,
        'category'          : category,
        'urgency'           : urgency,
        'sentiment'         : sentiment,
        'aiDraftReply'      : aiDraftReply,
        'aiDraftGeneratedAt': aiDraftGeneratedAt,
        'finalReply'        : finalReply,
        'repliedBy'         : repliedBy,
        'draftWasEdited'    : draftWasEdited,
        'isEscalated'       : isEscalated,
        'createdAt'         : createdAt,
        'repliedAt'         : repliedAt,
        'slaDeadline'       : slaDeadline,
      };

  Ticket copyWith({
    String?    status,
    String?    assignedTo,
    String?    category,
    String?    urgency,
    String?    sentiment,
    String?    aiDraftReply,
    Timestamp? aiDraftGeneratedAt,
    String?    finalReply,
    String?    repliedBy,
    bool?      draftWasEdited,
    bool?      isEscalated,
    Timestamp? repliedAt,
    Timestamp? slaDeadline,
  }) =>
      Ticket(
        ticketId            : ticketId,
        message             : message,
        status              : status              ?? this.status,
        assignedTo          : assignedTo          ?? this.assignedTo,
        category            : category            ?? this.category,
        urgency             : urgency             ?? this.urgency,
        sentiment           : sentiment           ?? this.sentiment,
        aiDraftReply        : aiDraftReply        ?? this.aiDraftReply,
        aiDraftGeneratedAt  : aiDraftGeneratedAt  ?? this.aiDraftGeneratedAt,
        finalReply          : finalReply          ?? this.finalReply,
        repliedBy           : repliedBy           ?? this.repliedBy,
        draftWasEdited      : draftWasEdited      ?? this.draftWasEdited,
        isEscalated         : isEscalated         ?? this.isEscalated,
        createdAt           : createdAt,
        repliedAt           : repliedAt           ?? this.repliedAt,
        slaDeadline         : slaDeadline         ?? this.slaDeadline,
      );
}
