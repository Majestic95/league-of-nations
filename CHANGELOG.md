# Changelog

All notable changes to League of Nations are documented here. Newest entries on top.

This project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **M1 (in progress):** engine Congress suppression via `WORLD_CONGRESS_INITIAL_ERA = 99`; founding gate in `LON_Founding.lua` (Printing Press + meet-all-civs, Industrial fallback); placeholder founding notification.
- State persists via `GameConfiguration` (`LON_HasFounded`, `LON_HostPlayerID`, `LON_FoundingTurn`) — MP-safe, round-trips on save/load.
- All engine API calls wrapped in `pcall`; events registered defensively so missing events log a warning instead of crashing.
- Initial repository scaffold: design doc, coding standards (CLAUDE.md), modinfo skeleton, Lua module stubs, SQL stubs, localization stub, MIT license, contributor guide.

Targeting **v0.1.0** = M1 (skeleton: founding gate + engine Congress suppression).
