import 'package:flutter/material.dart';
import 'package:calico_mobile_flutter/core/constants/app_colors.dart';
import 'package:calico_mobile_flutter/core/constants/app_text_styles.dart';
import 'package:calico_mobile_flutter/core/network/api_client.dart';
import 'package:calico_mobile_flutter/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:calico_mobile_flutter/features/profile/domain/models/user_profile.dart';
import 'package:calico_mobile_flutter/features/profile/presentation/controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(
      ProfileRepositoryImpl(ApiClient()),
      widget.userId,
    );
    _controller.addListener(_onUpdate);
    _controller.loadProfile();
  }

  void _onUpdate() => setState(() {});

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
                    _ChangeModeButton(),
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

class _ChangeModeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text('Change to Tutor mode', style: AppTextStyles.buttonLabel),
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
