import 'package:flutter/material.dart';
import 'services/session.dart';

import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'dart:js' as js;
import 'services/lean_service.dart';
import 'screens/wallet_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/gamification_screen.dart';
import 'screens/pocket_assistant_screen.dart';

void main() {
  runApp(const PFMApp());
}

class PFMApp extends StatelessWidget {
  const PFMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PFM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const _Gate(),

      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/assistant': (context) => const PocketAssistantScreen(),

        // placeholders for now:
        '/wallet': (_) => const WalletScreen(),
        '/categories': (_) => const CategoriesScreen(),
        '/gamification': (_) => const GamificationScreen(),
      },
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Session.isLoggedIn(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final loggedIn = snap.data ?? false;
        return loggedIn ? const DashboardScreen() : const WelcomeScreen();
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(title, style: const TextStyle(fontSize: 18))),
    );
  }
}
