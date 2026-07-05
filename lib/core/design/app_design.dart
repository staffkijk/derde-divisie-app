import 'package:flutter/material.dart';

abstract class AppColors {
  static const primary = Color(0xFF2F8F3B);
  static const primaryDark = Color(0xFF153B2A);
  static const background = Color(0xFFF3F6F1);
  static const surface = Colors.white;
  static const border = Color(0xFFE1E8DE);
  static const text = Color(0xFF183126);
  static const textMuted = Color(0xFF667067);
  static const warning = Color(0xFFC77800);
  static const danger = Color(0xFFB3261E);
  static const info = Color(0xFF456A78);
}

abstract class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract class AppRadius {
  static const small = 10.0;
  static const card = 16.0;
  static const large = 18.0;
  static const pill = 999.0;
}

abstract class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}

abstract class AppLayout {
  static const contentMaxWidth = 1240.0;
  static const matchContentMaxWidth = 1120.0;
}

abstract class AppTextStyles {
  static const pageTitle = TextStyle(
    color: AppColors.primaryDark,
    fontSize: 26,
    fontWeight: FontWeight.w900,
  );
  static const sectionTitle = TextStyle(
    color: AppColors.primaryDark,
    fontSize: 18,
    fontWeight: FontWeight.w800,
  );
  static const bodyMuted = TextStyle(
    color: AppColors.textMuted,
    height: 1.35,
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
