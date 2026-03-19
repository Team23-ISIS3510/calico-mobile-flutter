import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Full-width primary action button with built-in loading state.
///
/// Shows a [CircularProgressIndicator] when [isLoading] is true and
/// disables the tap handler, preventing double-submits.
///
/// Usage:
///   AppPrimaryButton(
///     label: 'Register',
///     isLoading: _controller.isLoading,
///     onPressed: _controller.isLoading ? null : _onSubmit,
///   )
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

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
              : Text(label, style: AppTextStyles.buttonLabel),
        ),
      ),
    );
  }
}
