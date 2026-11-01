import 'package:flutter/material.dart';

import 'debug/debug_screen.dart';
import 'settings/settings_store.dart';

void main() {
  runApp(PitwallApp(store: SettingsStore()));
}

class PitwallApp extends StatelessWidget {
  const PitwallApp({super.key, required this.store});

  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitwall',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: DebugScreen(store: store),
    );
  }
}
