import 'dart:typed_data';

import 'lib/services/code_reader.dart';

void main() {
  // Test decode BB B3 80 00
  var bytes = Uint8List.fromList([0xBB, 0xB3, 0x80, 0x00]);
  var decoded = CodeReader.readCode(bytes, 68, 4);
  print('Bytes BB B3 80 00 decode to: $decoded');

  // Test encode -153
  var encoded = CodeReader.encode(-153.0, 68, -1);
  print(
    'Value -153 encodes to: ${encoded.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
  );

  // Test encode -24.55
  var encoded2 = CodeReader.encode(-24.55, 68, -1);
  print(
    'Value -24.55 encodes to: ${encoded2.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
  );
}
