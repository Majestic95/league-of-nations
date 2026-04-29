-- LON_TestHarness.lua
-- League of Nations — FireTuner-callable shortcuts for development/playtest.
-- Persisted state keys: (none)
-- Dependencies: LON_Core, LON_Founding, LON_Delegates, LON_Proposals
--
-- All public functions are intentionally GLOBAL (not namespaced under a table)
-- so they can be called directly from FireTuner's Lua console as one-liners
-- without typing a table prefix. Names are prefixed with `lon_test_` to avoid
-- collisions and to read clearly in the tuner.
--
-- Output goes to print() which appears in:
--   - FireTuner's Lua console (immediate)
--   - %USERPROFILE%\Documents\My Games\Sid Meier's Civilization VI\Logs\Lua.log
--
-- This module ships as part of the mod. For a Workshop release we'd flip
-- LON_Config.DEV_MODE to false to silence the init banner; the functions
-- remain defined but harmless unless deliberately called.

-- Helpers -------------------------------------------------------------------

local function _resolvePlayerID(playerID)
    if playerID ~= nil then return playerID end
    local local_ = (Game.GetLocalPlayer and Game.GetLocalPlayer()) or -1
    return local_
end

local function _validatePlayer(playerID)
    if playerID == nil or playerID < 0 then
        print("[LON_Test] No valid player ID (Game.GetLocalPlayer() == -1?). Pass an explicit ID, e.g. lon_test_grant_pp(0).")
        return nil
    end
    local p = Players[playerID]
    if p == nil or not p:IsAlive() then
        print(string.format("[LON_Test] Player %d not alive.", playerID))
        return nil
    end
    return p
end

-- M1: Founding gate ---------------------------------------------------------

-- Grant Printing Press to a major civ. Uses SetResearchProgress so the engine
-- fires Events.ResearchCompleted naturally, exercising the LON_Founding hook.
-- Defaults to the local player.
function lon_test_grant_pp(playerID)
    playerID = _resolvePlayerID(playerID)
    local p = _validatePlayer(playerID); if p == nil then return end

    local techRow = GameInfo.Technologies[LON_Config.FOUNDING_TECH]
    if techRow == nil then
        print("[LON_Test] " .. tostring(LON_Config.FOUNDING_TECH) .. " not in GameInfo.Technologies.")
        return
    end

    local ok, err = pcall(function()
        local techs = p:GetTechs()
        local cost = techs:GetResearchCost(techRow.Index)
        techs:SetResearchProgress(techRow.Index, cost)
    end)
    if not ok then
        print("[LON_Test] Failed to grant tech: " .. tostring(err))
        return
    end
    print(string.format("[LON_Test] Granted %s to player %d. Watch for founding if met-all-civs is satisfied.",
        LON_Config.FOUNDING_TECH, playerID))
end

-- Bypass the founding gate entirely. Force-founds with playerID as host.
-- Use this when you want to test post-founding behavior without satisfying
-- the gate (e.g., when met-all-civs is hard to set up).
function lon_test_force_found(playerID)
    playerID = _resolvePlayerID(playerID)
    if _validatePlayer(playerID) == nil then return end
    LON_Founding.ForceFoundForTesting(playerID)
    print(string.format("[LON_Test] Force-founded with host=%d. Run lon_test_dump() to verify.", playerID))
end

-- Reset founding state. After this you can re-test the gate without starting
-- a new game.
function lon_test_reset_founding()
    LON_Founding.ResetForTesting()
    print("[LON_Test] Founding state reset. Try lon_test_grant_pp(0) again.")
end

-- M2: Delegates / Host change -----------------------------------------------

-- Force a host change to playerID. Exercises the host-changed pub/sub:
-- LON_Delegates should recompute the host bonus.
function lon_test_change_host(newHostID)
    if newHostID == nil then
        print("[LON_Test] Usage: lon_test_change_host(playerID)")
        return
    end
    if _validatePlayer(newHostID) == nil then return end
    LON_Founding.SetHostForTesting(newHostID)
    print(string.format("[LON_Test] Host changed to %d. Run lon_debug_delegates() to verify the host bonus moved.",
        newHostID))
end

-- Force a delegate-cache recompute. Useful after manually mutating state via
-- other tuner panels (e.g., after granting techs or changing suzerainties).
function lon_test_recompute_delegates()
    if LON_Delegates ~= nil and LON_Delegates.RecomputeAll ~= nil then
        LON_Delegates.RecomputeAll()
        print("[LON_Test] Delegates recomputed.")
    else
        print("[LON_Test] LON_Delegates not loaded.")
    end
end

-- M3: Sessions / proposals --------------------------------------------------

-- Pick a random eligible resolution for playerID and submit it via LON_Session.
-- Stand-in for the M3.6 UI panel — lets a human player submit without UI.
function lon_test_pick_random(playerID)
    playerID = _resolvePlayerID(playerID)
    if _validatePlayer(playerID) == nil then return end
    if LON_Proposals == nil or LON_AI == nil or LON_Session == nil then
        print("[LON_Test] Required modules not loaded.")
        return
    end
    local pool = LON_Proposals.GetEligiblePoolFor(playerID)
    if #pool == 0 then
        print(string.format("[LON_Test] Empty pool for player %d.", playerID))
        return
    end
    local pick = LON_AI.PickProposal(playerID, pool)
    if pick == nil then
        print("[LON_Test] AI.PickProposal returned nil.")
        return
    end
    local ok = LON_Session.SubmitProposal(playerID, pick.hash)
    print(string.format("[LON_Test] player %d submitted %s (accepted=%s)",
        playerID, pick.resolutionType, tostring(ok)))
end

-- Force-begin a new session: snapshot proposers, clear picks, auto-submit AI.
-- Useful when force-founding mid-game and you want session state populated
-- without waiting for WorldCongressFinished.
function lon_test_begin_session()
    if LON_Session == nil or LON_Session.BeginSession == nil then
        print("[LON_Test] LON_Session not loaded.")
        return
    end
    LON_Session.BeginSession()
    print("[LON_Test] BeginSession called. Run lon_debug_session() to inspect.")
end

-- Inspection ----------------------------------------------------------------

-- Print full LON state in one shot.
function lon_test_dump()
    print("=== LON State Dump ===")

    local foundedStr = "?"; local hostStr = "?"; local turnStr = "?"
    if LON_Founding ~= nil then
        foundedStr = tostring(LON_Founding.HasFounded())
        hostStr    = tostring(LON_Founding.GetHostPlayerID())
        turnStr    = tostring(LON_Founding.GetFoundingTurn())
    end
    print(string.format("Founded: %s   Host: %s   Founding turn: %s", foundedStr, hostStr, turnStr))

    print("--- Delegates ---")
    if lon_debug_delegates ~= nil then lon_debug_delegates() else print("(LON_Delegates not loaded)") end

    print("--- Session ---")
    if lon_debug_session ~= nil then lon_debug_session() else print("(LON_Session not loaded)") end

    print("--- CanUseResolutions hook ---")
    if lon_debug_canuse_fires ~= nil then lon_debug_canuse_fires() else print("(LON_Proposals not loaded)") end

    print("--- Local player ---")
    local lp = (Game.GetLocalPlayer and Game.GetLocalPlayer()) or -1
    print(string.format("Local player ID: %d", lp))
    if lp >= 0 then
        local pcfg = PlayerConfigurations[lp]
        if pcfg ~= nil then
            local nameKey = pcfg:GetCivilizationDescription()
            print(string.format("Local civ: %s", nameKey ~= nil and Locale.Lookup(nameKey) or "?"))
        end
    end

    print("======================")
end

-- Help ----------------------------------------------------------------------

-- Print every command this harness exposes.
function lon_test_help()
    print("=== LON Test Harness Commands ===")
    print("Defaults: playerID arg defaults to Game.GetLocalPlayer() if omitted.")
    print("")
    print("M1 — Founding")
    print("  lon_test_grant_pp(playerID)        grant Printing Press; triggers natural founding flow")
    print("  lon_test_force_found(playerID)     bypass gate; force-found with playerID as host")
    print("  lon_test_reset_founding()          clear founded state; re-test gate without new game")
    print("")
    print("M2 — Delegates")
    print("  lon_test_change_host(newHostID)    force host change; exercises pub/sub")
    print("  lon_test_recompute_delegates()     force a cache rebuild")
    print("")
    print("M3 — Proposals / Sessions")
    print("  lon_debug_proposers()              current Host + second-place proposer with counts")
    print("  lon_debug_pool(playerID)           era-eligible resolution pool for that civ")
    print("  lon_debug_session()                current session state: proposers, picks, hashes")
    print("  lon_test_begin_session()           force-snapshot proposers, auto-submit AI picks")
    print("  lon_test_pick_random(playerID)     submit a random eligible pick (UI stand-in)")
    print("")
    print("Inspection")
    print("  lon_test_dump()                    full state snapshot in one shot")
    print("  lon_debug_delegates()              delegate breakdown only")
    print("  lon_debug_canuse_fires()           CanUseResolutions fire count only")
    print("  lon_test_help()                    this message")
    print("=================================")
end

-- Auto-actions --------------------------------------------------------------
-- Run scripted test actions at a configured turn. Lets the user playtest
-- without FireTuner: edit LON_Config.AUTO_*_AT_TURN, restart Civ 6, observe
-- Lua.log. Each action fires at most once per game.

local _autoActionsFired = {}

local function _maybeRunAutoActionsForTurn(turn)
    if not LON_Config.DEV_MODE then return end
    local local_ = (Game.GetLocalPlayer and Game.GetLocalPlayer()) or -1
    if local_ < 0 then return end

    if LON_Config.AUTO_FORCE_FOUND_AT_TURN ~= nil
        and turn >= LON_Config.AUTO_FORCE_FOUND_AT_TURN
        and not _autoActionsFired.force_found then
        _autoActionsFired.force_found = true
        print(string.format("[LON_Test][AUTO] turn %d: lon_test_force_found(%d)", turn, local_))
        lon_test_force_found(local_)
    end

    if LON_Config.AUTO_GRANT_PP_AT_TURN ~= nil
        and turn >= LON_Config.AUTO_GRANT_PP_AT_TURN
        and not _autoActionsFired.grant_pp then
        _autoActionsFired.grant_pp = true
        print(string.format("[LON_Test][AUTO] turn %d: lon_test_grant_pp(%d)", turn, local_))
        lon_test_grant_pp(local_)
    end

    if LON_Config.AUTO_DUMP_AT_TURN ~= nil
        and turn >= LON_Config.AUTO_DUMP_AT_TURN
        and not _autoActionsFired.dump then
        _autoActionsFired.dump = true
        print(string.format("[LON_Test][AUTO] turn %d: lon_test_dump()", turn))
        lon_test_dump()
    end
end

local function _onLocalPlayerTurnBegin()
    local turn = (Game.GetCurrentGameTurn and Game.GetCurrentGameTurn()) or -1
    if turn < 0 then return end
    _maybeRunAutoActionsForTurn(turn)
end

-- Init ----------------------------------------------------------------------

local function _initialize()
    if not LON_Config.DEV_MODE then
        return  -- silent in release builds
    end

    -- Banner so the user can confirm the harness is loaded.
    LON_Log("INFO", "LON_TestHarness loaded (DEV_MODE on)")
    LON_Log("INFO", "  Available: lon_test_help, _grant_pp, _force_found, _reset_founding,")
    LON_Log("INFO", "             _change_host, _recompute_delegates, _dump")

    -- Report any configured auto-actions so the user knows what's queued.
    if LON_Config.AUTO_FORCE_FOUND_AT_TURN then
        LON_Log("INFO", "  AUTO: force-found at turn " .. tostring(LON_Config.AUTO_FORCE_FOUND_AT_TURN))
    end
    if LON_Config.AUTO_GRANT_PP_AT_TURN then
        LON_Log("INFO", "  AUTO: grant Printing Press at turn " .. tostring(LON_Config.AUTO_GRANT_PP_AT_TURN))
    end
    if LON_Config.AUTO_DUMP_AT_TURN then
        LON_Log("INFO", "  AUTO: dump state at turn " .. tostring(LON_Config.AUTO_DUMP_AT_TURN))
    end

    if Events ~= nil and Events.LocalPlayerTurnBegin ~= nil then
        local ok, err = pcall(function() Events.LocalPlayerTurnBegin.Add(_onLocalPlayerTurnBegin) end)
        if not ok then
            LON_Log("WARN", "LON_TestHarness: failed to register LocalPlayerTurnBegin: " .. tostring(err))
        end
    end
end

_initialize()
