import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late String _avatarSeed;

  @override
  void initState() {
    super.initState();
    _avatarSeed = const Uuid().v4();
  }

  List<int> generateRandomBoard(int maxValue) {
    List<int> numbers = List.generate(maxValue, (index) => index + 1);
    numbers.shuffle();
    return numbers;
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
        'avatarSeed': _avatarSeed,
        'selectedNumbers': [],
        'bingoStatus': [false, false, false, false, false],
        'isWinner': false,
        'score': 0,
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
      extendBodyBehindAppBar: true,
      backgroundColor: netflixBlack,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "JOIN A MATCH",
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
                                  "ENTER YOUR NAME",
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
                                    hintText: "What should we call you?",
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
                                      borderSide: const BorderSide(color: netflixRed, width: 2.5),
                                    ),
                                    contentPadding: const EdgeInsets.all(20),
                                    counterText: "",
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            
                            // Game ID Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "MATCH ID",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _gameIdController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 8,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "ABCD",
                                    hintStyle: GoogleFonts.poppins(color: Colors.white10),
                                    filled: true,
                                    fillColor: netflixGrey.withOpacity(0.5),
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
                                      borderSide: const BorderSide(color: netflixRed, width: 3),
                                    ),
                                    contentPadding: const EdgeInsets.all(20),
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
                                  "YOUR AVATAR",
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
                                              "Not feeling this look?",
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
                                                "SHUFFLE AVATAR",
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
                                  "YOUR PROFILE COLOR",
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
                                          duration: const Duration(milliseconds: 300),
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: colors[index],
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(
                                              color: isSelected ? Colors.white : Colors.transparent,
                                              width: isSelected ? 3 : 0,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                        color: colors[index].withOpacity(0.6),
                                                        blurRadius: 15,
                                                        spreadRadius: 2)
                                                  ]
                                                : null,
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

                            const SizedBox(height: 60),
                            
                            Hero(
                              tag: 'join',
                              child: PremiumButton(
                                isLoading: _isLoading,
                                label: "JOIN MATCH",
                                icon: Icons.play_arrow_rounded,
                                onPressed: _isLoading ? () {} : _joinGame,
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
}
