import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/create_game.dart';
import 'package:bingo/view/join_game.dart';
import 'package:bingo/view/match_history.dart';
import 'package:bingo/view/leaderboard.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateJoin extends StatefulWidget {
  const CreateJoin({super.key});

  @override
  State<CreateJoin> createState() => _CreateJoinState();
}

class _CreateJoinState extends State<CreateJoin> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: netflixBlack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 700;
          final double titleSize = isTablet ? 120 : 84;
          final double spacing = isTablet ? 120 : 80;

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
                        netflixRed.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isTablet ? 500 : 400),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Hero(
                              tag: 'splash',
                              child: Column(
                                children: [
                                  Text(
                                    'BINGO',
                                    style: GoogleFonts.poppins(
                                      color: netflixRed,
                                      decoration: TextDecoration.none,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
                                      height: 1.0,
                                      shadows: [
                                        const Shadow(
                                          color: Colors.black,
                                          offset: Offset(4, 4),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.95, end: 1.05),
                                    duration: const Duration(seconds: 2),
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: netflixRed,
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(
                                                  color: netflixRed.withOpacity(
                                                      0.5 * value),
                                                  blurRadius: 10 * value)
                                            ],
                                          ),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'ORIGINAL SERIES',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: spacing),
                            Hero(
                              tag: 'create',
                              child: PremiumButton(
                                label: 'Create New Match',
                                icon: Icons.add_rounded,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CreateGamePage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Hero(
                              tag: 'join',
                              child: PremiumButton(
                                label: 'Join A Match',
                                color: netflixGrey,
                                icon: Icons.play_arrow_rounded,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const JoinGamePage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSecondaryButton(
                                    context: context,
                                    label: 'HISTORY',
                                    icon: Icons.history_rounded,
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const MatchHistoryPage())),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSecondaryButton(
                                    context: context,
                                    label: 'LEADERBOARD',
                                    icon: Icons.leaderboard_rounded,
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const LeaderboardPage())),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 64),
                            Text(
                              "NETFLIX EDITION v3.0",
                              style: GoogleFonts.poppins(
                                color: Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            )
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

  Widget _buildSecondaryButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return MaterialButton(
      onPressed: onPressed,
      color: netflixGrey.withOpacity(0.3),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
