import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'login_layout.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _onSignupPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final passwordConfirm = _passwordConfirmController.text.trim();
    final nickname = _nicknameController.text.trim();

    // 빈칸 검증
    if (email.isEmpty ||
        password.isEmpty ||
        passwordConfirm.isEmpty ||
        nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요.')));
      return;
    }

    // 비밀번호 일치 검증
    if (password != passwordConfirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    // 서버로 회원가입 요청 전송
    await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmailPressed(email, password, nickname);

    // UI 처리
    final state = ref.read(authControllerProvider);
    state.when(
      data: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다! 로그인해주세요.')),
        );
        Navigator.pop(context);
      },
      loading: () {},
      error: (error, _) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              LoginEmailForm(
                isSignup: true,
                emailController: _emailController,
                passwordController: _passwordController,
                passwordConfirmController: _passwordConfirmController,
                nicknameController: _nicknameController,
              ),
              const SizedBox(height: 32),

              if (authState.isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
              ],

              LoginPrimaryButton(
                text: '회원가입',
                onPressed: authState.isLoading ? () {} : _onSignupPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
