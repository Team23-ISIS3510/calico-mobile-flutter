import 'dart:async';

import 'package:calico_mobile_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../controllers/register_controller.dart';
import '../../../home/presentation/screens/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final RegisterController _controller;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;
  // True when the connection dropped while a registration request was in flight.
  bool _connectionLostDuringRequest = false;

  @override
  void initState() {
    super.initState();
    _controller = RegisterController(AuthRepositoryImpl(ApiClient()));
    _controller.addListener(_onControllerUpdate);
    _watchConnectivity();
  }

  Future<void> _watchConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(
      () => _isOffline =
          initial.isEmpty || initial.every((r) => r == ConnectivityResult.none),
    );

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      final wasOffline = _isOffline;
      final nowOffline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);

      // Connection dropped while a request was in flight → warn immediately
      // so the user is not left staring at the spinner waiting for a timeout.
      if (!wasOffline && nowOffline && _controller.isLoading) {
        _connectionLostDuringRequest = true;
        _showSnackBar(
          'Connection lost. Waiting for the server response to time out…',
          error: true,
        );
      }

      // Back online after being offline.
      if (wasOffline && !nowOffline) {
        _showSnackBar(
          'You\'re back online. You can try registering again.',
          error: false,
        );
      }

      setState(() => _isOffline = nowOffline);
    });
  }

  void _onControllerUpdate() {
    setState(() {});

    if (_controller.status == RegisterStatus.success) {
      _connectionLostDuringRequest = false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(studentId: _controller.userId ?? ''),
        ),
      );
    } else if (_controller.status == RegisterStatus.failure) {
      final raw = _controller.errorMessage ?? '';
      final String message;

      if (_connectionLostDuringRequest ||
          raw.contains('No internet') ||
          raw.contains('timed out') ||
          raw.contains('Connection error')) {
        message =
            'Connection was lost during registration. Please check your internet and try again.';
      } else {
        message = raw.isEmpty ? 'Registration failed. Please try again.' : raw;
      }

      _connectionLostDuringRequest = false;
      _showSnackBar(message, error: true);
    }
  }

  void _showSnackBar(String message, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lexend(fontSize: 14)),
        backgroundColor:
            error ? const Color(0xFFB00020) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    // Guard: do not allow a new attempt while one is already in flight.
    if (_controller.isLoading) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isOffline) {
      _showSnackBar(
        'No internet connection. Please try again when you\'re online.',
        error: true,
      );
      return;
    }

    // Collapse any sequence of internal whitespace to a single space
    // so "John     Smith" is stored as "John Smith".
    final cleanName = _nameController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    _controller.register(
      name: cleanName,
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LogoSection(),
                  if (_isOffline)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No internet connection. Connect to the internet before registering.',
                        style: AppTextStyles.itemSubtitle.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  AppTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    validator: FormValidators.fullName,
                  ),
                  AppTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: FormValidators.email,
                  ),
                  AppTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                    validator: FormValidators.password,
                  ),
                  AppPrimaryButton(
                    label: 'Register',
                    isLoading: _controller.isLoading,
                    onPressed: _controller.isLoading
                        ? null
                        : _onRegisterPressed,
                  ),
                  _LoginLink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────
// Only screen-specific widgets live here.
// Reusable widgets have been moved to core/widgets/.

/// Centered logo header — specific to auth screens (extra top padding).
class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: const Center(child: AppLogo()),
    );
  }
}

class _LoginLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Text(
          'Already have an account? Login',
          textAlign: TextAlign.center,
          style: AppTextStyles.linkText,
        ),
      ),
    );
  }
}
