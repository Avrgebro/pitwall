import '../../core/format/text_query.dart';
import '../../core/readings/readings.dart';
import '../../ui/components/disclosure.dart';

/// What the values page lists: the values in reach, split by where they
/// come from, narrowed by the search.
class ValuesView {
  /// [category] keeps only the profile values OBDb files under it, and
  /// [profileOpen] is whether the user opened the profile values.
  factory ValuesView.of(
    List<ValueOption> all, {
    String? category,
    TextQuery query = TextQuery.none,
    bool profileOpen = false,
  }) {
    final options = category == null
        ? all
        : [
            for (final option in all)
              if (option.category == category) option,
          ];
    final shown = [
      for (final option in options)
        if (query.matches([option.metric.name, option.metric.key])) option,
    ];
    return ValuesView._(
      options: options,
      standard: [
        for (final o in shown)
          if (!o.fromProfile) o,
      ],
      profile: [
        for (final o in shown)
          if (o.fromProfile) o,
      ],
      // Matches are what was searched for, and a category is what was
      // asked for, so neither waits to be opened.
      profileList: Disclosure(
        forced: !query.isEmpty || category != null,
        open: profileOpen,
      ),
    );
  }

  const ValuesView._({
    required this.options,
    required this.standard,
    required this.profile,
    required this.profileList,
  });

  /// Every value in reach, before the search.
  final List<ValueOption> options;

  /// The standard values to list.
  final List<ValueOption> standard;

  /// The profile values to list.
  final List<ValueOption> profile;

  /// Whether the profile values list, and whether a row folds them.
  final Disclosure profileList;

  int sentCount(Set<String> sent) =>
      options.where((o) => sent.contains(o.metric.key)).length;
}
