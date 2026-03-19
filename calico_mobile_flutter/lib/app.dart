import 'package:flutter/material.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';

/// Root widget. Owns theming and the route table.
class CalicoApp extends StatelessWidget {
  const CalicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFAA324),
          surface: Color(0xFFFCFAF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFFCFAF7),
      ),
      home: LoginScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            final studentId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => HomeScreen(studentId: studentId),
            );
          default:
            return null;
        }
      },
    );
  }
}