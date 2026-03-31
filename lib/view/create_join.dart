import 'package:bingo/view/match_history.dart';
import 'package:bingo/view/leaderboard.dart';
import 'package:bingo/utils/game_theme.dart';
import 'package:flutter/material.dart';
import 'package:bingo/view/create_game.dart';
import 'package:bingo/view/join_game.dart';
import 'package:bingo/view/spectate_game.dart';

class CreateJoin extends StatefulWidget {
  const CreateJoin({super.key});

  @override
  State<CreateJoin> createState() => _CreateJoinState();
}

class _CreateJoinState extends State<CreateJoin> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: GameTheme.currentTheme,
      builder: (context, currentTheme, child) {
        final theme = GameTheme.getThemeColors(currentTheme);
        return Scaffold(
          backgroundColor: theme['bg'],
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 700;
              final double titleSize = isTablet ? 120 : 84;
              final double spacing = isTablet ? 120 : 80;

              return Stack(
                children: [
                  // Background layer
                  Container(color: theme['bg']),
                  
                  // Premium Asset Background (Only for Netflix theme)
                  if (currentTheme == 'Netflix')
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.4,
                        child: Image.asset(
                          'assets/images/movie_flex.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // Subtle radial gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -1.2),
                          radius: 1.5,
                          colors: [
                            (theme['accent'] as Color).withOpacity(0.15),
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
                                        style: theme['font'](
                                          color: theme['accent'],
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
                                                color: theme['accent'],
                                                borderRadius: BorderRadius.circular(4),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: (theme['accent'] as Color).withOpacity(
                                                          0.5 * value),
                                                      blurRadius: 10 * value)
                                                ],
                                              ),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          currentTheme == 'Netflix' ? 'ORIGINAL SERIES' : (currentTheme == 'Cyberpunk' ? 'FUTURE TECH' : 'ROYAL CASINO'),
                                          style: theme['font'](
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
                                  child: _buildPremiumButton(
                                    label: 'Create New Match',
                                    icon: Icons.add_rounded,
                                    theme: theme,
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
                                  child: _buildPremiumButton(
                                    label: 'Join A Match',
                                    theme: theme,
                                    isSecondary: true,
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
                                const SizedBox(height: 16),
                                Hero(
                                  tag: 'spectate',
                                  child: _buildPremiumButton(
                                    label: 'Spectate A Match',
                                    theme: theme,
                                    isSecondary: true,
                                    icon: Icons.visibility_rounded,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SpectateGamePage(),
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
                                        theme: theme,
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
                                        theme: theme,
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
                                  "${currentTheme.toUpperCase()} EDITION v3.0",
                                  style: theme['font'](
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
      },
    );
  }

  Widget _buildPremiumButton({
    required String label,
    required IconData icon,
    required Map<String, dynamic> theme,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return MaterialButton(
      onPressed: onPressed,
      color: isSecondary ? theme['card'] : theme['accent'],
      elevation: 10,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSecondary ? BorderSide(color: Colors.white.withOpacity(0.1)) : BorderSide.none,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: theme['font'](
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Map<String, dynamic> theme,
    required VoidCallback onPressed,
  }) {
    return MaterialButton(
      onPressed: onPressed,
      color: (theme['card'] as Color).withOpacity(0.3),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme['accent'], size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme['font'](
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
