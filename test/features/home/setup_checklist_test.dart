import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/features/home/setup_checklist.dart';

void main() {
  test('a fresh install has every step left', () {
    final checklist = SetupChecklist.from(
      settings: const AppSettings(),
      hasWebhook: false,
      missingPermissions: 2,
    );

    expect(checklist.items.map((i) => i.step), [
      SetupStep.vehicle,
      SetupStep.webhook,
      SetupStep.permissions,
    ]);
    expect(checklist.complete, isFalse);
    expect(checklist.doneCount, 0);
    expect(checklist.items.last.detail, '2 to allow');
  });

  test('steps done before the first vehicle count', () {
    final checklist = SetupChecklist.from(
      settings: const AppSettings(),
      hasWebhook: true,
      missingPermissions: 0,
    );

    expect(checklist.doneCount, 2);
    expect(checklist.items[1].detail, 'Readings go to your webhook');
  });
}
