import 'package:flutter/material.dart';

class AppColors {
  static const Color darkNavy    = Color(0xFF001D39);
  static const Color navy        = Color(0xFF0A4174);
  static const Color slateBlue   = Color(0xFF49769F);
  static const Color steelTeal   = Color(0xFF4E8EA2);
  static const Color softTeal    = Color(0xFF6EA2B3);
  static const Color skyBlue     = Color(0xFF7BBDE8);
  static const Color lightBlue   = Color(0xFFBDD8E9);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkNavy, navy, slateBlue],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, slateBlue, softTeal],
  );
}
