import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FileService {
  // Đọc file TXT từ bytes (cho web platform)
  static Future<Map<String, dynamic>> readTXTFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      String content = utf8.decode(bytes);
      List<String> lines = content.split('\n');
      return _processTXTLines(lines);
    } catch (e) {
      return {
        'headerList': [],
        'unitList': [],
        'dataRows': [],
        'success': false,
        'message': 'Lỗi khi đọc file TXT từ bytes: $e',
      };
    }
  }

  // Đọc file TXT (tương đương readTXT trong C++)
  static Future<Map<String, dynamic>> readTXT(String txtPath) async {
    try {
      File txtFile = File(txtPath);
      if (!await txtFile.exists()) {
        throw Exception('Không mở được file TXT!');
      }

      List<String> lines = await txtFile.readAsLines(encoding: utf8);
      return _processTXTLines(lines);
    } catch (e) {
      return {
        'headerList': [],
        'unitList': [],
        'dataRows': [],
        'success': false,
        'message': 'Lỗi khi đọc file TXT: $e',
      };
    }
  }

  // Xử lý nội dung TXT từ danh sách lines
  static Map<String, dynamic> _processTXTLines(List<String> lines) {
    List<String> headerList = [];
    List<String> unitList = [];
    List<List<String>> dataRows = [];

    bool foundHeader = false;
    bool foundUnit = false;

    for (String line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Bỏ qua dòng ngày tháng hoặc dòng tiêu đề phụ
      if (trimmedLine.toLowerCase().contains('- time - recorder') ||
          trimmedLine.toLowerCase().contains('depth') ||
          trimmedLine.toLowerCase().contains('logging') ||
          trimmedLine.toLowerCase().contains('vietsovpetro') ||
          trimmedLine.toLowerCase().contains('recorder') ||
          RegExp(r'^\d{1,2}/\d{1,2}/\d{4}').hasMatch(trimmedLine)) {
        continue;
      }

      List<String> parts = trimmedLine.split(RegExp(r'\s+'));

      // Nhận diện dòng header (TIME DEPT ...)
      if (!foundHeader &&
          parts.isNotEmpty &&
          (parts[0].toUpperCase() == 'TIME' ||
              parts[0].toUpperCase() == 'DEPTH')) {
        headerList = parts;
        foundHeader = true;
        continue;
      }

      // Nhận diện dòng đơn vị (nếu có)
      if (foundHeader &&
          !foundUnit &&
          parts.isNotEmpty &&
          (parts[0].contains(':') ||
              parts[0].contains('M') ||
              parts[0].contains('S'))) {
        unitList = parts;
        foundUnit = true;
        continue;
      }

      // Nhận diện dòng dữ liệu bắt đầu bằng TIME hợp lệ (0:00:00:01 ...)
      if (parts.isNotEmpty &&
          RegExp(r'^\d+:\d{2}:\d{2}:\d{2}$').hasMatch(parts[0])) {
        dataRows.add(parts);
      }
    }

    // Chuyển đổi TIME sang giây cho từng dòng dữ liệu
    for (List<String> row in dataRows) {
      if (row.isNotEmpty) {
        String timeStr = row[0];
        List<String> timeParts = timeStr.split(':');
        int totalSeconds = 0;

        if (timeParts.length == 4) {
          int days = int.tryParse(timeParts[0]) ?? 0;
          int hours = int.tryParse(timeParts[1]) ?? 0;
          int minutes = int.tryParse(timeParts[2]) ?? 0;
          int seconds = int.tryParse(timeParts[3]) ?? 0;
          totalSeconds = days * 86400 + hours * 3600 + minutes * 60 + seconds;
        } else if (timeParts.length == 3) {
          int hours = int.tryParse(timeParts[0]) ?? 0;
          int minutes = int.tryParse(timeParts[1]) ?? 0;
          int seconds = int.tryParse(timeParts[2]) ?? 0;
          totalSeconds = hours * 3600 + minutes * 60 + seconds;
        }

        row[0] = totalSeconds.toString();

        // Xử lý giá trị DEPTH
        if (row.length > 1) {
          double? depthVal = double.tryParse(row[1]);
          if (depthVal != null) {
            double depthFloor = (depthVal * 10).floor() / 10.0;
            row[1] = depthFloor.toStringAsFixed(3);
          }
        }
      }
    }

    // Debug logging

    print('Data rows: ${dataRows.length}');

    return {
      'headerList': headerList,
      'unitList': unitList,
      'dataRows': dataRows,
      'success': true,
      'message': 'Đọc file TXT thành công',
    };
  }

  // Tách file TXT dựa trên cột DIR (từ bytes cho web platform)
  static Future<Map<String, dynamic>> splitTxtFileFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      String content = utf8.decode(bytes);
      List<String> lines = content.split('\n');
      return _splitTxtLines(lines, fileName);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi khi tách file TXT từ bytes: $e',
        'upContent': '',
        'downContent': '',
      };
    }
  }

  // Tách file TXT dựa trên cột DIR
  static Future<Map<String, dynamic>> splitTxtFile(String txtPath) async {
    try {
      File txtFile = File(txtPath);
      if (!await txtFile.exists()) {
        throw Exception('Không mở được file TXT!');
      }

      List<String> lines = await txtFile.readAsLines(encoding: utf8);
      String fileName = txtPath.split('/').last.split('\\').last;
      return _splitTxtLines(lines, fileName);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi khi tách file TXT: $e',
        'upContent': '',
        'downContent': '',
      };
    }
  }

  // Xử lý logic tách file dựa trên cột DIR
  static Map<String, dynamic> _splitTxtLines(
    List<String> lines,
    String fileName,
  ) {
    // Tìm cột DIR trong header
    int dirColIdx = -1;
    int headerLineIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      List<String> parts = line.split(RegExp(r'\s+'));
      for (int j = 0; j < parts.length; j++) {
        if (parts[j].toUpperCase() == 'DIR') {
          dirColIdx = j;
          headerLineIdx = i;
          break;
        }
      }
      if (dirColIdx != -1) break;
    }

    if (dirColIdx == -1 || headerLineIdx == -1) {
      return {
        'success': false,
        'message': 'Không tìm thấy cột DIR trong file!',
        'upContent': '',
        'downContent': '',
      };
    }

    // Tạo nội dung cho file UP và DOWN
    List<String> upLines = [];
    List<String> downLines = [];

    // Giữ nguyên cấu trúc header cho cả 2 file
    for (int i = 0; i <= headerLineIdx; i++) {
      upLines.add(lines[i]);
      downLines.add(lines[i]);
    }

    // Phân loại dữ liệu dựa trên cột DIR
    int upCount = 0;
    int downCount = 0;

    for (int i = headerLineIdx + 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      List<String> parts = line.split(RegExp(r'\s+'));
      if (parts.length <= dirColIdx) continue;

      int dir = int.tryParse(parts[dirColIdx]) ?? -1;

      if (dir == 0) {
        downLines.add(lines[i]);
        downCount++;
      } else if (dir == 1) {
        upLines.add(lines[i]);
        upCount++;
      }
    }

    // Tạo tên file mới
    String baseName = fileName.replaceAll('.txt', '').replaceAll('.TXT', '');
    String upFileName = '${baseName}_up.txt';
    String downFileName = '${baseName}_down.txt';

    return {
      'success': true,
      'message':
          'Tách file thành công!\nUP: $upCount dòng\nDOWN: $downCount dòng',
      'upContent': upLines.join('\n'),
      'downContent': downLines.join('\n'),
      'upFileName': upFileName,
      'downFileName': downFileName,
      'upCount': upCount,
      'downCount': downCount,
    };
  }
}
