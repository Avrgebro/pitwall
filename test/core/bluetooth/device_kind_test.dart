import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/device_kind.dart';

void main() {
  test('device classes map to kinds', () {
    expect(DeviceKind.fromClass(0x1F00), DeviceKind.uncategorized);
    expect(DeviceKind.fromClass(0x0420), DeviceKind.carAudio);
    expect(DeviceKind.fromClass(0x0408), DeviceKind.carAudio);
    expect(DeviceKind.fromClass(0x0418), DeviceKind.audio); // headphones
    expect(DeviceKind.fromClass(0x020C), DeviceKind.phone);
    expect(DeviceKind.fromClass(0x0704), DeviceKind.wearable);
    expect(DeviceKind.fromClass(0x0540), DeviceKind.peripheral);
    expect(DeviceKind.fromClass(0x0600), DeviceKind.other);
  });

  test('adapters are the uncategorized kinds, head units the car audio', () {
    expect(DeviceRole.adapter.suits(DeviceKind.uncategorized), isTrue);
    expect(DeviceRole.adapter.suits(DeviceKind.audio), isFalse);
    expect(DeviceRole.adapter.suits(DeviceKind.carAudio), isFalse);
    expect(DeviceRole.headUnit.suits(DeviceKind.carAudio), isTrue);
    expect(DeviceRole.headUnit.suits(DeviceKind.uncategorized), isFalse);
  });

  test('a Bluetooth LE device is told by its name', () {
    for (final name in [
      'IOS-Vlink',
      'Android-Vlink',
      'OBDII',
      'vLinker MC+',
      'Veepeak BLE+',
    ]) {
      expect(DeviceKind.fromName(name), DeviceKind.obdAdapter, reason: name);
    }
    expect(DeviceKind.fromName('Galaxy Watch'), DeviceKind.bluetoothLe);
    expect(DeviceRole.adapter.suits(DeviceKind.obdAdapter), isTrue);
    expect(DeviceRole.adapter.suits(DeviceKind.bluetoothLe), isFalse);
  });
}
