import 'dart:io';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

@singleton
class DatabaseHelper {
  static const int CURRENT_DB_VERSION = 20260212;
  static const String _keyDbVersion = 'bible_db_version';
  
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
    // Check for downloaded pack first (PackDownloadService saves to packs/:id/)
    final appDir = await getApplicationDocumentsDirectory();
    final packDbPath = join(appDir.path, 'packs', _dbName.contains('chs') ? 'lang_chs' : 'lang_cht', _dbName);
    
    if (await File(packDbPath).exists()) {
      print('📦 [DB] Loading from downloaded pack: $packDbPath');
      return await openDatabase(packDbPath, version: 1);
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    // Version check for forced upgrade
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt(_keyDbVersion) ?? 0;
    
    // Check if DB exists in sqflite's internal storage
    final exists = await databaseExists(path);

    bool shouldCopy = !exists || savedVersion < CURRENT_DB_VERSION;

    if (shouldCopy) {
      if (savedVersion < CURRENT_DB_VERSION) {
        print('Forcing database upgrade to version $CURRENT_DB_VERSION');
      } else {
        print('Creating new copy from asset: $_dbName');
      }
      
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from assets
      try {
        String assetDir = _dbName.contains('chs') ? 'chs' : 'cht';
        ByteData data = await rootBundle.load(join('assets', assetDir, _dbName));
        List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

        // Write and flush the bytes written
        await File(path).writeAsBytes(bytes, flush: true);
        
        // Update saved version
        await prefs.setInt(_keyDbVersion, CURRENT_DB_VERSION);
      } catch (e) {
        print('⚠️ [DB] Asset for $_dbName not found. Waiting for download if applicable.');
        // If it's Traditional and we don't have it, we might need to prompt download.
        // For now, let it fail or return dummy if not found to avoid crash during switch.
        throw 'Database file not found: $_dbName';
      }
    } else {
      print('Opening existing database: $_dbName (Version: $savedVersion)');
    }

    return await openDatabase(path, version: 1);
  }
}
