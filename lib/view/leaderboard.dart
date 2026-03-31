import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:bingo/utils/game_theme.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: GameTheme.currentTheme,
      builder: (context, currentTheme, child) {
        final theme = GameTheme.getThemeColors(currentTheme);
        return Scaffold(
          backgroundColor: theme['bg'],
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              "GLOBAL LEADERBOARD",
              style: theme['font'](
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 16,
                color: theme['accent'],
              ),
            ),
          ),
          body: Stack(
            children: [
              Container(color: theme['bg']),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.2),
                      radius: 1.5,
                      colors: [(theme['accent'] as Color).withOpacity(0.1), Colors.transparent],
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth > 700;
                  final double listMaxWidth = isTablet ? 700 : 500;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('match_history')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: theme['accent']));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.leaderboard_rounded, color: (theme['secondary'] as Color).withOpacity(0.1), size: 80),
                              const SizedBox(height: 16),
                              Text(
                                "NO DATA YET",
                                style: theme['font'](
                                  color: (theme['secondary'] as Color).withOpacity(0.24),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Aggregate wins per winnerName/Id
                      final Map<String, Map<String, dynamic>> leaderboard = {};
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['winnerName'] ?? "Unknown";
                        final id = data['winnerId'] ?? "UnknownId";
                        final avatarSeed = data['avatarSeed'] ?? id;
                        
                        if (leaderboard.containsKey(id)) {
                          leaderboard[id]!['wins'] += 1;
                        } else {
                          leaderboard[id] = {
                            'name': name,
                            'wins': 1,
                            'id': id,
                            'avatarSeed': avatarSeed,
                          };
                        }
                      }

                      final sortedList = leaderboard.values.toList()
                        ..sort((a, b) => b['wins'].compareTo(a['wins']));

                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: listMaxWidth),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                            itemCount: sortedList.length,
                            itemBuilder: (context, index) {
                              final player = sortedList[index];
                              final isTop3 = index < 3;
                              final crownColor = index == 0 ? Colors.amber : (index == 1 ? Colors.grey[300] : Colors.brown[300]);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isTop3 ? (theme['accent'] as Color).withOpacity(0.1) : (theme['card'] as Color).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isTop3 ? (theme['accent'] as Color).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                                    width: isTop3 ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      "#${index + 1}",
                                      style: theme['font'](
                                        color: isTop3 ? theme['accent'] : Colors.white38,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        color: Colors.white10,
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.network(
                                          "https://api.dicebear.com/7.x/avataaars/svg?seed=${player['avatarSeed']}",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        player['name'].toString().toUpperCase(),
                                        style: theme['font'](
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${player['wins']}",
                                          style: theme['font'](
                                            color: theme['accent'],
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                          ),
                                        ),
                                        Text(
                                          "WINS",
                                          style: theme['font'](
                                            color: Colors.white38,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isTop3) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.emoji_events_rounded, color: crownColor, size: 24),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
