import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD6ECFF), // top light blue
            Color(0xFFEAF6FF), // mid soft blue
            Colors.white, // bottom white
          ],
        ),
      ),
      child: child,
    );
  }
}
