/// Whether [a] is the Bluetooth address [b]. Addresses compare without
/// case: Android reports them upper case, but stored ones may differ.
bool sameAddress(String? a, String b) =>
    a != null && a.toUpperCase() == b.toUpperCase();
