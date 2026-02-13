import 'package:flutter/material.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/pack_download_service.dart';
import 'package:gracewords/core/services/weight_service.dart';
import 'package:gracewords/features/bible_reading/presentation/pages/home_page.dart';
import 'package:gracewords/src/rust/frb_generated.dart'; // Rust Bridge
import 'package:media_kit/media_kit.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    
    // Initialize Rust Library
    await RustLib.init();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    await configureDependencies();

    // Services Init
    final appDocDir = await getApplicationDocumentsDirectory();
    print('📂 [AppPath] Documents: ${appDocDir.path}');
    
    await getIt<PackDownloadService>().init();
    await getIt<WeightService>().init();

    runApp(const GraceWordsApp());
  } catch (e, stack) {
    print('Initialization Error: $e');
    print(stack);
    // Optional: Run a simple error app
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text('Error: $e')))));
  }
}

class GraceWordsApp extends StatelessWidget {
  const GraceWordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GraceWords',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF8E1),
          elevation: 0,
          titleTextStyle: TextStyle(color: Color(0xFF212121), fontSize: 22, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Color(0xFF212121)),
        ),
      ),
      home: const HomePage(),
    );
  }
}
