import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bluetooth/classic_bluetooth.dart';
import '../obd/elm327.dart';
import '../obd/pids.dart';

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
      final voltage = await elm.readBatteryVoltage();
      if (voltage != null) _values['battery_v'] = '$voltage V';
      for (final definition in standardPids) {
        if (!_supported.contains(definition.pid)) continue;
        final value = await elm.read(definition);
        _values[definition.key] = value == null
            ? 'no data'
            : '${_format(value)} ${definition.unit}';
      }
      setState(() {});
    });
  }

  void _toggleAutoRead(bool on) {
    _autoRead?.cancel();
    _autoRead = on
        ? Timer.periodic(const Duration(seconds: 2), (_) => _readValues())
        : null;
    setState(() {});
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
