import 'dart:math';
import 'dart:ui';
import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late String _avatarSeed;

  @override
  void initState() {
    super.initState();
    _avatarSeed = const Uuid().v4();
  }

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
        'winMode': 'Classic',
        'createdAt': FieldValue.serverTimestamp(),
        'gameStarted': false,
        'selectedNumbers': [],
        'players': {
          newPlayerId: {
            'name': name,
            'color': colors[selectedColorIndex!].value,
            'avatarSeed': _avatarSeed,
            'selectedNumbers': [],
            'bingoStatus': [false, false, false, false, false],
            'isWinner': false,
            'score': 0,
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
      backgroundColor: netflixBlack,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "CREATE BINGO MATCH",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 16,
            color: netflixRed,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 700;
          final double horizontalPadding = isTablet ? constraints.maxWidth * 0.15 : 24;
          final double formMaxWidth = isTablet ? 600 : 500;

          return Stack(
            children: [
              // Netflix background
              Container(color: netflixBlack),
              // Very subtle radial gradient from top
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.2),
                      radius: 1.5,
                      colors: [
                        netflixRed.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: formMaxWidth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            
                            // Identity Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "WHO'S PLAYING?",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _nameController,
                                  maxLength: 15,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Enter your name...",
                                    hintStyle: GoogleFonts.poppins(color: Colors.white24),
                                    filled: true,
                                    fillColor: netflixGrey,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: netflixRed, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.all(20),
                                    counterText: "",
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            
                            // Avatar Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "YOUR SHOW AVATAR",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: netflixGrey.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: netflixRed.withOpacity(0.3),
                                              width: 2),
                                        ),
                                        child: ClipOval(
                                          child: Image.network(
                                            "https://api.dicebear.com/7.x/avataaars/svg?seed=$_avatarSeed",
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Pick your premiere look",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            MaterialButton(
                                              onPressed: () {
                                                setState(() {
                                                  _avatarSeed = const Uuid().v4();
                                                });
                                              },
                                              color: netflixRed,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: Text(
                                                "SHUFFLE LOOK",
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            
                            // Color Selection Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CHOOSE YOUR AVATAR COLOR",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 60,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: colors.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final bool isSelected = selectedColorIndex == index;
                                      return GestureDetector(
                                        onTap: () => setState(() => selectedColorIndex = index),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: colors[index],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? Colors.white : Colors.transparent,
                                              width: 3,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check, color: Colors.white, size: 30)
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            
                            // Options Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildOptionGroup<int>(
                                    title: "BOARD SIZE",
                                    options: valueOptions.map((e) => {"label": "$e", "value": e}).toList(),
                                    selectedValue: selectedValue,
                                    onSelected: (val) => setState(() => selectedValue = val),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildOptionGroup<int>(
                                    title: "MAX PLAYERS",
                                    options: playerCountOptions.map((e) => {"label": "$e", "value": e}).toList(),
                                    selectedValue: maxPlayers,
                                    onSelected: (val) => setState(() => maxPlayers = val),
                                  ),
                                ),
                              ],
                            ),

                             const SizedBox(height: 16),

                            // Note: Win Mode selection removed for Normal Mode simplification

                            if (gameId != null) ...[
                              const SizedBox(height: 40),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: netflixGrey,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green, width: 1),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "GAME CREATED!",
                                      style: GoogleFonts.poppins(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SelectableText(
                                      gameId!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Share this ID with other players",
                                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
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
                                label: gameId != null ? "ENTER SHOW" : "CREATE MATCH",
                                icon: gameId != null ? Icons.play_arrow_rounded : Icons.add_rounded,
                                onPressed: _isLoading
                                    ? () {}
                                    : gameId != null
                                        ? _navigateToGame
                                        : _createGame,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOptionGroup<T>({
    required String title,
    required List<Map<String, dynamic>> options,
    required T? selectedValue,
    required Function(T) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((opt) {
            final isSelected = selectedValue == opt['value'];
            return GestureDetector(
              onTap: () => onSelected(opt['value'] as T),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? netflixRed : netflixGrey,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.05),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: netflixRed.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                child: Text(
                  "${opt['label']}",
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
