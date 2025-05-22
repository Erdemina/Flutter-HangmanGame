import 'package:flutter/material.dart';
import 'pvp_screen.dart';
import 'user_session.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final int trophies;
  final String gladiator;

  const HomeScreen({
    super.key,
    required this.username,
    required this.trophies,
    required this.gladiator,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _username;
  late int _trophies;
  late String _gladiator;

  @override
  void initState() {
    super.initState();
    _username = widget.username;
    _trophies = widget.trophies;
    _gladiator = widget.gladiator;
    // UserSession'ı güncelle
    UserSession.saveUser(
      username: _username,
      userId: UserSession.userId ?? '',
      trophies: _trophies,
      gladiator: _gladiator,
    );
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username ||
        oldWidget.trophies != widget.trophies ||
        oldWidget.gladiator != widget.gladiator) {
      setState(() {
        _username = widget.username;
        _trophies = widget.trophies;
        _gladiator = widget.gladiator;
      });
      // UserSession'ı güncelle
      UserSession.saveUser(
        username: _username,
        userId: UserSession.userId ?? '',
        trophies: _trophies,
        gladiator: _gladiator,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Arka plan
          Positioned.fill(
            child: Image.asset(
              'assets/openingscreen.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: theme.colorScheme.background);
              },
            ),
          ),

          // İçerik
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Üst Bilgi: Kullanıcı adı ve kupa
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: theme.colorScheme.onBackground),
                      const SizedBox(width: 8),
                      Text(
                        _username,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Oyun modu
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PvPScreen(
                              username: _username,
                              gladiator: _gladiator,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: theme.colorScheme.primary.withOpacity(0.1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/Start.png',
                                width: 120,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.play_circle_fill,
                                    size: 120,
                                    color: theme.colorScheme.primary,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Çok Oyunculu",
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onBackground,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Alt Menü
                Container(
                  margin: const EdgeInsets.only(bottom: 20.0),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Profile
                      IconButton(
                        icon: Icon(Icons.person,
                            color: theme.colorScheme.onBackground),
                        iconSize: 32,
                        onPressed: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                      ),

                      // Leaderboard
                      IconButton(
                        icon: Icon(Icons.leaderboard,
                            color: theme.colorScheme.onBackground),
                        iconSize: 32,
                        onPressed: () {
                          Navigator.pushNamed(context, '/leaderboard');
                        },
                      ),

                      // Settings
                      IconButton(
                        icon: Icon(Icons.settings,
                            color: theme.colorScheme.onBackground),
                        iconSize: 32,
                        onPressed: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
