-- LON_Proposals.lua
-- League of Nations — proposer selection, eligible resolution pool, AI proposal selection.
-- Persisted state keys: (TBD — added in M3)
-- Dependencies: LON_Core, LON_Config, LON_Delegates

LON_Proposals = {}

-- TODO(M3): implement proposal flow per design doc §5.3.
-- Each session, two civs propose: the Host and the civ with the next-highest
-- delegate count. Ties broken in favor of human, then by PlayerID.
-- AI proposers also consider proposing a repeal of an active resolution that
-- conflicts with their agenda (see LON_Repeal, LON_AI).
