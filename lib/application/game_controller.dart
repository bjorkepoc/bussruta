import 'dart:async';

import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:flutter/widgets.dart';

class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController({required GameEngine engine, required GameStorage storage})
    : _engine = engine,
      _storage = storage {
    WidgetsBinding.instance.addObserver(this);
  }

  final GameEngine _engine;
  final GameStorage _storage;

  GameState _state = GameState.initial();
  bool _initialized = false;
  bool _autoPlayRunning = false;
  Timer? _autoPlayTimer;
  String? _errorMessage;

  GameState get state => _state;

  bool get initialized => _initialized;

  String? consumeErrorMessage() {
    final String? value = _errorMessage;
    _errorMessage = null;
    return value;
  }

  Future<void> initialize() async {
    final GameState? restored = await _storage.loadGameState();
    if (restored != null) {
      _state = restored;
    } else {
      _state = GameState.initial();
    }
    _initialized = true;
    notifyListeners();
    _syncAutoPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_persistState());
    }
  }

  void setLanguage(AppLanguage language) {
    _emit(_state.copyWith(language: language));
  }

  void setPlayerCount(int count) {
    final SetupDraft resized = _engine.resizeSetupDraft(
      _state.setupDraft,
      count,
    );
    _emit(_state.copyWith(setupDraft: resized));
  }

  void addPlayer() {
    setPlayerCount(_state.setupDraft.playerCount + 1);
  }

  void removePlayer() {
    setPlayerCount(_state.setupDraft.playerCount - 1);
  }

  void removePlayerAt(int index) {
    if (_state.setupDraft.playerCount <= GameEngine.minPlayers) {
      return;
    }
    final List<String> names = List<String>.from(_state.setupDraft.names);
    if (index < 0 || index >= names.length) {
      return;
    }
    names.removeAt(index);
    final SetupDraft resized = _engine.resizeSetupDraft(
      _state.setupDraft.copyWith(names: names),
      _state.setupDraft.playerCount - 1,
    );
    _emit(_state.copyWith(setupDraft: resized));
  }

  void setPlayerName(int index, String value) {
    final List<String> names = List<String>.from(_state.setupDraft.names);
    if (index < 0 || index >= names.length) {
      return;
    }
    names[index] = value;
    _emit(
      _state.copyWith(setupDraft: _state.setupDraft.copyWith(names: names)),
    );
  }

  void randomizeSetupNames() {
    final List<String> names = _engine.randomSetupNames(
      count: _state.setupDraft.playerCount,
      language: _state.language,
    );
    _emit(
      _state.copyWith(setupDraft: _state.setupDraft.copyWith(names: names)),
    );
  }

  void setReversePyramid(bool value) {
    _emit(
      _state.copyWith(
        setupDraft: _state.setupDraft.copyWith(reversePyramid: value),
      ),
    );
  }

  void hardResetSetup() {
    _emit(_engine.resetToSetup(_state, hardReset: true));
  }

  void resetToSetup() {
    _emit(_engine.resetToSetup(_state, hardReset: false));
  }

  void startGameFromSetup() {
    try {
      final List<String> names = List<String>.from(_state.setupDraft.names);
      final GameState started = _engine.startGame(
        state: _state,
        rawNames: names,
        reversePyramid: _state.setupDraft.reversePyramid,
        language: _state.language,
      );
      _emit(started);
    } catch (_) {
      _errorMessage = _state.language == AppLanguage.no
          ? 'Legg inn 1-9 spillernavn.'
          : 'Please add 1-9 player names.';
      notifyListeners();
    }
  }

  void playWarmupGuess(WarmupGuess guess) {
    _emit(_engine.playWarmupGuess(_state, guess));
  }

  void revealPyramidNext() {
    _emit(_engine.revealNextPyramidSlot(_state));
  }

  void runTieBreakRound() {
    _emit(_engine.runTieBreakRound(_state));
  }

  void beginBusRoute(BusStartSide side) {
    _emit(_engine.beginBusRoute(_state, side));
  }

  void playBusGuess(BusGuess guess) {
    _emit(_engine.playBusGuess(_state, guess));
  }

  void setAutoPlayDelayMs(int delayMs) {
    final int normalized = delayMs.clamp(350, 60000);
    _emit(
      _state.copyWith(autoPlay: _state.autoPlay.copyWith(delayMs: normalized)),
    );
  }

  void toggleAutoPlay([bool? forceValue]) {
    final bool nextValue = forceValue ?? !_state.autoPlay.enabled;
    final List<String> logs = List<String>.from(_state.log);
    logs.insert(
      0,
      _state.language == AppLanguage.no
          ? (nextValue ? 'Autospill aktivert.' : 'Autospill pause.')
          : (nextValue ? 'Auto play enabled.' : 'Auto play paused.'),
    );
    _emit(
      _state.copyWith(
        autoPlay: _state.autoPlay.copyWith(enabled: nextValue),
        log: logs,
      ),
    );
  }

  Future<void> _persistState() async {
    await _storage.saveGameState(_state);
  }

  void _emit(GameState nextState) {
    _state = nextState;
    notifyListeners();
    unawaited(_persistState());
    _syncAutoPlay();
  }

  void _syncAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;

    if (!_state.autoPlay.enabled ||
        _state.phase == GamePhase.setup ||
        _state.phase == GamePhase.finished ||
        _autoPlayRunning) {
      return;
    }

    _autoPlayTimer = Timer(
      Duration(milliseconds: _state.autoPlay.delayMs),
      () => _runAutoPlayStep(),
    );
  }

  Future<void> _runAutoPlayStep() async {
    if (!_state.autoPlay.enabled ||
        _state.phase == GamePhase.setup ||
        _state.phase == GamePhase.finished) {
      return;
    }
    if (_autoPlayRunning) {
      return;
    }
    _autoPlayRunning = true;
    try {
      if (_state.phase == GamePhase.warmup) {
        playWarmupGuess(_engine.chooseWarmupGuessByStats(_state));
      } else if (_state.phase == GamePhase.pyramid) {
        revealPyramidNext();
      } else if (_state.phase == GamePhase.tiebreak) {
        runTieBreakRound();
      } else if (_state.phase == GamePhase.bussetup) {
        beginBusRoute(_state.busStartSide);
      } else if (_state.phase == GamePhase.bus) {
        playBusGuess(_engine.chooseBusGuessByStats(_state));
      }
    } finally {
      _autoPlayRunning = false;
      _syncAutoPlay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoPlayTimer?.cancel();
    unawaited(_persistState());
    super.dispose();
  }
}
