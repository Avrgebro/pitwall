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

  test('the app\'s target travels to Android', () async {
    final gateway = AndroidTripServiceGateway();

    await gateway.startService(const VehicleTarget('mazda'));
    await gateway.startService(const AnyVehicleTarget());

    expect(calls.map((c) => c.arguments), [
      {'vehicleId': 'mazda'},
      <String, String>{},
    ]);
  });

  test('Android\'s starts come back as targets', () async {
    final gateway = AndroidTripServiceGateway();
    final targets = <TripTarget>[];
    gateway.starts.listen(targets.add);

    await androidStarts({'headUnit': 'AA:BB'});
    await androidStarts({'vehicleId': 'mazda'});
    await androidStarts(<String, String>{});
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
    pending = {'vehicleId': 'mazda'};
    expect(
      await gateway.takeTripRequest(),
      isA<VehicleTarget>().having((t) => t.id, 'id', 'mazda'),
    );
    pending = null;
    expect(await gateway.takeTripRequest(), isNull);
  });
}
