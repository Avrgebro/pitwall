import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// A text file the user picked.
class PickedFile {
  const PickedFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

/// Thrown when a picked file can't be used as text.
class UnreadableFileException implements Exception {
  const UnreadableFileException({this.tooLarge = false});

  final bool tooLarge;
}

/// Lets the user pick files, behind an interface so screens and controllers
/// can be tested without a phone.
abstract interface class FileGateway {
  /// Asks the user for a JSON file. Null if they cancel.
  ///
  /// Throws [UnreadableFileException] if it's too large or not text.
  Future<PickedFile?> pickJson({int maxBytes});
}

class FilePickerGateway implements FileGateway {
  const FilePickerGateway();

  @override
  Future<PickedFile?> pickJson({int maxBytes = 5 * 1024 * 1024}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    if ((await file.length() ?? 0) > maxBytes) {
      throw const UnreadableFileException(tooLarge: true);
    }
    try {
      return PickedFile(
        name: file.name,
        contents: utf8.decode(await file.readAsBytes()),
      );
    } on FormatException {
      throw const UnreadableFileException();
    }
  }
}
