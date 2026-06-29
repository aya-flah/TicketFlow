import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();

    // Hide status bar for a full-screen feel
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Logo scales up from 0.4 → 1.0
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Logo fades in
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    // Tagline fades in after logo
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeIn),
      ),
    );

    // Tagline slides up slightly
    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Navigate to WelcomeScreen after 2.8 s
    Future.delayed(const Duration(milliseconds: 2800), _navigateNext);
  }

  void _navigateNext() {
    if (!mounted) return;
    // Restore system UI before leaving
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const WelcomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.darkNavy,
              AppColors.navy,
              AppColors.slateBlue,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles – background depth
            _buildDecoCircle(
              alignment: const Alignment(-1.2, -1.3),
              size: 320,
              color: AppColors.slateBlue.withValues(alpha: 0.25),
            ),
            _buildDecoCircle(
              alignment: const Alignment(1.4, 1.5),
              size: 260,
              color: AppColors.steelTeal.withValues(alpha: 0.20),
            ),
            _buildDecoCircle(
              alignment: const Alignment(1.2, -0.9),
              size: 140,
              color: AppColors.skyBlue.withValues(alpha: 0.18),
            ),
            _buildDecoCircle(
              alignment: const Alignment(-1.0, 1.1),
              size: 100,
              color: AppColors.softTeal.withValues(alpha: 0.22),
            ),

            // Centre content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo — scale + fade
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => FadeTransition(
                      opacity: _logoOpacity,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            'lib/image/logo.png',
                            width: 200,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tagline — fade + slide
                  FadeTransition(
                    opacity: _taglineFade,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: Column(
                        children: [
                          Text(
                            'Manage smarter.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Resolve faster.',
                            style: TextStyle(
                              color: AppColors.skyBlue.withValues(alpha: 0.95),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom loading indicator
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _taglineFade,
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoCircle({
    required Alignment alignment,
    required double size,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
