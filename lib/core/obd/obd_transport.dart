/// A byte connection to an ELM327 adapter.
///
/// Implemented by the classic Bluetooth (serial) and Bluetooth LE connections,
/// and by a fake in tests. The protocol layer only sees bytes in and out.
abstract interface class ObdTransport {
  /// Bytes received from the adapter, in whatever chunks they arrive.
  Stream<List<int>> get input;

  /// Sends bytes to the adapter.
  Future<void> write(List<int> bytes);
}
