import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:frontend/features/auth/data/auth_service.dart';
import 'package:frontend/features/auth/presentation/widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSubscription;

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isGoogleReady = false;

  static const Color _navy = Color(0xFF1E293B);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _linkBlue = Color(0xFF2D28C9);
  static const Color _red = Color(0xFFD00000);
  static const Color _inputBorder = Color(0xFFCBD5E1);

  @override
  void initState() {
    super.initState();
    _googleAuthSubscription = AuthService.googleSignIn.authenticationEvents
        .listen(
          _handleGoogleAuthenticationEvent,
          onError: _handleGoogleAuthenticationError,
        );
    unawaited(_initializeGoogleSignIn());
  }

  @override
  void dispose() {
    _googleAuthSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await AuthService.initializeGoogleSignIn();
      if (mounted) {
        setState(() => _isGoogleReady = AuthService.isGoogleLoginAvailable);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleReady = false);
        _showErrorSnackBar('Google login could not be initialized');
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        _navigateToDashboard();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) {
      return;
    }

    if (!mounted) return;
    setState(() => _isGoogleLoading = true);

    try {
      await _authService.loginWithGoogleAccount(event.user);
      if (mounted) {
        _navigateToDashboard();
      }
    } on GoogleAccountNotRegisteredException catch (e) {
      await AuthService.googleSignIn.signOut();
      if (mounted) {
        final encodedEmail = Uri.encodeQueryComponent(e.email);
        context.go('/register?email=$encodedEmail');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _handleGoogleAuthenticationError(Object error) {
    if (!mounted) return;

    setState(() => _isGoogleLoading = false);
    final message = switch (error) {
      GoogleSignInException(code: GoogleSignInExceptionCode.canceled) =>
        'Google sign-in was canceled',
      GoogleSignInException() => error.description ?? 'Google sign-in failed',
      _ => 'Google sign-in failed',
    };
    _showErrorSnackBar(message);
  }

  void _navigateToDashboard() {
    final user = AuthService.currentUser.value;
    context.go(user?.role == 'manager' ? '/manager/dashboard' : '/dashboard');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          return isWide ? _buildWideLayout() : _buildMobileLayout();
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(child: _buildBrandingPanel()),
        Expanded(child: _buildFormPanel()),
      ],
    );
  }

  Widget _buildBrandingPanel() {
    return Container(
      color: _navy,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.architecture, size: 120, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'Upkeep',
            style: GoogleFonts.manrope(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      color: _navy,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.architecture, size: 64, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              'Upkeep',
              style: GoogleFonts.manrope(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            _buildCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 456),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1E293B),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome back!',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please enter your details to sign in.',
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              _buildFieldLabel('Username'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _emailController,
                hint: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Email is required' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Password'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _passwordController,
                hint: 'Enter your password',
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: Colors.black45,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                      activeColor: _blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Remember me', style: GoogleFonts.dmSans(fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      // TODO: Navigate to forgot password
                    },
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.dmSans(fontSize: 12, color: _linkBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Log in',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.black26)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Alternatively, Login with',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.black26)),
                ],
              ),
              const SizedBox(height: 16),
              _buildGoogleLoginSection(),
              const SizedBox(height: 20),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    children: [
                      const TextSpan(
                        text: "Ask your property manager for registration",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLoginSection() {
    if (_isGoogleLoading) {
      return const SizedBox(
        width: double.infinity,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_isGoogleReady && kIsWeb) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: const GoogleSignInWebButton(),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _inputBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata, size: 22, color: Colors.black54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                AuthService.isGoogleLoginAvailable
                    ? 'Google login is only available on web'
                    : 'Google login is not configured',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 2),
        Text(
          '*',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _red,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _red),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
