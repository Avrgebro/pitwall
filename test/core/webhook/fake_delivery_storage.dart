import 'package:pitwall/core/webhook/delivery_storage.dart';

/// Keeps the delivery state in memory instead of in a file.
class FakeDeliveryStorage implements DeliveryStorage {
  DeliveryState state = const DeliveryState();

  /// Makes loading fail with this, like a file that can't be read.
  Object? loadError;
  int saves = 0;

  @override
  Future<DeliveryState> load() async {
    if (loadError case final error?) throw error;
    return state;
  }

  @override
  Future<void> save(DeliveryState state) async {
    saves++;
    this.state = state;
  }
}
