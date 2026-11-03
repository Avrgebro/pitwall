import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/platform/trip_service_gateway.dart';
import 'package:pitwall/core/trips/trip_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pitwall/service');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  Object? pending;

  setUp(() {
    calls = [];
    pending = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'takeTripRequest' ? pending : null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// Sends `tripStart` from Android with [arguments].
  Future<void> androidStarts(Object? arguments) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('tripStart', arguments)),
        (_) {},
      );

  test('the app\'s request travels to Android', () async {
    final gateway = AndroidTripServiceGateway();

    await gateway.startService(const VehicleTarget('mazda'));
    await gateway.startService(const AnyVehicleTarget());

    expect(calls.map((c) => c.arguments), [
      {'kind': 'vehicle', 'id': 'mazda'},
      {'kind': 'any'},
    ]);
  });

  test('Android\'s starts come back as targets', () async {
    final gateway = AndroidTripServiceGateway();
    final targets = <TripTarget>[];
    gateway.starts.listen(targets.add);

    await androidStarts({'kind': 'headUnit', 'address': 'AA:BB'});
    await androidStarts({'kind': 'vehicle', 'id': 'mazda'});
    await androidStarts({'kind': 'any'});
    await Future<void>.delayed(Duration.zero);

    expect(
      targets[0],
      isA<HeadUnitTarget>().having((t) => t.address, 'address', 'AA:BB'),
    );
    expect(targets[1], isA<VehicleTarget>().having((t) => t.id, 'id', 'mazda'));
    expect(targets[2], isA<AnyVehicleTarget>());
  });

  test('a start Android held for Dart keeps its target', () async {
    final gateway = AndroidTripServiceGateway();
    pending = {'kind': 'vehicle', 'id': 'mazda'};
    expect(
      await gateway.takeTripRequest(),
      isA<VehicleTarget>().having((t) => t.id, 'id', 'mazda'),
    );
    pending = null;
    expect(await gateway.takeTripRequest(), isNull);
  });

  test('anything but one head unit, one vehicle or any is an error', () async {
    final gateway = AndroidTripServiceGateway();
    for (final bad in <Object>[
      {'kind': 'headUnit', 'address': 'AA:BB', 'id': 'mazda'},
      {'kind': 'vehicle', 'id': 7},
      {'kind': 'vehicle'},
      {'vehicleId': 'mazda'},
      <String, String>{},
      'any',
    ]) {
      pending = bad;
      await expectLater(
        gateway.takeTripRequest(),
        throwsFormatException,
        reason: '$bad',
      );
    }
  });

  test(
    'a start Android sends that can\'t be read arrives as an error',
    () async {
      final gateway = AndroidTripServiceGateway();
      final errors = <Object>[];
      gateway.starts.listen((_) {}, onError: errors.add);

      await androidStarts({'kind': 'car'});
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isFormatException);
    },
  );

  test('a target reads back as itself', () {
    for (final target in const [
      HeadUnitTarget('AA:BB'),
      VehicleTarget('mazda'),
      AnyVehicleTarget(),
    ]) {
      expect(
        TripTarget.fromArguments(target.toArguments()).toArguments(),
        target.toArguments(),
      );
    }
  });
}
