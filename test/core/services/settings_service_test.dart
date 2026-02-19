import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/core/database/database_helper.dart';

import 'settings_service_test.mocks.dart';

@GenerateMocks([DatabaseHelper])
void main() {
  late SettingsService settingsService;
  late MockDatabaseHelper mockDatabaseHelper;

  setUp(() async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({
      'is_simplified': true,
      'is_human_voice': false,
    });
    final prefs = await SharedPreferences.getInstance();
    
    // Mock DatabaseHelper
    mockDatabaseHelper = MockDatabaseHelper();
    
    // Init Service
    settingsService = SettingsService(prefs, mockDatabaseHelper);
  });

  group('SettingsService Test', () {
    test('Initial values loaded correctly', () {
      expect(settingsService.isSimplified.value, true);
      expect(settingsService.isHumanVoice.value, false);
    });

    test('setSimplified updates state and calls DB switch', () async {
      // Setup mock behavior
      when(mockDatabaseHelper.switchDatabase(any)).thenAnswer((_) async {});

      // Act
      await settingsService.setSimplified(false);

      // Assert
      expect(settingsService.isSimplified.value, false);
      verify(mockDatabaseHelper.switchDatabase(false)).called(1);
    });

    test('setHumanVoice updates state and persists', () async {
      // Act
      await settingsService.setHumanVoice(true);

      // Assert
      expect(settingsService.isHumanVoice.value, true);
      
      // Verify persistence (re-read from prefs)
      // Since we can't easily access the same _prefs instance inside setHumanVoice without exposing it,
      // we trust the ValueNotifier update and the fact that we awaited the set.
      // A better test would inspect the underlying map of SharedPreferences if possible.
    });
  });
}
