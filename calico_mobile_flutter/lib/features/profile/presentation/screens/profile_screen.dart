import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:calico_mobile_flutter/core/constants/app_colors.dart';
import 'package:calico_mobile_flutter/core/constants/app_text_styles.dart';
import 'package:calico_mobile_flutter/core/network/api_client.dart';
import 'package:calico_mobile_flutter/core/services/motion_alert_preferences.dart';
import 'package:calico_mobile_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:calico_mobile_flutter/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:calico_mobile_flutter/features/profile/domain/models/user_profile.dart';
import 'package:calico_mobile_flutter/features/profile/presentation/controllers/profile_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;
  bool _isLoggingOut = false;
  MotionAlertSettings _motionSettings = const MotionAlertSettings(
    alertEmail: '',
    studentName: '',
    location: '',
    isEnabled: false,
  );

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(
      ProfileRepositoryImpl(ApiClient()),
      widget.userId,
    );
    _controller.addListener(_onUpdate);
    _controller.loadProfile();
    _loadMotionSettings();
  }

  void _onUpdate() => setState(() {});

  Future<void> _loadMotionSettings() async {
    final saved = await MotionAlertPreferences.load();
    if (!mounted) return;
    setState(() {
      _motionSettings = saved;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _controller.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _controller.profile == null
            ? Center(
                child: Text(
                  'Could not load profile',
                  style: AppTextStyles.itemSubtitle,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileHeader(profile: _controller.profile!),
                    _AboutSection(
                      profile: _controller.profile!,
                      onEdit: _editDescription,
                    ),
                    _MotionAlertSection(
                      settings: _motionSettings,
                      onConfigure: _openMotionAlertDialog,
                    ),
                    _ChangeModeButton(),
                    _LogoutButton(
                      isLoading: _isLoggingOut,
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }

  void _editDescription() async {
    final controller = TextEditingController(
      text: _controller.profile?.description ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit description', style: AppTextStyles.itemTitle),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: AppTextStyles.itemTitle.copyWith(fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            hintText: 'Write something about yourself...',
            hintStyle: AppTextStyles.itemSubtitle,
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.linkText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              'Save',
              style: AppTextStyles.linkText.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (result != null) {
      await _controller.updateProfile(description: result);
    }
  }

  Future<void> _openMotionAlertDialog() async {
    final emailController = TextEditingController(
      text: _motionSettings.alertEmail,
    );
    final nameController = TextEditingController(
      text: _motionSettings.studentName.isEmpty
          ? (_controller.profile?.name ?? '')
          : _motionSettings.studentName,
    );
    final locationController = TextEditingController(
      text: _motionSettings.location,
    );
    var enabled = _motionSettings.isEnabled;
    String? errorText;

    final updated = await showDialog<MotionAlertSettings>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Alerta por movimiento',
            style: AppTextStyles.itemTitle,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configura el correo y activa el monitoreo. La configuración quedará guardada para futuras alertas.',
                  style: AppTextStyles.itemSubtitle,
                ),
                const SizedBox(height: 12),
                _AlertTextField(
                  controller: emailController,
                  label: 'Correo de alerta',
                  keyboardType: TextInputType.emailAddress,
                  errorText: errorText,
                ),
                const SizedBox(height: 10),
                _AlertTextField(
                  controller: nameController,
                  label: 'Nombre del estudiante',
                ),
                const SizedBox(height: 10),
                _AlertTextField(
                  controller: locationController,
                  label: 'Ubicación (opcional)',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        enabled ? 'Monitoreo activo' : 'Monitoreo inactivo',
                        style: AppTextStyles.itemSubtitle,
                      ),
                    ),
                    Switch(
                      value: enabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        if (value && emailController.text.trim().isEmpty) {
                          setDialogState(() {
                            errorText = 'Ingresa el correo antes de activar.';
                          });
                          return;
                        }
                        setDialogState(() {
                          enabled = value;
                          errorText = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar', style: AppTextStyles.linkText),
            ),
            TextButton(
              onPressed: () {
                if (enabled && emailController.text.trim().isEmpty) {
                  setDialogState(() {
                    errorText = 'Ingresa un correo válido para activar.';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  MotionAlertSettings(
                    alertEmail: emailController.text.trim(),
                    studentName: nameController.text.trim(),
                    location: locationController.text.trim(),
                    isEnabled: enabled,
                  ),
                );
              },
              child: Text(
                'Guardar',
                style: AppTextStyles.linkText.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );

    if (updated == null) return;
    await MotionAlertPreferences.save(updated);
    if (!mounted) return;
    setState(() => _motionSettings = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración de alerta guardada.')),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cerrar sesión', style: AppTextStyles.itemTitle),
        content: Text(
          '¿Seguro que quieres cerrar sesión?',
          style: AppTextStyles.itemSubtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancelar', style: AppTextStyles.linkText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Cerrar sesión',
              style: AppTextStyles.linkText.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Some sessions are not Google-backed; continue with Firebase sign out.
    }

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cerrar sesión: $e'),
          backgroundColor: const Color(0xFFB00020),
        ),
      );
      setState(() => _isLoggingOut = false);
    }
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('Student Profile', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFFF5E6D3),
            child: Text(
              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name.isNotEmpty ? profile.name : 'Student',
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(profile.email, style: AppTextStyles.itemSubtitle),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;
  const _AboutSection({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'About',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: AppColors.brown),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.description?.isNotEmpty == true
                ? profile.description!
                : 'No description yet. Tap the edit button to add one.',
            style: AppTextStyles.itemTitle.copyWith(
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionAlertSection extends StatelessWidget {
  const _MotionAlertSection({
    required this.settings,
    required this.onConfigure,
  });

  final MotionAlertSettings settings;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final hasEmail = settings.alertEmail.trim().isNotEmpty;
    final statusText = settings.isEnabled && hasEmail
        ? 'Activo'
        : 'Inactivo';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alerta por movimiento', style: AppTextStyles.itemTitle),
            const SizedBox(height: 6),
            Text(
              'Estado: $statusText${hasEmail ? '  •  ${settings.alertEmail}' : ''}',
              style: AppTextStyles.itemSubtitle,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConfigure,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Configurar alerta',
                  style: AppTextStyles.buttonLabel.copyWith(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTextField extends StatelessWidget {
  const _AlertTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.itemTitle.copyWith(fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        isDense: true,
      ),
    );
  }
}

class _ChangeModeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () async {
            final url = Uri.parse('https://forms.gle/16c7j2dKP4L9wLMG7');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text('¡Quiero ser tutor!', style: AppTextStyles.buttonLabel),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFB00020), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFFB00020),
                  ),
                )
              : Text(
                  'Cerrar sesión',
                  style: AppTextStyles.buttonLabel.copyWith(
                    color: const Color(0xFFB00020),
                  ),
                ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 1,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.black54,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.background,
      elevation: 0,
      selectedLabelStyle: AppTextStyles.itemSubtitle,
      unselectedLabelStyle: AppTextStyles.itemSubtitle,
      onTap: (i) {
        if (i == 0) Navigator.pop(context);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
