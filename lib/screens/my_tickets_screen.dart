import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/ticket.dart';
import '../widgets/ticket_widgets.dart';
import 'ticket_detail_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final String userName;
  final String role;

  const MyTicketsScreen({
    super.key,
    required this.userName,
    required this.role,
  });

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  String _statusFilter = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const _filters = [
    ('all', 'All'),
    ('assigned', 'Assigned'),
    ('in_progress', 'In Progress'),
    ('resolved', 'Resolved'),
    ('reopened', 'Reopened'),
  ];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<Ticket>> _myTicketsStream() {
    return FirebaseFirestore.instance
        .collection('tickets')
        .where('assignedTo', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Ticket.fromFirestore).toList());
  }

  List<Ticket> _filter(List<Ticket> all) => all.where((t) {
        final ms = _statusFilter == 'all' || t.status == _statusFilter;
        final q = _searchQuery.toLowerCase();
        final mq = q.isEmpty || t.message.toLowerCase().contains(q);
        return ms && mq;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Tickets',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.skyBlue,
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.darkNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          _filterBar(),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style:
              const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search my tickets…',
            hintStyle:
                const TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon: const Icon(Icons.search,
                color: AppColors.slateBlue, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        color: Colors.black38, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.lightBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.lightBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.navy, width: 1.5),
            ),
          ),
        ),
      );

  Widget _filterBar() => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _filters.map((f) {
            final active = _statusFilter == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.$2),
                selected: active,
                onSelected: (_) =>
                    setState(() => _statusFilter = f.$1),
                backgroundColor: Colors.white,
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color: active ? Colors.white : Colors.black54,
                  fontSize: 13,
                  fontWeight: active
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                side: BorderSide(
                    color: active
                        ? AppColors.navy
                        : AppColors.lightBlue),
                checkmarkColor: Colors.white,
                showCheckmark: false,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6),
              ),
            );
          }).toList(),
        ),
      );

  Widget _list() => StreamBuilder<List<Ticket>>(
        stream: _myTicketsStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.navy));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style:
                        const TextStyle(color: Colors.redAccent)));
          }
          final list = _filter(snap.data ?? []);
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 64,
                      color: AppColors.slateBlue
                          .withValues(alpha: 0.40)),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty ||
                            _statusFilter != 'all'
                        ? 'No tickets match your filter.'
                        : 'No tickets assigned to you yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color:
                            Colors.black.withValues(alpha: 0.35),
                        fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: list.length,
            itemBuilder: (_, i) => _card(list[i]),
          );
        },
      );

  Widget _card(Ticket t) {
    final sc = statusColor(t.status);
    final uc = urgencyColor(t.urgency);
    final urgencyLabel = t.urgency != null
        ? t.urgency![0].toUpperCase() + t.urgency!.substring(1)
        : 'Not classified';
    final d = t.createdAt.toDate();
    final dateStr =
        '${d.day}/${d.month}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: AppColors.navy.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TicketDetailScreen(ticket: t)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${t.ticketId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      color: AppColors.slateBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(dateStr,
                      style: const TextStyle(
                          color: Colors.black38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.darkNavy,
                    fontSize: 14,
                    height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TicketBadge(
                      label: formatStatus(t.status), color: sc),
                  TicketBadge(
                      label: urgencyLabel,
                      color: uc,
                      faint: t.urgency == null),
                  if (t.isEscalated)
                    const TicketBadge(
                        label: '⚠ Escalated',
                        color: Color(0xFFF44336)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
