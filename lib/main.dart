import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'core/services/geofence_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'screens/home_screen.dart';

// ─── Background entry point (must be top-level) ───────────────────────────────
@pragma('vm:entry-point')
void startForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(GeofenceTaskHandler());
}

// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode (utility app)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  await StorageService.instance.init();
  await NotificationService.instance.init();
  GeofenceService.instance.initForegroundTask();

  // Initialize foreground task communication port BEFORE runApp
  FlutterForegroundTask.initCommunicationPort();

  runApp(const StaffTransportApp());
}

class StaffTransportApp extends StatelessWidget {
  const StaffTransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MaterialApp(
        title: 'Staff Transport Reminder',
        debugShowCheckedModeBanner: false,

        // ─── Material 3 Theme ───────────────────────────────────────────
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,

        // ─── Routes ────────────────────────────────────────────────────
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
        },

        // Handle deep link from notification button
        onGenerateRoute: (settings) {
          if (settings.name == '/active-trip') {
            // Load active trip from storage and navigate
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0), // Deep blue
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,

      // Typography
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        titleSmall: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(height: 1.5),
        bodyMedium: TextStyle(height: 1.4),
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),

      // Scaffold
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F9FF),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1E1E30) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Chips
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primary,
        backgroundColor: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}
