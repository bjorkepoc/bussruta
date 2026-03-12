# Bussruta Web App

Web version of the Bussruta card game, based on the rules and flow in `bæsso.py`.

## Run locally

Open `index.html` directly in a browser, or serve the folder with any static server.

Example (Python):

```bash
python -m http.server 8000
```

Then open `http://localhost:8000`.

## Game flow implemented

1. Four warmup rounds:
- Round 1: black/red
- Round 2: higher/lower/same
- Round 3: between/outside/same
- Round 4: suit guess

2. Language mode:
- Setup includes language choice: English or Norwegian
- The UI and game messages are shown in the selected language

3. Real-table style UI:
- Players are positioned around a round table
- Cards are dealt with animation
- Warmup guesses are selected under the center deck
- Clicking a warmup guess deals immediately (no extra deck click)
- Active warmup player hand has stronger visual highlight

4. Pyramid of 15 cards:
- Cards are revealed one at a time
- The next card is revealed by clicking the highlighted face-down pyramid card
- Matching ranks are removed from player hands
- Drink value is based on pyramid height
- Optional reversed scoring (bottom=5, top=1)

5. Bus route candidate:
- Player with most cards left goes to bus route
- If tied, tied players enter an animated high-card tie-break
- Tie-break cards are drawn by clicking the tie deck on the board

6. Bus route:
- Five route cards are shown on the board with a deck beside them
- Guess directly on each active checkpoint (click above/below/same)
- Above/below zones are only shown as active targets on the current checkpoint
- Zones flash and tint green/red for result
- Wrong guess resets route (or same-step penalty on equal card after step 1)
- On restart, previous checkpoint colors clear while the failed checkpoint stays visible
- Drawn bus cards animate to high/low/same positions and stay stacked on the board
- Correct outcomes vibrate green, wrong outcomes vibrate red
- Must complete all 5 in one run to finish
- If finished on first try, log states that everyone else finishes drinks

7. Auto play mode:
- Small Auto Play toggle is shown beside the phase title
- Advanced settings are in an `Options` dropdown beside the phase title
- Uses probability-based decisions for guesses
- Pace presets include 0.8s, 1.5s, 5s, 10s, 30s, and 60s
- Auto play pauses when bus route starts; press Auto Play again to automate that phase
- Includes motion and effects controls

8. Setup flow:
- Choose player count directly (1-9)
- Add/remove player buttons
- Optional `Randomize` button generates random player names
- Duplicate names are auto-numbered instead of blocking game start

## UI tweaks included

- Larger cards and table-focused board
- Scrollable game log panel
- Horizontal player hand rendering (no vertical stack)
- Dynamic seat/card scaling for larger player counts
- Bus route view hides player hands to keep focus on route cards
- End-of-game celebration overlay with confetti, stronger on first-try completion
