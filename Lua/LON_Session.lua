-- LON_Session.lua
-- League of Nations — current session state: which two civs propose this
-- session, and which resolutions they've picked. The CanUseResolutions hook
-- (in LON_Proposals) reads these picks at engine-fire time.
--
-- Persisted state keys (via GameConfiguration; primitives only):
--   "LON_S_SessionID"   (number) — increments per session, lets us detect new sessions on load
--   "LON_S_HostID"      (number) — proposer 1 (Host) for the current session, or -1
--   "LON_S_SecondID"    (number) — proposer 2 (next-highest delegate), or -1
--   "LON_S_HostPick"    (number) — resolution hash picked by Host, or 0 if not yet
--   "LON_S_SecondPick"  (number) — resolution hash picked by Second, or 0 if not yet
--
-- Dependencies: LON_Core, LON_Founding, LON_Proposals
--
-- Public API:
--   LON_Session.GetCurrentSessionID()           -> number
--   LON_Session.GetProposers()                   -> { host, second }
--   LON_Session.SubmitProposal(playerID, hash)   -> bool   true if accepted
--   LON_Session.GetResolutionHashes()            -> array of hashes (length 0/1/2)
--   LON_Session.HasAllPicks()                    -> bool
--   LON_Session.BeginSession()                   -> snapshot proposers, clear picks
--   LON_Session.EndSession()                     -> bump sessionID, clear picks

LON_Session = {}

-- Internal state (mirror of GameConfiguration values). _loadState rehydrates,
-- _saveState pushes back.
local _sessionID  = 0
local _hostID     = -1
local _secondID   = -1
local _hostPick   = 0   -- 0 = unset (resolution hashes are never 0 in practice)
local _secondPick = 0

-- Persistence ---------------------------------------------------------------

local function _saveState()
    local ok, err = pcall(function()
        GameConfiguration.SetValue("LON_S_SessionID",  _sessionID)
        GameConfiguration.SetValue("LON_S_HostID",     _hostID)
        GameConfiguration.SetValue("LON_S_SecondID",   _secondID)
        GameConfiguration.SetValue("LON_S_HostPick",   _hostPick)
        GameConfiguration.SetValue("LON_S_SecondPick", _secondPick)
    end)
    if not ok then
        LON_Log("ERROR", "LON_Session: failed to persist state: " .. tostring(err))
    end
end

local function _loadState()
    local ok, err = pcall(function()
        _sessionID  = GameConfiguration.GetValue("LON_S_SessionID")  or 0
        _hostID     = GameConfiguration.GetValue("LON_S_HostID")     or -1
        _secondID   = GameConfiguration.GetValue("LON_S_SecondID")   or -1
        _hostPick   = GameConfiguration.GetValue("LON_S_HostPick")   or 0
        _secondPick = GameConfiguration.GetValue("LON_S_SecondPick") or 0
    end)
    if not ok then
        LON_Log("WARN", "LON_Session: failed to load state: " .. tostring(err))
    end
end

-- Public API ----------------------------------------------------------------

function LON_Session.GetCurrentSessionID()
    return _sessionID
end

function LON_Session.GetProposers()
    return { host = _hostID, second = _secondID }
end

-- Returns the array of resolution hashes the engine should use this session.
-- May contain 0, 1, or 2 hashes depending on which proposers have submitted.
-- The CanUseResolutions handler reads this to constrain the pool.
function LON_Session.GetResolutionHashes()
    local hashes = {}
    if _hostPick   ~= 0 then table.insert(hashes, _hostPick)   end
    if _secondPick ~= 0 then table.insert(hashes, _secondPick) end
    return hashes
end

function LON_Session.HasAllPicks()
    if _hostID >= 0 and _hostPick == 0 then return false end
    if _secondID >= 0 and _secondPick == 0 then return false end
    return true
end

-- Records a proposer's pick. Returns true if accepted (playerID is one of the
-- two current proposers); false otherwise.
function LON_Session.SubmitProposal(playerID, resolutionHash)
    if playerID == _hostID then
        _hostPick = resolutionHash
        _saveState()
        LON_Log("INFO", string.format("Session %d: host (player %d) picked hash %s",
            _sessionID, playerID, tostring(resolutionHash)))
        return true
    elseif playerID == _secondID then
        _secondPick = resolutionHash
        _saveState()
        LON_Log("INFO", string.format("Session %d: second (player %d) picked hash %s",
            _sessionID, playerID, tostring(resolutionHash)))
        return true
    end
    LON_Log("WARN", string.format("Session %d: player %d submitted but isn't a proposer (host=%d second=%d)",
        _sessionID, playerID, _hostID, _secondID))
    return false
end

-- Auto-submit a pick on behalf of an AI proposer. Picks at random from the
-- AI's era-eligible pool via LON_AI. Skips humans (they pick via UI).
local function _autoSubmitForAI(playerID)
    if playerID < 0 then return end
    local p = Players[playerID]
    if p == nil or not p:IsAlive() or p:IsHuman() then return end
    if LON_Proposals == nil or LON_AI == nil or LON_AI.PickProposal == nil then return end

    local pool = LON_Proposals.GetEligiblePoolFor(playerID)
    local pick = LON_AI.PickProposal(playerID, pool)
    if pick == nil then
        LON_Log("WARN", string.format("AI proposer %d has empty eligible pool — no submission", playerID))
        return
    end
    LON_Session.SubmitProposal(playerID, pick.hash)
    LON_Log("INFO", string.format("AI proposer %d auto-submitted: %s", playerID, pick.resolutionType))
end

-- Snapshot the current proposers from LON_Proposals and clear any prior picks.
-- Called on founding (first session) and on WorldCongressFinished (subsequent
-- sessions). Idempotent — safe to call multiple times. Auto-submits picks
-- for any AI proposer; humans pick via the UI panel (M3.6).
function LON_Session.BeginSession()
    if LON_Proposals == nil or LON_Proposals.GetCurrentProposers == nil then
        LON_Log("WARN", "LON_Session.BeginSession: LON_Proposals not loaded")
        return
    end
    local p = LON_Proposals.GetCurrentProposers()
    _hostID     = p.host
    _secondID   = p.second
    _hostPick   = 0
    _secondPick = 0
    _saveState()
    LON_Log("INFO", string.format("Session %d began: proposers host=%d second=%d",
        _sessionID, _hostID, _secondID))

    _autoSubmitForAI(_hostID)
    _autoSubmitForAI(_secondID)

    -- If the local player is a human proposer, fire the cross-context event
    -- that opens LON_ProposalPanel. (UI-side filters by Game.GetLocalPlayer.)
    local localID = (Game.GetLocalPlayer and Game.GetLocalPlayer()) or -1
    if localID >= 0 and (localID == _hostID or localID == _secondID) then
        local p = Players[localID]
        if p ~= nil and p:IsHuman() then
            local pool = LON_Proposals.GetEligiblePoolFor(localID)
            if #pool > 0 and LuaEvents ~= nil and LuaEvents.LON_OpenProposalPanel ~= nil then
                LuaEvents.LON_OpenProposalPanel(localID, pool)
            end
        end
    end
end

-- Listen for the UI panel's confirm event and commit the pick.
local function _onPanelSubmitted(playerID, resolutionHash, resolutionType)
    LON_Session.SubmitProposal(playerID, resolutionHash)
end

-- Increments the session counter and clears picks. Called on
-- Events.WorldCongressFinished. Subsequent BeginSession refreshes proposers.
function LON_Session.EndSession()
    _sessionID  = _sessionID + 1
    _hostID     = -1
    _secondID   = -1
    _hostPick   = 0
    _secondPick = 0
    _saveState()
    LON_Log("INFO", string.format("Session ended; next session ID=%d", _sessionID))
end

-- Event hooks ---------------------------------------------------------------

local function _onLoadScreenClose()
    _loadState()
    LON_Log("DEBUG", string.format(
        "LON_Session loaded: id=%d host=%d second=%d hostPick=%s secondPick=%s",
        _sessionID, _hostID, _secondID, tostring(_hostPick), tostring(_secondPick)))
end

local function _onWorldCongressFinished()
    LON_Session.EndSession()
    -- Begin the next session immediately; proposer slots populate from current
    -- delegate state. UI panel + AI auto-submit then drive picks.
    LON_Session.BeginSession()
end

local function _onHostChanged(_)
    -- Founding event (or a host transfer) — kick off the very first session
    -- so proposer slots are populated before any CanUseResolutions fires.
    LON_Session.BeginSession()
end

-- FireTuner debug helpers ---------------------------------------------------

function lon_debug_session()
    print("[LON_Debug] Session state:")
    print(string.format("  sessionID=%d", _sessionID))
    print(string.format("  proposers: host=%d second=%d", _hostID, _secondID))
    print(string.format("  picks: hostPick=%s secondPick=%s",
        _hostPick == 0 and "(none)" or tostring(_hostPick),
        _secondPick == 0 and "(none)" or tostring(_secondPick)))
    print(string.format("  hashes for engine: [%s]",
        table.concat(LON_Session.GetResolutionHashes(), ", ")))
end

-- Init ----------------------------------------------------------------------

local function _safeRegister(event, handler, name)
    if event == nil then
        LON_Log("WARN", "LON_Session: event '" .. name .. "' not available")
        return
    end
    local ok, err = pcall(function() event.Add(handler) end)
    if not ok then
        LON_Log("ERROR", "LON_Session: failed to register '" .. name .. "': " .. tostring(err))
    end
end

local function _initialize()
    _safeRegister(Events.LoadScreenClose,        _onLoadScreenClose,        "LoadScreenClose")
    _safeRegister(Events.WorldCongressFinished,  _onWorldCongressFinished,  "WorldCongressFinished")

    if LON_Founding ~= nil and LON_Founding.RegisterHostChangedHandler ~= nil then
        LON_Founding.RegisterHostChangedHandler(_onHostChanged)
    end

    if LuaEvents ~= nil and LuaEvents.LON_ProposalPanel_Submitted ~= nil then
        LuaEvents.LON_ProposalPanel_Submitted.Add(_onPanelSubmitted)
    end

    LON_Log("INFO", "LON_Session initialized")
end

_initialize()
