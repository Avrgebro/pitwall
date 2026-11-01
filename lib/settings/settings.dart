/// The user's settings, except the webhook URL. That one works like a
/// password, so it's kept apart in secure storage (see `SettingsStore`).
class Settings {
  const Settings({
    this.adapterAddress,
    this.adapterName,
    this.deviceName = defaultDeviceName,
    this.modelYear,
    this.selectedKeys,
  });

  static const defaultDeviceName = 'my-car';

  /// Bluetooth address of the paired OBD adapter.
  final String? adapterAddress;
  final String? adapterName;

  /// Sent as `device` in every payload, so one receiver can tell several
  /// cars apart.
  final String deviceName;

  /// Picks which of the vehicle profile's signals apply.
  final int? modelYear;

  /// Payload keys to send. Null means the default set.
  final Set<String>? selectedKeys;

  Settings copyWith({
    Object? adapterAddress = _keep,
    Object? adapterName = _keep,
    String? deviceName,
    Object? modelYear = _keep,
    Object? selectedKeys = _keep,
  }) => Settings(
    adapterAddress: adapterAddress == _keep
        ? this.adapterAddress
        : adapterAddress as String?,
    adapterName: adapterName == _keep
        ? this.adapterName
        : adapterName as String?,
    deviceName: deviceName ?? this.deviceName,
    modelYear: modelYear == _keep ? this.modelYear : modelYear as int?,
    selectedKeys: selectedKeys == _keep
        ? this.selectedKeys
        : selectedKeys as Set<String>?,
  );

  Map<String, Object?> toJson() => {
    'adapterAddress': adapterAddress,
    'adapterName': adapterName,
    'deviceName': deviceName,
    'modelYear': modelYear,
    'selectedKeys': selectedKeys?.toList()?..sort(),
  };

  /// Tolerates missing or wrongly typed fields, falling back to defaults,
  /// so older saved settings keep loading.
  factory Settings.fromJson(Map<String, Object?> json) => Settings(
    adapterAddress: _string(json['adapterAddress']),
    adapterName: _string(json['adapterName']),
    deviceName: switch (json['deviceName']) {
      final String name when name.isNotEmpty => name,
      _ => defaultDeviceName,
    },
    modelYear: switch (json['modelYear']) {
      final num year => year.toInt(),
      _ => null,
    },
    selectedKeys: switch (json['selectedKeys']) {
      final List<Object?> keys => {...keys.whereType<String>()},
      _ => null,
    },
  );
}

const _keep = Object();

String? _string(Object? value) => value is String ? value : null;

/// Returns why [url] can't be used as a webhook, or null if it can.
String? webhookUrlProblem(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'Enter a full URL, like https://example.com/api/webhook/…';
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return 'The URL must start with https:// or http://';
  }
  return null;
}
