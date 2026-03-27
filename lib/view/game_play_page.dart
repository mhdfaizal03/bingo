import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';
import 'dart:ui';

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
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
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
                      child: Column(
                        children: [
                          Lottie.asset(
                            'assets/Animation - 1749893443207.json',
                            repeat: false,
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 20),

                          // Winner name glass card
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
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
                          const Text(
                            "got BINGO!",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 25),

                          // Action buttons
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              if (playerCount > 2 && isHost)
                                _buildGlassButton("Continue", Colors.green, () {
                                  Navigator.of(context).pop();
                                  _continueGame();
                                }),
                              if (isHost)
                                _buildGlassButton("Restart", Colors.blue, () {
                                  Navigator.of(context).pop();
                                  _restartGame();
                                }),
                              if (!isHost || playerCount <= 2)
                                _buildGlassButton("OK", Colors.purple, () {
                                  Navigator.of(context).pop();
                                }),
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
        ),
      ),
    );
  }

  Widget _buildGlassButton(String label, Color color, VoidCallback onPressed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: MaterialButton(
            onPressed: onPressed,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
    if (gameData == null || playerData == null || board.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.indigoAccent),
        ),
      );
    }

    final playerName = playerData?['name'] ?? "Player";
    final playerColor = Color(playerData?['color'] ?? Colors.grey.value);
    final selectedNumbers = List<int>.from(gameData?['selectedNumbers'] ?? []);

    return WillPopScope(
      onWillPop: () async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: AlertDialog(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  title: const Text('Exit Game?',
                      style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to leave?',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay',
                          style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Leave',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            ) ??
            false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag, size: 16, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  widget.gameId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (isHost)
              IconButton(
                icon: Icon(
                  isGamePaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Colors.white,
                ),
                onPressed: _pauseOrResumeGame,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            // Premium background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E1B4B), // Deep Indigo
                    Color(0xFF0F172A), // Slate 900
                    Colors.black,
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Turn Indicator and Player Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMyTurn ? "YOUR TURN" : "WAITING FOR...",
                                style: TextStyle(
                                  color: isMyTurn
                                      ? Colors.emeraldAccent
                                      : Colors.white38,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isMyTurn ? playerName : _getCurrentPlayerName(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _buildBingoLetterRow(),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: GlassContainer(
                              padding: const EdgeInsets.all(12),
                              borderRadius: 24,
                              borderColor: isMyTurn
                                  ? Colors.indigoAccent.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.1),
                              child: GridView.builder(
                                itemCount: board.length,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridSize,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemBuilder: (context, index) {
                                  final number = board[index];
                                  final isGloballySelected =
                                      selectedNumbers.contains(number);

                                  return _buildGridCell(
                                    number: number,
                                    isSelected: isGloballySelected,
                                    isMyTurn: isMyTurn,
                                    playerColor: playerColor,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Game Status Footer
                  if (isGamePaused && !dialogShown)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        borderRadius: 30,
                        backgroundColor: Colors.red.withOpacity(0.2),
                        child: const Text(
                          "GAME PAUSED",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBingoLetterRow() {
    const letters = ['B', 'I', 'N', 'G', 'O'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final active = bingoStatus[i];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(left: 6),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? Colors.indigoAccent
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? Colors.white : Colors.white24,
              width: 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.5),
                        blurRadius: 8)
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              letters[i],
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGridCell({
    required int number,
    required bool isSelected,
    required bool isMyTurn,
    required Color playerColor,
  }) {
    return GestureDetector(
      onTap: () => _handleNumberTap(number),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? playerColor.withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? playerColor
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: playerColor.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 8,
                  )
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Positioned.fill(
                child: CustomPaint(
                  painter: _ShinePainter(color: playerColor.withOpacity(0.2)),
                ),
              ),
            Text(
              "$number",
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                fontSize: gridSize > 6 ? 14 : 18,
              ),
            ),
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
}

class _ShinePainter extends CustomPainter {
  final Color color;
  _ShinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
