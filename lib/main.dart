import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'logic/firebase_manager.dart';
import 'logic/game_engine.dart';
import 'logic/online_game_engine.dart';
import 'models/game_state.dart';
import 'screens/setup_screen.dart';
import 'screens/role_reveal_screen.dart';
import 'screens/game_board_screen.dart';
import 'screens/multiplayer_setup_screen.dart';
import 'screens/online_lobby_screen.dart';
import 'screens/online_game_board_screen.dart';
import 'screens/multiplayer_sandbox_screen.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey == 'YOUR_API_KEY' || options.apiKey.isEmpty) {
      print("Firebase options are not configured. Sign-ins will fallback to mock-mode.");
    } else {
      await Firebase.initializeApp(
        options: options,
      );
      print("Firebase Core initialized successfully with config.");
    }
  } catch (e) {
    print("Firebase Core initialization warning: $e");
  }
  await FirebaseManager.initialize();
  runApp(const SecretHitlerApp());
}

class SecretHitlerApp extends StatelessWidget {
  const SecretHitlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secret Hitler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1B1816),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37), // Antique Gold
          secondary: Color(0xFF9E2A2B), // Dark Fascist Red
          surface: Color(0xFF2C2523),
          background: Color(0xFF1B1816),
        ),
        textTheme: GoogleFonts.vazirmatnTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const GameRouter(),
    );
  }
}

enum AppMode {
  login,
  onlineSetup,
  onlineLobby,
  onlinePlaying,
}

class GameRouter extends StatefulWidget {
  const GameRouter({super.key});

  @override
  State<GameRouter> createState() => _GameRouterState();
}

class _GameRouterState extends State<GameRouter> {
  AppMode _mode = AppMode.login;

  // Online Game values
  String _lobbyCode = '';
  String _playerName = '';
  String _playerId = '';
  OnlineGameEngine? _onlineEngine;

  void _quitToMenu() {
    setState(() {
      _mode = AppMode.login;
      _onlineEngine?.dispose();
      _onlineEngine = null;
      _lobbyCode = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case AppMode.login:
        return LoginScreen(
          onLoginSuccess: () {
            setState(() {
              _mode = AppMode.onlineSetup;
            });
          },
        );

      case AppMode.onlineSetup:
        return MultiplayerSetupScreen(
          onBack: () {
            setState(() {
              _mode = AppMode.login;
            });
          },
          onEnterLobby: (code, name, id) {
            setState(() {
              _lobbyCode = code;
              _playerName = name;
              _playerId = id;
              _mode = AppMode.onlineLobby;
              _onlineEngine = OnlineGameEngine(
                lobbyCode: code,
                localPlayerId: id,
                localPlayerName: name,
              );
            });
          },
        );

      case AppMode.onlineLobby:
        if (_onlineEngine == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: _onlineEngine!,
          builder: (context, _) {
            if (_onlineEngine!.status == 'playing') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _mode = AppMode.onlinePlaying;
                });
              });
            }
            return OnlineLobbyScreen(
              engine: _onlineEngine!,
              onLeave: _quitToMenu,
            );
          },
        );

      case AppMode.onlinePlaying:
        if (_onlineEngine == null) return const SizedBox.shrink();
        return OnlineGameBoardScreen(
          engine: _onlineEngine!,
          onQuit: _quitToMenu,
        );
    }
  }
}
