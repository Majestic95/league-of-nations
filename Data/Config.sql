-- Config.sql
-- League of Nations — global parameters and configuration.

-- M1: Suppress engine's Medieval-era auto-start of the World Congress.
-- Verified mechanism (2026-04-26): WORLD_CONGRESS_INITIAL_ERA takes an integer
-- era index (Ancient=0, Classical=1, Medieval=2, ...). GS sets it to 2. We
-- raise it to 99 so the engine never auto-founds; LON_Founding.lua drives
-- founding via Printing Press + meet-all-civs, with an Industrial fallback.
-- Reference: design doc §5.1; verified against
-- DLC/Expansion2/Data/Expansion2_GlobalParameters.xml line 296.
UPDATE GlobalParameters SET Value = '99' WHERE Name = 'WORLD_CONGRESS_INITIAL_ERA';
