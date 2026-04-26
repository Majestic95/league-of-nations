-- LON_Negotiation.lua
-- League of Nations — vote bribery: offers, AI evaluation, commitments.
-- Persisted state keys: (TBD — added in M5a)
-- Dependencies: LON_Core, LON_Config, LON_Delegates, LON_AI

LON_Negotiation = {}

-- TODO(M5a/M5b): implement negotiation panel logic per design doc §5.4.
-- Panel-only: no integration with the engine deal screen (deal item types
-- are hardcoded). Gold/Favor/resources move via Lua bookkeeping inside the panel.
-- AI targets: evaluate via LON_AI.EvaluateBribery(...) using LON_Config.AI_BRIBERY_RESISTANCE.
-- Human targets (M5b): notification → accept/decline flow on the recipient's client.
