-- LON_Proposals.lua
-- League of Nations — proposer selection, eligible resolution pool, proposal commit.
-- Persisted state keys: (TBD — added in M3.3 / LON_Session)
-- Dependencies: LON_Core, LON_Config, LON_Delegates, LON_Founding
--
-- Public API:
--   LON_Proposals.GetCurrentProposers()         -> { host=ID, second=ID }   (-1 fields if N/A)
--   LON_Proposals.GetEligiblePoolFor(playerID)  -> [ { resolutionType, hash, name, ... } ]
--   LON_Proposals.SubmitProposal(playerID, ...) -> (M3.3, via LON_Session)
--
-- Engine integration: GameEvents.CanUseResolutions is the Path B hook that
-- lets us constrain the resolution pool down to the proposers' picks BEFORE
-- the engine selects from it. The hook currently logs only (M1 spike); M3.5
-- replaces the no-op with real proposer-pick injection.

LON_Proposals = {}

-- Proposer selection (M3.1) -------------------------------------------------

-- Returns { host = ID, second = ID }. host is LON_Founding's host. second is
-- the alive major civ (other than host) with the next-highest delegate count;
-- ties broken in favor of humans first, then by lower PlayerID. -1 fields
-- when not founded or no eligible second-place civ exists.
function LON_Proposals.GetCurrentProposers()
    local result = { host = -1, second = -1 }

    if LON_Founding == nil or not LON_Founding.HasFounded() then
        return result
    end
    result.host = LON_Founding.GetHostPlayerID()

    local candidates = {}
    pcall(function()
        for _, pPlayer in ipairs(PlayerManager.GetAliveMajors()) do
            local pid = pPlayer:GetID()
            if pid ~= result.host then
                table.insert(candidates, {
                    id    = pid,
                    count = LON_Delegates.GetDelegateCount(pid),
                    human = pPlayer:IsHuman() and true or false,
                })
            end
        end
    end)

    table.sort(candidates, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        if a.human ~= b.human then return a.human end       -- human wins ties
        return a.id < b.id                                   -- then lower PlayerID
    end)

    if #candidates > 0 then
        result.second = candidates[1].id
    end
    return result
end

-- Eligible pool (M3.2) ------------------------------------------------------

-- Returns an array of resolution entries eligible for playerID's era.
-- Each entry: { resolutionType, hash, name, targetKind, effect1, effect2 }
-- Filters: skip InjectionOnly resolutions; respect EarliestEra / LatestEra
-- via ChronologyIndex on the player's current era.
function LON_Proposals.GetEligiblePoolFor(playerID)
    local pool = {}
    local ok, err = pcall(function()
        local p = Players[playerID]
        if p == nil or not p:IsAlive() then return end

        local eras = p:GetEras()
        if eras == nil then return end
        local playerEraIdx = eras:GetEra()
        local playerEraRow = GameInfo.Eras[playerEraIdx]
        if playerEraRow == nil then return end
        local playerChrono = playerEraRow.ChronologyIndex

        for resolution in GameInfo.Resolutions() do
            if not resolution.InjectionOnly then
                local minOk = true
                local maxOk = true
                if resolution.EarliestEra ~= nil and resolution.EarliestEra ~= "" then
                    local minRow = GameInfo.Eras[resolution.EarliestEra]
                    if minRow ~= nil then minOk = playerChrono >= minRow.ChronologyIndex end
                end
                if resolution.LatestEra ~= nil and resolution.LatestEra ~= "" then
                    local maxRow = GameInfo.Eras[resolution.LatestEra]
                    if maxRow ~= nil then maxOk = playerChrono <= maxRow.ChronologyIndex end
                end
                if minOk and maxOk then
                    table.insert(pool, {
                        resolutionType = resolution.ResolutionType,
                        hash           = resolution.Hash,
                        name           = resolution.Name,
                        targetKind     = resolution.TargetKind,
                        effect1        = resolution.Effect1Description,
                        effect2        = resolution.Effect2Description,
                    })
                end
            end
        end
    end)
    if not ok then
        LON_Log("WARN", "GetEligiblePoolFor error: " .. tostring(err))
    end
    return pool
end

-- M1 spike: CanUseResolutions hook ------------------------------------------
-- Logs every fire so we can observe engine cadence and confirm the hook works.
-- The handler leaves resolutions.Resolutions unmodified (no behavior change).
-- M3.5 replaces this with real proposer-pick injection.

local _canUseFires = 0

-- M3.5: real handler. Once the League has founded AND both proposers have
-- submitted picks, replace the engine's resolution pool with exactly those
-- two hashes. Pre-founding or with incomplete picks: leave the pool alone
-- (engine falls back to vanilla GS behavior — full pool, engine random).
local function _onCanUseResolutions(resolutions)
    _canUseFires = _canUseFires + 1

    if resolutions == nil or resolutions.Resolutions == nil then return end

    local poolCount = 0
    for _ in ipairs(resolutions.Resolutions) do poolCount = poolCount + 1 end

    local founded = LON_Founding ~= nil and LON_Founding.HasFounded()
    local injected = false

    if founded and LON_Session ~= nil and LON_Session.HasAllPicks ~= nil and LON_Session.HasAllPicks() then
        local picks = LON_Session.GetResolutionHashes()
        if #picks >= 2 then
            resolutions.Resolutions = { picks[1], picks[2] }
            injected = true
        end
    end

    LON_Log("INFO", string.format(
        "CanUseResolutions fired (#%d): poolIn=%d founded=%s injected=%s",
        _canUseFires, poolCount, tostring(founded), tostring(injected)
    ))
end

-- FireTuner / log debug helpers ---------------------------------------------

function lon_debug_canuse_fires()
    print(string.format("[LON_Debug] CanUseResolutions fires so far: %d", _canUseFires))
end

-- Print current proposers + their delegate counts.
function lon_debug_proposers()
    local p = LON_Proposals.GetCurrentProposers()
    print("[LON_Debug] Current proposers:")
    if p.host < 0 then
        print("  League not founded — no proposers.")
        return
    end
    print(string.format("  Host:   player %d (delegates=%d)", p.host,
        LON_Delegates and LON_Delegates.GetDelegateCount(p.host) or -1))
    if p.second < 0 then
        print("  Second: (none — no other alive major)")
    else
        print(string.format("  Second: player %d (delegates=%d)", p.second,
            LON_Delegates and LON_Delegates.GetDelegateCount(p.second) or -1))
    end
end

-- Print the eligible resolution pool for a player. Defaults to local player.
function lon_debug_pool(playerID)
    playerID = playerID or (Game.GetLocalPlayer and Game.GetLocalPlayer()) or -1
    if playerID < 0 then
        print("[LON_Debug] No valid player ID. Pass an explicit ID, e.g. lon_debug_pool(0).")
        return
    end
    local pool = LON_Proposals.GetEligiblePoolFor(playerID)
    print(string.format("[LON_Debug] Eligible pool for player %d (%d resolutions):", playerID, #pool))
    for i, entry in ipairs(pool) do
        print(string.format("  %2d. %s   (target=%s)", i, entry.resolutionType, tostring(entry.targetKind)))
    end
end

-- Init ----------------------------------------------------------------------

local function _initialize()
    if GameEvents == nil or GameEvents.CanUseResolutions == nil then
        LON_Log("WARN", "LON_Proposals: GameEvents.CanUseResolutions not available — Path B hook missing")
        return
    end
    local ok, err = pcall(function() GameEvents.CanUseResolutions.Add(_onCanUseResolutions) end)
    if ok then
        LON_Log("INFO", "LON_Proposals: CanUseResolutions hook registered (M1 spike)")
    else
        LON_Log("ERROR", "LON_Proposals: failed to register CanUseResolutions: " .. tostring(err))
    end
end

_initialize()
