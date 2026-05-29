import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';

// API 설정 및 네트워크 통신
class _ApiConfig {
  // 백엔드 서버 기본 주소
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // 10초 동안 응답이 없으면 에러
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _ApiConfig.baseUrl,
      connectTimeout: _ApiConfig.connectTimeout,
      receiveTimeout: _ApiConfig.receiveTimeout,
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  final storage = ref.read(_tokenStorageProvider);

  dio.interceptors.add(AuthInterceptor(storage));

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

class AuthInterceptor extends Interceptor {
  final TokenStorage storage;

  AuthInterceptor(this.storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 토큰 읽기
    final auth = await storage.read();
    final token = auth?.accessToken;

    // 토큰이 있으면 형태를 변환
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    print("=== REQUEST ===");
    print(options.uri);
    print(options.headers);

    // 서버로 전송
    handler.next(options);
  }
}

class AuthModel {
  final String accessToken;
  final String refreshToken;

  const AuthModel({required this.accessToken, required this.refreshToken});

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
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

  final FlutterSecureStorage _storage;

  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> save(AuthModel auth) async {
    await _storage.write(key: _accessTokenKey, value: auth.accessToken);
    await _storage.write(key: _refreshTokenKey, value: auth.refreshToken);
  }

  @override
  Future<AuthModel?> read() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    return AuthModel(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

final _tokenStorageProvider = Provider<TokenStorage>((ref) {
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
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<String?> login() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      return auth.idToken;
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
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? '로그인 실패')
          : '로그인 실패';
      throw Exception(message);
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
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? '이메일 로그인 실패')
          : '이메일 로그인 실패';
      throw Exception(message);
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

final _authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(_dioProvider));
});

final _signInWithKakaoUseCaseProvider = Provider<SignInWithKakaoUseCase>((ref) {
  return SignInWithKakaoUseCase(
    kakaoAuthDataSource: ref.watch(_kakaoAuthDataSourceProvider),
    repository: ref.watch(_authRepositoryProvider),
  );
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
        tokenStorage: ref.watch(_tokenStorageProvider),
      );
    });

class AuthController extends StateNotifier<AsyncValue<AuthModel?>> {
  final SignInWithKakaoUseCase signInWithKakao;
  final SignInWithGoogleUseCase signInWithGoogle;
  final SignInWithEmailUseCase signInWithEmail;
  final TokenStorage tokenStorage;

  AuthController({
    required this.signInWithKakao,
    required this.signInWithGoogle,
    required this.signInWithEmail,
    required this.tokenStorage,
  }) : super(const AsyncData(null));

  Future<void> signInWithEmailPressed(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = await signInWithEmail.execute(email, password);
      await tokenStorage.save(auth);
      return auth;
    });
  }

  // 카카오 버튼을 눌렀을 때
  Future<void> signInWithKakaoPressed() async {
    // 로딩
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
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

  Future<void> logout() async {
    // 로그아웃시 클리어
    await tokenStorage.clear();
    state = const AsyncData(null);
  }
}

// UI
class LoginPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const LoginPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
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
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 1.2),
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

  const LoginEmailForm({
    super.key,
    this.isSignup = false,
    this.emailController,
    this.passwordController,
    this.passwordConfirmController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LoginAuthTextField(hintText: '이메일', controller: emailController),
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

class _SocialLoginButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onPressed;
  final Color backgroundColor;

  const _SocialLoginButton({
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
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// 로그인 화면

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailLoginPressed() async {
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

    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      data: (auth) {
        if (auth != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이메일 로그인 성공')));
        }
      },
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  const Text(
                    '무나로',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '여행 기록 플랫폼',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 56),

                  LoginEmailForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                  ),

                  const SizedBox(height: 32),

                  LoginPrimaryButton(
                    text: '이메일 로그인',
                    onPressed: _onEmailLoginPressed,
                  ),

                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '간편 로그인',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialLoginButton(
                        assetPath: 'assets/icons/kakao.png',
                        backgroundColor: const Color(0xFFFEE500),
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signInWithKakaoPressed();

                          final state = ref.read(authControllerProvider);

                          state.whenOrNull(
                            data: (auth) {
                              if (auth != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('카카오 로그인 성공')),
                                );
                              }
                            },
                            error: (error, _) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 20),
                      _SocialLoginButton(
                        assetPath: 'assets/icons/google.png',
                        backgroundColor: Colors.white,
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signInWithGooglePressed();

                          final state = ref.read(authControllerProvider);

                          state.whenOrNull(
                            data: (auth) {
                              if (auth != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('구글 로그인 성공')),
                                );
                              }
                            },
                            error: (error, _) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  // 로딩 상태 표시
                  if (authState.isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('계정이 없으신가요?'),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Text('회원가입'),
                      ),
                    ],
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