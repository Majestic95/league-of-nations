# Contributing to League of Nations

Thanks for your interest in contributing. This is an open-source Civ 6 mod and contributions are welcome.

## Getting set up

1. Fork and clone the repo.
2. Symlink the repo into your Civ 6 Mods folder (see [README](README.md#installation)).
3. Read [CLAUDE.md](CLAUDE.md) — it documents the architecture, coding standards, hard rules, and PR checklist.
4. Read [docs/league_of_nations_design.md](docs/league_of_nations_design.md) for the design spec.

## Where to start

- Open issues labeled `good first issue` are the easiest entry points.
- The [build order](CLAUDE.md#build-order-v1) lists upcoming milestones (M1–M7). Open issues track work for the active milestone.
- Documentation, localization, and mod-compatibility fixes are always welcome and don't require deep Civ 6 modding experience.

## Pull requests

Before opening a PR, run through the [PR checklist in CLAUDE.md](CLAUDE.md#pr-checklist). The hard rules there (MP-safe RNG, no client-only state, `LON_` prefix, `LOC_LON_*` strings, tunables in `LON_Config.lua`) are review-blockers.

Keep PRs focused — one concern per PR is much easier to review than a grab-bag.

## Discussion

Use GitHub Issues for bugs and feature proposals. For broader design discussion, open a Discussion thread.

## License

By contributing, you agree your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).
