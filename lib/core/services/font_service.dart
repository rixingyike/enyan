import 'dart:io';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FontService {
  final Set<String> _loadedFamilies = {};

  bool isLoaded(String family) => _loadedFamilies.contains(family);

  Future<void> loadFontFromFile(String family, String filePath) async {
    if (_loadedFamilies.contains(family)) return;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print("❌ [FontService] Font file not found: $filePath");
        return;
      }

      final fontData = await file.readAsBytes();
      final fontLoader = FontLoader(family);
      fontLoader.addFont(Future.value(ByteData.sublistView(fontData)));
      
      await fontLoader.load();
      _loadedFamilies.add(family);
      print("✅ [FontService] Successfully loaded font: $family from $filePath");
    } catch (e) {
      print("❌ [FontService] Failed to load font $family: $e");
    }
  }
}
