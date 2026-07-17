import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/ticket.dart';
import '../services/notification_service.dart';
import '../widgets/ticket_widgets.dart';
import 'my_tickets_screen.dart';
import 'notifications_screen.dart';
import 'ticket_detail_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String role;

  const HomeScreen({
    super.key,
    this.userName = 'there',
    this.role = '',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _statusFilter  = 'all';
  String _urgencyFilter = 'all'; // all | high | medium | low
  String _searchQuery   = '';
  final _searchCtrl = TextEditingController();

  static const _statusFilters = [
    ('all',         'All'),
    ('open',        'Open'),
    ('assigned',    'Assigned'),
    ('in_progress', 'In Progress'),
    ('resolved',    'Resolved'),
  ];

  static const _urgencyFilters = [
    ('all',    'All'),
    ('high',   'High'),
    ('medium', 'Medium'),
    ('low',    'Low'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Firestore stream ─────────────────────────────────────────────────────────
  Stream<List<Ticket>> _stream() => FirebaseFirestore.instance
      .collection('tickets')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Ticket.fromFirestore).toList());

  List<Ticket> _filter(List<Ticket> all) => all.where((t) {
        final ms = _statusFilter == 'all' || t.status == _statusFilter;
        final mu = _urgencyFilter == 'all' || t.urgency == _urgencyFilter;
        final q  = _searchQuery.toLowerCase();
        return ms && mu &&
            (q.isEmpty || t.message.toLowerCase().contains(q));
      }).toList();

  // ── Create ticket ────────────────────────────────────────────────────────────
  Future<void> _createTicket(String message, String status) async {
    try {
      final ref = FirebaseFirestore.instance.collection('tickets').doc();
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

      // Notify all agents about the new ticket
      await NotificationService.notifyAgentsNewTicket(
        ticketId: ref.id,
        message: message,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ticket created'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Seed 30 test tickets ─────────────────────────────────────────────────────
  Future<void> _seedTickets() async {
    // 30 realistic messages across 4 categories
    const messages = [
      // Billing (8)
      "I was charged twice for my subscription this month. Please refund the duplicate charge immediately.",
      "My invoice shows \$149 but I'm on the \$49/month plan. This is incorrect, please fix it.",
      "I cancelled my plan 3 weeks ago and I'm still being billed. This is unacceptable.",
      "I need a VAT invoice for my last 3 payments for accounting purposes.",
      "The promo code I entered at checkout was not applied to my bill. I'd like a credit.",
      "I was charged in USD but my account is set to EUR. Please adjust the currency.",
      "My payment failed but you still debited my card. I need this reversed urgently.",
      "Can you explain the line item 'Platform fee \$12' on my last invoice? I don't recall agreeing to this.",
      // Bug reports (8)
      "The mobile app crashes every time I try to open a ticket on iOS 17. Reproducible 100% of the time.",
      "Attachments fail to upload when the file size is over 2MB. I get a generic error with no details.",
      "The search bar in the dashboard returns no results even when I type the exact ticket ID.",
      "Email notifications stopped working 2 days ago. I'm not receiving any updates on my tickets.",
      "The status filter dropdown resets to 'All' every time I navigate away and come back.",
      "Dark mode on the web app shows white text on a white background in the ticket composer.",
      "I can't log in from Safari on macOS — it redirects in a loop after entering my password.",
      "The API endpoint POST /tickets returns 500 intermittently with no useful error body.",
      // General questions (7)
      "How do I add a second user to my account? I want my colleague to access our tickets.",
      "Is there a way to export all our tickets to CSV for a quarterly review?",
      "What is the SLA response time for tickets marked as 'high urgency'?",
      "Can I integrate your platform with Slack to get ticket updates in our team channel?",
      "How do I change the email address associated with my account?",
      "Is there a REST API I can use to create tickets programmatically from our internal tool?",
      "What happens to our data if we cancel the subscription? How long is it retained?",
      // Angry complaints (7)
      "This is absolutely ridiculous. I've been waiting 5 days for a response and nobody has contacted me. I want a refund.",
      "Your support is completely useless. I've opened the same issue 3 times and nobody fixes it.",
      "I am furious. Your last update BROKE my entire workflow and you haven't even acknowledged it.",
      "Three weeks without a working product and you keep closing my tickets without resolving them. I am escalating this.",
      "I'm done. Fix this NOW or I'm disputing every charge with my bank and posting a review everywhere.",
      "This is the worst support experience I have ever had. My clients are complaining because YOUR platform is down.",
      "Someone needs to call me TODAY. I have lost thousands of dollars because of your bug and I'm getting no response.",
    ];

    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < messages.length; i++) {
      final ref = FirebaseFirestore.instance.collection('tickets').doc();
      // Stagger over the last 7 days (oldest first)
      final offset = Duration(
        hours: ((messages.length - i) * 5) + (i * 2),
        minutes: (i * 17) % 60,
      );
      final createdAt = Timestamp.fromDate(now.subtract(offset));

      batch.set(ref, {
        'ticketId': ref.id,
        'message': messages[i],
        'status': 'open',
        'assignedTo': null,
        'category': null,
        'urgency': null,
        'sentiment': null,
        'aiDraftReply': null,
        'finalReply': null,
        'isEscalated': false,
        'createdAt': createdAt,
        'repliedAt': null,
        'slaDeadline': null,
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ 30 test tickets seeded'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Seed failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Dev dialog ───────────────────────────────────────────────────────────────
  void _showDevDialog() {
    final msgCtrl = TextEditingController();
    String status = 'open';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Dev Tools',
              style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Single ticket ──────────────────────────────────────
                const Text('Message',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: msgCtrl,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                  decoration: _fieldDeco('Describe the issue…'),
                ),
                const SizedBox(height: 14),
                const Text('Status',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: _fieldDeco(null),
                  items: const [
                    DropdownMenuItem(
                        value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                        value: 'assigned', child: Text('Assigned')),
                    DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress')),
                  ],
                  onChanged: (v) => setS(() => status = v ?? 'open'),
                ),
                const SizedBox(height: 16),

                // ── Seed button ────────────────────────────────────────
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _seedTickets();
                    },
                    icon: const Icon(Icons.dataset_outlined, size: 18),
                    label: const Text('Seed 30 test tickets'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
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

  InputDecoration _fieldDeco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Colors.black38, fontSize: 13),
        filled: true,
        fillColor: AppColors.lightBlue.withValues(alpha: 0.20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.navy, width: 1.5),
        ),
      );




  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _appBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDevDialog,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        tooltip: 'Dev tools / New ticket',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _searchBar(),
          _statusFilterBar(),
          _urgencyFilterBar(),
          Expanded(child: _ticketList()),
        ],
      ),
    );
  }

  AppBar _appBar() => AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Image.asset('lib/image/logowt.png',
                  height: 28, color: Colors.white),
              const Spacer(),
              if (widget.role.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // ── Notification bell with live unread badge ────────────────────
          StreamBuilder<int>(
            stream: NotificationService.getUnreadCountStream(
                FirebaseAuth.instance.currentUser?.uid ?? ''),
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
          // My Tickets shortcut
          IconButton(
            icon: const Icon(Icons.assignment_ind_outlined,
                color: Colors.white, size: 22),
            tooltip: 'My Tickets',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyTicketsScreen(
                  userName: widget.userName,
                  role: widget.role,
                ),
              ),
            ),
          ),
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

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: TextField(
          controller: _searchCtrl,
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

  Widget _statusFilterBar() => SizedBox(
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
                    color: active ? AppColors.navy : AppColors.lightBlue),
                checkmarkColor: Colors.white,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            );
          }).toList(),
        ),
      );

  Widget _urgencyFilterBar() {
    // Urgency chip colours
    Color chipColor(String urgency) {
      switch (urgency) {
        case 'high':   return const Color(0xFFF44336);
        case 'medium': return const Color(0xFFFF9800);
        case 'low':    return const Color(0xFF4CAF50);
        default:       return AppColors.navy;
      }
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        children: _urgencyFilters.map((f) {
          final active  = _urgencyFilter == f.$1;
          final color   = f.$1 == 'all' ? AppColors.navy : chipColor(f.$1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: active,
              onSelected: (_) =>
                  setState(() => _urgencyFilter = f.$1),
              backgroundColor: Colors.white,
              selectedColor: color,
              labelStyle: TextStyle(
                color: active ? Colors.white : Colors.black54,
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                  color: active ? color : AppColors.lightBlue),
              checkmarkColor: Colors.white,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _ticketList() => StreamBuilder<List<Ticket>>(
        stream: _stream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.navy));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(
                        color: Colors.redAccent)));
          }
          final list = _filter(snap.data ?? []);
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64,
                      color: AppColors.slateBlue
                          .withValues(alpha: 0.40)),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty ||
                            _statusFilter != 'all' ||
                            _urgencyFilter != 'all'
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
            padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 88),
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
