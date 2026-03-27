import 'package:bingo/utils/colors.dart';
import 'package:bingo/view/create_join.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
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
  Set<int> winningIndices = {};
  bool dialogShown = false;
  bool isSoundEnabled = true;
  bool isVibrationEnabled = true;
  List<Map<String, dynamic>> _activeReactions = [];

  bool get isHost => gameData?['hostPlayerId'] == widget.playerId;
  bool get isGameStarted => gameData?['gameStarted'] ?? false;
  bool get isGamePaused => gameData?['gamePaused'] ?? false;
  bool get isMyTurn =>
      gameData?['turn'] == widget.playerId && isGameStarted && !isGamePaused;

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

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _listenToGame() {
    gameRef.snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        final players = data['players'] as Map<String, dynamic>;
        final player = players[widget.playerId] as Map<String, dynamic>?;

        if (player != null) {
          setState(() {
            gameData = data;
            playerData = player;
            board = List<int>.from(player['board'] ?? []);
            final selectedValue = data['selectedValue'] ?? 25;

            if (board.isEmpty || board.length != selectedValue) {
              final newBoard = List.generate(selectedValue, (i) => i + 1)
                ..shuffle();
              board = newBoard;
              gameRef.update({
                'players.${widget.playerId}.board': newBoard,
                'players.${widget.playerId}.selectedNumbers': [],
                'players.${widget.playerId}.bingoStatus': List.filled(5, false),
              });
            }
            final result = _calculateBingo(board, List<int>.from(player['selectedNumbers'] ?? []));
            bingoStatus = result.status;
            winningIndices = result.highlightIndices;
          });

          // Detect new reactions
          final snapshotData = snapshot.data() as Map<String, dynamic>;
          final newPlayers = snapshotData['players'] as Map<String, dynamic>? ?? {};
          final oldPlayers = gameData?['players'] as Map<String, dynamic>? ?? {};

          newPlayers.forEach((playerId, playerData) {
            final oldPlayer = oldPlayers[playerId] as Map<String, dynamic>?;
            final newReaction = playerData['lastReaction'];
            final oldReaction = oldPlayer?['lastReaction'];

            if (newReaction != null && (oldReaction == null || newReaction['time'] != oldReaction['time'])) {
              _showFloatingEmoji(playerId, newReaction['emoji']);
            }
          });

          final winnerId = data['winnerId'] as String?;
          final winnerName = data['winnerName'] as String?;
          final showWinnerDialog = data['showWinnerDialog'] ?? false;

          if (showWinnerDialog &&
              winnerId != null &&
              winnerName != null &&
              !dialogShown) {
            dialogShown = true;
            _confettiController.play();
            _logMatchToHistory(winnerId, winnerName);
            _showWinnerDialog(winnerName, winnerId);
          }

          if (!showWinnerDialog) {
            dialogShown = false;
          }
        }
      }
    });
  }

  void _startGame() {
    final players = gameData?['players'] as Map<String, dynamic>? ?? {};
    final playerIds = players.keys.toList();
    final hostId = gameData?['hostPlayerId'] ?? playerIds.first;

    gameRef.update({
      'gameStarted': true,
      'gamePaused': false,
      'turn': hostId,
      'selectedNumbers': [],
      'playerOrder': playerIds,
      'winnerId': null,
      'winnerName': null,
      'showWinnerDialog': false,
    });
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
      players[key]['bingoStatus'] = List.filled(5, false);
      players[key]['isWinner'] = false;
      players[key]['board'] = newBoard;
    }

    final playerIds = players.keys.toList();
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
    if (!isHost) return;
    gameRef.update({
      'showWinnerDialog': false,
      'winnerId': null,
      'winnerName': null,
      'gamePaused': false,
    });
  }

  void _handleNumberTap(int number) {
    if (!isMyTurn ||
        (gameData?['selectedNumbers'] ?? []).contains(number) ||
        gameData?['gamePaused'] == true)
      return;

    if (isSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    if (isVibrationEnabled) {
      HapticFeedback.mediumImpact();
    }

    final updatedSelectedNumbers =
        List<int>.from(gameData?['selectedNumbers'] ?? [])..add(number);
    final players = Map<String, dynamic>.from(gameData?['players']);
    String? winnerId;
    String? winnerName;
    List<String> newWinnerNames = [];

    for (var playerId in players.keys) {
      final player = players[playerId];
      final board = List<int>.from(player['board'] ?? []);
      final selected = List<int>.from(player['selectedNumbers'] ?? []);
      if (board.contains(number)) selected.add(number);

      final result = _calculateBingo(board, selected);
      final bingo = result.status;
      players[playerId]['selectedNumbers'] = selected;
      players[playerId]['bingoStatus'] = bingo;

      if (playerId == widget.playerId) {
        winningIndices = result.highlightIndices;
      }

      final isNowWinner = bingo.every((b) => b == true);
      final wasAlreadyWinner = player['isWinner'] ?? false;

      if (isNowWinner && !wasAlreadyWinner) {
        players[playerId]['isWinner'] = true;
        players[playerId]['score'] = (player['score'] ?? 0) + 1;
        newWinnerNames.add(player['name'] ?? 'Unknown');
        winnerId = playerId;
      }
    }

    if (newWinnerNames.isNotEmpty) winnerName = newWinnerNames.join(" & ");

    final playerOrder =
        List<String>.from(gameData?['playerOrder'] ?? players.keys.toList());
    final currentIndex = playerOrder.indexOf(widget.playerId);
    final nextIndex = (currentIndex + 1) % playerOrder.length;
    final nextPlayerId = playerOrder[nextIndex];

    Map<String, dynamic> updateData = {
      'selectedNumbers': updatedSelectedNumbers,
      'players': players,
      'turn': nextPlayerId,
    };

    if (winnerId != null && winnerName != null) {
      updateData.addAll({
        'winnerId': winnerId,
        'winnerName': winnerName,
        'showWinnerDialog': true,
        'gamePaused': true,
      });
    }

    gameRef.update(updateData);
    setState(() {});
  }
  Future<void> _logMatchToHistory(String winnerId, String winnerName) async {
    if (!isHost) return; // Only host logs the history to avoid duplicates
    try {
      final historyRef = FirebaseFirestore.instance.collection('match_history');
      await historyRef.add({
        'gameId': widget.gameId,
        'winnerId': winnerId,
        'winnerName': winnerName,
        'avatarSeed': gameData?['players'][winnerId]['avatarSeed'],
        'winMode': gameData?['winMode'] ?? 'Classic',
        'players': gameData?['players'],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error logging match history: $e");
    }
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;
    FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .collection('messages')
        .add({
      'senderId': widget.playerId,
      'senderName': gameData?['players'][widget.playerId]['name'] ?? 'Player',
      'text': text,
      'avatarSeed': gameData?['players'][widget.playerId]['avatarSeed'],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: netflixBlack.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("LOCKER ROOM CHAT",
                        style: GoogleFonts.poppins(
                            color: netflixRed,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('games')
                          .doc(widget.gameId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final msgs = snapshot.data!.docs;
                        return ListView.builder(
                          controller: controller,
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: msgs.length,
                          itemBuilder: (context, index) {
                            final m = msgs[index].data() as Map<String, dynamic>;
                            final isMe = m['senderId'] == widget.playerId;
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? netflixRed : netflixGrey,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(m['senderName'],
                                          style: GoogleFonts.poppins(
                                              color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text(m['text'],
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _buildChatInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    final TextEditingController _msgController = TextEditingController();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: netflixGrey,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type a taunt...",
                hintStyle: GoogleFonts.poppins(color: Colors.white24),
                border: InputBorder.none,
              ),
              onSubmitted: (val) {
                _sendMessage(val);
                _msgController.clear();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: netflixRed),
            onPressed: () {
              _sendMessage(_msgController.text);
              _msgController.clear();
            },
          ),
        ],
      ),
    );
  }

  void _showFloatingEmoji(String playerId, String emoji) {
    if (!mounted) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _activeReactions.add({
        'id': id,
        'emoji': emoji,
        'playerId': playerId,
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _activeReactions.removeWhere((r) => r['id'] == id);
        });
      }
    });
  }

  void _sendReaction(String emoji) {
    gameRef.update({
      'players.${widget.playerId}.lastReaction': {
        'emoji': emoji,
        'time': DateTime.now().millisecondsSinceEpoch,
      }
    });
  }

  void _shuffleMyAvatar() {
    gameRef.update({
      'players.${widget.playerId}.avatarSeed': const Uuid().v4(),
    });
  }

  ({List<bool> status, Set<int> highlightIndices}) _calculateBingo(
      List<int> board, List<int> selected) {
    final size = gridSize;
    List<bool> status = List.filled(5, false);
    Set<int> highlightIndices = {};

    List<List<int>> lines = [];
    List<List<int>> lineIndices = [];

    // Rows
    for (int i = 0; i < size; i++) {
      lines.add(board.sublist(i * size, (i + 1) * size));
      lineIndices.add([for (int j = 0; j < size; j++) i * size + j]);
    }
    // Columns
    for (int i = 0; i < size; i++) {
      lines.add([for (int j = 0; j < size; j++) board[j * size + i]]);
      lineIndices.add([for (int j = 0; j < size; j++) j * size + i]);
    }
    // Diagonals
    lines.add([for (int i = 0; i < size; i++) board[i * (size + 1)]]);
    lineIndices.add([for (int i = 0; i < size; i++) i * (size + 1)]);

    lines.add([for (int i = 0; i < size; i++) board[(i + 1) * (size - 1)]]);
    lineIndices.add([for (int i = 0; i < size; i++) (i + 1) * (size - 1)]);

    int count = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].every((n) => selected.contains(n))) {
        if (count < 5) status[count] = true;
        highlightIndices.addAll(lineIndices[i]);
        count++;
      }
    }
    return (status: status, highlightIndices: highlightIndices);
  }

  String _getCurrentPlayerName() {
    final turnId = gameData?['turn'];
    final players = gameData?['players'] as Map<String, dynamic>? ?? {};
    return players[turnId]?['name'] ?? "Waiting...";
  }

  @override
  Widget build(BuildContext context) {
    if (gameData == null || playerData == null || board.isEmpty) {
      return const Scaffold(
        backgroundColor: netflixBlack,
        body: Center(child: CircularProgressIndicator(color: netflixRed)),
      );
    }

    final isMyTurn = gameData?['turn'] == widget.playerId;
    final playerName = playerData?['name'] ?? "Player";
    final playerColor = Color(playerData?['color'] ?? Colors.grey.value);
    final selectedNumbers = List<int>.from(gameData?['selectedNumbers'] ?? []);
    final playersMap = gameData?['players'] as Map<String, dynamic>? ?? {};
    final playerList = playersMap.entries.toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: netflixGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: Text('Exit Game?',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text('Are you sure you want to leave?',
                  style: GoogleFonts.poppins(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('STAY',
                      style: GoogleFonts.poppins(
                          color: Colors.white60, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('LEAVE',
                      style: GoogleFonts.poppins(
                          color: netflixRed, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
        if (shouldLeave == true && context.mounted) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const CreateJoin()),
              (route) => false);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            isGameStarted ? "GAME ID: ${widget.gameId}" : "WAITING FOR PLAYERS",
            style: GoogleFonts.poppins(
                color: netflixRed,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2),
          ),
          actions: [
            IconButton(
              icon: Icon(
                isVibrationEnabled
                    ? Icons.vibration_rounded
                    : Icons.browser_not_supported_rounded,
                color: isVibrationEnabled ? netflixRed : Colors.white38,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => isVibrationEnabled = !isVibrationEnabled),
            ),
            IconButton(
              icon: Icon(
                isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: isSoundEnabled ? netflixRed : Colors.white38,
                size: 18,
              ),
              onPressed: () => setState(() => isSoundEnabled = !isSoundEnabled),
            ),
            if (isHost && isGameStarted)
              IconButton(
                icon: Icon(
                    isGamePaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: Colors.white),
                onPressed: _pauseOrResumeGame,
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white60),
              onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateJoin()),
                  (route) => false),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;
            final double horizontalPadding = isTablet ? constraints.maxWidth * 0.1 : 24;
            final double gridMaxWidth = isTablet ? 550 : double.infinity;

            return Stack(
              children: [
                Container(color: netflixBlack),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -1.2),
                        radius: 1.5,
                        colors: [netflixRed.withOpacity(0.15), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _buildPlayerStats(playerList),
                          Padding(
                            padding: const EdgeInsets.only(right: 24, bottom: 8),
                            child: _buildReactionPicker(),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding, vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.1, end: 1.0),
                                    duration: const Duration(seconds: 1),
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: isMyTurn ? value : 1.0,
                                        child: Text(
                                          isMyTurn
                                              ? "YOUR TURN"
                                              : (isGameStarted ? "WAITING" : "LOBBY"),
                                          style: GoogleFonts.poppins(
                                              color: isMyTurn ? playerColor : netflixRed,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              letterSpacing: 2,
                                              shadows: isMyTurn
                                                  ? [
                                                      BoxShadow(
                                                          color: playerColor
                                                              .withOpacity(0.5 * value),
                                                          blurRadius: 10 * value)
                                                    ]
                                                  : null),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isGameStarted
                                        ? (isMyTurn
                                            ? playerName.toUpperCase()
                                            : _getCurrentPlayerName().toUpperCase())
                                        : "BINGO MATCH",
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        letterSpacing: -0.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            _buildBingoLetterRow(playerColor),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: gridMaxWidth),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: netflixGrey,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            isMyTurn ? netflixRed : Colors.white10,
                                        width: isMyTurn ? 2 : 1),
                                  ),
                                  child: isGameStarted
                                      ? GridView.builder(
                                          itemCount: board.length,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: gridSize,
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 10,
                                          ),
                                          itemBuilder: (context, index) {
                                            final number = board[index];
                                            return _buildGridCell(
                                              number: number,
                                              isSelected:
                                                  selectedNumbers.contains(number),
                                              isWinningCell:
                                                  winningIndices.contains(index),
                                              isMyTurn: isMyTurn,
                                              playerColor: playerColor,
                                            );
                                          },
                                        )
                                      : Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                  Icons.play_circle_fill_rounded,
                                                  size: 80,
                                                  color: playerColor),
                                              const SizedBox(height: 24),
                                              Text(
                                                "READY TO PLAY?\n(${playerList.length}/${gameData?['maxPlayers'] ?? '?'})",
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 18,
                                                    letterSpacing: 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isHost && !isGameStarted)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: _buildNetflixButton("START BINGO MATCH",
                              Icons.play_arrow_rounded, playerColor, _startGame),
                        )
                      else if (isHost && isGameStarted)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildNetflixButton(
                                    isGamePaused ? "RESUME" : "PAUSE",
                                    isGamePaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    netflixRed,
                                    _pauseOrResumeGame),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildNetflixButton("RESTART",
                                    Icons.refresh_rounded, netflixGrey, _restartGame),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Floating Chat Trigger
                Positioned(
                  bottom: 30,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: _showChat,
                    backgroundColor: netflixRed,
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                  ),
                ),

                // Reactions
                ..._activeReactions.map((r) => _buildFloatingEmoji(r)),

                // Confetti
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [netflixRed, Colors.white, Colors.black26],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerStats(List<MapEntry<String, dynamic>> players) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final p = players[index].value;
          final bool isMe = players[index].key == widget.playerId;
          final bool isTurn = gameData?['turn'] == players[index].key;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: isTurn
                  ? const Border(
                      bottom: BorderSide(color: netflixRed, width: 4))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.05),
                      border: isTurn
                          ? Border.all(color: Colors.white, width: 2)
                          : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: isMe ? _shuffleMyAvatar : null,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Opacity(
                              opacity: isTurn ? 1.0 : 0.6,
                              child: Stack(
                                children: [
                                  Image.network(
                                    "https://api.dicebear.com/7.x/avataaars/svg?seed=${p['avatarSeed'] ?? players[index].key}",
                                    fit: BoxFit.cover,
                                  ),
                                  if (isMe)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black12,
                                        child: const Icon(Icons.shuffle,
                                            color: Colors.white54, size: 16),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: netflixRed,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              "${p['score'] ?? 0}",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p['name'] + (isMe ? " (YOU)" : ""),
                    style: GoogleFonts.poppins(
                        color: isTurn ? Colors.white : Colors.white60,
                        fontWeight: isTurn ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 12),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBingoLetterRow(Color themeColor) {
    const letters = ['B', 'I', 'N', 'G', 'O'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final active = bingoStatus[i];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(left: 8),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? themeColor : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: Colors.white, width: 2)
                : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: themeColor.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1)
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              letters[i],
              style: GoogleFonts.poppins(
                  color: active ? Colors.white : Colors.white24,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  shadows: active
                      ? [const Shadow(color: Colors.black45, blurRadius: 4)]
                      : null),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGridCell({
    required int number,
    required bool isSelected,
    required bool isWinningCell,
    required bool isMyTurn,
    required Color playerColor,
  }) {
    return GestureDetector(
      onTap: () => _handleNumberTap(number),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        decoration: BoxDecoration(
          color: isWinningCell
              ? playerColor
              : (isSelected ? playerColor.withOpacity(0.85) : netflixGrey),
          borderRadius: BorderRadius.circular(15),
          gradient: isWinningCell || isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                )
              : null,
          border: Border.all(
            color: isWinningCell
                ? Colors.white
                : (isSelected
                    ? Colors.white.withOpacity(0.6)
                    : Colors.white.withOpacity(0.05)),
            width: isWinningCell ? 2.5 : 1,
          ),
          boxShadow: [
            if (isWinningCell)
              BoxShadow(
                color: playerColor.withOpacity(0.7),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            if (isSelected && !isWinningCell)
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(2, 2),
              ),
          ],
        ),
        child: Center(
          child: Text(
            "$number",
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: gridSize > 6 ? 16 : 22,
                shadows: isWinningCell
                    ? [const Shadow(color: Colors.black26, blurRadius: 4)]
                    : null),
          ),
        ),
      ),
    );
  }

  Future<void> _showWinnerDialog(String winnerName, String winnerId) async {
    if (!mounted) return;

    if (isSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
      Future.delayed(const Duration(milliseconds: 200),
          () => SystemSound.play(SystemSoundType.click));
    }
    if (isVibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
    final players = gameData?['players'] as Map<String, dynamic>? ?? {};
    final playerCount = players.length;
    final winnerData = players[winnerId] as Map<String, dynamic>?;
    final winnerColor = Color(winnerData?['color'] ?? netflixRed.value);

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Winner",
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 450),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [netflixGrey, netflixBlack.withOpacity(0.9)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                        color: winnerColor.withOpacity(0.3),
                        blurRadius: 50,
                        spreadRadius: 10)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Lottie.asset('assets/Animation - 1749893443207.json',
                            repeat: true,
                            width: 300,
                            height: 250,
                            fit: BoxFit.contain),
                        Positioned(
                          top: -60,
                          child: Icon(Icons.stars_rounded,
                              size: 100, color: Colors.amber.shade400),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: winnerColor,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                    color: winnerColor.withOpacity(0.5),
                                    blurRadius: 10)
                              ],
                            ),
                            child: Text("BINGO!",
                                style: GoogleFonts.poppins(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 4)),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
                      child: Column(
                        children: [
                          Text("CONGRATULATIONS",
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.amber.shade400,
                                  letterSpacing: 4)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundImage: NetworkImage(
                                        "https://api.dicebear.com/7.x/avataaars/svg?seed=${gameData?['players'][winnerId]['avatarSeed'] ?? winnerId}"),
                                  ),
                                const SizedBox(height: 12),
                                Text(winnerName.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Scoreboard / Standings
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "FINAL STANDINGS",
                                      style: GoogleFonts.poppins(
                                          color: Colors.white38,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          letterSpacing: 2),
                                    ),
                                    Text(
                                      "SCORE",
                                      style: GoogleFonts.poppins(
                                          color: Colors.white38,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          letterSpacing: 2),
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white10, height: 20),
                                ...players.entries.map((entry) {
                                  final player = entry.value;
                                  final isWinnerRow = entry.key == winnerId;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.white10,
                                          child: ClipOval(
                                            child: Image.network(
                                              "https://api.dicebear.com/7.x/avataaars/svg?seed=${player['avatarSeed'] ?? entry.key}",
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.person,
                                                      size: 14,
                                                      color: Colors.white24),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            player['name'] +
                                                (entry.key == widget.playerId
                                                    ? " (YOU)"
                                                    : ""),
                                            style: GoogleFonts.poppins(
                                                color: isWinnerRow
                                                    ? Colors.white
                                                    : Colors.white70,
                                                fontWeight: isWinnerRow
                                                    ? FontWeight.w900
                                                    : FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        ),
                                        if (isWinnerRow)
                                          const Icon(Icons.stars_rounded,
                                              color: Colors.amber, size: 18),
                                        const SizedBox(width: 12),
                                        Text(
                                          "${player['score'] ?? 0}",
                                          style: GoogleFonts.poppins(
                                              color: isWinnerRow
                                                  ? winnerColor
                                                  : Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Column(
                            children: [
                              if (playerCount > 2 && isHost)
                                _buildNetflixButton("CONTINUE GAME",
                                    Icons.play_arrow_rounded, netflixRed, () {
                                  Navigator.of(context).pop();
                                  _continueGame();
                                }),
                              if (isHost) ...[
                                const SizedBox(height: 12),
                                _buildNetflixButton("RESTART MATCH",
                                    Icons.refresh_rounded, Colors.white12, () {
                                  Navigator.of(context).pop();
                                  _restartGame();
                                }),
                              ],
                              if (!isHost || playerCount <= 2)
                                _buildNetflixButton(
                                    "VIEW RESULTS",
                                    Icons.visibility_outlined,
                                    winnerColor,
                                    () => Navigator.of(context).pop()),
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
      },
    );
  }

  Widget _buildReactionPicker() {
    final emojis = ["🔥", "👏", "😂", "🤯", "💯", "🎉"];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: netflixBlack.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((e) {
          return GestureDetector(
            onTap: () => _sendReaction(e),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(e, style: const TextStyle(fontSize: 20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloatingEmoji(Map<String, dynamic> reaction) {
    // Basic logic to find player card position for the emoji
    return Positioned(
      bottom: 200,
      left: MediaQuery.of(context).size.width / 2,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 2),
        builder: (context, value, child) {
          return Opacity(
            opacity: 1 - value,
            child: Transform.translate(
              offset: Offset(0, -200 * value),
              child: Text(reaction['emoji'],
                  style: const TextStyle(fontSize: 40)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetflixButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: MaterialButton(
        onPressed: onPressed,
        color: color,
        elevation: 0,
        highlightElevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: color == netflixRed ? Colors.white : Colors.white70,
                size: 24),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    color: color == netflixRed ? Colors.white : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
