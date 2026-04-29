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
    print("Inspection")
    print("  lon_test_dump()                    full state snapshot in one shot")
    print("  lon_debug_delegates()              delegate breakdown only")
    print("  lon_debug_canuse_fires()           CanUseResolutions fire count only")
    print("  lon_test_help()                    this message")
    print("=================================")
end

-- Init ----------------------------------------------------------------------

local function _initialize()
    LON_Log("INFO", "LON_TestHarness loaded — type lon_test_help() in FireTuner")
end

_initialize()
