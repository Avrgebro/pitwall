import 'package:flutter/material.dart';

import 'debug/debug_screen.dart';

void main() {
  runApp(const PitwallApp());
}

class PitwallApp extends StatelessWidget {
  const PitwallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitwall',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const DebugScreen(),
    );
  }
}
