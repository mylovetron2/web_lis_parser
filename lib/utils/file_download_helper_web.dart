// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation for file download
Future<void> downloadFileImpl(Uint8List bytes, String fileName) async {
  // Create a blob from the bytes
  final blob = html.Blob([bytes]);

  // Create a download URL
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create an anchor element and trigger download
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  // Clean up the URL
  html.Url.revokeObjectUrl(url);
}
