import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    Color color = Colors.black,
    IconData icon = Icons.info_outline,
  }) {
    if (context.mounted) {
      Flushbar(
        isDismissible: true,
        message: message,
        backgroundColor: color,
        flushbarPosition: FlushbarPosition.TOP,
        duration: Duration(milliseconds: 2000),
        margin: EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(8),
        icon: Icon(icon, color: Colors.white),
      )..show(context);
    }
  }
}

class GradientText extends StatelessWidget {
  const GradientText({
    Key? key,
    required this.text,
    this.style,
    required this.gradient,
  }) : super(key: key);
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
