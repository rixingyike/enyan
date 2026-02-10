import 'dart:io';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

@singleton
class DatabaseHelper {
  String _dbName = 'bible_chs.db'; // Default to Simplified
  static Database? _database;

  Future<void> switchDatabase(bool isSimplified) async {
    final newName = isSimplified ? 'bible_chs.db' : 'bible_cht.db';
    if (_dbName == newName && _database != null) return;

    print('Switching database to: $newName');
    _dbName = newName;

    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    // Check if DB exists
    final exists = await databaseExists(path);

    if (!exists) {
      // Should move db from assets to documents
      print('Creating new copy from asset: $_dbName');
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from assets
      ByteData data = await rootBundle.load(join('assets', _dbName));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      print('Opening existing database: $_dbName');
    }

    return await openDatabase(path, version: 1);
  }
}
