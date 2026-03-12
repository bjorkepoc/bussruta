const SUITS = [
  { key: "clubs", symbol: "\u2663", color: "black", warmupLabel: "klover", displayName: "Kl\u00f8ver" },
  { key: "diamonds", symbol: "\u2666", color: "red", warmupLabel: "ruter", displayName: "Ruter" },
  { key: "hearts", symbol: "\u2665", color: "red", warmupLabel: "hjerter", displayName: "Hjerter" },
  { key: "spades", symbol: "\u2660", color: "black", warmupLabel: "spar", displayName: "Spar" }
];

const RANK_LABELS = {
  1: "A",
  11: "J",
  12: "Q",
  13: "K"
};

const PYRAMID_ROWS = [
  [14],
  [12, 13],
  [9, 10, 11],
  [5, 6, 7, 8],
  [0, 1, 2, 3, 4]
];

const state = {
  phase: "setup",
  lang: "en",
  setupDraft: {
    playerCount: 4,
    names: ["", "", "", ""],
    reversePyramid: false
  },
  preferences: {
    motionMode: "cinematic",
    effectsLevel: "normal"
  },
  players: [],
  deck: [],
  reversePyramid: false,
  busStartSide: "left",
  warmupRound: 1,
  currentPlayerIndex: 0,
  pyramidCards: Array(15).fill(null),
  pyramidRevealIndex: 0,
  busRunnerIndex: null,
  tieBreak: null,
  busRoute: null,
  pendingWarmupGuess: null,
  animating: false,
  bannerTone: "info",
  pyramidHighlightPlayers: [],
  autoPlay: {
    enabled: false,
    delayMs: 1500,
    timerId: null,
    running: false
  },
  autoPlayMenuOpen: false,
  banner: "",
  log: []
};

const GUESS_LABELS = {
  en: {
    svart: "Black",
    rodt: "Red",
    over: "Higher",
    under: "Lower",
    mellom: "Between",
    utenfor: "Outside",
    samme: "Same",
    klover: "Clubs",
    ruter: "Diamonds",
    hjerter: "Hearts",
    spar: "Spades"
  },
  no: {
    svart: "Svart",
    rodt: "Rødt",
    over: "Over",
    under: "Under",
    mellom: "Mellom",
    utenfor: "Utenfor",
    samme: "Samme",
    klover: "Kløver",
    ruter: "Ruter",
    hjerter: "Hjerter",
    spar: "Spar"
  }
};

const AUTO_PLAY_PRESETS = [
  { key: "blitz", en: "Blitz (0.45s)", no: "Blitz (0.45s)", delayMs: 450, motionMode: "turbo", effectsLevel: "subtle" },
  { key: "quick", en: "Quick (0.8s)", no: "Rask (0.8s)", delayMs: 800, motionMode: "fast", effectsLevel: "subtle" },
  { key: "normal", en: "Normal (1.5s)", no: "Normal (1.5s)", delayMs: 1500, motionMode: "cinematic", effectsLevel: "normal" },
  { key: "slow5", en: "Slow (5s)", no: "Sakte (5s)", delayMs: 5000, motionMode: "cinematic", effectsLevel: "normal" },
  { key: "slow10", en: "Slow (10s)", no: "Sakte (10s)", delayMs: 10000, motionMode: "cinematic", effectsLevel: "normal" },
  { key: "slow30", en: "Very Slow (30s)", no: "Veldig sakte (30s)", delayMs: 30000, motionMode: "cinematic", effectsLevel: "normal" },
  { key: "slow60", en: "Ultra Slow (60s)", no: "Ultrasakte (60s)", delayMs: 60000, motionMode: "cinematic", effectsLevel: "subtle" }
];

const RANDOM_NAME_PARTS = {
  start: ["River", "Echo", "Nova", "Mango", "Polar", "Velvet", "Sunny", "Pixel", "Frost", "Clover", "Lemon", "Rogue"],
  end: ["Fox", "Raven", "Tiger", "Otter", "Falcon", "Comet", "Wolf", "Panda", "Hawk", "Lynx", "Moose", "Shark"]
};

const AUTO_PLAY_DELAY_MIN = 350;
const AUTO_PLAY_DELAY_MAX = 60000;

function tr(enText, noText) {
  return state.lang === "no" ? noText : enText;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function pickRandom(items) {
  if (!Array.isArray(items) || items.length === 0) return "";
  return items[Math.floor(Math.random() * items.length)];
}

function randomSetupNames(count, lang) {
  const total = clamp(Number(count) || 0, 1, 9);
  const fallbackPrefix = lang === "no" ? "Spiller" : "Player";
  const used = new Set();
  const generated = [];

  for (let i = 0; i < total; i += 1) {
    let tries = 0;
    let candidate = "";

    while (tries < 40) {
      candidate = `${pickRandom(RANDOM_NAME_PARTS.start)} ${pickRandom(RANDOM_NAME_PARTS.end)}`.trim();
      if (candidate && !used.has(candidate.toLowerCase())) {
        break;
      }
      tries += 1;
    }

    if (!candidate || used.has(candidate.toLowerCase())) {
      candidate = `${fallbackPrefix} ${i + 1}`;
    }

    used.add(candidate.toLowerCase());
    generated.push(candidate);
  }

  return generated;
}

function formatDelayLabel(delayMs) {
  const seconds = delayMs / 1000;
  if (seconds >= 10) {
    return `${Math.round(seconds)}s`;
  }
  return `${Math.round(seconds * 10) / 10}s`;
}

function nearestAutoPlayPresetKey() {
  if (!AUTO_PLAY_PRESETS.length) return "";
  let best = AUTO_PLAY_PRESETS[0];
  let diff = Math.abs(state.autoPlay.delayMs - best.delayMs);

  for (const preset of AUTO_PLAY_PRESETS) {
    const nextDiff = Math.abs(state.autoPlay.delayMs - preset.delayMs);
    if (nextDiff < diff) {
      best = preset;
      diff = nextDiff;
    }
  }

  return best.key;
}

function guessLabel(key) {
  return GUESS_LABELS[state.lang][key] || key;
}

const phaseLabel = document.getElementById("phaseLabel");
const deckLabel = document.getElementById("deckLabel");
const playerBoard = document.getElementById("playerBoard");
const controls = document.getElementById("controls");
const board = document.getElementById("board");
const logEl = document.getElementById("log");
const setupTemplate = document.getElementById("setupTemplate");
const pageHeaderTitle = document.querySelector(".page-header h1");
const pageHeaderSubtitle = document.querySelector(".page-header p");
const statusHeading = document.getElementById("statusHeading");
const logHeading = document.getElementById("logHeading");

boot();

function boot() {
  state.phase = "setup";
  applyVisualPreferences();
  renderAll();
}

function createDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (let rank = 1; rank <= 13; rank += 1) {
      deck.push({ suit, rank });
    }
  }
  shuffle(deck);
  return deck;
}

function shuffle(items) {
  for (let i = items.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [items[i], items[j]] = [items[j], items[i]];
  }
}

function drawCardFromDeck(deckKey = "deck") {
  if (!Array.isArray(state[deckKey])) {
    throw new Error(`Deck '${deckKey}' is not available.`);
  }
  if (state[deckKey].length === 0) {
    state[deckKey] = createDeck();
    addLog(tr("Deck was empty and has been reshuffled.", "Stokken var tom og ble stokket på nytt."));
  }
  return state[deckKey].pop();
}

function drawCardFromBusDeck() {
  const bus = state.busRoute;
  if (!bus) {
    throw new Error("Bus route is not initialized.");
  }
  if (bus.deck.length === 0) {
    bus.deck = createDeck();
    addLog(tr("Bus route deck was empty and has been reshuffled.", "Bussruta-stokken var tom og ble stokket på nytt."));
  }
  return bus.deck.pop();
}

function rankLabel(rank) {
  return RANK_LABELS[rank] || String(rank);
}

function cardLabel(card) {
  return `${rankLabel(card.rank)}${card.suit.symbol}`;
}

function cardHtml(card, options = {}) {
  const size = options.size || "sm";
  const extraClass = options.extraClass ? ` ${options.extraClass}` : "";

  if (options.back || !card) {
    return `<div class="playing-card ${size} back${extraClass}"></div>`;
  }

  const rank = rankLabel(card.rank);
  const tone = card.suit.color;
  const suit = card.suit.symbol;
  return `
    <div class="playing-card ${size} ${tone}${extraClass}">
      <span class="pc-corner pc-top">${rank}<small>${suit}</small></span>
      <span class="pc-center">${suit}</span>
      <span class="pc-corner pc-bottom">${rank}<small>${suit}</small></span>
    </div>
  `;
}

function buildCardNode(card, options = {}) {
  const wrapper = document.createElement("div");
  wrapper.className = `playing-card ${options.size || "md"} ${options.back ? "back" : card.suit.color}`;

  if (!options.back) {
    const rank = rankLabel(card.rank);
    const suit = card.suit.symbol;
    wrapper.innerHTML = `
      <span class="pc-corner pc-top">${rank}<small>${suit}</small></span>
      <span class="pc-center">${suit}</span>
      <span class="pc-corner pc-bottom">${rank}<small>${suit}</small></span>
    `;
  }

  return wrapper;
}

function normalizePlayerNames(rawNames) {
  if (Array.isArray(rawNames)) {
    return rawNames.map((name) => String(name || "").trim());
  }
  return String(rawNames || "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function dedupePlayerNames(names, lang) {
  const prefix = lang === "no" ? "Spiller" : "Player";
  const used = new Set();
  const countByBase = new Map();
  const normalized = [];

  names.forEach((name, idx) => {
    const baseRaw = name && name.trim() ? name.trim() : `${prefix} ${idx + 1}`;
    const baseKey = baseRaw.toLowerCase();
    let baseCount = (countByBase.get(baseKey) || 0) + 1;
    countByBase.set(baseKey, baseCount);

    let candidate = baseCount === 1 ? baseRaw : `${baseRaw} ${baseCount}`;
    while (used.has(candidate.toLowerCase())) {
      baseCount += 1;
      countByBase.set(baseKey, baseCount);
      candidate = `${baseRaw} ${baseCount}`;
    }

    used.add(candidate.toLowerCase());
    normalized.push(candidate);
  });

  return normalized;
}

function startGame(rawNames, reversePyramid, lang = "en") {
  const names = normalizePlayerNames(rawNames);

  if (names.length < 1 || names.length > 9) {
    window.alert(tr("Please add 1-9 player names.", "Legg inn 1-9 spillernavn."));
    return;
  }

  const dedupedNames = dedupePlayerNames(names, lang);

  state.lang = lang;
  state.players = dedupedNames.map((name) => ({
    name,
    hand: []
  }));
  state.deck = createDeck();
  state.reversePyramid = reversePyramid;
  state.busStartSide = "left";
  state.setupDraft = {
    playerCount: dedupedNames.length,
    names: [...dedupedNames],
    reversePyramid: state.reversePyramid
  };
  state.phase = "warmup";
  state.warmupRound = 1;
  state.currentPlayerIndex = 0;
  state.pyramidCards = Array(15).fill(null);
  state.pyramidRevealIndex = 0;
  state.busRunnerIndex = null;
  state.tieBreak = null;
  state.busRoute = null;
  state.pendingWarmupGuess = null;
  state.animating = false;
  state.bannerTone = "info";
  state.pyramidHighlightPlayers = [];
  clearAutoPlayTimer();
  state.autoPlay.enabled = false;
  state.autoPlay.running = false;
  state.autoPlayMenuOpen = false;
  state.log = [];
  state.banner = "";

  addLog(tr(
    `Game started with ${state.players.length} player(s).`,
    `Spillet startet med ${state.players.length} spillere.`
  ));
  addLog(reversePyramid
    ? tr("Pyramid drinks are reversed: bottom = 5, top = 1.", "Pyramide er reversert: nederst = 5, øverst = 1.")
    : tr("Pyramid drinks are normal: bottom = 1, top = 5.", "Pyramide er normal: nederst = 1, øverst = 5."));
  addLog(tr(
    "Warmup tip: choose a guess under DEAL in the center to draw immediately.",
    "Oppvarmingstips: velg gjetning under DEAL i midten for umiddelbart trekk."
  ));

  renderAll();
  syncAutoPlay();
}

function resetToSetup(hardReset = false) {
  const hard = hardReset === true;
  const rememberedFromGame = !hard && state.players.length > 0
    ? {
      playerCount: state.players.length,
      names: state.players.map((player) => player.name),
      reversePyramid: state.reversePyramid
    }
    : null;

  state.phase = "setup";
  if (hard) {
    state.lang = "en";
    state.setupDraft = {
      playerCount: 4,
      names: ["", "", "", ""],
      reversePyramid: false
    };
    state.preferences = {
      motionMode: "cinematic",
      effectsLevel: "normal"
    };
    state.autoPlay.delayMs = 1500;
  } else if (rememberedFromGame) {
    state.setupDraft = rememberedFromGame;
  }
  state.players = [];
  state.deck = [];
  state.reversePyramid = state.setupDraft.reversePyramid;
  state.busStartSide = "left";
  state.warmupRound = 1;
  state.currentPlayerIndex = 0;
  state.pyramidCards = Array(15).fill(null);
  state.pyramidRevealIndex = 0;
  state.busRunnerIndex = null;
  state.tieBreak = null;
  state.busRoute = null;
  state.pendingWarmupGuess = null;
  state.animating = false;
  state.bannerTone = "info";
  state.pyramidHighlightPlayers = [];
  clearAutoPlayTimer();
  state.autoPlay.enabled = false;
  state.autoPlay.running = false;
  state.autoPlayMenuOpen = false;
  state.banner = "";
  state.log = [];
  applyVisualPreferences();
  renderAll();
}

function getCurrentPlayer() {
  return state.players[state.currentPlayerIndex];
}

function compareCardRanks(a, b) {
  if (a > b) return 1;
  if (a < b) return -1;
  return 0;
}

function createStackEntry(card) {
  return {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    card,
    offsetX: Math.floor(Math.random() * 17) - 8,
    offsetY: Math.floor(Math.random() * 15) - 8,
    rotate: (Math.random() * 14 - 7).toFixed(2)
  };
}

function clearAutoPlayTimer() {
  if (state.autoPlay.timerId) {
    window.clearTimeout(state.autoPlay.timerId);
    state.autoPlay.timerId = null;
  }
}

function waitMs(ms) {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

function animationScale() {
  if (state.preferences.motionMode === "turbo") return 0.48;
  if (state.preferences.motionMode === "fast") return 0.72;
  return 1.12;
}

function applyVisualPreferences() {
  document.body.dataset.motion = state.preferences.motionMode;
  document.body.dataset.effects = state.preferences.effectsLevel;
}

function pickBestStatKey(statMap) {
  const entries = Object.entries(statMap);
  if (entries.length === 0) return null;
  let best = -Infinity;
  for (const [, value] of entries) {
    if (value > best) best = value;
  }
  const candidates = entries
    .filter(([, value]) => value === best)
    .map(([key]) => key);
  return candidates[Math.floor(Math.random() * candidates.length)] || entries[0][0];
}

function chooseWarmupGuessByStats() {
  const deck = state.deck;
  if (!deck || deck.length === 0) {
    return warmupRoundData(state.warmupRound).options[0].key;
  }
  const player = getCurrentPlayer();

  if (state.warmupRound === 1) {
    const stats = { svart: 0, rodt: 0 };
    for (const card of deck) {
      stats[card.suit.color === "black" ? "svart" : "rodt"] += 1;
    }
    return pickBestStatKey(stats);
  }

  if (state.warmupRound === 2 && player.hand[0]) {
    const ref = player.hand[0].rank;
    const stats = { over: 0, under: 0, samme: 0 };
    for (const card of deck) {
      if (card.rank > ref) stats.over += 1;
      else if (card.rank < ref) stats.under += 1;
      else stats.samme += 1;
    }
    return pickBestStatKey(stats);
  }

  if (state.warmupRound === 3 && player.hand[0] && player.hand[1]) {
    const low = Math.min(player.hand[0].rank, player.hand[1].rank);
    const high = Math.max(player.hand[0].rank, player.hand[1].rank);
    const stats = { mellom: 0, utenfor: 0, samme: 0 };
    for (const card of deck) {
      if (card.rank === low || card.rank === high) stats.samme += 1;
      else if (card.rank > low && card.rank < high) stats.mellom += 1;
      else stats.utenfor += 1;
    }
    return pickBestStatKey(stats);
  }

  const suitStats = { klover: 0, ruter: 0, hjerter: 0, spar: 0 };
  for (const card of deck) {
    suitStats[card.suit.warmupLabel] += 1;
  }
  return pickBestStatKey(suitStats);
}

function chooseBusGuessByStats() {
  const bus = state.busRoute;
  if (!bus || bus.progress >= bus.routeCards.length) return "over";
  const deck = bus.deck;
  if (!deck || deck.length === 0) return "over";

  const activeIndex = bus.order?.[bus.progress] ?? bus.progress;
  const target = bus.routeCards[activeIndex];
  if (!target) return "over";
  const stats = { over: 0, under: 0, samme: 0 };
  for (const card of deck) {
    if (card.rank > target.rank) stats.over += 1;
    else if (card.rank < target.rank) stats.under += 1;
    else stats.samme += 1;
  }
  return pickBestStatKey(stats);
}

function syncAutoPlay() {
  if (!state.autoPlay.enabled || state.phase === "setup" || state.phase === "finished") {
    clearAutoPlayTimer();
    return;
  }
  if (state.autoPlay.running || state.animating || state.autoPlay.timerId) return;

  state.autoPlay.timerId = window.setTimeout(() => {
    state.autoPlay.timerId = null;
    void runAutoPlayStep();
  }, state.autoPlay.delayMs);
}

function toggleAutoPlay(forceValue) {
  const nextValue = typeof forceValue === "boolean" ? forceValue : !state.autoPlay.enabled;
  state.autoPlay.enabled = nextValue;
  state.autoPlay.running = false;

  if (!nextValue) {
    clearAutoPlayTimer();
    addLog(tr("Auto play paused.", "Autospill pause."));
  } else {
    addLog(tr("Auto play enabled.", "Autospill aktivert."));
  }

  renderAll();
  syncAutoPlay();
}

async function runAutoPlayStep() {
  if (!state.autoPlay.enabled || state.phase === "setup" || state.phase === "finished") {
    clearAutoPlayTimer();
    return;
  }
  if (state.animating) {
    syncAutoPlay();
    return;
  }

  state.autoPlay.running = true;
  try {
    if (state.phase === "warmup") {
      await playWarmupGuess(chooseWarmupGuessByStats());
      return;
    }
    if (state.phase === "pyramid") {
      if (state.pyramidRevealIndex < 15) {
        await revealPyramidSlot(pyramidSlotForStep(state.pyramidRevealIndex));
      }
      return;
    }
    if (state.phase === "tiebreak") {
      await runTieBreakRound();
      return;
    }
    if (state.phase === "bussetup") {
      beginBusRoute(state.busStartSide || "left");
      renderAll();
      return;
    }
    if (state.phase === "bus" && state.busRoute) {
      const activeIndex = state.busRoute.order?.[state.busRoute.progress] ?? state.busRoute.progress;
      await playBusGuess(chooseBusGuessByStats(), activeIndex);
    }
  } finally {
    state.autoPlay.running = false;
    syncAutoPlay();
  }
}

function addLog(message) {
  state.log.unshift(message);
  if (state.log.length > 140) {
    state.log.length = 140;
  }
}

function warmupRoundData(round) {
  if (round === 1) {
    return {
      title: tr("Round 1: Black or Red", "Runde 1: Svart eller Rødt"),
      prompt: tr("Guess color. Correct: give 1 drink, wrong: drink 1.", "Gjett farge. Riktig: del ut 1, feil: drikk 1."),
      options: [
        { key: "svart", label: guessLabel("svart") },
        { key: "rodt", label: guessLabel("rodt") }
      ]
    };
  }

  if (round === 2) {
    return {
      title: tr("Round 2: Higher or Lower", "Runde 2: Over eller Under"),
      prompt: tr("Compare against your card from round 1.", "Sammenlikn med kortet fra runde 1."),
      options: [
        { key: "over", label: guessLabel("over") },
        { key: "under", label: guessLabel("under") },
        { key: "samme", label: guessLabel("samme") }
      ]
    };
  }

  if (round === 3) {
    return {
      title: tr("Round 3: Between or Outside", "Runde 3: Mellom eller Utenfor"),
      prompt: tr("Compare against your first two cards.", "Sammenlikn med de to første kortene dine."),
      options: [
        { key: "mellom", label: guessLabel("mellom") },
        { key: "utenfor", label: guessLabel("utenfor") },
        { key: "samme", label: guessLabel("samme") }
      ]
    };
  }

  return {
    title: tr("Round 4: Guess Suit", "Runde 4: Gjett sort"),
    prompt: tr("Pick suit.", "Gjett sort."),
    options: [
      { key: "klover", label: guessLabel("klover") },
      { key: "ruter", label: guessLabel("ruter") },
      { key: "hjerter", label: guessLabel("hjerter") },
      { key: "spar", label: guessLabel("spar") }
    ]
  };
}

function warmupGuessDisplay(guess) {
  return guessLabel(guess);
}

async function playWarmupGuess(guess) {
  if (state.animating || state.phase !== "warmup") return;
  state.pendingWarmupGuess = guess;
  state.bannerTone = "info";
  state.banner = tr(`Selected: ${warmupGuessDisplay(guess)}. Dealing...`, `Valgt: ${warmupGuessDisplay(guess)}. Trekker kort...`);
  renderAll();
  await revealWarmupCardFromDeck(guess);
}

function evaluateWarmupRound(round, guess, player, drawnCard) {
  if (round === 1) {
    const actual = drawnCard.suit.color === "black" ? "svart" : "rodt";
    const correct = guess === actual;
    return {
      correct,
      message: correct
        ? tr(`${player.name} drew ${cardLabel(drawnCard)}. Correct, give out 1 drink.`, `${player.name} trakk ${cardLabel(drawnCard)}. Riktig, del ut 1 slurk.`)
        : tr(`${player.name} drew ${cardLabel(drawnCard)}. Wrong, drink 1.`, `${player.name} trakk ${cardLabel(drawnCard)}. Feil, drikk 1.`)
    };
  }

  if (round === 2) {
    const firstCard = player.hand[0];
    const relation = compareCardRanks(drawnCard.rank, firstCard.rank);

    if (relation > 0 && guess === "over") {
      return { correct: true, message: tr(`${player.name} drew ${cardLabel(drawnCard)} over ${cardLabel(firstCard)}. Correct, give out 2 drinks.`, `${player.name} trakk ${cardLabel(drawnCard)} over ${cardLabel(firstCard)}. Riktig, del ut 2.`) };
    }
    if (relation < 0 && guess === "under") {
      return { correct: true, message: tr(`${player.name} drew ${cardLabel(drawnCard)} under ${cardLabel(firstCard)}. Correct, give out 2 drinks.`, `${player.name} trakk ${cardLabel(drawnCard)} under ${cardLabel(firstCard)}. Riktig, del ut 2.`) };
    }
    if (relation === 0 && guess === "samme") {
      return { correct: true, message: tr(`${player.name} drew ${cardLabel(drawnCard)} equal to ${cardLabel(firstCard)}. Perfect, give out 4 drinks.`, `${player.name} trakk ${cardLabel(drawnCard)} lik ${cardLabel(firstCard)}. Perfekt, del ut 4.`) };
    }
    if (relation === 0) {
      return { correct: false, message: tr(`${player.name} drew ${cardLabel(drawnCard)} equal to ${cardLabel(firstCard)}. Wrong, drink 4.`, `${player.name} trakk ${cardLabel(drawnCard)} lik ${cardLabel(firstCard)}. Feil, drikk 4.`) };
    }
    return { correct: false, message: tr(`${player.name} drew ${cardLabel(drawnCard)}. Wrong, drink 2.`, `${player.name} trakk ${cardLabel(drawnCard)}. Feil, drikk 2.`) };
  }

  if (round === 3) {
    const first = player.hand[0].rank;
    const second = player.hand[1].rank;
    const low = Math.min(first, second);
    const high = Math.max(first, second);

    if (guess === "samme") {
      if (drawnCard.rank === low || drawnCard.rank === high) {
        return { correct: true, message: tr(`${player.name} drew ${cardLabel(drawnCard)} matching edge cards. Correct, give out 6 drinks.`, `${player.name} trakk ${cardLabel(drawnCard)} på kantkort. Riktig, del ut 6.`) };
      }
      return { correct: false, message: tr(`${player.name} drew ${cardLabel(drawnCard)} without edge match. Wrong, drink 3.`, `${player.name} trakk ${cardLabel(drawnCard)} uten kanttreff. Feil, drikk 3.`) };
    }

    if (drawnCard.rank === low || drawnCard.rank === high) {
      return { correct: false, message: tr(`${player.name} drew ${cardLabel(drawnCard)} equal to an edge card. Wrong, drink 6.`, `${player.name} trakk ${cardLabel(drawnCard)} lik et kantkort. Feil, drikk 6.`) };
    }

    if (guess === "mellom") {
      const correct = drawnCard.rank > low && drawnCard.rank < high;
      return {
        correct,
        message: correct
          ? tr(`${player.name} drew ${cardLabel(drawnCard)} between cards. Correct, give out 3 drinks.`, `${player.name} trakk ${cardLabel(drawnCard)} mellom kortene. Riktig, del ut 3.`)
          : tr(`${player.name} drew ${cardLabel(drawnCard)} outside cards. Wrong, drink 3.`, `${player.name} trakk ${cardLabel(drawnCard)} utenfor kortene. Feil, drikk 3.`)
      };
    }

    const correct = drawnCard.rank < low || drawnCard.rank > high;
    return {
      correct,
      message: correct
        ? tr(`${player.name} drew ${cardLabel(drawnCard)} outside cards. Correct, give out 3 drinks.`, `${player.name} trakk ${cardLabel(drawnCard)} utenfor kortene. Riktig, del ut 3.`)
        : tr(`${player.name} drew ${cardLabel(drawnCard)} between cards. Wrong, drink 3.`, `${player.name} trakk ${cardLabel(drawnCard)} mellom kortene. Feil, drikk 3.`)
    };
  }

  const correct = guess === drawnCard.suit.warmupLabel;
  return {
    correct,
    message: correct
      ? tr(`${player.name} drew ${cardLabel(drawnCard)}. Correct suit, give out 4 drinks.`, `${player.name} trakk ${cardLabel(drawnCard)}. Riktig sort, del ut 4.`)
      : tr(`${player.name} drew ${cardLabel(drawnCard)}. Wrong suit, drink 4.`, `${player.name} trakk ${cardLabel(drawnCard)}. Feil sort, drikk 4.`)
  };
}

function advanceWarmupTurn() {
  if (state.currentPlayerIndex < state.players.length - 1) {
    state.currentPlayerIndex += 1;
    return;
  }

  if (state.warmupRound < 4) {
    state.warmupRound += 1;
    state.currentPlayerIndex = 0;
    addLog(tr(`Warmup round ${state.warmupRound} begins.`, `Oppvarmingsrunde ${state.warmupRound} starter.`));
    return;
  }

  state.phase = "pyramid";
  state.currentPlayerIndex = 0;
  state.pyramidHighlightPlayers = [];
  state.bannerTone = "info";
  addLog(tr("Warmup is complete. Pyramid phase begins.", "Oppvarmingen er ferdig. Pyramiden starter."));
  state.banner = tr("Click the glowing pyramid back-card to reveal next.", "Klikk det lysende pyramidkortet for å snu neste.");
}

async function revealWarmupCardFromDeck(guessOverride) {
  if (state.phase !== "warmup" || state.animating) return;
  const guess = guessOverride || state.pendingWarmupGuess;
  if (!guess) {
    state.bannerTone = "info";
    state.banner = tr("Choose a guess under DEAL first.", "Velg en gjetning under DEAL først.");
    renderAll();
    return;
  }

  const player = getCurrentPlayer();
  state.pendingWarmupGuess = guess;
  const card = drawCardFromDeck("deck");
  const result = evaluateWarmupRound(state.warmupRound, guess, player, card);

  state.animating = true;
  player.hand.push(card);
  renderAll();

  const fromEl = document.getElementById("deckStack");
  const seatAnchorEl = document.querySelector(`[data-seat-index="${state.currentPlayerIndex}"] .seat-anchor`);
  const targetCardEl = document.querySelector(`[data-seat-index="${state.currentPlayerIndex}"] .seat-anchor .playing-card:last-child`);
  if (targetCardEl) {
    targetCardEl.style.visibility = "hidden";
  }
  const toEl = targetCardEl || seatAnchorEl;

  await animateCardFlight({ fromEl, toEl, card, back: false });
  if (targetCardEl) {
    targetCardEl.style.visibility = "";
  }
  const seatPulseNow = document.querySelector(`[data-seat-index="${state.currentPlayerIndex}"] .seat-chip`);
  await pulseElement(seatPulseNow || toEl, result.correct ? "success" : "fail");

  addLog(result.message);
  state.bannerTone = result.correct ? "success" : "fail";
  state.banner = result.message;
  state.pendingWarmupGuess = null;
  advanceWarmupTurn();
  state.animating = false;
  renderAll();
}
function pyramidDrinksForIndex(index) {
  let base = 1;
  if (index >= 5) base = 2;
  if (index >= 9) base = 3;
  if (index >= 12) base = 4;
  if (index === 14) base = 5;
  return state.reversePyramid ? 6 - base : base;
}

function pyramidSlotForStep(step) {
  const normalized = clamp(Number(step) || 0, 0, 14);
  return state.reversePyramid ? 14 - normalized : normalized;
}

function collectPyramidMatches(card, drinksBase) {
  const matchingPlayers = [];
  for (let idx = 0; idx < state.players.length; idx += 1) {
    const player = state.players[idx];
    const matches = player.hand.filter((handCard) => handCard.rank === card.rank);
    if (matches.length === 0) continue;

    matchingPlayers.push({
      playerIndex: idx,
      playerName: player.name,
      cards: matches,
      count: matches.length,
      drinks: drinksBase * matches.length
    });
  }
  return matchingPlayers;
}

async function revealPyramidSlot(index) {
  if (state.phase !== "pyramid" || state.animating) return;
  const targetIndex = pyramidSlotForStep(state.pyramidRevealIndex);
  if (index !== targetIndex) return;

  const slotEl = document.querySelector(`[data-pyramid-slot="${index}"]`);
  if (!slotEl) return;

  state.animating = true;
  const hadPreviousHighlights = state.pyramidHighlightPlayers.length > 0;
  state.pyramidHighlightPlayers = [];
  state.bannerTone = "info";
  if (hadPreviousHighlights) {
    renderAll();
  }

  const card = drawCardFromDeck("deck");
  const drinksBase = pyramidDrinksForIndex(index);

  state.pyramidCards[index] = card;
  state.pyramidRevealIndex += 1;

  const matches = collectPyramidMatches(card, drinksBase);
  const success = matches.length > 0;
  state.pyramidHighlightPlayers = matches.map((match) => match.playerIndex);

  addLog(tr(`Pyramid revealed ${cardLabel(card)} (row value ${drinksBase}).`, `Pyramiden viste ${cardLabel(card)} (radverdi ${drinksBase}).`));
  if (success) {
    for (const match of matches) {
      addLog(tr(
        `${match.playerName} matched ${match.count} card(s) and can give out ${match.drinks} drink(s).`,
        `${match.playerName} hadde ${match.count} treff og kan dele ut ${match.drinks}.`
      ));
    }
    const detailsEn = matches
      .map((match) => `${match.playerName}: give ${match.drinks}`)
      .join(" | ");
    const detailsNo = matches
      .map((match) => `${match.playerName}: del ut ${match.drinks}`)
      .join(" | ");
    state.bannerTone = "success";
    state.banner = tr(
      `${cardLabel(card)} matched. ${detailsEn}`,
      `${cardLabel(card)} ga treff. ${detailsNo}`
    );
  } else {
    addLog(tr(`No player had rank ${rankLabel(card.rank)}.`, `Ingen hadde rank ${rankLabel(card.rank)}.`));
    state.bannerTone = "fail";
    state.banner = tr(
      `${cardLabel(card)} gave no matches. No drinks handed out.`,
      `${cardLabel(card)} ga ingen treff. Ingen kan dele ut.`
    );
  }

  renderAll();
  const newCardEl = document.querySelector(`[data-pyramid-slot="${index}"] .playing-card`);
  if (newCardEl) {
    newCardEl.classList.add("flip-reveal");
  }
  await waitMs(Math.round(130 * animationScale()));

  if (success) {
    for (const match of matches) {
      for (const matchedCard of match.cards) {
        const fromEl = document.querySelector(`[data-seat-index="${match.playerIndex}"] .seat-anchor`);
        const toEl = document.querySelector(`[data-pyramid-slot="${index}"] .playing-card`) || slotEl;
        await animateCardFlight({ fromEl, toEl, card: matchedCard, back: false, duration: 520 });

        const hand = state.players[match.playerIndex].hand;
        const removeIdx = hand.findIndex((handCard) => handCard.rank === card.rank);
        if (removeIdx !== -1) {
          hand.splice(removeIdx, 1);
          renderAll();
        }
      }
    }
  }

  await pulseElement(newCardEl, success ? "success" : "fail", success ? "normal" : "soft");

  if (state.pyramidRevealIndex === 15) {
    finalizePyramid();
  }

  state.animating = false;
  renderAll();
}

function finalizePyramid() {
  const counts = state.players.map((player) => player.hand.length);
  const maxCount = Math.max(...counts);
  const contenders = counts
    .map((count, idx) => ({ count, idx }))
    .filter((entry) => entry.count === maxCount)
    .map((entry) => entry.idx);

  if (contenders.length === 1) {
    state.busRunnerIndex = contenders[0];
    addLog(tr(
      `${state.players[state.busRunnerIndex].name} has most cards (${maxCount}) and takes bus route.`,
      `${state.players[state.busRunnerIndex].name} har flest kort (${maxCount}) og må ta bussruta.`
    ));
    startBusRoute();
  } else {
    startTieBreak(contenders, maxCount);
  }
}

function startTieBreak(contenders, maxCount) {
  state.phase = "tiebreak";
  state.tieBreak = {
    contenders: [...contenders],
    deck: createDeck(),
    round: 1,
    lastDraws: []
  };
  addLog(tr(
    `Tie on most cards (${maxCount}). Starting tie-break.`,
    `Likestilling med flest kort (${maxCount}). Starter tie-break.`
  ));
  state.bannerTone = "info";
  state.banner = tr(
    "Tie-break: highest card wins. Click the tie deck to draw.",
    "Tie-break: høyeste kort vinner. Klikk tie-stokken for trekk."
  );
}

async function runTieBreakRound() {
  if (state.phase !== "tiebreak" || state.animating) return;
  const tie = state.tieBreak;
  if (!tie || tie.contenders.length < 2) return;

  if (tie.deck.length < tie.contenders.length) {
    tie.deck = createDeck();
    addLog(tr("Tie-break deck reshuffled.", "Tie-break-stokk stokket på nytt."));
  }

  state.animating = true;
  tie.lastDraws = [];
  renderAll();

  for (const idx of tie.contenders) {
    const draw = tie.deck.pop();
    const fromEl = document.getElementById("tieDeckStack");
    const toEl = document.querySelector(`[data-tie-slot="${idx}"]`);
    await animateCardFlight({ fromEl, toEl, card: draw, back: false, duration: 520 });
    tie.lastDraws.push({ idx, card: draw });
    renderAll();
  }

  const highest = Math.max(...tie.lastDraws.map((entry) => entry.card.rank));
  const next = tie.lastDraws
    .filter((entry) => entry.card.rank === highest)
    .map((entry) => entry.idx);

  const summary = tie.lastDraws
    .map((entry) => `${state.players[entry.idx].name}: ${cardLabel(entry.card)}`)
    .join(" | ");
  addLog(tr(`Tie-break round ${tie.round}: ${summary}.`, `Tie-break runde ${tie.round}: ${summary}.`));

  renderAll();
  for (const entry of tie.lastDraws) {
    const slotCard = document.querySelector(`[data-tie-slot="${entry.idx}"] .playing-card`);
    await pulseElement(slotCard, next.includes(entry.idx) ? "success" : "fail");
  }

  if (next.length === 1) {
    state.busRunnerIndex = next[0];
    addLog(tr(
      `${state.players[state.busRunnerIndex].name} won tie-break and takes bus route.`,
      `${state.players[state.busRunnerIndex].name} vant tie-break og tar bussruta.`
    ));
    state.tieBreak = null;
    state.animating = false;
    startBusRoute();
    renderAll();
    return;
  }

  tie.contenders = next;
  tie.round += 1;
  state.bannerTone = "info";
  state.banner = tr(
    `${next.length} players are still tied. Draw next tie-break round.`,
    `${next.length} spillere er fortsatt likt. Trekk neste tie-break-runde.`
  );
  state.animating = false;
  renderAll();
}

function startBusRoute() {
  const pausedAutoPlay = state.autoPlay.enabled;
  if (pausedAutoPlay) {
    state.autoPlay.enabled = false;
    state.autoPlay.running = false;
    clearAutoPlayTimer();
    addLog(tr(
      "Auto play paused for bus route. Press Auto Play again to continue automatically.",
      "Autospill stoppet ved bussruta. Trykk Autospill igjen for å fortsette automatisk."
    ));
  }

  const busDeck = createDeck();
  const routeCards = [];
  for (let i = 0; i < 5; i += 1) {
    routeCards.push(busDeck.pop());
  }

  state.busRoute = {
    routeCards,
    deck: busDeck,
    overlays: Array.from({ length: 5 }, () => ({ high: [], low: [], same: [] })),
    zoneTone: Array.from({ length: 5 }, () => ({ high: "", low: "", same: "" })),
    startSide: null,
    order: [0, 1, 2, 3, 4],
    progress: 0,
    firstTry: true,
    history: []
  };

  state.phase = "bussetup";
  state.bannerTone = "info";
  const runnerName = state.players[state.busRunnerIndex]?.name || tr("Runner", "Deltaker");
  const pausedNote = pausedAutoPlay
    ? tr(" Auto play is paused here; press Auto Play again after choosing side.", " Autospill er pause her; trykk Autospill igjen etter sidevalg.")
    : "";
  state.banner = tr(
    `${runnerName} must choose start side after the route cards are dealt.${pausedNote}`,
    `${runnerName} må velge startside etter at rutekortene er lagt ut.${pausedNote}`
  );
  addLog(state.banner);
}

function beginBusRoute(startSide = "left") {
  const chosenSide = startSide === "right" ? "right" : "left";
  state.busStartSide = chosenSide;
  const order = chosenSide === "right" ? [4, 3, 2, 1, 0] : [0, 1, 2, 3, 4];
  const bus = state.busRoute;
  if (!bus) {
    return;
  }

  state.phase = "bus";
  bus.startSide = chosenSide;
  bus.order = order;
  bus.progress = 0;
  bus.firstTry = true;

  state.bannerTone = "info";
  const routeMessage = tr(
    `${state.players[state.busRunnerIndex].name} starts the bus route from the ${chosenSide}. Click above, below, or same on the active stop.`,
    `${state.players[state.busRunnerIndex].name} starter bussruta fra ${chosenSide === "right" ? "høyre" : "venstre"}. Klikk over, under eller samme på aktivt stopp.`
  );
  state.banner = routeMessage;
  addLog(state.banner);
}

async function playBusGuess(guess, step) {
  if (state.phase !== "bus" || state.animating) return;

  const bus = state.busRoute;
  if (!bus) return;
  const activeStep = bus.order?.[bus.progress] ?? bus.progress;
  if (step !== activeStep) return;

  const placement = guess === "over" ? "high" : guess === "under" ? "low" : "same";
  const fromEl = document.getElementById("busDeckStack");
  const toEl = document.querySelector(`[data-bus-zone="${activeStep}-${placement}"]`);
  if (!fromEl || !toEl) return;

  const target = bus.routeCards[activeStep];
  const draw = drawCardFromBusDeck();
  const relation = compareCardRanks(draw.rank, target.rank);

  state.animating = true;
  await animateCardFlight({ fromEl, toEl, card: draw, back: false, duration: 560 });

  let correct = false;
  let restartRoute = false;
  let message = "";

  if (guess === "over" && relation > 0) {
    correct = true;
    bus.progress += 1;
    message = tr(`Correct: ${cardLabel(draw)} is higher than ${cardLabel(target)}.`, `Riktig: ${cardLabel(draw)} er høyere enn ${cardLabel(target)}.`);
  } else if (guess === "under" && relation < 0) {
    correct = true;
    bus.progress += 1;
    message = tr(`Correct: ${cardLabel(draw)} is lower than ${cardLabel(target)}.`, `Riktig: ${cardLabel(draw)} er lavere enn ${cardLabel(target)}.`);
  } else if (guess === "samme" && relation === 0) {
    correct = true;
    bus.progress += 1;
    message = tr(`Correct: ${cardLabel(draw)} equals ${cardLabel(target)}.`, `Riktig: ${cardLabel(draw)} er lik ${cardLabel(target)}.`);
  } else if (relation === 0 && bus.progress > 0 && guess !== "samme") {
    message = tr(`Equal card ${cardLabel(draw)}. Drink ${bus.progress + 1} and retry this step.`, `Lik verdi ${cardLabel(draw)}. Drikk ${bus.progress + 1} og prøv samme steg igjen.`);
  } else {
    restartRoute = true;
    bus.firstTry = false;
    message = tr(`Wrong with ${cardLabel(draw)}. Drink ${bus.progress + 1} and restart route.`, `Feil med ${cardLabel(draw)}. Drikk ${bus.progress + 1} og start ruta på nytt.`);
  }

  const zone = bus.overlays[activeStep] || { high: [], low: [], same: [] };
  const placedEntry = createStackEntry(draw);
  zone[placement].push(placedEntry);
  if (zone[placement].length > 6) {
    zone[placement].shift();
  }
  bus.overlays[activeStep] = zone;
  bus.zoneTone[activeStep] = { high: "", low: "", same: "" };
  bus.zoneTone[activeStep][placement] = correct ? "success" : "fail";
  bus.history.push({ step: activeStep, guess, target, draw, message, correct });
  state.bannerTone = correct ? "success" : "fail";
  state.banner = message;
  addLog(message);

  renderAll();
  await waitMs(Math.round(90 * animationScale()));

  if (restartRoute && bus.progress > 0) {
    const clearBefore = bus.progress;
    window.setTimeout(() => {
      if (state.busRoute !== bus) return;
      for (let idx = 0; idx < clearBefore; idx += 1) {
        const cardIdx = bus.order?.[idx] ?? idx;
        bus.zoneTone[cardIdx] = { high: "", low: "", same: "" };
      }
      if (state.phase === "bus") {
        renderAll();
      }
    }, 1450);
  }

  if (restartRoute) {
    bus.progress = 0;
  }

  if (bus.progress >= 5) {
    state.phase = "finished";
    if (bus.firstTry) {
      const finishText = tr(
        `${state.players[state.busRunnerIndex].name} finished on first try. Everyone else finishes drinks.`,
        `${state.players[state.busRunnerIndex].name} klarte det på første forsøk. Alle andre må fullføre enheten sin.`
      );
      addLog(finishText);
      state.bannerTone = "success";
      state.banner = finishText;
    } else {
      const finishText = tr(
        `${state.players[state.busRunnerIndex].name} completed the bus route.`,
        `${state.players[state.busRunnerIndex].name} fullførte bussruta.`
      );
      addLog(finishText);
      state.bannerTone = "success";
      state.banner = finishText;
    }
  }

  state.animating = false;
  renderAll();
}

function renderAll() {
  document.body.dataset.phase = state.phase;
  renderHeader();
  renderPhaseLabel();
  renderDeckLabel();
  renderPlayerBoard();
  renderControls();
  renderBoard();
  renderLog();
  syncAutoPlay();
}

function headerSubtitleText() {
  if (state.phase === "setup") {
    return tr(
      "Warmup rounds, pyramid showdown, and the bus route finale.",
      "Oppvarmingsrunder, pyramidespill og bussruta-finale."
    );
  }

  if (state.phase === "warmup") {
    return tr(
      `Warmup round ${state.warmupRound}: active player guesses, then the deck deals automatically.`,
      `Oppvarming runde ${state.warmupRound}: aktiv spiller gjetter, og kort deles automatisk.`
    );
  }

  if (state.phase === "pyramid") {
    return tr(
      "Pyramid: click the highlighted card. Matching ranks give drinks by row value.",
      "Pyramide: klikk markert kort. Like ranker gir utdeling etter radverdi."
    );
  }

  if (state.phase === "tiebreak") {
    return tr(
      "Tie-break: click the tie deck. Highest card wins the bus route.",
      "Tie-break: klikk tie-stokken. Høyeste kort vinner bussruta."
    );
  }

  if (state.phase === "bus") {
    return tr(
      "Bus route: guess above, below, or same on the active card. Wrong guess restarts.",
      "Bussrute: gjett over, under eller samme på aktivt kort. Feil gjetning starter på nytt."
    );
  }

  if (state.phase === "bussetup") {
    return tr(
      "Bus route setup: the runner chooses whether to start from left or right.",
      "Bussrute-oppsett: deltakeren velger om ruta starter fra venstre eller høyre."
    );
  }

  return tr(
    "Game complete. Start a new game when ready.",
    "Spillet er ferdig. Start nytt spill når dere er klare."
  );
}

function renderHeader() {
  document.documentElement.lang = state.lang === "no" ? "no" : "en";

  if (pageHeaderTitle) {
    pageHeaderTitle.textContent = "Bussruta";
  }
  if (pageHeaderSubtitle) {
    pageHeaderSubtitle.textContent = headerSubtitleText();
  }
  if (statusHeading) {
    statusHeading.textContent = tr("Status", "Status");
  }
  if (logHeading) {
    logHeading.textContent = tr("Game Log", "Spilllogg");
  }
}

function renderPhaseLabel() {
  const labels = {
    setup: tr("Setup", "Oppsett"),
    warmup: tr(`Warmup Round ${state.warmupRound}`, `Oppvarming Runde ${state.warmupRound}`),
    pyramid: tr("Pyramid", "Pyramide"),
    tiebreak: tr("Tie-Break", "Tie-break"),
    bussetup: tr("Bus Setup", "Buss-oppsett"),
    bus: tr("Bus Route", "Bussrute"),
    finished: tr("Finished", "Ferdig")
  };
  phaseLabel.textContent = labels[state.phase] || tr("Game", "Spill");
}

function renderDeckLabel() {
  let remaining = state.phase === "setup" ? 52 : state.deck.length;
  if (state.phase === "tiebreak" && state.tieBreak) {
    remaining = state.tieBreak.deck.length;
  }
  if ((state.phase === "bussetup" || state.phase === "bus" || state.phase === "finished") && state.busRoute) {
    remaining = state.busRoute.deck.length;
  }
  deckLabel.textContent = tr(`Deck: ${remaining} cards`, `Stokk: ${remaining} kort`);
}

function renderPlayerBoard() {
  if (state.players.length === 0) {
    playerBoard.classList.remove("dense-status", "compact-status");
    playerBoard.innerHTML = `<p class="caption">${tr("No players yet.", "Ingen spillere ennå.")}</p>`;
    return;
  }

  const denseStatus = state.players.length >= 9;
  const compactStatus = !denseStatus && state.players.length >= 7;
  playerBoard.classList.toggle("dense-status", denseStatus);
  playerBoard.classList.toggle("compact-status", compactStatus);

  const activeIndex = state.phase === "warmup"
    ? state.currentPlayerIndex
    : (state.phase === "bussetup" || state.phase === "bus" || state.phase === "finished")
      ? state.busRunnerIndex
      : null;

  playerBoard.innerHTML = state.players
    .map((player, idx) => {
      const active = idx === activeIndex;
      return `
        <div class="player-card ${active ? "active" : ""}">
          <div class="player-name">${escapeHtml(player.name)}</div>
          <div class="player-meta">${tr("Cards left", "Kort igjen")}: ${player.hand.length}</div>
        </div>
      `;
    })
    .join("");
}

function autoPlayControlsHtml() {
  const enabled = state.autoPlay.enabled;
  const selectedPresetKey = nearestAutoPlayPresetKey();
  const delayLabel = formatDelayLabel(state.autoPlay.delayMs);

  return `
    <div class="auto-play-tools">
      <button id="toggleAutoPlayBtn" class="btn btn-mini auto-play-toggle ${enabled ? "btn-secondary" : "btn-neutral"}">
        ${enabled ? tr("Auto ON", "Auto PÅ") : tr("Auto OFF", "Auto AV")}
      </button>
      <details class="auto-play-menu" ${state.autoPlayMenuOpen ? "open" : ""}>
        <summary>${tr("Options", "Valg")}</summary>
        <div class="auto-play-menu-body">
          <label class="auto-play-inline compact">
            <span>${tr("Pace", "Tempo")}</span>
            <select id="autoPlayPresetSelect">
              ${AUTO_PLAY_PRESETS
                .map((preset) => `
                  <option value="${preset.key}" ${preset.key === selectedPresetKey ? "selected" : ""}>${state.lang === "no" ? preset.no : preset.en}</option>
                `)
                .join("")}
            </select>
          </label>
          <label class="auto-play-inline compact">
            <span>${tr("Motion", "Bevegelse")}</span>
            <select id="motionModeSelect">
              <option value="cinematic" ${state.preferences.motionMode === "cinematic" ? "selected" : ""}>${tr("Cinematic", "Kino")}</option>
              <option value="fast" ${state.preferences.motionMode === "fast" ? "selected" : ""}>${tr("Fast", "Rask")}</option>
              <option value="turbo" ${state.preferences.motionMode === "turbo" ? "selected" : ""}>${tr("Turbo", "Turbo")}</option>
            </select>
          </label>
          <label class="auto-play-inline compact">
            <span>${tr("Effects", "Effekter")}</span>
            <select id="effectsLevelSelect">
              <option value="subtle" ${state.preferences.effectsLevel === "subtle" ? "selected" : ""}>${tr("Subtle", "Rolig")}</option>
              <option value="normal" ${state.preferences.effectsLevel === "normal" ? "selected" : ""}>${tr("Normal", "Normal")}</option>
              <option value="strong" ${state.preferences.effectsLevel === "strong" ? "selected" : ""}>${tr("Strong", "Sterk")}</option>
            </select>
          </label>
          <span class="auto-play-note">${tr(`Delay ${delayLabel}. Uses probability-based choices.`, `Forsinkelse ${delayLabel}. Bruker sannsynlighetsvalg.`)}</span>
        </div>
      </details>
    </div>
  `;
}

function bindAutoPlayControls() {
  document.getElementById("toggleAutoPlayBtn")?.addEventListener("click", () => toggleAutoPlay());

  const autoMenu = document.querySelector(".auto-play-menu");
  if (autoMenu) {
    autoMenu.addEventListener("toggle", () => {
      state.autoPlayMenuOpen = autoMenu.open;
    });
  }

  const presetSelect = document.getElementById("autoPlayPresetSelect");
  if (presetSelect) {
    presetSelect.addEventListener("change", () => {
      const preset = AUTO_PLAY_PRESETS.find((entry) => entry.key === presetSelect.value);
      if (!preset) return;
      state.autoPlay.delayMs = clamp(preset.delayMs, AUTO_PLAY_DELAY_MIN, AUTO_PLAY_DELAY_MAX);
      if (["cinematic", "fast", "turbo"].includes(preset.motionMode)) {
        state.preferences.motionMode = preset.motionMode;
      }
      if (["subtle", "normal", "strong"].includes(preset.effectsLevel)) {
        state.preferences.effectsLevel = preset.effectsLevel;
      }
      state.autoPlayMenuOpen = true;
      applyVisualPreferences();
      if (state.autoPlay.enabled) {
        clearAutoPlayTimer();
        syncAutoPlay();
      }
      renderAll();
    });
  }

  const motion = document.getElementById("motionModeSelect");
  if (motion) {
    motion.addEventListener("change", () => {
      state.preferences.motionMode = ["cinematic", "fast", "turbo"].includes(motion.value) ? motion.value : "cinematic";
      state.autoPlayMenuOpen = true;
      applyVisualPreferences();
      renderAll();
    });
  }

  const effects = document.getElementById("effectsLevelSelect");
  if (effects) {
    effects.addEventListener("change", () => {
      state.preferences.effectsLevel = ["subtle", "normal", "strong"].includes(effects.value) ? effects.value : "normal";
      state.autoPlayMenuOpen = true;
      applyVisualPreferences();
      renderAll();
    });
  }
}

function renderControls() {
  if (state.phase === "setup") {
    controls.innerHTML = "";
    controls.appendChild(setupTemplate.content.cloneNode(true));

    const list = controls.querySelector("#playerList");
    const countSelect = controls.querySelector("#playerCountSelect");
    const addPlayerBtn = controls.querySelector("#addPlayerBtn");
    const removePlayerBtn = controls.querySelector("#removePlayerBtn");
    const randomizeNamesBtn = controls.querySelector("#randomizeNamesBtn");
    const resetSetupBtn = controls.querySelector("#resetSetupBtn");
    const reverseBox = document.getElementById("reversePyramid");

    const syncSetupCount = (nextCount) => {
      const count = clamp(nextCount, 1, 9);
      state.setupDraft.playerCount = count;
      if (state.setupDraft.names.length < count) {
        while (state.setupDraft.names.length < count) {
          state.setupDraft.names.push("");
        }
      } else if (state.setupDraft.names.length > count) {
        state.setupDraft.names = state.setupDraft.names.slice(0, count);
      }
    };

    const renderSetupNameRows = () => {
      if (!list) return;
      list.innerHTML = state.setupDraft.names
        .map((value, idx) => `
          <div class="setup-player-row">
            <span class="setup-player-tag">${tr("Player", "Spiller")} ${idx + 1}</span>
            <input type="text" data-setup-name="${idx}" value="${escapeHtml(value)}" placeholder="${tr("Name", "Navn")}">
            <button
              type="button"
              class="setup-remove-x"
              data-setup-remove="${idx}"
              title="${tr("Remove this player", "Fjern denne spilleren")}"
              aria-label="${tr(`Remove player ${idx + 1}`, `Fjern spiller ${idx + 1}`)}"
              ${state.setupDraft.playerCount <= 1 ? "disabled" : ""}
            >x</button>
          </div>
        `)
        .join("");

      list.querySelectorAll("[data-setup-name]").forEach((input) => {
        input.addEventListener("input", () => {
          const idx = Number(input.dataset.setupName);
          if (Number.isNaN(idx)) return;
          state.setupDraft.names[idx] = input.value;
        });
      });

      list.querySelectorAll("[data-setup-remove]").forEach((button) => {
        button.addEventListener("click", () => {
          if (state.setupDraft.playerCount <= 1) return;
          const idx = Number(button.dataset.setupRemove);
          if (Number.isNaN(idx)) return;
          state.setupDraft.names.splice(idx, 1);
          syncSetupCount(state.setupDraft.playerCount - 1);
          renderControls();
        });
      });
    };

    const applySetupLocale = () => {
      const title = controls.querySelector("h2");
      if (title) title.textContent = tr("Start game", "Start spill");
      const intro = controls.querySelector("p");
      if (intro) intro.textContent = tr("Choose players, then edit names (1-9 players).", "Velg antall spillere og rediger navn (1-9 spillere).");
      const langLabel = controls.querySelector("#langLabel");
      if (langLabel) langLabel.textContent = tr("Language", "Språk");
      const countLabel = controls.querySelector("#playerCountLabel");
      if (countLabel) countLabel.textContent = tr("Players", "Spillere");
      const addLabel = controls.querySelector("#addPlayerBtn");
      if (addLabel) addLabel.textContent = tr("Add player", "Legg til spiller");
      const removeLabel = controls.querySelector("#removePlayerBtn");
      if (removeLabel) removeLabel.textContent = tr("Remove player", "Fjern spiller");
      const randomizeLabel = controls.querySelector("#randomizeNamesBtn");
      if (randomizeLabel) randomizeLabel.textContent = tr("Randomize", "Tilfeldige");
      const resetSetupLabel = controls.querySelector("#resetSetupBtn");
      if (resetSetupLabel) resetSetupLabel.textContent = tr("Reset setup", "Nullstill oppsett");
      const reverseLabel = controls.querySelector("#reverseLabel");
      if (reverseLabel) reverseLabel.textContent = tr("Reverse pyramid drinks (bottom = 5, top = 1)", "Reverser pyramide (nederst = 5, øverst = 1)");
      const startBtn = document.getElementById("startGameBtn");
      if (startBtn) startBtn.textContent = tr("Start game", "Start spill");
      renderSetupNameRows();
    };

    const langSelect = document.getElementById("langSelect");
    if (langSelect) {
      langSelect.value = state.lang;
      langSelect.addEventListener("change", () => {
        state.lang = langSelect.value;
        applySetupLocale();
        renderHeader();
        renderPhaseLabel();
        renderDeckLabel();
        renderPlayerBoard();
        renderBoard();
        renderLog();
      });
    }

    syncSetupCount(state.setupDraft.playerCount);
    if (countSelect) {
      countSelect.value = String(state.setupDraft.playerCount);
      countSelect.addEventListener("change", () => {
        syncSetupCount(Number(countSelect.value));
        renderControls();
      });
    }

    if (addPlayerBtn) {
      addPlayerBtn.addEventListener("click", () => {
        syncSetupCount(state.setupDraft.playerCount + 1);
        renderControls();
      });
    }

    if (removePlayerBtn) {
      removePlayerBtn.addEventListener("click", () => {
        syncSetupCount(state.setupDraft.playerCount - 1);
        renderControls();
      });
    }

    if (randomizeNamesBtn) {
      randomizeNamesBtn.addEventListener("click", () => {
        state.setupDraft.names = randomSetupNames(state.setupDraft.playerCount, state.lang);
        renderControls();
      });
    }

    if (resetSetupBtn) {
      resetSetupBtn.addEventListener("click", () => {
        resetToSetup(true);
      });
    }

    if (reverseBox) {
      reverseBox.checked = state.setupDraft.reversePyramid;
      reverseBox.addEventListener("change", () => {
        state.setupDraft.reversePyramid = reverseBox.checked;
      });
    }

    const startBtn = document.getElementById("startGameBtn");
    applySetupLocale();
    startBtn.addEventListener("click", () => {
      const names = state.setupDraft.names;
      const reverse = state.setupDraft.reversePyramid;
      const lang = document.getElementById("langSelect")?.value || "en";
      startGame(names, reverse, lang);
    });
    return;
  }

  if (state.phase === "warmup") {
    const roundInfo = warmupRoundData(state.warmupRound);
    const player = getCurrentPlayer();
    controls.innerHTML = `
      <div class="controls-head">
        <h2>${roundInfo.title}</h2>
        ${autoPlayControlsHtml()}
      </div>
      <p>${tr("Active player", "Aktiv spiller")}: <strong>${escapeHtml(player.name)}</strong></p>
      <p>${roundInfo.prompt}</p>
    `;
    bindAutoPlayControls();
    return;
  }

  if (state.phase === "pyramid") {
    const nextSlot = state.pyramidRevealIndex < 15 ? pyramidSlotForStep(state.pyramidRevealIndex) : null;
    const nextValue = nextSlot === null ? "-" : pyramidDrinksForIndex(nextSlot);
    controls.innerHTML = `
      <div class="controls-head">
        <h2>${tr("Pyramid", "Pyramide")}</h2>
        ${autoPlayControlsHtml()}
      </div>
      <p>${tr("Click the highlighted next card in the pyramid.", "Klikk det markerte neste kortet i pyramiden.")}</p>
      <p>${tr("Row value now", "Radverdi nå")}: <strong>${nextValue}</strong> ${tr("drink(s) per match.", "slurk(er) per treff.")}</p>
    `;
    bindAutoPlayControls();
    return;
  }

  if (state.phase === "tiebreak") {
    const tie = state.tieBreak;
    controls.innerHTML = `
      <div class="controls-head">
        <h2>${tr("Tie-Break", "Tie-break")}</h2>
        ${autoPlayControlsHtml()}
      </div>
      <p>${tr("Highest card wins. If tied, draw again.", "Høyeste kort vinner. Ved likhet trekkes på nytt.")}</p>
      <p>${tr("Round", "Runde")}: ${tie ? tie.round : "-"}</p>
      <p>${tr("Click the tie deck on the table to deal cards.", "Klikk tie-stokken på bordet for å dele kort.")}</p>
    `;
    bindAutoPlayControls();
    return;
  }

  if (state.phase === "bussetup") {
    const runner = state.players[state.busRunnerIndex];
    controls.innerHTML = `
      <div class="controls-head">
        <h2>${tr("Bus Setup", "Buss-oppsett")}</h2>
        ${autoPlayControlsHtml()}
      </div>
      <p><strong>${escapeHtml(runner.name)}</strong> ${tr("must choose where to start after the 5 cards are dealt.", "må velge hvor ruta skal starte etter at 5 kort er lagt ut.")}</p>
      <div class="btn-row">
        <button id="busStartLeftBtn" class="btn btn-neutral">${tr("Start Left", "Start venstre")}</button>
        <button id="busStartRightBtn" class="btn btn-neutral">${tr("Start Right", "Start høyre")}</button>
      </div>
    `;
    bindAutoPlayControls();
    document.getElementById("busStartLeftBtn")?.addEventListener("click", () => {
      beginBusRoute("left");
      renderAll();
    });
    document.getElementById("busStartRightBtn")?.addEventListener("click", () => {
      beginBusRoute("right");
      renderAll();
    });
    return;
  }

  if (state.phase === "bus") {
    const runner = state.players[state.busRunnerIndex];
    const step = state.busRoute.progress + 1;
    controls.innerHTML = `
      <div class="controls-head">
        <h2>${tr("Bus Route", "Bussrute")}</h2>
        ${autoPlayControlsHtml()}
      </div>
      <p><strong>${escapeHtml(runner.name)}</strong> ${tr(`is on step ${step} of 5.`, `er på steg ${step} av 5.`)}</p>
      <p>${tr("Click above/below on the active stop. Click \"same\" on the card for equal.", "Klikk over/under på aktivt stopp. Klikk \"samme\" på kortet ved likt.")}</p>
    `;
    bindAutoPlayControls();
    return;
  }

  controls.innerHTML = `
    <div class="controls-head">
      <h2>${tr("Game Complete", "Spillet er ferdig")}</h2>
      ${autoPlayControlsHtml()}
    </div>
    <p>${escapeHtml(state.banner)}</p>
    <div class="btn-row">
      <button id="newGameBtn" class="btn btn-primary">${tr("Start new game", "Start nytt spill")}</button>
    </div>
  `;
  bindAutoPlayControls();
  document.getElementById("newGameBtn").addEventListener("click", () => resetToSetup(false));
}
function renderBoard() {
  board.classList.toggle("setup-scroll", state.phase === "setup");

  if (state.phase === "setup") {
    board.innerHTML = `
      <h2>${tr("How this version plays", "Slik spilles denne versjonen")}</h2>
      <p>${tr("1. Four warmup rounds build each hand.", "1. Fire oppvarmingsrunder bygger hver hånd.")}</p>
      <p>${tr("2. Pyramid cards are clicked directly on the board.", "2. Pyramidkort klikkes direkte på bordet.")}</p>
      <p>${tr("3. Player with most cards left takes bus route (ties use highest-card draw).", "3. Spilleren med flest kort igjen tar bussruta (likt avgjøres med høyeste kort).")}</p>
      <p>${tr("4. Bus route guesses happen directly above/below the active card.", "4. I bussruta gjettes det direkte over/under aktivt kort.")}</p>
    `;
    return;
  }

  const resultClass = [
    "result-banner",
    state.bannerTone ? `tone-${state.bannerTone}` : "",
    (state.phase === "warmup" || state.phase === "pyramid") ? "major" : ""
  ]
    .filter(Boolean)
    .join(" ");

  board.innerHTML = `
    <div class="table-stage">
      ${renderRoundTable()}
      ${state.banner ? `<div class="${resultClass}">${escapeHtml(state.banner)}</div>` : ""}
    </div>
  `;

  bindBoardInteractions();
}

function renderRoundTable() {
  const showSeats = state.phase === "warmup" || state.phase === "pyramid";
  return `
    <div class="round-table-wrap">
      <div class="round-table">
        <div class="table-felt"></div>
        ${showSeats ? `<div class="seat-layer">${renderSeatsAroundTable()}</div>` : ""}
        ${state.phase === "warmup" ? renderWarmupDeckArea() : ""}
        ${state.phase === "pyramid" ? renderPyramidOverlay() : ""}
        ${state.phase === "tiebreak" ? renderTieBreakOverlay() : ""}
        ${(state.phase === "bussetup" || state.phase === "bus" || state.phase === "finished") ? renderBusOverlay() : ""}
        ${state.phase === "finished" ? renderCelebrationOverlay() : ""}
      </div>
    </div>
  `;
}

function renderCelebrationOverlay() {
  const bus = state.busRoute;
  const runner = state.players[state.busRunnerIndex];
  const safeName = runner ? escapeHtml(runner.name) : "";
  const firstTry = Boolean(bus && bus.firstTry);
  const headline = firstTry
    ? tr("FIRST TRY!", "FØRSTE FORSØK!")
    : tr("BUS ROUTE COMPLETE!", "BUSSRUTA FULLFØRT!");
  const subline = firstTry
    ? tr(`${safeName} did it first attempt. Everyone else drinks!`, `${safeName} klarte det på første forsøk. Alle andre drikker!`)
    : tr(`${safeName} completed the route.`, `${safeName} fullførte ruta.`);
  const confetti = Array.from({ length: 28 }, (_, i) => `<span class="confetti-piece" style="--piece:${i};"></span>`).join("");

  return `
    <div class="celebration-overlay ${firstTry ? "first-try" : ""}">
      <div class="celebration-burst">${confetti}</div>
      <div class="celebration-card">
        <h3>${headline}</h3>
        <p>${subline}</p>
      </div>
    </div>
  `;
}

function renderSeatsAroundTable() {
  if (state.players.length === 0) return "";
  const compactSeats = state.players.length >= 8;

  return state.players
    .map((player, idx) => {
      const pos = seatPosition(idx, state.players.length, state.phase);
      const isWarmupActive = state.phase === "warmup" && idx === state.currentPlayerIndex;
      const isBusRunner = (state.phase === "bus" || state.phase === "finished") && idx === state.busRunnerIndex;
      const isPyramidWinner = state.phase === "pyramid" && state.pyramidHighlightPlayers.includes(idx);
      const isEmpty = player.hand.length === 0;

      const handSize = seatHandSize();
      const handCards = player.hand.length > 0
        ? player.hand.map((card) => cardHtml(card, { size: handSize })).join("")
        : `<span class="seat-empty">${tr("No cards", "Ingen kort")}</span>`;

      return `
        <div class="table-seat ${isWarmupActive ? "active-turn" : ""} ${isBusRunner ? "bus-runner" : ""} ${isPyramidWinner ? "pyramid-winner" : ""} ${state.phase === "pyramid" ? "pyramid-side-seat" : ""}" style="left:${pos.x}%;top:${pos.y}%" data-seat-index="${idx}">
          <div class="seat-chip ${compactSeats ? "compact" : ""} ${state.phase === "pyramid" ? "pyramid-side" : ""} ${isEmpty ? "empty-hand" : ""}">
            <div class="seat-name">${escapeHtml(player.name)}</div>
            <div class="seat-count">${player.hand.length} ${tr("cards", "kort")}</div>
            <div class="seat-anchor">${handCards}</div>
          </div>
        </div>
      `;
    })
    .join("");
}

function seatHandSize() {
  return "sm";
}

function seatPosition(index, total, phase = "warmup") {
  if (phase === "pyramid") {
    const leftCount = Math.ceil(total / 2);
    const isLeft = index < leftCount;
    const sideIndex = isLeft ? index : index - leftCount;
    const sideTotal = isLeft ? leftCount : total - leftCount;
    const y = sideTotal <= 1 ? 50 : 16 + (sideIndex * 68) / (sideTotal - 1);
    const x = isLeft ? 15 : 85;
    return { x, y };
  }

  const angleStep = 360 / total;
  const baseAngle = -90;
  const angle = (baseAngle + angleStep * index) * (Math.PI / 180);

  let radiusX = 37;
  let radiusY = 39;
  if (total <= 3) {
    radiusX = 34;
    radiusY = 37;
  }
  if (total === 4) {
    radiusX = 36;
    radiusY = 38;
  }
  if (total >= 5 && total <= 6) {
    radiusX = 37;
    radiusY = 38;
  }
  if (total >= 7 && total <= 8) {
    radiusX = 36;
    radiusY = 36;
  }
  if (total >= 9) {
    radiusX = 34;
    radiusY = 34;
  }

  const x = 50 + Math.cos(angle) * radiusX;
  const y = 50 + Math.sin(angle) * radiusY;
  return { x, y };
}

function renderWarmupDeckArea() {
  const round = warmupRoundData(state.warmupRound);
  const enabled = !state.animating;
  return `
    <div class="deck-wrap">
      <button id="deckStack" class="deck-stack visual-only ${enabled ? "ready" : "idle"}" disabled>
        <span class="deck-face">${tr("DEAL", "TREKK")}</span>
      </button>
      <div class="deck-guess-row">
        ${round.options
          .map((option) => `
            <button
              class="deck-guess-btn ${state.pendingWarmupGuess === option.key ? "selected" : ""}"
              data-warmup-guess="${option.key}"
              ${enabled ? "" : "disabled"}
            >${option.label}</button>
          `)
          .join("")}
      </div>
    </div>
  `;
}

function renderPyramidOverlay() {
  const nextSlot = state.pyramidRevealIndex < 15 ? pyramidSlotForStep(state.pyramidRevealIndex) : -1;
  return `
    <div class="pyramid-overlay">
      ${PYRAMID_ROWS.map((row) => `
        <div class="pyramid-row">
          ${row
            .map((idx) => {
              const card = state.pyramidCards[idx];
              const clickable = idx === nextSlot && !state.animating;
              return `
                <button
                  class="pyramid-slot ${clickable ? "clickable next-turn" : ""}"
                  data-pyramid-slot="${idx}"
                  ${clickable ? `data-pyramid-click="${idx}"` : ""}
                  ${clickable ? "" : "disabled"}
                >
                  ${card ? cardHtml(card, { size: "sm" }) : cardHtml(null, { size: "sm", back: true })}
                </button>
              `;
            })
            .join("")}
        </div>
      `).join("")}
    </div>
  `;
}

function renderTieBreakOverlay() {
  const tie = state.tieBreak;
  if (!tie) return "";

  return `
    <div class="tie-overlay">
      <div class="tie-deck-wrap">
        <button id="tieDeckStack" class="deck-stack ${state.animating ? "idle" : "ready"}" data-tie-draw="1" ${state.animating ? "disabled" : ""}>
          <span class="deck-face">${tr("TIE", "TIE")}</span>
        </button>
        <div class="deck-tip">${tr("Click deck to draw", "Klikk stokken for trekk")}</div>
      </div>
      <div class="tie-contenders">
        ${tie.contenders.map((idx) => {
          const drawn = tie.lastDraws.find((entry) => entry.idx === idx);
          return `
            <div class="tie-player">
              <div class="tie-name">${escapeHtml(state.players[idx].name)}</div>
              <div class="tie-slot" data-tie-slot="${idx}">
                ${drawn ? cardHtml(drawn.card, { size: "md" }) : cardHtml(null, { size: "md", back: true })}
              </div>
            </div>
          `;
        }).join("")}
      </div>
    </div>
  `;
}

function renderBusZoneStack(cards, size, stackClass = "") {
  if (!cards || cards.length === 0) return "";
  const visible = cards.slice(-6);
  return `
    <div class="bus-stack ${stackClass}">
      ${visible
        .map((entry, idx) => {
          const stackEntry = entry && entry.card
            ? entry
            : { id: "", card: entry, offsetX: 0, offsetY: 0, rotate: "0.0" };
          return `
          <div class="bus-stack-card" data-stack-card-id="${escapeHtml(stackEntry.id || "")}" style="--stack-index:${idx};--offset-x:${stackEntry.offsetX}px;--offset-y:${stackEntry.offsetY}px;--rot:${stackEntry.rotate}deg;">
            ${cardHtml(stackEntry.card, { size })}
          </div>
        `;
        })
        .join("")}
    </div>
  `;
}

function renderBusOverlay() {
  const bus = state.busRoute;
  if (!bus) return "";
  const activeIndex = bus.order?.[bus.progress] ?? bus.progress;

  return `
    <div class="bus-overlay">
      <div class="bus-deck-wrap">
        <button id="busDeckStack" class="deck-stack ${state.phase === "bus" && !state.animating ? "ready" : "idle"}" disabled>
          <span class="deck-face">${tr("DEAL", "TREKK")}</span>
        </button>
        <div class="deck-count">${tr("Cards left", "Kort igjen")}: ${bus.deck.length}</div>
        <div class="deck-tip">${tr("Guess by clicking above/below card", "Gjett ved å klikke over/under kortet")}</div>
      </div>
      <div class="bus-lane">
        ${bus.routeCards
          .map((routeCard, idx) => {
            const lane = bus.overlays[idx] || { high: [], low: [], same: [] };
            const tone = bus.zoneTone[idx] || { high: "", low: "", same: "" };
            const active = idx === activeIndex && state.phase === "bus" && !state.animating;

            return `
              <div class="bus-stop ${idx === activeIndex && state.phase === "bus" ? "active" : ""}">
                <div
                  class="bus-zone ${active ? "guess-target" : "inactive-zone"} ${tone.high ? `tone-${tone.high}` : ""}"
                  data-bus-zone="${idx}-high"
                  ${active ? `data-bus-guess="over" data-bus-step="${idx}"` : ""}
                >
                  ${active ? `<span class="bus-zone-label">${tr("above", "over")}</span>` : ""}
                  ${renderBusZoneStack(lane.high, "sm")}
                </div>
                <div class="bus-base ${tone.same ? `tone-${tone.same}` : ""} ${active ? "next-guess" : ""}" data-bus-zone="${idx}-same">
                  ${cardHtml(routeCard, { size: "md", extraClass: "bus-route-card" })}
                  <div class="bus-same-overlay">
                    ${renderBusZoneStack(lane.same, "xs", "same")}
                  </div>
                  ${active ? `<button class="bus-same-btn" data-bus-guess="samme" data-bus-step="${idx}">${tr("same", "samme")}</button>` : ""}
                </div>
                <div
                  class="bus-zone ${active ? "guess-target" : "inactive-zone"} ${tone.low ? `tone-${tone.low}` : ""}"
                  data-bus-zone="${idx}-low"
                  ${active ? `data-bus-guess="under" data-bus-step="${idx}"` : ""}
                >
                  ${active ? `<span class="bus-zone-label">${tr("below", "under")}</span>` : ""}
                  ${renderBusZoneStack(lane.low, "sm")}
                </div>
              </div>
            `;
          })
          .join("")}
      </div>
    </div>
  `;
}
function bindBoardInteractions() {
  if (state.phase === "warmup") {
    board.querySelectorAll("[data-warmup-guess]").forEach((button) => {
      button.addEventListener("click", () => {
        void playWarmupGuess(button.dataset.warmupGuess);
      });
    });
    return;
  }

  if (state.phase === "pyramid") {
    board.querySelectorAll("[data-pyramid-click]").forEach((slot) => {
      slot.addEventListener("click", () => {
        const idx = Number(slot.dataset.pyramidClick);
        void revealPyramidSlot(idx);
      });
    });
    return;
  }

  if (state.phase === "tiebreak") {
    const tieDeck = board.querySelector("[data-tie-draw]");
    if (tieDeck) {
      tieDeck.addEventListener("click", () => {
        void runTieBreakRound();
      });
    }
    return;
  }

  if (state.phase === "bus") {
    board.querySelectorAll("[data-bus-guess]").forEach((target) => {
      target.addEventListener("click", () => {
        const guess = target.dataset.busGuess;
        const step = Number(target.dataset.busStep);
        void playBusGuess(guess, step);
      });
    });
  }
}

function renderLog() {
  if (state.log.length === 0) {
    logEl.innerHTML = `<div class="log-entry">${tr("No events yet.", "Ingen hendelser ennå.")}</div>`;
    return;
  }

  logEl.innerHTML = state.log
    .map((entry) => `<div class="log-entry">${escapeHtml(entry)}</div>`)
    .join("");
}

async function animateCardFlight({ fromEl, toEl, card, back = false, duration = 560 }) {
  if (!fromEl || !toEl) {
    return;
  }

  const fromRect = fromEl.getBoundingClientRect();
  const toRect = toEl.getBoundingClientRect();

  const flyer = buildCardNode(card, { size: "md", back });
  flyer.classList.add("flying-card");
  document.body.appendChild(flyer);

  const flyerRect = flyer.getBoundingClientRect();
  const startLeft = fromRect.left + fromRect.width / 2 - flyerRect.width / 2;
  const startTop = fromRect.top + fromRect.height / 2 - flyerRect.height / 2;
  const endLeft = toRect.left + toRect.width / 2 - flyerRect.width / 2;
  const endTop = toRect.top + toRect.height / 2 - flyerRect.height / 2;

  flyer.style.left = `${startLeft}px`;
  flyer.style.top = `${startTop}px`;

  const dx = endLeft - startLeft;
  const dy = endTop - startTop;
  const distance = Math.hypot(dx, dy);
  const arcLift = clamp(Math.round(distance * 0.19), 42, 148);
  const drift = (Math.random() * 8) - 4;
  const spin = clamp(dx * 0.035, -11, 11);
  const durationScale = clamp(0.98 + (distance / 1750), 0.98, 1.22);
  const settleX = dx === 0 ? 0 : Math.sign(dx) * clamp(Math.abs(dx) * 0.016, 1.2, 4.2);
  const settleY = dy === 0 ? 0 : Math.sign(dy) * clamp(Math.abs(dy) * 0.012, 0.8, 3.2);
  const startTilt = (-6 + spin).toFixed(2);
  const midTilt = (spin * 0.5).toFixed(2);
  const endTilt = (spin * 0.22).toFixed(2);

  const animation = flyer.animate(
    [
      {
        offset: 0,
        transform: `translate(0px, 0px) rotate(${startTilt}deg) scale(0.985)`,
        opacity: 0.96
      },
      {
        offset: 0.12,
        transform: `translate(${(dx * 0.08 + drift * 0.25).toFixed(2)}px, ${(dy * 0.08 - arcLift * 0.28).toFixed(2)}px) rotate(${(spin * 0.65).toFixed(2)}deg) scale(1)`,
        opacity: 0.99
      },
      {
        offset: 0.52,
        transform: `translate(${(dx * 0.4 + drift).toFixed(2)}px, ${(dy * 0.28 - arcLift).toFixed(2)}px) rotate(${midTilt}deg) scale(1.02)`,
        opacity: 1
      },
      {
        offset: 0.82,
        transform: `translate(${(dx * 0.9).toFixed(2)}px, ${(dy * 0.9 - arcLift * 0.12).toFixed(2)}px) rotate(${(spin * 0.32).toFixed(2)}deg) scale(1)`,
        opacity: 1
      },
      {
        offset: 0.93,
        transform: `translate(${(dx + settleX).toFixed(2)}px, ${(dy + settleY).toFixed(2)}px) rotate(${(spin * 0.16).toFixed(2)}deg) scale(0.996)`,
        opacity: 1
      },
      {
        offset: 1,
        transform: `translate(${dx.toFixed(2)}px, ${dy.toFixed(2)}px) rotate(${endTilt}deg) scale(1)`,
        opacity: 1
      }
    ],
    {
      duration: Math.round(duration * animationScale() * durationScale),
      easing: "cubic-bezier(.22,.74,.24,1)",
      fill: "forwards"
    }
  );

  try {
    await animation.finished;
  } catch {
    // Ignore canceled animation.
  }

  flyer.remove();
}

function pulseElement(element, tone, strength = "normal") {
  return new Promise((resolve) => {
    if (!element) {
      resolve();
      return;
    }

    const className = tone === "success"
      ? (strength === "soft" ? "feedback-success-soft" : "feedback-success")
      : (strength === "soft" ? "feedback-fail-soft" : "feedback-fail");
    element.classList.remove("feedback-success", "feedback-fail", "feedback-success-soft", "feedback-fail-soft");
    void element.offsetWidth;
    element.classList.add(className);

    const baseMs = strength === "soft" ? 620 : 900;
    const pulseMs = Math.round(baseMs * animationScale());

    window.setTimeout(() => {
      element.classList.remove(className);
      resolve();
    }, pulseMs);
  });
}

function escapeHtml(text) {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}


