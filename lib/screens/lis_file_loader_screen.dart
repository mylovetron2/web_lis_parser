import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/lis_file_class.dart';

class LisFileLoaderScreen extends StatefulWidget {
  const LisFileLoaderScreen({super.key});

  @override
  State<LisFileLoaderScreen> createState() => _LisFileLoaderScreenState();
}

class _LisFileLoaderScreenState extends State<LisFileLoaderScreen> {
  String? filePath;
  LISFileClass? lisFileClass;
  String status = '';
  int logicalRecordNum = 0;
  int logicalFileNum = 0;
  int dataSetNum = 0;

  Future<void> pickAndLoadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null) {
      String? path;
      try {
        path = result.files.single.path;
      } catch (e) {
        // On web, path is not available
        path = null;
      }

      if (path != null) {
        setState(() {
          filePath = path;
          status = 'Đang load file...';
        });
        lisFileClass = LISFileClass(strFileName: filePath!);
        await lisFileClass!.parse();

        await lisFileClass!.createLogicalFileArr();
        await lisFileClass!.parseLogicalFile(0);
        await lisFileClass!.createDataSet();
        setState(() {
          logicalRecordNum = lisFileClass!.lrArr.length;
          logicalFileNum = lisFileClass!.logicalFileArr.length;
          dataSetNum = lisFileClass!.datasetArr.length;
          status = 'Đã load xong!';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test LISFileClass Loader')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: pickAndLoadFile,
              child: const Text('Chọn và load file LIS'),
            ),
            const SizedBox(height: 16),
            Text('Trạng thái: $status'),
            if (filePath != null) ...[
              Text('File: $filePath'),
              Text('Số Logical Record: $logicalRecordNum'),
              Text('Số Logical File: $logicalFileNum'),
              Text('Số DataSet: $dataSetNum'),
              const SizedBox(height: 16),
              if (lisFileClass != null)
                Expanded(
                  child: ListView.builder(
                    itemCount: lisFileClass!.lisRecords.length,
                    itemBuilder: (context, index) {
                      final record = lisFileClass!.lisRecords[index];
                      return ListTile(
                        title: Text('Record ${index + 1}: ${record.typeName}'),
                        subtitle: Text(
                          'Addr: ${record.addr}, Len: ${record.length}, Name: ${record.name}',
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
