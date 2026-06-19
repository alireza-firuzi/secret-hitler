import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FirebaseManager {
  static bool _firebaseInitialized = false;
  static bool get isFirebaseAvailable => _firebaseInitialized;

  static WebSocketChannel? _channel;
  static final StreamController<Map<String, dynamic>?> _gameStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();
  static final StreamController<String> _errorStreamController =
      StreamController<String>.broadcast();
  static Stream<String> get errorStream => _errorStreamController.stream;

  // Maps to match request completers for getPrivateRole
  static final Map<String, Completer<Map<String, dynamic>?>> _privateRoleCompleters = {};

  static String get _wsUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.host != 'localhost' && uri.host != '127.0.0.1' && uri.host.isNotEmpty) {
        // Production hosted backend server on Render
        return 'wss://secret-hitler-backend-alireza.onrender.com';
      }
    }
    return 'ws://localhost:3000';
  }

  static Future<void> initialize() async {
    try {
      _connectWebSocket();
      _firebaseInitialized = true; // Signal that the WebSocket sync service is running
      print("WebSocket Sync Server connected successfully at $_wsUrl");
    } catch (e) {
      _firebaseInitialized = false;
      print("Failed to connect to local WebSocket server. Falling back to local offline mode.");
    }
  }

  static void _connectWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
    _channel!.stream.listen(
      (message) {
        try {
          final payload = jsonDecode(message as String);
          final type = payload['type'];

          if (type == 'sync' || type == 'created' || type == 'joined') {
            final data = payload['data'] as Map<String, dynamic>?;
            _gameStreamController.add(data);
          } else if (type == 'error') {
            final errorMessage = payload['message'] ?? 'خطایی رخ داد';
            _errorStreamController.add(errorMessage);
          } else if (type == 'privateRole') {
            final data = payload['data'] as Map<String, dynamic>?;
            // Match with active completer
            final lobbyCode = payload['lobbyCode'] ?? '';
            final playerId = payload['playerId'] ?? '';
            final key = '${lobbyCode}_$playerId';

            final completer = _privateRoleCompleters.remove(key);
            if (completer != null && !completer.isCompleted) {
              completer.complete(data);
            }
          }
        } catch (e) {
          print("Error parsing WebSocket message: $e");
        }
      },
      onError: (err) {
        print("WebSocket Error: $err");
        _firebaseInitialized = false;
      },
      onDone: () {
        print("WebSocket Connection Closed");
        _firebaseInitialized = false;
      },
    );
  }

  // Create a new game lobby
  static Future<String> createGame({
    required String hostName,
    required String hostId,
  }) async {
    final completer = Completer<String>();
    
    // Ensure we are connected
    if (_channel == null || !_firebaseInitialized) {
      _connectWebSocket();
      _firebaseInitialized = true;
    }

    // Temporary listener to get the created code
    late StreamSubscription tempSub;
    tempSub = _gameStreamController.stream.listen((data) {
      if (data != null && data['hostId'] == hostId) {
        tempSub.cancel();
        completer.complete(data['lobbyCode']);
      }
    });

    _channel!.sink.add(jsonEncode({
      'action': 'create',
      'hostName': hostName,
      'playerId': hostId,
    }));

    return completer.future;
  }

  // Join an existing game lobby
  static Future<String?> joinGame({
    required String lobbyCode,
    required String playerName,
    required String playerId,
  }) async {
    final completer = Completer<String?>();

    if (_channel == null || !_firebaseInitialized) {
      _connectWebSocket();
      _firebaseInitialized = true;
    }

    // Listen to confirm join or handle errors
    late StreamSubscription tempSub;
    late StreamSubscription errorSub;

    void cleanup() {
      tempSub.cancel();
      errorSub.cancel();
    }

    tempSub = _gameStreamController.stream.listen((data) {
      if (data != null && data['lobbyCode'] == lobbyCode) {
        final List<dynamic> players = data['players'] ?? [];
        final hasMe = players.any((p) => p['id'] == playerId);
        if (hasMe) {
          cleanup();
          completer.complete(null); // null means success (no error message)
        }
      }
    });

    errorSub = errorStream.listen((errorMessage) {
      cleanup();
      completer.complete(errorMessage);
    });

    // Timeout after 3 seconds if lobby not found
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete('پاسخی از سرور دریافت نشد. لطفاً کد لابی را بررسی کنید.');
      }
    });

    _channel!.sink.add(jsonEncode({
      'action': 'join',
      'lobbyCode': lobbyCode,
      'playerName': playerName,
      'playerId': playerId,
    }));

    return completer.future;
  }

  // Stream updates for a game
  static Stream<Map<String, dynamic>?> streamGame(String lobbyCode, String playerId) {
    // Send subscription request to the server
    _channel?.sink.add(jsonEncode({
      'action': 'subscribe',
      'lobbyCode': lobbyCode,
      'playerId': playerId,
    }));
    return _gameStreamController.stream;
  }

  // Update game state
  static Future<void> updateGame(String lobbyCode, Map<String, dynamic> updates) async {
    _channel?.sink.add(jsonEncode({
      'action': 'update',
      'lobbyCode': lobbyCode,
      'updates': updates,
    }));
  }

  // Save private role mappings
  static Future<void> savePrivateRoles(
    String lobbyCode,
    Map<String, Map<String, dynamic>> playerRoles,
  ) async {
    _channel?.sink.add(jsonEncode({
      'action': 'savePrivateRoles',
      'lobbyCode': lobbyCode,
      'playerRoles': playerRoles,
    }));
  }

  // Get private role info for a user
  static Future<Map<String, dynamic>?> getPrivateRole(String lobbyCode, String playerId) async {
    final key = '${lobbyCode}_$playerId';
    final completer = Completer<Map<String, dynamic>?>();
    _privateRoleCompleters[key] = completer;

    _channel?.sink.add(jsonEncode({
      'action': 'getPrivateRole',
      'lobbyCode': lobbyCode,
      'playerId': playerId,
    }));

    // Timeout fallback
    Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        _privateRoleCompleters.remove(key);
        completer.complete(null);
      }
    });

    return completer.future;
  }
}
