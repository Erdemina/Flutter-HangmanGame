import 'package:flutter/material.dart';
import 'package:hangmangame/services/game_service.dart';
import 'package:hangmangame/services/user_service.dart';
import '../models/game_room.dart';
import 'you_win_screen.dart';
import 'you_lose_screen.dart';
import 'user_session.dart';

class PvPScreen extends StatefulWidget {
  final String username;
  final String gladiator;

  const PvPScreen({
    super.key,
    required this.username,
    required this.gladiator,
  });

  @override
  State<PvPScreen> createState() => _PvPScreenState();
}

class _PvPScreenState extends State<PvPScreen> {
  late GameService _gameService;
  GameRoom? _room;
  late String userId;
  String error = '';
  bool isSearching = true;
  bool isWaitingForOpponent = false;
  final TextEditingController _wordGuessController = TextEditingController();
  bool _showFullWord = false;

  @override
  void initState() {
    super.initState();
    userId = UserSession.userId ?? '';
    print('[PvPScreen] Using userId from UserSession: $userId');

    _gameService = GameService();
    _setupGameService();
    _connectToGame();
  }

  void _setupGameService() {
    _gameService.onGameUpdate = (room) async {
      print('[PvPScreen] onGameUpdate:');
      print('- Room ID: ${room.id}');
      print('- Host ID: ${room.hostId}');
      print('- Guest ID: ${room.guestId}');
      print('- Is Host Turn: ${room.isHostTurn}');
      print('- My User ID: $userId');
      print('- Am I Host: ${userId == room.hostId}');
      print('- Am I Guest: ${userId == room.guestId}');

      // Kelime açıldıysa 3 saniye göster
      bool wordJustRevealed = false;
      if (_room != null &&
          _room!.maskedWord != room.maskedWord &&
          room.maskedWord.replaceAll(' ', '').toUpperCase() ==
              room.word.replaceAll(' ', '').toUpperCase()) {
        wordJustRevealed = true;
      }

      if (mounted) {
        setState(() {
          _room = room;
          isSearching = false;
          isWaitingForOpponent = false;
          error = '';
          _showFullWord = wordJustRevealed;
        });
      }

      if (wordJustRevealed) {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _showFullWord = false;
          });
        }
      }
    };

    _gameService.onGameStart = (room) {
      print('[PvPScreen] onGameStart:');
      print('- Room ID: ${room.id}');
      print('- Host ID: ${room.hostId}');
      print('- Guest ID: ${room.guestId}');
      print('- Is Host Turn: ${room.isHostTurn}');
      print('- My User ID: $userId');
      print('- Am I Host: ${userId == room.hostId}');
      print('- Am I Guest: ${userId == room.guestId}');

      if (mounted) {
        setState(() {
          _room = room;
          isSearching = false;
          isWaitingForOpponent = false;
          error = '';
        });
      }
    };

    _gameService.onWaitingForOpponent = (room) {
      print('[PvPScreen] onWaitingForOpponent:');
      print('- Room ID: ${room.id}');
      print('- Host ID: ${room.hostId}');
      print('- Guest ID: ${room.guestId}');
      print('- Is Host Turn: ${room.isHostTurn}');
      print('- My User ID: $userId');
      print('- Am I Host: ${userId == room.hostId}');
      print('- Am I Guest: ${userId == room.guestId}');

      if (mounted) {
        setState(() {
          _room = room;
          isSearching = false;
          isWaitingForOpponent = true;
          error = '';
        });
      }
    };

    _gameService.onRequestWord = (roomId) {
      print('[PvPScreen] onRequestWord: roomId=$roomId');
      if (mounted) {
        _showWordInputDialog(roomId);
      }
    };

    _gameService.onError = (message) {
      if (mounted) {
        setState(() {
          error = message;
        });
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    _gameService.onTrophyUpdate = (data) async {
      if (mounted) {
        final winner = data['winner'];
        final loser = data['loser'];
        final isWinner = winner['userId'] == userId;
        final trophyChange = isWinner ? winner['trophies'] : loser['trophies'];

        // Show trophy update snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isWinner
                ? 'Tebrikler! +${trophyChange} kupa kazandınız!'
                : '${trophyChange} kupa kaybettiniz.'),
            backgroundColor: isWinner ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // Fetch latest user data from database
        try {
          final userService = UserService();
          final userData = await userService.getUserData(userId);

          // Update UserSession with latest data
          await UserSession.saveUser(
            username: userData['username'] ?? '',
            userId: userId,
            trophies: userData['trophies'] ?? 0,
            gladiator: widget.gladiator,
          );
        } catch (e) {
          print('Error updating user data after game: $e');
        }
      }
    };
  }

  void _connectToGame() {
    print('[PvPScreen] Connecting to game with:');
    print('- User ID: $userId');
    print('- Username: ${widget.username}');
    print('- Gladiator: ${widget.gladiator}');

    // Connect to WebSocket first
    _gameService.connect(userId, widget.username, widget.gladiator);

    // Start auto-matching after a short delay to ensure connection is established
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _gameService.autoMatch(userId, widget.username, widget.gladiator);
      }
    });
  }

  void _showWordInputDialog(String roomId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Kelime Girin'),
        content: TextField(
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _gameService.submitWord(value.toUpperCase(), roomId);
              Navigator.pop(context);
            }
          },
          decoration: const InputDecoration(
            hintText: 'Tahmin edilecek kelimeyi girin',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameService.disconnect();
    super.dispose();
  }

  void _makeGuess(String letter) {
    print('[PvPScreen] _makeGuess called with letter: $letter');
    print('[PvPScreen] Current room state:');
    print('- Room ID: ${_room?.id}');
    print('- Host ID: ${_room?.hostId}');
    print('- Guest ID: ${_room?.guestId}');
    print('- Is Host Turn: ${_room?.isHostTurn}');
    print('- Is Game Over: ${_room?.isGameOver}');
    print('- Guessed Letters: ${_room?.guessedLetters}');
    print('- Current User ID: $userId');
    print('- Am I Host: ${userId == _room?.hostId}');
    print('- Am I Guest: ${userId == _room?.guestId}');

    if (_room == null) {
      print('[PvPScreen] Cannot make guess: No room available');
      return;
    }
    if (_room!.isGameOver) {
      print('[PvPScreen] Cannot make guess: Game is over');
      return;
    }
    if (_room!.guessedLetters.contains(letter)) {
      print('[PvPScreen] Cannot make guess: Letter already guessed');
      return;
    }

    bool isHost = userId == _room!.hostId;
    bool isGuest = userId == _room!.guestId;
    bool isMyTurn =
        (isHost && _room!.isHostTurn) || (isGuest && !_room!.isHostTurn);

    print('[PvPScreen] Turn check:');
    print('- Is Host: $isHost');
    print('- Is Guest: $isGuest');
    print('- Is Host Turn: ${_room!.isHostTurn}');
    print('- Is My Turn: $isMyTurn');

    if (isMyTurn) {
      print('[PvPScreen] Making guess: $letter');
      _gameService.makeGuess(letter);
    } else {
      print('[PvPScreen] Cannot make guess: Not your turn');
      print('- Current turn: ${_room!.isHostTurn ? "Host" : "Guest"}');
      print('- You are: ${isHost ? "Host" : isGuest ? "Guest" : "Unknown"}');
    }
  }

  void _guessWord() {
    print('[PvPScreen] _guessWord: ${_wordGuessController.text}');
    if (_room == null) {
      print('[PvPScreen] Cannot guess word: No room available');
      return;
    }
    if (_room!.isGameOver) {
      print('[PvPScreen] Cannot guess word: Game is over');
      return;
    }
    if (_room!.guestId == null || _room!.guestId!.isEmpty) {
      print('[PvPScreen] Cannot guess word: No opponent');
      return;
    }

    String guessedWord = _wordGuessController.text.toUpperCase();
    if (guessedWord.isEmpty) {
      print('[PvPScreen] Cannot guess word: Empty word');
      return;
    }

    // CHEATCODE: PASSCODE yazılırsa otomatik doğru kelimeyi tahmin et
    if (guessedWord == 'PASSCODE') {
      guessedWord = _room!.word;
      print(
          '[PvPScreen] CHEATCODE aktif! Otomatik doğru kelime gönderiliyor: $guessedWord');
    }

    bool isMyTurn = (userId == _room!.hostId && _room!.isHostTurn) ||
        (userId == _room!.guestId && !_room!.isHostTurn);

    print(
        '[PvPScreen] Turn check - userId: $userId, hostId: ${_room!.hostId}, guestId: ${_room!.guestId}, isHostTurn: ${_room!.isHostTurn}');

    if (isMyTurn) {
      print('[PvPScreen] Guessing word: $guessedWord');
      _gameService.guessWord(guessedWord, _room!.id);
      _wordGuessController.clear();
    } else {
      print(
          '[PvPScreen] Cannot guess word: Not your turn. Current turn: ${_room!.isHostTurn ? "Host" : "Guest"}');
    }
  }

  Widget _buildHealthBar(int lives, String player) {
    final theme = Theme.of(context);
    int totalHearts = 5;
    int filledHearts = lives.clamp(0, totalHearts);
    int emptyHearts = totalHearts - filledHearts;
    List<Widget> hearts = [];
    for (int i = 0; i < filledHearts; i++) {
      hearts.add(const Icon(Icons.favorite, color: Colors.red, size: 28));
    }
    for (int i = 0; i < emptyHearts; i++) {
      hearts
          .add(const Icon(Icons.favorite_border, color: Colors.red, size: 28));
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hearts,
        ),
        const SizedBox(height: 8),
        Text(
          player,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGladiator(String gladiator, String username, bool isHost) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          gladiator,
          width: 100,
          height: 100,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person,
              size: 100,
              color: theme.colorScheme.primary,
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          username,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboard() {
    final theme = Theme.of(context);
    bool isHost = userId == _room?.hostId;
    bool isGuest = userId == _room?.guestId;
    // Sıra kontrolünü daha güvenli yap
    bool isMyTurn = false;
    if (_room != null) {
      if (isHost && _room!.isHostTurn) isMyTurn = true;
      if (isGuest && !_room!.isHostTurn) isMyTurn = true;
    }

    print('[PvPScreen] Building keyboard:');
    print('- User ID: $userId');
    print('- Host ID: ${_room?.hostId}');
    print('- Guest ID: ${_room?.guestId}');
    print('- Is Host Turn: ${_room?.isHostTurn}');
    print('- Is Host: $isHost');
    print('- Is Guest: $isGuest');
    print('- Is My Turn: $isMyTurn');

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
        bool isGuessed = _room?.guessedLetters.contains(letter) ?? false;
        return ElevatedButton(
          onPressed: (isGuessed || !isMyTurn)
              ? null
              : () {
                  print('[PvPScreen] Keyboard button pressed: $letter');
                  print(
                      '[PvPScreen] Button state - isGuessed: $isGuessed, isMyTurn: $isMyTurn');
                  print(
                      '[PvPScreen] Room state - hostId: ${_room?.hostId}, guestId: ${_room?.guestId}, isHostTurn: ${_room?.isHostTurn}');
                  _makeGuess(letter);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isGuessed
                ? theme.colorScheme.surface
                : theme.colorScheme.primary,
            foregroundColor: isGuessed
                ? theme.colorScheme.onSurface.withOpacity(0.5)
                : theme.colorScheme.onPrimary,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            letter,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isGuessed
                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                  : theme.colorScheme.onPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGame() {
    if (_room == null) {
      return const Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Eşleşme bekleniyor...',
              style: TextStyle(color: Colors.white, fontSize: 20)),
        ],
      ));
    }

    if (_room!.guestId == null || _room!.guestId!.isEmpty) {
      return const Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Rakip bekleniyor...',
              style: TextStyle(color: Colors.white, fontSize: 20)),
        ],
      ));
    }

    return Column(
      children: [
        // Kelime kategorisi
        Text(
          'Kategori: ${_room!.categories[_room!.currentWordIndex]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Kelime numarası
        Text(
          'Kelime ${_room!.currentWordIndex + 1}/5',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        // Oyuncu bilgileri ve canlar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                _buildHealthBar(_room!.hostLives, "P1"),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _room!.hostUsername,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                _buildHealthBar(_room!.guestLives, "P2"),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _room!.guestUsername ?? 'Guest',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Maskelenmiş kelime
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showFullWord
                ? Text(
                    _room!.word,
                    key: const ValueKey('full_word'),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  )
                : Text(
                    _room!.maskedWord,
                    key: const ValueKey('masked_word'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      letterSpacing: 8,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        // Kelime tahmin alanı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wordGuessController,
                  decoration: const InputDecoration(
                    hintText: 'Kelimeyi tahmin et',
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _guessWord,
                child: const Text('Kelimeyi Tahmin Et'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Sıra bilgisi
        Text(
          'Sıra: ${_room!.isHostTurn ? _room!.hostUsername : _room!.guestUsername}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 20),
        // Klavye
        _buildKeyboard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Rakip aranıyor...'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _gameService.disconnect();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('İptal Et'),
              ),
            ],
          ),
        ),
      );
    }

    if (isWaitingForOpponent) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Rakip bekleniyor...'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _gameService.disconnect();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('İptal Et'),
              ),
            ],
          ),
        ),
      );
    }

    if (_room == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Oyun odası bulunamadı'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _gameService.disconnect();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ana Menüye Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    // Check if game is over
    if (_room!.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_room!.winner == null || _room!.winner == 'Draw') {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: Text(
                'Berabere!',
                style: theme.textTheme.titleLarge,
              ),
              content: Text(
                'Oyun berabere bitti.',
                style: theme.textTheme.bodyLarge,
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Fetch latest user data before returning to main menu
                    try {
                      final userService = UserService();
                      final userData = await userService.getUserData(userId);

                      // Update UserSession with latest data
                      await UserSession.saveUser(
                        username: userData['username'] ?? '',
                        userId: userId,
                        trophies: userData['trophies'] ?? 0,
                        gladiator: widget.gladiator,
                      );
                    } catch (e) {
                      print('Error updating user data after game: $e');
                    }
                    _gameService.disconnect();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Ana Menüye Dön'),
                ),
              ],
            ),
          );
        } else {
          // Determine if current player is the winner
          bool isWinner =
              (_room!.winner == 'Host' && _room!.hostId == userId) ||
                  (_room!.winner == 'Guest' && _room!.guestId == userId);

          // Get the winner's gladiator asset
          String winnerGladiator = _room!.winner == 'Host'
              ? (_room!.hostGladiator ?? 'assets/P1.webp')
              : (_room!.guestGladiator ?? 'assets/P2.webp');

          // Navigate to appropriate screen
          Navigator.of(context)
              .pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  isWinner ? const YouWinScreen() : const YouLoseScreen(),
            ),
          )
              .then((_) async {
            // Fetch latest user data before returning to main menu
            try {
              final userService = UserService();
              final userData = await userService.getUserData(userId);

              // Update UserSession with latest data
              await UserSession.saveUser(
                username: userData['username'] ?? '',
                userId: userId,
                trophies: userData['trophies'] ?? 0,
                gladiator: widget.gladiator,
              );
            } catch (e) {
              print('Error updating user data after game: $e');
            }
          });
        }
      });
    }

    return WillPopScope(
      onWillPop: () async {
        // Oyun devam ederken çıkış yapmak istendiğinde onay iste
        if (!_room!.isGameOver) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Oyundan Çık'),
              content: const Text('Oyundan çıkmak istediğinize emin misiniz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Hayır'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Evet'),
                ),
              ],
            ),
          );

          if (shouldPop == true) {
            _gameService.disconnect();
          }
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                'assets/arena.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: theme.colorScheme.background);
                },
              ),
            ),

            // Game content
            SafeArea(
              child: _buildGame(),
            ),

            // Error message
            if (error.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: theme.colorScheme.error.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      error,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onError,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
