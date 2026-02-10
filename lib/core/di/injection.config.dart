// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../../features/bible_reading/data/datasources/bible_local_datasource.dart'
    as _i757;
import '../../features/bible_reading/data/repositories/bible_repository_impl.dart'
    as _i942;
import '../../features/bible_reading/domain/repositories/bible_repository.dart'
    as _i354;
import '../../features/bible_reading/domain/usecases/get_books.dart' as _i187;
import '../../features/bible_reading/domain/usecases/get_chapter_content.dart'
    as _i710;
import '../../features/bible_reading/presentation/bloc/bible_bloc.dart'
    as _i582;
import '../data/audio_repository.dart' as _i610;
import '../database/database_helper.dart' as _i64;
import '../services/audio_manager.dart' as _i856;
import '../services/audio_player_manager.dart' as _i531;
import '../services/pack_download_service.dart' as _i258;
import '../services/settings_service.dart' as _i114;
import '../services/tts_service.dart' as _i27;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => registerModule.prefs,
      preResolve: true,
    );
    gh.singleton<_i64.DatabaseHelper>(() => _i64.DatabaseHelper());
    gh.lazySingleton<_i610.AudioRepository>(() => _i610.AudioRepository());
    gh.lazySingleton<_i531.AudioPlayerManager>(
        () => _i531.AudioPlayerManager());
    gh.lazySingleton<_i258.PackDownloadService>(
        () => _i258.PackDownloadService());
    gh.lazySingleton<_i27.TtsService>(() => _i27.TtsService());
    gh.lazySingleton<_i856.AudioManager>(
        () => _i856.AudioManager(gh<_i610.AudioRepository>()));
    gh.lazySingleton<_i114.SettingsService>(() => _i114.SettingsService(
          gh<_i460.SharedPreferences>(),
          gh<_i64.DatabaseHelper>(),
        ));
    gh.lazySingleton<_i757.BibleLocalDataSource>(
        () => _i757.BibleLocalDataSourceImpl(gh<_i64.DatabaseHelper>()));
    gh.lazySingleton<_i354.BibleRepository>(
        () => _i942.BibleRepositoryImpl(gh<_i757.BibleLocalDataSource>()));
    gh.lazySingleton<_i187.GetBooksUseCase>(
        () => _i187.GetBooksUseCase(gh<_i354.BibleRepository>()));
    gh.lazySingleton<_i710.GetChapterContentUseCase>(
        () => _i710.GetChapterContentUseCase(gh<_i354.BibleRepository>()));
    gh.factory<_i582.BibleBloc>(() => _i582.BibleBloc(
          gh<_i187.GetBooksUseCase>(),
          gh<_i710.GetChapterContentUseCase>(),
          gh<_i114.SettingsService>(),
        ));
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
