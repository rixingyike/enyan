import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/font_service.dart';
import 'package:gracewords/core/config/app_config.dart';

enum PackStatus {
  notDownloaded,
  downloading,
  downloaded,
  error,
}

@lazySingleton
class PackDownloadService {
  final ValueNotifier<Map<String, PackStatus>> statusNotifier =
      ValueNotifier({});

  final _client = http.Client();
  // Configured in AppConfig
  static const String _baseUrl = AppConfig.packDownloadBaseUrl;

  Future<void> init() async {
    // Check local files to update initial status
    // TODO: persist status or check file existence
    // For now, reset to notDownloaded unless we verify file existence
    final dir = await getApplicationDocumentsDirectory();
    final packsDir = Directory('${dir.path}/packs');

    final status = <String, PackStatus>{};
    if (packsDir.existsSync()) {
      if (File('${packsDir.path}/lang_cht/completed').existsSync()) {
        status['lang_cht'] = PackStatus.downloaded;
        await _checkAndLoadFonts('lang_cht', Directory('${packsDir.path}/lang_cht'));
      }
      if (File('${packsDir.path}/voice_6k/completed').existsSync()) {
        status['voice_6k'] = PackStatus.downloaded;
      }
      if (File('${packsDir.path}/voice_8k/completed').existsSync()) {
        status['voice_8k'] = PackStatus.downloaded;
      }
    }
    statusNotifier.value = status;
  }

  Future<List<Map<String, dynamic>>> fetchPacks() async {
    try {
      // If config URL ends with .json, use it directly; otherwise append /packs.json
      final url = _baseUrl.endsWith('.json') ? _baseUrl : '$_baseUrl/packs.json';
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['packs']);
      }
    } catch (e) {
      debugPrint("Error fetching packs: $e");
    }
    return [];
  }

  // ... (downloadPack remains largely the same, passing partUrls if available)
  
  // Update downloadPack to pass explicit part_urls
  Future<void> downloadPack(String packId) async {
    // 1. Get info
    final packs = await fetchPacks();
    final pack = packs.firstWhere((p) => p['id'] == packId, orElse: () => {});

    if (pack.isEmpty) {
      _updateStatus(packId, PackStatus.error);
      return;
    }

    final url = pack['url'] as String;
    final int parts = pack['parts'] ?? 1;
    final List<String>? explicitPartUrls = pack['part_urls'] != null 
        ? List<String>.from(pack['part_urls']) 
        : null;

    try {
      _updateStatus(packId, PackStatus.downloading);

      final dir = await getApplicationDocumentsDirectory();
      
      // Determine file processing based on extension
      final isGzip = url.endsWith('.gz');
      final isZip = url.contains('.zip'); // .zip or .zip.gz
      
      final tempFile = File('${dir.path}/temp_$packId${isGzip ? '.gz' : '.zip'}');

      // 2. Download (Single or Multipart)
      if (parts > 1) {
        debugPrint("📦 Downloading $parts parts for $packId...");
        await _downloadPartsAndMerge(url, parts, tempFile, explicitPartUrls: explicitPartUrls);
      } else {
        await _downloadSingleFile(url, tempFile);
      }

      List<int> bytes = await tempFile.readAsBytes();

      // 3. Decompress Gzip if needed
      if (isGzip) {
        debugPrint("📦 Decompressing Gzip: $packId...");
        try {
          bytes = GZipDecoder().decodeBytes(bytes);
        } catch (e) {
             debugPrint("❌ Gzip Error: $e");
             throw e;
        }
      }

      // Create target dir
      final targetDir = Directory('${dir.path}/packs/$packId');
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      if (isZip) {
        // 4. Unzip
        debugPrint("🤐 Unzipping: $packId...");
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            File('${targetDir.path}/$filename')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else {
            Directory('${targetDir.path}/$filename').create(recursive: true);
          }
        }
      } else {
        // Single file (e.g. bible_cht.db.br -> bible_cht.db)
        String targetFilename;
        if (packId == 'lang_cht') {
          targetFilename = 'bible_cht.db';
        } else {
          // Default: remove .gz from url basename
          targetFilename = url.split('/').last.replaceAll('.gz', '');
        }

        final targetFile = File('${targetDir.path}/$targetFilename');
        debugPrint("📦 Saving single file to: ${targetFile.path}");
        targetFile.writeAsBytesSync(bytes);
      }

      // 5. Mark completed
      File('${targetDir.path}/completed').createSync();

      // Check for font files to load
      await _checkAndLoadFonts(packId, targetDir);

      // Cleanup
      if (tempFile.existsSync()) tempFile.deleteSync();

      _updateStatus(packId, PackStatus.downloaded);
      debugPrint("✅ Download & Process complete: $packId");
    } catch (e) {
      debugPrint("❌ Download error: $e");
      _updateStatus(packId, PackStatus.error);
    }
  }

  Future<void> _downloadSingleFile(String url, File targetFile) async {
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception("Download failed: ${response.statusCode}");
      }
      
      final sink = targetFile.openWrite();
      await response.stream.pipe(sink);
      await sink.close();
  }

  Future<void> _downloadPartsAndMerge(String baseUrl, int parts, File targetFile, {List<String>? explicitPartUrls}) async {
      final sink = targetFile.openWrite();
      
      try {
        for (int i = 1; i <= parts; i++) {
            // Construct part URL: explicit or url.part1, url.part2 ...
            String partUrl;
            if (explicitPartUrls != null && i <= explicitPartUrls.length) {
                partUrl = explicitPartUrls[i-1];
            } else {
                partUrl = "$baseUrl.part$i";
            }

            debugPrint("⬇️ Downloading part $i/$parts: $partUrl");
            
            final request = http.Request('GET', Uri.parse(partUrl));
            final response = await _client.send(request);
            
            if (response.statusCode != 200) {
              throw Exception("Part $i download failed: ${response.statusCode}");
            }

            // Append to sink
            await sink.addStream(response.stream);
        }
      } finally {
        await sink.close();
      }
  }

  Future<void> _checkAndLoadFonts(String packId, Directory targetDir) async {
    try {
      final entities = await targetDir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.ttf')) {
          String family = '';
          if (packId == 'lang_cht' || entity.path.contains('_cht.ttf')) family = 'LxgwWenkaiTC';
          // Supports identifying by filename suffix
          if (entity.path.contains('_chs.ttf')) family = 'LxgwWenKai';
          
          if (family.isNotEmpty) {
            await getIt<FontService>().loadFontFromFile(family, entity.path);
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking fonts in $packId: $e");
    }
  }

  void _updateStatus(String packId, PackStatus status) {
    var current = Map<String, PackStatus>.from(statusNotifier.value);
    current[packId] = status;
    statusNotifier.value = current;
  }
}
