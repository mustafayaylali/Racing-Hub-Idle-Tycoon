import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'views/main_game_screen.dart';

late final SharedPreferences sharedPrefs;

void main() async {
  // Ensure Flutter bindings are initialized before configuring system settings
  WidgetsFlutterBinding.ensureInitialized();
  sharedPrefs = await SharedPreferences.getInstance();
  
  // Restrict app orientation to portrait mode only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      const ProviderScope(
        child: PawpitalApp(),
      ),
    );
  });
}

class PawpitalApp extends StatelessWidget {
  const PawpitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cozy Derby: Idle Racing Tycoon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainGameScreen(),
    );
  }
}
