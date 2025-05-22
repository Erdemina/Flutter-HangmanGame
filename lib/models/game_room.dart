import 'package:uuid/uuid.dart';

class GameRoom {
  final String id;
  final String hostId;
  final String? guestId;
  final String hostUsername;
  final String? guestUsername;
  final String hostGladiator;
  final String? guestGladiator;
  final bool isHostTurn;
  final int hostLives;
  final int guestLives;
  final String word;
  final String maskedWord;
  final List<String> guessedLetters;
  final bool isGameOver;
  final String? winner;
  final int currentWordIndex;
  final List<String> words;
  final List<String> categories;

  GameRoom({
    required this.id,
    required this.hostId,
    this.guestId,
    required this.hostUsername,
    this.guestUsername,
    required this.hostGladiator,
    this.guestGladiator,
    required this.isHostTurn,
    required this.hostLives,
    required this.guestLives,
    required this.word,
    required this.maskedWord,
    required this.guessedLetters,
    required this.isGameOver,
    this.winner,
    required this.currentWordIndex,
    required this.words,
    required this.categories,
  });

  GameRoom copyWith({
    String? hostId,
    String? guestId,
    String? hostUsername,
    String? guestUsername,
    String? hostGladiator,
    String? guestGladiator,
    String? word,
    String? maskedWord,
    List<String>? guessedLetters,
    int? hostLives,
    int? guestLives,
    bool? isHostTurn,
    bool? isGameOver,
    String? winner,
    int? currentWordIndex,
    List<String>? words,
    List<String>? categories,
  }) {
    return GameRoom(
      id: id,
      hostId: hostId ?? this.hostId,
      guestId: guestId ?? this.guestId,
      hostUsername: hostUsername ?? this.hostUsername,
      guestUsername: guestUsername ?? this.guestUsername,
      hostGladiator: hostGladiator ?? this.hostGladiator,
      guestGladiator: guestGladiator ?? this.guestGladiator,
      isHostTurn: isHostTurn ?? this.isHostTurn,
      hostLives: hostLives ?? this.hostLives,
      guestLives: guestLives ?? this.guestLives,
      word: word ?? this.word,
      maskedWord: maskedWord ?? this.maskedWord,
      guessedLetters: guessedLetters ?? this.guessedLetters,
      isGameOver: isGameOver ?? this.isGameOver,
      winner: winner ?? this.winner,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      words: words ?? this.words,
      categories: categories ?? this.categories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'guestId': guestId,
      'hostUsername': hostUsername,
      'guestUsername': guestUsername,
      'hostGladiator': hostGladiator,
      'guestGladiator': guestGladiator,
      'isHostTurn': isHostTurn,
      'hostLives': hostLives,
      'guestLives': guestLives,
      'word': word,
      'maskedWord': maskedWord,
      'guessedLetters': guessedLetters,
      'isGameOver': isGameOver,
      'winner': winner,
      'currentWordIndex': currentWordIndex,
      'words': words,
      'categories': categories,
    };
  }

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'],
      hostId: json['hostId'],
      guestId: json['guestId'],
      hostUsername: json['hostUsername'],
      guestUsername: json['guestUsername'],
      hostGladiator: json['hostGladiator'],
      guestGladiator: json['guestGladiator'],
      isHostTurn: json['isHostTurn'],
      hostLives: json['hostLives'],
      guestLives: json['guestLives'],
      word: json['word'],
      maskedWord: json['maskedWord'],
      guessedLetters: List<String>.from(json['guessedLetters']),
      isGameOver: json['isGameOver'],
      winner: json['winner'],
      currentWordIndex: json['currentWordIndex'],
      words: List<String>.from(json['words']),
      categories: List<String>.from(json['categories']),
    );
  }
}
