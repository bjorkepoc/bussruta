import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsGameStorage', () {
    tearDown(SharedPreferences.resetStatic);

    test('skips writing identical encoded game state payloads', () async {
      final _CountingPreferencesStore store = _CountingPreferencesStore();
      SharedPreferencesStorePlatform.instance = store;
      SharedPreferences.resetStatic();
      final SharedPrefsGameStorage storage = SharedPrefsGameStorage();
      final GameState state = GameState.initial();

      await storage.saveGameState(state);
      await storage.saveGameState(state);

      expect(store.setStringCalls, 1);
    });
  });
}

class _CountingPreferencesStore extends SharedPreferencesStorePlatform {
  _CountingPreferencesStore()
    : _backend = InMemorySharedPreferencesStore.empty();

  final InMemorySharedPreferencesStore _backend;
  int setStringCalls = 0;

  @override
  Future<bool> clear() {
    return _backend.clear();
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) {
    return _backend.clearWithParameters(parameters);
  }

  @override
  Future<Map<String, Object>> getAll() {
    return _backend.getAll();
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) {
    return _backend.getAllWithParameters(parameters);
  }

  @override
  Future<bool> remove(String key) {
    return _backend.remove(key);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (valueType == 'String' && key == 'flutter.bussruta.game_state.v1') {
      setStringCalls += 1;
    }
    return _backend.setValue(valueType, key, value);
  }
}
