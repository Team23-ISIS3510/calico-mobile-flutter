import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:calico_mobile_flutter/core/constants/app_colors.dart';
import 'package:calico_mobile_flutter/core/constants/app_text_styles.dart';
import 'package:calico_mobile_flutter/core/network/api_client.dart';
import 'package:calico_mobile_flutter/core/services/motion_alert_coordinator.dart';
import 'package:calico_mobile_flutter/core/services/motion_alert_file_log.dart';
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
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  bool _isLoggingOut = false;
  bool _isOnline = true;
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

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online =
          results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) _controller.syncAndReload();
      }
    });
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
    _connectivitySub.cancel();
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
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_off,
                      size: 48,
                      color: AppColors.brown,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _controller.errorMessage?.trim().isNotEmpty == true
                          ? _controller.errorMessage!
                          : 'No pudimos cargar tu perfil. Revisa tu conexión e inténtalo de nuevo.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.itemSubtitle,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _controller.loadProfile,
                      child: Text(
                        'Reintentar',
                        style: AppTextStyles.buttonLabel.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_controller.fromCache)
                      _InfoBanner(
                        icon: Icons.offline_bolt,
                        label: 'Showing saved data',
                        color: Colors.orange.shade700,
                        background: Colors.orange.shade50,
                      ),
                    if (_controller.hasPendingUpdate)
                      _InfoBanner(
                        icon: Icons.sync,
                        label:
                            'Description pending sync — will update when online',
                        color: Colors.blue.shade700,
                        background: Colors.blue.shade50,
                      ),
                    _ProfileHeader(profile: _controller.profile!),
                    _AboutSection(
                      profile: _controller.profile!,
                      onEdit: _editDescription,
                    ),
                    _MotionAlertSection(
                      settings: _motionSettings,
                      onConfigure: _openMotionAlertDialog,
                    ),
                    _ChangeModeButton(isOnline: _isOnline),
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
      if (!mounted) return;
      if (_controller.hasPendingUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally — will sync when online'),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openMotionAlertDialog() async {
    // Ensure monitoring + counters are initialized before showing the dialog.
    await MotionAlertCoordinator.instance.initialize();
    final alertEvents = await MotionAlertFileLog.instance.readAlertEvents();
    final previousAlert = alertEvents.isNotEmpty ? alertEvents.first : null;
    final defaultProfileEmail = _controller.profile?.email.trim() ?? '';
    final emailController = TextEditingController(
      text: _motionSettings.alertEmail.isNotEmpty
          ? _motionSettings.alertEmail
          : defaultProfileEmail,
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

    if (!mounted) return;
    final updated = await showDialog<MotionAlertSettings>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Alerta por movimiento', style: AppTextStyles.itemTitle),
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
                if (previousAlert != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE6DAC2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerta anterior',
                          style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAlertPreview(previousAlert),
                          style: AppTextStyles.itemSubtitle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3EA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE6DAC2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Motion detection (debug)',
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<int>(
                        valueListenable:
                            MotionAlertCoordinator.instance.hitsInWindow,
                        builder: (context, hits, _) => Text(
                          'Shake hits (last ${MotionAlertCoordinator.instance.window.inSeconds}s): '
                          '$hits / ${MotionAlertCoordinator.instance.minHitsInWindow}',
                          style: AppTextStyles.itemSubtitle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<int>(
                        valueListenable:
                            MotionAlertCoordinator.instance.totalHits,
                        builder: (context, total, _) => Text(
                          'Total hits (since monitoring started): $total',
                          style: AppTextStyles.itemSubtitle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        enabled
                            ? 'Tip: shake firmly until the counter reaches the threshold.'
                            : 'Enable monitoring to start counting hits.',
                        style: AppTextStyles.itemSubtitle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
                final resolvedEmail = emailController.text.trim().isNotEmpty
                    ? emailController.text.trim()
                    : defaultProfileEmail;
                if (enabled && resolvedEmail.isEmpty) {
                  setDialogState(() {
                    errorText = 'Ingresa un correo válido para activar.';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  MotionAlertSettings(
                    alertEmail: resolvedEmail,
                    studentName: nameController.text.trim(),
                    location: locationController.text.trim(),
                    isEnabled: enabled,
                  ),
                );
              },
              child: Text(
                'Guardar',
                style: AppTextStyles.linkText.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (updated == null) return;
    await MotionAlertPreferences.save(updated);
    final persisted = await MotionAlertPreferences.load();
    if (!mounted) return;
    setState(() => _motionSettings = persisted);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración de alerta guardada.')),
    );
  }

  String _formatAlertPreview(AlertLogEntry entry) {
    final dt = entry.timestamp.toLocal();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final state = entry.success ? 'enviada' : 'fallida por internet (no se pudo enviar)';
    return '$day/$month/$year $hour:$minute · $state\n${entry.reason}';
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
      await MotionAlertCoordinator.instance.clearLocalDataForLogout();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _motionSettings = const MotionAlertSettings(
          alertEmail: '',
          studentName: '',
          location: '',
          isEnabled: false,
        );
      });
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
    final statusText = settings.isEnabled && hasEmail ? 'Activo' : 'Inactivo';
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }
}

class _ChangeModeButton extends StatelessWidget {
  const _ChangeModeButton({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: isOnline
              ? () async {
                  final url = Uri.parse('https://forms.gle/16c7j2dKP4L9wLMG7');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
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
  const _LogoutButton({required this.isLoading, required this.onPressed});

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

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _InfoBanner({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.itemSubtitle.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
