import 'package:calico_mobile_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../controllers/register_controller.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../../core/validators/form_validators.dart';
import '../screens/login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = RegisterController(AuthRepositoryImpl(ApiClient()));
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    setState(() {});

    if (_controller.status == RegisterStatus.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(studentId: _controller.userId ?? ''),
        ),
      );
    } else if (_controller.status == RegisterStatus.failure) {
      _showSnackBar(
        _controller.errorMessage ?? 'Registration failed. Please try again.',
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_formKey.currentState?.validate() ?? false) {
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
                  _LogoSection(),
                  _InputField(
                    label: 'Full Name',
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    validator: FormValidators.fullName,
                  ),
                  _InputField(
                    label: 'Email',
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
                  _RegisterButton(
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
// Kept in the same file because they are small, have no independent lifecycle,
// and are only used by RegisterScreen.

class _LogoSection extends StatelessWidget {
  // TODO!!!!!!!: Pass this to a file for sharing widgets when we start to reuse them.
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
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 12px top+bottom, 16px left+right — matches design "padding: 12px 16px"
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        validator: validator,
        style: AppTextStyles.fieldPlaceholder,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: AppTextStyles.fieldPlaceholder,
          filled: true,
          fillColor: AppColors.inputBackground,
          // 16px padding on all sides — matches "padding: 16px" in the spec
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

class _RegisterButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _RegisterButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Matches "padding: 12px 16px" from the spec
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            // Keep the orange tint visible even when disabled
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
              : Text('Register', style: AppTextStyles.buttonLabel),
        ),
      ),
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
