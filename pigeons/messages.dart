// The messages between Dart and Android. Run
// `dart run pigeon --input pigeons/messages.dart` after changing them; both
// sides' code is generated from this file.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/messages.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/io/github/avrgebro/pitwall/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.github.avrgebro.pitwall'),
  ),
)
/// Which vehicle a trip is for, as it travels between Dart and Android.
sealed class TripTargetMessage {}

/// A car's head unit connected: the trip is for the vehicle whose trips
/// it starts.
class HeadUnitMessage extends TripTargetMessage {
  HeadUnitMessage({required this.address});

  String address;
}

/// The app asked for the trip.
class AppRequestMessage extends TripTargetMessage {
  AppRequestMessage({required this.target});

  AppTripTargetMessage target;
}

/// What the app can ask for: one vehicle, or any. Only a head unit names
/// itself, so the app never asks for one.
sealed class AppTripTargetMessage {}

/// A trip for one vehicle.
class VehicleMessage extends AppTripTargetMessage {
  VehicleMessage({required this.id});

  String id;
}

/// A trip for whichever vehicle's adapter answers.
class AnyVehicleMessage extends AppTripTargetMessage {}

/// The trip service, called from Dart.
@HostApi()
abstract class TripServiceApi {
  /// The head units whose connection starts a trip.
  void configure(List<String> headUnitAddresses);

  /// Starts the service for a trip the app asked for: a vehicle, or any.
  void startService(AppTripTargetMessage target);

  void stopService();

  void updateNotification(String text);

  /// The trip Android asked for before Dart was listening, if any. Asking
  /// also tells Android that Dart is now listening.
  TripTargetMessage? takeTripRequest();
}

/// Trips Android starts, called from Android.
@FlutterApi()
abstract class TripStartApi {
  void tripStart(TripTargetMessage target);
}

/// A device paired with the phone.
class BondedDeviceMessage {
  BondedDeviceMessage({
    required this.name,
    required this.address,
    required this.deviceClass,
  });

  String name;
  String address;

  /// Android's major and minor device class.
  int deviceClass;
}

/// Classic Bluetooth serial adapters, called from Dart. Failures arrive as
/// errors coded `unavailable`, `disabled`, `permission`, `connect_failed`
/// or `write_failed`.
///
/// There's one serial connection at a time, and each gets its own number:
/// writing to or closing a connection that's no longer the current one
/// does nothing to the one that is.
@HostApi()
abstract class ClassicBluetoothApi {
  List<BondedDeviceMessage> bondedDevices();

  /// Opens a serial connection, closing any other, and returns its number.
  @async
  int connect(String address);

  @async
  void write(int connection, Uint8List bytes);

  /// Closes the connection, or the attempt to make it, at once.
  void disconnect(int connection);
}

/// Something from an adapter connection.
sealed class AdapterEvent {}

/// Bytes the adapter sent.
class AdapterBytes extends AdapterEvent {
  AdapterBytes({required this.connection, required this.bytes});

  int connection;
  Uint8List bytes;
}

/// The connection dropped; nothing more comes from it. Not sent for a
/// connection Dart closed.
class AdapterDropped extends AdapterEvent {
  AdapterDropped({required this.connection});

  int connection;
}

/// What Android reports as it happens.
@EventChannelApi()
abstract class BluetoothEvents {
  /// Every adapter connection's events, each with its number.
  AdapterEvent adapterEvents();

  /// Whether Bluetooth is on: now, then each change.
  bool bluetoothEnabled();
}
