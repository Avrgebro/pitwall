import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bluetooth/classic_bluetooth.dart';
import '../../../core/settings/settings.dart';
import '../../../state/settings_state.dart';
import '../../../ui/ui.dart';
import '../../common/widgets/adapter_picker.dart';

/// What starts Pitwall when a drive begins.
class WakeSection extends ConsumerWidget {
  const WakeSection({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);
    final carBluetooth = settings.wakeTrigger == WakeTrigger.carBluetooth;

    return GroupCard(
      children: [
        RadioGroup<WakeTrigger>(
          groupValue: settings.wakeTrigger,
          onChanged: (trigger) {
            if (trigger != null) notifier.setWakeTrigger(trigger);
          },
          child: Column(
            children: [
              const RadioListTile(
                value: WakeTrigger.carBluetooth,
                title: Text('When the phone connects to the car\'s Bluetooth'),
              ),
              if (carBluetooth)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.xxl * 2,
                    0,
                    Insets.l,
                    Insets.m,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.m,
                      Insets.s,
                      Insets.xs,
                      Insets.s,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: Corners.mediumRadius,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: LabeledValue(
                            label: 'Car head unit',
                            value: settings.headUnitName ?? 'Not chosen',
                          ),
                        ),
                        TextButton(
                          onPressed: () => _chooseHeadUnit(context, ref),
                          child: const Text('Choose'),
                        ),
                      ],
                    ),
                  ),
                ),
              const RadioListTile(
                value: WakeTrigger.drivingDetection,
                title: Text('When driving is detected'),
                subtitle: Text(
                  'For cars without Bluetooth audio. Can start a minute or '
                  'two late.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _chooseHeadUnit(BuildContext context, WidgetRef ref) async {
    final device = await showModalBottomSheet<BondedDevice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: Insets.page.add(const EdgeInsets.only(bottom: Insets.xl)),
        child: AdapterPicker(
          title: 'Paired devices',
          selectedAddress: settings.headUnitAddress,
          onSelected: (device) => Navigator.pop(context, device),
        ),
      ),
    );
    if (device == null) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setHeadUnit(address: device.address, name: device.name);
  }
}
