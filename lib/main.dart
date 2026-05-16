import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/pages/login_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MunaroApp(),
    ),
  );
}

class MunaroApp extends StatelessWidget {
  const MunaroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}