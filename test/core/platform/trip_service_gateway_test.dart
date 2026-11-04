import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/platform/messages.g.dart';
import 'package:pitwall/core/platform/trip_service_gateway.dart';
import 'package:pitwall/core/trips/trip_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const startService = 'dev.flutter.pigeon.pitwall.TripServiceApi.startService';

  /// [message] after a trip through the channel's codec.
  T throughCodec<T>(T message) =>
      TripServiceApi.pigeonChannelCodec.decodeMessage(
        TripServiceApi.pigeonChannelCodec.encodeMessage(message),
      ) as T;

  test('Android\'s starts come back as targets', () async {
    final gateway = AndroidTripServiceGateway();
    final targets = <TripTarget>[];
    gateway.starts.listen(targets.add);

    for (final message in [
      HeadUnitMessage(address: 'AA:BB'),
      AppRequestMessage(target: VehicleMessage(id: 'mazda')),
      AppRequestMessage(target: AnyVehicleMessage()),
    ]) {
      gateway.tripStart(throughCodec<TripTargetMessage>(message));
    }
    await Future<void>.delayed(Duration.zero);

    expect(targets, [
      isA<HeadUnitTarget>().having((t) => t.address, 'address', 'AA:BB'),
      isA<VehicleTarget>().having((t) => t.id, 'id', 'mazda'),
      isA<AnyVehicleTarget>(),
    ]);
  });

  test('the app\'s request travels as its message', () async {
    AppTripTargetMessage? sent;
    messenger.setMockMessageHandler(startService, (data) async {
      final args =
          TripServiceApi.pigeonChannelCodec.decodeMessage(data)!
              as List<Object?>;
      sent = args.single! as AppTripTargetMessage;
      return TripServiceApi.pigeonChannelCodec.encodeMessage(<Object?>[null]);
    });
    addTearDown(() => messenger.setMockMessageHandler(startService, null));

    await AndroidTripServiceGateway().startService(
      const VehicleTarget('mazda'),
    );

    expect(sent, VehicleMessage(id: 'mazda'));
  });
}
