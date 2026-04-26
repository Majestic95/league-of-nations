-- LON_Founding.lua
-- League of Nations — founding gate (Printing Press + meet-all-civs).
-- Persisted state keys: (TBD — added in M1)
-- Dependencies: LON_Core, LON_Config

LON_Founding = {}

-- TODO(M1): implement founding gate per design doc §5.1.
-- The League founds when any civ has researched LON_Config.FOUNDING_TECH AND
-- has met all other civs in the game. That civ becomes the first Host.
-- Fallback: first civ to enter LON_Config.FOUNDING_FALLBACK_ERA founds the
-- League regardless, to prevent soft-locks on isolated maps.
