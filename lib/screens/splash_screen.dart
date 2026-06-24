import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/login_layout.dart';
import '../screens/main_screen.dart';
import '../utils/jwt_utils.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _backgroundTop = Color(0xFF0C0F1A);
  static const _backgroundMid = Color(0xFF1A2156);
  static const _accentBlue = Color(0xFF4F8EFF);
  static const _accentIndigo = Color(0xFF6366F1);
  static const _accentLight = Color(0xFF818CF8);

  int _progress = 0;
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      setState(() {
        if (_progress >= 100) {
          _timer?.cancel();
          _navigateAfterSplash();
          return;
        }
        _progress += 4;
      });
    });
  }

  Future<void> _navigateAfterSplash() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    final auth = await ref.read(tokenStorageProvider).read();
    if (!mounted) return;

    if (auth != null && !JwtUtils.isExpired(auth.accessToken)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
      return;
    }

    if (auth != null) {
      await ref.read(tokenStorageProvider).clear();
    }

    _goToLogin();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_backgroundTop, _backgroundMid, _backgroundTop],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(12, _buildParticle),
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accentBlue.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accentBlue.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_accentBlue, _accentIndigo],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accentBlue.withValues(alpha: 0.5),
                          blurRadius: 48,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🏛', style: TextStyle(fontSize: 44)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '무나로',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'MUNARO',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '문화유산을 탐험하고\n역사를 게임으로 즐기세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.55),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 60,
              right: 60,
              bottom: 80,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          Container(color: Colors.white.withValues(alpha: 0.1)),
                          FractionallySizedBox(
                            widthFactor: _progress / 100,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_accentBlue, _accentLight],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '로딩 중... $_progress%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.3),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            if (_progress > 40)
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: TextButton(
                  onPressed: _goToLogin,
                  child: Text(
                    '탭하여 시작 →',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticle(int i) {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      left: size.width * ((10 + (i * 37) % 80) / 100),
      top: size.height * ((5 + (i * 29) % 90) / 100),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: _accentBlue.withValues(alpha: 0.2 + (i % 5) * 0.15),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
