import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/escalation_service.dart';
import '../services/notification_service.dart';
import 'ai_weekly_digest_screen.dart';
import 'escalations_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, this.userName = 'Manager'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    EscalationService.checkAndEscalateOverdueTickets();
  }

  // ── Convert Firestore snapshot to stats map ──────────────────────────────
  Map<String, dynamic> _computeStats(List<QueryDocumentSnapshot> docs) {
    int open = 0, resolved = 0, escalated = 0;
    int low = 0, medium = 0, high = 0, noUrgency = 0;
    double totalResponseHours = 0;
    int responseSamples = 0;

    final now     = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final Map<String, int> dailyVolume   = {};
    final Map<String, int> categoryCount = {};

    for (var d = 0; d < 7; d++) {
      final day = now.subtract(Duration(days: d));
      dailyVolume['${day.day}/${day.month}'] = 0;
    }

    for (final doc in docs) {
      final data      = doc.data() as Map<String, dynamic>;
      final status    = data['status']      as String?    ?? '';
      final urg       = data['urgency']     as String?;
      final isEsc     = data['isEscalated'] as bool?      ?? false;
      final cat       = data['category']    as String?;
      final createdAt = data['createdAt']   as Timestamp?;
      final repliedAt = data['repliedAt']   as Timestamp?;

      if (status != 'resolved') open++;
      if (status == 'resolved') resolved++;
      if (isEsc) escalated++;

      switch (urg) {
        case 'high':   high++;      break;
        case 'medium': medium++;    break;
        case 'low':    low++;       break;
        default:       noUrgency++; break;
      }

      if (createdAt != null) {
        final dt = createdAt.toDate();
        if (dt.isAfter(weekAgo)) {
          final key = '${dt.day}/${dt.month}';
          dailyVolume[key] = (dailyVolume[key] ?? 0) + 1;
          if (cat != null && cat != 'unclassified') {
            categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
          }
        }
      }

      if (createdAt != null && repliedAt != null) {
        final diff = repliedAt.toDate().difference(createdAt.toDate());
        totalResponseHours += diff.inMinutes / 60.0;
        responseSamples++;
      }
    }

    String topCategory = 'N/A';
    if (categoryCount.isNotEmpty) {
      topCategory = categoryCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      topCategory =
          topCategory[0].toUpperCase() + topCategory.substring(1);
    }

    final avgResponse = responseSamples > 0
        ? (totalResponseHours / responseSamples).toStringAsFixed(1)
        : 'N/A';

    final orderedDays = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = '${day.day}/${day.month}';
      return MapEntry(key, dailyVolume[key] ?? 0);
    });

    return {
      'total'        : docs.length,
      'open'         : open,
      'resolved'     : resolved,
      'escalated'    : escalated,
      'high'         : high,
      'medium'       : medium,
      'low'          : low,
      'noUrgency'    : noUrgency,
      'dailyVolume'  : orderedDays,
      'topCategory'  : topCategory,
      'avgResponse'  : avgResponse,
      'categoryCount': categoryCount,
    };
  }

  // ── Live stream of all tickets ────────────────────────────────────────────
  Stream<Map<String, dynamic>> get _statsStream => _db
      .collection('tickets')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => _computeStats(snap.docs));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _appBar(context),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _statsStream,
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
          final s = snap.data!;
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Greeting
                Text(
                  'Hello, ${widget.userName} 👋',
                  style: const TextStyle(
                      color: AppColors.darkNavy,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('Here\'s your support overview',
                    style: TextStyle(
                        color: AppColors.slateBlue, fontSize: 14)),
                const SizedBox(height: 20),

                // a) Stats row
                _statsRow(s),
                const SizedBox(height: 24),

                // b) Urgency breakdown
                _sectionHeader('Urgency Breakdown'),
                const SizedBox(height: 12),
                _urgencyChart(s),
                const SizedBox(height: 24),

                // c) Ticket volume over 7 days
                _sectionHeader('Ticket Volume — Last 7 Days'),
                const SizedBox(height: 12),
                _volumeChart(s),
                const SizedBox(height: 24),

                // d) Top category + e) Avg response
                Row(
                  children: [
                    Expanded(child: _infoCard(
                      icon : Icons.category_outlined,
                      color: AppColors.steelTeal,
                      label: 'Top Category',
                      value: s['topCategory'] as String,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _infoCard(
                      icon : Icons.timer_outlined,
                      color: AppColors.navy,
                      label: 'Avg Response',
                      value: '${s['avgResponse']} hrs',
                    )),
                  ],
                ),
                const SizedBox(height: 24),

                // AI Digest shortcut
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => AIWeeklyDigestScreen(stats: s))),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.navy, AppColors.slateBlue],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Weekly Digest',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Generate an executive summary with Gemini',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            color: Colors.white60, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

             
              ],
            );
          
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _appBar(BuildContext context) => AppBar(
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
              const SizedBox(width: 10),
              const Text('Dashboard',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Manager',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        actions: [
          // Tickets list shortcut (manager)
          IconButton(
            icon: const Icon(Icons.list_alt_outlined,
                color: Colors.white, size: 22),
            tooltip: 'All Tickets',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  userName: widget.userName,
                  role: 'manager',
                ),
              ),
            ),
          ),
          // Notifications
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
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF44336),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          // Escalations
          StreamBuilder<int>(
            stream: EscalationService.getActiveEscalationCountStream(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.warning_amber_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const EscalationsScreen())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF44336),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      );

  // ── a) Stats row ──────────────────────────────────────────────────────────
  Widget _statsRow(Map<String, dynamic> s) {
    return Row(
      children: [
        _statCard('Total',     '${s['total']}',     AppColors.navy),
        const SizedBox(width: 10),
        _statCard('Open',      '${s['open']}',      const Color(0xFF2196F3)),
        const SizedBox(width: 10),
        _statCard('Resolved',  '${s['resolved']}',  const Color(0xFF4CAF50)),
        const SizedBox(width: 10),
        _statCard('Escalated', '${s['escalated']}', const Color(0xFFF44336)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.black45, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  // ── b) Urgency pie chart ──────────────────────────────────────────────────
  Widget _urgencyChart(Map<String, dynamic> s) {
    final high   = (s['high']   as int).toDouble();
    final medium = (s['medium'] as int).toDouble();
    final low    = (s['low']    as int).toDouble();
    final none   = (s['noUrgency'] as int).toDouble();
    final total  = high + medium + low + none;

    if (total == 0) {
      return _emptyCard('No urgency data yet');
    }

    final sections = <PieChartSectionData>[];
    void add(double v, Color c, String label) {
      if (v == 0) return;
      sections.add(PieChartSectionData(
        value: v,
        color: c,
        title: '${(v / total * 100).round()}%',
        titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold),
        radius: 60,
      ));
    }
    add(high,   const Color(0xFFF44336), 'High');
    add(medium, const Color(0xFFFF9800), 'Medium');
    add(low,    const Color(0xFF4CAF50), 'Low');
    add(none,   Colors.grey,             'N/A');

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 28,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legend(const Color(0xFFF44336), 'High',   high.toInt()),
              _legend(const Color(0xFFFF9800), 'Medium', medium.toInt()),
              _legend(const Color(0xFF4CAF50), 'Low',    low.toInt()),
              if (none > 0)
                _legend(Colors.grey, 'Unclassified', none.toInt()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('$label: $count',
                style: const TextStyle(
                    color: Colors.black54, fontSize: 13)),
          ],
        ),
      );

  // ── c) Volume line chart ──────────────────────────────────────────────────
  Widget _volumeChart(Map<String, dynamic> s) {
    final days = s['dailyVolume'] as List<MapEntry<String, int>>;
    final maxY = days.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    if (maxY == 0) return _emptyCard('No tickets in the last 7 days');

    final spots = days.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.toDouble());
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: _cardDeco(),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxY + 2).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxY > 4 ? (maxY / 4).ceilToDouble() : 1,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                      color: Colors.black38, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    days[idx].key,
                    style: const TextStyle(
                        color: Colors.black38, fontSize: 9),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.navy,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.navy.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
            color: AppColors.darkNavy,
            fontSize: 15,
            fontWeight: FontWeight.bold),
      );

  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.black45, fontSize: 12)),
          ],
        ),
      );

  Widget _emptyCard(String msg) => Container(
        height: 80,
        decoration: _cardDeco(),
        child: Center(
          child: Text(msg,
              style: const TextStyle(color: Colors.black38, fontSize: 13)),
        ),
      );

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
}
