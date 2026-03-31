import 'package:bingo/utils/game_theme.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/game_play_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class SpectateGamePage extends StatefulWidget {
  const SpectateGamePage({super.key});

  @override
  State<SpectateGamePage> createState() => _SpectateGamePageState();
}

class _SpectateGamePageState extends State<SpectateGamePage> {
  final TextEditingController _gameIdController = TextEditingController();
  bool _isLoading = false;

  void _spectateGame() async {
    final gameId = _gameIdController.text.trim();
    if (gameId.isEmpty) {
      CustomSnackBar.show(
        context: context,
        message: "Please enter a valid Game ID",
        color: Colors.redAccent,
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('games').doc(gameId).get();
      
      if (!doc.exists) {
        if (mounted) {
          CustomSnackBar.show(
            context: context,
            message: "Match not found!",
            color: Colors.redAccent,
            icon: Icons.search_off_rounded,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        // Use a temporary spectator ID that won't be in the players map
        final spectatorId = "spectator_${const Uuid().v4().substring(0, 8)}";
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GamePlayPage(
              gameId: gameId,
              playerId: spectatorId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: "Error: $e",
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: GameTheme.currentTheme,
      builder: (context, currentTheme, child) {
        final theme = GameTheme.getThemeColors(currentTheme);
        return Scaffold(
          backgroundColor: theme['bg'],
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "SPECTATE MATCH",
              style: theme['font'](
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 18,
              ),
            ),
          ),
          body: Stack(
            children: [
              if (currentTheme == 'Netflix')
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: Image.asset('assets/images/movie_flex.png', fit: BoxFit.cover),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.visibility_rounded, size: 64, color: theme['accent']),
                          const SizedBox(height: 24),
                          Text(
                            "ENTER GAME ID",
                            style: theme['font'](
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Watch the match live without playing.",
                            textAlign: TextAlign.center,
                            style: theme['font'](color: Colors.white60, fontSize: 13),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _gameIdController,
                            style: theme['font'](color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Example: abc-123-xyz",
                              hintStyle: theme['font'](color: Colors.white24),
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme['accent']),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          PremiumButton(
                            label: "ENTER SPECTATOR BOX",
                            isLoading: _isLoading,
                            onPressed: _spectateGame,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
