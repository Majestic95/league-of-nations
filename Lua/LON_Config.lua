-- LON_Config.lua
-- League of Nations — single source of truth for tunable constants.
-- Modify values here rather than in logic files. If a number lives anywhere
-- else in the codebase, that's a bug.
--
-- Persisted state keys: (none — config is static)
-- Dependencies: (none)

LON_Config = {}

-- Founding gate ---------------------------------------------------------------
LON_Config.FOUNDING_TECH         = "TECH_PRINTING_PRESS"
LON_Config.FOUNDING_FALLBACK_ERA = "ERA_INDUSTRIAL"

-- Delegates -------------------------------------------------------------------
-- Base delegates per civ by current era (Civ 5 BNW-style scaling).
LON_Config.DELEGATES_BASE_BY_ERA = {
    ERA_MEDIEVAL    = 1,
    ERA_RENAISSANCE = 2,
    ERA_INDUSTRIAL  = 3,
    ERA_MODERN      = 4,
    ERA_ATOMIC      = 4,
    ERA_INFORMATION = 5,
    ERA_FUTURE      = 5,
}
LON_Config.DELEGATES_HOST_BONUS     = 2  -- extra delegates while Host
LON_Config.DELEGATES_PER_SUZERAINTY = 1  -- per active city-state suzerainty

-- Special Sessions ------------------------------------------------------------
LON_Config.SPECIAL_SESSION_FAVOR_COST = 30

-- Bribery ---------------------------------------------------------------------
-- AI accepts a bribe when:  offerValue * relationshipMod  >  ownPreference * RESISTANCE
LON_Config.AI_BRIBERY_RESISTANCE = 1.5

-- Development / playtest --------------------------------------------------
-- Set DEV_MODE = false before any Workshop release. Currently controls
-- whether LON_TestHarness logs its load banner and runs auto-actions.
LON_Config.DEV_MODE = true

-- Auto-actions run by LON_TestHarness on Events.LocalPlayerTurnBegin when
-- DEV_MODE is true. Set to a turn number (>= 1) to fire that action once.
-- Set to nil to disable. The local player ID is used as the target where
-- relevant.
LON_Config.AUTO_FORCE_FOUND_AT_TURN = nil   -- e.g., 3 -> bypass gate, force-found at turn 3
LON_Config.AUTO_GRANT_PP_AT_TURN    = nil   -- e.g., 3 -> grant Printing Press at turn 3 (natural flow)
LON_Config.AUTO_DUMP_AT_TURN        = nil   -- e.g., 5 -> print full state dump at turn 5
