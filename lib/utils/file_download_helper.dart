import 'dart:typed_data';

import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_io.dart';

/// Helper class to download files on different platforms
class FileDownloadHelper {
  /// Download bytes as a file
  static Future<void> downloadFile(Uint8List bytes, String fileName) async {
    await downloadFileImpl(bytes, fileName);
  }
}
