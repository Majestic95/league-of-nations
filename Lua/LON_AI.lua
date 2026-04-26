-- LON_AI.lua
-- League of Nations — AI overrides: proposal selection, vote choice, bribery evaluation.
-- Persisted state keys: (TBD — added in M3+)
-- Dependencies: LON_Core, LON_Config, LON_Delegates, LON_Proposals

LON_AI = {}

-- TODO(M3+): implement agenda-driven AI behavior per design doc §7.
-- v1 model:
--   - Proposal selection: weight era-eligible resolutions by leader agenda flavor + strategic state.
--     AI may choose "propose repeal of X" when X conflicts strongly with agenda.
--   - Vote choice: keep engine default as floor; override on accepted bribe or
--     strong agenda preference.
--   - Bribery acceptance: accept if (offerValue * relationshipMod) > (ownPreference * LON_Config.AI_BRIBERY_RESISTANCE).
-- Out of scope for v1: AI counter-bribery, AI-called Special Sessions, long-horizon Congress strategy.
