import 'package:flutter/material.dart';

class Requirements extends StatelessWidget {
  const Requirements({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Require users to redo clockouts",
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
