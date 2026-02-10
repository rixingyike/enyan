import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

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
  // IP will need to be configured or discovered
  // For simulator: 127.0.0.1 or 10.0.2.2 usually works but for
  // real device we need the actual IP of the computer running python server.
  // We can hardcode for now or make it configurable.
  // Let's assume localhost for macOS desktop app use case which is current focus.
  static const String _baseUrl = "http://127.0.0.1:8080/api";

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
      final response = await _client.get(Uri.parse('$_baseUrl/packs'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['packs']);
      }
    } catch (e) {
      debugPrint("Error fetching packs: $e");
    }
    return [];
  }

  Future<void> downloadPack(String packId) async {
    // 1. Get info
    final packs = await fetchPacks();
    final pack = packs.firstWhere((p) => p['id'] == packId, orElse: () => {});

    if (pack.isEmpty) {
      _updateStatus(packId, PackStatus.error);
      return;
    }

    final url = pack['url'] as String;

    try {
      _updateStatus(packId, PackStatus.downloading);

      // 2. Download
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception("Download failed: ${response.statusCode}");
      }

      final dir = await getApplicationDocumentsDirectory();
      final zipFile = File('${dir.path}/temp_$packId.zip');

      // Stream download
      final IOSink sink = zipFile.openWrite();
      await response.stream.pipe(sink);
      await sink.close();

      // 3. Unzip
      debugPrint("Unzipping $packId...");
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Create target dir
      final targetDir = Directory('${dir.path}/packs/$packId');
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

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

      // 4. Mark completed (create a marker file)
      File('${targetDir.path}/completed').createSync();

      // 5. Cleanup
      if (zipFile.existsSync()) zipFile.deleteSync();

      _updateStatus(packId, PackStatus.downloaded);
      debugPrint("Download & Unzip complete: $packId");
    } catch (e) {
      debugPrint("Download error: $e");
      _updateStatus(packId, PackStatus.error);
    }
  }

  void _updateStatus(String packId, PackStatus status) {
    final current = Map<String, PackStatus>.from(statusNotifier.value);
    current[packId] = status;
    statusNotifier.value = current;
  }
}
