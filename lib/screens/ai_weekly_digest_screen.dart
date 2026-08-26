import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class AIWeeklyDigestScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  const AIWeeklyDigestScreen({super.key, required this.stats});

  @override
  State<AIWeeklyDigestScreen> createState() => _AIWeeklyDigestScreenState();
}

class _AIWeeklyDigestScreenState extends State<AIWeeklyDigestScreen>
    with SingleTickerProviderStateMixin {
  bool    _loading        = false;
  String? _digest;
  String? _error;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // Auto-generate on open
    _generate();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; _digest = null; });

    try {
      final s         = widget.stats;
      final total     = s['total']       as int;
      final resolved  = s['resolved']    as int;
      final open      = s['open']        as int;
      final escalated = s['escalated']   as int;
      final topCat    = s['topCategory'] as String;
      final avgResp   = s['avgResponse'] as String;

      final summaryData =
          'Total tickets: $total. '
          'Resolved this period: $resolved. '
          'Open/in-progress: $open. '
          'Escalated: $escalated. '
          'Top category: $topCat. '
          'Average response time: $avgResp hours.';

      final prompt =
          'You are an AI support operations analyst. Based on this week\'s '
          'ticket data, write a concise 3-4 sentence executive intelligence '
          'summary for a manager. Sound analytical and professional, like a '
          'real business intelligence report. Include specific numbers. '
          'Data: $summaryData';

      final result = await GeminiService.generateWeeklyDigest(prompt: prompt);
      if (mounted) {
        setState(() {
          _digest  = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Date range label ────────────────────────────────────────────────────────
  String get _weekRange {
    final now  = DateTime.now();
    final from = now.subtract(const Duration(days: 6));
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[from.month-1]} ${from.day} – '
        '${months[now.month-1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628), // dark bg for premium feel
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Weekly Intelligence Report',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mini stats row ────────────────────────────────────────────
            _miniStatsRow(s),
            const SizedBox(height: 28),

            // ── Loading state ─────────────────────────────────────────────
            if (_loading) _loadingCard(),

            // ── Error state ───────────────────────────────────────────────
            if (_error != null && !_loading) _errorCard(),

            // ── Digest card ───────────────────────────────────────────────
            if (_digest != null && !_loading) _digestCard(s),
          ],
        ),
      ),
    );
  }

  // ── Loading card with pulsing icon ────────────────────────────────────────
  Widget _loadingCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF7BBDE8),
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'AI is analyzing this week\'s data...',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Colors.white12,
                color: Color(0xFF7BBDE8),
                minHeight: 3,
              ),
            ),
          ],
        ),
      );

  // ── Error card ────────────────────────────────────────────────────────────
  Widget _errorCard() => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF44336).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFF44336).withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFF44336), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _regenerateButton(),
        ],
      );

  // ── Premium digest card ───────────────────────────────────────────────────
  Widget _digestCard(Map<String, dynamic> s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main report card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A4174), Color(0xFF1A5A9A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A4174).withValues(alpha: 0.50),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: AI badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7BBDE8).withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF7BBDE8)
                                .withValues(alpha: 0.40)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              color: Color(0xFF7BBDE8), size: 13),
                          SizedBox(width: 5),
                          Text('AI Generated',
                              style: TextStyle(
                                  color: Color(0xFF7BBDE8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                const Text('Weekly Intelligence Report',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2)),
                const SizedBox(height: 6),

                // Date range
                Text(_weekRange,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 20),

                // Divider
                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12)),
                const SizedBox(height: 20),

                // AI paragraph
                Text(
                  _digest!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.7,
                      letterSpacing: 0.2),
                ),
                const SizedBox(height: 24),

                // Mini stat chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statChip('Total: ${s['total']}'),
                    _statChip('Resolved: ${s['resolved']}'),
                    _statChip('Escalated: ${s['escalated']}'),
                    _statChip('Top: ${s['topCategory']}'),
                    _statChip('Avg: ${s['avgResponse']}h'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Regenerate button — subtle, bottom right
          Align(
            alignment: Alignment.centerRight,
            child: _regenerateButton(),
          ),
        ],
      );

  Widget _statChip(String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      );

  Widget _regenerateButton() => TextButton.icon(
        onPressed: _loading ? null : _generate,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Regenerate'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF7BBDE8),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );

  // ── Mini stats row ────────────────────────────────────────────────────────
  Widget _miniStatsRow(Map<String, dynamic> s) => Row(
        children: [
          _miniStat('Total',    '${s['total']}',     const Color(0xFF7BBDE8)),
          const SizedBox(width: 10),
          _miniStat('Resolved', '${s['resolved']}',  const Color(0xFF4CAF50)),
          const SizedBox(width: 10),
          _miniStat('Escalated','${s['escalated']}', const Color(0xFFF44336)),
          const SizedBox(width: 10),
          _miniStat('Avg',     '${s['avgResponse']}h',const Color(0xFF49769F)),
        ],
      );

  Widget _miniStat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
