# Changelog

All notable changes to League of Nations are documented here. Newest entries on top.

This project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added (dev)
- `Lua/LON_TestHarness.lua` — FireTuner-callable global helpers: `lon_test_grant_pp`, `lon_test_force_found`, `lon_test_reset_founding`, `lon_test_change_host`, `lon_test_recompute_delegates`, `lon_test_dump`, `lon_test_help`. Cuts a per-cycle playtest from minutes to seconds.
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
