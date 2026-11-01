import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// The frame of every screen: a title (with a back arrow on sub-screens),
/// an optional subtitle, and scrolling content with page padding.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Pinned below the content, such as an input bar.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: subtitle == null
            ? Text(title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.l,
                Insets.s,
                Insets.l,
                Insets.xxl * 3,
              ),
              children: children,
            ),
          ),
          ?bottom,
        ],
      ),
    );
  }
}
