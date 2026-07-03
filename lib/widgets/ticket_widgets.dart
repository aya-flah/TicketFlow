/// Shared ticket UI helpers reused across HomeScreen, MyTicketsScreen,
/// and TicketDetailScreen.
library;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ── Status colours ─────────────────────────────────────────────────────────────
Color statusColor(String status) {
  switch (status) {
    case 'open':
      return const Color(0xFF2196F3);
    case 'assigned':
      return const Color(0xFFFF9800);
    case 'in_progress':
      return const Color(0xFFFFC107);
    case 'resolved':
      return const Color(0xFF4CAF50);
    case 'reopened':
      return const Color(0xFFF44336);
    default:
      return Colors.grey;
  }
}

// ── Urgency colours ────────────────────────────────────────────────────────────
Color urgencyColor(String? urgency) {
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

// ── Capitalise "in_progress" → "In Progress" ──────────────────────────────────
String formatStatus(String s) => s
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');

// ── Small coloured pill badge ─────────────────────────────────────────────────
class TicketBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool faint;

  const TicketBadge({
    super.key,
    required this.label,
    required this.color,
    this.faint = false,
  });

  @override
  Widget build(BuildContext context) {
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

// ── Section heading inside detail screen ────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );
}

// ── Divider with optional label ───────────────────────────────────────────────
class LabeledDivider extends StatelessWidget {
  final String? label;
  const LabeledDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    if (label == null) return const Divider(height: 28);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label!,
              style: const TextStyle(color: Colors.black38, fontSize: 12)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// ── Action button used on detail screen ──────────────────────────────────────
class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(label,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Shared AppBar builder (used by both list screens) ─────────────────────────
AppBar buildTicketAppBar({
  required String userName,
  required String role,
  required VoidCallback onSignOut,
  List<Widget> extraActions = const [],
  Widget? titleExtra,
}) {
  return AppBar(
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
          if (titleExtra != null) ...[
            const SizedBox(width: 10),
            titleExtra,
          ],
          const Spacer(),
          if (role.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.skyBlue.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role[0].toUpperCase() + role.substring(1),
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
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
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
      ...extraActions,
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
        tooltip: 'Sign out',
        onPressed: onSignOut,
      ),
      const SizedBox(width: 4),
    ],
  );
}
