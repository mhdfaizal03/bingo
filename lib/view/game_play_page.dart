// import 'dart:ui';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:confetti/confetti.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:lottie/lottie.dart';
// import 'dart:math';

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
//   late ConfettiController _confettiController;

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

//   // Get grid size based on selectedValue
//   int get gridSize {
//     final selectedValue = gameData?['selectedValue'] ?? 25;
//     return sqrt(selectedValue).round();
//   }

//   @override
//   void initState() {
//     super.initState();
//     _confettiController =
//         ConfettiController(duration: const Duration(seconds: 4));
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

//             // Check if board needs to be regenerated due to selectedValue change
//             final selectedValue = data['selectedValue'] ?? 25;
//             if (board.isEmpty || board.length != selectedValue) {
//               // Generate new board with correct size
//               final newBoard = List.generate(selectedValue, (i) => i + 1)
//                 ..shuffle();
//               board = newBoard;

//               // Update the player's board in Firebase
//               gameRef.update({
//                 'players.${widget.playerId}.board': newBoard,
//                 'players.${widget.playerId}.selectedNumbers': [],
//                 'players.${widget.playerId}.bingoStatus': List.filled(5, false),
//               });
//             }

//             // Update bingoStatus based on grid size
//             final size = sqrt(selectedValue).round();
//             bingoStatus =
//                 List<bool>.from(player['bingoStatus'] ?? List.filled(5, false));
//           });

//           // Check if there's a winner and show dialog to all players
//           final winnerId = data['winnerId'] as String?;
//           final winnerName = data['winnerName'] as String?;
//           final showWinnerDialog = data['showWinnerDialog'] ?? false;

//           if (showWinnerDialog &&
//               winnerId != null &&
//               winnerName != null &&
//               !dialogShown) {
//             dialogShown = true;
//             _confettiController.play();
//             _showWinnerDialog(winnerName, winnerId);
//           }

//           // Reset dialog flag when game is restarted
//           if (!showWinnerDialog) {
//             dialogShown = false;
//           }
//         }
//       }
//     });
//   }

//   // Get players in the order they joined (based on joinOrder or timestamp)
//   List<String> _getPlayerOrder() {
//     if (gameData == null) return [];

//     final players = gameData!['players'] as Map<String, dynamic>;
//     final playerEntries = players.entries.toList();

//     // Sort by joinOrder if available, otherwise use the order they appear
//     playerEntries.sort((a, b) {
//       final orderA = a.value['joinOrder'] ?? 0;
//       final orderB = b.value['joinOrder'] ?? 0;
//       return orderA.compareTo(orderB);
//     });

//     return playerEntries.map((e) => e.key).toList();
//   }

//   void _startGame() {
//     final playerIds = _getPlayerOrder();

//     // Start with the host (creator) as the first player
//     final hostId = gameData?['hostPlayerId'];
//     String firstPlayer;

//     if (hostId != null && playerIds.contains(hostId)) {
//       firstPlayer = hostId;
//     } else {
//       // Fallback to first player in order if host not found
//       firstPlayer = playerIds.isNotEmpty ? playerIds.first : '';
//     }

//     gameRef.update({
//       'gameStarted': true,
//       'gamePaused': false,
//       'turn': firstPlayer,
//       'selectedNumbers': [],
//       'playerOrder': playerIds, // Store the player order in the game data
//       'winnerId': null,
//       'winnerName': null,
//       'showWinnerDialog': false,
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
//       players[key]['board'] =
//           newBoard; // Use all numbers, not just take(maxVal)
//     }

//     // Get the player order for restart
//     final playerIds = _getPlayerOrder();
//     final hostId = gameData?['hostPlayerId'];
//     String firstPlayer;

//     if (hostId != null && playerIds.contains(hostId)) {
//       firstPlayer = hostId;
//     } else {
//       firstPlayer = playerIds.isNotEmpty ? playerIds.first : '';
//     }

//     gameRef.update({
//       'gameStarted': false,
//       'gamePaused': false,
//       'selectedNumbers': [],
//       'turn': null,
//       'players': players,
//       'playerOrder': playerIds,
//       'winnerId': null,
//       'winnerName': null,
//       'showWinnerDialog': false,
//     });

//     dialogShown = false;
//   }

//   void _continueGame() {
//     // Only host can continue the game
//     if (!isHost) return;

//     gameRef.update({
//       'showWinnerDialog': false,
//       'winnerId': null,
//       'winnerName': null,
//       'gamePaused': false,
//     });
//   }

//   void _handleNumberTap(int number) {
//     if (!isMyTurn || (gameData?['selectedNumbers'] ?? []).contains(number)) {
//       return;
//     }

//     final updatedSelectedNumbers =
//         List<int>.from(gameData?['selectedNumbers'] ?? [])..add(number);
//     final players = Map<String, dynamic>.from(gameData?['players']);
//     String? winnerId;
//     String? winnerName;

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
//         winnerName = player['name'] ?? 'Unknown';
//       }
//     }

//     // Get the next player in proper order
//     List<String> playerOrder =
//         List<String>.from(gameData?['playerOrder'] ?? _getPlayerOrder());

//     final currentIndex = playerOrder.indexOf(widget.playerId);
//     final nextIndex = (currentIndex + 1) % playerOrder.length;
//     final nextPlayerId = playerOrder[nextIndex];

//     // Prepare update data
//     Map<String, dynamic> updateData = {
//       'selectedNumbers': updatedSelectedNumbers,
//       'players': players,
//       'turn': nextPlayerId,
//       'playerOrder': playerOrder, // Ensure player order is maintained
//     };

//     // If there's a winner, add winner information and pause the game
//     if (winnerId != null && winnerName != null) {
//       updateData.addAll({
//         'winnerId': winnerId,
//         'winnerName': winnerName,
//         'showWinnerDialog': true,
//         'gamePaused': true,
//       });
//     }

//     gameRef.update(updateData);
//   }

//   List<bool> _calculateBingo(List<int> board, List<int> selected) {
//     final size = gridSize;
//     List<bool> status = List.filled(5, false);
//     List<List<int>> lines = [];

//     // Rows
//     for (int i = 0; i < size; i++) {
//       lines.add(board.sublist(i * size, (i + 1) * size));
//     }

//     // Columns
//     for (int i = 0; i < size; i++) {
//       lines.add([for (int j = 0; j < size; j++) board[j * size + i]]);
//     }

//     // Diagonal TL-BR
//     lines.add([for (int i = 0; i < size; i++) board[i * (size + 1)]]);

//     // Diagonal TR-BL
//     lines.add([for (int i = 0; i < size; i++) board[(i + 1) * (size - 1)]]);

//     int count = 0;
//     for (var line in lines) {
//       if (line.every((n) => selected.contains(n))) {
//         if (count < 5) status[count] = true;
//         count++;
//       }
//     }

//     return status;
//   }

//   Future<void> _showWinnerDialog(String winnerName, String winnerId) async {
//     if (!mounted) return;

//     final players = gameData?['players'] as Map<String, dynamic>? ?? {};
//     final playerCount = players.length;

//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
//         child: CupertinoAlertDialog(
//           title: Lottie.asset(
//               width: 200, height: 200, 'assets/Animation - 1749893443207.json'),
//           content: Text(
//             "$winnerName got BINGO!",
//             style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//           actions: [
//             // Show Continue button only if there are more than 2 players and user is host
//             if (playerCount > 2 && isHost)
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   _continueGame();
//                 },
//                 child: const Text("Continue"),
//               ),
//             // Show Restart button only if user is host
//             if (isHost)
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   _restartGame();
//                 },
//                 child: const Text("Restart"),
//               ),
//             // Show OK button for non-host players or when there are only 2 players
//             if (!isHost || playerCount <= 2)
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text("OK"),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _confettiController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedNumbers = List<int>.from(gameData?['selectedNumbers'] ?? []);
//     final color = Color(playerData?['color'] ?? Colors.grey.value);
//     final playerName = playerData?['name'] ?? "Player";
//     final players = gameData?['players'] as Map<String, dynamic>? ?? {};
//     final playerWidgets = players.entries.take(4).toList();

//     if (gameData == null || playerData == null || board.isEmpty) {
//       return Scaffold(
//         body: Center(
//             child: Lottie.asset('assets/Animation - 1749891403914.json')),
//       );
//     }

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
//           title: SizedBox(
//             width: 100,
//             child: TextFormField(
//                 initialValue: widget.gameId,
//                 readOnly: true,
//                 decoration: InputDecoration(
//                     border: OutlineInputBorder(borderSide: BorderSide.none)),
//                 style: TextStyle(
//                     fontSize: 25, color: color, fontWeight: FontWeight.w500)),
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
//                     Text(
//                         gameData?['showWinnerDialog'] == true
//                             ? "Game Paused - Winner Found!"
//                             : "Game Paused",
//                         style:
//                             const TextStyle(fontSize: 20, color: Colors.red)),

//                   // Show current turn player
//                   if (isGameStarted && !isGamePaused)
//                     Text(
//                       "Current Turn: ${_getCurrentPlayerName()}",
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                         color: Colors.blue,
//                       ),
//                     ),

//                   const SizedBox(height: 20),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: List.generate(5, (i) {
//                       const letters = ['B', 'I', 'N', 'G', 'O'];
//                       return Container(
//                         height: 60,
//                         width: 60,
//                         margin: const EdgeInsets.all(2),
//                         decoration: BoxDecoration(
//                           color: bingoStatus[i]
//                               ? Colors.red[300]
//                               : Colors.green[300],
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Center(
//                           child: bingoStatus[i]
//                               ? Icon(Icons.check, size: 40, color: Colors.white)
//                               : Text(
//                                   letters[i],
//                                   style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 30,
//                                       fontWeight: FontWeight.bold),
//                                 ),
//                         ),
//                       );
//                     }),
//                   ),
//                   const SizedBox(height: 10),
//                   Container(
//                     width: 500,
//                     decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(30),
//                         border: Border.all(
//                           width: 2,
//                           color: isMyTurn ? Colors.green : Colors.transparent,
//                         )),
//                     child: Center(
//                       child: GridView.builder(
//                         itemCount: board.length,
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                             crossAxisCount: gridSize), // Dynamic grid size
//                         itemBuilder: (_, index) {
//                           // Safety check to prevent range error
//                           if (index >= board.length) {
//                             return Container(); // Return empty container if index is out of range
//                           }
//                           final number = board[index];
//                           final selected = playerData?['selectedNumbers']
//                                   ?.contains(number) ??
//                               false;
//                           return GestureDetector(
//                             onTap: () => _handleNumberTap(number),
//                             child: Container(
//                               margin: const EdgeInsets.all(3),
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 color: selected
//                                     ? color.withOpacity(0.8)
//                                     : Colors.grey.shade200,
//                               ),
//                               child: Center(
//                                 child: Text(
//                                   "$number",
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: gridSize > 5
//                                         ? 16
//                                         : 20, // Smaller font for larger grids
//                                     color:
//                                         selected ? Colors.white : Colors.black,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//                   const Spacer(),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       if (isGameStarted &&
//                           isHost &&
//                           gameData?['showWinnerDialog'] != true)
//                         MaterialButton(
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                           color: color,
//                           height: 50,
//                           onPressed: _pauseOrResumeGame,
//                           child: Text(isGamePaused ? "Resume" : "Pause",
//                               style: const TextStyle(color: Colors.white)),
//                         ),
//                       if (!isGameStarted && isHost)
//                         MaterialButton(
//                           color: color,
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                           height: 50,
//                           onPressed: _startGame,
//                           child: const Text("Start Game",
//                               style: TextStyle(color: Colors.white)),
//                         ),
//                       const SizedBox(width: 5),
//                       if (isGameStarted &&
//                           isHost &&
//                           gameData?['showWinnerDialog'] != true)
//                         MaterialButton(
//                           color: color,
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                           height: 50,
//                           onPressed: isGamePaused ? _restartGame : null,
//                           child: Text("Restart",
//                               style: TextStyle(
//                                   color: isGamePaused
//                                       ? Colors.white
//                                       : Colors.black)),
//                         ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),

//             // Confetti Widget
//             Align(
//               alignment: Alignment.center,
//               child: ConfettiWidget(
//                 confettiController: _confettiController,
//                 blastDirectionality: BlastDirectionality.explosive,
//                 shouldLoop: false,
//                 numberOfParticles: 30,
//                 emissionFrequency: 0.1,
//               ),
//             ),

//             Positioned(
//                 top: 10,
//                 left: 10,
//                 child: _buildCornerText(playerWidgets, 0, color)),
//             Positioned(
//                 top: 10,
//                 right: 10,
//                 child: _buildCornerText(playerWidgets, 1, color)),
//             Positioned(
//                 bottom: 140,
//                 left: 10,
//                 child: _buildCornerText(playerWidgets, 2, color)),
//             Positioned(
//                 bottom: 140,
//                 right: 10,
//                 child: _buildCornerText(playerWidgets, 3, color)),
//           ],
//         ),
//       ),
//     );
//   }

//   String _getCurrentPlayerName() {
//     final currentTurn = gameData?['turn'];
//     if (currentTurn == null) return "Unknown";

//     final players = gameData?['players'] as Map<String, dynamic>?;
//     if (players == null) return "Unknown";

//     final currentPlayer = players[currentTurn];
//     return currentPlayer?['name'] ?? "Unknown";
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
import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';

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

  // Get grid size based on selectedValue
  int get gridSize {
    final selectedValue = gameData?['selectedValue'] ?? 25;
    return sqrt(selectedValue).round();
  }

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

            // Check if board needs to be regenerated due to selectedValue change
            final selectedValue = data['selectedValue'] ?? 25;
            if (board.isEmpty || board.length != selectedValue) {
              // Generate new board with correct size
              final newBoard = List.generate(selectedValue, (i) => i + 1)
                ..shuffle();
              board = newBoard;

              // Update the player's board in Firebase
              gameRef.update({
                'players.${widget.playerId}.board': newBoard,
                'players.${widget.playerId}.selectedNumbers': [],
                'players.${widget.playerId}.bingoStatus': List.filled(5, false),
              });
            }

            // Update bingoStatus based on grid size
            final size = sqrt(selectedValue).round();
            bingoStatus =
                List<bool>.from(player['bingoStatus'] ?? List.filled(5, false));
          });

          // Check if there's a winner and show dialog to all players
          final winnerId = data['winnerId'] as String?;
          final winnerName = data['winnerName'] as String?;
          final showWinnerDialog = data['showWinnerDialog'] ?? false;

          if (showWinnerDialog &&
              winnerId != null &&
              winnerName != null &&
              !dialogShown) {
            dialogShown = true;
            _confettiController.play();
            _showWinnerDialog(winnerName, winnerId);
          }

          // Reset dialog flag when game is restarted
          if (!showWinnerDialog) {
            dialogShown = false;
          }
        }
      }
    });
  }

  // Get players in the order they joined (based on joinOrder or timestamp)
  List<String> _getPlayerOrder() {
    if (gameData == null) return [];

    final players = gameData!['players'] as Map<String, dynamic>;
    final playerEntries = players.entries.toList();

    // Sort by joinOrder if available, otherwise use the order they appear
    playerEntries.sort((a, b) {
      final orderA = a.value['joinOrder'] ?? 0;
      final orderB = b.value['joinOrder'] ?? 0;
      return orderA.compareTo(orderB);
    });

    return playerEntries.map((e) => e.key).toList();
  }

  void _startGame() {
    final playerIds = _getPlayerOrder();

    // Start with the host (creator) as the first player
    final hostId = gameData?['hostPlayerId'];
    String firstPlayer;

    if (hostId != null && playerIds.contains(hostId)) {
      firstPlayer = hostId;
    } else {
      // Fallback to first player in order if host not found
      firstPlayer = playerIds.isNotEmpty ? playerIds.first : '';
    }

    gameRef.update({
      'gameStarted': true,
      'gamePaused': false,
      'turn': firstPlayer,
      'selectedNumbers': [],
      'playerOrder': playerIds, // Store the player order in the game data
      'winnerId': null,
      'winnerName': null,
      'showWinnerDialog': false,
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
      players[key]['board'] =
          newBoard; // Use all numbers, not just take(maxVal)
    }

    // Get the player order for restart
    final playerIds = _getPlayerOrder();
    final hostId = gameData?['hostPlayerId'];
    String firstPlayer;

    if (hostId != null && playerIds.contains(hostId)) {
      firstPlayer = hostId;
    } else {
      firstPlayer = playerIds.isNotEmpty ? playerIds.first : '';
    }

    gameRef.update({
      'gameStarted': false,
      'gamePaused': false,
      'selectedNumbers': [],
      'turn': null,
      'players': players,
      'playerOrder': playerIds,
      'winnerId': null,
      'winnerName': null,
      'showWinnerDialog': false,
    });

    dialogShown = false;
  }

  void _continueGame() {
    // Only host can continue the game
    if (!isHost) return;

    gameRef.update({
      'showWinnerDialog': false,
      'winnerId': null,
      'winnerName': null,
      'gamePaused': false,
    });
  }

  void _handleNumberTap(int number) {
    if (!isMyTurn || (gameData?['selectedNumbers'] ?? []).contains(number)) {
      return;
    }

    final updatedSelectedNumbers =
        List<int>.from(gameData?['selectedNumbers'] ?? [])..add(number);
    final players = Map<String, dynamic>.from(gameData?['players']);
    String? winnerId;
    String? winnerName;

    // Update all players' selected numbers and bingo status
    for (var playerId in players.keys) {
      final player = players[playerId];
      final board = List<int>.from(player['board'] ?? []);
      final selected = List<int>.from(player['selectedNumbers'] ?? []);
      if (board.contains(number)) {
        selected.add(number);
      }

      final bingo = _calculateBingo(board, selected);
      players[playerId]['selectedNumbers'] = selected;
      players[playerId]['bingoStatus'] = bingo;
    }

    // Check if the CURRENT player (who clicked) wins
    final currentPlayer = players[widget.playerId];
    if (currentPlayer != null) {
      final currentBingo = List<bool>.from(currentPlayer['bingoStatus'] ?? []);
      final isCurrentPlayerWinner = currentBingo.every((b) => b == true);

      if (isCurrentPlayerWinner && !(currentPlayer['isWinner'] ?? false)) {
        players[widget.playerId]['isWinner'] = true;
        players[widget.playerId]['score'] = (currentPlayer['score'] ?? 0) + 1;
        winnerId = widget.playerId;
        winnerName = currentPlayer['name'] ?? 'Unknown';
      }
    }

    // Get the next player in proper order
    List<String> playerOrder =
        List<String>.from(gameData?['playerOrder'] ?? _getPlayerOrder());

    final currentIndex = playerOrder.indexOf(widget.playerId);
    final nextIndex = (currentIndex + 1) % playerOrder.length;
    final nextPlayerId = playerOrder[nextIndex];

    // Prepare update data
    Map<String, dynamic> updateData = {
      'selectedNumbers': updatedSelectedNumbers,
      'players': players,
      'turn': nextPlayerId,
      'playerOrder': playerOrder, // Ensure player order is maintained
    };

    // If there's a winner, add winner information and pause the game
    if (winnerId != null && winnerName != null) {
      updateData.addAll({
        'winnerId': winnerId,
        'winnerName': winnerName,
        'showWinnerDialog': true,
        'gamePaused': true,
      });
    }

    gameRef.update(updateData);
  }

  List<bool> _calculateBingo(List<int> board, List<int> selected) {
    final size = gridSize;
    List<bool> status = List.filled(5, false);
    List<List<int>> lines = [];

    // Rows
    for (int i = 0; i < size; i++) {
      lines.add(board.sublist(i * size, (i + 1) * size));
    }

    // Columns
    for (int i = 0; i < size; i++) {
      lines.add([for (int j = 0; j < size; j++) board[j * size + i]]);
    }

    // Diagonal TL-BR
    lines.add([for (int i = 0; i < size; i++) board[i * (size + 1)]]);

    // Diagonal TR-BL
    lines.add([for (int i = 0; i < size; i++) board[(i + 1) * (size - 1)]]);

    int count = 0;
    for (var line in lines) {
      if (line.every((n) => selected.contains(n))) {
        if (count < 5) status[count] = true;
        count++;
      }
    }

    return status;
  }

  Future<void> _showWinnerDialog(String winnerName, String winnerId) async {
    if (!mounted) return;

    final players = gameData?['players'] as Map<String, dynamic>? ?? {};
    final playerCount = players.length;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFA500), // Orange
                  Color(0xFFFF6B6B), // Light Red
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with confetti background
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Trophy/Crown Icon
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Celebration text
                      const Text(
                        "🎉 WINNER! 🎉",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(25),
                      bottomRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Lottie animation
                      Lottie.asset(
                        'assets/Animation - 1749893443207.json',
                        repeat: false,
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),

                      // Winner name
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          winnerName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // BINGO text
                      const Text(
                        "got BINGO!",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 25),

                      // Action buttons
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          // Continue button (only for host with more than 2 players)
                          if (playerCount > 2 && isHost)
                            _buildActionButton(
                              label: "Continue",
                              color: const Color(0xFF4CAF50),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _continueGame();
                              },
                            ),

                          // Restart button (only for host)
                          if (isHost)
                            _buildActionButton(
                              label: "Restart",
                              color: const Color(0xFF2196F3),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _restartGame();
                              },
                            ),

                          // OK button (for non-host or 2 players only)
                          if (!isHost || playerCount <= 2)
                            _buildActionButton(
                              label: "OK",
                              color: const Color(0xFF9C27B0),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 5,
        shadowColor: color.withOpacity(0.4),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(
          Colors.white.withOpacity(0.1),
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

    if (gameData == null || playerData == null || board.isEmpty) {
      return Scaffold(
        body: Center(
            child: Lottie.asset('assets/Animation - 1749891403914.json')),
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
          title: SizedBox(
            width: 100,
            child: TextFormField(
                initialValue: widget.gameId,
                readOnly: true,
                decoration: InputDecoration(
                    border: OutlineInputBorder(borderSide: BorderSide.none)),
                style: TextStyle(
                    fontSize: 25, color: color, fontWeight: FontWeight.w500)),
          ),
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
                    Text(
                        gameData?['showWinnerDialog'] == true
                            ? "Game Paused - Winner Found!"
                            : "Game Paused",
                        style:
                            const TextStyle(fontSize: 20, color: Colors.red)),

                  // Show current turn player
                  if (isGameStarted && !isGamePaused)
                    Text(
                      "Current Turn: ${_getCurrentPlayerName()}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),

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
                        itemCount: board.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridSize), // Dynamic grid size
                        itemBuilder: (_, index) {
                          // Safety check to prevent range error
                          if (index >= board.length) {
                            return Container(); // Return empty container if index is out of range
                          }
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
                                    fontSize: gridSize > 5
                                        ? 16
                                        : 20, // Smaller font for larger grids
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
                      if (isGameStarted &&
                          isHost &&
                          gameData?['showWinnerDialog'] != true)
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
                      if (isGameStarted &&
                              isHost &&
                              gameData?['showWinnerDialog'] != true ||
                          isGamePaused)
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

  String _getCurrentPlayerName() {
    final currentTurn = gameData?['turn'];
    if (currentTurn == null) return "Unknown";

    final players = gameData?['players'] as Map<String, dynamic>?;
    if (players == null) return "Unknown";

    final currentPlayer = players[currentTurn];
    return currentPlayer?['name'] ?? "Unknown";
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
