import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/features/home/setup_checklist.dart';

const _tucson = Vehicle(id: 'tucson', name: 'Tucson');

void main() {
  test('a fresh install has every step left', () {
    final checklist = SetupChecklist.from(
      settings: const AppSettings(),
      hasWebhook: false,
      missingPermissions: 2,
    );

    expect(checklist.complete, isFalse);
    expect(checklist.doneCount, 0);
    expect(checklist.items.last.detail, '2 to allow');
  });

  test('everything set completes the checklist', () {
    final checklist = SetupChecklist.from(
      settings: const AppSettings(
        vehicles: [_tucson],
        headUnitAddress: 'AA',
        headUnitName: 'TUCSON BT',
      ),
      hasWebhook: true,
      missingPermissions: 0,
    );

    expect(checklist.complete, isTrue);
    expect(checklist.items.first.detail, 'Tucson');
    expect(
      checklist.items.firstWhere((i) => i.step == SetupStep.headUnit).detail,
      'Trips start when TUCSON BT connects',
    );
  });

  test('a missing head unit keeps the checklist open', () {
    final checklist = SetupChecklist.from(
      settings: const AppSettings(vehicles: [_tucson]),
      hasWebhook: true,
      missingPermissions: 0,
    );

    expect(checklist.complete, isFalse);
    expect(checklist.doneCount, 3);
  });
}
