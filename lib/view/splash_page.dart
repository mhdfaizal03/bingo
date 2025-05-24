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

    Timer(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CreateJoin()),
      );
    });
  }

  var colorizeColors = [
    Colors.blue,
    Colors.yellow,
    Colors.red,
  ];

  var colorizeTextStyle = TextStyle(
    fontSize: 80.0,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
          child: SizedBox(
        child: AnimatedTextKit(
          animatedTexts: [
            ColorizeAnimatedText(
              'BINGO',
              textStyle: colorizeTextStyle,
              colors: colorizeColors,
            ),
          ],
          isRepeatingAnimation: true,
        ),
      )),
    );
  }
}
