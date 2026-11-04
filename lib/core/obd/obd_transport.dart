/// A byte connection to an ELM327 adapter.
///
/// Implemented by the classic Bluetooth (serial) and Bluetooth LE connections,
/// and by a fake in tests. The protocol layer only sees bytes in and out.
abstract interface class ObdTransport {
  /// Bytes received from the adapter, in whatever chunks they arrive. Ends,
  /// with or without an error, when the connection does.
  Stream<List<int>> get input;

  /// Sends bytes to the adapter. Throws [TransportClosed] if the connection
  /// is gone.
  Future<void> write(List<int> bytes);
}

/// The connection to the adapter is gone, as found while writing to it.
class TransportClosed implements Exception {
  const TransportClosed();

  @override
  String toString() => 'TransportClosed';
}
