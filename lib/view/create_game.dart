import 'dart:math';
import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:uuid/uuid.dart';

class CreateGamePage extends StatefulWidget {
  const CreateGamePage({super.key});

  @override
  State<CreateGamePage> createState() => _CreateGamePageState();
}

class _CreateGamePageState extends State<CreateGamePage> {
  final TextEditingController _nameController = TextEditingController();
  final List<int> valueOptions = [25, 64];
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
      appBar: AppBar(title: const Text("Create Game")),
      body: Padding(
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
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[300],
                          hintText: "Your ID / Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("Choose Color"),
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
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: selectedColorIndex == index
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      const Text("Value Range"),
                      Wrap(
                        spacing: 10,
                        children: valueOptions.map((value) {
                          return ChoiceChip(
                            label: Text("$value"),
                            selected: selectedValue == value,
                            onSelected: (_) =>
                                setState(() => selectedValue = value),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text("Player Count"),
                      Wrap(
                        spacing: 10,
                        children: playerCountOptions.map((count) {
                          return ChoiceChip(
                            labelPadding: EdgeInsets.symmetric(horizontal: 12),
                            label: Text("$count"),
                            selected: maxPlayers == count,
                            onSelected: (_) =>
                                setState(() => maxPlayers = count),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      if (gameId != null) ...[
                        const SizedBox(height: 30),
                        const Text("Game ID", style: TextStyle(fontSize: 16)),
                        SelectableText(
                          gameId!,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                  Center(
                    child: MaterialButton(
                      height: 50,
                      minWidth: double.infinity,
                      color: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onPressed: _isLoading
                          ? null
                          : gameId != null
                              ? _navigateToGame
                              : _createGame,
                      child: _isLoading
                          ? Lottie.asset(
                              width: 300,
                              height: 200,
                              'assets/Animation - 1749891403914.json')
                          // const CircularProgressIndicator(
                          //     color: Colors.blue,
                          //     strokeWidth: 1.8,
                          //   )
                          : Text(gameId != null ? "Go to Game" : "Create Game",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
