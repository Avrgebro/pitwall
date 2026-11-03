import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/platform/messages.g.dart';
import 'package:pitwall/core/platform/trip_service_gateway.dart';
import 'package:pitwall/core/trips/trip_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const startService = 'dev.flutter.pigeon.pitwall.TripServiceApi.startService';

  test('every target reads back as itself', () {
    for (final target in const [
      HeadUnitTarget('AA:BB'),
      VehicleTarget('mazda'),
      AnyVehicleTarget(),
    ]) {
      final back = tripTargetFrom(target.toMessage());
      expect(back.toMessage().encode(), target.toMessage().encode());
    }
  });

  test('a kind without what it names, or with another\'s, is an error', () {
    for (final message in [
      TripTargetMessage(kind: TripTargetKind.headUnit),
      TripTargetMessage(kind: TripTargetKind.vehicle, address: 'AA:BB'),
      TripTargetMessage(
        kind: TripTargetKind.headUnit,
        address: 'AA:BB',
        vehicleId: 'mazda',
      ),
      TripTargetMessage(kind: TripTargetKind.anyVehicle, vehicleId: 'mazda'),
    ]) {
      expect(() => tripTargetFrom(message), throwsFormatException);
    }
  });

  test('Android\'s starts come back as targets, or errors', () async {
    final gateway = AndroidTripServiceGateway();
    final targets = <TripTarget>[];
    final errors = <Object>[];
    gateway.starts.listen(targets.add, onError: errors.add);

    gateway.tripStart(
      TripTargetMessage(kind: TripTargetKind.headUnit, address: 'AA:BB'),
    );
    gateway.tripStart(TripTargetMessage(kind: TripTargetKind.vehicle));
    await Future<void>.delayed(Duration.zero);

    expect(
      targets.single,
      isA<HeadUnitTarget>().having((t) => t.address, 'address', 'AA:BB'),
    );
    expect(errors.single, isFormatException);
  });

  test('the app\'s request travels as its message', () async {
    TripTargetMessage? sent;
    messenger.setMockMessageHandler(startService, (data) async {
      final args =
          TripServiceApi.pigeonChannelCodec.decodeMessage(data)!
              as List<Object?>;
      sent = args.single! as TripTargetMessage;
      return TripServiceApi.pigeonChannelCodec.encodeMessage(<Object?>[null]);
    });
    addTearDown(() => messenger.setMockMessageHandler(startService, null));

    await AndroidTripServiceGateway().startService(
      const VehicleTarget('mazda'),
    );

    expect(sent?.kind, TripTargetKind.vehicle);
    expect(sent?.vehicleId, 'mazda');
  });
}
