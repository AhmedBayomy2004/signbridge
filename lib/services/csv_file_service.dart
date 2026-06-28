import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

class CsvFileService {
  static Future<List<List<dynamic>>> readFullCsv(String path) async {
    final rawData = await rootBundle.loadString(path);

    final stream = Stream.value(rawData);
    final rowsAsListOfValues = await stream.transform(csv.decoder).toList();

    return rowsAsListOfValues;
  }

  static Future<List<dynamic>> readSingleColumnCsv(String path) async {
    final rawData = await rootBundle.loadString(path);

    final stream = Stream.value(rawData);
    final rows = await stream.transform(csv.decoder).toList();

    // كل row عبارة عن List فيها عنصر واحد
    // فبناخد أول عنصر من كل صف
    return rows.map((row) => row[0]).toList();
  }
}
