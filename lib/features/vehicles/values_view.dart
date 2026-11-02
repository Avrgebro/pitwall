import '../../core/format/text_query.dart';
import '../../core/readings/readings.dart';

/// What the values page lists: the values in reach, split by where they
/// come from, narrowed by the search.
class ValuesView {
  /// [category] keeps only the profile values OBDb files under it.
  factory ValuesView.of(
    List<ValueOption> all, {
    String? category,
    TextQuery query = TextQuery.none,
  }) {
    final options = category == null
        ? all
        : [
            for (final option in all)
              if (option.category == category) option,
          ];
    final shown = [
      for (final option in options)
        if (query.matches([option.name, option.key])) option,
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
      searched: !query.isEmpty,
      // Matches are what was searched for, and a category is what was
      // asked for, so neither waits to be opened.
      profileForcedOpen: !query.isEmpty || category != null,
    );
  }

  const ValuesView._({
    required this.options,
    required this.standard,
    required this.profile,
    required this.searched,
    required this.profileForcedOpen,
  });

  /// Every value in reach, before the search.
  final List<ValueOption> options;

  /// The standard values to list.
  final List<ValueOption> standard;

  /// The profile values to list.
  final List<ValueOption> profile;

  /// Whether a search is narrowing the lists.
  final bool searched;

  /// Whether the profile values list with no row to fold them away.
  final bool profileForcedOpen;

  bool get nothingMatches => searched && standard.isEmpty && profile.isEmpty;

  int sentCount(Set<String> sent) =>
      options.where((o) => sent.contains(o.key)).length;
}
