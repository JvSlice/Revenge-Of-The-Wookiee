import 'package:flutter/material.dart';
import 'game/game_page.dart';

void main() {
  runApp(const CanopyDefenseApp());
}

class CanopyDefenseApp extends StatelessWidget {
  const CanopyDefenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canopy Defense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}
