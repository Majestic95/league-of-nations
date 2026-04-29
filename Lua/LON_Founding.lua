-- LON_Founding.lua
-- League of Nations — founding gate (Printing Press + meet-all-civs).
-- Persisted state keys (via GameConfiguration, MP-safe):
--   "LON_HasFounded"   (bool)  — true once the League has been founded
--   "LON_HostPlayerID" (int)   — player ID of the founding civ (the first Host)
--   "LON_FoundingTurn" (int)   — game turn the League was founded on
-- Dependencies: LON_Core, LON_Config

LON_Founding = {}

-- Internal state cache. Hydrated from GameConfiguration on LoadScreenClose so
-- save/load and MP join both pick up the right values.
local _hasFounded   = false
local _hostPlayerID = -1
local _foundingTurn = -1

-- Public API ----------------------------------------------------------------

-- Returns true if the League has been founded.
function LON_Founding.HasFounded()
    return _hasFounded
end

-- Returns the host player ID, or -1 if not founded.
function LON_Founding.GetHostPlayerID()
    return _hostPlayerID
end

-- Returns the turn the League was founded on, or -1 if not founded.
function LON_Founding.GetFoundingTurn()
    return _foundingTurn
end

-- Host-changed pub/sub ------------------------------------------------------
-- Other modules subscribe to host changes here instead of LON_Founding having
-- to know about its consumers (LON_Delegates wants to refresh the host bonus,
-- M3+ LON_Proposals wants to reset proposer order, etc.).

local _hostChangedHandlers = {}

-- Registers a handler called as fn(newHostPlayerID) whenever the host changes.
-- Handlers are called inside pcall so a buggy handler can't break others.
function LON_Founding.RegisterHostChangedHandler(fn)
    table.insert(_hostChangedHandlers, fn)
end

local function _fireHostChanged(newHostID)
    for _, fn in ipairs(_hostChangedHandlers) do
        local ok, err = pcall(fn, newHostID)
        if not ok then
            LON_Log("WARN", "Host-changed handler errored: " .. tostring(err))
        end
    end
end

-- Persistence helpers -------------------------------------------------------

-- GameConfiguration.SetValue only accepts primitives (string/number/nil) per
-- empirical Civ 6 behavior — no booleans. We round-trip _hasFounded as 0/1.

local function _loadState()
    local ok, err = pcall(function()
        local foundedInt = GameConfiguration.GetValue("LON_HasFounded") or 0
        _hasFounded   = (foundedInt == 1)
        _hostPlayerID = GameConfiguration.GetValue("LON_HostPlayerID") or -1
        _foundingTurn = GameConfiguration.GetValue("LON_FoundingTurn") or -1
    end)
    if not ok then
        LON_Log("WARN", "LON_Founding: failed to load state: " .. tostring(err))
    end
end

local function _saveState()
    local ok, err = pcall(function()
        GameConfiguration.SetValue("LON_HasFounded",   _hasFounded and 1 or 0)
        GameConfiguration.SetValue("LON_HostPlayerID", _hostPlayerID)
        GameConfiguration.SetValue("LON_FoundingTurn", _foundingTurn)
    end)
    if not ok then
        LON_Log("ERROR", "LON_Founding: failed to persist state: " .. tostring(err))
    end
end

-- Lookup helpers ------------------------------------------------------------

-- Returns the row Index for our founding tech, or nil if not found.
local function _foundingTechIndex()
    local row = GameInfo.Technologies[LON_Config.FOUNDING_TECH]
    return row and row.Index or nil
end

-- Returns the row Index for our fallback era, or nil if not found.
local function _fallbackEraIndex()
    local row = GameInfo.Eras[LON_Config.FOUNDING_FALLBACK_ERA]
    return row and row.Index or nil
end

-- Iterates alive major civs and yields each player ID.
local function _aliveMajorIDs()
    local ids = {}
    local maxMajors = (GameDefines and GameDefines.MAX_MAJOR_CIVS) or 64
    for i = 0, maxMajors - 1 do
        local p = Players[i]
        if p ~= nil and p:IsAlive() then
            table.insert(ids, i)
        end
    end
    return ids
end

-- Predicates ----------------------------------------------------------------

-- True if playerID has met every other living major civ.
local function _hasMetAllLivingMajors(playerID)
    local ok, result = pcall(function()
        local p = Players[playerID]
        if p == nil or not p:IsAlive() then return false end
        local diplo = p:GetDiplomacy()
        if diplo == nil then return false end
        for _, otherID in ipairs(_aliveMajorIDs()) do
            if otherID ~= playerID and not diplo:HasMet(otherID) then
                return false
            end
        end
        return true
    end)
    if not ok then
        LON_Log("WARN", "_hasMetAllLivingMajors error: " .. tostring(result))
        return false
    end
    return result
end

-- True if playerID has researched the founding tech.
local function _hasFoundingTech(playerID)
    local techIdx = _foundingTechIndex()
    if techIdx == nil then return false end
    local ok, result = pcall(function()
        local p = Players[playerID]
        if p == nil or not p:IsAlive() then return false end
        local techs = p:GetTechs()
        return techs ~= nil and techs:HasTech(techIdx)
    end)
    return ok and result or false
end

-- True if playerID is in or past the fallback era.
local function _atOrPastFallbackEra(playerID)
    local eraIdx = _fallbackEraIndex()
    if eraIdx == nil then return false end
    local ok, result = pcall(function()
        local p = Players[playerID]
        if p == nil or not p:IsAlive() then return false end
        local eras = p:GetEras()
        return eras ~= nil and eras:GetEra() >= eraIdx
    end)
    return ok and result or false
end

-- Founding ------------------------------------------------------------------

-- Best-effort lookup of a civ's display name. Falls back to "Player N".
local function _civDisplayName(playerID)
    local name
    local ok = pcall(function()
        local cfg = PlayerConfigurations[playerID]
        if cfg ~= nil then
            local key = cfg:GetCivilizationDescription()
            if key ~= nil then name = Locale.Lookup(key) end
        end
    end)
    if not ok or name == nil or name == "" then
        return "Player " .. tostring(playerID)
    end
    return name
end

-- Sends the placeholder "League founded" notification to one player.
-- Wrapped in pcall so an unexpected NotificationTypes shape doesn't crash.
local function _notifyFounding(targetPlayerID, hostName)
    pcall(function()
        local data = {}
        data[ParameterTypes.MESSAGE] = Locale.Lookup("LOC_LON_NOTIF_FOUNDED_MESSAGE", hostName)
        data[ParameterTypes.SUMMARY] = Locale.Lookup("LOC_LON_NOTIF_FOUNDED_SUMMARY", hostName)
        NotificationManager.SendNotification(targetPlayerID, NotificationTypes.USER_DEFINED_1, data)
    end)
end

-- Founds the League with playerID as host. Idempotent.
local function _foundLeague(playerID, reason)
    if _hasFounded then return end
    _hasFounded   = true
    _hostPlayerID = playerID
    _foundingTurn = (Game.GetCurrentGameTurn and Game.GetCurrentGameTurn()) or -1
    _saveState()

    local hostName = _civDisplayName(playerID)
    LON_Log("INFO", string.format(
        "League of Nations founded by %s (player %d) on turn %d via %s",
        hostName, playerID, _foundingTurn, reason
    ))

    for _, otherID in ipairs(_aliveMajorIDs()) do
        _notifyFounding(otherID, hostName)
    end

    _fireHostChanged(playerID)
end

-- Test-only API -------------------------------------------------------------
-- These functions exist to support LON_TestHarness. They mutate state in ways
-- the regular event flow wouldn't. Don't call them from production code paths.

-- Bypass the gate; force-found with playerID as host. Idempotent.
function LON_Founding.ForceFoundForTesting(playerID)
    if _hasFounded then
        LON_Log("WARN", "ForceFoundForTesting: already founded; ignoring")
        return
    end
    _foundLeague(playerID, "test_force")
end

-- Force a host change without re-running the founding gate. Fires the
-- host-changed pub/sub so consumers (LON_Delegates) refresh their state.
function LON_Founding.SetHostForTesting(newHostID)
    if not _hasFounded then
        LON_Log("WARN", "SetHostForTesting: not founded yet; use ForceFoundForTesting first")
        return
    end
    _hostPlayerID = newHostID
    _saveState()
    LON_Log("INFO", "Host changed to player " .. tostring(newHostID) .. " (test)")
    _fireHostChanged(newHostID)
end

-- Reset founding state to pre-founded. Allows re-testing the gate without
-- starting a new game. Recomputes delegates so the cached host bonus drops.
function LON_Founding.ResetForTesting()
    _hasFounded   = false
    _hostPlayerID = -1
    _foundingTurn = -1
    _saveState()
    LON_Log("INFO", "LON_Founding reset (test)")
    if LON_Delegates ~= nil and LON_Delegates.RecomputeAll ~= nil then
        LON_Delegates.RecomputeAll()
    end
end

-- Condition checks ----------------------------------------------------------

-- Scans all alive majors for the primary founding condition. First qualifier
-- in player ID order founds.
local function _checkPrimary()
    if _hasFounded then return end
    for _, pid in ipairs(_aliveMajorIDs()) do
        if _hasFoundingTech(pid) and _hasMetAllLivingMajors(pid) then
            _foundLeague(pid, "primary")
            return
        end
    end
end

-- Checks the fallback condition for a single player (just entered fallback era).
local function _checkFallback(playerID)
    if _hasFounded then return end
    if _atOrPastFallbackEra(playerID) then
        _foundLeague(playerID, "fallback")
    end
end

-- Event hooks ---------------------------------------------------------------

local function _onResearchCompleted(playerID, techIndex)
    if _hasFounded then return end
    local foundingIdx = _foundingTechIndex()
    if foundingIdx ~= nil and techIndex == foundingIdx then
        _checkPrimary()
    end
end

local function _onDiplomacyMeet(playerID1, playerID2)
    -- Either party may now satisfy the meet-all-civs condition; cheap to scan.
    if _hasFounded then return end
    _checkPrimary()
end

local function _onPlayerEraChanged(playerID)
    if _hasFounded then return end
    _checkFallback(playerID)
end

local function _onLoadScreenClose()
    _loadState()
    LON_Log("DEBUG", string.format(
        "LON_Founding state loaded: hasFounded=%s host=%d turn=%d",
        tostring(_hasFounded), _hostPlayerID, _foundingTurn
    ))
    -- Notify subscribers if a host was already set in the loaded save so they
    -- can refresh their derived state.
    if _hasFounded and _hostPlayerID >= 0 then
        _fireHostChanged(_hostPlayerID)
    end
end

-- Per-turn recovery + diagnostic. Catches cases where Events.DiplomacyMeet or
-- Events.ResearchCompleted fired but our predicate evaluated stale state, and
-- logs WHY the gate fails when it does so we can diagnose without FireTuner.
local function _onLocalPlayerTurnBegin()
    if _hasFounded then return end

    -- Recovery: re-run the primary gate from scratch.
    _checkPrimary()
    if _hasFounded then return end

    -- Diagnostic: for any civ that has the founding tech, log who they haven't
    -- met yet. Tells us whether the gate fails on the tech or on meet-all.
    for _, pid in ipairs(_aliveMajorIDs()) do
        if _hasFoundingTech(pid) then
            local missing = {}
            pcall(function()
                local p = Players[pid]
                local diplo = p and p:GetDiplomacy() or nil
                if diplo == nil then return end
                for _, otherID in ipairs(_aliveMajorIDs()) do
                    if otherID ~= pid and not diplo:HasMet(otherID) then
                        table.insert(missing, tostring(otherID))
                    end
                end
            end)
            if #missing == 0 then
                -- Has tech AND met all alive majors — but gate failed. Bug.
                LON_Log("WARN", string.format(
                    "Gate diagnostic: player %d has tech AND met all alive majors but gate didn't fire", pid))
            else
                LON_Log("INFO", string.format(
                    "Gate diagnostic: player %d has tech, hasn't met player(s): [%s]",
                    pid, table.concat(missing, ",")))
            end
        end
    end
end

-- Init ----------------------------------------------------------------------

local function _safeRegister(event, handler, name)
    if event == nil then
        LON_Log("WARN", "LON_Founding: event '" .. name .. "' not available")
        return
    end
    local ok, err = pcall(function() event.Add(handler) end)
    if not ok then
        LON_Log("ERROR", "LON_Founding: failed to register '" .. name .. "': " .. tostring(err))
    end
end

local function _initialize()
    _safeRegister(Events.LoadScreenClose,     _onLoadScreenClose,        "LoadScreenClose")
    _safeRegister(Events.ResearchCompleted,   _onResearchCompleted,      "ResearchCompleted")
    _safeRegister(Events.DiplomacyMeet,       _onDiplomacyMeet,          "DiplomacyMeet")
    _safeRegister(Events.PlayerEraChanged,    _onPlayerEraChanged,       "PlayerEraChanged")
    _safeRegister(Events.LocalPlayerTurnBegin, _onLocalPlayerTurnBegin,  "LocalPlayerTurnBegin")
    LON_Log("INFO", "LON_Founding initialized (gate: "
        .. LON_Config.FOUNDING_TECH .. " + meet-all-civs; fallback: "
        .. LON_Config.FOUNDING_FALLBACK_ERA .. ")")
end

_initialize()
