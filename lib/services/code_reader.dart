// CodeReader service - converted from C++ ReadCode functions

import 'dart:math' as math;
import 'dart:typed_data';

import '../constants/lis_constants.dart';

class CodeReader {
  // Chuyển số thập phân sang chuỗi bát phân (octal)
  String toOctal(double value, {int precision = 6}) {
    int intPart = value.floor();
    double fracPart = value - intPart;
    String octal = '${intPart.toRadixString(8)}.';
    for (int i = 0; i < precision; i++) {
      fracPart *= 8;
      int digit = fracPart.floor();
      octal += digit.toString();
      fracPart -= digit;
    }
    return octal;
  }

  static Uint8List encodeCode68(double value) {
    if (value == 0.0) return Uint8List.fromList([0, 0, 0, 0]);
    int signBit, exponent, fraction;
    double absValue = value.abs();
    // Chuyển thập phân sang bát phân trước
    String octalStrFull = CodeReader().toOctal(
      absValue,
      precision: 8,
    ); // VD: "231.31415..."
    List<String> parts = octalStrFull.split('.');
    int intPartOctal = int.parse(parts[0]);
    String fracPartOctalStr = parts.length > 1 ? parts[1] : '';
    // Chuẩn hóa về dạng M*2^E, M thuộc [0.5, 1.0)
    int E = 0;
    double norm = absValue;
    while (norm >= 1.0) {
      norm /= 2.0;
      E++;
    }
    while (norm < 0.5) {
      norm *= 2.0;
      E--;
    }
    //E++;
    // Lấy phần thập phân nhị phân
    // norm nằm trong [0.5, 1.0), cần encode phần thập phân (bỏ 0.5)
    int fracBits = 0;
    double remainingFrac = norm; // Bắt đầu từ giá trị đã normalize
    double bitValue = 0.5; // Bit đầu tiên đại diện cho 0.5
    for (int i = 22; i >= 0; i--) {
      if (remainingFrac >= bitValue) {
        fracBits |= (1 << i);
        remainingFrac -= bitValue;
      }
      bitValue /= 2.0;
    }
    if (value >= 0) {
      signBit = 0;
      exponent = E + 128;
      fraction = fracBits;
    } else {
      signBit = 1;
      exponent = 127 - E;
      fraction = (~fracBits + 1) & 0x7FFFFF;
    }
    print(
      'encodeCode68: S = \u001b[33m$signBit\u001b[0m, E (bin) = \u001b[32m$E\u001b[0m, exponent = \u001b[36m$exponent\u001b[0m, F = \u001b[35m$fraction\u001b[0m',
    );
    int byte0 = (signBit << 7) | ((exponent & 0xFF) >> 1);
    int byte1 = ((exponent & 0x1) << 7) | ((fraction >> 16) & 0x7F);
    int byte2 = (fraction >> 8) & 0xFF;
    int byte3 = fraction & 0xFF;
    return Uint8List.fromList([byte0, byte1, byte2, byte3]);
  }

  static double decodeCode68(Uint8List bytes) {
    if (bytes.length != 4) throw ArgumentError('Code68 requires 4 bytes');
    int b0 = bytes[0];
    int b1 = bytes[1];
    int b2 = bytes[2];
    int b3 = bytes[3];
    int signBit = (b0 >> 7) & 0x1;
    int exponent = ((b0 & 0x7F) << 1) | ((b1 >> 7) & 0x1);
    int fraction = ((b1 & 0x7F) << 16) | (b2 << 8) | b3;

    // Decode mantissa using factor array matching _read32BitFloat
    List<double> factor = [
      0,
      0.5,
      0.25,
      0.125,
      0.0625,
      0.03125,
      0.015625,
      0.0078125,
      0.00390625,
      0.001953125,
      0.0009765625,
      0.00048828125,
      0.000244140625,
      0.0001220703125,
      0.00006103515625,
      0.000030517578125,
      0.0000152587890625,
      0.00000762939453125,
      0.000003814697265625,
      0.0000019073486328125,
      0.00000095367431640625,
      0.000000476837158203125,
      0.0000002384185791015625,
      0.00000011920928955078125,
    ];

    if (signBit == 0) {
      // Số dương
      int mPart = fraction;
      double M = 0;
      int mPart2 = mPart << 8;
      for (int i = 0; i < 24; i++) {
        if ((mPart2 & 0x80000000) == 0x80000000) M += factor[i];
        mPart2 = mPart2 << 1;
      }
      int E = exponent;
      return M * math.pow(2.0, E - 128);
    } else {
      // Số âm
      int mPart = (~fraction + 1) & 0x7FFFFF;
      double M = 0;
      int mPart2 = mPart << 8;
      for (int i = 0; i < 24; i++) {
        if ((mPart2 & 0x80000000) == 0x80000000) M += factor[i];
        mPart2 = mPart2 << 1;
      }
      int E = exponent;
      return (M.abs() < 0.00000001) ? 0 : -M * math.pow(2.0, 127 - E);
    }
  }

  /// Mã hóa ngược lại từ double sang 4 byte kiểu float LIS (dựa trên _read32BitFloat)
  static Uint8List encode32BitFloatReverse(double value) {
    if (value == 0.0) return Uint8List.fromList([0, 0, 0, 0]);
    bool isNegative = value < 0;
    double absValue = value.abs();
    int E;
    double M;
    if (!isNegative) {
      // value = M * 2^(E - 128)
      double log2 = math.log(absValue) / math.ln2;
      E = (log2 + 128).floor();
      M = absValue / math.pow(2.0, E - 128);
    } else {
      // value = -M * 2^(127 - E)
      double log2 = math.log(absValue) / math.ln2;
      E = (127 - log2).floor();
      M = absValue / math.pow(2.0, 127 - E);
    }
    // Chuyển M thành mPart (giống decode)
    int mPart = 0;
    double remain = M;
    List<double> factor = [
      0,
      0.5,
      0.25,
      0.125,
      0.0625,
      0.03125,
      0.015625,
      0.0078125,
      0.00390625,
      0.001953125,
      0.0009765625,
      0.00048828125,
      0.000244140625,
      0.0001220703125,
      0.00006103515625,
      0.000030517578125,
      0.0000152587890625,
      0.00000762939453125,
      0.000003814697265625,
      0.0000019073486328125,
      0.00000095367431640625,
      0.000000476837158203125,
      0.0000002384185791015625,
      0.00000011920928955078125,
    ];
    for (int i = 1; i < factor.length; i++) {
      if (remain >= factor[i]) {
        mPart |= (1 << (23 - (i - 1)));
        remain -= factor[i];
      }
    }
    if (isNegative) {
      mPart = (~mPart + 1) & 0x7FFFFF;
    }
    int byte1 = isNegative ? (E >> 1) | 0x80 : (E >> 1);
    int byte2 = ((E & 1) << 7) | ((mPart >> 16) & 0x7F);
    int byte3 = (mPart >> 8) & 0xFF;
    int byte4 = mPart & 0xFF;
    return Uint8List.fromList([byte1, byte2, byte3, byte4]);
  }

  /// Giải mã 4 byte kiểu float LIS về double

  static dynamic readCode(Uint8List entry, int reprCode, int size) {
    switch (reprCode) {
      case 56: // Signed byte
        return _readSignedByte(entry);
      case 65: // Character string - trả về chuỗi gốc
        return String.fromCharCodes(entry.sublist(0, size)).trim();
      case 66: // Unsigned byte
        return entry[0].toDouble();
      case 68: // 32-bit float
        return _read32BitFloat(entry);
      case 73: // 32-bit integer
        return _read32BitInteger(entry);
      case 79: // 16-bit integer
        return _read16BitInteger(entry);
      default:
        throw Exception('Unknown representation code: $reprCode');
    }
  }

  static int getCodeSize(int code) {
    switch (code) {
      case 49:
        return 2;
      case 50:
        return 4;
      case 56:
        return 1;
      case 66:
        return 1;
      case 68:
        return 4;
      case 70:
        return 4;
      case 73:
        return 4;
      case 79:
        return 2;
      default:
        throw Exception('Unknown code size for code: $code');
    }
  }

  static int getCodeType(int code) {
    switch (code) {
      case 49:
      case 50:
      case 68:
      case 70:
        return LisConstants.typeFloat;
      case 56:
      case 66:
      case 73:
      case 79:
        return LisConstants.typeInt;
      case 65:
        return LisConstants.typeChar;
      default:
        return LisConstants.typeUnknown;
    }
  }

  static double _readSignedByte(Uint8List entry) {
    int ch = entry[0];
    if (ch < 128) {
      return ch.toDouble();
    } else {
      int result = ch;
      result = ~result;
      result = result + 1;
      return (-1 * result).toDouble();
    }
  }

  static double _readDepthUnit(Uint8List entry, int size) {
    final chars = List.generate(size, (i) => entry[i]);
    String unit = String.fromCharCodes(chars).trim().toUpperCase();

    // Accept a few common variants used in LIS headers
    switch (unit) {
      case 'CM':
      case 'CMS':
        return LisConstants.depthUnitCm.toDouble();
      case '.5MM':
      case '0.5MM':
        return LisConstants.depthUnitHmm.toDouble();
      case 'MM':
      case 'MMS':
        return LisConstants.depthUnitMm.toDouble();
      case 'M':
      case 'METRE':
      case 'METERS':
      case 'METRE(S)':
        return LisConstants.depthUnitM.toDouble();
      case 'FT':
      case 'FEET':
      case "'":
        return LisConstants.depthUnitFeet.toDouble();
      case '.1IN':
      case '0.1IN':
        return LisConstants.depthUnitP1in.toDouble();
      default:
        return LisConstants.depthUnitUnknown.toDouble();
    }
  }

  static double _read32BitFloat(Uint8List entry) {
    int byte1 = entry[0];
    int byte2 = entry[1];
    int byte3 = entry[2];
    int byte4 = entry[3];

    int ePart = ((byte1 << 1) & 0xFF) + (byte2 >= 128 ? 1 : 0);
    int mPart = ((byte2 << 16) | (byte3 << 8) | byte4) & 0x7FFFFF;

    double M = 0;
    List<double> factor = [
      0,
      0.5,
      0.25,
      0.125,
      0.0625,
      0.03125,
      0.015625,
      0.0078125,
      0.00390625,
      0.001953125,
      0.0009765625,
      0.00048828125,
      0.000244140625,
      0.0001220703125,
      0.00006103515625,
      0.000030517578125,
      0.0000152587890625,
      0.00000762939453125,
      0.000003814697265625,
      0.0000019073486328125,
      0.00000095367431640625,
      0.000000476837158203125,
      0.0000002384185791015625,
      0.00000011920928955078125,
    ];

    if (byte1 >= 128) {
      mPart = (~mPart + 1) & 0x7FFFFF;
    }

    int E = ePart;
    int mPart2 = mPart << 8;
    for (int i = 0; i < 24; i++) {
      if ((mPart2 & 0x80000000) == 0x80000000) M += factor[i];
      mPart2 = mPart2 << 1;
    }

    double value;
    if (byte1 < 128) {
      value = M * math.pow(2.0, E - 128);
    } else {
      value = (M.abs() < 0.00000001) ? 0 : -M * math.pow(2.0, 127 - E);
    }

    return value;
  }

  /// Mã hóa số thực thành 4 byte kiểu float LIS (big endian)

  static double _read32BitInteger(Uint8List entry) {
    int ch0 = entry[0];
    int ch1 = entry[1];
    int ch2 = entry[2];
    int ch3 = entry[3];

    int result = 0;
    result |= (ch0 << 24);
    result |= (ch1 << 16);
    result |= (ch2 << 8);
    result |= ch3;

    if (ch0 >= 128) {
      // Negative number
      result = ~result;
      result = result + 1;
      return (-1 * result).toDouble();
    }

    return result.toDouble();
  }

  static double _read16BitInteger(Uint8List entry) {
    // Read as big-endian 16-bit value
    int value = (entry[0] << 8) | entry[1];

    // Check if this is a negative value (MSB set)
    if (value >= 0x8000) {
      // Convert from two's complement to negative
      value = value - 0x10000;
    }

    return value.toDouble();
  }

  /// Mã hóa giá trị thành Uint8List cho từng reprCode
  static Uint8List encodeSignedByte(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([v & 0xFF]);
  }

  static Uint8List encodeAscii(dynamic value, int size) {
    String str = value?.toString() ?? '';
    List<int> bytes = str.padRight(size).codeUnits;
    return Uint8List.fromList(bytes.take(size).toList());
  }

  static Uint8List encodeUnsignedByte(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([v & 0xFF]);
  }

  static Uint8List encode32BitFloat(double value) {
    if (value == 0.0) return Uint8List.fromList([0, 0, 0, 0]);
    bool isNegative = value < 0;
    double absValue = value.abs();
    // Đầu tiên thử encode đặc biệt như cũ
    int E = 0;
    double M = 0;
    for (int e = 127; e >= 0; e--) {
      double v = 0.5 * math.pow(2.0, 127 - e);
      if ((absValue - v).abs() < 0.0001) {
        E = e;
        M = 0.5;
        break;
      }
    }
    if (M != 0) {
      int byte1 = isNegative ? (E >> 1) | 0x80 : (E >> 1);
      int byte2 = ((E & 1) << 7) | 0x40;
      int byte3 = 0;
      int byte4 = 0;
      return Uint8List.fromList([byte1, byte2, byte3, byte4]);
    }
    // Nếu không phải giá trị đặc biệt, encode ngược lại từ logic decode32BitFloat
    // Tìm E và M phù hợp
    if (!isNegative) {
      // value = M * 2^(E - 128)
      double log2 = math.log(absValue) / math.ln2;
      E = (log2 + 128).floor();
      M = absValue / math.pow(2.0, E - 128);
    } else {
      // value = -M * 2^(127 - E)
      double log2 = math.log(absValue) / math.ln2;
      E = (127 - log2).floor();
      M = absValue / math.pow(2.0, 127 - E);
    }
    // Chuyển M thành mPart (giống decode)
    int mPart = 0;
    double remain = M;
    List<double> factor = [
      0,
      0.5,
      0.25,
      0.125,
      0.0625,
      0.03125,
      0.015625,
      0.0078125,
      0.00390625,
      0.001953125,
      0.0009765625,
      0.00048828125,
      0.000244140625,
      0.0001220703125,
      0.00006103515625,
      0.000030517578125,
      0.0000152587890625,
      0.00000762939453125,
      0.000003814697265625,
      0.0000019073486328125,
      0.00000095367431640625,
      0.000000476837158203125,
      0.0000002384185791015625,
      0.00000011920928955078125,
    ];
    for (int i = 1; i < factor.length; i++) {
      if (remain >= factor[i]) {
        mPart |= (1 << (23 - (i - 1)));
        remain -= factor[i];
      }
    }
    if (isNegative) {
      mPart = (~mPart + 1) & 0x7FFFFF;
    }
    int byte1 = isNegative ? (E >> 1) | 0x80 : (E >> 1);
    int byte2 = ((E & 1) << 7) | ((mPart >> 16) & 0x7F);
    int byte3 = (mPart >> 8) & 0xFF;
    int byte4 = mPart & 0xFF;
    return Uint8List.fromList([byte1, byte2, byte3, byte4]);
  }

  static Uint8List encode32BitInteger(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ]);
  }

  static Uint8List encode16BitInteger(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([(v >> 8) & 0xFF, v & 0xFF]);
  }

  /// Hàm tổng hợp gọi từng hàm encode theo reprCode
  static Uint8List encode(dynamic value, int reprCode, int size) {
    switch (reprCode) {
      case 56:
        return encodeSignedByte(value);
      case 65:
        return encodeAscii(value, size);
      case 66:
        return encodeUnsignedByte(value);
      case 68:
        //return encode32BitFloat(value);
        //return encode32BitFloatReverse(value);
        //return encodeCode68(value);
        return _encodeRussianLisFloat(value);
      case 73:
        return encode32BitInteger(value);
      case 79:
        return encode16BitInteger(value);
      default:
        throw Exception('Unknown representation code for encode: $reprCode');
    }
  }

  static _encodeRussianLisFloat(double value) {
    // Custom encoding algorithm matching C++ ReadCode logic
    //print('DEBUG ENCODE: input value=$value');

    if (value == 0.0) {
      final result = Uint8List.fromList([0, 0, 0, 0]);
      //print('DEBUG ENCODE: zero -> bytes=[${result.join(', ')}]');
      return result;
    }

    // Handle sign bit
    bool isNegative = value < 0;
    double absValue = value.abs();

    // Normalize fraction to [0.5, 1.0) range
    double targetFraction = absValue;
    int exponentBits;

    if (!isNegative) {
      // Positive: value = M * 2^(E - 128)
      exponentBits = 128;
      while (targetFraction >= 1.0) {
        targetFraction /= 2.0;
        exponentBits++;
      }
      while (targetFraction < 0.5) {
        targetFraction *= 2.0;
        exponentBits--;
      }
    } else {
      // Negative: value = -M * 2^(127 - E)
      // So: 127 - E = log2(absValue/M)
      // => E = 127 - log2(absValue/M)
      exponentBits = 127;
      while (targetFraction >= 1.0) {
        targetFraction /= 2.0;
        exponentBits--; // Decrease for negative!
      }
      while (targetFraction < 0.5) {
        targetFraction *= 2.0;
        exponentBits++; // Increase for negative!
      }
    }

    // Clamp exponent to valid range
    exponentBits = exponentBits.clamp(0, 255);

    // Convert fraction to 23-bit mantissa using C++ algorithm
    int mantissaBits = 0;
    double remainingFraction = targetFraction;
    double bitValue = 0.5;
    for (int i = 22; i >= 0; i--) {
      if (remainingFraction >= bitValue) {
        mantissaBits |= (1 << i);
        remainingFraction -= bitValue;
      }
      bitValue /= 2.0;
    }

    // Handle negative numbers - C++ does complement operation
    if (isNegative) {
      mantissaBits = (~mantissaBits + 1) & 0x7FFFFF;
    }

    // Assemble bytes according to Russian LIS format:
    // Byte 0: [S][E7-E1]
    // Byte 1: [E0][M22-M16]
    // Byte 2: [M15-M8]
    // Byte 3: [M7-M0]
    int ch0 = (isNegative ? 0x80 : 0x00) | ((exponentBits >> 1) & 0x7F);
    int ch1 = ((exponentBits & 0x01) << 7) | ((mantissaBits >> 16) & 0x7F);
    int ch2 = (mantissaBits >> 8) & 0xFF;
    int ch3 = mantissaBits & 0xFF;

    final encoded = Uint8List.fromList([ch0, ch1, ch2, ch3]);
    // print(
    //   'DEBUG ENCODE: value=$value, isNeg=$isNegative, exp=$exponentBits, mantissa=0x${mantissaBits.toRadixString(16).padLeft(6, '0')} -> bytes=[${encoded.join(', ')}]',
    // );
    return encoded;
  }
}
