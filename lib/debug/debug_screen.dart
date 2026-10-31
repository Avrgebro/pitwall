import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bluetooth/classic_bluetooth.dart';
import '../obd/elm327.dart';
import '../obd/pids.dart';
import '../profiles/profile_reader.dart';
import '../profiles/signal_set.dart';

/// Temporary screen for trying the adapter by hand: pick a paired device,
/// connect, see what the car supports and read live values. The log shows
/// every raw exchange, so real replies can be copied into tests.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const _maxLogLines = 300;

  /// Checks where a 2023 Hyundai Tucson (NX4) reports fuel level, based on
  /// OBDb's signal definitions: which ECU answers the standard fuel PID, the
  /// instrument cluster's 22 B002 and the engine ECU's 22 E007. Flow control
  /// is set by hand so the cluster's long reply arrives in full.
  static const _tucsonFuelCheck = [
    'ATH1', '012F', 'ATH0', //
    'ATSH7C6', 'ATFCSH7C6', 'ATFCSD300000', 'ATFCSM1', 'ATCRA7CE', '22B002',
    'ATSH7E0', 'ATFCSH7E0', 'ATCRA7E8', '22E007',
  ];

  final _commandController = TextEditingController();

  /// OBDb files are around 100 KB; anything far larger isn't one.
  static const _maxProfileBytes = 5 * 1024 * 1024;

  final _yearController = TextEditingController();
  SignalSet? _profile;
  String? _profileName;

  List<BondedDevice>? _devices;
  ClassicTransport? _transport;
  Elm327? _elm;
  String? _status;
  String? _banner;
  Set<int> _supported = {};
  final Map<String, String> _values = {};
  final List<String> _log = [];
  Timer? _autoRead;
  bool _busy = false;

  bool get _connected => _elm != null;

  @override
  void dispose() {
    _autoRead?.cancel();
    _transport?.close();
    _commandController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final permission = await Permission.bluetoothConnect.request();
    if (!permission.isGranted) {
      setState(() => _status = 'Bluetooth permission was not granted.');
      return;
    }
    try {
      final devices = await ClassicBluetooth.bondedDevices();
      setState(() {
        _devices = devices;
        _status = devices.isEmpty
            ? 'No paired devices. Pair the adapter in Android settings first.'
            : null;
      });
    } on PlatformException catch (e) {
      setState(() => _status = 'Could not list devices: ${e.message}');
    }
  }

  Future<void> _connect(BondedDevice device) async {
    await _run('Connecting to ${device.name}...', () async {
      final transport = await ClassicBluetooth.connect(device.address);
      final elm = Elm327(transport, log: _addLog);
      _transport = transport;
      _elm = elm;
      final banner = await elm.initialize();
      setState(() => _banner = banner);
      _setStatus('Adapter ready. Asking the car what it supports...');
      final supported = await elm.supportedPids();
      setState(() => _supported = supported);
      _setStatus('Connected.');
    });
  }

  Future<void> _readValues() async {
    final elm = _elm;
    if (elm == null || _busy) return;
    await _run(null, () async {
      final standard = <String, double>{};
      final voltage = await elm.readBatteryVoltage();
      if (voltage != null) standard['battery_v'] = voltage;
      for (final definition in standardPids) {
        if (!_supported.contains(definition.pid)) continue;
        final value = await elm.read(definition);
        if (value != null) standard[definition.key] = value;
      }
      final profile = _profile;
      final year = _modelYear;
      final fromProfile = profile != null && year != null
          ? await readProfile(elm, profile, year)
          : <String, double>{};
      final merged = mergeValues(standard, fromProfile);
      setState(() {
        _values
          ..clear()
          ..addAll({
            for (final MapEntry(:key, :value) in merged.entries)
              key: '${_format(value)} ${_unitFor(key)}',
          });
      });
    });
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
      final profile = SignalSet.parse(utf8.decode(await file.readAsBytes()));
      setState(() {
        _profile = profile;
        _profileName = file.name;
        _status = 'Imported ${file.name}.';
      });
    } on FormatException catch (e) {
      _setStatus('Could not import ${file.name}: ${e.message}');
    }
  }

  int? get _modelYear {
    final year = int.tryParse(_yearController.text);
    return year != null && year >= 1996 && year <= 2100 ? year : null;
  }

  String _unitFor(String key) {
    if (key == 'battery_v') return 'V';
    if (standardPids.where((d) => d.key == key).firstOrNull case final d?) {
      return d.unit;
    }
    for (final command in _profile?.commands ?? const <ProfileCommand>[]) {
      for (final signal in command.signals) {
        if (signal.key == key) return signal.unit;
      }
    }
    return '';
  }

  void _toggleAutoRead(bool on) {
    _autoRead?.cancel();
    _autoRead = on
        ? Timer.periodic(const Duration(seconds: 2), (_) => _readValues())
        : null;
    setState(() {});
  }

  /// Sends raw commands in order. Replies and errors show up in the log;
  /// an error on one command doesn't stop the rest.
  Future<void> _sendCommands(List<String> commands) async {
    final elm = _elm;
    if (elm == null || _busy || commands.isEmpty) return;
    // Auto-read would interleave with header changes.
    if (_autoRead != null) _toggleAutoRead(false);
    await _run(null, () async {
      for (final command in commands) {
        try {
          await elm.send(command);
        } on ElmException catch (e) {
          if (e.error == ElmError.disconnected) rethrow;
        }
      }
      // Raw AT commands can change settings the app keeps track of, like
      // which module it's talking to, so start again from a clean adapter.
      if (commands.any((c) => c.startsWith('AT'))) await elm.initialize();
      _setStatus('Sent ${commands.length} command(s). See the log.');
    });
  }

  void _sendTypedCommand() {
    final commands = _commandController.text
        .split(RegExp(r'[,\s]+'))
        .where((c) => c.isNotEmpty)
        .map((c) => c.toUpperCase())
        .toList();
    _sendCommands(commands);
  }

  Future<void> _disconnect() async {
    _autoRead?.cancel();
    _autoRead = null;
    await _transport?.close();
    await _elm?.dispose();
    setState(() {
      _transport = null;
      _elm = null;
      _banner = null;
      _supported = {};
      _values.clear();
      _status = 'Disconnected.';
    });
  }

  /// Runs an adapter operation, showing errors instead of throwing them.
  Future<void> _run(String? status, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      if (status != null) _status = status;
    });
    try {
      await action();
    } on ElmException catch (e) {
      _setStatus(switch (e.error) {
        ElmError.unableToConnect =>
          'The adapter answered, but the car didn\'t. Is the ignition on?',
        ElmError.disconnected => 'The adapter disconnected.',
        _ => 'Adapter error: ${e.error.name} on ${e.command}',
      });
      if (e.error == ElmError.disconnected) await _disconnect();
    } on PlatformException catch (e) {
      _setStatus('Bluetooth error: ${e.message ?? e.code}');
      if (_transport != null) await _disconnect();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  void _addLog(String command, String rawReply) {
    final reply = rawReply.replaceAll('\r', r'\r').replaceAll('\n', r'\n');
    setState(() {
      _log.add('$command → $reply');
      if (_log.length > _maxLogLines) _log.removeAt(0);
    });
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pitwall (debug)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_status case final status?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(status, style: theme.textTheme.bodyLarge),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (!_connected) ..._buildDevicePicker(),
          if (_connected) ..._buildConnected(theme),
          ..._buildProfile(theme),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Log', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: _log.isEmpty
                    ? null
                    : () => Clipboard.setData(
                        ClipboardData(text: _log.join('\n')),
                      ),
                child: const Text('Copy'),
              ),
            ],
          ),
          SelectableText(
            _log.isEmpty ? 'Nothing yet.' : _log.join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProfile(ThemeData theme) {
    final profile = _profile;
    final year = _modelYear;
    return [
      const SizedBox(height: 24),
      Text('Vehicle profile', style: theme.textTheme.titleMedium),
      Row(
        children: [
          OutlinedButton(
            onPressed: _busy ? null : _importProfile,
            child: Text(profile == null ? 'Import JSON' : 'Replace'),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Model year'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      if (profile != null) ...[
        const SizedBox(height: 8),
        Text(
          '$_profileName: ${profile.commands.length} requests, '
          '${profile.signalCount} signals.',
        ),
        Text(
          year == null
              ? 'Enter the model year to use it.'
              : '${profile.commandsFor(year).length} requests apply to $year. '
                    'They run with "Read values".',
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

  List<Widget> _buildDevicePicker() => [
    FilledButton(
      onPressed: _busy ? null : _loadDevices,
      child: const Text('Show paired devices'),
    ),
    for (final device in _devices ?? const <BondedDevice>[])
      ListTile(
        title: Text(device.name),
        subtitle: Text(device.address),
        onTap: _busy ? null : () => _connect(device),
      ),
  ];

  List<Widget> _buildConnected(ThemeData theme) => [
    if (_banner case final banner?) Text('Adapter: $banner'),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      children: [
        FilledButton(
          onPressed: _busy ? null : _readValues,
          child: const Text('Read values'),
        ),
        OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
      ],
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Read every 2 seconds'),
      value: _autoRead != null,
      onChanged: _toggleAutoRead,
    ),
    for (final entry in _values.entries)
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(entry.key),
        trailing: Text(entry.value, style: theme.textTheme.titleMedium),
      ),
    const SizedBox(height: 16),
    Text('Raw commands', style: theme.textTheme.titleMedium),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commandController,
            decoration: const InputDecoration(
              hintText: 'e.g. ATSH7C6 22B002',
              helperText: 'Separate several commands with spaces',
            ),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            onSubmitted: (_) => _sendTypedCommand(),
          ),
        ),
        IconButton(
          onPressed: _busy ? null : _sendTypedCommand,
          icon: const Icon(Icons.send),
          tooltip: 'Send',
        ),
      ],
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: _busy ? null : () => _sendCommands(_tucsonFuelCheck),
      child: const Text('Run Tucson fuel check'),
    ),
    const SizedBox(height: 16),
    Text('Supported PIDs', style: theme.textTheme.titleMedium),
    Text(
      _supported.isEmpty
          ? 'None reported.'
          : (_supported.toList()..sort())
                .map(
                  (pid) => pid.toRadixString(16).padLeft(2, '0').toUpperCase(),
                )
                .join(' '),
      style: const TextStyle(fontFamily: 'monospace'),
    ),
  ];
}
