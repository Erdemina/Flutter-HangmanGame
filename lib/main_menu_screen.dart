import 'package:flutter/material.dart';
import 'package:hangmangame/services/user_service.dart';
import 'user_session.dart';
import 'pvp_screen.dart';
import 'profile_screen.dart';
import 'main.dart'; // RouteObserver erişimi için
import 'opening_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with RouteAware {
  final UserService _userService = UserService();
  bool _isLoading = true;
  String _username = '';
  int _trophies = 0;
  String _gladiator = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Başka bir ekrandan ana menüye dönünce çağrılır
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _userService
          .getUserData(UserSession.userId != null ? UserSession.userId! : '');
      if (mounted) {
        setState(() {
          _username = userData['username'];
          _trophies = userData['trophies'];
          _gladiator = userData['gladiator'];
          _isLoading = false;
        });
        // UserSession'ı da güncelle
        await UserSession.saveUser(
          username: userData['username'] ?? '',
          userId: UserSession.userId != null ? UserSession.userId! : '',
          trophies: userData['trophies'] ?? 0,
          gladiator: userData['gladiator'] ?? 'assets/P1.png',
        );
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı bilgileri yüklenemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/menu_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: theme.colorScheme.background);
              },
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User info
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Card(
                      color: Colors.white.withOpacity(0.9),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Image.asset(
                              _gladiator,
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.person, size: 60);
                              },
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _username,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Menu buttons
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PvPScreen(
                            username: _username,
                            gladiator: _gladiator,
                          ),
                        ),
                      ).then((_) =>
                          _loadUserData()); // Refresh user data after returning
                    },
                    child: const Text('PvP Oyna'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      ).then((_) =>
                          _loadUserData()); // Refresh user data after returning
                    },
                    child: const Text('Profil'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Çıkış işlemi
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Çıkış Yap'),
                          content: const Text(
                              'Çıkış yapmak istediğinize emin misiniz?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Hayır'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                UserSession.logout().then((_) {
                                  Navigator.of(context)
                                      .popUntil((route) => false);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const OpeningScreen()),
                                  );
                                });
                              },
                              child: const Text('Evet'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Çıkış Yap'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
