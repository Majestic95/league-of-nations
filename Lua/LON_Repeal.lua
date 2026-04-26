-- LON_Repeal.lua
-- League of Nations — repeal proposals and effect removal.
-- Persisted state keys: (TBD — added in M4)
-- Dependencies: LON_Core, LON_Permanence

LON_Repeal = {}

-- TODO(M4): implement repeal mechanic per design doc §5.5.
-- Any proposer (Host or 2nd-place delegates) may use their proposal slot to
-- propose a repeal of any active resolution. Same vote rules: >50% of the live
-- delegate pool to pass. On pass: LON_Permanence removes the modifiers and the
-- resolution becomes eligible for re-proposal.
