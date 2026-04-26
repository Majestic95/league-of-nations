-- LON_Permanence.lua
-- League of Nations — keeps passed resolutions active past the engine's 30-turn auto-expiry.
-- Persisted state keys: (TBD — added in M4)
-- Dependencies: LON_Core, LON_Config

LON_Permanence = {}

-- TODO(M4): implement permanence layer per design doc §5.5.
-- Re-apply modifiers on OnTurnBegin (NOT on session boundaries — engine 30-turn
-- expiry can fire between sessions). Apply/remove must be IDEMPOTENT, keyed on
-- resolution ID, to prevent stacking (e.g., +1 / +2 / +3 / ... production).
-- Public API (planned):
--   LON_Permanence.Apply(resolutionID, payload)
--   LON_Permanence.Remove(resolutionID)
--   LON_Permanence.GetActive() -> { [resolutionID] = payload, ... }
