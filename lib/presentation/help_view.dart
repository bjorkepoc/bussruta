import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/presentation/strings.dart';
import 'package:flutter/material.dart';

class RulesHelpScreen extends StatelessWidget {
  const RulesHelpScreen({super.key, required this.language, this.onOpenIntro});

  final AppLanguage language;
  final VoidCallback? onOpenIntro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(language, 'Rules & how to play', 'Regler og hvordan spille'),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF3ECDD), Color(0xFFE7D5C1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _HelpCard(
                title: tr(language, 'Quick start', 'Rask start'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr(
                        language,
                        'Flow: setup -> warmup (4 rounds) -> pyramid -> tie-break (if needed) -> bus route.',
                        'Flyt: oppsett -> oppvarming (4 runder) -> pyramide -> tie-break (ved behov) -> bussrute.',
                      ),
                    ),
                    if (onOpenIntro != null) ...<Widget>[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onOpenIntro,
                        icon: const Icon(Icons.slideshow),
                        label: Text(
                          tr(language, 'Open intro cards', 'Apne intro-kort'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _HelpCard(
                title: tr(language, 'Setup', 'Oppsett'),
                bullets: <String>[
                  tr(
                    language,
                    'Choose 1-9 players and enter names.',
                    'Velg 1-9 spillere og legg inn navn.',
                  ),
                  tr(
                    language,
                    'Reverse pyramid changes drink values (bottom heavy).',
                    'Reversert pyramide endrer drikkeverdier (mer nederst).',
                  ),
                  tr(
                    language,
                    'Start game begins warmup immediately.',
                    'Start spill starter oppvarming med en gang.',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HelpCard(
                title: tr(language, 'Warmup rounds', 'Oppvarmingsrunder'),
                bullets: <String>[
                  tr(
                    language,
                    'Round 1: guess black or red.',
                    'Runde 1: gjett svart eller rod.',
                  ),
                  tr(
                    language,
                    'Round 2: above / below / same compared to first card.',
                    'Runde 2: over / under / samme mot forste kort.',
                  ),
                  tr(
                    language,
                    'Round 3: between / outside / same compared to two cards.',
                    'Runde 3: mellom / utenfor / samme mot to kort.',
                  ),
                  tr(
                    language,
                    'Round 4: guess suit (clubs, diamonds, hearts, spades).',
                    'Runde 4: gjett sort (klov, ruter, hjerter, spar).',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HelpCard(
                title: tr(language, 'Pyramid', 'Pyramide'),
                bullets: <String>[
                  tr(
                    language,
                    'Reveal one card at a time from the deck.',
                    'Avslor ett kort om gangen fra stokken.',
                  ),
                  tr(
                    language,
                    'Players with matching rank can give out drinks.',
                    'Spillere med matchende rang kan dele ut drikker.',
                  ),
                  tr(
                    language,
                    'Drink amount depends on revealed row value.',
                    'Drikkemengde avhenger av raden som blir avslort.',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HelpCard(
                title: tr(language, 'Tie-break', 'Tie-break'),
                bullets: <String>[
                  tr(
                    language,
                    'If multiple players tie on most cards, tie-break starts.',
                    'Hvis flere spillere har flest kort, starter tie-break.',
                  ),
                  tr(
                    language,
                    'Contenders draw facedown, then reveal together.',
                    'Deltakere trekker med baksiden opp, sa avslor sammen.',
                  ),
                  tr(
                    language,
                    'Highest card loses and goes to bus route.',
                    'Hoyeste kort taper og gar til bussruta.',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HelpCard(
                title: tr(language, 'Bus route', 'Bussrute'),
                bullets: <String>[
                  tr(
                    language,
                    'Only the bus loser controls guesses on the active route card.',
                    'Kun busstaper styrer gjetting pa aktivt rutekort.',
                  ),
                  tr(
                    language,
                    'Choose above, below, or same for each step.',
                    'Velg over, under eller samme for hvert steg.',
                  ),
                  tr(
                    language,
                    'Wrong guesses can restart route progress depending on step.',
                    'Feil gjetting kan starte ruten pa nytt avhengig av steg.',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HelpCard(
                title: tr(language, 'Local vs Hosted', 'Lokal vs hostet'),
                bullets: <String>[
                  tr(
                    language,
                    'Local: everyone plays on one device and all hands are visible there.',
                    'Lokal: alle spiller pa en enhet og alle hender vises der.',
                  ),
                  tr(
                    language,
                    'Hosted: one player per phone, each player only sees own hand + public table.',
                    'Hostet: en spiller per mobil, hver spiller ser kun egen hand + offentlig bord.',
                  ),
                  tr(
                    language,
                    'Hosted host has extra tools (auto play, game log) but is still a normal player.',
                    'I hostet har verten ekstra verktoy (autospill, spilllogg) men spiller fortsatt normalt.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingIntroScreen extends StatefulWidget {
  const OnboardingIntroScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  State<OnboardingIntroScreen> createState() => _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends State<OnboardingIntroScreen> {
  late final PageController _controller = PageController();
  int _page = 0;

  List<_IntroSlide> _slides(AppLanguage lang) {
    return <_IntroSlide>[
      _IntroSlide(
        icon: Icons.table_restaurant,
        title: tr(lang, 'Local or Hosted', 'Lokal eller hostet'),
        body: tr(
          lang,
          'Pick Local for one-device play, or Hosted for one player per phone over LAN.',
          'Velg Lokal for en-enhets spill, eller Hostet for en spiller per mobil over LAN.',
        ),
      ),
      _IntroSlide(
        icon: Icons.style,
        title: tr(lang, 'Core flow', 'Kjerneflyt'),
        body: tr(
          lang,
          'Play 4 warmup rounds, then pyramid. If needed, tie-break decides who takes bus route.',
          'Spill 4 oppvarmingsrunder, sa pyramide. Ved behov avgjor tie-break hvem som tar bussruta.',
        ),
      ),
      _IntroSlide(
        icon: Icons.hub,
        title: tr(lang, 'Hosted basics', 'Hostet grunnlag'),
        body: tr(
          lang,
          'In Hosted mode, private hands stay private. The host can still play while using host tools.',
          'I hostet modus holdes private hender private. Verten kan fortsatt spille mens vertsverktoy brukes.',
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = widget.language;
    final List<_IntroSlide> slides = _slides(lang);
    final bool last = _page == slides.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(lang, 'Quick intro', 'Rask intro')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr(lang, 'Skip', 'Hopp over')),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF4ECE1), Color(0xFFEAD9C8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (int value) {
                    setState(() {
                      _page = value;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _IntroSlide slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFFF9F0E2),
                              Color(0xFFF2E0CA),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: const Color(0x44A56D45)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 16,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFE2C3A1),
                                child: Icon(
                                  slide.icon,
                                  size: 30,
                                  color: const Color(0xFF603B26),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                slide.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slide.body,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(slides.length, (int index) {
                    final bool active = index == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF8B4D2C)
                            : const Color(0x55A26B47),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (!last) {
                        await _controller.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        );
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pop(true);
                    },
                    icon: Icon(last ? Icons.check : Icons.arrow_forward),
                    label: Text(
                      last
                          ? tr(lang, 'Got it', 'Skjonner')
                          : tr(lang, 'Next', 'Neste'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.title,
    this.child,
    this.bullets = const <String>[],
  });

  final String title;
  final Widget? child;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8EEDD),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (child != null) ...<Widget>[const SizedBox(height: 8), child!],
            for (final String bullet in bullets) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(bullet)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroSlide {
  const _IntroSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
