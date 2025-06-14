import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GamePlayPage extends StatefulWidget {
  final String gameId;
  final String playerId;

  const GamePlayPage({
    super.key,
    required this.gameId,
    required this.playerId,
  });

  @override
  State<GamePlayPage> createState() => _GamePlayPageState();
}

class _GamePlayPageState extends State<GamePlayPage> {
  late ConfettiController _confettiController;

  late DocumentReference gameRef;
  Map<String, dynamic>? gameData;
  Map<String, dynamic>? playerData;
  List<int> board = [];
  List<bool> bingoStatus = List.filled(5, false);
  bool dialogShown = false;

  bool get isHost => gameData?['hostPlayerId'] == widget.playerId;
  bool get isGameStarted => gameData?['gameStarted'] ?? false;
  bool get isGamePaused => gameData?['gamePaused'] ?? false;
  bool get isMyTurn =>
      gameData?['turn'] == widget.playerId && isGameStarted && !isGamePaused;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    _listenToGame();
  }

  void _listenToGame() {
    gameRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final players = data['players'] as Map<String, dynamic>;
        final player = players[widget.playerId] as Map<String, dynamic>?;

        if (player != null) {
          setState(() {
            gameData = data;
            playerData = player;
            board = List<int>.from(player['board'] ?? []);
            bingoStatus = List<bool>.from(player['bingoStatus'] ?? []);
          });

          if (player['isWinner'] == true && !dialogShown) {
            dialogShown = true;
            _pauseGame();
            _confettiController.play();
            _showWinnerDialog(player['name'] ?? 'Unknown');
          }
        }
      }
    });
  }

  void _startGame() {
    final playerIds = (gameData?['players'] as Map).keys.toList();
    gameRef.update({
      'gameStarted': true,
      'gamePaused': false,
      'turn': playerIds.first,
      'selectedNumbers': [],
    });
  }

  void _pauseGame() {
    gameRef.update({'gamePaused': true});
  }

  void _pauseOrResumeGame() {
    if (!isHost || !isGameStarted) return;
    gameRef.update({'gamePaused': !isGamePaused});
  }

  void _restartGame() {
    final players = Map<String, dynamic>.from(gameData?['players'] ?? {});
    final maxVal = gameData?['selectedValue'] ?? 25;

    for (var key in players.keys) {
      final newBoard = List.generate(maxVal, (i) => i + 1)..shuffle();
      players[key]['selectedNumbers'] = [];
      players[key]['bingoStatus'] = [false, false, false, false, false];
      players[key]['isWinner'] = false;
      players[key]['board'] = newBoard.take(25).toList();
    }

    gameRef.update({
      'gameStarted': false,
      'gamePaused': false,
      'selectedNumbers': [],
      'turn': null,
      'players': players,
    });

    dialogShown = false;
  }

  void _handleNumberTap(int number) {
    if (!isMyTurn || (gameData?['selectedNumbers'] ?? []).contains(number)) {
      return;
    }

    final updatedSelectedNumbers =
        List<int>.from(gameData?['selectedNumbers'] ?? [])..add(number);
    final players = Map<String, dynamic>.from(gameData?['players']);
    String? winnerId;

    for (var playerId in players.keys) {
      final player = players[playerId];
      final board = List<int>.from(player['board'] ?? []);
      final selected = List<int>.from(player['selectedNumbers'] ?? []);
      if (board.contains(number)) {
        selected.add(number);
      }

      final bingo = _calculateBingo(board, selected);
      final isWinner = bingo.every((b) => b == true);

      players[playerId]['selectedNumbers'] = selected;
      players[playerId]['bingoStatus'] = bingo;

      if (isWinner && !(player['isWinner'] ?? false)) {
        players[playerId]['isWinner'] = true;
        players[playerId]['score'] = (player['score'] ?? 0) + 1;
        winnerId = playerId;
      }
    }

    final playerIds = players.keys.toList();
    final nextIndex =
        (playerIds.indexOf(widget.playerId) + 1) % playerIds.length;
    final nextPlayerId = playerIds[nextIndex];

    gameRef.update({
      'selectedNumbers': updatedSelectedNumbers,
      'players': players,
      'turn': nextPlayerId,
    });
  }

  List<bool> _calculateBingo(List<int> board, List<int> selected) {
    List<bool> status = List.filled(5, false);
    List<List<int>> lines = [];

    for (int i = 0; i < 5; i++) {
      lines.add(board.sublist(i * 5, (i + 1) * 5)); // Rows
      lines.add([for (int j = 0; j < 5; j++) board[j * 5 + i]]); // Columns
    }

    lines.add([for (int i = 0; i < 5; i++) board[i * 6]]); // Diagonal TL-BR
    lines.add(
        [for (int i = 0; i < 5; i++) board[(i + 1) * 4]]); // Diagonal TR-BL

    int count = 0;
    for (var line in lines) {
      if (line.every((n) => selected.contains(n))) {
        if (count < 5) status[count] = true;
        count++;
      }
    }

    return status;
  }

  Future<void> _showWinnerDialog(String winnerName) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: CupertinoAlertDialog(
          title: const Text("🎉 BINGO!"),
          content: Text(
            "$winnerName got BINGO!",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (isHost)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restartGame();
                },
                child: const Text("Restart"),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedNumbers = List<int>.from(gameData?['selectedNumbers'] ?? []);
    final color = Color(playerData?['color'] ?? Colors.grey.value);
    final playerName = playerData?['name'] ?? "Player";
    final players = gameData?['players'] as Map<String, dynamic>? ?? {};
    final playerWidgets = players.entries.take(4).toList();

    if (gameData == null || playerData == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: color)),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        bool? shouldExit = await showDialog(
          context: context,
          builder: (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: CupertinoAlertDialog(
              title: const Text('Exit Game?'),
              content: const Text('Are you sure you want to exit the game?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Text(widget.gameId,
              style: TextStyle(
                  fontSize: 25, color: color, fontWeight: FontWeight.w500)),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("Hello, $playerName",
                      style: const TextStyle(
                          fontSize: 25, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (isGameStarted && !isGamePaused)
                    Text(isMyTurn ? "Your Turn" : "Waiting...",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  if (isGamePaused)
                    const Text("Game Paused",
                        style: TextStyle(fontSize: 20, color: Colors.red)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      const letters = ['B', 'I', 'N', 'G', 'O'];
                      return Container(
                        height: 60,
                        width: 60,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: bingoStatus[i]
                              ? Colors.red[300]
                              : Colors.green[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: bingoStatus[i]
                              ? Icon(Icons.check, size: 40, color: Colors.white)
                              : Text(
                                  letters[i],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 500,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          width: 2,
                          color: isMyTurn ? Colors.green : Colors.transparent,
                        )),
                    child: Center(
                      child: GridView.builder(
                        itemCount: 25,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5),
                        itemBuilder: (_, index) {
                          final number = board[index];
                          final selected = playerData?['selectedNumbers']
                                  ?.contains(number) ??
                              false;
                          return GestureDetector(
                            onTap: () => _handleNumberTap(number),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? color.withOpacity(0.8)
                                    : Colors.grey.shade200,
                              ),
                              child: Center(
                                child: Text(
                                  "$number",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color:
                                        selected ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isGameStarted && isHost)
                        MaterialButton(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          color: color,
                          height: 50,
                          onPressed: _pauseOrResumeGame,
                          child: Text(isGamePaused ? "Resume" : "Pause",
                              style: const TextStyle(color: Colors.white)),
                        ),
                      if (!isGameStarted && isHost)
                        MaterialButton(
                          color: color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          height: 50,
                          onPressed: _startGame,
                          child: const Text("Start Game",
                              style: TextStyle(color: Colors.white)),
                        ),
                      const SizedBox(width: 5),
                      if (isGameStarted && isHost)
                        MaterialButton(
                          color: color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          height: 50,
                          onPressed: isGamePaused ? _restartGame : null,
                          child: Text("Restart",
                              style: TextStyle(
                                  color: isGamePaused
                                      ? Colors.white
                                      : Colors.black)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Confetti Widget
            Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 30,
                emissionFrequency: 0.1,
              ),
            ),

            Positioned(
                top: 10,
                left: 10,
                child: _buildCornerText(playerWidgets, 0, color)),
            Positioned(
                top: 10,
                right: 10,
                child: _buildCornerText(playerWidgets, 1, color)),
            Positioned(
                bottom: 140,
                left: 10,
                child: _buildCornerText(playerWidgets, 2, color)),
            Positioned(
                bottom: 140,
                right: 10,
                child: _buildCornerText(playerWidgets, 3, color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerText(
      List<MapEntry<String, dynamic>> players, int index, Color color) {
    if (index >= players.length) return const SizedBox();
    final player = players[index].value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(player['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          "${player['score'] ?? 0}",
          style: TextStyle(
              color: color, fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:confetti/confetti.dart';
// import 'dart:math';

// class GamePlayPage extends StatefulWidget {
//   final String gameId;

//   const GamePlayPage({Key? key, required this.gameId}) : super(key: key);

//   @override
//   State<GamePlayPage> createState() => _GamePlayPageState();
// }

// class _GamePlayPageState extends State<GamePlayPage> {
//   final user = FirebaseAuth.instance.currentUser;
//   final ConfettiController _confettiController =
//       ConfettiController(duration: const Duration(seconds: 3));

//   late List<List<int>> grid;
//   late List<List<bool>> selected;
//   bool isLoading = true;
//   bool isGameStarted = false;
//   bool isHost = false;
//   bool isMyTurn = false;
//   Map<String, dynamic> gameData = {};
//   Map<String, dynamic> players = {};
//   Map<String, dynamic> playerProgress = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadGame();
//   }

//   void _loadGame() async {
//     final doc = await FirebaseFirestore.instance
//         .collection('games')
//         .doc(widget.gameId)
//         .get();
//     final data = doc.data()!;
//     final myId = user!.uid;
//     setState(() {
//       gameData = data;
//       players = Map<String, dynamic>.from(data['players']);
//       playerProgress = Map<String, dynamic>.from(data['progress'] ?? {});
//       isHost = data['hostId'] == myId;
//       isGameStarted = data['started'] ?? false;
//       isMyTurn = data['turn'] == myId;

//       grid = List<List<int>>.from(
//           (data['grid'] as List).map((row) => List<int>.from(row)));
//       selected = List<List<bool>>.from(
//           (data['selected'] as List).map((row) => List<bool>.from(row)));
//       isLoading = false;
//     });
//   }

//   void _selectNumber(int row, int col) async {
//     if (!isMyTurn || selected[row][col]) return;

//     selected[row][col] = true;
//     final number = grid[row][col];

//     await FirebaseFirestore.instance
//         .collection('games')
//         .doc(widget.gameId)
//         .update({
//       'selected': selected,
//     });

//     _checkBingoAndUpdate(row, col);
//     _nextTurn();
//   }

//   void _checkBingoAndUpdate(int row, int col) {
//     int linesCompleted = 0;
//     final playerId = user!.uid;
//     final markGrid = selected;

//     for (int i = 0; i < 5; i++) {
//       if (markGrid[i].every((e) => e)) linesCompleted++;
//       if (markGrid.every((e) => e[i])) linesCompleted++;
//     }

//     if (markGrid[0][0] &&
//         markGrid[1][1] &&
//         markGrid[2][2] &&
//         markGrid[3][3] &&
//         markGrid[4][4]) {
//       linesCompleted++;
//     }
//     if (markGrid[0][4] &&
//         markGrid[1][3] &&
//         markGrid[2][2] &&
//         markGrid[3][1] &&
//         markGrid[4][0]) {
//       linesCompleted++;
//     }

//     final bingoLetters = ['B', 'I', 'N', 'G', 'O'];
//     final progress = playerProgress[playerId] ?? [];
//     final newProgress = bingoLetters.take(linesCompleted).toList();

//     if (newProgress.length == 5) {
//       _confettiController.play();
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text("BINGO!"),
//           content: const Text("You've completed all lines and won the game!"),
//           actions: [
//             TextButton(
//               onPressed: () =>
//                   Navigator.of(context).popUntil((route) => route.isFirst),
//               child: const Text("OK"),
//             ),
//           ],
//         ),
//       );
//     }

//     FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
//       'progress.$playerId': newProgress,
//       'players.$playerId.score': newProgress.length,
//     });
//   }

//   void _nextTurn() {
//     final keys = players.keys.toList();
//     final currentIndex = keys.indexOf(user!.uid);
//     final nextIndex = (currentIndex + 1) % keys.length;
//     final nextPlayerId = keys[nextIndex];

//     FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
//       'turn': nextPlayerId,
//     });
//   }

//   void _restartGame() async {
//     final random = Random();
//     final newGrid =
//         List.generate(5, (_) => List.generate(5, (_) => random.nextInt(100)));
//     final newSelected = List.generate(5, (_) => List.generate(5, (_) => false));

//     await FirebaseFirestore.instance
//         .collection('games')
//         .doc(widget.gameId)
//         .update({
//       'grid': newGrid,
//       'selected': newSelected,
//       'started': true,
//       'progress': {},
//       'players': {
//         for (var entry in players.entries)
//           entry.key: {
//             'name': entry.value['name'],
//             'score': 0,
//             'color': entry.value['color'],
//           }
//       },
//       'turn': players.keys.first,
//     });

//     _loadGame();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     final playerWidgets = players.entries.toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Bingo Game"),
//         automaticallyImplyLeading: false,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.exit_to_app),
//             onPressed: () {
//               showDialog(
//                 context: context,
//                 builder: (_) => AlertDialog(
//                   title: const Text("Exit Game"),
//                   content:
//                       const Text("Are you sure you want to leave the game?"),
//                   actions: [
//                     TextButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       child: const Text("Cancel"),
//                     ),
//                     TextButton(
//                       onPressed: () => Navigator.of(context)
//                           .popUntil((route) => route.isFirst),
//                       child: const Text("Exit"),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           )
//         ],
//       ),
//       body: Stack(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               children: [
//                 const SizedBox(height: 10),
//                 Text(
//                   isMyTurn ? "Your Turn" : "Waiting for opponent...",
//                   style: const TextStyle(
//                       fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 10),
//                 Expanded(
//                   child: GridView.builder(
//                     gridDelegate:
//                         const SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: 5,
//                       mainAxisSpacing: 4,
//                       crossAxisSpacing: 4,
//                     ),
//                     itemCount: 25,
//                     itemBuilder: (_, index) {
//                       final row = index ~/ 5;
//                       final col = index % 5;
//                       final value = grid[row][col];
//                       final isSelected = selected[row][col];

//                       return ElevatedButton(
//                         onPressed:
//                             isSelected ? null : () => _selectNumber(row, col),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor:
//                               isSelected ? Colors.grey : Colors.blueAccent,
//                           foregroundColor: Colors.white,
//                         ),
//                         child: Text(value.toString()),
//                       );
//                     },
//                   ),
//                 ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text("Score: ", style: TextStyle(fontSize: 16)),
//                     Text(
//                       (players[user!.uid]?['score'] ?? 0).toString(),
//                       style: const TextStyle(
//                           fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(width: 5),
//                     if (isHost)
//                       MaterialButton(
//                         color: Colors.redAccent,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10)),
//                         height: 50,
//                         onPressed: _restartGame,
//                         child: const Text("Restart",
//                             style: TextStyle(color: Colors.white)),
//                       ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 Wrap(
//                   alignment: WrapAlignment.center,
//                   spacing: 10,
//                   runSpacing: 10,
//                   children: playerWidgets.map((entry) {
//                     final player = entry.value;
//                     final playerName = player['name'] ?? 'Player';
//                     final score = player['score'] ?? 0;
//                     final color = Color(player['color'] ?? Colors.grey.value);
//                     return Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 12, vertical: 8),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(12),
//                         color: color.withOpacity(0.2),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           CircleAvatar(
//                             backgroundColor: color,
//                             radius: 8,
//                           ),
//                           const SizedBox(width: 5),
//                           Text(
//                             '$playerName: $score',
//                             style: const TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                         ],
//                       ),
//                     );
//                   }).toList(),
//                 ),
//               ],
//             ),
//           ),
//           Align(
//             alignment: Alignment.center,
//             child: ConfettiWidget(
//               confettiController: _confettiController,
//               blastDirectionality: BlastDirectionality.explosive,
//               shouldLoop: false,
//               numberOfParticles: 30,
//               gravity: 0.3,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _confettiController.dispose();
//     super.dispose();
//   }
// }
