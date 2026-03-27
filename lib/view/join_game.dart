import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class JoinGamePage extends StatefulWidget {
  const JoinGamePage({super.key});

  @override
  State<JoinGamePage> createState() => _JoinGamePageState();
}

class _JoinGamePageState extends State<JoinGamePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gameIdController = TextEditingController();
  int? selectedColorIndex;
  bool _isLoading = false;

  List<int> generateRandomBoard(int maxValue) {
    List<int> numbers = List.generate(maxValue, (index) => index + 1);
    numbers.shuffle();
    return numbers;
  }

  Future<void> _joinGame() async {
    final name = _nameController.text.trim();
    final gameId = _gameIdController.text.trim().toUpperCase();

    if (name.isEmpty || gameId.isEmpty || selectedColorIndex == null) {
      CustomSnackBar.show(
          context: context,
          message: "Fill all fields and select a color",
          color: Colors.red);

      return;
    }

    try {
      setState(() => _isLoading = true);

      final gameRef =
          FirebaseFirestore.instance.collection('games').doc(gameId);
      final doc = await gameRef.get();

      if (!doc.exists) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(
            context: context, message: "Invalid Game ID", color: Colors.red);

        return;
      }

      final data = doc.data()!;
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      final maxPlayers = data['maxPlayers'];
      final gameStarted = data['gameStarted'] ?? false;
      final selectedValue = data['selectedValue'];

      if (gameStarted) {
        CustomSnackBar.show(
            context: context,
            message: "Game has already started",
            color: Colors.red);

        setState(() => _isLoading = false);
        return;
      }

      if (players.length >= maxPlayers) {
        CustomSnackBar.show(
            context: context, message: "Game is full", color: Colors.red);

        setState(() => _isLoading = false);
        return;
      }

      final colorValue = colors[selectedColorIndex!].value;
      if (players.values.any((p) => p['color'] == colorValue)) {
        CustomSnackBar.show(
          context: context,
          message: "Color already taken",
          color: Colors.red,
        );
        setState(() => _isLoading = false);
        return;
      }

      final playerId = const Uuid().v4();
      final board = generateRandomBoard(selectedValue);

      players[playerId] = {
        'name': name,
        'color': colorValue,
        'selectedNumbers': [],
        'bingoStatus': [false, false, false, false, false],
        'isWinner': false,
        'board': board,
      };

      await gameRef.update({'players': players});
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePlayPage(
            playerId: playerId,
            gameId: gameId,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.show(
        context: context,
        message: "Error: $e",
        color: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "JOIN GAME",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E1B4B),
                  Colors.black,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "YOUR IDENTITY",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _nameController,
                                maxLength: 15,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Enter your name...",
                                  hintStyle:
                                      const TextStyle(color: Colors.white24),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                  counterText: "",
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "GAME ID",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _gameIdController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                ),
                                decoration: InputDecoration(
                                  hintText: "ABCD",
                                  hintStyle:
                                      const TextStyle(color: Colors.white24),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                "PICK YOUR COLOR",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 50,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: colors.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 16),
                                  itemBuilder: (context, index) {
                                    final bool isSelected =
                                        selectedColorIndex == index;
                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => selectedColorIndex = index),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: colors[index],
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 3,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: colors[index]
                                                        .withOpacity(0.5),
                                                    blurRadius: 12,
                                                    spreadRadius: 2,
                                                  )
                                                ]
                                              : [],
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check,
                                                color: Colors.white)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        Hero(
                          tag: 'join',
                          child: PremiumButton(
                            isLoading: _isLoading,
                            label: "JOIN GAME",
                            icon: Icons.login_rounded,
                            onPressed: _isLoading ? () {} : _joinGame,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
