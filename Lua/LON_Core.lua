-- LON_Core.lua
-- League of Nations — core init, save/load registry, shared logging.
-- Persisted state keys: (none directly — modules register their own via RegisterPersistence)
-- Dependencies: (none)
--
-- Version: 0.1.0-dev (mirror in LeagueOfNations.modinfo <Version>)

LON_Core = {}

-- Logging --------------------------------------------------------------------

local LOG_LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
local LOG_THRESHOLD = LOG_LEVELS.INFO  -- bump to DEBUG during development

-- Log a message. Use this; never bare print().
function LON_Log(level, message)
    local n = LOG_LEVELS[level] or LOG_LEVELS.INFO
    if n >= LOG_THRESHOLD then
        print(string.format("[LON][%s] %s", level, tostring(message)))
    end
end

-- Save/load registry ---------------------------------------------------------
-- Modules register persistence callbacks here so save/load is centralized
-- and contributors don't have to thread save hooks through every module.

LON_Core._saveLoadEntries = {}

-- Register a module's persistence hooks.
--   key:    unique string ID for this module's state slot
--   onSave: function() -> table  (returns the table to persist)
--   onLoad: function(savedTable) (restores from the persisted table)
function LON_Core.RegisterPersistence(key, onSave, onLoad)
    LON_Core._saveLoadEntries[key] = { save = onSave, load = onLoad }
    LON_Log("DEBUG", "Persistence registered: " .. tostring(key))
end

-- Init -----------------------------------------------------------------------

local function _initialize()
    LON_Log("INFO", "League of Nations v0.1.0-dev loaded")
end

_initialize()
