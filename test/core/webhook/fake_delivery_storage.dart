import 'package:pitwall/core/webhook/delivery_storage.dart';

/// Keeps the delivery state in memory instead of in a file.
class FakeDeliveryStorage implements DeliveryStorage {
  DeliveryState state = const DeliveryState();

  @override
  Future<DeliveryState> load() async => state;

  @override
  Future<void> save(DeliveryState state) async => this.state = state;
}
