/// Formatting shared by screens: numbers, durations and times in the
/// app's plain style.
abstract final class Formatters {
  /// `33999.7` → `33,999.7`; whole numbers lose the decimal (`52`).
  static String number(num value, {int decimals = 1}) {
    final rounded = value.toStringAsFixed(decimals);
    var (whole, fraction) = rounded.contains('.')
        ? (rounded.split('.')[0], rounded.split('.')[1])
        : (rounded, '');
    final negative = whole.startsWith('-');
    if (negative) whole = whole.substring(1);
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
      grouped.write(whole[i]);
    }
    fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    return '${negative ? '-' : ''}$grouped${fraction.isEmpty ? '' : '.$fraction'}';
  }

  /// "every 30 seconds", "every minute", "every 5 minutes".
  static String every(Duration interval) {
    if (interval.inSeconds < 60) return 'every ${interval.inSeconds} seconds';
    if (interval.inMinutes == 1) return 'every minute';
    return 'every ${interval.inMinutes} minutes';
  }

  /// "Every 30 s", "Every minute", "Every 5 minutes", for pickers.
  static String interval(Duration interval) {
    if (interval.inSeconds < 60) return 'Every ${interval.inSeconds} s';
    final minutes = interval.inMinutes;
    return minutes == 1 ? 'Every minute' : 'Every $minutes minutes';
  }

  /// "just now", "40 s ago", "3 min ago", "2 h ago", "yesterday", "12 Oct".
  static String ago(DateTime time, DateTime now) {
    final elapsed = now.difference(time);
    if (elapsed.inSeconds < 10) return 'just now';
    if (elapsed.inSeconds < 60) return '${elapsed.inSeconds} s ago';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24 && _sameDay(time, now)) {
      return '${elapsed.inHours} h ago';
    }
    if (_sameDay(time, now.subtract(const Duration(days: 1)))) {
      return 'yesterday';
    }
    if (elapsed.inDays < 7) return '${elapsed.inDays} days ago';
    return date(time);
  }

  /// "12 Oct".
  static String date(DateTime time) => '${time.day} ${_months[time.month - 1]}';

  /// "24 min", "1 h 5 min".
  static String duration(Duration duration) {
    if (duration.inMinutes < 60) return '${duration.inMinutes} min';
    final minutes = duration.inMinutes % 60;
    return '${duration.inHours} h${minutes == 0 ? '' : ' $minutes min'}';
  }

  /// "0.3 s", "1.2 s".
  static String elapsed(Duration duration) =>
      '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';

  /// "18:49".
  static String clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// "18:49:02".
  static String clockWithSeconds(DateTime time) =>
      '${clock(time)}:${time.second.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
