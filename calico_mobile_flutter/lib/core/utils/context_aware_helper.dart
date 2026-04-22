import 'package:flutter/material.dart';

class ContextAwareHelper {
  static String getTitle() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static String getMessage({required bool hasSessions}) {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) {
      return hasSessions
          ? 'Empieza tu día revisando tus próximas sesiones.'
          : 'Es un buen momento para explorar cursos para hoy.';
    }

    if (hour < 18) {
      return hasSessions
          ? 'Aún tienes tiempo para prepararte para tu próxima sesión.'
          : 'Explora cursos y encuentra apoyo para tus clases.';
    }

    return hasSessions
        ? 'Revisa tus sesiones y prepárate para mañana.'
        : 'Un buen momento para repasar cursos antes de terminar el día.';
  }

  static String getIcon() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) return '☀️';
    if (hour < 18) return '🌤';
    return '🌙';
  }

  static Color getBackgroundColor() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) return const Color(0xFFFFF8E1);
    if (hour < 18) return const Color(0xFFFFF3E0);
    return const Color(0xFFE8EAF6);
  }

  static Color getAccentColor() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) return const Color(0xFFF9A825);
    if (hour < 18) return const Color(0xFFFB8C00);
    return const Color(0xFF3949AB);
  }
}
