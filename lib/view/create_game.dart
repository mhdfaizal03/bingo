import 'dart:math';
import 'dart:ui';
import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
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
    return numbers.take(25).toList();
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
      backgroundColor: Colors.black,
      appBar: AppBar(
          foregroundColor: Colors.white70,
          backgroundColor: const Color.fromARGB(248, 61, 8, 26),
          title: const Text("Create Game")),
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
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: MediaQuery.of(context).size.height * 0.80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  maxLength: 15,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: "Your ID / Name",
                                    hintStyle:
                                        const TextStyle(color: Colors.white70),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    counterText: "",
                                  ),
                                  buildCounter: (
                                    BuildContext context, {
                                    required int currentLength,
                                    required bool isFocused,
                                    required int? maxLength,
                                  }) {
                                    return null; // hides the counter
                                  },
                                )),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Choose Color",
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: List.generate(colors.length, (index) {
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedColorIndex = index),
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
                                    ? const Icon(Icons.check,
                                        color: Colors.white)
                                    : null,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Value Range",
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: valueOptions.map((value) {
                            final isSelected = selectedValue == value;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedValue = value),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white38,
                                    width: 1.2,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Text(
                                      "$value",
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Player Count",
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: playerCountOptions.map((count) {
                            final isSelected = maxPlayers == count;
                            return GestureDetector(
                              onTap: () => setState(() => maxPlayers = count),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 25, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white38,
                                    width: 1.2,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Text(
                                      "$count",
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        if (gameId != null) ...[
                          const SizedBox(height: 30),
                          const Text("Game ID",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white)),
                          SelectableText(
                            gameId!,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                    _isLoading
                        ? Lottie.asset(
                            'assets/Animation - 1749891403914.json',
                            width: 300,
                            height: 200,
                          )
                        : Center(
                            child: Hero(
                              tag: 'create',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.25),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 6,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: MaterialButton(
                                      height: 50,
                                      minWidth: double.infinity,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : gameId != null
                                              ? _navigateToGame
                                              : _createGame,
                                      child: Text(
                                        gameId != null
                                            ? "Go to Game"
                                            : "Create Game",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white.withOpacity(0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
