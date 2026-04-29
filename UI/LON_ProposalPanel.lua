-- LON_ProposalPanel.lua
-- League of Nations — UI panel for human proposers to pick a resolution.
-- Loaded by Civ 6 in the InGame UI context (see modinfo <AddUserInterfaces>).
--
-- Cross-context bridge:
--   Gameplay (LON_Session) fires LuaEvents.LON_OpenProposalPanel(playerID, poolData)
--   -> this UI script renders.
--   On confirm: this UI fires LuaEvents.LON_ProposalPanel_Submitted(playerID, resolutionHash, resolutionType)
--   -> LON_Session listens and commits the pick.
--
-- The pool payload is passed in via the LuaEvent so the UI doesn't have to
-- call back across contexts to query it. Each entry is the same shape
-- LON_Proposals.GetEligiblePoolFor returns:
--   { resolutionType, hash, name, targetKind, effect1, effect2 }

include("InstanceManager")

local m_resolutionIM = InstanceManager:new("ResolutionItem", "Root", Controls.ResolutionStack)
local m_currentPlayerID = -1

-- Render -------------------------------------------------------------------

local function _renderPool(pool)
    m_resolutionIM:ResetInstances()
    if pool == nil then return end

    for _, entry in ipairs(pool) do
        local instance = m_resolutionIM:GetInstance()

        -- Some resolution Name strings include a {1_Target} substitution slot.
        -- We don't have target picked yet (engine resolves it via AITargetChooser),
        -- so use the bare locale string; trailing format slots remain literal.
        if entry.name ~= nil and entry.name ~= "" then
            instance.NameLabel:LocalizeAndSetText(entry.name)
        else
            instance.NameLabel:SetText(entry.resolutionType or "?")
        end
        if entry.effect1 ~= nil and entry.effect1 ~= "" then
            instance.Effect1Label:LocalizeAndSetText(entry.effect1)
        else
            instance.Effect1Label:SetText("")
        end
        if entry.effect2 ~= nil and entry.effect2 ~= "" then
            instance.Effect2Label:LocalizeAndSetText(entry.effect2)
        else
            instance.Effect2Label:SetText("")
        end

        local hash = entry.hash
        local rtype = entry.resolutionType
        instance.SelectButton:RegisterCallback(Mouse.eLClick, function()
            LuaEvents.LON_ProposalPanel_Submitted(m_currentPlayerID, hash, rtype)
            UIManager:DequeuePopup(ContextPtr)
        end)
    end
end

-- Open / close -------------------------------------------------------------

local function Open(playerID, pool)
    m_currentPlayerID = playerID
    _renderPool(pool)
    UIManager:QueuePopup(ContextPtr, PopupPriority.Current, { AlwaysVisibleInQueue = true })
end

local function Close()
    UIManager:DequeuePopup(ContextPtr)
end

-- Event hooks --------------------------------------------------------------

local function _onOpenRequested(playerID, pool)
    -- Only the player whose proposal it is gets the panel — for hot-seat / MP.
    if playerID ~= Game.GetLocalPlayer() then return end
    Open(playerID, pool)
end

local function _onCancel()
    Close()
end

local function OnInputHandler(inputStruct)
    if ContextPtr:IsHidden() then return false end
    local uiMsg = inputStruct:GetMessageType()
    if uiMsg == KeyEvents.KeyUp then
        local key = inputStruct:GetKey()
        if key == Keys.VK_ESCAPE then
            Close()
            return true
        end
    end
    return false
end

-- Init ---------------------------------------------------------------------

local function Initialize()
    ContextPtr:SetHide(true)
    ContextPtr:SetInputHandler(OnInputHandler, true)
    Controls.CancelButton:RegisterCallback(Mouse.eLClick, _onCancel)

    LuaEvents.LON_OpenProposalPanel.Add(_onOpenRequested)
end

Initialize()
