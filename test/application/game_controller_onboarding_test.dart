import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameController onboarding', () {
    test('loads persisted onboarding seen state', () async {
      final _FakeStorage storage = _FakeStorage(onboardingSeen: true);
      final GameController controller = GameController(
        engine: GameEngine(),
        storage: storage,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.onboardingSeen, isTrue);
    });

    test('marks onboarding seen and persists flag', () async {
      final _FakeStorage storage = _FakeStorage(onboardingSeen: false);
      final GameController controller = GameController(
        engine: GameEngine(),
        storage: storage,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      controller.markOnboardingSeen();
      await Future<void>.delayed(Duration.zero);

      expect(controller.onboardingSeen, isTrue);
      expect(storage.savedOnboardingSeen, isTrue);
    });
  });
}

class _FakeStorage implements GameStorage {
  _FakeStorage({required this.onboardingSeen});

  final bool onboardingSeen;
  bool? savedOnboardingSeen;
  GameState? savedGameState;

  @override
  Future<void> clearGameState() async {
    savedGameState = null;
  }

  @override
  Future<GameState?> loadGameState() async {
    return null;
  }

  @override
  Future<bool> loadOnboardingSeen() async {
    return onboardingSeen;
  }

  @override
  Future<void> saveGameState(GameState state) async {
    savedGameState = state;
  }

  @override
  Future<void> saveOnboardingSeen(bool seen) async {
    savedOnboardingSeen = seen;
  }
}
