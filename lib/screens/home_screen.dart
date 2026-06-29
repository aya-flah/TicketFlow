import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/ticket.dart';
import 'ticket_detail_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String role; // 'agent' | 'manager'

  const HomeScreen({
    super.key,
    this.userName = 'there',
    this.role = '',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Filter / search state ────────────────────────────────────────────────────
  String _statusFilter = 'all'; // all | open | assigned | in_progress | resolved
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _statusFilters = [
    ('all', 'All'),
    ('open', 'Open'),
    ('assigned', 'Assigned'),
    ('in_progress', 'In Progress'),
    ('resolved', 'Resolved'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Status badge colours ─────────────────────────────────────────────────────
  static Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return const Color(0xFF2196F3); // blue
      case 'assigned':
        return const Color(0xFFFF9800); // orange
      case 'in_progress':
        return const Color(0xFFFFC107); // yellow
      case 'resolved':
        return const Color(0xFF4CAF50); // green
      case 'reopened':
        return const Color(0xFFF44336); // red
      default:
        return Colors.grey;
    }
  }

  static Color _urgencyColor(String? urgency) {
    switch (urgency) {
      case 'high':
        return const Color(0xFFF44336);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  // ── Firestore stream ─────────────────────────────────────────────────────────
  Stream<List<Ticket>> _ticketsStream() {
    return FirebaseFirestore.instance
        .collection('tickets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Ticket.fromFirestore(d)).toList());
  }

  // ── Client-side filter ───────────────────────────────────────────────────────
  List<Ticket> _applyFilters(List<Ticket> all) {
    return all.where((t) {
      final matchesStatus =
          _statusFilter == 'all' || t.status == _statusFilter;
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty || t.message.toLowerCase().contains(q);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  // ── Create test ticket dialog ────────────────────────────────────────────────
  void _showCreateDialog() {
    final msgCtrl = TextEditingController();
    String status = 'open';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'New Test Ticket',
            style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message
                const Text('Message',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: msgCtrl,
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Message is required'
                          : null,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue…',
                    hintStyle: const TextStyle(
                        color: Colors.black38, fontSize: 13),
                    filled: true,
                    fillColor:
                        AppColors.lightBlue.withValues(alpha: 0.20),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.lightBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.lightBlue),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.navy, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status dropdown
                const Text('Status',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor:
                        AppColors.lightBlue.withValues(alpha: 0.20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.lightBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.lightBlue),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                        value: 'assigned', child: Text('Assigned')),
                    DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress')),
                  ],
                  onChanged: (v) => setS(() => status = v ?? 'open'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black45)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                await _createTicket(msgCtrl.text.trim(), status);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTicket(String message, String status) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('tickets').doc();
      await ref.set({
        'ticketId': ref.id,
        'message': message,
        'status': status,
        'assignedTo': null,
        'category': null,
        'urgency': null,
        'sentiment': null,
        'aiDraftReply': null,
        'finalReply': null,
        'isEscalated': false,
        'createdAt': FieldValue.serverTimestamp(),
        'repliedAt': null,
        'slaDeadline': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket created'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        tooltip: 'New ticket',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _searchBar(),
          _filterBar(),
          Expanded(child: _ticketList()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.navy,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Image.asset('lib/image/logowt.png',
                height: 28, color: Colors.white),
            const Spacer(),
            if (widget.role.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.role[0].toUpperCase() +
                      widget.role.substring(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.skyBlue,
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.darkNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout,
              color: Colors.white70, size: 20),
          tooltip: 'Sign out',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────────
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search tickets…',
          hintStyle:
              const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: AppColors.slateBlue, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: Colors.black38, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBlue),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBlue),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.navy, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────────
  Widget _filterBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _statusFilters.map((f) {
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
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                  color:
                      active ? AppColors.navy : AppColors.lightBlue),
              checkmarkColor: Colors.white,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Ticket list ──────────────────────────────────────────────────────────────
  Widget _ticketList() {
    return StreamBuilder<List<Ticket>>(
      stream: _ticketsStream(),
      builder: (context, snap) {
        // Loading
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navy),
          );
        }

        // Error
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final filtered = _applyFilters(snap.data ?? []);

        // Empty state
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 64,
                    color: AppColors.slateBlue.withValues(alpha: 0.40)),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty ||
                          _statusFilter != 'all'
                      ? 'No tickets match your filter.'
                      : 'No tickets yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.35),
                      fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ticketCard(filtered[i]),
        );
      },
    );
  }

  // ── Ticket card ──────────────────────────────────────────────────────────────
  Widget _ticketCard(Ticket ticket) {
    final statusColor = _statusColor(ticket.status);
    final urgencyColor = _urgencyColor(ticket.urgency);
    final urgencyLabel = ticket.urgency != null
        ? ticket.urgency![0].toUpperCase() + ticket.urgency!.substring(1)
        : 'Not classified';

    // Format date
    final dt = ticket.createdAt.toDate();
    final dateStr =
        '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: AppColors.navy.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketDetailScreen(ticket: ticket),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: ID + date
              Row(
                children: [
                  Text(
                    '#${ticket.ticketId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      color: AppColors.slateBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: const TextStyle(
                        color: Colors.black38, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Message preview
              Text(
                ticket.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.darkNavy,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // Badges row
              Row(
                children: [
                  // Status badge
                  _badge(
                    label: ticket.status
                        .replaceAll('_', ' ')
                        .split(' ')
                        .map((w) =>
                            w[0].toUpperCase() + w.substring(1))
                        .join(' '),
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),

                  // Urgency badge
                  _badge(
                    label: urgencyLabel,
                    color: urgencyColor,
                    faint: ticket.urgency == null,
                  ),

                  // Escalated indicator
                  if (ticket.isEscalated) ...[
                    const SizedBox(width: 8),
                    _badge(
                        label: '⚠ Escalated',
                        color: const Color(0xFFF44336)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge({
    required String label,
    required Color color,
    bool faint = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: faint
            ? Colors.grey.withValues(alpha: 0.10)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: faint
              ? Colors.grey.withValues(alpha: 0.30)
              : color.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: faint ? Colors.grey : color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
