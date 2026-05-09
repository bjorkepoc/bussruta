import 'package:bussruta_app/domain/game_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class GameStorage {
  Future<GameState?> loadGameState();

  Future<void> saveGameState(GameState state);

  Future<void> clearGameState();

  Future<bool> loadOnboardingSeen();

  Future<void> saveOnboardingSeen(bool seen);
}

class SharedPrefsGameStorage implements GameStorage {
  SharedPrefsGameStorage({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _gameStateKey = 'bussruta.game_state.v1';
  static const String _onboardingSeenKey = 'bussruta.onboarding_seen.v1';

  SharedPreferences? _prefs;
  String? _lastSavedGameStatePayload;

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
      final GameState state = GameState.fromEncodedJson(payload);
      _lastSavedGameStatePayload = payload;
      return state;
    } catch (_) {
      await prefs.remove(_gameStateKey);
      _lastSavedGameStatePayload = null;
      return null;
    }
  }

  @override
  Future<void> saveGameState(GameState state) async {
    final String payload = state.toEncodedJson();
    if (payload == _lastSavedGameStatePayload) {
      return;
    }
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_gameStateKey, payload);
    _lastSavedGameStatePayload = payload;
  }

  @override
  Future<void> clearGameState() async {
    final SharedPreferences prefs = await _instance();
    await prefs.remove(_gameStateKey);
    _lastSavedGameStatePayload = null;
  }

  @override
  Future<bool> loadOnboardingSeen() async {
    final SharedPreferences prefs = await _instance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  @override
  Future<void> saveOnboardingSeen(bool seen) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setBool(_onboardingSeenKey, seen);
  }
}
