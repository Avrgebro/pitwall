import 'package:material_ui/material_ui.dart';

import '../../../ui/ui.dart';

/// What a page about one vehicle shows once the vehicle is gone, say after
/// it was deleted while the page was open underneath.
class VehicleRemovedPage extends StatelessWidget {
  const VehicleRemovedPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => AppPage(
    title: title,
    children: const [
      InfoNote(text: TextSpan(text: 'This vehicle was removed.')),
    ],
  );
}
