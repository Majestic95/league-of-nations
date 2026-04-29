-- LON_Bootstrap.lua
-- League of Nations — single entry point for the gameplay-script context.
-- Persisted state keys: (none)
-- Dependencies: every other LON_ module (loads them via include)
--
-- Civ 6 runs each <AddGameplayScripts> file in its own Lua chunk, so globals
-- defined in one don't see globals defined in another. To share state we list
-- ONE entry point in <AddGameplayScripts> (this file) and pull in every
-- supporting module here via include() — all includes share this chunk's
-- global namespace.
--
-- Order matters: each include runs the file synchronously and any module that
-- references another's globals at module load time must be included AFTER its
-- dependency. Reference: Civ 6 Pirates scenario modinfo pattern.

include "LON_Core"          -- defines LON_Log + LON_Core; depends on nothing
include "LON_Config"        -- defines LON_Config; depends on nothing
include "LON_Founding"      -- uses LON_Log, LON_Config
include "LON_Delegates"     -- uses LON_Log, LON_Config, LON_Founding
include "LON_Proposals"     -- uses LON_Log, LON_Founding
include "LON_Repeal"        -- placeholder
include "LON_Permanence"    -- placeholder
include "LON_Negotiation"   -- placeholder
include "LON_AI"            -- placeholder
include "LON_TestHarness"   -- uses everything; load last
