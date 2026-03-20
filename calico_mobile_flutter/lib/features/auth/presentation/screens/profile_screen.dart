import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(),
              _AboutSection(),
              _SubjectsSection(),
              _ChangeModeButton(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
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
            child: ClipOval(
              child: Image.network(
                'https://i.pravatar.cc/150?img=47',
                width: 104,
                height: 104,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sophia Chen',
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'I am a dedicated student with a strong interest in Math, Physics, and Chemistry. '
            'I am committed to achieving my academic goals and consistently work hard to improve '
            'my understanding and performance in these subjects.',
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

class _SubjectsSection extends StatelessWidget {
  final List<String> subjects = const ['Math', 'Physics', 'Chemistry'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subjects',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: subjects
                .map(
                  (s) => Chip(
                    label: Text(s, style: AppTextStyles.itemTitle),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.black26),
                    ),
                  ),
                )
                .toList(),
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
        if (i == 0) {
          Navigator.pop(context);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
