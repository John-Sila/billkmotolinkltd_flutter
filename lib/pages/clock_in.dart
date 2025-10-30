import 'package:flutter/material.dart';

class ClockIn extends StatelessWidget {
  const ClockIn({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Clocking into shift",
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
