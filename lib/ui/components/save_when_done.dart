import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Saves what's typed in [child] once typing is done, rather than on every
/// key: when focus leaves its fields (Done on the keyboard does that),
/// when the app goes to the background, and when it leaves the screen,
/// however it leaves.
///
/// [onDone] can run after the screen is gone, so it mustn't look anything
/// up through the widget tree, or read objects disposed with it; capture
/// what it needs beforehand. It can also run more than once for the same
/// text, say on leaving the field and then the screen, so saving the same
/// value again must change nothing. A failure is reported, as nothing
/// awaits it.
class SaveWhenDone extends StatefulWidget {
  const SaveWhenDone({super.key, required this.onDone, required this.child});

  final AsyncCallback onDone;
  final Widget child;

  @override
  State<SaveWhenDone> createState() => _SaveWhenDoneState();
}

class _SaveWhenDoneState extends State<SaveWhenDone> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _save);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Just after, once the tree has settled: state can't change while
    // widgets are being taken down.
    scheduleMicrotask(_save);
    super.dispose();
  }

  void _save() => unawaited(
    widget.onDone().catchError(
      (Object error, StackTrace stack) => FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'saving typed text',
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      if (!focused) _save();
    },
    child: widget.child,
  );
}
