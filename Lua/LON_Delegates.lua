-- LON_Delegates.lua
-- League of Nations — delegate accounting (era + Host + Suzerain).
-- Persisted state keys: (TBD — added in M2)
-- Dependencies: LON_Core, LON_Config

LON_Delegates = {}

-- TODO(M2): implement delegate accounting per design doc §5.2.
-- Public API (planned):
--   LON_Delegates.GetDelegateCount(playerID)        -> integer
--   LON_Delegates.GetBreakdown(playerID)            -> {base=, host=, suzerain=, total=}
--   LON_Delegates.RecomputeAll()                    -> recalc cache for all players
-- Triggers a recompute on: era change, host change, suzerainty change, civ elimination.
