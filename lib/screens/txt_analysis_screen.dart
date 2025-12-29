import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_lis_parser/services/data_processing_service.dart';
import 'package:flutter_lis_parser/services/file_service.dart';
import 'package:flutter_lis_parser/utils/file_download_helper.dart';
//import '../services/services.dart';

class TxtAnalysisScreen extends StatefulWidget {
  const TxtAnalysisScreen({super.key});

  @override
  State<TxtAnalysisScreen> createState() => _TxtAnalysisScreenState();
}

class _TxtAnalysisScreenState extends State<TxtAnalysisScreen> {
  List<FlSpot> chartData = [];
  List<FlSpot> upTrendData = [];
  List<FlSpot> downTrendData = [];
  List<FlSpot> stableTrendData = [];
  bool isLoading = false;
  String errorMessage = '';
  bool isZoomMode = false;
  String? selectedTxtFile;
  Uint8List? selectedTxtFileBytes;
  String? selectedTxtFileName;

  // Thông tin xu hướng
  String currentTrend = '';
  double currentSlope = 0.0;
  bool isDepthIncreasing = true;

  // Thông tin tách file
  Map<String, dynamic>? splitResult;
  bool showSplitOptions = false;

  // Dữ liệu bảng
  List<List<String>> tableData = [];
  List<String> headerList = [];

  // Phân trang
  int currentPage = 0;
  int rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    // File sẽ được chọn thông qua file picker
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            selectedTxtFileBytes = result.files.single.bytes;
            selectedTxtFileName = result.files.single.name;
            selectedTxtFile = result.files.single.name;
          } else {
            selectedTxtFile = result.files.single.path!;
          }
          errorMessage = '';
        });
        _loadChartData();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Lỗi khi chọn file: $e';
      });
    }
  }

  Future<void> _loadChartData() async {
    if (selectedTxtFile == null) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
      chartData.clear();
      upTrendData.clear();
      downTrendData.clear();
      stableTrendData.clear();
      splitResult = null;
      tableData.clear();
      headerList.clear();
      currentPage = 0; // Reset về trang đầu
    });

    try {
      // Đọc file TXT
      Map<String, dynamic> txtResult;
      if (kIsWeb) {
        if (selectedTxtFileBytes == null) return;
        txtResult = await FileService.readTXTFromBytes(
          selectedTxtFileBytes!,
          selectedTxtFileName!,
        );
      } else {
        txtResult = await FileService.readTXT(selectedTxtFile!);
      }

      if (!txtResult['success']) {
        throw Exception(txtResult['message']);
      }

      List<List<String>> dataRows = txtResult['dataRows'];
      if (dataRows.isEmpty) {
        throw Exception('Không có dữ liệu hợp lệ để vẽ!');
      }

      // Lưu dữ liệu bảng
      headerList = txtResult['headerList'] ?? [];
      tableData = dataRows;

      // Tách file dựa trên cột DIR nếu có
      Map<String, dynamic> splitFileResult;
      if (kIsWeb) {
        splitFileResult = await FileService.splitTxtFileFromBytes(
          selectedTxtFileBytes!,
          selectedTxtFileName!,
        );
      } else {
        splitFileResult = await FileService.splitTxtFile(selectedTxtFile!);
      }

      if (splitFileResult['success']) {
        splitResult = splitFileResult;
        showSplitOptions = true;
      }

      // Tạo dữ liệu cho biểu đồ với trục đảo ngược
      List<double> xList = [];
      List<double> yList = [];

      for (List<String> row in dataRows) {
        if (row.length >= 2) {
          double? x = double.tryParse(row[0]); // TIME (seconds)
          double? y = double.tryParse(row[1]); // DEPTH

          if (x != null && y != null) {
            xList.add(x);
            yList.add(y);
          }
        }
      }

      if (xList.isEmpty || yList.isEmpty) {
        throw Exception('Không có dữ liệu hợp lệ để vẽ!');
      }

      // Phân tích xu hướng depth
      Map<String, dynamic> trendAnalysis =
          DataProcessingService.analyzeDepthTrend(yList);
      currentTrend = trendAnalysis['trend'];
      currentSlope = trendAnalysis['slope'];
      isDepthIncreasing = trendAnalysis['isIncreasing'];

      // Tạo chart data với trục đảo ngược: giá trị Y là X, TIME/DEPTH X là Y
      List<FlSpot> allSpots = [];
      for (int i = 0; i < xList.length; i++) {
        allSpots.add(
          FlSpot(yList[i], xList[i]),
        ); // Đổi trục: depth là X, time là Y
      }

      // Phân loại dữ liệu theo xu hướng cho màu sắc
      _categorizeDataByTrend(allSpots);

      setState(() {
        chartData = allSpots;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _categorizeDataByTrend(List<FlSpot> spots) {
    if (spots.length < 2) {
      stableTrendData = spots;
      return;
    }

    upTrendData.clear();
    downTrendData.clear();
    stableTrendData.clear();

    for (int i = 0; i < spots.length - 1; i++) {
      FlSpot current = spots[i];
      FlSpot next = spots[i + 1];

      double depthDiff = next.x - current.x; // Chênh lệch depth

      if (depthDiff > 0.05) {
        // Xu hướng tăng (depth tăng)
        upTrendData.add(current);
        if (i == spots.length - 2) upTrendData.add(next);
      } else if (depthDiff < -0.05) {
        // Xu hướng giảm (depth giảm)
        downTrendData.add(current);
        if (i == spots.length - 2) downTrendData.add(next);
      } else {
        // Xu hướng ổn định
        stableTrendData.add(current);
        if (i == spots.length - 2) stableTrendData.add(next);
      }
    }
  }

  Future<void> _downloadSplitFile(String content, String fileName) async {
    final bytes = utf8.encode(content);
    await FileDownloadHelper.downloadFile(Uint8List.fromList(bytes), fileName);
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'TĂNG':
        return Colors.green;
      case 'GIẢM':
        return Colors.red;
      case 'KHÔNG ĐỔI':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _buildColorLegend(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân tích file TXT, DXT'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(isZoomMode ? Icons.pan_tool : Icons.zoom_in),
            onPressed: () {
              setState(() {
                isZoomMode = !isZoomMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = '';
                chartData.clear();
                upTrendData.clear();
                downTrendData.clear();
                stableTrendData.clear();
                splitResult = null;
                showSplitOptions = false;
              });
              _loadChartData();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // File selection section - toàn bộ chiều rộng
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedTxtFile != null
                            ? 'File: ${selectedTxtFile!.split('/').last.split('\\').last}'
                            : 'Chưa chọn file TXT',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Chọn File TXT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Layout chính: Bảng dữ liệu bên trái, đồ thị và thông tin bên phải
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bảng dữ liệu bên trái (30% chiều rộng)
                  Expanded(
                    flex: 30,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dữ liệu TXT',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: selectedTxtFile == null
                                  ? const Center(
                                      child: Text(
                                        'Chưa có dữ liệu',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : errorMessage.isNotEmpty
                                  ? const Center(
                                      child: Text(
                                        'Có lỗi xảy ra',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    )
                                  : _buildDataTable(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Đồ thị ở giữa (40% chiều rộng)
                  Expanded(
                    flex: 40,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Biểu đồ phân tích',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: selectedTxtFile == null
                                  ? const Center(
                                      child: Text(
                                        'Vui lòng chọn file TXT',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : errorMessage.isNotEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            size: 48,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Lỗi: $errorMessage',
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                  : _buildChart(),
                            ),
                            if (!isLoading &&
                                errorMessage.isEmpty &&
                                selectedTxtFile != null)
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  'Điểm dữ liệu: ${chartData.length} | '
                                  'Chế độ: ${isZoomMode ? "Zoom" : "Pan"} | '
                                  'Xu hướng: $currentTrend',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Thông tin bên phải (30% chiều rộng)
                  Expanded(
                    flex: 30,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Trend analysis section
                          if (currentTrend.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          currentTrend == 'TĂNG'
                                              ? Icons.trending_up
                                              : currentTrend == 'GIẢM'
                                              ? Icons.trending_down
                                              : Icons.trending_flat,
                                          color: _getTrendColor(currentTrend),
                                          size: 32,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Xu hướng',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Độ sâu: $currentTrend',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _getTrendColor(currentTrend),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hệ số góc: ${currentSlope.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Split file section
                          if (showSplitOptions && splitResult != null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tách file theo DIR',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      splitResult!['message'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    if (kIsWeb) ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _downloadSplitFile(
                                            splitResult!['upContent'],
                                            splitResult!['upFileName'],
                                          ),
                                          icon: const Icon(
                                            Icons.file_download,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'UP File',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _downloadSplitFile(
                                            splitResult!['downContent'],
                                            splitResult!['downFileName'],
                                          ),
                                          icon: const Icon(
                                            Icons.file_download,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'DOWN File',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Chú thích màu sắc
                          if (currentTrend.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chú thích màu',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildColorLegend('Tăng', Colors.green),
                                    _buildColorLegend('Giảm', Colors.red),
                                    _buildColorLegend('Ổn định', Colors.orange),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (chartData.isEmpty) {
      return const Center(child: Text('Không có dữ liệu để hiển thị'));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Colors.grey, strokeWidth: 0.5);
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(color: Colors.grey, strokeWidth: 0.5);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Depth'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: null,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('TIME'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: null,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        lineBarsData: [
          // Đường xu hướng tăng (xanh lá)
          if (upTrendData.isNotEmpty)
            LineChartBarData(
              spots: upTrendData,
              isCurved: false,
              color: Colors.green,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          // Đường xu hướng giảm (đỏ)
          if (downTrendData.isNotEmpty)
            LineChartBarData(
              spots: downTrendData,
              isCurved: false,
              color: Colors.red,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          // Đường xu hướng ổn định (cam)
          if (stableTrendData.isNotEmpty)
            LineChartBarData(
              spots: stableTrendData,
              isCurved: false,
              color: Colors.orange,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          // Đường chính (xanh dương) nếu không có phân loại
          if (upTrendData.isEmpty &&
              downTrendData.isEmpty &&
              stableTrendData.isEmpty)
            LineChartBarData(
              spots: chartData,
              isCurved: false,
              color: Colors.blue,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
        // Đảo trục Y để TIME/DEPTH thấp ở phía trên, cao ở phía dưới
        minY: chartData.isNotEmpty
            ? chartData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
            : 10,
        maxY: chartData.isNotEmpty
            ? chartData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b)
            : 0,
        // Tắt hoàn toàn mọi interaction và tooltip
        lineTouchData: LineTouchData(
          enabled: false,
          touchTooltipData: LineTouchTooltipData(getTooltipItems: (_) => []),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (tableData.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    // Tính toán phân trang
    final totalRows = tableData.length;
    final totalPages = (totalRows / rowsPerPage).ceil();
    final startIndex = currentPage * rowsPerPage;
    final endIndex = (startIndex + rowsPerPage).clamp(0, totalRows);
    final displayData = tableData.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Thông tin phân trang
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiển thị ${startIndex + 1}-$endIndex / $totalRows dòng',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Row(
                children: [
                  Text('Dòng/trang:', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: rowsPerPage,
                    items: [25, 50, 100, 200].map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          rowsPerPage = value;
                          currentPage = 0; // Reset về trang đầu
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bảng dữ liệu
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                columns: headerList.map((header) {
                  return DataColumn(
                    label: Text(
                      header,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
                rows: displayData.map((row) {
                  return DataRow(
                    cells: row.map((cell) {
                      return DataCell(
                        Text(cell, style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Điều khiển phân trang
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: currentPage > 0
                    ? () => setState(() => currentPage = 0)
                    : null,
                tooltip: 'Trang đầu',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 0
                    ? () => setState(() => currentPage--)
                    : null,
                tooltip: 'Trang trước',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Trang ${currentPage + 1} / $totalPages',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages - 1
                    ? () => setState(() => currentPage++)
                    : null,
                tooltip: 'Trang sau',
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: currentPage < totalPages - 1
                    ? () => setState(() => currentPage = totalPages - 1)
                    : null,
                tooltip: 'Trang cuối',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
