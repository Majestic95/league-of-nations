-- Config.sql
-- League of Nations — global parameters and configuration.

-- TODO(M1): suppress engine's Medieval-era auto-start of the World Congress.
-- The exact mechanism (era index integer, era ID string, or row removal) needs
-- verification against Expansion2_GlobalParameters before being wired up.
-- Reference: design doc §5.1.

-- Example (commented out until verified):
-- UPDATE GlobalParameters SET Value = '999' WHERE Name = 'WORLD_CONGRESS_INITIAL_ERA';
