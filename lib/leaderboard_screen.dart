import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> players = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    final uri = Uri.parse(
        "https://4knen6mrs1.execute-api.eu-north-1.amazonaws.com/leaderboard");

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          players = data
              .map<Map<String, dynamic>>(
                  (e) => {"username": e["username"], "trophy": e["trophies"]})
              .toList();
          isLoading = false;
        });
      } else {
        print("API error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Connection error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/openingscreen.webp',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Leaderboard",
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
                ),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        )
                      : players.isEmpty
                          ? const Center(
                              child: Text("No data available",
                                  style: TextStyle(color: Colors.white)),
                            )
                          : ListView.builder(
                              itemCount: players.length,
                              itemBuilder: (context, index) {
                                final player = players[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 6),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.person,
                                          color: Colors.amber),
                                      title: Text(
                                        player['username'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.emoji_events,
                                              color: Colors.amber, size: 20),
                                          const SizedBox(width: 4),
                                          Text(player['trophy'].toString()),
                                        ],
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
        ],
      ),
    );
  }
}
