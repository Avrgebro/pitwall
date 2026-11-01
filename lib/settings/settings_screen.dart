import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bluetooth/classic_bluetooth.dart';
import '../profiles/signal_set.dart';
import '../readings/readings.dart';
import '../vehicles/vehicle.dart';
import '../webhook/webhook_sender.dart';
import 'settings.dart';
import 'settings_store.dart';

/// Temporary settings screen until the designed UI lands: the webhook, the
/// reading interval, and the first vehicle. Every change is saved right
/// away.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store, required this.sender});

  final SettingsStore store;
  final WebhookSender sender;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// OBDb files are around 100 KB; anything far larger isn't one.
  static const _maxProfileBytes = 5 * 1024 * 1024;

  final _webhookController = TextEditingController();
  final _intervalController = TextEditingController();
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();

  AppSettings _settings = const AppSettings();
  late Vehicle _vehicle;
  SignalSet? _profile;
  bool _loading = true;
  bool _showWebhookUrl = false;
  bool _testing = false;
  String? _webhookProblem;
  String? _testResult;
  String? _message;

  SettingsStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _webhookController.dispose();
    _intervalController.dispose();
    _nameController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _store.load();
    final webhookUrl = await _store.loadWebhookUrl();
    final vehicle = settings.vehicles.firstOrNull ?? Vehicle.create();
    final profile = await _store.loadProfile(vehicle);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _vehicle = vehicle;
      _profile = profile;
      _webhookController.text = webhookUrl ?? '';
      _intervalController.text = settings.interval.inSeconds.toString();
      _nameController.text = vehicle.name;
      _yearController.text = vehicle.modelYear?.toString() ?? '';
      _loading = false;
    });
  }

  Future<void> _updateSettings(AppSettings settings) async {
    setState(() => _settings = settings);
    await _store.save(settings);
  }

  Future<void> _updateVehicle(Vehicle vehicle) async {
    setState(() => _vehicle = vehicle);
    await _updateSettings(_settings.withVehicle(vehicle));
  }

  Future<void> _webhookChanged(String text) async {
    final url = text.trim();
    final problem = url.isEmpty ? null : webhookUrlProblem(url);
    setState(() {
      _webhookProblem = problem;
      _testResult = null;
    });
    if (problem == null) await _store.saveWebhookUrl(url);
  }

  Future<void> _sendTest() async {
    final url = _webhookController.text.trim();
    if (url.isEmpty || _webhookProblem != null) return;
    setState(() => _testing = true);
    final error = await widget.sender.sendTest(url);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = error ?? 'Test sent. Check the receiving side.';
    });
  }

  Future<void> _intervalChanged(String text) async {
    final seconds = int.tryParse(text);
    if (seconds == null || seconds < AppSettings.minInterval.inSeconds) return;
    await _updateSettings(
      _settings.copyWith(interval: Duration(seconds: seconds)),
    );
  }

  Future<void> _nameChanged(String text) => _updateVehicle(
    _vehicle.copyWith(
      name: text.trim().isEmpty ? Vehicle.defaultName : text.trim(),
    ),
  );

  Future<void> _yearChanged(String text) {
    final year = int.tryParse(text);
    final valid = year != null && year >= 1996 && year <= 2100;
    return _updateVehicle(_vehicle.copyWith(modelYear: valid ? year : null));
  }

  Future<void> _chooseAdapter() async {
    final permission = await Permission.bluetoothConnect.request();
    if (!permission.isGranted) {
      setState(() => _message = 'Bluetooth permission was not granted.');
      return;
    }
    final List<BondedDevice> devices;
    try {
      devices = await ClassicBluetooth.bondedDevices();
    } on PlatformException catch (e) {
      setState(() => _message = 'Could not list devices: ${e.message}');
      return;
    }
    if (!mounted) return;
    final device = await showDialog<BondedDevice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Paired devices'),
        children: [
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No paired devices. Pair the adapter in Android settings first.',
              ),
            ),
          for (final device in devices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, device),
              child: ListTile(
                title: Text(device.name),
                subtitle: Text(device.address),
              ),
            ),
        ],
      ),
    );
    if (device == null) return;
    await _updateVehicle(
      _vehicle.copyWith(
        adapterAddress: device.address,
        adapterName: device.name,
      ),
    );
  }

  Future<void> _importProfile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    try {
      if ((await file.length() ?? 0) > _maxProfileBytes) {
        throw const FormatException('The file is too large.');
      }
      final source = utf8.decode(await file.readAsBytes());
      final profile = SignalSet.parse(source);
      final vehicle = await _store.saveProfile(_vehicle, source, file.name);
      await _updateVehicle(vehicle);
      setState(() {
        _profile = profile;
        _message = 'Imported ${file.name}.';
      });
    } on FormatException catch (e) {
      setState(() => _message = 'Could not import ${file.name}: ${e.message}');
    }
  }

  Future<void> _removeProfile() async {
    await _updateVehicle(await _store.deleteProfile(_vehicle));
    setState(() {
      _profile = null;
      _message = 'Vehicle profile removed.';
    });
  }

  Future<void> _toggleValue(String key, bool on, Set<String> selected) =>
      _updateVehicle(
        _vehicle.copyWith(
          selectedKeys: on ? {...selected, key} : ({...selected}..remove(key)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(message, style: theme.textTheme.bodyLarge),
                  ),
                ..._buildWebhook(theme),
                const SizedBox(height: 24),
                Text('Vehicle', style: theme.textTheme.titleLarge),
                ..._buildAdapter(theme),
                ..._buildProfile(theme),
                ..._buildValues(theme),
              ],
            ),
    );
  }

  List<Widget> _buildWebhook(ThemeData theme) => [
    Text('Webhook', style: theme.textTheme.titleMedium),
    TextField(
      controller: _webhookController,
      obscureText: !_showWebhookUrl,
      keyboardType: TextInputType.url,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'Webhook URL',
        helperText: 'Stored securely on this phone only.',
        errorText: _webhookProblem,
        suffixIcon: IconButton(
          icon: Icon(_showWebhookUrl ? Icons.visibility_off : Icons.visibility),
          tooltip: _showWebhookUrl ? 'Hide' : 'Show',
          onPressed: () => setState(() => _showWebhookUrl = !_showWebhookUrl),
        ),
      ),
      onChanged: _webhookChanged,
    ),
    if (_webhookController.text.trim().startsWith('http://'))
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Without https, readings travel unencrypted.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
    const SizedBox(height: 8),
    Row(
      children: [
        FilledButton.tonal(
          onPressed: _testing ? null : _sendTest,
          child: const Text('Send test'),
        ),
        const SizedBox(width: 12),
        if (_testing)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_testResult case final result?)
          Expanded(child: Text(result)),
      ],
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _intervalController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Send every (seconds)',
        helperText:
            'While driving. At least ${AppSettings.minInterval.inSeconds}.',
      ),
      onChanged: _intervalChanged,
    ),
  ];

  List<Widget> _buildAdapter(ThemeData theme) => [
    TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Name',
        helperText: 'Sent as "device", to tell cars apart.',
      ),
      onChanged: _nameChanged,
    ),
    const SizedBox(height: 8),
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_vehicle.adapterName ?? 'No adapter chosen'),
      subtitle: _vehicle.adapterAddress == null
          ? null
          : Text(_vehicle.adapterAddress!),
      trailing: OutlinedButton(
        onPressed: _chooseAdapter,
        child: const Text('Choose'),
      ),
    ),
  ];

  List<Widget> _buildProfile(ThemeData theme) {
    final profile = _profile;
    final year = _vehicle.modelYear;
    return [
      const SizedBox(height: 16),
      Text('Vehicle profile', style: theme.textTheme.titleMedium),
      const Text(
        'Optional. Adds values your car only reports through manufacturer '
        'requests. Download your car\'s signalsets/v3/default.json from '
        'github.com/OBDb and import it here.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          OutlinedButton(
            onPressed: _importProfile,
            child: Text(profile == null ? 'Import JSON' : 'Replace'),
          ),
          if (profile != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: _removeProfile, child: const Text('Remove')),
          ],
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Model year'),
              onChanged: _yearChanged,
            ),
          ),
        ],
      ),
      if (profile != null) ...[
        const SizedBox(height: 8),
        Text(
          '${_vehicle.profileName}: ${profile.commands.length} requests, '
          '${profile.signalCount} signals.',
        ),
        Text(
          year == null
              ? 'Enter the model year to use it.'
              : '${profile.commandsFor(year).length} requests apply to $year.',
        ),
        if (profile.skipped.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Skipped: ${profile.skipped.length}'),
            children: [
              for (final skipped in profile.skipped)
                ListTile(
                  dense: true,
                  title: Text(skipped.description),
                  subtitle: Text(skipped.reason),
                ),
            ],
          ),
      ],
    ];
  }

  List<Widget> _buildValues(ThemeData theme) {
    final options = valueOptions(_profile, _vehicle.modelYear);
    final selected = _vehicle.selectedKeys ?? defaultKeys(options);

    Widget tile(ValueOption option) => CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: selected.contains(option.key),
      title: Text(option.name),
      subtitle: Text(
        option.unit.isEmpty ? option.key : '${option.key} (${option.unit})',
      ),
      onChanged: (on) => _toggleValue(option.key, on ?? false, selected),
    );

    final others = options.where((o) => !o.recommended).toList();
    return [
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Text('Values to send', style: theme.textTheme.titleMedium),
          ),
          if (_vehicle.selectedKeys != null)
            TextButton(
              onPressed: () =>
                  _updateVehicle(_vehicle.copyWith(selectedKeys: null)),
              child: const Text('Reset'),
            ),
        ],
      ),
      const Text(
        'Only values your car actually reports are sent. Fewer values '
        'means fewer requests to the car.',
      ),
      for (final option in options.where((o) => o.recommended)) tile(option),
      if (others.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Other profile signals (${others.length})'),
          subtitle: const Text('Mostly diagnostic. Each adds requests.'),
          children: [for (final option in others) tile(option)],
        ),
    ];
  }
}
