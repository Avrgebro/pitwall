import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/bluetooth/device_kind.dart';
import '../../core/bluetooth/classic_bluetooth.dart';
import '../../core/settings/settings.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';

/// What starts Pitwall when a drive begins.
class WakeScreen extends ConsumerWidget {
  const WakeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) return const AppPage(title: '', children: []);
    final notifier = ref.read(appSettingsProvider.notifier);
    final headUnit = settings.headUnitName;

    return AppPage(
      title: 'What wakes Pitwall',
      children: [
        RadioGroup<WakeTrigger>(
          groupValue: settings.wakeTrigger,
          onChanged: (trigger) {
            if (trigger != null) notifier.setWakeTrigger(trigger);
          },
          child: const RowGroup(
            children: [
              ChoiceRow(
                value: WakeTrigger.carBluetooth,
                title: 'When the phone connects to the car\'s Bluetooth',
                subtitle: 'Starts within seconds of switching the car on.',
              ),
              ChoiceRow(
                value: WakeTrigger.drivingDetection,
                enabled: false,
                title: 'When driving is detected',
                subtitle:
                    'For cars without Bluetooth audio. Not available yet.',
              ),
            ],
          ),
        ),
        if (settings.wakeTrigger == WakeTrigger.carBluetooth) ...[
          const SectionHeader('Car head unit'),
          RowGroup(
            children: [
              GroupTile(
                icon: Symbols.bluetooth_rounded,
                title: headUnit ?? 'Not chosen yet',
                subtitle: headUnit == null
                    ? 'Choose your car\'s stereo or hands-free system'
                    : settings.headUnitAddress,
                trailing: TextButton(
                  onPressed: () => _chooseHeadUnit(context, ref, settings),
                  child: Text(headUnit == null ? 'Choose' : 'Change'),
                ),
              ),
            ],
          ),
          const InfoNote(
            text: TextSpan(
              text:
                  'When the phone connects to it, Pitwall connects to the '
                  'adapter and starts sending. When it disconnects, the trip '
                  'ends.',
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _chooseHeadUnit(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final device = await showModalBottomSheet<BondedDevice>(
      context: context,
      // Grows with the list, up to just below the status bar; a longer
      // list scrolls.
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: Insets.page.copyWith(bottom: Insets.xl),
        child: SafeArea(
          top: false,
          child: AdapterPicker(
            title: 'Paired devices',
            role: DeviceRole.headUnit,
            selectedAddress: settings.headUnitAddress,
            onSelected: (device) => Navigator.pop(context, device),
          ),
        ),
      ),
    );
    if (device == null) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setHeadUnit(address: device.address, name: device.name);
  }
}
