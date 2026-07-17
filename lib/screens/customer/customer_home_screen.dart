import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ticket.dart';
import '../../services/notification_service.dart';
import '../../widgets/ticket_widgets.dart';
import '../notifications_screen.dart';
import '../welcome_screen.dart';
import 'customer_ticket_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final String userName;
  const CustomerHomeScreen({super.key, this.userName = 'there'});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
} 
     

     
class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Image.asset('lib/image/logowt.png',
                  height: 28, color: Colors.white),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Customer',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.skyBlue,
                child: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      color: AppColors.darkNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Notification bell with live badge
          StreamBuilder<int>(
            stream: NotificationService.getUnreadCountStream(_uid),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 22),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF44336),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline, size: 20),
                text: 'Submit Ticket'),
            Tab(icon: Icon(Icons.list_alt_outlined, size: 20),
                text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SubmitTicketTab(uid: _uid, userName: widget.userName),
          _MyTicketsTab(uid: _uid),
        ],
      ),
    );
  }
}

// ── Submit Ticket Tab ─────────────────────────────────────────────────────────
class _SubmitTicketTab extends StatefulWidget {
  final String uid;
  final String userName;
  const _SubmitTicketTab({required this.uid, required this.userName});

  @override
  State<_SubmitTicketTab> createState() => _SubmitTicketTabState();
}

class _SubmitTicketTabState extends State<_SubmitTicketTab> {
  final _formKey   = GlobalKey<FormState>();
  final _msgCtrl   = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final ref = FirebaseFirestore.instance.collection('tickets').doc();
      await ref.set({
        'ticketId'    : ref.id,
        'message'     : _msgCtrl.text.trim(),
        'status'      : 'open',
        'isEscalated' : false,
        'submittedBy' : widget.uid,
        'assignedTo'  : null,
        'category'    : null, // always null — AI will classify
        'urgency'     : null,
        'sentiment'   : null,
        'aiDraftReply': null,
        'finalReply'  : null,
        'createdAt'   : FieldValue.serverTimestamp(),
        'repliedAt'   : null,
        'slaDeadline' : null,
      });

      // Notify agents + managers
      await NotificationService.notifyAgentsNewTicket(
        ticketId   : ref.id,
        message    : _msgCtrl.text.trim(),
        submittedBy: widget.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket submitted successfully'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Clear form
        _msgCtrl.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Hi, ${widget.userName} 👋',
              style: const TextStyle(
                  color: AppColors.darkNavy,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tell us about your issue and we\'ll get back to you.',
              style: TextStyle(color: AppColors.slateBlue, fontSize: 14),
            ),
            const SizedBox(height: 28),

            // Message
            _label('Describe your issue *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _msgCtrl,
              maxLines: 6,
              maxLength: 500,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please describe your issue'
                  : null,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              decoration: _fieldDeco(
                  'e.g. I was charged twice for my subscription…'),
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_submitting ? 'Submitting…' : 'Submit Ticket',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.w500));

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
        filled: true,
        fillColor: AppColors.lightBlue.withValues(alpha: 0.20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      );
}

// ── My Tickets Tab ────────────────────────────────────────────────────────────
class _MyTicketsTab extends StatelessWidget {
  final String uid;
  const _MyTicketsTab({required this.uid});

  Stream<List<Ticket>> _stream() => FirebaseFirestore.instance
      .collection('tickets')
      .where('submittedBy', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final tickets = s.docs.map(Ticket.fromFirestore).toList();
        // Sort client-side — no composite index needed
        tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return tickets;
      });

  String _fmt(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ticket>>(
      stream: _stream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
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
                Icon(Icons.inbox_outlined,
                    size: 64,
                    color: AppColors.slateBlue.withValues(alpha: 0.40)),
                const SizedBox(height: 16),
                Text(
                  'No tickets yet.\nSubmit one using the first tab.',
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final t = list[i];
            final sc = statusColor(t.status);
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
                      builder: (_) =>
                          CustomerTicketDetailScreen(ticket: t)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ID + date
                      Row(
                        children: [
                          Text(
                            '#${t.ticketId.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                                color: AppColors.slateBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          Text(_fmt(t.createdAt),
                              style: const TextStyle(
                                  color: Colors.black38, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Message preview
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

                      // Status badge + reply indicator
                      Row(
                        children: [
                          TicketBadge(
                              label: formatStatus(t.status), color: sc),
                          if (t.finalReply != null) ...[
                            const SizedBox(width: 8),
                            const TicketBadge(
                                label: '✓ Replied',
                                color: Color(0xFF4CAF50)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
