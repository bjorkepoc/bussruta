import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/presentation/bussruta_app.dart';
import 'package:bussruta_app/presentation/help_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auto onboarding opens without navigator context errors', (
    WidgetTester tester,
  ) async {
    final GameController controller = GameController(
      engine: GameEngine(),
      storage: _FakeStorage(onboardingSeen: false),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(BussrutaApp(controller: controller));
    await controller.initialize();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingIntroScreen), findsOneWidget);
  });
}

class _FakeStorage implements GameStorage {
  _FakeStorage({required this.onboardingSeen});

  final bool onboardingSeen;

  @override
  Future<void> clearGameState() async {}

  @override
  Future<GameState?> loadGameState() async => null;

  @override
  Future<bool> loadOnboardingSeen() async => onboardingSeen;

  @override
  Future<void> saveGameState(GameState state) async {}

  @override
  Future<void> saveOnboardingSeen(bool seen) async {}
}
