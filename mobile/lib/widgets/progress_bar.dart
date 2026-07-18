import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class YProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final double height;

  const YProgressBar({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: AppColors.accentSofter.withValues(alpha: 0.15),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: AppColors.accent),
        ),
      ),
    );
  }
}
