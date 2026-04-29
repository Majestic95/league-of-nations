# Changelog

All notable changes to League of Nations are documented here. Newest entries on top.

This project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added (M3 — Lua-only half)
- **M3.1** `LON_Proposals.GetCurrentProposers()` — Host + next-highest delegate, ties broken human-first then by PlayerID.
- **M3.2** `LON_Proposals.GetEligiblePoolFor(playerID)` — `GameInfo.Resolutions` filtered by `EarliestEra`/`LatestEra` (via `ChronologyIndex`) and `InjectionOnly`.
- **M3.3** `LON_Session.lua` — per-session state machine. Persists `LON_S_*` keys via `GameConfiguration` (sessionID, two proposer IDs, two resolution hashes). Hooks `Events.WorldCongressFinished` to bump session and rebuild proposers; subscribes to `LON_Founding`'s host-changed pub/sub for the initial session.
- **M3.4** `LON_AI.PickProposal(playerID, pool)` — random from pool via `Game.GetRandNum` (synced RNG). M7 will tune via agendas.
- **M3.5** Real `GameEvents.CanUseResolutions` handler. When founded AND both proposers have submitted picks, replaces the engine's resolution pool with exactly the two picks. Otherwise leaves it unmodified (vanilla GS fallback).
- **M3.7** AI proposers auto-submit on `BeginSession`. Humans skip — they pick via M3.6 UI panel.
- Test harness: `lon_test_pick_random(playerID)`, `lon_test_begin_session()`, `lon_debug_session()`. `lon_test_dump()` now includes session state. `lon_test_help()` updated.

### Fixed
- **Critical: cross-module globals.** Each `<AddGameplayScripts>` file ran in its own isolated Lua chunk, so `LON_Config`, `LON_Founding`, `LON_Log`, etc. were `nil` in every module except the one that defined them. Mod was effectively non-functional after init — every module's `_initialize()` errored out when it referenced another module's globals. Fix: single entry point `Lua/LON_Bootstrap.lua` in `<AddGameplayScripts>`, every other module moved to `<ImportFiles>` only and pulled in via `include()` from the bootstrap. CLAUDE.md "Add a new Lua module" recipe updated to enforce the pattern.

### Added (dev)
- `Lua/LON_TestHarness.lua` — global helpers: `lon_test_grant_pp`, `lon_test_force_found`, `lon_test_reset_founding`, `lon_test_change_host`, `lon_test_recompute_delegates`, `lon_test_dump`, `lon_test_help`. Plus auto-action support: configure `LON_Config.AUTO_FORCE_FOUND_AT_TURN` / `AUTO_GRANT_PP_AT_TURN` / `AUTO_DUMP_AT_TURN` to fire actions at the configured turn — works without FireTuner.
- `LON_Config.DEV_MODE` flag (default `true`) gates the harness banner and auto-action wiring. Flip to `false` for Workshop release.
- Test-only API on `LON_Founding`: `ForceFoundForTesting`, `SetHostForTesting`, `ResetForTesting`. Production code paths don't use these — they exist for the harness.

### Changed
- **M1 refactor:** `WORLD_CONGRESS_INITIAL_ERA` lowered from `99` (full suppression) to `3` (Renaissance) so `GameEvents.CanUseResolutions` can fire — that's the hook M3 will use to constrain the resolution pool to proposers' picks. Trade-off: a few engine sessions may run as vanilla GS before LON founds (between Renaissance and Printing Press research); once LON founds, our hook takes over.

### Added
- **M3 spike:** `LON_Proposals.lua` registers a `GameEvents.CanUseResolutions` handler that logs every fire and leaves the pool unmodified. Lets us verify the hook works in playtest before building the full M3 flow on top. `lon_debug_canuse_fires()` FireTuner helper reports the count.
- **M2 (in progress):** delegate accounting in `LON_Delegates.lua`. Per-civ breakdown of base era delegates (1→5 across Medieval→Information), Host bonus (+2), and Suzerain bonus (+1 per active city-state suzerainty). Cache recomputed on era / influence / host-change / elimination events. `lon_debug_delegates()` FireTuner helper prints a snapshot.
- `LON_Founding.RegisterHostChangedHandler(fn)` — tiny pub-sub so consumers (M2 LON_Delegates, future M3 LON_Proposals) react to host changes without LON_Founding knowing about them. Also fires on `LoadScreenClose` if the loaded save already had a host.
- **M1 (in progress):** engine Congress suppression via `WORLD_CONGRESS_INITIAL_ERA = 99`; founding gate in `LON_Founding.lua` (Printing Press + meet-all-civs, Industrial fallback); placeholder founding notification.
- State persists via `GameConfiguration` (`LON_HasFounded`, `LON_HostPlayerID`, `LON_FoundingTurn`) — MP-safe, round-trips on save/load.
- All engine API calls wrapped in `pcall`; events registered defensively so missing events log a warning instead of crashing.
- Initial repository scaffold: design doc, coding standards (CLAUDE.md), modinfo skeleton, Lua module stubs, SQL stubs, localization stub, MIT license, contributor guide.

Targeting **v0.1.0** = M1 (skeleton: founding gate + engine Congress suppression).
