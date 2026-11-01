import 'package:flutter/material.dart';

import 'debug/debug_screen.dart';
import 'settings/settings_store.dart';
import 'webhook/delivery_storage.dart';
import 'webhook/webhook_sender.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SettingsStore();
  final sender = WebhookSender(
    storage: FileDeliveryStorage(),
    webhookUrl: store.loadWebhookUrl,
  );
  await sender.init();
  runApp(PitwallApp(store: store, sender: sender));
}

class PitwallApp extends StatelessWidget {
  const PitwallApp({super.key, required this.store, required this.sender});

  final SettingsStore store;
  final WebhookSender sender;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitwall',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: DebugScreen(store: store, sender: sender),
    );
  }
}
