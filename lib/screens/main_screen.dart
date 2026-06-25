import 'package:flutter/material.dart';
import 'ranking_screen.dart';
import 'mypage_screen.dart';
import 'home_screen.dart';
import 'quiz_sccreen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavTab(icon: '🗺', label: '홈'),
    _NavTab(icon: '📋', label: '기록'),
    _NavTab(icon: '🏆', label: '랭킹'),
    _NavTab(icon: '👤', label: '마이'),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          onNavigateToTab: (tabIndex) => setState(() => _currentIndex = tabIndex),
        );
      case 1:
        return const QuizHistoryScreen();
      case 2:
        return const RankingScreen();
      case 3:
        return MyPageScreen(
          onNavigateToTab: (tabIndex) => setState(() => _currentIndex = tabIndex),
        );
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(_currentIndex),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 60,
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  final isActive = _currentIndex == index;
                  return Expanded(
                    child: _BottomNavItem(
                      icon: tab.icon,
                      label: tab.label,
                      isActive: isActive,
                      onTap: () => setState(() => _currentIndex = index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String icon;
  final String label;

  const _NavTab({required this.icon, required this.label});
}

class _BottomNavItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (isActive)
              Positioned(
                top: 0,
                child: Container(
                  width: 28,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4F8EFF),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22, height: 1.1)),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive
                          ? const Color(0xFF4F8EFF)
                          : const Color(0xFF9CA3AF),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
