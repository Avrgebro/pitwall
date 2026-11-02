import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// A spinner where content is still loading, set apart from what's around
/// it.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(Insets.xl),
    child: Center(child: CircularProgressIndicator()),
  );
}
