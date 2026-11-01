/// Turns a vehicle's display name into the `device` id sent in payloads:
/// lower case, accents removed, everything else collapsed into single
/// dashes. "Hyundai Tucson" → `hyundai-tucson`, "Citroën C3 (2019)" →
/// `citroen-c3-2019`.
///
/// Easy to match in automations and safe in URLs, topics and entity ids.
String deviceIdFor(String name) {
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folded[char] ?? char);
  }
  final id = buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return id.isEmpty ? fallbackDeviceId : id;
}

/// Used when a name has nothing that survives, like "🚗".
const fallbackDeviceId = 'my-car';

/// Latin letters with accents and ligatures, mapped to plain ASCII.
const _folded = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', //
  'æ': 'ae', 'ç': 'c', 'č': 'c', 'ć': 'c', 'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e', 'ę': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'œ': 'oe', 'ř': 'r', 'ś': 's', 'š': 's', 'ß': 'ss', 'ť': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u',
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};
