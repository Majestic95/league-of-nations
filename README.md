# League of Nations

A Civilization VI mod that reworks the World Congress to feel like Civilization V: Brave New World — a political arena with real player agency.

Pick what gets proposed. Broker votes directly. Make outcomes stick until repealed.

## Status

Pre-alpha. Repository scaffold only. See the [milestone roadmap](CLAUDE.md#build-order-v1).

## Requirements

- Civilization VI with **all DLC**, including:
  - Rise and Fall
  - Gathering Storm — *required; the World Congress only exists in GS*
  - New Frontier Pass

## Installation

### From Steam Workshop
*Not yet released — coming after v1.0.0.*

### From source
Clone the repo, then symlink it into your Civ 6 Mods folder:

```bash
git clone https://github.com/Majestic95/league-of-nations.git
# Windows (run as admin or enable Developer Mode):
mklink /D "%USERPROFILE%\Documents\My Games\Sid Meier's Civilization VI\Mods\LeagueOfNations" "%CD%\league-of-nations"
```

Enable the mod from the **Additional Content** menu in-game.

## Documentation

- [CLAUDE.md](CLAUDE.md) — project context, coding standards, milestones
- [docs/league_of_nations_design.md](docs/league_of_nations_design.md) — full design spec
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to contribute
- [CHANGELOG.md](CHANGELOG.md) — release notes

## License

MIT — see [LICENSE](LICENSE).
