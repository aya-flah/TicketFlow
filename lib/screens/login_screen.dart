import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
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

  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      // TODO: wire up auth
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    child: _buildCard(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNavy.withValues(alpha: 0.30),
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
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Sign in to your account',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.40),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Email
            _buildLabel('Email'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _emailController,
              hint: 'kristin.watson@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Password
            _buildLabel('Password'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _passwordController,
              hint: '••••••••••',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              suffixIcon: IconButton(
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
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Remember me + Forgot password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        activeColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: AppColors.slateBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Remember me',
                        style:
                            TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: forgot password flow
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Sign In button
            _buildPrimaryButton(
              label: 'Sign in',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 28),

            // Sign in with
            const Center(
              child: Text('Sign in with',
                  style: TextStyle(color: Colors.black45, fontSize: 13)),
            ),
            const SizedBox(height: 16),
            _buildSocialRow(),
            const SizedBox(height: 24),

            // Don't have account
            Center(
              child: RichText(
                text: TextSpan(
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 14),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black54,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.slateBlue, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.lightBlue.withValues(alpha: 0.25),
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

  Widget _buildPrimaryButton({
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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

  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(icon: Icons.facebook, color: const Color(0xFF1877F2)),
        const SizedBox(width: 16),
        _socialButton(
            icon: Icons.flutter_dash, color: const Color(0xFF1DA1F2)),
        const SizedBox(width: 16),
        _socialButton(
            icon: Icons.g_mobiledata_rounded,
            color: const Color(0xFFDB4437)),
        const SizedBox(width: 16),
        _socialButton(icon: Icons.apple, color: Colors.black87),
      ],
    );
  }

  Widget _socialButton({required IconData icon, required Color color}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.lightBlue, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}
