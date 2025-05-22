import 'package:flutter/material.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String userId;
  final String roomId;

  MultiplayerGameScreen({required this.userId, required this.roomId});

  @override
  _MultiplayerGameScreenState createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final String wordToGuess = "FLUTTER"; // Bunu sunucudan çekeceksin
  List<String> guessedLetters = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("Room: ${widget.roomId}"),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 40),
          _buildWordDisplay(),
          _buildLetterButtons(),
        ],
      ),
    );
  }

  Widget _buildWordDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: wordToGuess.split("").map((letter) {
        bool revealed = guessedLetters.contains(letter.toUpperCase());
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Text(
            revealed ? letter : "_",
            style: const TextStyle(
              fontSize: 36,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLetterButtons() {
    const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: letters.split("").map((letter) {
          bool isGuessed = guessedLetters.contains(letter);
          bool isCorrect = wordToGuess.contains(letter);

          Color buttonColor;
          if (!isGuessed) {
            buttonColor = Colors.blueAccent;
          } else if (isCorrect) {
            buttonColor = Colors.green;
          } else {
            buttonColor = Colors.black54;
          }

          return ElevatedButton(
            onPressed: isGuessed
                ? null
                : () {
              setState(() {
                guessedLetters.add(letter);
              });

              // TODO: Buraya multiplayer güncellemeyi ve sonucu bildirme kodunu ekle
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
