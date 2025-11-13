import 'dart:math';
//import '../models/models.dart';

class DataProcessingService {
  // Chuyển đổi chuỗi thời gian thành giây (tương đương timeStringToSeconds trong C++)
  static int timeStringToSeconds(String timeStr) {
    List<String> parts = timeStr.split(':');
    if (parts.length != 4) {
      return 0; // hoặc xử lý lỗi
    }

    int days = int.tryParse(parts[0]) ?? 0;
    int hours = int.tryParse(parts[1]) ?? 0;
    int minutes = int.tryParse(parts[2]) ?? 0;
    int seconds = int.tryParse(parts[3]) ?? 0;

    return (days * 86400 + hours * 3600 + minutes * 60 + seconds) * 1000;
  }

  // Chuyển đổi giây thành chuỗi thời gian
  static String secondsToTimeString(int totalSeconds) {
    totalSeconds = totalSeconds ~/ 1000;
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // Phân tích xu hướng độ sâu bằng hồi quy tuyến tính
  static Map<String, dynamic> analyzeDepthTrend(List<double> depthList) {
    if (depthList.length <= 1) {
      return {'trend': 'KHÔNG ĐỔI', 'slope': 0.0, 'isIncreasing': true};
    }

    int n = depthList.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += depthList[i];
      sumXY += i * depthList[i];
      sumXX += i * i;
    }

    double slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    String trend;
    bool isIncreasing;

    if (slope > 0.0) {
      trend = 'TĂNG';
      isIncreasing = true;
    } else if (slope < 0.0) {
      trend = 'GIẢM';
      isIncreasing = false;
    } else {
      trend = 'KHÔNG ĐỔI';
      isIncreasing = true;
    }

    return {'trend': trend, 'slope': slope, 'isIncreasing': isIncreasing};
  }

  // Tạo dãy độ sâu đều và nội suy giá trị
  static Map<String, List<double>> createRegularDepthsWithInterpolation(
    List<double> dosauList,
  ) {
    if (dosauList.length <= 1) {
      return {'regularDepths': [], 'interpolatedValues': []};
    }

    List<double> regularDepths = [];
    List<double> interpolatedValues = [];

    double minDepth = dosauList.reduce(min);
    double maxDepth = dosauList.reduce(max);

    if (minDepth > maxDepth) {
      double temp = minDepth;
      minDepth = maxDepth;
      maxDepth = temp;
    }

    // Tạo dãy độ sâu đều với step 0.1
    for (double d = minDepth; d <= maxDepth + 1e-6; d += 0.1) {
      double dRound = (d * 1000).round() / 1000.0;
      regularDepths.add(dRound);
    }

    // Tạo map độ sâu gốc -> giá trị
    Map<double, double> depthToValue = {};
    for (double v in dosauList) {
      depthToValue[v] = v;
    }

    // Nội suy tuyến tính cho các độ sâu đều nếu thiếu
    for (double d in regularDepths) {
      if (depthToValue.containsKey(d)) {
        interpolatedValues.add(depthToValue[d]!);
      } else {
        // Tìm 2 điểm gần nhất để nội suy
        double d1 = minDepth, d2 = maxDepth;
        for (double v in dosauList) {
          if (v < d && v > d1) d1 = v;
          if (v > d && v < d2) d2 = v;
        }

        if (d1 == d2) {
          interpolatedValues.add(d1);
        } else {
          // Nội suy tuyến tính
          double v1 = d1, v2 = d2;
          double interp = v1 + (v2 - v1) * (d - d1) / (d2 - d1);
          interpolatedValues.add(interp);
        }
      }
    }

    return {
      'regularDepths': regularDepths,
      'interpolatedValues': interpolatedValues,
    };
  }
}
