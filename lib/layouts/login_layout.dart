import 'dart:developer';

import 'package:flutter_svg/flutter_svg.dart';
import '../screens/main_screen.dart';
import '../utils/jwt_utils.dart';
import '../utils/api_error_utils.dart';
import '../utils/nickname_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// API 설정 및 네트워크 통신
class _ApiConfig {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}

final sessionExpiredProvider = StateProvider<bool>((ref) => false);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _ApiConfig.baseUrl,
      connectTimeout: _ApiConfig.connectTimeout,
      receiveTimeout: _ApiConfig.receiveTimeout,
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  final storage = ref.read(tokenStorageProvider);

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      onSessionExpired: () {
        ref.read(sessionExpiredProvider.notifier).state = true;
      },
    ),
  );

  // 로그 확인
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: false,
    ),
  );

  return dio;
});

Future<AuthModel?> refreshAuthSession(TokenStorage storage) async {
  final auth = await storage.read();
  if (auth == null) return null;
  if (auth.refreshToken == null || auth.refreshToken!.isEmpty) return null;

  final refreshDio = Dio(
    BaseOptions(
      baseUrl: _ApiConfig.baseUrl,
      connectTimeout: _ApiConfig.connectTimeout,
      receiveTimeout: _ApiConfig.receiveTimeout,
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  try {
    final response = await refreshDio.post(
      '/auth/refresh',
      data: {'refreshToken': auth.refreshToken},
    );

    final data = response.data;
    final payload = (data is Map<String, dynamic> && data['data'] is Map)
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;

    final refreshed = AuthModel.fromJson(payload);
    await storage.save(refreshed);
    return refreshed;
  } catch (_) {
    return null;
  }
}

// 토큰 자동 전송
class AuthInterceptor extends QueuedInterceptor {
  final TokenStorage storage;
  final VoidCallback? onSessionExpired;

  AuthInterceptor({
    required this.storage,
    this.onSessionExpired,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var auth = await storage.read();
    if (auth == null) {
      handler.next(options);
      return;
    }

    if (JwtUtils.isExpired(auth.accessToken)) {
      auth = await refreshAuthSession(storage);
      if (auth == null) {
        await _expireSession();
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            message: '로그인이 만료되었습니다.',
          ),
        );
        return;
      }
    }

    options.headers['Authorization'] = 'Bearer ${auth.accessToken}';
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    if (statusCode != 401 && statusCode != 403) {
      handler.next(err);
      return;
    }

    final auth = await storage.read();
    if (auth == null) {
      handler.next(err);
      return;
    }

    if (!JwtUtils.isExpired(auth.accessToken)) {
      handler.next(err);
      return;
    }

    await _expireSession();
    handler.next(err);
  }

  Future<void> _expireSession() async {
    await storage.clear();
    onSessionExpired?.call();
  }
}

class AuthModel {
  final String accessToken;
  final String? refreshToken;
  final String? role;

  const AuthModel({
    required this.accessToken,
    this.refreshToken,
    this.role,
  });

  bool get isAdmin {
    if (role != null && JwtUtils.isAdminRole(role!)) {
      return true;
    }
    return JwtUtils.hasAdminRole(accessToken);
  }

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    return AuthModel(
      accessToken: json['accessToken'].toString(),
      refreshToken: _nullableString(json['refreshToken']),
      role: _readRole(json, user),
    );
  }

  static String? _readRole(Map<String, dynamic> json, dynamic user) {
    final rootRole = json['role'] ??
        json['memberRole'] ??
        json['userRole'];
    if (rootRole != null) return rootRole.toString();

    if (user is Map) {
      final nestedRole =
          user['role'] ?? user['memberRole'] ?? user['userRole'];
      if (nestedRole != null) return nestedRole.toString();
    }

    return null;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

enum LoginPlatform { kakao, google }

// 토큰 저장소
abstract class TokenStorage {
  Future<void> save(AuthModel auth);
  Future<AuthModel?> read();
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _roleKey = 'user_role';

  final FlutterSecureStorage _storage;

  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> save(AuthModel auth) async {
    await _storage.write(key: _accessTokenKey, value: auth.accessToken);
    if (auth.refreshToken != null && auth.refreshToken!.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: auth.refreshToken!);
    } else {
      await _storage.delete(key: _refreshTokenKey);
    }
    if (auth.role != null) {
      await _storage.write(key: _roleKey, value: auth.role);
    } else {
      await _storage.delete(key: _roleKey);
    }
  }

  @override
  Future<AuthModel?> read() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final role = await _storage.read(key: _roleKey);

    return AuthModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: role,
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _roleKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

class KakaoAuthDataSource {
  Future<String?> login() async {
    // 앱이 있으면 앱 없으면 웹
    if (await isKakaoTalkInstalled()) {
      try {
        final token = await UserApi.instance.loginWithKakaoTalk();
        return token.accessToken;
      } catch (error) {
        if (error is PlatformException && error.code == 'CANCELED') {
          return null;
        }

        try {
          final token = await UserApi.instance.loginWithKakaoAccount();
          return token.accessToken;
        } catch (error) {
          log(error.toString());
        }
      }
    } else {
      try {
        final token = await UserApi.instance.loginWithKakaoAccount();
        return token.accessToken;
      } catch (error) {
        log(error.toString());
      }
    }
    return null;
  }

  Future<void> logout() async {
    await UserApi.instance.logout();
  }
}

class GoogleAuthDataSource {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
  );

  Future<String?> login() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        print("사용자가 구글 로그인을 취소했습니다.");
        return null;
      }

      final auth = await account.authentication;

      return auth.accessToken;
    } catch (e) {
      log(e.toString());
      return null;
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
  }
}

abstract class AuthRepository {
  Future<AuthModel> login({
    required String accessToken,
    required LoginPlatform platform,
  });

  Future<AuthModel> loginWithEmail({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  });

  Future<void> logout();

  Future<void> withdraw();
}

class AuthRepositoryImpl implements AuthRepository {
  final Dio dio;

  AuthRepositoryImpl(this.dio);

  @override
  Future<AuthModel> login({
    required String accessToken,
    required LoginPlatform platform,
  }) async {
    try {
      // API 명세서와 같은 주소로 인증서 전송
      final response = await dio.post(
        '/auth/${platform.name}/login',
        data: {'accessToken': accessToken},
      );

      final data = response.data;
      final payload = (data is Map<String, dynamic> && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return AuthModel.fromJson(payload);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '로그인 실패'),
      );
    }
  }

  @override
  Future<AuthModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // 백엔드로 이메일과 비밀번호 전송
      final response = await dio.post(
        '/auth/email/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      final payload = (data is Map<String, dynamic> && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return AuthModel.fromJson(payload);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '이메일 로그인 실패'),
      );
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      await dio.post(
        '/auth/email/signup',
        data: {'email': email, 'password': password, 'nickname': nickname},
      );
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '회원가입 실패'),
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } on DioException catch (_) {
      // 서버 로그아웃 실패해도 로컬 세션은 정리합니다.
    }
  }

  @override
  Future<void> withdraw() async {
    try {
      await dio.delete('/auth/withdraw');
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '회원 탈퇴에 실패했습니다.'),
      );
    }
  }
}

// USECASE

class SignInWithKakaoUseCase {
  final KakaoAuthDataSource kakaoAuthDataSource;
  final AuthRepository repository;

  SignInWithKakaoUseCase({
    required this.kakaoAuthDataSource,
    required this.repository,
  });

  Future<AuthModel> execute() async {
    // 카카오 로그인 창을 띄워 인증서 받아오기
    final kakaoAccessToken = await kakaoAuthDataSource.login();

    if (kakaoAccessToken == null) {
      throw Exception('카카오 로그인이 취소되었거나 실패했습니다.');
    }

    // 백엔드 서버에 인증서를 넘겨주고 토큰 받아오기
    return repository.login(
      accessToken: kakaoAccessToken,
      platform: LoginPlatform.kakao,
    );
  }
}

class SignInWithEmailUseCase {
  final AuthRepository repository;

  SignInWithEmailUseCase({required this.repository});

  Future<AuthModel> execute(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('이메일과 비밀번호를 입력해주세요.');
    }
    return repository.loginWithEmail(email: email, password: password);
  }
}

class SignUpWithEmailUseCase {
  final AuthRepository repository;

  SignUpWithEmailUseCase({required this.repository});

  Future<void> execute(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('이메일과 비밀번호를 입력해주세요.');
    }
    final nickname = NicknameRules.temporaryFromEmail(email);
    return repository.signUpWithEmail(
      email: email,
      password: password,
      nickname: nickname,
    );
  }
}

class SignInWithGoogleUseCase {
  final GoogleAuthDataSource googleAuthDataSource;
  final AuthRepository repository;

  SignInWithGoogleUseCase({
    required this.googleAuthDataSource,
    required this.repository,
  });

  Future<AuthModel> execute() async {
    final googleIdToken = await googleAuthDataSource.login();

    if (googleIdToken == null) {
      throw Exception('구글 로그인이 취소되었거나 실패했습니다.');
    }

    return repository.login(
      accessToken: googleIdToken,
      platform: LoginPlatform.google,
    );
  }
}

final _kakaoAuthDataSourceProvider = Provider<KakaoAuthDataSource>((ref) {
  return KakaoAuthDataSource();
});

final _googleAuthDataSourceProvider = Provider<GoogleAuthDataSource>((ref) {
  return GoogleAuthDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(dioProvider));
});

final _authRepositoryProvider = authRepositoryProvider;

final _signInWithKakaoUseCaseProvider = Provider<SignInWithKakaoUseCase>((ref) {
  return SignInWithKakaoUseCase(
    kakaoAuthDataSource: ref.watch(_kakaoAuthDataSourceProvider),
    repository: ref.watch(_authRepositoryProvider),
  );
});

final _signUpWithEmailUseCaseProvider = Provider<SignUpWithEmailUseCase>((ref) {
  return SignUpWithEmailUseCase(repository: ref.watch(_authRepositoryProvider));
});

final _signInWithGoogleUseCaseProvider = Provider<SignInWithGoogleUseCase>((
  ref,
) {
  return SignInWithGoogleUseCase(
    googleAuthDataSource: ref.watch(_googleAuthDataSourceProvider),
    repository: ref.watch(_authRepositoryProvider),
  );
});

final _signInWithEmailUseCaseProvider = Provider<SignInWithEmailUseCase>((ref) {
  return SignInWithEmailUseCase(repository: ref.watch(_authRepositoryProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthModel?>>((ref) {
      return AuthController(
        signInWithKakao: ref.watch(_signInWithKakaoUseCaseProvider),
        signInWithGoogle: ref.watch(_signInWithGoogleUseCaseProvider),
        signInWithEmail: ref.watch(_signInWithEmailUseCaseProvider),
        signUpWithEmail: ref.watch(_signUpWithEmailUseCaseProvider),
        authRepository: ref.watch(authRepositoryProvider),
        tokenStorage: ref.watch(tokenStorageProvider),
      );
    });

class AuthController extends StateNotifier<AsyncValue<AuthModel?>> {
  final SignInWithKakaoUseCase signInWithKakao;
  final SignInWithGoogleUseCase signInWithGoogle;
  final SignInWithEmailUseCase signInWithEmail;
  final SignUpWithEmailUseCase signUpWithEmail;
  final AuthRepository authRepository;
  final TokenStorage tokenStorage;

  AuthController({
    required this.signInWithKakao,
    required this.signInWithGoogle,
    required this.signInWithEmail,
    required this.signUpWithEmail,
    required this.authRepository,
    required this.tokenStorage,
  }) : super(const AsyncData(null));

  Future<void> signInWithEmailPressed(String email, String password) async {
    state = const AsyncLoading(); // 로딩딩
    state = await AsyncValue.guard(() async {
      final auth = await signInWithEmail.execute(email, password);
      await tokenStorage.save(auth); // 토큰 저장장
      return auth; // 성공공
    });
  }

  // 카카오 버튼을 눌렀을 때
  Future<void> signInWithKakaoPressed() async {
    // 로딩
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // try { await UserApi.instance.unlink(); } catch(e) {} // 동의 항목

      // USECASE에서 토큰을 받아옴
      final auth = await signInWithKakao.execute();
      // 토큰 저장
      await tokenStorage.save(auth);
      // 로그인 종료
      return auth;
    });
  }

  Future<void> signInWithGooglePressed() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = await signInWithGoogle.execute();
      await tokenStorage.save(auth);
      return auth;
    });
  }

  Future<void> signUpWithEmailPressed(
    String email,
    String password,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await signUpWithEmail.execute(email, password);

      return null;
    });
  }

  Future<void> logout() async {
    await authRepository.logout();
    await tokenStorage.clear();
    state = const AsyncData(null);
  }

  Future<void> withdraw() async {
    await authRepository.withdraw();
    await tokenStorage.clear();
    state = const AsyncData(null);
  }
}

// UI
class LoginPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const LoginPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  static const _accentBlue = Color(0xFF4F8EFF);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          disabledBackgroundColor: _accentBlue.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class LoginAuthTextField extends StatefulWidget {
  final String hintText;
  final bool isPassword;
  final TextEditingController? controller;

  const LoginAuthTextField({
    super.key,
    required this.hintText,
    this.isPassword = false,
    this.controller,
  });

  @override
  State<LoginAuthTextField> createState() => _LoginAuthTextFieldState();
}

class _LoginAuthTextFieldState extends State<LoginAuthTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        hintText: widget.hintText,
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F8EFF), width: 1.2),
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () {
                  setState(() => _obscureText = !_obscureText);
                },
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
              )
            : null,
      ),
    );
  }
}

class LoginEmailForm extends StatelessWidget {
  final bool isSignup;
  final TextEditingController? emailController;
  final TextEditingController? passwordController;
  final TextEditingController? passwordConfirmController;
  final TextEditingController? nicknameController;

  const LoginEmailForm({
    super.key,
    this.isSignup = false,
    this.emailController,
    this.passwordController,
    this.passwordConfirmController,
    this.nicknameController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isSignup) ...[
          LoginAuthTextField(hintText: '닉네임', controller: nicknameController),
          const SizedBox(height: 20),
        ],
        LoginAuthTextField(hintText: 'example@example.com', controller: emailController),
        const SizedBox(height: 20),
        LoginAuthTextField(
          hintText: '비밀번호',
          isPassword: true,
          controller: passwordController,
        ),
        if (isSignup) ...[
          const SizedBox(height: 20),
          LoginAuthTextField(
            hintText: '비밀번호 확인',
            isPassword: true,
            controller: passwordConfirmController,
          ),
        ],
      ],
    );
  }
}


class _SocialLoginButtonStyle {
  static const buttonHeight = 45.0;
  static const borderRadius = 6.0;
  static const iconLeft = 16.0;
  static const iconSize = 20.0;
}

class _SocialLoginButton extends StatelessWidget {
  final Color backgroundColor;
  final String iconAsset;
  final String label;
  final Color labelColor;
  final VoidCallback? onPressed;
  final Border? border;
  final Color splashColor;
  final Color highlightColor;

  const _SocialLoginButton({
    required this.backgroundColor,
    required this.iconAsset,
    required this.label,
    required this.labelColor,
    required this.onPressed,
    required this.splashColor,
    required this.highlightColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: _SocialLoginButtonStyle.buttonHeight,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(
            _SocialLoginButtonStyle.borderRadius,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(
              _SocialLoginButtonStyle.borderRadius,
            ),
            splashColor: splashColor,
            highlightColor: highlightColor,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  _SocialLoginButtonStyle.borderRadius,
                ),
                border: border,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: _SocialLoginButtonStyle.iconLeft,
                    child: SvgPicture.asset(
                      iconAsset,
                      width: _SocialLoginButtonStyle.iconSize,
                      height: _SocialLoginButtonStyle.iconSize,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeroArea extends StatelessWidget {
  const _LoginHeroArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 80, bottom: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F5FF), Colors.white],
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F8EFF).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.7],
                ),
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4F8EFF), Color(0xFFA78BFA)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F8EFF).withValues(alpha: 0.3),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏛', style: TextStyle(fontSize: 38)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '무나로',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1D23),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '문화유산 탐험 게임 플랫폼',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFF3F4F6))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '또는',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFF3F4F6))),
      ],
    );
  }
}


class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  void _navigateOnAuthSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  Future<void> _onKakaoLoginPressed() async {
    await ref.read(authControllerProvider.notifier).signInWithKakaoPressed();

    if (!mounted) return;

    final state = ref.read(authControllerProvider);

    state.whenOrNull(
      data: (auth) {
        if (auth != null) {
          _navigateOnAuthSuccess('카카오 로그인 성공');
        }
      },
      error: (error, _) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              ApiErrorUtils.readable(error, fallback: '카카오 로그인 실패'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onGoogleLoginPressed() async {
    await ref.read(authControllerProvider.notifier).signInWithGooglePressed();

    if (!mounted) return;

    final state = ref.read(authControllerProvider);

    state.whenOrNull(
      data: (auth) {
        if (auth != null) {
          _navigateOnAuthSuccess('구글 로그인 성공');
        }
      },
      error: (error, _) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              ApiErrorUtils.readable(error, fallback: '구글 로그인 실패'),
            ),
          ),
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              const _LoginHeroArea(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Text(
                      '소셜 계정으로 간편 시작',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SocialLoginButton(
                      backgroundColor: const Color(0xFFFEE500),
                      iconAsset: 'assets/icons/kakao_login_logo.svg',
                      label: '카카오 로그인',
                      labelColor: const Color(0xDE000000),
                      splashColor: Colors.black.withValues(alpha: 0.08),
                      highlightColor: Colors.black.withValues(alpha: 0.04),
                      onPressed: isLoading ? null : _onKakaoLoginPressed,
                    ),
                    const SizedBox(height: 12),
                    _SocialLoginButton(
                      backgroundColor: Colors.white,
                      iconAsset: 'assets/icons/google_sign_in_logo.svg',
                      label: 'Google 로그인',
                      labelColor: const Color(0xFF1F1F1F),
                      splashColor: const Color(0xFF303030).withValues(alpha: 0.12),
                      highlightColor:
                          const Color(0xFF303030).withValues(alpha: 0.08),
                      border: Border.all(color: const Color(0xFF747775)),
                      onPressed: isLoading ? null : _onGoogleLoginPressed,
                    ),
                    const SizedBox(height: 14),
                    const _LoginDivider(),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pushNamed(context, '/email-login'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8F9FF),
                          side: const BorderSide(
                            color: Color(0xFFE0E8FF),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('✉️', style: TextStyle(fontSize: 17)),
                            SizedBox(width: 8),
                            Text(
                              '이메일 로그인',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4F8EFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '계정이 없으신가요?',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.pushNamed(context, '/signup'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '회원가입',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F8EFF),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 40),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                      height: 1.7,
                    ),
                    children: [
                      const TextSpan(text: '로그인 시 '),
                      TextSpan(
                        text: '이용약관',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' 및 '),
                      TextSpan(
                        text: '개인정보 처리방침',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: '에 동의하게 됩니다.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isLoading) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: CircularProgressIndicator(
                    color: Color(0xFF4F8EFF),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmailLoginPage extends ConsumerStatefulWidget {
  const EmailLoginPage({super.key});

  @override
  ConsumerState<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends ConsumerState<EmailLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onEmailLoginPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요.')));
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .signInWithEmailPressed(email, password);

    if (!mounted) return;

    final state = ref.read(authControllerProvider);

    state.whenOrNull(
      data: (auth) {
        if (auth != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이메일 로그인 성공')));
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      },
      error: (error, _) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              ApiErrorUtils.readable(error, fallback: '이메일 로그인 실패'),
            ),
          ),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: const Color(0xFF1A1D23),
          onPressed: isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '이메일 로그인',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D23),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '이메일과 비밀번호를 입력하세요',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 32),
              LoginEmailForm(
                emailController: _emailController,
                passwordController: _passwordController,
              ),
              const SizedBox(height: 24),
              LoginPrimaryButton(
                text: '로그인',
                onPressed: isLoading ? null : _onEmailLoginPressed,
              ),
              if (isLoading) ...[
                const SizedBox(height: 24),
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4F8EFF),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
