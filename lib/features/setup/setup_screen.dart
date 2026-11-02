import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/bluetooth/classic_bluetooth.dart';
import '../../core/platform/permission_gateway.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/permissions_state.dart';
import '../../state/settings_state.dart';
import '../../state/webhook_state.dart';
import '../common/widgets/adapter_picker.dart';
import '../common/widgets/vehicle_name_field.dart';
import 'steps/done_step.dart';
import 'steps/permissions_step.dart';
import 'steps/webhook_step.dart';
import 'steps/welcome_step.dart';
import 'widgets/step_scaffold.dart';

enum _Step { welcome, adapter, permissions, webhook, done }

/// First-run setup: welcome, adapter and name, permissions, webhook, done.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  _Step _step = _Step.welcome;
  BondedDevice? _adapter;
  String _name = '';
  String? _vehicleId;
  bool _testPassed = false;

  void _go(_Step step) => setState(() => _step = step);

  /// Creates the vehicle, or updates it when coming back to this step.
  Future<void> _saveVehicle() async {
    final adapter = _adapter!;
    final settings = ref.read(appSettingsProvider).requireValue;
    final existing = _vehicleId == null
        ? null
        : settings.vehicleById(_vehicleId!);
    final vehicle = (existing ?? Vehicle.create()).copyWith(
      name: _name.trim(),
      adapterAddress: adapter.address,
      adapterName: adapter.name,
      adapterType: AdapterType.classic,
    );
    await ref.read(appSettingsProvider.notifier).saveVehicle(vehicle);
    _vehicleId = vehicle.id;
    _go(_Step.permissions);
  }

  Future<void> _finish() async {
    await ref.read(appSettingsProvider.notifier).completeSetup();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step.index + 1;
    final steps = _Step.values.length;
    return switch (_step) {
      _Step.welcome => StepScaffold(
        step: step,
        steps: steps,
        primaryLabel: 'Get started',
        onPrimary: () => _go(_Step.adapter),
        footnote: 'Free and open source · MIT licence',
        children: const [WelcomeStep()],
      ),
      _Step.adapter => StepScaffold(
        step: step,
        steps: steps,
        title: 'Choose your adapter',
        message:
            'Plug it into the port under the dashboard and switch the '
            'ignition on.',
        primaryLabel: 'Continue',
        onPrimary: _adapter != null && _name.trim().isNotEmpty
            ? _saveVehicle
            : null,
        onBack: () => _go(_Step.welcome),
        // The vehicle can be added later from the Vehicles tab.
        onSkip: () => _go(_Step.permissions),
        children: [
          AdapterPicker(
            selectedAddress: _adapter?.address,
            onSelected: (device) => setState(() => _adapter = device),
          ),
          const SizedBox(height: 8),
          VehicleNameField(
            initialName: _name,
            note: 'You can change it later.',
            onChanged: (name) => setState(() => _name = name),
          ),
        ],
      ),
      _Step.permissions => StepScaffold(
        step: step,
        steps: steps,
        title: 'Three permissions',
        message:
            'These let Pitwall run on its own. Nothing leaves your phone '
            'except the readings sent to your webhook.',
        primaryLabel: 'Continue',
        // Bluetooth is essential; the others can be fixed later from the
        // background checks in Settings.
        onPrimary:
            ref.watch(permissionsProvider).value?[AppPermission.bluetooth] ??
                false
            ? () => _go(_Step.webhook)
            : null,
        onBack: () => _go(_Step.adapter),
        children: const [PermissionsStep()],
      ),
      _Step.webhook => StepScaffold(
        step: step,
        steps: steps,
        title: 'Where should readings go?',
        message:
            'In Home Assistant, create an automation with a Webhook trigger '
            'and paste its URL here.',
        primaryLabel: 'Continue',
        onPrimary: ref.watch(webhookConfigProvider).value?.hasUrl ?? false
            ? () => _go(_Step.done)
            : null,
        onBack: () => _go(_Step.permissions),
        // The webhook can be set later in Settings; readings wait on the
        // phone until then.
        onSkip: () => _go(_Step.done),
        children: [
          WebhookStep(
            vehicleName: _name.trim(),
            onTested: (passed) => setState(() => _testPassed = passed),
          ),
        ],
      ),
      _Step.done => StepScaffold(
        step: step,
        steps: steps,
        primaryLabel: 'Go to Home',
        onPrimary: _finish,
        children: [
          DoneStep(
            vehicle: _vehicleId == null
                ? null
                : ref.watch(vehicleProvider(_vehicleId!)),
            testPassed: _testPassed,
            hasWebhook: ref.watch(webhookConfigProvider).value?.hasUrl ?? false,
          ),
        ],
      ),
    };
  }
}
