import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/ticket.dart';

/// Placeholder — full detail screen will be built next.
class TicketDetailScreen extends StatelessWidget {
  final Ticket ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Ticket #${ticket.ticketId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ticket ID
            _infoRow('Ticket ID', ticket.ticketId),
            const SizedBox(height: 12),
            _infoRow('Status', ticket.status),
            const SizedBox(height: 12),
            if (ticket.urgency != null) _infoRow('Urgency', ticket.urgency!),
            if (ticket.urgency != null) const SizedBox(height: 12),
            if (ticket.category != null)
              _infoRow('Category', ticket.category!),
            if (ticket.category != null) const SizedBox(height: 12),
            const Divider(height: 32),

            // Full message
            const Text(
              'Message',
              style: TextStyle(
                color: AppColors.darkNavy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.lightBlue, width: 1),
              ),
              child: Text(
                ticket.message,
                style: const TextStyle(
                    color: Colors.black87, fontSize: 15, height: 1.5),
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'Full detail screen coming soon.',
                style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.35),
                    fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.darkNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
