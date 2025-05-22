import 'package:flutter/material.dart';
import 'opening_screen.dart';
import 'pvp_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'home_screen.dart';
import 'user_session.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hata yakalama
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(details.toString());
  };

  // Kullanıcı oturumunu yükle
  try {
    await UserSession.loadUser();
  } catch (e) {
    debugPrint('Error loading user session: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hangman Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: UserSession.isLoggedIn
          ? HomeScreen(
              username: UserSession.username ?? '',
              trophies: UserSession.trophies,
              gladiator: UserSession.gladiator ?? 'assets/P1.webp',
            )
          : const OpeningScreen(),
      routes: {
        '/home': (context) => HomeScreen(
              username: UserSession.username ?? '',
              trophies: UserSession.trophies,
              gladiator: UserSession.gladiator ?? 'assets/P1.webp',
            ),
        '/profile': (context) => const ProfileScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      navigatorObservers: [routeObserver],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}
