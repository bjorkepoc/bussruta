import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameController setup persistence', () {
    testWidgets('setPlayerName updates state without notifying immediately', (
      WidgetTester tester,
    ) async {
      final _RecordingStorage storage = _RecordingStorage();
      final GameController controller = GameController(
        engine: GameEngine(),
        storage: storage,
      );
      await controller.initialize();

      int notifications = 0;
      controller.addListener(() {
        notifications += 1;
      });

      controller.setPlayerName(0, 'Ada');

      expect(controller.state.setupDraft.names.first, 'Ada');
      expect(notifications, 0);
      expect(storage.savedGameStates, isEmpty);

      controller.dispose();
      await tester.pump();
    });

    testWidgets('rapid name edits persist once after debounce', (
      WidgetTester tester,
    ) async {
      final _RecordingStorage storage = _RecordingStorage();
      final GameController controller = GameController(
        engine: GameEngine(),
        storage: storage,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      controller
        ..setPlayerName(0, 'A')
        ..setPlayerName(0, 'Ad')
        ..setPlayerName(0, 'Ada');

      await tester.pump(const Duration(milliseconds: 599));
      expect(storage.savedGameStates, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(storage.savedGameStates, hasLength(1));
      expect(storage.savedGameStates.single.setupDraft.names.first, 'Ada');
    });

    testWidgets('lifecycle pause flushes a pending name edit', (
      WidgetTester tester,
    ) async {
      final _RecordingStorage storage = _RecordingStorage();
      final GameController controller = GameController(
        engine: GameEngine(),
        storage: storage,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      controller.setPlayerName(0, 'Linus');
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();

      expect(storage.savedGameStates, hasLength(1));
      expect(storage.savedGameStates.single.setupDraft.names.first, 'Linus');
    });

    testWidgets('dispose flushes a pending name edit', (
      WidgetTester tester,
    ) async {
      final _RecordingStorage storage = _RecordingStorage();
      final GameController controller = GameController(
        engine: GameEngine(),
        storage: storage,
      );
      await controller.initialize();

      controller.setPlayerName(0, 'Grace');
      controller.dispose();
      await tester.pump();

      expect(storage.savedGameStates, hasLength(1));
      expect(storage.savedGameStates.single.setupDraft.names.first, 'Grace');
    });

    testWidgets('startGameFromSetup uses pending name edits immediately', (
      WidgetTester tester,
    ) async {
      final _RecordingStorage storage = _RecordingStorage();
      final GameController controller = GameController(
        engine: GameEngine(),
        storage: storage,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      controller
        ..setPlayerCount(1)
        ..setPlayerName(0, 'Immediate')
        ..startGameFromSetup();

      expect(controller.state.players.single.name, 'Immediate');
      expect(controller.state.phase, GamePhase.warmup);
    });
  });
}

class _RecordingStorage implements GameStorage {
  final List<GameState> savedGameStates = <GameState>[];

  @override
  Future<void> clearGameState() async {
    savedGameStates.clear();
  }

  @override
  Future<GameState?> loadGameState() async => null;

  @override
  Future<bool> loadOnboardingSeen() async => true;

  @override
  Future<void> saveGameState(GameState state) async {
    savedGameStates.add(state);
  }

  @override
  Future<void> saveOnboardingSeen(bool seen) async {}
}
