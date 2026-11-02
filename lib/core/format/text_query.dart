/// What's typed in a filter field, ready to match against: trimmed, and
/// matched without regard to case.
extension type const TextQuery._(String text) {
  TextQuery(String typed) : this._(typed.trim());

  static const none = TextQuery._('');

  bool get isEmpty => text.isEmpty;

  /// Whether any of [fields] contains the query. Everything matches an
  /// empty one.
  bool matches(Iterable<String> fields) {
    final query = text.toLowerCase();
    return fields.any((field) => field.toLowerCase().contains(query));
  }
}
