import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../core/vehicles/device_id.dart';
import '../../../core/webhook/payload.dart';
import '../../../ui/ui.dart';
import '../../common/widgets/webhook_section.dart';

/// The webhook URL with a test send, and what a reading will look like.
class WebhookStep extends StatelessWidget {
  const WebhookStep({
    super.key,
    required this.vehicleName,
    required this.onTested,
  });

  final String vehicleName;
  final ValueChanged<bool> onTested;

  @override
  Widget build(BuildContext context) {
    final sample = const JsonEncoder.withIndent('  ').convert(
      buildPayload(
        device: deviceIdFor(vehicleName),
        seq: 1,
        timestamp: DateTime.now(),
        values: const {
          'fuel_level_l': 47.5,
          'odometer_km': 33999,
          'battery_v': 13.6,
          'coolant_temp_c': 89,
        },
        connected: true,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WebhookSection(onTested: onTested),
        const SectionHeader('What a reading looks like'),
        CodeBlock(child: Text(sample)),
      ],
    );
  }
}
