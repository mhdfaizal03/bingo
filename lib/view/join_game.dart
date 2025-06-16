import 'dart:ui';

import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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
    return numbers.take(25).toList();
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
      appBar: AppBar(
          foregroundColor: Colors.white70,
          backgroundColor: const Color.fromARGB(248, 61, 8, 26),
          title: const Text("Join Game")),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
              const Color.fromARGB(248, 61, 8, 26),
              Colors.black,
            ])),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              width: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        child: TextField(
                          controller: _nameController,
                          maxLength: 15, // optional
                          buildCounter: (
                            context, {
                            required int currentLength,
                            required bool isFocused,
                            required int? maxLength,
                          }) {
                            return null; // hides the counter completely
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Your ID / Name",
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            counterText: "", // also helps hide counter space
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withOpacity(0.1), // Glass background
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color:
                                Colors.white.withOpacity(0.2), // Frosted border
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        child: TextField(
                          controller: _gameIdController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Game ID",
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none, // Remove default border
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Select your color:",
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: List.generate(colors.length, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedColorIndex = index),
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors[index],
                            border: Border.all(
                              color: selectedColorIndex == index
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: selectedColorIndex == index
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),
                  Spacer(),
                  Hero(
                      tag: 'join',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.2,
                              ),
                            ),
                            child: MaterialButton(
                              height: 50,
                              minWidth: double.infinity,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              onPressed: _isLoading ? null : _joinGame,
                              child: _isLoading
                                  ? Lottie.asset(
                                      'assets/Animation - 1749891403914.json',
                                      width: 300,
                                      height: 200,
                                    )
                                  : const Text(
                                      "Join Game",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
