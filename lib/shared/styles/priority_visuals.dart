import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class PriorityVisual {
  final Color accent;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;
  final int level;

  const PriorityVisual({
    required this.accent,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.level,
  });
}

class PriorityVisuals {
  const PriorityVisuals._();

  static PriorityVisual consultation(String status) {
    final value = status.trim();

    if (value == 'قيد التنفيذ') {
      return const PriorityVisual(
        accent: AppColors.teal,
        background: Color(0xFFE8F7F8),
        foreground: Color(0xFF23636A),
        icon: Icons.play_circle_fill_rounded,
        label: 'جارية الآن',
        level: 4,
      );
    }

    if (value.contains('عدم حضور') ||
        value.contains('إلغاء') ||
        value.contains('ملغي') ||
        value.contains('رفض') ||
        value.contains('مرفوض') ||
        value.contains('منتهي')) {
      return const PriorityVisual(
        accent: AppColors.error,
        background: AppColors.errorContainer,
        foreground: AppColors.cancelledText,
        icon: Icons.error_outline_rounded,
        label: 'تنبيه',
        level: 4,
      );
    }

    if (value.contains('انتظار') ||
        value.contains('مراجعة') ||
        value.contains('معلق') ||
        value.contains('طلب') ||
        value.isEmpty) {
      return const PriorityVisual(
        accent: AppColors.goldDark,
        background: AppColors.pendingBg,
        foreground: AppColors.pendingText,
        icon: Icons.pending_actions_rounded,
        label: 'يحتاج إجراء',
        level: 3,
      );
    }

    if (value == 'مؤكد' || value == 'مقبول') {
      return const PriorityVisual(
        accent: AppColors.success,
        background: AppColors.acceptedBg,
        foreground: AppColors.acceptedText,
        icon: Icons.event_available_rounded,
        label: 'مؤكد',
        level: 2,
      );
    }

    if (value == 'مكتمل' || value == 'مسترد') {
      return const PriorityVisual(
        accent: AppColors.success,
        background: Color(0xFFF0F7F3),
        foreground: AppColors.acceptedText,
        icon: Icons.check_circle_outline_rounded,
        label: 'مكتمل',
        level: 1,
      );
    }

    return const PriorityVisual(
      accent: AppColors.primary,
      background: AppColors.primaryFixed,
      foreground: AppColors.primaryDark,
      icon: Icons.info_outline_rounded,
      label: 'معلومة',
      level: 1,
    );
  }

  static PriorityVisual notification({
    required String type,
    String title = '',
    String body = '',
  }) {
    final value = type.trim().toLowerCase();
    final text = '$title $body'.toLowerCase();

    final isNegative = value.contains('reject') ||
        value.contains('expired') ||
        value.contains('cancel') ||
        value.contains('no_show') ||
        value == 'warning' ||
        value == 'alert' ||
        text.contains('رفض') ||
        text.contains('أُلغي') ||
        text.contains('الغاء') ||
        text.contains('إلغاء') ||
        text.contains('انتهت المهلة') ||
        text.contains('عدم الحضور');
    if (isNegative) {
      return const PriorityVisual(
        accent: AppColors.error,
        background: AppColors.errorContainer,
        foreground: AppColors.cancelledText,
        icon: Icons.priority_high_rounded,
        label: 'مهم',
        level: 4,
      );
    }

    final needsAction = value == 'appointment_options_ready' ||
        value == 'appointment_client_counter_offer' ||
        value == 'appointment_request_new' ||
        value.contains('appointment') ||
        text.contains('بانتظار رد') ||
        text.contains('اختر') ||
        text.contains('وافق') ||
        text.contains('مراجعتك');
    if (needsAction) {
      return const PriorityVisual(
        accent: AppColors.goldDark,
        background: AppColors.pendingBg,
        foreground: AppColors.pendingText,
        icon: Icons.notifications_active_rounded,
        label: 'يتطلب إجراء',
        level: 3,
      );
    }

    if (value == 'payment' ||
        text.contains('تم الدفع') ||
        text.contains('تم التأكيد') ||
        text.contains('تم تأكيد')) {
      return const PriorityVisual(
        accent: AppColors.success,
        background: AppColors.acceptedBg,
        foreground: AppColors.acceptedText,
        icon: Icons.check_circle_rounded,
        label: 'تم',
        level: 2,
      );
    }

    if (value == 'chat' || value == 'message') {
      return const PriorityVisual(
        accent: AppColors.teal,
        background: Color(0xFFE8F7F8),
        foreground: Color(0xFF23636A),
        icon: Icons.chat_bubble_rounded,
        label: 'رسالة',
        level: 2,
      );
    }

    if (value == 'booking') {
      return const PriorityVisual(
        accent: AppColors.primary,
        background: AppColors.primaryFixed,
        foreground: AppColors.primaryDark,
        icon: Icons.event_available_rounded,
        label: 'استشارة',
        level: 2,
      );
    }

    if (value == 'profile') {
      return const PriorityVisual(
        accent: Color(0xFF7357B7),
        background: Color(0xFFF2EEFF),
        foreground: Color(0xFF4D3983),
        icon: Icons.person_rounded,
        label: 'الحساب',
        level: 1,
      );
    }

    return const PriorityVisual(
      accent: AppColors.secondary,
      background: AppColors.secondaryContainer,
      foreground: AppColors.onSecondaryContainer,
      icon: Icons.notifications_rounded,
      label: 'معلومة',
      level: 1,
    );
  }
}
