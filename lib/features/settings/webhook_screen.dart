import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';
import '../common/widgets/webhook_section.dart';

/// Where readings go: URL, optional authentication, and a test send.
class WebhookScreen extends StatelessWidget {
  const WebhookScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppPage(title: 'Webhook', children: [WebhookSection()]);
}
