import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/presentation/bussruta_app.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final GameController controller = GameController(
    engine: GameEngine(),
    storage: SharedPrefsGameStorage(),
  );
  await controller.initialize();

  runApp(BussrutaApp(controller: controller));
}
