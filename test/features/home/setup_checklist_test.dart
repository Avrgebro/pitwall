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
      settings: AppSettings(
        vehicles: [
          _tucson.copyWith(headUnitAddress: 'AA', headUnitName: 'TUCSON BT'),
        ],
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

  test('the trip start step names the vehicle that still needs one', () {
    ({String detail, String? vehicleId, bool done}) step(List<Vehicle> v) {
      final item = SetupChecklist.from(
        settings: AppSettings(vehicles: v),
        hasWebhook: true,
        missingPermissions: 0,
      ).items.firstWhere((i) => i.step == SetupStep.headUnit);
      return (detail: item.detail, vehicleId: item.vehicleId, done: item.done);
    }

    final tucson = _tucson.copyWith(headUnitAddress: 'AA', headUnitName: 'T');
    const mazda = Vehicle(id: 'mazda', name: 'Mazda');
    const kia = Vehicle(id: 'kia', name: 'Kia');

    expect(step([tucson, mazda]), (
      detail: 'Mazda needs one',
      vehicleId: 'mazda',
      done: false,
    ));
    expect(step([tucson, mazda, kia]), (
      detail: '2 vehicles need one',
      vehicleId: null,
      done: false,
    ));
    expect(
      step([tucson, mazda.copyWith(headUnitAddress: 'BB')]).detail,
      'Every vehicle has one',
    );
  });
}
