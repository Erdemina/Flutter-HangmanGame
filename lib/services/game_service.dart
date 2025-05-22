import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;
import '../models/game_room.dart';

class GameService {
  WebSocketChannel? _channel;
  final String _serverUrl = 'ws://10.0.2.2:8080'; // Local development server
  String? _userId;
  String? _username;
  String? _gladiator;
  GameRoom? _currentRoom;
  Function(GameRoom)? onGameUpdate;
  Function(String)? onError;
  Function(GameRoom)? onGameStart;
  Function(GameRoom)? onWaitingForOpponent;
  Function(String)? onRequestWord;
  Function(Map<String, dynamic>)? onTrophyUpdate;

  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);

  void connect(String userId, String username, String gladiator) {
    print('[GameService] Connecting to WebSocket...');
    print('[GameService] Connection details:');
    print('- User ID: $userId');
    print('- Username: $username');
    print('- Gladiator: $gladiator');

    _userId = userId;
    _username = username;
    _gladiator = gladiator;
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _listenToMessages();
      _isReconnecting = false;
      _reconnectAttempts = 0;
      print('[GameService] WebSocket connected successfully');
    } catch (e) {
      print('[GameService] WebSocket connection error: $e');
      _handleConnectionError();
    }
  }

  void _handleConnectionError() {
    if (!_isReconnecting && _reconnectAttempts < maxReconnectAttempts) {
      _isReconnecting = true;
      _reconnectAttempts++;
      print(
          '[GameService] Attempting to reconnect (${_reconnectAttempts}/$maxReconnectAttempts)...');

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(reconnectDelay, () {
        _isReconnecting = false;
        _connectWebSocket();
      });
    } else {
      onError?.call('Connection failed after $maxReconnectAttempts attempts');
    }
  }

  void _listenToMessages() {
    _channel?.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          print('[GameService] Received message: $data');

          switch (data['type']) {
            case 'gameUpdate':
              if (data['room'] != null) {
                final room = GameRoom.fromJson(data['room']);
                handleGameUpdate(room);
              }
              break;
            case 'gameStart':
              _currentRoom = GameRoom.fromJson(data['room']);
              print('[GameService] Game start received:');
              print('- Room ID: ${_currentRoom?.id}');
              print('- Host ID: ${_currentRoom?.hostId}');
              print('- Guest ID: ${_currentRoom?.guestId}');
              print('- Is Host Turn: ${_currentRoom?.isHostTurn}');
              print('- Current User ID: $_userId');
              onGameStart?.call(_currentRoom!);
              break;
            case 'waitingForOpponent':
              _currentRoom = GameRoom.fromJson(data['room']);
              print('[GameService] Waiting for opponent:');
              print('- Room ID: ${_currentRoom?.id}');
              print('- Host ID: ${_currentRoom?.hostId}');
              print('- Guest ID: ${_currentRoom?.guestId}');
              print('- Is Host Turn: ${_currentRoom?.isHostTurn}');
              print('- Current User ID: $_userId');
              onWaitingForOpponent?.call(_currentRoom!);
              break;
            case 'requestWord':
              print(
                  '[GameService] Word request received for room: ${data['roomId']}');
              onRequestWord?.call(data['roomId']);
              break;
            case 'error':
              print('[GameService] Error received: ${data['message']}');
              onError?.call(data['message']);
              break;
            case 'trophyUpdate':
              if (onTrophyUpdate != null) {
                onTrophyUpdate!(data);
              }
              break;
            default:
              print('[GameService] Unknown message type: ${data['type']}');
              onError?.call('Unknown message type: ${data['type']}');
          }
        } catch (e) {
          print('[GameService] Error processing message: $e');
          onError?.call('Invalid message format: $e');
        }
      },
      onError: (error) {
        print('[GameService] WebSocket error: $error');
        _handleConnectionError();
      },
      onDone: () {
        print('[GameService] WebSocket connection closed');
        _handleConnectionError();
      },
    );
  }

  void createRoom(String word) {
    if (_channel == null ||
        _userId == null ||
        _username == null ||
        _gladiator == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'createRoom',
      'userId': _userId,
      'username': _username,
      'gladiator': _gladiator,
      'word': word,
    }));
  }

  void joinRoom(String roomId) {
    if (_channel == null ||
        _userId == null ||
        _username == null ||
        _gladiator == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'joinRoom',
      'userId': _userId,
      'username': _username,
      'gladiator': _gladiator,
      'roomId': roomId,
    }));
  }

  void makeGuess(String letter) {
    if (_channel == null || _userId == null || _currentRoom == null) {
      print('[GameService] makeGuess failed: Missing required data');
      return;
    }

    print('[GameService] Attempting to make guess:');
    print('- Letter: $letter');
    print('- Room ID: ${_currentRoom!.id}');
    print('- User ID: $_userId');
    print('- Host ID: ${_currentRoom!.hostId}');
    print('- Guest ID: ${_currentRoom!.guestId}');
    print('- Is Host Turn: ${_currentRoom!.isHostTurn}');
    print('- Am I Host: ${_userId == _currentRoom!.hostId}');
    print('- Am I Guest: ${_userId == _currentRoom!.guestId}');

    bool isHost = _userId == _currentRoom!.hostId;
    bool isGuest = _userId == _currentRoom!.guestId;
    bool isMyTurn = (isHost && _currentRoom!.isHostTurn) ||
        (isGuest && !_currentRoom!.isHostTurn);

    if (!isMyTurn) {
      print('[GameService] Cannot make guess: Not your turn');
      print('- Current turn: ${_currentRoom!.isHostTurn ? "Host" : "Guest"}');
      print('- You are: ${isHost ? "Host" : isGuest ? "Guest" : "Unknown"}');
      return;
    }

    print('[GameService] Sending guess: $letter');
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'makeGuess',
        'userId': _userId,
        'roomId': _currentRoom!.id,
        'letter': letter,
        'isWordGuess': false,
      }));
    } catch (e) {
      print('[GameService] Error sending guess: $e');
      _handleConnectionError();
    }
  }

  void disconnect() {
    print('[GameService] Disconnecting...');
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _currentRoom = null;
    _isReconnecting = false;
    _reconnectAttempts = 0;
  }

  Future<void> autoMatch(
      String userId, String username, String gladiator) async {
    try {
      print('[GameService] Starting auto match...');
      print('[GameService] Auto match details:');
      print('- User ID: $userId');
      print('- Username: $username');
      print('- Gladiator: $gladiator');

      final response = await http.get(
        Uri.parse(
            'https://rhzggje2o3.execute-api.eu-north-1.amazonaws.com/words'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> wordsData = json.decode(response.body);
        final List<String> words =
            wordsData.map((w) => w['word'].toString()).toList();
        final List<String> categories =
            wordsData.map((w) => w['category'].toString()).toList();

        print(
            '[GameService] Words fetched successfully, sending auto match request');
        _channel!.sink.add(json.encode({
          'type': 'autoMatch',
          'userId': userId,
          'username': username,
          'gladiator': gladiator,
          'words': words,
          'categories': categories,
        }));
      } else {
        print('[GameService] Failed to fetch words: ${response.statusCode}');
        onError?.call('Failed to fetch words');
      }
    } catch (e) {
      print('[GameService] Auto match error: $e');
      onError?.call(e.toString());
    }
  }

  void nextRound() {
    if (_channel == null || _userId == null || _currentRoom == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'nextRound',
      'userId': _userId,
      'roomId': _currentRoom!.id,
    }));
  }

  void endGame() {
    if (_channel == null || _userId == null || _currentRoom == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'endGame',
      'userId': _userId,
      'roomId': _currentRoom!.id,
    }));
  }

  void submitWord(String word, String roomId) {
    if (_channel == null) {
      print('[GameService] submitWord failed: No WebSocket connection');
      return;
    }
    print('[GameService] Submitting word: $word for room: $roomId');
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'wordInput',
        'roomId': roomId,
        'word': word,
      }));
    } catch (e) {
      print('[GameService] Error submitting word: $e');
      _handleConnectionError();
    }
  }

  void guessWord(String word, String roomId) {
    if (_channel == null || _userId == null || _currentRoom == null) {
      print('[GameService] guessWord failed: Missing required data');
      return;
    }

    bool isMyTurn =
        (_userId == _currentRoom!.hostId && _currentRoom!.isHostTurn) ||
            (_userId == _currentRoom!.guestId && !_currentRoom!.isHostTurn);

    if (!isMyTurn) {
      print(
          '[GameService] Cannot guess word: Not your turn. Current turn: ${_currentRoom!.isHostTurn ? "Host" : "Guest"}');
      return;
    }

    print(
        '[GameService] Sending word guess: $word, roomId: $roomId, userId: $_userId, isHostTurn: ${_currentRoom!.isHostTurn}');
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'makeGuess',
        'userId': _userId,
        'roomId': roomId,
        'word': word,
        'isWordGuess': true,
      }));
    } catch (e) {
      print('[GameService] Error sending word guess: $e');
      _handleConnectionError();
    }
  }

  // Her game update'de _currentRoom'u güncelle
  void handleGameUpdate(GameRoom room) {
    _currentRoom = room;
    if (onGameUpdate != null) onGameUpdate!(room);
  }

  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
  }
}
