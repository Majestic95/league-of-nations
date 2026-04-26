-- LON_Delegates.lua
-- League of Nations — delegate accounting (era base + Host bonus + Suzerain bonus).
--
-- Persisted state keys: (none — cache is fully derived from game state and
--   recomputed on LoadScreenClose, so no serialization is needed)
-- Dependencies: LON_Core, LON_Config, LON_Founding

LON_Delegates = {}

-- Cache: { [playerID] = { base, host, suzerain, total } }. Recomputed in
-- response to era / influence / host / elimination events.
local _cache = {}

-- Public API ----------------------------------------------------------------

-- Returns the total delegate count for a major civ, or 0 if unknown / dead.
function LON_Delegates.GetDelegateCount(playerID)
    local b = _cache[playerID]
    return b and b.total or 0
end

-- Returns a defensive copy of the breakdown for a major civ, or nil if unknown.
function LON_Delegates.GetBreakdown(playerID)
    local b = _cache[playerID]
    if b == nil then return nil end
    return { base = b.base, host = b.host, suzerain = b.suzerain, total = b.total }
end

-- Helpers -------------------------------------------------------------------

-- Returns the base delegates for playerID's current era, or 0 if pre-Medieval
-- (or if the era type isn't in LON_Config.DELEGATES_BASE_BY_ERA).
local function _eraBaseFor(playerID)
    local ok, value = pcall(function()
        local p = Players[playerID]
        if p == nil or not p:IsAlive() then return 0 end
        local eras = p:GetEras()
        if eras == nil then return 0 end
        local eraIdx = eras:GetEra()
        local eraRow = GameInfo.Eras[eraIdx]
        local eraType = eraRow and eraRow.EraType or nil
        if eraType == nil then return 0 end
        return LON_Config.DELEGATES_BASE_BY_ERA[eraType] or 0
    end)
    return ok and value or 0
end

-- Returns the host bonus playerID gets (DELEGATES_HOST_BONUS if they're the
-- League's current Host, 0 otherwise).
local function _hostBonusFor(playerID)
    if not LON_Founding.HasFounded() then return 0 end
    if LON_Founding.GetHostPlayerID() == playerID then
        return LON_Config.DELEGATES_HOST_BONUS
    end
    return 0
end

-- Returns the suzerain bonus for playerID — count of alive city-states whose
-- current suzerain is playerID, times DELEGATES_PER_SUZERAINTY.
local function _suzerainBonusFor(playerID)
    local ok, value = pcall(function()
        local count = 0
        local minorIDs = PlayerManager.GetAliveMinorIDs()
        if minorIDs == nil then return 0 end
        for _, csID in ipairs(minorIDs) do
            local cs = Players[csID]
            if cs ~= nil and cs:IsAlive() then
                local infl = cs:GetInfluence()
                if infl ~= nil and infl:GetSuzerain() == playerID then
                    count = count + 1
                end
            end
        end
        return count * LON_Config.DELEGATES_PER_SUZERAINTY
    end)
    return ok and value or 0
end

-- Recomputation -------------------------------------------------------------

-- Recomputes the cache entry for one major civ.
function LON_Delegates.RecomputeFor(playerID)
    local p = Players[playerID]
    if p == nil or not p:IsAlive() then
        _cache[playerID] = nil
        return
    end
    local base     = _eraBaseFor(playerID)
    local host     = _hostBonusFor(playerID)
    local suzerain = _suzerainBonusFor(playerID)
    _cache[playerID] = {
        base     = base,
        host     = host,
        suzerain = suzerain,
        total    = base + host + suzerain,
    }
end

-- Rebuilds the cache for every alive major civ. Cheap (O(n_civs * n_minors)),
-- safe to call from any event handler.
function LON_Delegates.RecomputeAll()
    _cache = {}
    local ok, err = pcall(function()
        for _, pPlayer in ipairs(PlayerManager.GetAliveMajors()) do
            LON_Delegates.RecomputeFor(pPlayer:GetID())
        end
    end)
    if not ok then
        LON_Log("WARN", "LON_Delegates.RecomputeAll error: " .. tostring(err))
    end
end

-- Event hooks ---------------------------------------------------------------

local function _onPlayerEraChanged(playerID)
    LON_Delegates.RecomputeFor(playerID)
end

local function _onGameEraChanged()
    -- Safety net: per-player era events drive most updates, but a global era
    -- shift can affect cached entries we missed.
    LON_Delegates.RecomputeAll()
end

local function _onInfluenceChanged()
    -- Suzerainties may have shifted; recompute all majors' suzerain bonuses.
    LON_Delegates.RecomputeAll()
end

local function _onPlayerEliminated(playerID)
    -- That civ's delegates vanish; suzerainties they held may have shifted to
    -- other civs, so recompute everyone.
    _cache[playerID] = nil
    LON_Delegates.RecomputeAll()
end

local function _onLoadScreenClose()
    LON_Delegates.RecomputeAll()
    LON_Log("DEBUG", "LON_Delegates: recomputed on load")
end

local function _onHostChanged(_)
    LON_Delegates.RecomputeAll()
end

-- FireTuner debug helper (intentionally global, not namespaced) -------------

-- Print a snapshot of the delegate cache. Invoke from FireTuner.
function lon_debug_delegates()
    print("[LON_Debug] Delegate counts:")
    for _, pPlayer in ipairs(PlayerManager.GetAliveMajors()) do
        local pid = pPlayer:GetID()
        local b = LON_Delegates.GetBreakdown(pid) or { base = 0, host = 0, suzerain = 0, total = 0 }
        print(string.format(
            "  Player %d: base=%d host=%d suzerain=%d total=%d",
            pid, b.base, b.host, b.suzerain, b.total
        ))
    end
end

-- Init ----------------------------------------------------------------------

local function _safeRegister(event, handler, name)
    if event == nil then
        LON_Log("WARN", "LON_Delegates: event '" .. name .. "' not available")
        return
    end
    local ok, err = pcall(function() event.Add(handler) end)
    if not ok then
        LON_Log("ERROR", "LON_Delegates: failed to register '" .. name .. "': " .. tostring(err))
    end
end

local function _initialize()
    _safeRegister(Events.LoadScreenClose,    _onLoadScreenClose,    "LoadScreenClose")
    _safeRegister(Events.PlayerEraChanged,   _onPlayerEraChanged,   "PlayerEraChanged")
    _safeRegister(Events.GameEraChanged,     _onGameEraChanged,     "GameEraChanged")
    _safeRegister(Events.InfluenceChanged,   _onInfluenceChanged,   "InfluenceChanged")
    _safeRegister(Events.PlayerDefeat,       _onPlayerEliminated,   "PlayerDefeat")
    _safeRegister(Events.PlayerDestroyed,    _onPlayerEliminated,   "PlayerDestroyed")

    LON_Founding.RegisterHostChangedHandler(_onHostChanged)

    LON_Log("INFO", "LON_Delegates initialized")
end

_initialize()
