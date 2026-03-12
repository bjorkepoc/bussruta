import 'package:bussruta_app/domain/game_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class GameStorage {
  Future<GameState?> loadGameState();

  Future<void> saveGameState(GameState state);

  Future<void> clearGameState();
}

class SharedPrefsGameStorage implements GameStorage {
  SharedPrefsGameStorage({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _gameStateKey = 'bussruta.game_state.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    if (_prefs != null) {
      return _prefs!;
    }
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<GameState?> loadGameState() async {
    final SharedPreferences prefs = await _instance();
    final String? payload = prefs.getString(_gameStateKey);
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }
    try {
      return GameState.fromEncodedJson(payload);
    } catch (_) {
      await prefs.remove(_gameStateKey);
      return null;
    }
  }

  @override
  Future<void> saveGameState(GameState state) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_gameStateKey, state.toEncodedJson());
  }

  @override
  Future<void> clearGameState() async {
    final SharedPreferences prefs = await _instance();
    await prefs.remove(_gameStateKey);
  }
}
