import 'dart:math';
import 'dart:ui';
import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class CreateGamePage extends StatefulWidget {
  const CreateGamePage({super.key});

  @override
  State<CreateGamePage> createState() => _CreateGamePageState();
}

class _CreateGamePageState extends State<CreateGamePage> {
  final TextEditingController _nameController = TextEditingController();
  final List<int> valueOptions = [25, 36, 64];
  final List<int> playerCountOptions = [2, 3, 4, 5];
  int? selectedColorIndex;
  int? selectedValue;
  int? maxPlayers;
  String? gameId;
  String? playerId;
  bool _isLoading = false;

  String _generateGameId() {
    const chars = '0123456789';
    final rand = Random();
    return List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  List<int> generateRandomBoard(int maxValue) {
    List<int> numbers = List.generate(maxValue, (index) => index + 1);
    numbers.shuffle();
    return numbers;
  }

  Future<void> _createGame() async {
    final name = _nameController.text.trim();

    if (name.isEmpty ||
        selectedColorIndex == null ||
        selectedValue == null ||
        maxPlayers == null) {
      CustomSnackBar.show(
          context: context,
          message: "Please fill all required fields.",
          color: Colors.red);

      return;
    }

    try {
      setState(() => _isLoading = true);

      final newGameId = _generateGameId();
      final newPlayerId = const Uuid().v4();
      final board = generateRandomBoard(selectedValue!);
      final gameRef =
          FirebaseFirestore.instance.collection('games').doc(newGameId);

      await gameRef.set({
        'createdBy': name,
        'hostPlayerId': newPlayerId,
        'selectedValue': selectedValue,
        'maxPlayers': maxPlayers,
        'createdAt': FieldValue.serverTimestamp(),
        'gameStarted': false,
        'selectedNumbers': [],
        'players': {
          newPlayerId: {
            'name': name,
            'color': colors[selectedColorIndex!].value,
            'selectedNumbers': [],
            'bingoStatus': [false, false, false, false, false],
            'isWinner': false,
            'board': board,
          }
        },
      });

      setState(() {
        gameId = newGameId;
        playerId = newPlayerId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.show(
          context: context,
          message: "Error creating game: $e",
          color: Colors.red);
    }
  }

  void _navigateToGame() {
    if (gameId != null && playerId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePlayPage(
            gameId: gameId!,
            playerId: playerId!,
          ),
        ),
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
          "CREATE GAME",
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
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildOptionGroup(
                                title: "VALUE RANGE",
                                options: valueOptions,
                                selectedValue: selectedValue,
                                onSelected: (val) =>
                                    setState(() => selectedValue = val),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildOptionGroup(
                                title: "PLAYERS",
                                options: playerCountOptions,
                                selectedValue: maxPlayers,
                                onSelected: (val) =>
                                    setState(() => maxPlayers = val),
                              ),
                            ),
                          ],
                        ),
                        if (gameId != null) ...[
                          const SizedBox(height: 32),
                          GlassContainer(
                            padding: const EdgeInsets.all(20),
                            borderColor: Colors.green.withOpacity(0.3),
                            child: Column(
                              children: [
                                const Text(
                                  "GAME CREATED SUCCESSFULLY!",
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SelectableText(
                                  gameId!,
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const Text(
                                  "Share this ID with your friends",
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 48),
                        Hero(
                          tag: 'create',
                          child: PremiumButton(
                            isLoading: _isLoading,
                            label: gameId != null ? "GO TO LOBBY" : "CREATE GAME",
                            icon: gameId != null
                                ? Icons.rocket_launch_outlined
                                : Icons.add_rounded,
                            onPressed: _isLoading
                                ? () {}
                                : gameId != null
                                    ? _navigateToGame
                                    : _createGame,
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

  Widget _buildOptionGroup({
    required String title,
    required List<int> options,
    required int? selectedValue,
    required Function(int) onSelected,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = selectedValue == opt;
              return GestureDetector(
                onTap: () => onSelected(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    "$opt",
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
