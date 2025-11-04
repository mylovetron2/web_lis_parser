import 'dart:io';
import 'dart:typed_data';

/// Abstract interface for file reading that works on both web and desktop
abstract class ByteFileReader {
  Future<int> position();
  Future<void> setPosition(int position);
  Future<Uint8List> read(int bytes);
  Future<int> length();
  Future<void> close();
  Future<void> writeFrom(Uint8List bytes);
  Future<void> flush();
  Future<Uint8List> getAllBytes();

  factory ByteFileReader.fromFile(RandomAccessFile file) =
      _RandomAccessFileReader;
  factory ByteFileReader.fromBytes(Uint8List bytes, String fileName) =
      _BytesReader;
}

/// Desktop implementation using RandomAccessFile
class _RandomAccessFileReader implements ByteFileReader {
  final RandomAccessFile _file;

  _RandomAccessFileReader(this._file);

  @override
  Future<int> position() async => _file.position();

  @override
  Future<void> setPosition(int position) async {
    await _file.setPosition(position);
  }

  @override
  Future<Uint8List> read(int bytes) async {
    final data = await _file.read(bytes);
    return Uint8List.fromList(data);
  }

  @override
  Future<int> length() async => _file.length();

  @override
  Future<void> close() async {
    await _file.close();
  }

  @override
  Future<void> writeFrom(Uint8List bytes) async {
    await _file.writeFrom(bytes);
  }

  @override
  Future<void> flush() async {
    await _file.flush();
  }

  @override
  Future<Uint8List> getAllBytes() async {
    final currentPos = await _file.position();
    await _file.setPosition(0);
    final fileLength = await _file.length();
    final allBytes = await _file.read(fileLength);
    await _file.setPosition(currentPos);
    return Uint8List.fromList(allBytes);
  }
}

/// Web implementation using in-memory bytes
class _BytesReader implements ByteFileReader {
  final Uint8List _bytes;
  int _position = 0;

  _BytesReader(this._bytes, String fileName);

  @override
  Future<int> position() async => _position;

  @override
  Future<void> setPosition(int position) async {
    if (position < 0 || position > _bytes.length) {
      throw RangeError(
        'Position $position is out of range [0, ${_bytes.length}]',
      );
    }
    _position = position;
  }

  @override
  Future<Uint8List> read(int bytes) async {
    final endPosition = _position + bytes;
    if (endPosition > _bytes.length) {
      // Read only available bytes
      final availableBytes = _bytes.length - _position;
      if (availableBytes <= 0) {
        return Uint8List(0);
      }
      final result = _bytes.sublist(_position, _bytes.length);
      _position = _bytes.length;
      return result;
    }
    final result = _bytes.sublist(_position, endPosition);
    _position = endPosition;
    return result;
  }

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<void> close() async {
    // Nothing to close for in-memory bytes
  }

  @override
  Future<void> writeFrom(Uint8List bytes) async {
    throw UnsupportedError('Write operations are not supported on web');
  }

  @override
  Future<void> flush() async {
    throw UnsupportedError('Flush operations are not supported on web');
  }

  @override
  Future<Uint8List> getAllBytes() async {
    // Return a copy of the bytes
    return Uint8List.fromList(_bytes);
  }
}
