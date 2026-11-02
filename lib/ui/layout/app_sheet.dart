import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Shows a bottom sheet in the app's frame: a drag handle, page padding,
/// and room for the system bars. It grows with its content, up to just
/// below the status bar; longer content scrolls.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => SingleChildScrollView(
    padding: Insets.page.copyWith(bottom: Insets.xl),
    child: SafeArea(top: false, child: builder(context)),
  ),
);
