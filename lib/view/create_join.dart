import 'package:bingo/utils/colors.dart';
import 'package:bingo/utils/widgets.dart';
import 'package:bingo/view/create_game.dart';
import 'package:bingo/view/join_game.dart';
import 'package:flutter/material.dart';

class CreateJoin extends StatefulWidget {
  const CreateJoin({super.key});

  @override
  State<CreateJoin> createState() => _CreateJoinState();
}

class _CreateJoinState extends State<CreateJoin> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B), // Deep Indigo
                  Color(0xFF312E81), // Indigo
                  Colors.black,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'splash',
                        child: Column(
                          children: [
                            GradientText(
                              text: 'BINGO',
                              gradient: LinearGradient(colors: colors),
                              style: const TextStyle(
                                decoration: TextDecoration.none,
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                            const Text(
                              'PREMIUM EDITION',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 64),
                      Hero(
                        tag: 'create',
                        child: PremiumButton(
                          label: 'Create New Game',
                          icon: Icons.add_circle_outline,
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
                          label: 'Join Game',
                          icon: Icons.group_add_outlined,
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
                      const SizedBox(height: 48),
                      const Text(
                        "v2.1.0 Premium",
                        style: TextStyle(
                          color: Colors.white12,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
