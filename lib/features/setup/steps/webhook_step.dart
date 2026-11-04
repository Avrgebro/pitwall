import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../core/readings/metric.dart';
import '../../../core/vehicles/device_id.dart';
import '../../../core/webhook/payload.dart';
import '../../../ui/ui.dart';
import '../../common/widgets/webhook_section.dart';

/// The webhook URL with a test send, and what a reading will look like.
class WebhookStep extends StatelessWidget {
  const WebhookStep({super.key, required this.vehicleName});

  final String vehicleName;

  @override
  Widget build(BuildContext context) {
    final sample = const JsonEncoder.withIndent('  ').convert(
      buildPayload(
        device: deviceIdFor(vehicleName),
        seq: 1,
        timestamp: DateTime.now(),
        values: {
          Metrics.fuelLevel.key: 87.5,
          Metrics.odometer.key: 33999,
          Metrics.batteryVoltage.key: 13.6,
          Metrics.coolantTemperature.key: 89,
        },
        connected: true,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WebhookSection(),
        const SectionHeader('What a reading looks like'),
        CodeBlock(child: Text(sample)),
      ],
    );
  }
}
