import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/router.dart' as app_router;
import '../widgets/blob_background.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Firebase login ───────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Fetch profile (non-fatal if missing)
      String name = '';
      String role = '';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .get();
        name = doc.data()?['name'] as String? ?? '';
        role = doc.data()?['role'] as String? ?? '';
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => app_router.homeForRole(
            userName: name.isNotEmpty
                ? name.split(' ').first
                : _emailController.text.split('@').first,
            role: role,
          ),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(_authMessage(e.code));
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'No account found with these credentials.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Sign-in failed ($code).';
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          SafeArea(
            child: Column(
              children: [
                _topBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    child: _card(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 16),
            label: const Text('Back',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
          Image.asset('lib/image/logowt.png',
              height: 34, color: Colors.white.withValues(alpha: 0.85)),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNavy.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Center(
              child: Text(
                'Welcome back',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Sign in to your account',
                style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.40),
                    fontSize: 14),
              ),
            ),
            const SizedBox(height: 30),

            // Email
            _label('Email'),
            const SizedBox(height: 6),
            _field(
              controller: _emailController,
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Password
            _label('Password'),
            const SizedBox(height: 6),
            _field(
              controller: _passwordController,
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.slateBlue,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
            ),
            const SizedBox(height: 12),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {},
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Sign in button
            _primaryBtn(
              label: 'Log In',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),

            // Don't have account
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                  children: [
                    const TextSpan(text: "Don't have an account? "),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignupScreen()),
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.slateBlue, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.lightBlue.withValues(alpha: 0.20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryBtn({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
