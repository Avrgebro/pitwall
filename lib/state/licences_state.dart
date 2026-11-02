import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One package and the licence texts it ships with.
@immutable
class PackageLicences {
  const PackageLicences(this.name, this.texts);

  final String name;
  final List<String> texts;
}

/// The licences of every package Pitwall is built with, by package and
/// sorted by name. Read from Flutter's licence registry, the same source
/// as its built-in licence page; it's collected once.
///
/// Splitting a licence into paragraphs is slow and runs on the UI thread,
/// so, as Flutter's licence page does, each licence is its own scheduler
/// task, and frames keep coming while the page opens.
final licencesProvider = FutureProvider<List<PackageLicences>>((ref) async {
  final byPackage = <String, List<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final text = await SchedulerBinding.instance.scheduleTask(
      () => entry.paragraphs.map(_paragraph).join('\n\n'),
      Priority.animation,
      debugLabel: 'Licence',
    );
    for (final package in entry.packages) {
      (byPackage[package] ??= []).add(text);
    }
  }
  final names = byPackage.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [for (final name in names) PackageLicences(name, byPackage[name]!)];
});

/// A paragraph as plain text, keeping its indentation.
String _paragraph(LicenseParagraph paragraph) =>
    paragraph.indent == LicenseParagraph.centeredIndent
    ? paragraph.text
    : '${'  ' * paragraph.indent}${paragraph.text}';
