import 'package:bussruta_app/domain/game_models.dart';

String tr(AppLanguage language, String english, String norwegian) {
  return language == AppLanguage.no ? norwegian : english;
}

String languageName(AppLanguage language) {
  return language == AppLanguage.no ? 'Norsk' : 'English';
}

String phaseLabel(AppLanguage language, GamePhase phase, int warmupRound) {
  switch (phase) {
    case GamePhase.setup:
      return tr(language, 'Setup', 'Oppsett');
    case GamePhase.warmup:
      return tr(language, 'Warmup $warmupRound/4', 'Oppvarming $warmupRound/4');
    case GamePhase.pyramid:
      return tr(language, 'Pyramid', 'Pyramide');
    case GamePhase.tiebreak:
      return tr(language, 'Tie-break', 'Tie-break');
    case GamePhase.bussetup:
      return tr(language, 'Bus Setup', 'Buss-oppsett');
    case GamePhase.bus:
      return tr(language, 'Bus Route', 'Bussrute');
    case GamePhase.finished:
      return tr(language, 'Finished', 'Ferdig');
  }
}

String warmupGuessLabel(AppLanguage language, WarmupGuess guess) {
  switch (guess) {
    case WarmupGuess.black:
      return tr(language, 'Black', 'Svart');
    case WarmupGuess.red:
      return tr(language, 'Red', 'Rodt');
    case WarmupGuess.above:
      return tr(language, 'Higher', 'Over');
    case WarmupGuess.below:
      return tr(language, 'Lower', 'Under');
    case WarmupGuess.between:
      return tr(language, 'Between', 'Mellom');
    case WarmupGuess.outside:
      return tr(language, 'Outside', 'Utenfor');
    case WarmupGuess.same:
      return tr(language, 'Same', 'Samme');
    case WarmupGuess.clubs:
      return tr(language, 'Clubs', 'Klover');
    case WarmupGuess.diamonds:
      return tr(language, 'Diamonds', 'Ruter');
    case WarmupGuess.hearts:
      return tr(language, 'Hearts', 'Hjerter');
    case WarmupGuess.spades:
      return tr(language, 'Spades', 'Spar');
  }
}

String busGuessLabel(AppLanguage language, BusGuess guess) {
  switch (guess) {
    case BusGuess.above:
      return tr(language, 'Above', 'Over');
    case BusGuess.below:
      return tr(language, 'Below', 'Under');
    case BusGuess.same:
      return tr(language, 'Same', 'Samme');
  }
}
