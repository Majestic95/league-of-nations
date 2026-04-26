# CLAUDE.md — League of Nations

Project context for Claude Code and human contributors. Read this fully before making changes.

## Mission

Rework Civ 6's World Congress to feel like Civ 5: Brave New World — a political arena with real player agency, not a random event with sliders. Every design decision is evaluated against: **does this give the player more meaningful control over diplomacy?**

Source-of-truth design spec: [docs/league_of_nations_design.md](docs/league_of_nations_design.md). When this CLAUDE.md and the design doc disagree, CLAUDE.md wins (it tracks more recent decisions).

## Quick start

```bash
# Clone
git clone https://github.com/Majestic95/league-of-nations.git
cd league-of-nations

# Symlink into Civ 6 Mods folder (Windows, run as admin or with developer mode)
mklink /D "%USERPROFILE%\Documents\My Games\Sid Meier's Civilization VI\Mods\LeagueOfNations" "%CD%"

# Enable mod from in-game Additional Content menu, then restart Civ 6 after edits.
```

There is no hot-reload — restart the game (or at least the session) after any change.

## Architecture: Path B + Path C elements

Civ 6's engine is closed (no DLL). The Congress flow — session trigger, A/B/Target structure, vote tally, AI voting, deal screen item types — is hardcoded.

- **Skeleton stays:** session trigger, A/B + Target structure, base vote tally, base resolution data.
- **Agency layer is Lua + custom UI:** proposal selection, bribery panel, repeal tracking, permanent-until-repealed re-application, delegate currency, founding gate.
- **AI is the soft spot.** Engine AI voting is a black box. We override via Lua keyed on agendas + accepted bribes. v1 is "good enough, refinable later."

Default to **layering on top of engine flow**, not replacing it. Replacements are expensive and break compatibility with future patches and other mods.

## Hard rules (review-blockers)

Violations block PR merge. No exceptions without a documented reason in the PR description.

### Multiplayer is first-class
This mod must work in MP. Therefore:
- **Never use `math.random()`.** Use `Game.GetRandNum(...)` (synced RNG). Bare `math.random` desyncs clients.
- **No client-only mutable state.** All custom state persists via `GameConfiguration` or save-hooked tables. Document every persisted key in `LON_Core.lua`'s registry.
- **UI panels are views.** They render host-authoritative state and emit intent events. They do not mutate game state directly.
- **Human-targeted bribery uses notification → accept/decline.** The recipient must explicitly accept on their own client.
- **Every milestone is tested in 2-player MP** before being declared done. Save → exit → reload → reconnect must round-trip.

### Mod identity prefix
- Prefix `LON_` on **everything** custom: SQL identifiers, Lua globals, UI element IDs, localization keys, custom file names.
- Examples: `LON_RESOLUTION_REPEAL`, `LON_NotifyHostChanged`, `LOC_LON_PROPOSAL_PANEL_TITLE`, `LON_Delegates.lua`.
- Avoids collisions with the base game and other mods. Non-negotiable.

### No bare `print()`
- All logging goes through `LON_Log(level, message)` from `LON_Core.lua`. Levels: `DEBUG`, `INFO`, `WARN`, `ERROR`.
- Default release log level: `INFO`. Bump to `DEBUG` during development by editing one constant in `LON_Core.lua`.

### No hardcoded player-visible strings
- Every string the player can see is a `LOC_LON_*` key in `Text/en_US.xml`. No literals in UI XML or Lua.
- Stub other locale files (`de_DE.xml`, `fr_FR.xml`, ...) as empty placeholders so contributors can fill them.

### No magic numbers in logic files
- All tunable constants live in `Lua/LON_Config.lua`. If a number is in any other Lua file, it's a bug.

### `pcall` around fragile engine APIs
- Wrap calls into `Game.GetWorldCongress()` and adjacent APIs in `pcall`. These have known edge cases that crash sessions.

## Coding standards

### Lua

- **One concern per file.** Each `LON_*.lua` owns one subsystem. See File Layout.
- **One global table per file.** Public functions are members: `LON_Delegates.GetDelegateCount(playerID)`. Never free-floating.
- **`local` by default.** Only export what other modules need.
- **Internal helpers prefixed `_`:** `LON_Delegates._calculateCityStateBonus(playerID)`.
- **No reaching into another module's internals.** If `LON_Negotiation` needs delegate counts, it calls `LON_Delegates.GetDelegateCount`, never reads its tables directly.
- **No mutating other modules' state.** Mutate state through the owning module's API.

### Lua file header (mandatory)

```lua
-- LON_<Name>.lua
-- League of Nations — <one-line purpose>.
-- Persisted state keys: <list, or "(none)">
-- Dependencies: <list of other LON_ modules, or "(none)">
```

### Function comments

- Every public function: one-line comment with inputs, outputs, side effects.
- Inline comments explain *why*, not *what*. Assume the reader can read Lua.

### SQL

- **Prefer SQL over XML** for database changes. Diffs are readable; conditional updates are easier.
- One `.sql` file per concern. Mirror against the Lua module that consumes it where it makes sense.
- Statements end in `;`. Comments use `--`.
- File header explains the file's purpose.

### XML

- Reserved for: the modinfo file, `<ActionCriteria>` blocks, UI panels, and locale text.
- Two-space indentation.
- All UI element IDs prefixed `LON_`.

### Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Lua file | `LON_PascalCase.lua` | `LON_Delegates.lua` |
| Lua global table | `LON_PascalCase` | `LON_Delegates` |
| Lua public fn | `PascalCase` | `GetDelegateCount` |
| Lua internal fn | `_camelCase` | `_calculateCityStateBonus` |
| Lua local var | `camelCase` | `delegateCount` |
| SQL identifier | `LON_SCREAMING_SNAKE` | `LON_RESOLUTION_REPEAL` |
| UI element ID | `LON_PascalCase` | `LON_ProposalList` |
| Loc key | `LOC_LON_SCREAMING_SNAKE` | `LOC_LON_PROPOSAL_TITLE` |

## Modularity principles

The codebase must stay tidy enough that a contributor unfamiliar with it can find their way in under an hour. To that end:

1. **Subsystem boundaries are sacred.** Each `LON_*.lua` file owns one subsystem and exposes a small, deliberate public API. Cross-module access goes through that API.
2. **`LON_Config.lua` is the only place tunables live.** Adding a new tunable means adding it to config, not hardcoding it in your module.
3. **Every new feature gets its own file or extends an existing one in scope.** Don't dump unrelated logic into existing modules. If it doesn't fit, that's a sign it should be its own module.
4. **Modinfo updates ship with the file they reference.** When adding a new Lua file, add it to `LeagueOfNations.modinfo` `<InGameActions>`, `<AddGameplayScripts>`, and `<Files>` blocks in the same commit.
5. **Save/load contracts are explicit.** Any module that persists state lists its keys in its file header AND registers them via `LON_Core.RegisterPersistence(...)`.

## v1 core mechanics (locked in)

- **Founding gate:** Printing Press researched + met all civs. Fallback: first civ to enter Industrial era founds. Tunables in `LON_Config.lua`.
- **Two currencies:** Delegates (standing) and Favor (leverage). Design doc §5.2.
- **Delegate sources:** base era scaling (1→5 across Medieval→Information), +2 while Host, +1 per active Suzerainty (Civ 6 GS Suzerain hook).
- **Proposers each session:** Host + civ with next-highest delegate count. Ties: human first, then `PlayerID`.
- **Permanent until repealed.** Re-apply modifiers on `OnTurnBegin` (NOT each session — engine 30-turn expiry can fire between sessions). Apply/remove keyed on resolution ID — must be idempotent.
- **Vote Negotiation panel-only.** No hidden trade-screen integration. Gold/Favor/resources move via Lua bookkeeping.
- **AI repeals are in.** When an AI civ is one of the two proposers and an active resolution conflicts strongly with its agenda, "propose a repeal of X" is a valid proposal action.
- **Eliminated civs:** their permanent resolutions persist (flagged "proposer eliminated"); their delegates vanish; vote thresholds recompute against the live delegate pool.
- **Special Sessions:** any civ may call one for 30 Favor (tunable).

## Build order (v1)

Each milestone is a playable, testable build. Test in SP **and** MP before declaring done.

| ID | Goal | Done when |
|---|---|---|
| **M1** Skeleton | Modinfo loads, founding gate works, engine Congress suppressed | Placeholder notification fires when League founds |
| **M2** Delegates | Delegate accounting per civ; Host concept | Debug command shows correct counts in all states |
| **M3** Proposals | Proposal Selection panel, era-eligible pool, AI proposal selection (incl. repeal) | Proposers (human + AI) pick from valid pool |
| **M4** Permanence + Repeal | Resolutions persist past 30 turns; repeals work; Active Resolutions panel | Resolution passed at T100 still active at T200 |
| **M5a** AI bribery | Negotiation panel for AI targets; bribed AI votes honored | Offer accepted → tally reflects it |
| **M5b** Human bribery + MP plumbing | Notification → accept/decline flow for human-targeted offers | 2-player MP test passes |
| **M6** Special Sessions | Player can call Special Sessions with Favor | Triggered session resolves correctly |
| **M7** Polish | AI tuning, edge cases, loc sweep, mod-compat | All known issues triaged |

## File layout

```
LeagueOfNations.modinfo          # entry point (mod id, file imports, action criteria)
Data/
  Config.sql                     # GlobalParameters (e.g., suppress engine Congress)
  Resolutions.sql                # resolution data tweaks
  Modifiers.sql                  # modifier definitions for permanent effects
Lua/
  LON_Core.lua                   # init, save/load registry, LON_Log, version
  LON_Config.lua                 # all tunable constants (the ONLY place for tunables)
  LON_Founding.lua               # Printing Press + meet-all-civs gate
  LON_Delegates.lua              # delegate accounting (era + Host + Suzerain)
  LON_Proposals.lua              # who proposes, eligible pool, AI proposal selection
  LON_Negotiation.lua            # bribery offers + AI evaluation
  LON_Repeal.lua                 # repeal tracking and effects
  LON_Permanence.lua             # re-apply modifiers each turn
  LON_AI.lua                     # AI proposal/vote/bribery overrides
UI/
  LON_CongressScreen.{xml,lua}   # main custom Congress screen   [M3+]
  LON_ProposalPanel.{xml,lua}    # Proposal Selection panel       [M3]
  LON_NegotiationPanel.{xml,lua} # Vote Negotiation panel         [M5]
  LON_ActiveResolutions.xml      # active resolutions list        [M4]
Text/
  en_US.xml                      # all LOC_LON_* strings
docs/
  league_of_nations_design.md    # source-of-truth design spec
CLAUDE.md                        # this file
README.md                        # workshop description source
CONTRIBUTING.md                  # how to contribute
CHANGELOG.md                     # newest entries on top
LICENSE                          # MIT
.gitignore
```

## Recipes

### Add a new tunable constant
1. Add to `Lua/LON_Config.lua` with a comment explaining what it controls.
2. Reference via `LON_Config.YOUR_CONSTANT`. **Never hardcode the value elsewhere.**

### Add a new Lua module
1. Create `Lua/LON_YourModule.lua` with the standard file header.
2. Declare global table: `LON_YourModule = {}`.
3. Add to `LeagueOfNations.modinfo` in the same commit:
   - `<ImportFiles>`: `<File>Lua/LON_YourModule.lua</File>`
   - `<AddGameplayScripts>` (only if it has runtime hooks): same line
   - `<Files>`: same line
4. If it persists state, call `LON_Core.RegisterPersistence(key, onSave, onLoad)` and document the keys in the file header.

### Add a new player-visible string
1. Add `<Row Tag="LOC_LON_YOUR_KEY" Language="en_US"><Text>Your text</Text></Row>` to `Text/en_US.xml`.
2. Reference by tag in Lua/UI XML. Never put the literal in code.

### Add a new resolution
TBD — wire up in M3. The recipe will live here once the proposal flow lands.

## Testing

- **Manual playthroughs are primary validation.** No automated test framework exists for Civ 6 mods.
- **FireTuner** for state inspection: `Game.GetWorldCongress()`, custom `lon_debug_*` commands.
- **Test matrix per milestone:**
  - SP fast: Online speed, Pangaea, 4 civs.
  - SP full: Standard speed, Continents, 8 civs.
  - MP: 2-player hot-join. Save → exit → reload → reconnect must work.
  - Edge cases: Printing Press researched late (Industrial fallback), perma-isolated civs, civ elimination after passing a permanent resolution.

## Known risks

Flag in PR description if any of these become blockers.

1. **Bribery timing.** If the engine commits AI vote choices before our Lua hook fires, every bribe is cosmetic. Identify the exact `GameEvents` we can intercept on **before writing M5a**.
2. **Permanent modifier stacking.** Re-application must be idempotent — apply/remove keyed on resolution ID, not blind re-add.
3. **Save/load fidelity.** Active resolutions, delegate counts, host identity, in-flight bribery offers must round-trip. Historically fragile in Civ 6 modding.
4. **MP RNG and state divergence.** The "no `math.random`, no client-only state" rule is the line of defense.
5. **Mod conflicts.** Anything else touching `WORLD_CONGRESS_INITIAL_ERA` or the Congress UI will collide. Document conflicts as discovered.

## PR checklist

Before opening a PR, confirm:

- [ ] No `math.random()` calls; all RNG via `Game.GetRandNum`
- [ ] No new persisted state without `LON_Core.RegisterPersistence` + file-header docs
- [ ] No hardcoded player-visible strings; all use `LOC_LON_*` keys
- [ ] No magic numbers in logic files; all tunables in `LON_Config.lua`
- [ ] No bare `print()` calls; all use `LON_Log`
- [ ] All new files added to `LeagueOfNations.modinfo`
- [ ] Tested in SP at least once
- [ ] Tested in 2-player MP at least once (waivable for docs-only PRs)
- [ ] CHANGELOG updated under `## [Unreleased]`

## Versioning

- Semver: `MAJOR.MINOR.PATCH`.
- Version mirrored in `<Version>` in modinfo and the top-of-file comment in `LON_Core.lua`. Keep them in sync.
- `v0.1.0` = M1 first playable build.
- `v1.0.0` = feature-complete (M1–M6 working in SP and MP).
