-- LON_AI.lua
-- League of Nations — AI overrides: proposal selection, vote choice, bribery evaluation.
-- Persisted state keys: (none — derived per call)
-- Dependencies: LON_Core, LON_Config
--
-- v1 model:
--   - Proposal selection: random from the eligible pool via the synced RNG.
--     M7 polish tunes this via leader agenda flavors.
--   - Vote choice: TBD M5.
--   - Bribery acceptance: TBD M5a.
--
-- Out of scope for v1: AI counter-bribery, AI-called Special Sessions,
-- long-horizon Congress strategy.

LON_AI = {}

-- Returns one entry from `pool` (the table returned by
-- LON_Proposals.GetEligiblePoolFor). Returns nil for an empty pool.
-- Uses Game.GetRandNum (synced RNG, MP-safe). Never math.random — that
-- desyncs MP clients per the CLAUDE.md hard rule.
function LON_AI.PickProposal(playerID, pool)
    if pool == nil or #pool == 0 then return nil end
    local idx = 0
    if Game.GetRandNum ~= nil then
        idx = Game.GetRandNum(#pool, "LON AI proposal pick")
    end
    if idx < 0 or idx >= #pool then idx = 0 end
    return pool[idx + 1]
end
