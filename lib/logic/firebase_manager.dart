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
  static final Map<String, Completer<List<String>?>> _checkLobbyCompleters = {};
  static final Map<String, Completer<Map<String, dynamic>?>> _loginCompleters = {};
  static Completer<List<dynamic>?>? _leaderboardCompleter;
  static Map<String, dynamic>? currentUserProfile;

  static String? _activeLobbyCode;
  static String? _activePlayerId;
  static Timer? _reconnectTimer;

  static void clearActiveSubscription() {
    _activeLobbyCode = null;
    _activePlayerId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    print("Cleared active subscription, reconnect loop terminated.");
  }

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
    try {
      try {
        _channel?.sink.close();
      } catch (_) {}
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
            } else if (type == 'lobbyChecked') {
              final lobbyCode = payload['lobbyCode'] ?? '';
              final takenAvatars = List<String>.from(payload['takenAvatars'] ?? []);
              final completer = _checkLobbyCompleters.remove(lobbyCode);
              if (completer != null && !completer.isCompleted) {
                completer.complete(takenAvatars);
              }
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
            } else if (type == 'userProfile') {
              final data = payload['data'] as Map<String, dynamic>?;
              currentUserProfile = data;
              final uid = payload['data']?['uid'] ?? '';
              final key = 'login_$uid';
              final completer = _loginCompleters.remove(key);
              if (completer != null && !completer.isCompleted) {
                completer.complete(data);
              }
            } else if (type == 'leaderboard') {
              final list = payload['data'] as List<dynamic>?;
              final completer = _leaderboardCompleter;
              if (completer != null && !completer.isCompleted) {
                _leaderboardCompleter = null;
                completer.complete(list);
              }
            }
          } catch (e) {
            print("Error parsing WebSocket message: $e");
          }
        },
        onError: (err) {
          print("WebSocket Error: $err");
          _firebaseInitialized = false;
          _scheduleReconnect();
        },
        onDone: () {
          print("WebSocket Connection Closed");
          _firebaseInitialized = false;
          _scheduleReconnect();
        },
      );
      _firebaseInitialized = true;

      // Resubscribe if active lobby is set
      if (_activeLobbyCode != null && _activePlayerId != null) {
        _channel?.sink.add(jsonEncode({
          'action': 'subscribe',
          'lobbyCode': _activeLobbyCode,
          'playerId': _activePlayerId,
        }));
        print("Resubscribed to lobby $_activeLobbyCode for player $_activePlayerId");
      }
    } catch (e) {
      print("WebSocket Connection Exception: $e");
      _firebaseInitialized = false;
      _scheduleReconnect();
    }
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_firebaseInitialized) {
        print("Attempting to reconnect WebSocket...");
        _connectWebSocket();
      }
    });
  }

  // Create a new game lobby
  static Future<String> createGame({
    required String hostName,
    required String hostId,
    String? avatar,
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

    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        tempSub.cancel();
        _firebaseInitialized = false;
        try {
          _channel?.sink.close();
        } catch (_) {}
        _channel = null;
        completer.completeError(TimeoutException('پاسخی از سرور دریافت نشد.'));
      }
    });

    _channel!.sink.add(jsonEncode({
      'action': 'create',
      'hostName': hostName,
      'playerId': hostId,
      'avatar': avatar,
    }));

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  // Join an existing game lobby
  static Future<String?> joinGame({
    required String lobbyCode,
    required String playerName,
    required String playerId,
    String? avatar,
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

    // Timeout after 10 seconds if lobby not found
    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        cleanup();
        _firebaseInitialized = false;
        try {
          _channel?.sink.close();
        } catch (_) {}
        _channel = null;
        completer.complete('پاسخی از سرور دریافت نشد. لطفاً کد لابی را بررسی کنید.');
      }
    });

    _channel!.sink.add(jsonEncode({
      'action': 'join',
      'lobbyCode': lobbyCode,
      'playerName': playerName,
      'playerId': playerId,
      'avatar': avatar,
    }));

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  // Stream updates for a game
  static Stream<Map<String, dynamic>?> streamGame(String lobbyCode, String playerId) {
    _activeLobbyCode = lobbyCode;
    _activePlayerId = playerId;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

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

    // Timeout fallback (5 seconds)
    final timer = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        _privateRoleCompleters.remove(key);
        completer.complete(null);
      }
    });

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  // Check the lobby existance and retrieve taken avatars list
  static Future<List<String>?> checkLobby({
    required String lobbyCode,
  }) async {
    final completer = Completer<List<String>?>();

    if (_channel == null || !_firebaseInitialized) {
      _connectWebSocket();
      _firebaseInitialized = true;
    }

    late StreamSubscription errorSub;

    void cleanup() {
      errorSub.cancel();
      _checkLobbyCompleters.remove(lobbyCode);
    }

    errorSub = errorStream.listen((errorMessage) {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    _checkLobbyCompleters[lobbyCode] = completer;

    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        cleanup();
        _firebaseInitialized = false;
        try {
          _channel?.sink.close();
        } catch (_) {}
        _channel = null;
        completer.complete(null);
      }
    });

    _channel!.sink.add(jsonEncode({
      'action': 'checkLobby',
      'lobbyCode': lobbyCode,
    }));

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  // Explicitly notify the server we are leaving the lobby/game
  static Future<void> leaveGame(String lobbyCode, String playerId) async {
    try {
      if (_channel != null && _firebaseInitialized) {
        _channel!.sink.add(jsonEncode({
          'action': 'leave',
          'lobbyCode': lobbyCode,
          'playerId': playerId,
        }));
      }
    } catch (e) {
      print("Error sending leave game action: $e");
    }
    clearActiveSubscription();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _firebaseInitialized = false;
  }

  // Login or create a persistent user profile in MongoDB
  static Future<Map<String, dynamic>?> loginUser({
    required String uid,
    required String displayName,
    String? email,
    String? photoUrl,
  }) async {
    final key = 'login_$uid';
    final completer = Completer<Map<String, dynamic>?>();
    _loginCompleters[key] = completer;

    if (_channel == null || !_firebaseInitialized) {
      _connectWebSocket();
      _firebaseInitialized = true;
    }

    // Wait for the websocket connection to stabilize before sending
    await Future.delayed(const Duration(milliseconds: 300));

    _channel!.sink.add(jsonEncode({
      'action': 'loginUser',
      'uid': uid,
      'displayName': displayName,
      'email': email ?? '',
      'photoUrl': photoUrl ?? 'avatar_1',
    }));

    // 10s timeout
    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        _loginCompleters.remove(key);
        completer.complete(null);
      }
    });

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  // Update user profile (username/avatar)
  static Future<Map<String, dynamic>?> updateProfile({
    required String uid,
    required String displayName,
    required String photoUrl,
  }) async {
    final key = 'login_$uid';
    final completer = Completer<Map<String, dynamic>?>();
    _loginCompleters[key] = completer;

    if (_channel == null || !_firebaseInitialized) {
      _connectWebSocket();
      _firebaseInitialized = true;
    }

    _channel!.sink.add(jsonEncode({
      'action': 'updateProfile',
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
    }));

    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        _loginCompleters.remove(key);
        completer.complete(null);
      }
    });

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  // Fetch the top 10 users for the leaderboard
  static Future<List<dynamic>?> getLeaderboard() async {
    final completer = Completer<List<dynamic>?>();
    _leaderboardCompleter = completer;

    if (_channel == null || !_firebaseInitialized) {
      _connectWebSocket();
      _firebaseInitialized = true;
    }

    _channel!.sink.add(jsonEncode({
      'action': 'getLeaderboard',
    }));

    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        if (_leaderboardCompleter == completer) {
          _leaderboardCompleter = null;
        }
        completer.complete(null);
      }
    });

    final result = await completer.future;
    timer.cancel();
    return result;
  }
}
