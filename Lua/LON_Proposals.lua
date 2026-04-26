-- LON_Proposals.lua
-- League of Nations — proposer selection, eligible resolution pool, proposal commit.
-- Persisted state keys: (TBD — added in M3)
-- Dependencies: LON_Core, LON_Config, LON_Delegates, LON_Founding

LON_Proposals = {}

-- TODO(M3): implement proposal flow per design doc §5.3.
-- Each session, two civs propose: the Host (LON_Founding.GetHostPlayerID) and
-- the civ with the next-highest delegate count from LON_Delegates. Ties broken
-- in favor of human, then by PlayerID. AI proposers may also pick "propose a
-- repeal of X" when an active resolution conflicts with their agenda (M4).
--
-- Engine integration: GameEvents.CanUseResolutions (this file) is the hook
-- that lets us constrain the resolution pool down to the proposers' picks
-- BEFORE the engine selects from it. The proposers' picks are collected via
-- LON_ProposalPanel UI (M3) which calls LON_Proposals.SubmitProposal.

-- Spike instrumentation (M1 refactor) -----------------------------------------
-- Logs every CanUseResolutions fire so we can observe engine session cadence
-- and confirm the hook works in our environment. The handler currently leaves
-- resolutions.Resolutions unmodified (no behavior change) — M3 mutates it to
-- the proposers' picks once LON has founded.

local _canUseFires = 0

local function _onCanUseResolutions(resolutions)
    _canUseFires = _canUseFires + 1
    local count = 0
    if resolutions ~= nil and resolutions.Resolutions ~= nil then
        for _ in ipairs(resolutions.Resolutions) do count = count + 1 end
    end
    local foundedStr = "?"
    if LON_Founding ~= nil and LON_Founding.HasFounded ~= nil then
        foundedStr = tostring(LON_Founding.HasFounded())
    end
    LON_Log("INFO", string.format(
        "CanUseResolutions fired (#%d) with %d resolutions in pool. Founded=%s",
        _canUseFires, count, foundedStr
    ))
    -- TODO(M3): if LON_Founding.HasFounded() then
    --     resolutions.Resolutions = LON_Proposals._currentSessionPicks()
    -- end
end

-- FireTuner debug helper. Reports total CanUseResolutions fires this session.
function lon_debug_canuse_fires()
    print(string.format(
        "[LON_Debug] CanUseResolutions fires so far: %d",
        _canUseFires
    ))
end

-- Init ------------------------------------------------------------------------

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
