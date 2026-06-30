// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:treelens/core/theme/app_theme.dart';
import 'package:treelens/presentation/providers/app_provider.dart';
import 'package:treelens/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TreeLensApp());
}

class TreeLensApp extends StatelessWidget {
  const TreeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (_, provider, __) {
          return MaterialApp(
            title: 'TreeLens',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: provider.themeMode,
            home: const _SplashGate(),
          );
        },
      ),
    );
  }
}

/// Shows a brief splash while the TFLite model loads
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await context.read<AppProvider>().initModel();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.modelReady) {
      return const HomeScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.forest_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'TreeLens',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading AI model…',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
