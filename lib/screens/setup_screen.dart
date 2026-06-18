import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  final Function(List<String>) onStartGame;

  const SetupScreen({Key? key, required this.onStartGame}) : super(key: key);

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _playerCount = 5;
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateControllers() {
    // Sync controllers with player count
    if (_controllers.length < _playerCount) {
      while (_controllers.length < _playerCount) {
        _controllers.add(TextEditingController(text: 'Player ${_controllers.length + 1}'));
      }
    } else if (_controllers.length > _playerCount) {
      while (_controllers.length > _playerCount) {
        final last = _controllers.removeLast();
        last.dispose();
      }
    }
  }

  void _submit() {
    final List<String> names = _controllers.map((c) => c.text.trim()).toList();

    // Validations
    for (int i = 0; i < names.length; i++) {
      if (names[i].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a name for Player ${i + 1}'),
            backgroundColor: const Color(0xFF9E2A2B),
          ),
        );
        return;
      }
    }

    // Check duplicates
    if (names.toSet().length != names.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All player names must be unique.'),
          backgroundColor: Color(0xFF9E2A2B),
        ),
      );
      return;
    }

    widget.onStartGame(names);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  const Text(
                    'SECRET',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE6DFD3),
                      letterSpacing: 8,
                      shadows: [
                        Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4),
                      ],
                    ),
                  ),
                  const Text(
                    'HITLER',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9E2A2B),
                      letterSpacing: 10,
                      shadows: [
                        Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 2,
                    color: const Color(0xFFD4AF37),
                  ),
                ],
              ),
            ),

            // Player count selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NUMBER OF PLAYERS',
                    style: TextStyle(
                      color: Color(0xFFE6DFD3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      final count = index + 5;
                      final bool isSelected = _playerCount == count;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _playerCount = count;
                              _updateControllers();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFD4AF37)
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFFD700)
                                    : Colors.white24,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Player names scrollable list
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _playerCount,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controllers[index],
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.black26,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.white10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Start Game button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9E2A2B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF9E2A2B).withOpacity(0.4),
                ),
                child: const Text(
                  'START GAME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
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
