import 'dart:typed_data';

import 'lib/services/code_reader.dart';

void main() {
  // Test decode various negative values
  print('=== DECODE TESTS ===');
  var test1 = Uint8List.fromList([0xBB, 0xB3, 0x80, 0x00]);
  print('BB B3 80 00 → ${CodeReader.readCode(test1, 68, 4)}');

  var test2 = Uint8List.fromList([0xC2, 0x1D, 0xCC, 0xCD]);
  print('C2 1D CC CD → ${CodeReader.readCode(test2, 68, 4)}');

  var test3 = Uint8List.fromList([0xBD, 0x1D, 0xCC, 0xCD]);
  print('BD 1D CC CD → ${CodeReader.readCode(test3, 68, 4)}');

  print('\n=== ENCODE TESTS ===');
  var enc1 = CodeReader.encode(-153.0, 68, -1);
  print(
    '-153.0 → ${enc1.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
  );

  var enc2 = CodeReader.encode(-24.55, 68, -1);
  print(
    '-24.55 → ${enc2.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
  );

  var enc3 = CodeReader.encode(24.55, 68, -1);
  print(
    '24.55 → ${enc3.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
  );

  print('\n=== ROUND-TRIP TESTS ===');
  var encoded = CodeReader.encode(-24.55, 68, -1);
  var decoded = CodeReader.readCode(encoded, 68, 4);
  print('-24.55 encode → decode: $decoded (diff: ${(-24.55 - decoded).abs()})');
}
