import 'dart:ui';
import 'package:another_flushbar/flushbar.dart';
import 'package:bingo/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        duration: const Duration(milliseconds: 2000),
        margin: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(12),
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
    this.textAlign,
  }) : super(key: key);
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style != null
            ? GoogleFonts.poppins(textStyle: style)
            : GoogleFonts.poppins(),
        textAlign: textAlign,
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Color? borderColor;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15,
    this.opacity = 0.1,
    this.borderRadius = 16,
    this.borderColor,
    this.gradient,
    this.padding,
    this.width,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.05),
              width: 1,
            ),
            gradient: gradient,
          ),
          child: child,
        ),
      ),
    );
  }
}

class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final bool isLoading;
  final IconData? icon;

  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = color ?? netflixRed;

    return MaterialButton(
      onPressed: isLoading ? null : onPressed,
      height: 54,
      minWidth: double.infinity,
      color: buttonColor,
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                ],
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
    );
  }
}

class MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    const double spacing = 40.0;

    for (double i = 0; i < size.width + spacing; i += spacing) {
      path.moveTo(i, 0);
      path.quadraticBezierTo(
        i + 20,
        size.height / 2,
        i - 20,
        size.height,
      );
    }

    for (double i = 0; i < size.height + spacing; i += spacing) {
      path.moveTo(0, i);
      path.quadraticBezierTo(
        size.width / 2,
        i + 20,
        size.width,
        i - 20,
      );
    }

    paint.color = Colors.white.withOpacity(0.1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
