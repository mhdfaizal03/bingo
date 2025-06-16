import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:bingo/view/create_join.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Navigate to CreateJoin after 3 seconds with smooth transition
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (_, __, ___) => const CreateJoin(),
        ),
      );
    });
  }

  // Vibrant color combination for animated splash text
  final colorizeColors = const [
    Color(0xFFE91E63), // Vibrant Pink
    Color(0xFFFFC107), // Amber
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
  ];

  final colorizeTextStyle = const TextStyle(
    fontSize: 70.0,
    fontWeight: FontWeight.w900,
    letterSpacing: 4,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 26, 0, 33),
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: Hero(
            tag: 'splash',
            child: AnimatedTextKit(
              animatedTexts: [
                ColorizeAnimatedText(
                  'BINGO',
                  textStyle: colorizeTextStyle,
                  colors: colorizeColors,
                ),
              ],
              isRepeatingAnimation: true,
              totalRepeatCount: 10,
              pause: const Duration(milliseconds: 200),
            ),
          ),
        ),
      ),
    );
  }
}
