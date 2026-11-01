import 'package:material_ui/material_ui.dart';

/// A row showing the current choice; tapping it opens the other options.
class SelectTile<T> extends StatelessWidget {
  const SelectTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    initialValue: value,
    onSelected: onChanged,
    position: PopupMenuPosition.under,
    itemBuilder: (context) => [
      for (final option in options)
        PopupMenuItem(value: option, child: Text(labelOf(option))),
    ],
    child: ListTile(
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: Text(labelOf(value)),
      trailing: const Icon(Icons.arrow_drop_down),
    ),
  );
}
