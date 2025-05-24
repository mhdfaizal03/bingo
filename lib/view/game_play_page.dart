// import 'dart:ui';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';

// class GamePlayPage extends StatefulWidget {
//   final String gameId;
//   final String playerId;

//   const GamePlayPage({
//     super.key,
//     required this.gameId,
//     required this.playerId,
//   });

//   @override
//   State<GamePlayPage> createState() => _GamePlayPageState();
// }

// class _GamePlayPageState extends State<GamePlayPage> {
//   late DocumentReference gameRef;
//   Map<String, dynamic>? gameData;
//   Map<String, dynamic>? playerData;
//   List<int> board = [];
//   List<bool> bingoStatus = List.filled(5, false);
//   bool dialogShown = false;

//   bool get isHost => gameData?['hostPlayerId'] == widget.playerId;
//   bool get isGameStarted => gameData?['gameStarted'] ?? false;
//   bool get isGamePaused => gameData?['gamePaused'] ?? false;
//   bool get isMyTurn =>
//       gameData?['turn'] == widget.playerId && isGameStarted && !isGamePaused;

//   @override
//   void initState() {
//     super.initState();
//     gameRef = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
//     _listenToGame();
//   }

//   void _listenToGame() {
//     gameRef.snapshots().listen((snapshot) {
//       if (snapshot.exists) {
//         final data = snapshot.data() as Map<String, dynamic>;
//         final players = data['players'] as Map<String, dynamic>;
//         final player = players[widget.playerId] as Map<String, dynamic>?;

//         if (player != null) {
//           setState(() {
//             gameData = data;
//             playerData = player;
//             board = List<int>.from(player['board'] ?? []);
//             bingoStatus = List<bool>.from(player['bingoStatus'] ?? []);
//           });

//           if (player['isWinner'] == true && !dialogShown) {
//             dialogShown = true;
//             _pauseGame();
//             _showWinnerDialog(player['name'] ?? 'Unknown');
//           }
//         }
//       }
//     });
//   }

//   void _startGame() {
//     final playerIds = (gameData?['players'] as Map).keys.toList();
//     gameRef.update({
//       'gameStarted': true,
//       'gamePaused': false,
//       'turn': playerIds.first,
//       'selectedNumbers': [],
//     });
//   }

//   void _pauseGame() {
//     gameRef.update({'gamePaused': true});
//   }

//   void _pauseOrResumeGame() {
//     if (!isHost || !isGameStarted) return;
//     gameRef.update({'gamePaused': !isGamePaused});
//   }

//   void _restartGame() {
//     final players = Map<String, dynamic>.from(gameData?['players'] ?? {});
//     final maxVal = gameData?['selectedValue'] ?? 25;

//     for (var key in players.keys) {
//       final newBoard = List.generate(maxVal, (i) => i + 1)..shuffle();
//       players[key]['selectedNumbers'] = [];
//       players[key]['bingoStatus'] = [false, false, false, false, false];
//       players[key]['isWinner'] = false;
//       players[key]['board'] = newBoard.take(25).toList();
//       // DO NOT reset the score
//     }

//     gameRef.update({
//       'gameStarted': false,
//       'gamePaused': false,
//       'selectedNumbers': [],
//       'turn': null,
//       'players': players,
//     });

//     dialogShown = false;
//   }

//   void _handleNumberTap(int number) {
//     if (!isMyTurn || (gameData?['selectedNumbers'] ?? []).contains(number))
//       return;

//     final updatedSelectedNumbers =
//         List<int>.from(gameData?['selectedNumbers'] ?? [])..add(number);
//     final players = Map<String, dynamic>.from(gameData?['players']);
//     String? winnerId;

//     for (var playerId in players.keys) {
//       final player = players[playerId];
//       final board = List<int>.from(player['board'] ?? []);
//       final selected = List<int>.from(player['selectedNumbers'] ?? []);
//       if (board.contains(number)) {
//         selected.add(number);
//       }

//       final bingo = _calculateBingo(board, selected);
//       final isWinner = bingo.every((b) => b == true);

//       players[playerId]['selectedNumbers'] = selected;
//       players[playerId]['bingoStatus'] = bingo;

//       if (isWinner && !(player['isWinner'] ?? false)) {
//         players[playerId]['isWinner'] = true;
//         players[playerId]['score'] = (player['score'] ?? 0) + 1;
//         winnerId = playerId;
//       }
//     }

//     final playerIds = players.keys.toList();
//     final nextIndex =
//         (playerIds.indexOf(widget.playerId) + 1) % playerIds.length;
//     final nextPlayerId = playerIds[nextIndex];

//     gameRef.update({
//       'selectedNumbers': updatedSelectedNumbers,
//       'players': players,
//       'turn': nextPlayerId,
//     });
//   }

//   List<bool> _calculateBingo(List<int> board, List<int> selected) {
//     List<bool> status = List.filled(5, false);
//     List<List<int>> lines = [];

//     for (int i = 0; i < 5; i++) {
//       lines.add(board.sublist(i * 5, (i + 1) * 5)); // Rows
//     }
//     for (int i = 0; i < 5; i++) {
//       lines.add([for (int j = 0; j < 5; j++) board[j * 5 + i]]); // Columns
//     }
//     lines.add([for (int i = 0; i < 5; i++) board[i * 6]]); // Diagonal \
//     lines.add([for (int i = 0; i < 5; i++) board[(i + 1) * 4]]); // Diagonal /

//     int count = 0;
//     for (var line in lines) {
//       if (line.every((n) => selected.contains(n))) {
//         if (count < 5) status[count] = true;
//         count++;
//       }
//     }

//     return status;
//   }

//   Future<void> _showWinnerDialog(String winnerName) async {
//     if (!mounted) return;

//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
//         child: CupertinoAlertDialog(
//           title: const Text("🎉 BINGO!"),
//           content: Text(
//             "$winnerName got BINGO!",
//             style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//           actions: [
//             if (isHost)
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   _restartGame();
//                 },
//                 child: const Text("Restart"),
//               ),
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text("Continue"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedNumbers = List<int>.from(gameData?['selectedNumbers'] ?? []);
//     final color = Color(playerData?['color'] ?? Colors.grey.value);
//     final playerName = playerData?['name'] ?? "Player";
//     final players = gameData?['players'] as Map<String, dynamic>? ?? {};

//     if (gameData == null || playerData == null) {
//       return Scaffold(
//         body: Center(child: CircularProgressIndicator(color: color)),
//       );
//     }

//     // List of player widgets to place in corners
//     final playerWidgets = players.entries.take(4).toList();

//     return WillPopScope(
//       onWillPop: () async {
//         bool? shouldExit = await showDialog(
//           context: context,
//           builder: (context) => BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
//             child: CupertinoAlertDialog(
//               title: const Text('Exit Game?'),
//               content: const Text('Are you sure you want to exit the game?'),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(false),
//                   child: const Text('No'),
//                 ),
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(true),
//                   child: const Text('Yes'),
//                 ),
//               ],
//             ),
//           ),
//         );
//         return shouldExit ?? false;
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           automaticallyImplyLeading: false,
//           centerTitle: true,
//           title: Text(
//             widget.gameId,
//             style: TextStyle(
//                 fontSize: 25, color: color, fontWeight: FontWeight.w500),
//           ),
//         ),
//         body: Stack(
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Text("Hello, $playerName",
//                       style: const TextStyle(
//                           fontSize: 25, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 10),
//                   if (isGameStarted && !isGamePaused)
//                     Text(isMyTurn ? "Your Turn" : "Waiting...",
//                         style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.green)),
//                   if (isGamePaused)
//                     const Text("Game Paused",
//                         style: TextStyle(fontSize: 20, color: Colors.red)),
//                   const SizedBox(height: 50),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: List.generate(5, (i) {
//                       const letters = ['B', 'I', 'N', 'G', 'O'];
//                       return Stack(
//                         children: [
//                           Container(
//                             height: 60,
//                             width: 60,
//                             margin: const EdgeInsets.all(2),
//                             padding: const EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               color: bingoStatus[i] ? Colors.red : color,
//                               shape: BoxShape.circle,
//                             ),
//                             child: Center(
//                               child: Text(
//                                 letters[i],
//                                 style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 30,
//                                     fontWeight: FontWeight.bold),
//                               ),
//                             ),
//                           ),
//                           if (bingoStatus[i])
//                             Icon(
//                               Icons.close_rounded,
//                               size: 50,
//                             ),
//                         ],
//                       );
//                     }),
//                   ),
//                   const SizedBox(height: 10),
//                   Expanded(
//                     child: GridView.builder(
//                       itemCount: 25,
//                       physics: const NeverScrollableScrollPhysics(),
//                       gridDelegate:
//                           const SliverGridDelegateWithFixedCrossAxisCount(
//                               crossAxisCount: 5),
//                       itemBuilder: (_, index) {
//                         final number = board[index];
//                         final selected =
//                             playerData?['selectedNumbers']?.contains(number) ??
//                                 false;
//                         return GestureDetector(
//                           onTap: () => _handleNumberTap(number),
//                           child: Container(
//                             margin: EdgeInsets.all(3),
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               color: selected
//                                   ? color.withOpacity(0.8)
//                                   : Colors.grey.shade200,
//                             ),
//                             child: Center(
//                               child: Text(
//                                 "$number",
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 20,
//                                   color: selected ? Colors.white : Colors.black,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   Row(
//                     children: [
//                       if (isGameStarted && isHost)
//                         Expanded(
//                           child: MaterialButton(
//                             color: color,
//                             height: 50,
//                             onPressed: _pauseOrResumeGame,
//                             child: Text(
//                                 isGamePaused ? "Resume Game" : "Pause Game",
//                                 style: const TextStyle(color: Colors.white)),
//                           ),
//                         ),
//                       if (!isGameStarted && isHost)
//                         Expanded(
//                           child: MaterialButton(
//                             color: color,
//                             height: 50,
//                             onPressed: _startGame,
//                             child: const Text("Start Game",
//                                 style: TextStyle(color: Colors.white)),
//                           ),
//                         ),
//                       const SizedBox(width: 5),
//                       if (isHost)
//                         Expanded(
//                           child: MaterialButton(
//                             color: color,
//                             height: 50,
//                             onPressed: _restartGame,
//                             child: const Text("Restart Game",
//                                 style: TextStyle(color: Colors.white)),
//                           ),
//                         ),
//                     ],
//                   )
//                 ],
//               ),
//             ),
//             // Player info in 4 corners
//             Positioned(
//                 top: 10,
//                 left: 10,
//                 child: _buildCornerText(playerWidgets, 0, color)),
//             Positioned(
//                 top: 10,
//                 right: 10,
//                 child: _buildCornerText(playerWidgets, 1, color)),
//             Positioned(
//                 bottom: 10,
//                 left: 10,
//                 child: _buildCornerText(playerWidgets, 2, color)),
//             Positioned(
//                 bottom: 10,
//                 right: 10,
//                 child: _buildCornerText(playerWidgets, 3, color)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCornerText(
//       List<MapEntry<String, dynamic>> players, int index, Color color) {
//     if (index >= players.length) return const SizedBox();
//     final player = players[index].value;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Text(player['name'] ?? '',
//             style: const TextStyle(fontWeight: FontWeight.bold)),
//         Text(
//           "${player['score'] ?? 0}",
//           style: TextStyle(
//               color: color, fontSize: 25, fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }
// }

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      lines.add(board.sublist(i * 5, (i + 1) * 5));
    }
    for (int i = 0; i < 5; i++) {
      lines.add([for (int j = 0; j < 5; j++) board[j * 5 + i]]);
    }
    lines.add([for (int i = 0; i < 5; i++) board[i * 6]]);
    lines.add([for (int i = 0; i < 5; i++) board[(i + 1) * 4]]);

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
                      return Stack(
                        children: [
                          Container(
                            height: 60,
                            width: 60,
                            margin: const EdgeInsets.all(2),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: bingoStatus[i]
                                    ? Colors.red[300]
                                    : Colors.green[300],
                                // shape: BoxShape.circle,
                                borderRadius: BorderRadius.circular(10)),
                            child: bingoStatus[i]
                                ? Center(
                                    child: Icon(Icons.close_rounded, size: 40),
                                  )
                                : Center(
                                    child: Text(
                                      letters[i],
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          ),
                        ],
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
                  Spacer(),
                  Row(
                    children: [
                      if (isGameStarted && isHost)
                        Center(
                          child: MaterialButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            color: color,
                            height: 50,
                            onPressed: _pauseOrResumeGame,
                            child: Text(isGamePaused ? "Resume" : "Pause",
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      if (!isGameStarted && isHost)
                        Center(
                          child: MaterialButton(
                            color: color,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            height: 50,
                            onPressed: _startGame,
                            child: const Text("Start Game",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      const SizedBox(width: 5),
                      if (isGameStarted && isHost)
                        Center(
                          child: MaterialButton(
                            color: color,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            height: 50,
                            onPressed: isGamePaused ? _restartGame : null,
                            child: Text("Restart",
                                style: TextStyle(
                                    color: !isGamePaused
                                        ? Colors.black
                                        : Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ],
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
