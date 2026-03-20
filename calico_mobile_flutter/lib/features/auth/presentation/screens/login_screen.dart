import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../controllers/login_controller.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../../core/validators/form_validators.dart';
import '../screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = LoginController(AuthRepositoryImpl(ApiClient()));
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    setState(() {});

    if (_controller.status == LoginStatus.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(studentId: _controller.userId ?? ''),
        ),
      );
    } else if (_controller.status == LoginStatus.failure) {
      _showSnackBar(
        _controller.errorMessage ?? 'Login failed. Please try again.',
        error: true,
      );
    }
  }

  void _showSnackBar(String message, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lexend(fontSize: 14)),
        backgroundColor: error
            ? const Color(0xFFB00020)
            : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      _controller.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  void _onGooglePressed() {
    _controller.loginWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LogoSection(),
              _InputField(
                label: 'Username or Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: FormValidators.email,
              ),
              _InputField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
                validator: FormValidators.password,
              ),
              _LoginButton(
                isLoading: _controller.isLoading,
                onPressed: _controller.isLoading ? null : _onLoginPressed,
              ),
              _GoogleButton(
                isLoading: _controller.isLoading,
                onPressed: _controller.isLoading ? null : _onGooglePressed,
              ),
              _RegisterLink(),
              _ForgotPasswordLink(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Center(child: Image.asset('assets/images/logo_calico.png')),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: AppTextStyles.fieldPlaceholder,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: AppTextStyles.fieldPlaceholder,
          filled: true,
          fillColor: AppColors.inputBackground,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5),
          ),
          errorStyle: AppTextStyles.errorText,
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: const Color(0xFFFCC06C),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black54,
                  ),
                )
              : Text('Log In', style: AppTextStyles.buttonLabel),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text(
              'G',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          label: Text(
            'Continue with Google',
            style: AppTextStyles.buttonLabel.copyWith(color: Colors.black87),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Colors.black26),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.inputBackground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('Register', style: AppTextStyles.buttonLabel),
        ),
      ),
    );
  }
}

class _ForgotPasswordLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: () {
          // TODO: Navigator.pushNamed(context, '/forgot-password');
        },
        child: Text(
          'Forgot Password?',
          textAlign: TextAlign.center,
          style: AppTextStyles.linkText,
        ),
      ),
    );
  }
}
