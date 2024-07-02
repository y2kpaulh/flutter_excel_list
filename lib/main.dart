import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '기간별 수익',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RevenueScreen(),
    );
  }
}

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  RevenueScreenState createState() => RevenueScreenState();
}

class RevenueScreenState extends State<RevenueScreen> {
  String _selectedPeriod = '일';
  final List<String> _periodOptions = ['일', '주', '월', '년'];
  Map<String, List<Map<String, dynamic>>> revenueDataMap = {};
  late Directory directory;

  @override
  void initState() {
    super.initState();

    _initializeDirectory();
    _generateAllPeriodData();
  }

  Future<void> _initializeDirectory() async {
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        Directory? externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          directory = externalDirectory;
        } else {
          // 외부 저장소 디렉토리가 null인 경우 스낵바로 알림
          _showSnackBar('외부 저장소 디렉토리를 찾을 수 없습니다.');
        }
      }
    } catch (e) {
      _showSnackBar('디렉토리 초기화 중 오류가 발생했습니다.');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
      ));
    }
  }

  // 모든 기간에 대한 더미 데이터 생성 함수
  Future<void> _generateAllPeriodData() async {
    await [Permission.storage].request();

    for (String period in _periodOptions) {
      revenueDataMap[period] = _generateDummyRevenueData(period);
    }
    setState(() {});
  }

  // 더미 데이터 생성 함수
  List<Map<String, dynamic>> _generateDummyRevenueData(String period) {
    Random random = Random();
    int itemCount;
    switch (period) {
      case '일':
        itemCount = 7;
        break;
      case '주':
        itemCount = 4;
        break;
      case '월':
        itemCount = 12;
        break;
      case '년':
        itemCount = 5;
        break;
      default:
        itemCount = 0;
    }

    return List.generate(itemCount, (index) {
      return {
        'date': _getDateLabel(period, index + 1),
        'revenue': random.nextDouble() * 1000,
      };
    });
  }

  String _getDateLabel(String period, int index) {
    switch (period) {
      case '일':
        return '2024-07-${index.toString().padLeft(2, '0')}';
      case '주':
        return '2024-07-${index.toString().padLeft(2, '0')}주';
      case '월':
        return '2024-${index.toString().padLeft(2, '0')}';
      case '년':
        return '202${index}년';
      default:
        return '';
    }
  }

  // 엑셀 파일 생성 및 저장 함수
  Future<void> _generateExcel(
      Map<String, List<Map<String, dynamic>>> dataMap) async {
    var excel = Excel.createExcel();

    // 기본 "Sheet1" 시트를 제거
    excel.delete('Sheet1');

    dataMap.forEach((period, data) {
      Sheet sheetObject = excel[period];

      // 설명 추가
      sheetObject.appendRow([TextCellValue('기간별 수익 데이터 - $period')]);

      // 헤더 추가
      sheetObject
          .appendRow([const TextCellValue('날짜'), const TextCellValue('수익')]);

      // 데이터 추가
      for (var entry in data) {
        sheetObject.appendRow([
          TextCellValue(entry['date'].toString()),
          TextCellValue(entry['revenue'].toString()),
        ]);
      }
    });

    // 현재 날짜와 시간 가져오기
    String formattedDate =
        DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

    // 파일 제목 생성
    String fileTitle = '기간별_수익_$formattedDate.xlsx';

    String filePath = '${directory.path}/$fileTitle';
    File file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    // 파일 열기
    OpenFile.open(filePath);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('엑셀 파일이 저장되었습니다: $filePath'),
      ));
    }

    // // 권한 요청
    // if (await Permission.storage.request().isGranted) {
    //   // 파일 저장
    //   final directory = await getApplicationDocumentsDirectory();
    //   String filePath = '${directory.path}/$fileTitle';
    //   File file = File(filePath)
    //     ..createSync(recursive: true)
    //     ..writeAsBytesSync(excel.encode()!);
    //
    //   // 파일 열기
    //   OpenFile.open(filePath);
    //
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //       content: Text('엑셀 파일이 저장되었습니다: $filePath'),
    //     ));
    //   }
    // } else {
    //   if (mounted) {
    //     // 권한이 거부된 경우
    //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    //       content: Text('저장소 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
    //     ));
    //   }
    // }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> selectedPeriodData =
        revenueDataMap[_selectedPeriod] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('기간별 수익'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPeriod = newValue!;
                });
              },
              items:
                  _periodOptions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: selectedPeriodData.length,
              itemBuilder: (context, index) {
                var item = selectedPeriodData[index];
                return ListTile(
                  title: Text(item['date']),
                  subtitle: Text('수익: ${item['revenue'].toStringAsFixed(0)}원'),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _generateExcel(revenueDataMap);
        },
        child: const Icon(Icons.save),
      ),
    );
  }
}
