import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart' as kakao_map;
import 'layouts/login_layout.dart';
import 'layouts/signup_layout.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // 카카오 SDK 초기화화
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
  );

  // 카카오맵 SDK 초기화화
  kakao_map.AuthRepository.initialize(
    appKey: dotenv.env['KAKAO_JAVASCRIPT_KEY'] ?? '',
    baseUrl: 'http://localhost',
  );

  runApp(
    // ProviderScope로 Riverpod(상태관리) 켜고 앱 실행
    const ProviderScope(
      child: MunaroApp(),
    ),
  );
}

class MunaroApp extends ConsumerWidget {
  const MunaroApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(sessionExpiredProvider, (previous, next) {
      if (!next) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionExpiredProvider.notifier).state = false;
        ref.read(authControllerProvider.notifier).logout();

        final navigator = navigatorKey.currentState;
        if (navigator == null) return;

        navigator.pushNamedAndRemoveUntil('/login', (_) => false);

        final messengerContext = navigatorKey.currentContext;
        if (messengerContext != null) {
          ScaffoldMessenger.of(messengerContext).showSnackBar(
            const SnackBar(
              content: Text('로그인이 만료되었습니다. 다시 로그인해 주세요.'),
            ),
          );
        }
      });
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '무나로',
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginPage(),
        '/email-login': (_) => const EmailLoginPage(),
        '/signup': (_) => const SignupPage(),
        '/profile-setup': (_) => const ProfileSetupScreen(),
      },
    );
  }
}