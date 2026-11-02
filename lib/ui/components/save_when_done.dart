import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Saves what's typed in [child] once typing is done, rather than on every
/// key: when focus leaves its fields (Done on the keyboard does that),
/// when the app goes to the background, and when it leaves the screen,
/// however it leaves.
///
/// [onDone] can run after the screen is gone, so it mustn't look anything
/// up through the widget tree; capture what it needs beforehand.
class SaveWhenDone extends StatefulWidget {
  const SaveWhenDone({super.key, required this.onDone, required this.child});

  final VoidCallback onDone;
  final Widget child;

  @override
  State<SaveWhenDone> createState() => _SaveWhenDoneState();
}

class _SaveWhenDoneState extends State<SaveWhenDone> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: () => widget.onDone());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Just after, once the tree has settled: state can't change while
    // widgets are being taken down.
    scheduleMicrotask(widget.onDone);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      if (!focused) widget.onDone();
    },
    child: widget.child,
  );
}
