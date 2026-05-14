import 'package:flutter/material.dart';

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
        TextField(
          decoration: _inputDecoration('이메일'),
        ),

        const SizedBox(height: 20),

        TextField(
          obscureText: true,
          decoration: _inputDecoration('비밀번호'),
        ),

        if (isSignup) ...[
          const SizedBox(height: 20),

          TextField(
            obscureText: true,
            decoration: _inputDecoration('비밀번호 확인'),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}