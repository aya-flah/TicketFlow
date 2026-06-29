import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/blob_background.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      setState(() => _isLoading = true);
      // TODO: wire up auth
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isLoading = false);
      });
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please agree to the terms to continue.')),
      );
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
                // Back button + logo corner
                _buildTopBar(context),

                // Scrollable card
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
                'Get Started',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Full Name
            _buildLabel('Full Name'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _nameController,
              hint: 'Enter Full Name',
              icon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 18),

            // Email
            _buildLabel('Email'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _emailController,
              hint: 'Enter Email',
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
              hint: 'Enter Password',
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
                if (v.length < 6) return 'Min. 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Terms checkbox
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _agreeToTerms,
                    onChanged: (v) =>
                        setState(() => _agreeToTerms = v ?? false),
                    activeColor: AppColors.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppColors.slateBlue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13),
                      children: [
                        const TextSpan(
                            text: 'I agree to the processing of '),
                        TextSpan(
                          text: 'Personal data',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Sign Up button
            _buildPrimaryButton(
              label: 'Sign up',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 28),

            // Sign up with
            const Center(
              child: Text('Sign up with',
                  style: TextStyle(color: Colors.black45, fontSize: 13)),
            ),
            const SizedBox(height: 16),
            _buildSocialRow(),
            const SizedBox(height: 24),

            // Already have account
            Center(
              child: RichText(
                text: TextSpan(
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
                        child: const Text(
                          'Sign in',
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
        _socialButton(
          icon: Icons.facebook,
          color: const Color(0xFF1877F2),
        ),
        const SizedBox(width: 16),
        _socialButton(
          icon: Icons.flutter_dash, // placeholder for Twitter/X
          color: const Color(0xFF1DA1F2),
        ),
        const SizedBox(width: 16),
        _socialButton(
          icon: Icons.g_mobiledata_rounded,
          color: const Color(0xFFDB4437),
        ),
        const SizedBox(width: 16),
        _socialButton(
          icon: Icons.apple,
          color: Colors.black87,
        ),
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
