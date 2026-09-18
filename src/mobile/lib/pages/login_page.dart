import 'package:flutter/material.dart';

import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/section_label.dart';

/// Sign-in. Sits outside the AppShell — there is no navigation to offer
/// someone who is not signed in yet.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthController.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _auth.signIn(_emailController.text, _passwordController.text);
    // On success the router redirects; on failure _auth.error renders below.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray10,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Grid Failure Advisor',
                      style: AppText.serif(size: 30, weight: FontWeight.w600, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    const SectionLabel('Operator sign-in'),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in to see the alerts raised on the assets you are responsible for.',
                      style: AppText.serif(
                        size: 15,
                        color: AppColors.gray70,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Hairline(),
                    const SizedBox(height: 28),

                    _field(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@utility.example',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      validator: (value) =>
                          (value == null || !value.contains('@')) ? 'Enter your work email.' : null,
                    ),
                    const SizedBox(height: 20),
                    _field(
                      controller: _passwordController,
                      label: 'Password',
                      obscure: _obscured,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Enter your password.' : null,
                      suffix: IconButton(
                        icon: Icon(
                          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.gray60,
                        ),
                        tooltip: _obscured ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscured = !_obscured),
                      ),
                    ),

                    if (_auth.error != null) ...[
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: AppColors.riskCriticalBg,
                          border: Border(
                            left: BorderSide(color: AppColors.riskCritical, width: 3),
                          ),
                        ),
                        child: Text(
                          _auth.error!,
                          style: AppText.sans(size: 13, color: AppColors.gray90, height: 1.4),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _auth.isSigningIn ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue60,
                          foregroundColor: AppColors.white,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: _auth.isSigningIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(
                                'Sign in',
                                style: AppText.sans(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: AppColors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
          style: AppText.sans(size: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.sans(size: 15, color: AppColors.gray30),
            filled: true,
            fillColor: AppColors.white,
            suffixIcon: suffix,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.gray20),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.gray20),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.blue60, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
