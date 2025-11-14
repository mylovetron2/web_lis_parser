// Data Table Widget for displaying LIS file data

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/lis_file_parser.dart';
import '../utils/file_download_helper.dart';
import 'waveform_viewer_dialog.dart';

class DataTableWidget extends StatefulWidget {
  final LisFileParser parser;

  const DataTableWidget({super.key, required this.parser});

  @override
  State<DataTableWidget> createState() => _DataTableWidgetState();
}

class _DataTableWidgetState extends State<DataTableWidget> {
  List<Map<String, dynamic>> tableData = [];
  List<String> columnNames = [];
  bool isLoading = false;
  String errorMessage = '';
  int maxRows = 100000; // Increased limit - display all data
  int currentPage = 0;
  final int rowsPerPage = 50;

  // Editing state removed - edit mode no longer supported

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  // Download modified file
  Future<void> _downloadModifiedFile() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang chuẩn bị file để download...'),
            ],
          ),
        ),
      );

      // Calculate startAdrSave - address of first blank record before data records
      int startAdrSave = 0;
      if (widget.parser.startDataRec > 0 &&
          widget.parser.startDataRec < widget.parser.lisRecords.length) {
        final firstDataRecord =
            widget.parser.lisRecords[widget.parser.startDataRec];
        // Blank record is 16 bytes before the data record
        startAdrSave = firstDataRecord.addr - 16;
      }

      // Get modified bytes
      final modifiedBytes = await widget.parser.getModifiedFileBytes(
        tableData,
        columnNames,
        startAdrSave,
      );

      // Generate filename
      final downloadFileName = widget.parser.getDownloadFileName();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Trigger download
      if (kIsWeb) {
        FileDownloadHelper.downloadFile(modifiedBytes, downloadFileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã download file: $downloadFileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download chỉ khả dụng trên web browser'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Merge theo TIME: thay DEPTH trong LIS bằng DEPTH trong TXT
  Future<void> _mergeByTimeFromTxt() async {
    // Xác định cột độ sâu mục tiêu để merge
    // Không cần xác định targetCol hay originalTable nữa
    try {
      // Chọn file TXT bằng file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null || result.files.isEmpty) return;

      // Handle both web (bytes) and desktop (path)
      String txtContent;
      if (result.files.single.bytes != null) {
        // Web: read from bytes
        txtContent = String.fromCharCodes(result.files.single.bytes!);
      } else if (result.files.single.path != null) {
        // Desktop: read from file
        txtContent = await File(result.files.single.path!).readAsString();
      } else {
        throw Exception('Unable to read file');
      }

      final merged = widget.parser.mergeDepthToTable(
        txtContent: txtContent,
        tableData: tableData,
        columnNames: columnNames,
      );
      int matchCount = merged.length; // Số dòng còn lại sau merge

      // Update the table data in memory (works on both web and desktop)
      // Nếu sau merge có cột LSPD thì tự động thêm vào columnNames để hiển thị
      final hasLspd = merged.any((row) => row.containsKey('LSPD'));
      final newColumnNames = List<String>.from(columnNames);
      if (hasLspd && !newColumnNames.contains('LSPD')) {
        newColumnNames.add('LSPD');
      }
      setState(() {
        tableData = merged;
        columnNames = newColumnNames;
        currentPage = 0; // quay về trang đầu để dễ thấy thay đổi
      });

      // Note: File saving is not supported on web
      // On desktop, you can uncomment the following to save changes:
      // try {
      //   await widget.parser.saveTableData2Lis(
      //     tableData: merged,
      //     columnNames: columnNames,
      //     startAdrSave: 30381,
      //   );
      //   if (mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: Text('Đã lưu thay đổi vào file!'),
      //         backgroundColor: Colors.green,
      //       ),
      //     );
      //   }
      // } catch (e) {
      //   print('Cannot save file (expected on web): $e');
      // }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã merge DEPTH từ TXT cho $matchCount dòng TIME khớp!',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi merge: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadTableData() async {
    // Có thể sử dụng entryBlock ở đây nếu cần cho logic bảng
    if (!widget.parser.isFileOpen) {
      setState(() {
        errorMessage = 'No file is currently open';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Loading table data (silent)
      columnNames = widget.parser.getColumnNames();
      // Ví dụ: debug in ra một số thông tin từ EntryBlock
      print(
        'EntryBlock DataFrameSize: ${widget.parser.entryBlock.nDataFrameSize}',
      );
      print('EntryBlock Direction: ${widget.parser.entryBlock.nDirection}');
      // Debug column names information
      print('Column names: $columnNames');
      print('Number of columns: ${columnNames.length}');
      for (int i = 0; i < columnNames.length && i < 10; i++) {
        print('Column $i: ${columnNames[i]}');
      }
      // Column names loaded
      if (columnNames.isEmpty) {
        setState(() {
          errorMessage =
              'No column data available. Parser has ${widget.parser.curves.length} curves, startDataRec=${widget.parser.startDataRec}';
          isLoading = false;
        });
        return;
      }

      final data = await widget.parser
          .getTableData(); // No maxRows limit - get all data
      // Nếu muốn dùng entryBlock để custom hiển thị, có thể chỉnh sửa logic ở đây
      // Retrieved ${data.length} rows of data

      setState(() {
        tableData = data;
        isLoading = false;
      });

      if (tableData.isEmpty) {
        setState(() {
          errorMessage =
              'No data found in the file. startDataRec=${widget.parser.startDataRec}, endDataRec=${widget.parser.endDataRec}';
        });
      }
    } catch (e) {
      // Error loading table data: $e
      setState(() {
        errorMessage = 'Error loading data: $e';
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get currentPageData {
    final startIndex = currentPage * rowsPerPage;
    final endIndex = (startIndex + rowsPerPage).clamp(0, tableData.length);
    return tableData.sublist(startIndex, endIndex);
  }

  int get totalPages => (tableData.length / rowsPerPage).ceil();

  Future<void> _updateParserData(
    int rowIndex,
    String columnName,
    double newValue,
  ) async {
    try {
      // Lấy số frame/record động từ parser
      int framesPerRecord = 1;
      if (widget.parser.startDataRec >= 0 &&
          widget.parser.endDataRec >= widget.parser.startDataRec) {
        // Lấy frameNum của record đầu tiên (giả định các record có cùng số frame)
        framesPerRecord = widget.parser.getFrameNum(widget.parser.startDataRec);
        if (framesPerRecord <= 0) framesPerRecord = 1;
      }
      final recordIndex = rowIndex ~/ framesPerRecord;
      final frameIndex = rowIndex % framesPerRecord;

      final success = await widget.parser.updateDataValue(
        recordIndex: recordIndex,
        frameIndex: frameIndex,
        columnName: columnName,
        newValue: newValue,
      );

      if (!success) {
        // Failed to update parser data for $columnName
      }
    } catch (e) {
      // Error updating parser data: $e
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading data...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadTableData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (tableData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Column(
      children: [
        // Header with file info and controls
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.table_chart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Data Table',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    // Nút merge DEPTH theo TIME
                    IconButton(
                      onPressed: _mergeByTimeFromTxt,
                      icon: const Icon(Icons.merge_type),
                      tooltip: 'Merge DEPTH từ TXT theo TIME',
                    ),
                    const SizedBox(width: 8),
                    // Download button
                    IconButton(
                      onPressed: _downloadModifiedFile,
                      icon: const Icon(Icons.download),
                      tooltip: 'Download file đã chỉnh sửa',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${tableData.length} rows'),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip('Columns', '${columnNames.length}'),
                    _buildInfoChip('Format', widget.parser.fileTypeString),
                    _buildInfoChip(
                      'Start Depth',
                      '${widget.parser.startDepth.toStringAsFixed(2)}m',
                    ),
                    _buildInfoChip(
                      'End Depth',
                      '${widget.parser.endDepth.toStringAsFixed(2)}m',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Pagination controls
        if (totalPages > 1) _buildPaginationControls(),

        // Data table
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  columns: [
                    ...columnNames.map(
                      (name) => DataColumn(
                        label: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  rows: currentPageData.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final row = entry.value;

                    return DataRow(
                      cells: columnNames.map((columnName) {
                        final value = row[columnName] ?? 'N/A';

                        if (value is Map && value['isArray'] == true) {
                          return DataCell(
                            InkWell(
                              onTap: () => _showWaveformDialog(
                                context,
                                value['datumName'],
                                value['recordIdx'],
                                value['frameIdx'],
                                double.tryParse(
                                      row['DEPTH']?.toString() ?? '0',
                                    ) ??
                                    0.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '...',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.show_chart,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        // Regular cell - display only
                        return DataCell(
                          Text(
                            value.toString(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: value == 'NULL' || value == 'N/A'
                                  ? Theme.of(context).colorScheme.outline
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        // Bottom pagination
        if (totalPages > 1) _buildPaginationControls(),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      labelStyle: const TextStyle(fontSize: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  void _showWaveformDialog(
    BuildContext context,
    String datumName,
    int recordIdx,
    int frameIdx,
    double depth,
  ) {
    showDialog(
      context: context,
      builder: (context) => WaveformViewerDialog(
        parser: widget.parser,
        datumName: datumName,
        recordIdx: recordIdx,
        frameIdx: frameIdx,
        depth: depth,
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${currentPage + 1} of $totalPages',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Row(
              children: [
                IconButton(
                  onPressed: currentPage > 0
                      ? () => setState(() => currentPage = 0)
                      : null,
                  icon: const Icon(Icons.first_page),
                  tooltip: 'First page',
                ),
                IconButton(
                  onPressed: currentPage > 0
                      ? () => setState(() => currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous page',
                ),
                IconButton(
                  onPressed: currentPage < totalPages - 1
                      ? () => setState(() => currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next page',
                ),
                IconButton(
                  onPressed: currentPage < totalPages - 1
                      ? () => setState(() => currentPage = totalPages - 1)
                      : null,
                  icon: const Icon(Icons.last_page),
                  tooltip: 'Last page',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
