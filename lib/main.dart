import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const TicketFlowApp());
}

class TicketFlowApp extends StatelessWidget {
  const TicketFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicketFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
          secondary: AppColors.skyBlue,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
