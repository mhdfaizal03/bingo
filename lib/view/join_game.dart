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
      appBar: AppBar(title: const Text("Join Game")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                TextField(
                  controller: _gameIdController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[300],
                    hintText: "Game ID",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Select your color:"),
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
                const SizedBox(height: 30),
                Spacer(),
                MaterialButton(
                  height: 50,
                  minWidth: double.infinity,
                  color: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onPressed: _isLoading ? null : _joinGame,
                  child: _isLoading
                      ? Lottie.asset(
                          width: 300,
                          height: 200,
                          'assets/Animation - 1749891403914.json')
                      // const CircularProgressIndicator(
                      //     color: Colors.green,
                      //     strokeWidth: 1.8,
                      //   )
                      : const Text("Join Game",
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
