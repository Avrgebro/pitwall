/// What a paired device says it is, from its Bluetooth device class.
enum DeviceKind {
  /// Car stereos and hands-free kits.
  carAudio,

  /// Headphones, speakers and other audio.
  audio,
  phone,
  computer,
  wearable,

  /// Keyboards, mice and other peripherals; some OBD adapters report this.
  peripheral,

  /// No class given. Most ELM327 adapters report this.
  uncategorized,

  /// Anything else, such as printers or toys.
  other;

  /// The kind for a Bluetooth device class, as Android reports it.
  factory DeviceKind.fromClass(int deviceClass) {
    // Minor classes within audio/video that a car reports.
    const carAudio = 0x0420;
    const handsFree = 0x0408;
    if (deviceClass == carAudio || deviceClass == handsFree) {
      return DeviceKind.carAudio;
    }
    return switch (deviceClass & _majorMask) {
      0x0100 => DeviceKind.computer,
      0x0200 => DeviceKind.phone,
      0x0400 => DeviceKind.audio,
      0x0500 => DeviceKind.peripheral,
      0x0700 => DeviceKind.wearable,
      0x1F00 => DeviceKind.uncategorized,
      _ => DeviceKind.other,
    };
  }

  static const _majorMask = 0x1F00;
}

/// What a paired device is being chosen for.
enum DeviceRole {
  /// The OBD adapter plugged into the car.
  adapter,

  /// The car's stereo, whose connection starts a trip.
  headUnit;

  /// Whether a device of [kind] is likely the one wanted for this role.
  bool suits(DeviceKind kind) => switch (this) {
    DeviceRole.adapter => switch (kind) {
      DeviceKind.uncategorized ||
      DeviceKind.peripheral ||
      DeviceKind.other => true,
      _ => false,
    },
    DeviceRole.headUnit => kind == DeviceKind.carAudio,
  };
}
