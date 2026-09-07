import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _highCtrl   = TextEditingController();
  final _medCtrl    = TextEditingController();
  final _lowCtrl    = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _highCtrl.dispose();
    _medCtrl.dispose();
    _lowCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('business')
          .get();
      final thresholds =
          doc.data()?['slaThresholds'] as Map<String, dynamic>? ??
              {'high': 2.0, 'medium': 8.0, 'low': 24.0};
      _highCtrl.text = (thresholds['high']  as num).toDouble().toString();
      _medCtrl.text  = (thresholds['medium'] as num).toDouble().toString();
      _lowCtrl.text  = (thresholds['low']   as num).toDouble().toString();
    } catch (e) {
      _highCtrl.text  = '2.0';
      _medCtrl.text   = '8.0';
      _lowCtrl.text   = '24.0';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final high   = double.parse(_highCtrl.text.trim());
      final medium = double.parse(_medCtrl.text.trim());
      final low    = double.parse(_lowCtrl.text.trim());

      await FirebaseFirestore.instance
          .collection('settings')
          .doc('business')
          .set({
        'slaThresholds': {
          'high'  : high,
          'medium': medium,
          'low'   : low,
        }
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('SLA thresholds saved'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ));
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
      if (mounted) setState(() => _saving = false);
    }
  }

  String _minuteHint(String hoursText) {
    final h = double.tryParse(hoursText);
    if (h == null) return '';
    final mins = (h * 60).toStringAsFixed(1);
    return '$hoursText h = $mins minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('SLA Settings',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.skyBlue),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.navy, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Changes apply to new tickets only. Use decimal values for demo (e.g. 0.033 ≈ 2 minutes).',
                              style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    _thresholdCard(
                      label      : 'High urgency threshold',
                      controller : _highCtrl,
                      dotColor   : const Color(0xFFF44336),
                    ),
                    const SizedBox(height: 16),
                    _thresholdCard(
                      label      : 'Medium urgency threshold',
                      controller : _medCtrl,
                      dotColor   : const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 16),
                    _thresholdCard(
                      label      : 'Low urgency threshold',
                      controller : _lowCtrl,
                      dotColor   : const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_saving ? 'Saving…' : 'Save thresholds',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _thresholdCard({
    required String label,
    required TextEditingController controller,
    required Color dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBlue),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.darkNavy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final d = double.tryParse(v.trim());
              if (d == null || d <= 0) return 'Enter a positive number';
              return null;
            },
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixText: 'hours',
              suffixStyle: const TextStyle(
                  color: Colors.black38, fontSize: 13),
              filled: true,
              fillColor: AppColors.lightBlue.withValues(alpha: 0.18),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
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
                borderSide:
                    const BorderSide(color: AppColors.navy, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Live minute equivalent hint
          if (controller.text.isNotEmpty)
            Text(
              _minuteHint(controller.text.trim()),
              style: const TextStyle(
                  color: AppColors.slateBlue,
                  fontSize: 12),
            ),
        ],
      ),
    );
  }
}
