import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/format/text_query.dart';
import 'package:pitwall/core/readings/metric.dart';
import 'package:pitwall/core/readings/readings.dart';
import 'package:pitwall/features/vehicles/values_view.dart';

const _speed = ValueOption(Metrics.vehicleSpeed);
const _fuel = ValueOption(
  Metric(key: 'tucson_fli_vol', name: 'Fuel level', unit: 'L'),
  category: 'Fuel',
);
const _tyre = ValueOption(
  Metric(key: 'tucson_tp_fl', name: 'Front left tyre pressure', unit: 'kPa'),
  category: 'Tires',
);
const _all = [_speed, _fuel, _tyre];

void main() {
  test('splits the values by where they come from', () {
    final view = ValuesView.of(_all);
    expect(view.standard, [_speed]);
    expect(view.profile, [_fuel, _tyre]);
    expect(view.profileList.showsToggle, isTrue);
    expect(view.profileList.showsList, isFalse);
  });

  test('a search narrows both lists and opens the profile ones', () {
    final view = ValuesView.of(_all, query: TextQuery('FUEL'));
    expect(view.standard, isEmpty);
    expect(view.profile, [_fuel]);
    expect(view.profileList.showsToggle, isFalse);
    expect(view.profileList.showsList, isTrue);
  });

  test('a search matches payload keys too', () {
    expect(ValuesView.of(_all, query: TextQuery('tp_fl')).profile, [_tyre]);
  });

  test('a category keeps only its profile values, opened', () {
    final view = ValuesView.of(_all, category: 'Tires');
    expect(view.options, [_tyre]);
    expect(view.standard, isEmpty);
    expect(view.profileList.showsToggle, isFalse);
    expect(view.profileList.showsList, isTrue);
    expect(view.sentCount({'tucson_tp_fl', 'speed_kmh'}), 1);
  });
}
