import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import '../utils/api_error_utils.dart';
import '../utils/nickname_utils.dart';
import '../widgets/profile_avatar.dart';

abstract final class _ProfileColors {
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
}

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  final UserProfile initialProfile;

  const ProfileSettingsScreen({super.key, required this.initialProfile});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late final TextEditingController _nicknameController;
  late final int _initialAvatarIndex;
  late int _avatarIndex;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController =
        TextEditingController(text: widget.initialProfile.nickname);
    _initialAvatarIndex = indexForAvatarValue(
      widget.initialProfile.avatarValue,
      avatarEmoji: widget.initialProfile.avatarEmoji,
      nickname: widget.initialProfile.nickname,
    );
    _avatarIndex = _initialAvatarIndex;
    _nicknameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  String get _nickname => _nicknameController.text.trim();

  bool get _validNickname => NicknameRules.isValid(_nickname);

  bool get _presetChanged => _avatarIndex != _initialAvatarIndex;

  bool get _hasChanges {
    if (_nickname != widget.initialProfile.nickname) return true;
    if (_presetChanged) return true;
    return false;
  }

  bool get _canSave => _validNickname && _hasChanges && !_isSaving;

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(userRepositoryProvider);
      final updated = await repo.updateProfile(
        nickname: _nickname,
        avatarValue: _presetChanged
            ? profileAvatars[_avatarIndex].value
            : null,
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiErrorUtils.readable(e, fallback: '프로필을 저장하지 못했습니다.'),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ProfileHeader(onBack: _isSaving ? null : () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    _AvatarPreview(
                      profile: widget.initialProfile,
                      avatarIndex: _avatarIndex,
                      presetChanged: _presetChanged,
                    ),
                    const SizedBox(height: 28),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '아바타 선택',
                        style: TextStyle(
                          fontSize: 12,
                          color: _ProfileColors.textLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AvatarGrid(
                      selectedIndex: _avatarIndex,
                      onSelected: (index) => setState(() => _avatarIndex = index),
                    ),
                    const SizedBox(height: 28),
                    _ProfileFormField(
                      label: '닉네임',
                      required: true,
                      hint: NicknameRules.lengthHint,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileInputBox(
                            hasValue: _nickname.isNotEmpty,
                            borderColor: _nickname.isNotEmpty
                                ? (_validNickname
                                    ? _ProfileColors.success
                                    : _ProfileColors.error)
                                : _ProfileColors.border,
                            child: TextField(
                              controller: _nicknameController,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _ProfileColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: '닉네임 입력',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: _ProfileColors.textSubtle,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_nickname.isNotEmpty && !_validNickname)
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Text(
                                '닉네임은 ${NicknameRules.minLength}~${NicknameRules.maxLength}자이며, 한글·영문·숫자·밑줄만 사용할 수 있습니다.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _ProfileColors.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _ProfileCtaBar(
              canSave: _canSave,
              isSaving: _isSaving,
              onSave: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final VoidCallback? onBack;

  const _ProfileHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ProfileColors.border)),
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
                  color: _ProfileColors.textLabel,
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
                  '프로필 설정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ProfileColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '아바타와 닉네임을 설정하세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: _ProfileColors.textSubtle,
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

class _AvatarPreview extends StatelessWidget {
  final UserProfile profile;
  final int avatarIndex;
  final bool presetChanged;

  const _AvatarPreview({
    required this.profile,
    required this.avatarIndex,
    required this.presetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showUploadedImage =
        !presetChanged && profile.hasUploadedAvatar;
    final avatarValue = presetChanged
        ? profileAvatars[avatarIndex].value
        : profile.avatarValue;

    return ProfileAvatar(
      avatarUrl: showUploadedImage ? profile.displayAvatarImageUrl : null,
      avatarValue: avatarValue,
      avatarEmoji: profile.avatarEmoji,
      nickname: profile.nickname,
      size: 96,
      emojiSize: 46,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4F8EFF).withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _AvatarGrid({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: profileAvatars.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final avatar = profileAvatars[index];
        final isSelected = index == selectedIndex;

        return Material(
          color: isSelected ? _ProfileColors.accentLight : _ProfileColors.bgMuted,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? _ProfileColors.accent
                      : _ProfileColors.border,
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(avatar.emoji, style: const TextStyle(fontSize: 28)),
                  if (isSelected)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: _ProfileColors.accent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '✓',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCtaBar extends StatelessWidget {
  final bool canSave;
  final bool isSaving;
  final VoidCallback? onSave;

  const _ProfileCtaBar({
    required this.canSave,
    required this.isSaving,
    required this.onSave,
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
          if (isSaving)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CircularProgressIndicator(
                color: _ProfileColors.accent,
                strokeWidth: 2,
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: canSave ? onSave : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canSave ? _ProfileColors.accent : _ProfileColors.accentLight,
                disabledBackgroundColor: _ProfileColors.accentLight,
                foregroundColor:
                    canSave ? Colors.white : _ProfileColors.accentDisabled,
                disabledForegroundColor: _ProfileColors.accentDisabled,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '저장하기',
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

class _ProfileFormField extends StatelessWidget {
  final String label;
  final bool required;
  final String? hint;
  final Widget child;

  const _ProfileFormField({
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
                color: _ProfileColors.textLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 11,
                  color: _ProfileColors.accent,
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
                  color: _ProfileColors.textSubtle,
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

class _ProfileInputBox extends StatelessWidget {
  final bool hasValue;
  final Color? borderColor;
  final Widget child;

  const _ProfileInputBox({
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
        color: hasValue ? _ProfileColors.bgFocus : _ProfileColors.bgMuted,
        border: Border.all(
          color: borderColor ??
              (hasValue ? _ProfileColors.accent : _ProfileColors.border),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
