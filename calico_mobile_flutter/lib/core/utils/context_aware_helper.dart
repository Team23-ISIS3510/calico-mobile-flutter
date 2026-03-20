import 'package:flutter/material.dart';

class ContextAwareHelper {
  static String getTitle() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static String getMessage({required bool hasSessions}) {
    final hour = DateTime.now().hour;

    if (hour < 12) {
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

  static IconData getIcon() {
    final hour = DateTime.now().hour;

    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 18) return Icons.light_mode_outlined;
    return Icons.nightlight_round;
  }
}
