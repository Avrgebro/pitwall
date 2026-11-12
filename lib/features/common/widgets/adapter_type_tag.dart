import 'package:material_ui/material_ui.dart';

import '../../../core/bluetooth/adapter_type.dart';
import '../../../ui/ui.dart';

/// How an adapter connects, as a small tag by its name.
class AdapterTypeTag extends StatelessWidget {
  const AdapterTypeTag(this.type, {super.key});

  final AdapterType type;

  @override
  Widget build(BuildContext context) => Tag(
    switch (type) {
      AdapterType.ble => 'BLE',
      AdapterType.classic => 'Classic',
    },
    tone: switch (type) {
      AdapterType.ble => StatusTone.active,
      AdapterType.classic => StatusTone.neutral,
    },
  );
}
