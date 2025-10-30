import 'package:flutter/material.dart';

class ClockOut extends StatelessWidget {
  const ClockOut({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Clocking out of shift",
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
