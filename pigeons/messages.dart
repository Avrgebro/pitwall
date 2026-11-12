// The messages between Dart and Android. After changing them, run
//
//   dart run pigeon --input pigeons/messages.dart &&
//     dart format lib/core/platform/messages.g.dart
//
// Both sides' code is generated from this file. The Dart side is kept as
// `dart format` leaves it, so formatting the project never changes it.
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

/// A vehicle's Bluetooth LE adapter woke up, as the car started: the trip
/// is for the vehicle whose trips start that way.
class AdapterMessage extends TripTargetMessage {
  AdapterMessage({required this.address});

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
  /// The head units whose connection starts a trip, and the Bluetooth LE
  /// adapters whose waking does: Android watches for those, and stops
  /// watching any others.
  void configure(
    List<String> headUnitAddresses,
    List<String> wakingAdapterAddresses,
  );

  /// Starts the service for a trip the app asked for: a vehicle, or any.
  void startService(AppTripTargetMessage target);

  void stopService();

  void updateNotification(String text);

  /// The trip Android asked for before Dart was listening, if any. Asking
  /// also tells Android that Dart is now listening.
  TripTargetMessage? takeTripRequest();
}

/// Android's companion devices, called from Dart while a screen is showing:
/// asking Android to watch for an adapter needs the user to confirm it.
@HostApi()
abstract class CompanionApi {
  /// Asks Android to watch for the Bluetooth LE adapter at [address], with
  /// the system dialog the user confirms. True once it does, also when it
  /// already did; false if the user declined. Fails with `unavailable`
  /// without a screen to ask on.
  @async
  bool watch(String address);
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
/// There's one serial connection at a time, each with a number Dart gives
/// it. The numbers only go up, so closing one closes every earlier one too:
/// writing to or closing a connection that's no longer the current one does
/// nothing to the one that is, and Dart can close a connection while it's
/// still connecting, or before it has started.
@HostApi()
abstract class ClassicBluetoothApi {
  List<BondedDeviceMessage> bondedDevices();

  /// Opens serial connection [connection], closing any other, even if it
  /// then fails. Fails with `unavailable`, `permission` or
  /// `connect_failed`, also when it was closed before it opened.
  @async
  void connect(int connection, String address);

  @async
  void write(int connection, Uint8List bytes);

  /// Closes the connection, or the attempt to make it, at once.
  void disconnect(int connection);
}

/// Bluetooth LE adapters, called from Dart. Failures arrive as errors coded
/// `unavailable`, `disabled`, `permission`, `connect_failed` or
/// `write_failed`.
///
/// Connections are numbered by Dart as for [ClassicBluetoothApi], with the
/// same rules, and report through the same `adapterEvents`. An adapter's
/// GATT service is found by what its characteristics do: one that notifies,
/// for replies, and one that takes writes, for commands.
@HostApi()
abstract class BleApi {
  /// Opens connection [connection] to the adapter at [address], closing any
  /// other Bluetooth LE connection, even if it then fails. Done once its
  /// replies are switched on, so it's ready for commands.
  @async
  void connect(int connection, String address);

  /// Sends [bytes], split to what the adapter takes in one write.
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
/// connection closed on purpose: by Dart, or by connecting again.
class AdapterDropped extends AdapterEvent {
  AdapterDropped({required this.connection});

  int connection;
}

/// A Bluetooth LE device found nearby, with the name it advertises.
class FoundDeviceMessage {
  FoundDeviceMessage({required this.name, required this.address});

  String name;
  String address;
}

/// What Android reports as it happens.
@EventChannelApi()
abstract class BluetoothEvents {
  /// Every adapter connection's events, each with its number.
  AdapterEvent adapterEvents();

  /// Whether Bluetooth is on: now, then each change.
  bool bluetoothEnabled();

  /// Bluetooth LE devices nearby, each time one is seen, while listened
  /// to: scanning stops when Dart stops listening. Devices without a name
  /// aren't sent. Fails with `disabled` or `permission`.
  FoundDeviceMessage nearbyDevices();
}
