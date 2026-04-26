# League of Nations — Civ 6 World Congress Mod

**Design Doc & Coding Standards (v0 handoff for Claude Code)**

---

## 1. Mission

Rework Civ 6's World Congress so it feels like Civ 5: Brave New World — a political arena where players have real agency, not a random event with sliders. The driving philosophy is **player agency**. Every design decision should be evaluated against: "does this give the player more meaningful control over diplomacy?"

## 2. Scope

**In scope:** World Congress flow, resolution proposal, voting, bribery/negotiation, delegate accounting, Favor accounting, repeal mechanic, Special Sessions, and the Congress UI screen(s).

**Out of scope (v1):** New civs/leaders/units/buildings, balance changes outside the Congress, multiplayer hardening, art assets beyond placeholders, and World Leader election (we are explicitly *not* changing the existing GS Diplomatic Victory — DVPs and the accumulation threshold stay as-is).

## 3. Target environment

- Civ 6 with **all DLC**, including both expansions (Rise and Fall, Gathering Storm) and the New Frontier Pass
- **Not** vanilla-compatible — the World Congress only exists in GS
- Steam Workshop release
- Plays nicely with popular mods (CQUI, Better Report Screen, etc.) where feasible — secondary priority

## 4. Implementation strategy: Path B + Path C elements

This is the most important architectural decision in the doc. Read it carefully.

Civ 6's engine is closed-source (no DLL access). The Congress flow — when sessions trigger, the A/B/Target structure, the resolution-generation algorithm, AI voting, and the deal screen's allowed items — is **hardcoded in the compiled engine**. We cannot change those directly.

Three modding paths exist:
- **Path A** (heavy tweak): keep Civ 6 flow, change resolution data only. Ships fast, low agency.
- **Path B** (hybrid): keep Civ 6 flow as skeleton, layer Civ 5 mechanics on top via data + Lua + custom UI panels.
- **Path C** (full replacement): suppress engine's Congress, rebuild in Lua/UI. Months of work; AI and multiplayer become hard.

**This mod is Path B with Path C elements where tractable.** The skeleton (session trigger, vote tally, A/B per resolution) stays. We add:
- Player proposal layer (Path C-style — Lua picks resolutions instead of letting the engine roll randomly, where hooks allow)
- Custom Vote Negotiation panel (Path C — custom UI flow)
- Permanent-until-repealed resolution tracking (Path C — Lua-tracked state outside the engine's 30-turn expiry)
- Delegates as a parallel currency (Path C — entirely Lua-modeled)
- Founding gate based on Printing Press + meeting all civs (Path B — overrides `WORLD_CONGRESS_INITIAL_ERA` plus Lua gating)

**Friction we accept:** The engine's AI voting logic is a black box. We will fake AI proposal selection and bribery responses in Lua using leader agenda flavors. AI behavior will be "good enough for v1, refinable later."

## 5. Core mechanics

### 5.1 Founding
- Disable Civ 6's Medieval-era auto-start (set `WORLD_CONGRESS_INITIAL_ERA` very high in `Expansion2_GlobalParameters` to suppress)
- Custom Lua condition: Congress founds when **any civ has researched Printing Press AND has met all other civs in the game**
- That civ becomes the first **Host**
- If no civ qualifies by Industrial era, fall back to "first civ to enter Industrial era founds the Congress" (prevents soft-locks on map types where civs never meet)

### 5.2 Delegates and Favor
Two parallel currencies, distinct purposes:

**Delegates** — your standing vote count, granted passively:
- Base "membership" delegates: 1, scaling with era (1/2/3/4/5 across Medieval → Information)
- Host bonus: +2 delegates while Host
- City-state allies (Suzerain): +1 delegate per city-state where you're suzerain (kicks in Industrial era, mirroring Civ 5)
- Future hooks for wonders/policies/governments to grant additional delegates (data-driven, easy to extend)

**Favor** — spendable, flexible:
- Earned as in vanilla GS (governments, alliances, city-state interactions, etc.)
- Spent on: extra votes for a single session, bribing other civs (see 5.4), calling Special Sessions, proposing repeals

Rule of thumb: **delegates = standing power; favor = leverage.**

### 5.3 Sessions and proposals
- Cadence follows Civ 5: every ~20–30 turns (standard speed), frequency increases in later eras (handled in Lua)
- Each session, **two civs propose**: the Host (always) and the civ with the next-highest delegate count (ties broken in favor of human, then by `PlayerID`)
- Proposing civs select their resolution from the era-appropriate eligible pool via a custom UI
- Existing GS resolutions (Border Control, World Religion, Climate Accords, Urban Development Treaty, etc.) are reused as the proposal pool — we are **not** writing brand-new resolutions for v1
- The A/B Outcome + Target structure stays (engine-hardcoded; the proposing civ implicitly endorses one option, which seeds AI default voting)

### 5.4 Vote Negotiation (bribery)
We cannot add a new tradeable item to the deal screen — the deal system's item types are hardcoded.

Instead, build a **dedicated Vote Negotiation panel** that opens before each Congress session resolves:
- Player selects a target civ
- Player offers Favor, Gold, or strategic/luxury resources
- Player requests vote commitment for a specific outcome on a specific proposal
- AI evaluates based on: relationship status, leader agenda flavor toward the proposal subject, perceived value of the offer vs. the player's offer history
- If accepted, the AI civ commits its delegates to the requested outcome at vote time (tracked in Lua — the engine's vote tally still runs, but our Lua adjusts the AI civ's chosen outcome before the engine reads it)
- Other civs can witness and react diplomatically (positive/negative modifiers for visible vote-buying)

### 5.5 Permanent resolutions and repeal
- When a resolution passes, it becomes **permanent until repealed** (overriding the engine's 30-turn auto-expiry by re-applying the modifier each session via Lua)
- Any civ may use their proposal slot to propose a **repeal** of any active resolution
- Repeal proposals follow the same vote rules: >50% of delegate-equivalent votes to pass
- Repealed resolutions remove all their modifiers and become eligible for re-proposal

### 5.6 Special Sessions
- Existing emergency triggers (natural disasters, aggressive moves) keep working
- **New:** any civ may **call a Special Session** by spending Favor (suggested cost: 30 Favor, matching vanilla, but tunable in `GlobalParameters`)
- Player-called Special Sessions allow proposing one resolution outside the normal cadence

### 5.7 What stays unchanged from GS
- Diplomatic Favor as a currency
- Diplomatic Victory Points and the existing DVP-accumulation victory threshold
- Emergency types and their triggers (we add a manual trigger; we don't remove the auto ones)
- Scored Competitions (World Games, Aid Request, etc.)
- A/B Outcome + Target structure for individual resolutions

## 6. UI

- **Replace** the Congress voting screen with a custom screen that supports the Civ 5-style flow: propose phase → negotiate phase → vote phase
- **Reuse** existing UI elements (resolution cards, civ portraits, etc.) where they fit
- New panels needed:
  - Proposal Selection panel (for the two proposing civs)
  - Vote Negotiation panel (bribery)
  - Repeal Proposal panel
  - Active Resolutions panel (lists permanent resolutions currently in effect)
- Notifications: add custom notifications for "You may propose a resolution," "Vote Negotiation available," "Resolution X has been repealed"

## 7. AI behavior (v1: agenda-based)

- AI proposal selection: weight era-appropriate resolutions by leader agenda flavor and current strategic state (at war? going for science? religious?)
- AI voting: existing engine logic stays as the floor. Our Lua layer adjusts when:
  - A bribe was accepted (forces a specific vote)
  - A leader has a strong agenda-driven preference (we override the engine's default favor-spend)
- AI bribery responsiveness: simple model — accept if (offer value × relationship modifier) > (own preference strength × 1.5). Tunable constants in a single Lua config file.

Not in scope for v1: AI counter-bribery, AI strategic long-term planning around the Congress, AI calling Special Sessions.

## 8. Coding standards

### 8.1 Mod identity
- **Display name:** League of Nations
- **Mod ID prefix:** `LON_`
- **All custom database entries, Lua globals, UI elements, localization keys use this prefix** — e.g., `LON_RESOLUTION_REPEAL`, `LON_NotifyHostChanged`, `LOC_LON_PROPOSAL_PANEL_TITLE`
- This avoids collisions with base game and other mods

### 8.2 Folder structure
```
LeagueOfNations/
├── LeagueOfNations.modinfo          # entry point
├── Data/                              # SQL/XML database changes
│   ├── Config.sql                     # global parameters, era cadence
│   ├── Resolutions.sql                # resolution data tweaks
│   └── Modifiers.sql                  # modifier definitions for permanent effects
├── Lua/                               # gameplay scripts
│   ├── LON_Core.lua                   # init, save/load hooks, shared state
│   ├── LON_Founding.lua               # Printing Press + meet-all-civs gate
│   ├── LON_Delegates.lua              # delegate accounting
│   ├── LON_Proposals.lua              # who proposes, what's eligible
│   ├── LON_Negotiation.lua            # bribery logic and AI evaluation
│   ├── LON_Repeal.lua                 # repeal tracking and effects
│   ├── LON_Permanence.lua             # re-applies modifiers each session
│   ├── LON_AI.lua                     # AI proposal/vote/bribery overrides
│   └── LON_Config.lua                 # tunable constants in one place
├── UI/                                # custom screens and panels
│   ├── LON_CongressScreen.xml
│   ├── LON_CongressScreen.lua
│   ├── LON_ProposalPanel.xml
│   ├── LON_ProposalPanel.lua
│   ├── LON_NegotiationPanel.xml
│   ├── LON_NegotiationPanel.lua
│   └── LON_ActiveResolutions.xml
├── Text/                              # localization
│   └── en_US.xml                      # all `LOC_LON_*` strings
└── README.md                          # workshop description source
```

### 8.3 Database changes: prefer SQL over XML
SQL is more readable in diffs, more powerful for conditional updates, and easier to maintain. Reserve XML for the modinfo file and any cases where the base game pattern is XML-only (e.g., modinfo `<ActionCriteria>` blocks).

### 8.4 Lua style
- One concern per file (see folder structure above)
- All public functions namespaced under a single global table per file: `LON_Delegates.GetDelegateCount(playerID)` rather than free-floating `GetDelegateCount`
- Use `local` for everything that doesn't need to be exported
- Prefix internal helpers with `_`: `LON_Delegates._calculateCityStateBonus(playerID)`
- All tunable numbers live in `LON_Config.lua`, not scattered through logic files
- Logging: use a wrapper `LON_Log(level, message)` defined in `LON_Core.lua`. Levels: `DEBUG`, `INFO`, `WARN`, `ERROR`. Default to `INFO` in releases, `DEBUG` while developing. No bare `print()` calls.
- Wrap engine API calls in `pcall` where failure shouldn't crash the session (especially anything that touches `Game.GetWorldCongress()` or related calls — these have known edge cases)
- Save/load: any custom state must be serialized via `GameConfiguration` or a save-hooked Lua table. Document each persisted key in `LON_Core.lua`.

### 8.5 Localization
- English-only (`en_US.xml`) for v1
- Every player-visible string is a `LOC_LON_*` key, never a hardcoded literal
- Stub other locale files (`de_DE.xml`, `fr_FR.xml`, etc.) as empty placeholders so future contributors can fill them without restructuring

### 8.6 Versioning
- Semver: `MAJOR.MINOR.PATCH`
- Version lives in two places (kept in sync): `<Version>` in modinfo, top-of-file comment in `LON_Core.lua`
- `CHANGELOG.md` at root, newest entries on top
- v0.1.0 = first playable build (founding + basic propose-and-vote loop)
- v1.0.0 = feature-complete: all core mechanics in section 5 working

### 8.7 Comments and docs
- Every Lua file: header comment with purpose, dependencies, and persisted state keys
- Every public function: one-line comment describing inputs, outputs, side effects
- Inline comments explain *why*, not *what* — assume the reader can read Lua

## 9. Testing

- Manual playthroughs are the primary validation
- Use FireTuner console for state inspection (`Game.GetWorldCongress()`, custom debug commands prefixed `con_debug_*`)
- Test matrix for v1:
  - Standard speed, Continents, 8 civs — full game from Ancient to Modern
  - Online speed, Pangaea, 4 civs — fast iteration
  - One game where Printing Press is researched late (Industrial fallback path)
  - One game where two civs are perma-isolated (founding edge case)
- Multiplayer: not actively tested in v1, but avoid known MP-breakers (e.g., random number generation outside the synced RNG)

## 10. Build order (suggested priority)

Claude Code should treat this as the recommended sprint order for v1. Each milestone is a playable, testable build.

1. **M1 — Skeleton.** Modinfo loads cleanly. Founding gate works (Printing Press + meet-all-civs). Existing Congress is suppressed. A placeholder notification fires when the Congress would have founded. *Goal: prove the mod loads and the engine's Congress can be controlled.*

2. **M2 — Delegate accounting.** Delegates tracked per civ. Simple debug UI shows current counts. Host concept exists; host gets bonus delegates. *Goal: Civ 5-style standing-power model is in place.*

3. **M3 — Proposal flow.** Custom Proposal Selection panel appears for the two proposing civs. They pick from era-appropriate resolutions. Existing engine voting still runs. *Goal: player agency over what gets proposed.*

4. **M4 — Permanent + repeal.** Resolutions persist past 30 turns. Repeal proposals work. Active Resolutions panel shows current state. *Goal: Civ 5 permanence model.*

5. **M5 — Vote Negotiation.** Bribery panel works. AI evaluates offers. Bribed votes are honored. *Goal: the agency centerpiece — direct deal-making.*

6. **M6 — Special Sessions.** Player can call Special Sessions with Favor. *Goal: complete the agency story.*

7. **M7 — Polish.** AI tuning, edge cases, localization sweep, mod compatibility checks, balance pass.

## 11. Known risks and unknowns

These are areas Claude Code should flag if they turn out to be blockers:

- **AI voting override reliability.** If the engine commits AI votes before our Lua layer can intercept, bribery becomes cosmetic. May need to inject overrides earlier in the turn cycle than expected.
- **Permanent modifier stacking.** Re-applying modifiers each session must not accumulate (e.g., +1 production, +2, +3...). Need a clean apply/remove cycle keyed on resolution ID.
- **Save/load fidelity.** Custom state (active resolutions, delegate counts, host identity) must survive save/load. This is historically a fragile area in Civ 6 modding.
- **Mod conflicts.** Anything else that touches `WORLD_CONGRESS_INITIAL_ERA` or the Congress UI will collide. Document conflicts as discovered.
- **Civ 6's hardcoded A/B/Target structure** may force compromises on resolution wording. Acceptable.

## 12. Definition of done for v1

- All M1–M6 milestones shipped and stable
- A full game (standard speed, 8 civs, Continents) can be played from start to victory without Congress-related crashes
- Player can: propose a resolution, get bribed for a vote, bribe another civ, propose a repeal, call a Special Session, win a Diplomatic Victory
- AI does all of the above too (with v1-acceptable strategy)
- Workshop page draft exists with screenshots and known limitations listed
