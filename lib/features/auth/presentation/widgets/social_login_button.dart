import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class SocialLoginButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onPressed;
  final Color backgroundColor;

  const SocialLoginButton({
    super.key,
    required this.assetPath,
    required this.onPressed,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            AppSpacing.md,
          ),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}