import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/readings/readings.dart';
import '../../../state/settings_state.dart';
import '../../../ui/ui.dart';

/// A page about one vehicle: built with its values, which carry the
/// vehicle, while it exists. Once it's gone, say deleted while the page was
/// open underneath, the page says so instead.
class VehiclePage extends ConsumerWidget {
  const VehiclePage({
    super.key,
    required this.vehicleId,
    required this.title,
    required this.builder,
  });

  final String vehicleId;

  /// The page's title while loading, or once the vehicle is gone.
  final String title;

  final Widget Function(BuildContext context, VehicleValues values) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    if (!settings.hasValue) {
      return settings.hasError
          ? _note('Couldn\'t read the settings.', tone: StatusTone.error)
          : AppPage.loading(title: title);
    }
    return switch (ref.watch(vehicleValuesProvider(vehicleId))) {
      final values? => builder(context, values),
      null => _note('This vehicle was removed.'),
    };
  }

  Widget _note(String text, {StatusTone? tone}) => AppPage(
    title: title,
    children: [
      InfoNote(
        tone: tone,
        text: TextSpan(text: text),
      ),
    ],
  );
}
