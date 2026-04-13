local addonName, ns = ...

local BUTTON_SIZE = 31
local BUTTON_BORDER_SIZE = 53
local BUTTON_ICON_INSET = 6

local minimapButton
local addonCompartmentEntry
local addonCompartmentRegistered = false

local function GetLauncherSettings()
    if ns.GetGlobalSettings then
        return ns.GetGlobalSettings()
    end

    return ns.DEFAULTS and ns.DEFAULTS.globalSettings or {}
end

local function ShouldShowMinimapButton()
    return GetLauncherSettings().showMinimapButton ~= false
end

local function ShouldShowAddonCompartment()
    return GetLauncherSettings().showAddonCompartment ~= false
end

local function OpenOptions()
    if ns.OpenOptions then
        ns.OpenOptions()
    end
end

local function GetLauncherIcon()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local iconTexture = C_AddOns.GetAddOnMetadata(addonName, "IconTexture")
        if type(iconTexture) == "string" and iconTexture ~= "" then
            return iconTexture
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ShowTooltip(owner)
    if not owner or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("NomTools", 1, 1, 1)
    GameTooltip:AddLine("Click to open settings.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function EnsureMinimapButton()
    local minimap = _G.Minimap
    if not minimap then
        return nil
    end

    if minimapButton then
        return minimapButton
    end

    local button = CreateFrame("Button", addonName .. "MinimapButton", minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((minimap:GetFrameLevel() or 0) + 8)
    button:SetPoint("TOPLEFT", minimap, "TOPLEFT", -2, 2)
    button:RegisterForClicks("AnyUp")
    button:SetScript("OnClick", OpenOptions)
    button:SetScript("OnEnter", function(self)
        ShowTooltip(self)
    end)
    button:SetScript("OnLeave", HideTooltip)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    background:SetTexture("Interface\\Minimap\\MiniMap-TrackingBackground")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", BUTTON_ICON_INSET, -BUTTON_ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BUTTON_ICON_INSET, BUTTON_ICON_INSET)
    icon:SetTexture(GetLauncherIcon())
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(BUTTON_BORDER_SIZE, BUTTON_BORDER_SIZE)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    minimapButton = button
    return button
end

local function RefreshMinimapButton()
    local button = EnsureMinimapButton()
    if not button then
        return
    end

    if button.icon then
        button.icon:SetTexture(GetLauncherIcon())
    end

    if ShouldShowMinimapButton() then
        button:Show()
    else
        button:Hide()
    end
end

local function EnsureAddonCompartmentEntry()
    if addonCompartmentEntry then
        addonCompartmentEntry.icon = GetLauncherIcon()
        return addonCompartmentEntry
    end

    addonCompartmentEntry = {
        text = "NomTools",
        icon = GetLauncherIcon(),
        notCheckable = true,
        registerForAnyClick = true,
        func = function()
            OpenOptions()
        end,
        funcOnEnter = function(button)
            if MenuUtil and MenuUtil.ShowTooltip then
                MenuUtil.ShowTooltip(button, function(tooltip)
                    tooltip:AddLine("NomTools")
                    tooltip:AddLine("Click to open settings.", 0.8, 0.8, 0.8)
                end)
                return
            end

            ShowTooltip(button)
        end,
        funcOnLeave = function(button)
            if MenuUtil and MenuUtil.HideTooltip then
                MenuUtil.HideTooltip(button)
                return
            end

            HideTooltip()
        end,
    }

    return addonCompartmentEntry
end

local function RegisterAddonCompartment()
    local compartment = _G.AddonCompartmentFrame
    if not compartment or addonCompartmentRegistered then
        return
    end

    compartment:RegisterAddon(EnsureAddonCompartmentEntry())
    addonCompartmentRegistered = true
end

local function UnregisterAddonCompartment()
    local compartment = _G.AddonCompartmentFrame
    if not compartment or not addonCompartmentRegistered then
        return
    end

    local registeredAddons = compartment.registeredAddons
    if type(registeredAddons) == "table" then
        for index = #registeredAddons, 1, -1 do
            if registeredAddons[index] == addonCompartmentEntry then
                table.remove(registeredAddons, index)
                if compartment.UpdateDisplay then
                    compartment:UpdateDisplay()
                end
                break
            end
        end
    end

    addonCompartmentRegistered = false
end

local function RefreshAddonCompartment()
    if ShouldShowAddonCompartment() then
        RegisterAddonCompartment()
    else
        UnregisterAddonCompartment()
    end
end

function ns.InitializeLauncherUI()
    EnsureMinimapButton()
    if ns.RefreshLauncherUI then
        ns.RefreshLauncherUI()
    end
end

function ns.RefreshLauncherUI()
    RefreshMinimapButton()
    RefreshAddonCompartment()
end