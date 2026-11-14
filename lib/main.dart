import 'package:flutter/material.dart';
import 'screens/main_shell_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'state/pos_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosUniversalApp());
}

class PosUniversalApp extends StatefulWidget {
  const PosUniversalApp({super.key});

  @override
  State<PosUniversalApp> createState() => _PosUniversalAppState();
}

class _PosUniversalAppState extends State<PosUniversalApp> {
  late final PosController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PosController()..initApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: _controller.store?.name ?? 'POS Universal',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _controller.themeMode,
          home: _buildRootScreen(),
        );
      },
    );
  }

  Widget _buildRootScreen() {
    if (_controller.isLoading && !_controller.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Memuat database POS Universal...'),
            ],
          ),
        ),
      );
    }

    if (!_controller.isInitialized) {
      return SetupWizardScreen(controller: _controller);
    }

    if (_controller.activeUser == null) {
      return PinLockScreen(controller: _controller);
    }

    return MainShellScreen(controller: _controller);
  }
}
