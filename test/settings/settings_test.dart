import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/settings/settings.dart';

void main() {
  test('settings survive a round trip through JSON', () {
    const settings = Settings(
      adapterAddress: '00:11:22:33:44:55',
      adapterName: 'OBDII',
      deviceName: 'tucson',
      modelYear: 2023,
      selectedKeys: {'fuel_level_l', 'battery_v'},
    );

    final restored = Settings.fromJson(settings.toJson());

    expect(restored.adapterAddress, settings.adapterAddress);
    expect(restored.adapterName, settings.adapterName);
    expect(restored.deviceName, 'tucson');
    expect(restored.modelYear, 2023);
    expect(restored.selectedKeys, {'fuel_level_l', 'battery_v'});
  });

  test('missing or broken fields fall back to defaults', () {
    final restored = Settings.fromJson({
      'deviceName': '',
      'modelYear': 'soon',
      'selectedKeys': 'all',
    });

    expect(restored.deviceName, Settings.defaultDeviceName);
    expect(restored.modelYear, isNull);
    expect(restored.selectedKeys, isNull);
  });

  test('copyWith can clear a value', () {
    const settings = Settings(modelYear: 2023, selectedKeys: {'rpm'});

    final cleared = settings.copyWith(modelYear: null, selectedKeys: null);

    expect(cleared.modelYear, isNull);
    expect(cleared.selectedKeys, isNull);
  });

  group('webhook URL', () {
    test('accepts https and http URLs', () {
      expect(webhookUrlProblem('https://example.com/api/webhook/abc'), isNull);
      expect(webhookUrlProblem('http://192.168.1.10:8123/x'), isNull);
    });

    test('rejects anything else', () {
      expect(webhookUrlProblem('example.com/hook'), isNotNull);
      expect(webhookUrlProblem('ftp://example.com/hook'), isNotNull);
      expect(webhookUrlProblem(''), isNotNull);
    });
  });
}
