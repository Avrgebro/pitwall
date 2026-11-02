import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/format/formatters.dart';

void main() {
  test('numbers get thousands separators and lose trailing zeros', () {
    expect(Formatters.number(33999.7, decimals: 0), '34,000');
    expect(Formatters.number(1234567.25), '1,234,567.3');
    expect(Formatters.number(47.5), '47.5');
    expect(Formatters.number(52), '52');
    expect(Formatters.number(-40.0), '-40');
  });

  test('relative times read naturally', () {
    final now = DateTime(2026, 10, 31, 18, 47);

    expect(
      Formatters.ago(now.subtract(const Duration(seconds: 3)), now),
      'just now',
    );
    expect(
      Formatters.ago(now.subtract(const Duration(seconds: 40)), now),
      '40 s ago',
    );
    expect(
      Formatters.ago(now.subtract(const Duration(minutes: 3)), now),
      '3 min ago',
    );
    expect(
      Formatters.ago(now.subtract(const Duration(hours: 2)), now),
      '2 h ago',
    );
    expect(Formatters.ago(DateTime(2026, 10, 30, 22), now), 'yesterday');
    expect(Formatters.ago(DateTime(2026, 10, 28), now), '3 days ago');
    expect(Formatters.ago(DateTime(2026, 10, 12), now), '12 Oct');
  });

  test('intervals and durations', () {
    expect(Formatters.every(const Duration(minutes: 1)), 'every minute');
    expect(Formatters.every(const Duration(seconds: 30)), 'every 30 seconds');
    expect(
      Formatters.every(const Duration(minutes: 5), capitalised: true),
      'Every 5 minutes',
    );
    expect(Formatters.duration(const Duration(minutes: 24)), '24 min');
    expect(Formatters.duration(const Duration(minutes: 65)), '1 h 5 min');
    expect(Formatters.elapsed(const Duration(milliseconds: 312)), '0.3 s');
  });
}
