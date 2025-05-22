import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../user_session.dart';
import '../services/game_service.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _matchHistory = [];
  bool _isLoading = true;
  final GameService _gameService = GameService();

  @override
  void initState() {
    super.initState();
    print('ProfileScreen (screens) initState çalıştı');
    print('ProfileScreen (screens) UserSession state:');
    print('- userId: ${UserSession.userId}');
    print('- username: ${UserSession.username}');
    print('- trophies: ${UserSession.trophies}');
    print('- isLoggedIn: ${UserSession.isLoggedIn}');
    _loadMatchHistory();
    _setupGameService();
  }

  void _setupGameService() {
    _gameService.onTrophyUpdate = (data) async {
      if (mounted) {
        final winner = data['winner'];
        final loser = data['loser'];
        final isWinner = winner['userId'] == UserSession.userId;

        // Fetch latest user data from database
        try {
          final userService = UserService();
          final userData =
              await userService.getUserData(UserSession.userId ?? '');

          // Update UserSession with latest data
          await UserSession.saveUser(
            username: userData['username'] ?? '',
            userId: UserSession.userId ?? '',
            trophies: userData['trophies'] ?? 0,
            gladiator: UserSession.gladiator ?? 'assets/P1.png',
          );

          _loadMatchHistory();
          setState(() {});
        } catch (e) {
          print('Error updating user data after game: $e');
        }
      }
    };
  }

  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
  }

  Future<void> _loadMatchHistory() async {
    print('ProfileScreen (screens) loadMatchHistory çağrıldı');
    final userId = UserSession.userId;
    print('ProfileScreen (screens) Kullanıcı ID: ' + userId.toString());
    print(
        'ProfileScreen (screens) UserSession.isLoggedIn: ${UserSession.isLoggedIn}');

    if (!UserSession.isLoggedIn) {
      print('ProfileScreen (screens) Error: User is not logged in');
      setState(() => _isLoading = false);
      return;
    }

    if (userId == null || userId.isEmpty) {
      print('ProfileScreen (screens) Error: userId is empty');
      setState(() => _isLoading = false);
      return;
    }

    final uri = Uri.parse(
        "https://6mfqpxj1i0.execute-api.eu-north-1.amazonaws.com/gethistory");

    try {
      final requestBody = json.encode({"userId": userId});
      print('ProfileScreen (screens) Request body: $requestBody');
      print(
          'ProfileScreen (screens) Request headers: {"Content-Type": "application/json"}');

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: requestBody,
      );

      print('ProfileScreen (screens) Response status: ${response.statusCode}');
      print('ProfileScreen (screens) Response body: ${response.body}');
      print('ProfileScreen (screens) Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('ProfileScreen (screens) API yanıtı: ' + response.body);
        final List<dynamic> matches = data["matches"];

        setState(() {
          _matchHistory = matches
              .map<Map<String, dynamic>>((e) => {
                    "opponent": e["opponentName"],
                    "result": e["matchResult"],
                    "trophies": e["trophyCount"],
                    "date": e["playedAt"]
                  })
              .toList();
          _isLoading = false;
        });
      } else {
        final errorBody = json.decode(response.body);
        print("ProfileScreen (screens) API error: ${response.statusCode}");
        print("ProfileScreen (screens) Error response: ${errorBody['error']}");
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print("ProfileScreen (screens) Fetch error: $e");
      print("ProfileScreen (screens) Stack trace: $stackTrace");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ProfileScreen (screens) build çalıştı');
    return Stack(
      children: [
        // Arka plan
        Positioned.fill(
          child: Image.asset(
            'assets/openingscreen.webp',
            fit: BoxFit.cover,
          ),
        ),

        // İçerik
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Profile",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    shadows: [
                      Shadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 2)
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Kullanıcı bilgileri
                Card(
                  color: Colors.white.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.amber,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          UserSession.username ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(
                              '${UserSession.trophies} Trophies',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Maç geçmişi
                const Text(
                  "Match History",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _matchHistory.length,
                      itemBuilder: (context, index) {
                        final match = _matchHistory[index];
                        print('DEBUG: match result: \\${match['result']}');
                        return Card(
                          color: Colors.white.withOpacity(0.9),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              match['result'].toString().replaceAll('\\', '') ==
                                      'WIN'
                                  ? Icons.emoji_events
                                  : Icons.sports_martial_arts,
                              color: match['result']
                                          .toString()
                                          .replaceAll('\\', '') ==
                                      'WIN'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text('vs ${match['opponent']}'),
                            subtitle: Text(match['date']),
                            trailing: Text(
                              '${match['trophies']}',
                              style: TextStyle(
                                color: match['result']
                                            .toString()
                                            .replaceAll('\\', '') ==
                                        'WIN'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
