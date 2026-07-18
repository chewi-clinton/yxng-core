import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: tint, size: size * 0.5),
    );
  }
}
