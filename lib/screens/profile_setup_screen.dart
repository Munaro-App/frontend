import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking.dart';
import '../repositories/user_repository.dart';
import '../utils/api_error_utils.dart';
import '../utils/nickname_utils.dart';
import 'main_screen.dart';

abstract final class _SetupColors {
  static const accent = Color(0xFF4F8EFF);
  static const accentLight = Color(0xFFEEF2FF);
  static const accentBorder = Color(0xFFC7D2FE);
  static const textPrimary = Color(0xFF1A1D23);
  static const textMuted = Color(0xFF6B7280);
  static const textSubtle = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const bg = Color(0xFFF8F9FF);
  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFD1FAE5);
  static const successBorder = Color(0xFF6EE7B7);
  static const successText = Color(0xFF065F46);
}

const _steps = ['아바타 선택', '닉네임 설정', '완료'];

const _features = [
  ('🗺', '문화유산 탐험', '주변의 문화유산을 지도에서 찾아보세요'),
  ('❓', '퀴즈 미션', '역사 퀴즈를 풀고 지식을 쌓으세요'),
  ('🏆', '시즌 랭킹', '탐험가들과 순위를 경쟁하세요'),
];

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  int _step = 0;
  int _avatarIndex = 0;
  final _nicknameController = TextEditingController();
  bool _nicknameChecked = false;
  bool _isSaving = false;

  bool get _validNicknameFormat => NicknameRules.isValid(_nickname);

  ProfileAvatarOption get _selectedAvatar => profileAvatars[_avatarIndex];

  String get _nickname => _nicknameController.text.trim();

  bool get _canGoNext {
    if (_step == 0) return true;
    if (_step == 1) return _nicknameChecked;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(() {
      if (_nicknameChecked) {
        setState(() => _nicknameChecked = false);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    Navigator.of(context).pop();
  }

  void _onNext() {
    if (!_canGoNext || _step >= 2) return;
    setState(() => _step += 1);
  }

  void _checkNickname() {
    if (!_validNicknameFormat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('닉네임은 ${NicknameRules.lengthHint}.')),
      );
      return;
    }
    setState(() => _nicknameChecked = true);
  }

  Future<void> _startExploring() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(userRepositoryProvider).updateProfile(
            nickname: _nickname,
            avatarValue: _selectedAvatar.value,
          );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiErrorUtils.readable(e, fallback: '프로필 저장에 실패했습니다.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SetupColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _SetupHeader(step: _step, onBack: _isSaving ? null : _onBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: switch (_step) {
                  0 => _AvatarStep(
                      avatarIndex: _avatarIndex,
                      onSelect: (index) => setState(() => _avatarIndex = index),
                    ),
                  1 => _NicknameStep(
                      nicknameController: _nicknameController,
                      nicknameChecked: _nicknameChecked,
                      validFormat: _validNicknameFormat,
                      avatar: _selectedAvatar,
                      onCheckNickname: _checkNickname,
                    ),
                  _ => _CompleteStep(avatar: _selectedAvatar, nickname: _nickname),
                },
              ),
            ),
            _SetupBottomBar(
              step: _step,
              canGoNext: _canGoNext,
              isSaving: _isSaving,
              onNext: _onNext,
              onStart: _startExploring,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;

  const _SetupHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(10),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.chevron_left,
                      color: _SetupColors.textPrimary,
                      size: 24,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      '탐험가 프로필 만들기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _SetupColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${step + 1} / ${_steps.length} 단계',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _SetupColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_steps.length, (i) {
              final active = i <= step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 3 : 0, right: i > 0 ? 0 : 3),
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: active ? _SetupColors.accent : _SetupColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _steps[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          fontWeight: i == step ? FontWeight.w700 : FontWeight.w400,
                          color: active ? _SetupColors.accent : _SetupColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _AvatarStep extends StatelessWidget {
  final int avatarIndex;
  final ValueChanged<int> onSelect;

  const _AvatarStep({required this.avatarIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final selected = profileAvatars[avatarIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '아바타를 선택하세요',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _SetupColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          '탐험 중 나를 대표하는 캐릭터입니다',
          style: TextStyle(fontSize: 12, color: _SetupColors.textMuted),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: profileAvatars.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final avatar = profileAvatars[index];
            final isSelected = index == avatarIndex;

            return Material(
              color: isSelected ? _SetupColors.accentLight : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => onSelect(index),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _SetupColors.accent : _SetupColors.border,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(avatar.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 3),
                      Text(
                        avatar.name,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected
                              ? _SetupColors.accent
                              : _SetupColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _SetupColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _SetupColors.accentLight,
                  border: Border.all(color: _SetupColors.accent, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(selected.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '선택된 아바타',
                      style: TextStyle(fontSize: 11, color: _SetupColors.textMuted),
                    ),
                    Text(
                      selected.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _SetupColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _SetupColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '선택됨 ✓',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NicknameStep extends StatelessWidget {
  final TextEditingController nicknameController;
  final bool nicknameChecked;
  final bool validFormat;
  final ProfileAvatarOption avatar;
  final VoidCallback onCheckNickname;

  const _NicknameStep({
    required this.nicknameController,
    required this.nicknameChecked,
    required this.validFormat,
    required this.avatar,
    required this.onCheckNickname,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = nicknameController.text.trim();
    final displayNickname = nickname.isEmpty ? '탐험가닉네임' : nickname;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '닉네임을 정해주세요',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _SetupColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          '다른 탐험가들에게 보여지는 이름입니다',
          style: TextStyle(fontSize: 12, color: _SetupColors.textMuted),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: nicknameChecked ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
                  border: Border.all(
                    color: nicknameChecked ? _SetupColors.success : _SetupColors.accent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nicknameController,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _SetupColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '닉네임 입력',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: _SetupColors.textSubtle,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (nicknameChecked)
                      const Text('✓', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              height: 50,
              child: TextButton(
                onPressed: onCheckNickname,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  '중복\n확인',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: _SetupColors.accent,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (nicknameChecked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _SetupColors.successBg,
              border: Border.all(color: _SetupColors.successBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Text('✅', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  '사용 가능한 닉네임입니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: _SetupColors.successText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else if (nickname.isNotEmpty && !validFormat)
          Text(
            '${NicknameRules.minLength}~${NicknameRules.maxLength}자 · 한글/영문/숫자만 사용 가능합니다.',
            style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
          )
        else
          Text(
            NicknameRules.lengthHint,
            style: const TextStyle(fontSize: 11, color: _SetupColors.textMuted),
          ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _SetupColors.bg,
            border: Border.all(color: _SetupColors.accentBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '프로필 미리보기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _SetupColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _SetupColors.accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(avatar.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayNickname,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _SetupColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _SetupColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Lv.1',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _SetupColors.accentLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '새내기 탐험가',
                              style: TextStyle(
                                fontSize: 10,
                                color: _SetupColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompleteStep extends StatelessWidget {
  final ProfileAvatarOption avatar;
  final String nickname;

  const _CompleteStep({required this.avatar, required this.nickname});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F8EFF), Color(0xFF818CF8)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8EFF).withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(avatar.emoji, style: const TextStyle(fontSize: 50)),
        ),
        const SizedBox(height: 18),
        const Text(
          '준비 완료! 🎉',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _SetupColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$nickname 탐험가님, 무나로에 오신 걸 환영합니다!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _SetupColors.textMuted),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _SetupColors.bg,
            border: Border.all(color: _SetupColors.accentBorder, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: _features.map((feature) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _SetupColors.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(feature.$1, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.$2,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _SetupColors.textPrimary,
                            ),
                          ),
                          Text(
                            feature.$3,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _SetupColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SetupBottomBar extends StatelessWidget {
  final int step;
  final bool canGoNext;
  final bool isSaving;
  final VoidCallback onNext;
  final VoidCallback onStart;

  const _SetupBottomBar({
    required this.step,
    required this.canGoNext,
    required this.isSaving,
    required this.onNext,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = step >= 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isSaving
              ? null
              : (isLastStep ? onStart : (canGoNext ? onNext : null)),
          style: ElevatedButton.styleFrom(
            backgroundColor: (!isLastStep && !canGoNext)
                ? _SetupColors.border
                : _SetupColors.accent,
            disabledBackgroundColor: _SetupColors.border,
            foregroundColor:
                (!isLastStep && !canGoNext) ? _SetupColors.textSubtle : Colors.white,
            disabledForegroundColor: _SetupColors.textSubtle,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isLastStep ? '🏛 탐험 시작하기' : '다음 단계 →',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
