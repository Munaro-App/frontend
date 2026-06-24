import '../utils/api_error_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/profile_setup_screen.dart';
import 'login_layout.dart';

abstract final class _SignupColors {
  static const accent = Color(0xFF4F8EFF);
  static const accentLight = Color(0xFFEFF5FF);
  static const accentDisabled = Color(0xFFA5C0FF);
  static const textPrimary = Color(0xFF1A1D23);
  static const textLabel = Color(0xFF374151);
  static const textSubtle = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const bgMuted = Color(0xFFF9FAFB);
  static const bgFocus = Color(0xFFF8F9FF);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
}

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _pwVisible = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onFormChanged);
    _passwordConfirmController.addListener(_onFormChanged);
    _emailController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;
  String get _passwordConfirm => _passwordConfirmController.text;

  static final _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  bool get _validEmail => _emailPattern.hasMatch(_email);

  bool get _validPasswordLength =>
      _password.length >= 8 && _password.length <= 20;

  bool get _pwMatch =>
      _validPasswordLength && _password == _passwordConfirm;

  bool get _canSubmitForm => _validEmail && _pwMatch;

  int get _pwStrength {
    if (_password.isEmpty) return 0;
    if (_password.length < 8) return 1;
    if (_password.length <= 20) return 3;
    return 1;
  }

  Color get _strengthColor {
    return switch (_pwStrength) {
      1 => _SignupColors.error,
      2 => _SignupColors.warning,
      3 => _SignupColors.success,
      _ => _SignupColors.border,
    };
  }

  String get _strengthLabel {
    return switch (_pwStrength) {
      1 => '약함',
      2 => '보통',
      3 => '강함',
      _ => '',
    };
  }

  Future<void> _submitSignup() async {
    if (!_canSubmitForm) return;

    final email = _email;
    final password = _password.trim();

    await ref.read(authControllerProvider.notifier).signUpWithEmailPressed(
          email,
          password,
        );

    if (!mounted) return;

    final state = ref.read(authControllerProvider);
    await state.when(
      data: (_) async {
        await ref
            .read(authControllerProvider.notifier)
            .signInWithEmailPressed(email, password);

        if (!mounted) return;

        final loginState = ref.read(authControllerProvider);
        loginState.whenOrNull(
          data: (auth) {
            if (auth == null) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
              (_) => false,
            );
          },
          error: (error, _) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ApiErrorUtils.readable(
                    error,
                    fallback: '로그인에 실패했습니다. 로그인 화면에서 다시 시도해주세요.',
                  ),
                ),
              ),
            );
            Navigator.pop(context);
          },
        );
      },
      loading: () async {},
      error: (error, _) async {
        final message = ApiErrorUtils.readable(error, fallback: '회원가입 실패');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SignupHeader(onBack: isLoading ? null : () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _buildFormStep(),
              ),
            ),
            _SignupCtaBar(
              canSubmit: _canSubmitForm,
              isLoading: isLoading,
              onSubmit: _canSubmitForm && !isLoading ? _submitSignup : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return Column(
      children: [
        _SignupFormField(
          label: '이메일',
          required: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SignupInputBox(
                hasValue: _email.isNotEmpty,
                borderColor: _email.isNotEmpty
                    ? (_validEmail ? _SignupColors.success : _SignupColors.error)
                    : _SignupColors.border,
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _SignupColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'example@email.com',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: _SignupColors.textSubtle,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_email.isNotEmpty && !_validEmail)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    '올바른 이메일 형식이 아닙니다.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _SignupColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SignupFormField(
          label: '비밀번호',
          required: true,
          hint: '8~20자',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SignupInputBox(
                hasValue: _password.isNotEmpty,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: !_pwVisible,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _SignupColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '비밀번호 입력',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: _SignupColors.textSubtle,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _pwVisible = !_pwVisible),
                      icon: Text(
                        _pwVisible ? '🙈' : '👁',
                        style: const TextStyle(fontSize: 15),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              if (_password.isNotEmpty) ...[
                const SizedBox(height: 7),
                Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: i < _pwStrength
                              ? _strengthColor
                              : _SignupColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  _strengthLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: _strengthColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SignupFormField(
          label: '비밀번호 확인',
          required: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SignupInputBox(
                hasValue: _passwordConfirm.isNotEmpty,
                borderColor: _passwordConfirm.isNotEmpty
                    ? (_pwMatch
                        ? _SignupColors.success
                        : _SignupColors.error)
                    : _SignupColors.border,
                child: TextField(
                  controller: _passwordConfirmController,
                  obscureText: true,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _SignupColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '비밀번호를 다시 입력',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: _SignupColors.textSubtle,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_passwordConfirm.isNotEmpty && !_pwMatch)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    !_validPasswordLength
                        ? '비밀번호는 8~20자여야 합니다.'
                        : '비밀번호가 일치하지 않습니다.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _SignupColors.error,
                    ),
                  ),
                ),
              if (_pwMatch)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    '✓ 비밀번호가 일치합니다.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _SignupColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SignupHeader extends StatelessWidget {
  final VoidCallback? onBack;

  const _SignupHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _SignupColors.border)),
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chevron_left,
                  color: _SignupColors.textLabel,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '회원가입',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _SignupColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '무나로 탐험가 계정 만들기',
                  style: TextStyle(
                    fontSize: 12,
                    color: _SignupColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupCtaBar extends StatelessWidget {
  final bool canSubmit;
  final bool isLoading;
  final VoidCallback? onSubmit;

  const _SignupCtaBar({
    required this.canSubmit,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CircularProgressIndicator(
                color: _SignupColors.accent,
                strokeWidth: 2,
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: canSubmit ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canSubmit ? _SignupColors.accent : _SignupColors.accentLight,
                disabledBackgroundColor: _SignupColors.accentLight,
                foregroundColor:
                    canSubmit ? Colors.white : _SignupColors.accentDisabled,
                disabledForegroundColor: _SignupColors.accentDisabled,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '가입하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupFormField extends StatelessWidget {
  final String label;
  final bool required;
  final String? hint;
  final Widget child;

  const _SignupFormField({
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _SignupColors.textLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 11,
                  color: _SignupColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(width: 4),
              Text(
                hint!,
                style: const TextStyle(
                  fontSize: 10,
                  color: _SignupColors.textSubtle,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _SignupInputBox extends StatelessWidget {
  final bool hasValue;
  final Color? borderColor;
  final Widget child;

  const _SignupInputBox({
    required this.hasValue,
    required this.child,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: hasValue ? _SignupColors.bgFocus : _SignupColors.bgMuted,
        border: Border.all(
          color: borderColor ??
              (hasValue ? _SignupColors.accent : _SignupColors.border),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
