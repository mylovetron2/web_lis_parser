import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Desktop/Mobile implementation for file download
Future<void> downloadFileImpl(Uint8List bytes, String fileName) async {
  // Let user choose save location
  String? outputPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save File',
    fileName: fileName,
  );

  if (outputPath != null) {
    final file = File(outputPath);
    await file.writeAsBytes(bytes);
  }
}
