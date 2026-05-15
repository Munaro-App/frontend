import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

import 'auth_text_field.dart';

class EmailLoginForm extends StatelessWidget {
  final bool isSignup;

  const EmailLoginForm({
    super.key,
    this.isSignup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AuthTextField(
          hintText: '이메일',
        ),

        const SizedBox(
          height: AppSpacing.lg,
        ),

        const AuthTextField(
          hintText: '비밀번호',
          isPassword: true,
        ),

        if (isSignup) ...[
          const SizedBox(
            height: AppSpacing.lg,
          ),

          const AuthTextField(
            hintText: '비밀번호 확인',
            isPassword: true,
          ),
        ],
      ],
    );
  }
}