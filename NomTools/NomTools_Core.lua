local addonName, ns = ...

local eventFrame = CreateFrame("Frame")
local addOnLoader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local getAddOnEnableState = (C_AddOns and C_AddOns.GetAddOnEnableState) or GetAddOnEnableState
local addonEnableStateAll = Enum and Enum.AddOnEnableState and Enum.AddOnEnableState.All or 2
local playerName = (UnitNameUnmodified and UnitNameUnmodified("player")) or (UnitName and UnitName("player")) or nil
local REFRESH_MODULE_ORDER = {
    "consumables",
    "objectiveTracker",
    "menuBar",
    "reminders",
    "dungeonDifficulty",
    "greatVault",
    "talentLoadout",
    "characterStats",
    "miscellaneous",
    "classesMonk",
    "worldQuests",
    "debugOverlay",
    "launchers",
    "options",
}
local REFRESH_MODULE_SET = {
    consumables = true,
    objectiveTracker = true,
    menuBar = true,
    reminders = true,
    dungeonDifficulty = true,
    greatVault = true,
    talentLoadout = true,
    characterStats = true,
    miscellaneous = true,
    classesMonk = true,
    worldQuests = true,
    debugOverlay = true,
    launchers = true,
    options = true,
}
local pendingRefreshModules = {}
local refreshFlushScheduled = false
local loadedModuleAddons = {}
local MODULE_ADDONS = {
    options = {
        addonName = "NomTools_Options",
    },
    miscellaneous = {
        addonName = "NomTools_Miscellaneous",
        initializerCallbacks = { "InitializeMenuBarUI", "InitializeCharacterStatsUI" },
    },
    consumables = {
        addonName = "NomTools_Consumables",
        initializers = {
            { stepName = "Consumables UI initialization", callbackName = "InitializeConsumablesModule" },
        },
    },
    objectiveTracker = {
        addonName = "NomTools_ObjectiveTracker",
        initializers = {
            { stepName = "Objective tracker UI initialization", callbackName = "InitializeObjectiveTrackerUI" },
        },
    },
    reminders = {
        addonName = "NomTools_Reminders",
        initializers = {
            { stepName = "Dungeon difficulty UI initialization", callbackName = "InitializeDungeonDifficultyUI" },
            { stepName = "Great Vault UI initialization", callbackName = "InitializeGreatVaultUI" },
            { stepName = "Talent loadout UI initialization", callbackName = "InitializeTalentLoadoutUI" },
        },
    },
    classes = {
        addonName = "NomTools_Classes",
        initializers = {
            { stepName = "Classes module initialization", callbackName = "InitializeClassesModule" },
        },
    },
    housing = {
        addonName = "NomTools_Housing",
        initializers = {
            { stepName = "Housing module initialization", callbackName = "InitializeHousingModule" },
        },
    },
    worldQuests = {
        addonName = "NomTools_WorldQuests",
        initializers = {
            { stepName = "World Quests module initialization", callbackName = "InitializeWorldQuestsModule" },
        },
    },
}
local MODULE_DEFINITIONS = {
    consumables = {
        addonKey = "consumables",
        refreshCallbackName = "RefreshUI",
    },
    objectiveTracker = {
        addonKey = "objectiveTracker",
        refreshCallbackName = "RefreshObjectiveTrackerUI",
    },
    menuBar = {
        addonKey = "miscellaneous",
        refreshCallbackName = "RefreshMenuBarUI",
    },
    reminders = {
        addonKey = "reminders",
        refreshCallbackName = "RefreshRemindersUI",
    },
    dungeonDifficulty = {
        addonKey = "reminders",
        refreshCallbackName = "RefreshDungeonDifficultyUI",
    },
    greatVault = {
        addonKey = "reminders",
        refreshCallbackName = "RefreshGreatVaultUI",
    },
    talentLoadout = {
        addonKey = "reminders",
        refreshCallbackName = "RefreshTalentLoadoutUI",
    },
    characterStats = {
        addonKey = "miscellaneous",
        refreshCallbackName = "RefreshCharacterStatsUI",
    },
    miscellaneous = {
        addonKey = "miscellaneous",
        refreshCallbackName = "RefreshMiscellaneousUI",
    },
    classesMonk = {
        addonKey = "classes",
        refreshCallbackName = "RefreshMonkChiBar",
    },
    housing = {
        addonKey = "housing",
        refreshCallbackName = "RefreshHousingModule",
    },
    worldQuests = {
        addonKey = "worldQuests",
        refreshCallbackName = "RefreshWorldQuestsUI",
    },
    debugOverlay = {
        refreshCallbackName = "RefreshDebugOverlay",
    },
    launchers = {
        refreshCallbackName = "RefreshLauncherUI",
    },
    options = {
        addonKey = "options",
        refreshCallbackName = "RefreshOptionsPanel",
    },
}
local OPTIONS_PAGE_DEPENDENCIES = {
    consumables = "consumables",
    consumables_general = "consumables",
    consumables_tracking = "consumables",
    consumables_appearance = "consumables",
    objective_tracker = "objectiveTracker",
    objective_tracker_general = "objectiveTracker",
    objective_tracker_layout = "objectiveTracker",
    objective_tracker_appearance = "objectiveTracker",
    objective_tracker_sections = "objectiveTracker",
    classes_general = "classesMonk",
    classes_monk = "classesMonk",
    reminders_general = "reminders",
    great_vault = "greatVault",
    dungeon_difficulty = "dungeonDifficulty",
    talent_loadout = "talentLoadout",
    housing = "housing",
    reminders_appearance = "reminders",
    miscellaneous = "miscellaneous",
    menu_bar = "miscellaneous",
    world_quests = "worldQuests",
}

local function RunNamedCallback(stepName, callback)
    if type(callback) ~= "function" then
        return true
    end

    local ok, err = pcall(callback)
    if not ok then
        geterrorhandler()(string.format("NomTools %s failed: %s", stepName, tostring(err)))
        return false
    end

    return true
end

local function IsModuleConfiguredEnabled(moduleKey)
    if ns.IsModuleConfiguredEnabled then
        return ns.IsModuleConfiguredEnabled(moduleKey)
    end

    return true
end

local function IsModuleRefreshAllowed(moduleKey)
    if moduleKey == "debugOverlay" or moduleKey == "launchers" or moduleKey == "options" then
        return true
    end

    return ns.IsModuleRuntimeEnabled == nil
        or ns.IsModuleRuntimeEnabled(moduleKey, IsModuleConfiguredEnabled(moduleKey))
end

local function IsModuleAddonLoaded(addonKey)
    local descriptor = addonKey and MODULE_ADDONS[addonKey] or nil
    local moduleAddonName = descriptor and descriptor.addonName or nil
    return moduleAddonName and isAddOnLoaded and isAddOnLoaded(moduleAddonName) or false
end

local function GetAddonAvailability(moduleAddonName)
    if type(moduleAddonName) ~= "string" or moduleAddonName == "" then
        return false, false, "This module addon is unavailable."
    end

    if getAddOnEnableState and playerName then
        local ok, enabledState = pcall(getAddOnEnableState, moduleAddonName, playerName)
        if ok and enabledState ~= nil and enabledState ~= addonEnableStateAll then
            return false, true, "Disabled in the Blizzard AddOns panel. Re-enable it there and reload the UI to use this module."
        end
    end

    return true, false, nil
end

local function GetModuleAddonKey(moduleKey)
    if MODULE_ADDONS[moduleKey] then
        return moduleKey
    end

    local definition = moduleKey and MODULE_DEFINITIONS[moduleKey] or nil
    return definition and definition.addonKey or nil
end

local function GetModuleAddonStatus(moduleKey)
    local addonKey = GetModuleAddonKey(moduleKey)
    local descriptor = addonKey and MODULE_ADDONS[addonKey] or nil
    if not descriptor then
        return true, false, nil
    end

    return GetAddonAvailability(descriptor.addonName)
end

local function EnsureModuleAddonLoaded(addonKey)
    local descriptor = MODULE_ADDONS[addonKey]
    if not descriptor then
        return true
    end

    local moduleAddonName = descriptor.addonName
    if not moduleAddonName or moduleAddonName == "" then
        return false
    end

    local isAvailable, isExternallyDisabled, unavailableReason = GetAddonAvailability(moduleAddonName)
    if not isAvailable then
        if not isExternallyDisabled and unavailableReason then
            geterrorhandler()(string.format("NomTools failed to load %s: %s", moduleAddonName, unavailableReason))
        end
        return false
    end

    if not IsModuleAddonLoaded(addonKey) then
        if not addOnLoader then
            return false
        end

        local loaded, reason = addOnLoader(moduleAddonName)
        if loaded ~= true and not IsModuleAddonLoaded(addonKey) then
            if reason and reason ~= "DISABLED" then
                geterrorhandler()(string.format("NomTools failed to load %s: %s", moduleAddonName, tostring(reason)))
            end
            return false
        end
    end

    if loadedModuleAddons[addonKey] then
        return true
    end

    for _, initializer in ipairs(descriptor.initializers or {}) do
        if not RunNamedCallback(initializer.stepName, ns[initializer.callbackName]) then
            return false
        end
    end

    for _, callbackName in ipairs(descriptor.initializerCallbacks or {}) do
        if not RunNamedCallback(callbackName, ns[callbackName]) then
            return false
        end
    end

    loadedModuleAddons[addonKey] = true
    return true
end

function ns.EnsureModuleImplementation(moduleKey)
    local definition = moduleKey and MODULE_DEFINITIONS[moduleKey] or nil
    if definition and definition.addonKey then
        return EnsureModuleAddonLoaded(definition.addonKey)
    end

    return true
end

function ns.IsModuleImplementationLoaded(moduleKey)
    local definition = moduleKey and MODULE_DEFINITIONS[moduleKey] or nil
    if not definition or not definition.addonKey then
        return true
    end

    return IsModuleAddonLoaded(definition.addonKey)
end

function ns.IsModuleAddonAvailable(moduleKey)
    local isAvailable = GetModuleAddonStatus(moduleKey)
    return isAvailable
end

function ns.IsModuleAddonExternallyDisabled(moduleKey)
    local _, isExternallyDisabled = GetModuleAddonStatus(moduleKey)
    return isExternallyDisabled == true
end

function ns.GetModuleAddonUnavailableReason(moduleKey)
    local isAvailable, _, unavailableReason = GetModuleAddonStatus(moduleKey)
    if isAvailable then
        return nil
    end

    return unavailableReason
end

function ns.EnsureOptionsPageDependencies(pageKey)
    local moduleKey = pageKey and OPTIONS_PAGE_DEPENDENCIES[pageKey] or nil
    if moduleKey then
        return ns.EnsureModuleImplementation(moduleKey)
    end

    return true
end

local function RequestRefreshModule(moduleKey, target)
    local definition = MODULE_DEFINITIONS[moduleKey]
    if definition and not IsModuleRefreshAllowed(moduleKey) then
        if target then
            target[moduleKey] = nil
        end
        return
    end

    if moduleKey == "options" and not ns.IsModuleImplementationLoaded(moduleKey) then
        if target then
            target[moduleKey] = nil
        end
        return
    end

    if definition and definition.addonKey and not ns.EnsureModuleImplementation(moduleKey) then
        if target then
            target[moduleKey] = nil
        end
        return
    end

    local refreshCallback = definition and definition.refreshCallbackName and ns[definition.refreshCallbackName] or nil
    if type(refreshCallback) == "function" then
        refreshCallback()
    end

    if target then
        target[moduleKey] = nil
    end
end

local collectRequestedScratch = {}
local collectRequested
local collectRequestedCount

local function CollectAddModule(moduleKey)
    if moduleKey == "all" then
        for _, refreshModuleKey in ipairs(REFRESH_MODULE_ORDER) do
            if not collectRequested[refreshModuleKey] then
                collectRequested[refreshModuleKey] = true
                collectRequestedCount = collectRequestedCount + 1
            end
        end
        return
    end

    if REFRESH_MODULE_SET[moduleKey] and not collectRequested[moduleKey] then
        collectRequested[moduleKey] = true
        collectRequestedCount = collectRequestedCount + 1
    end
end

local function CollectAddValue(value)
    if type(value) == "string" then
        CollectAddModule(value)
    elseif type(value) == "table" then
        for _, nestedValue in ipairs(value) do
            CollectAddValue(nestedValue)
        end
    end
end

local function CollectRequestedRefreshModules(...)
    collectRequested = collectRequestedScratch
    for k in pairs(collectRequested) do collectRequested[k] = nil end
    collectRequestedCount = 0

    local argumentCount = select("#", ...)
    if argumentCount == 0 then
        CollectAddModule("all")
    else
        for argumentIndex = 1, argumentCount do
            CollectAddValue(select(argumentIndex, ...))
        end
    end

    return collectRequested, collectRequestedCount
end

local function HasPendingRefreshModules()
    return next(pendingRefreshModules) ~= nil
end

local flushScratch = {}

local function FlushPendingRefreshes()
    if InCombatLockdown() then
        ns.pendingRefresh = true
        return false
    end

    if not HasPendingRefreshModules() then
        ns.pendingRefresh = false
        return true
    end

    local modulesToRefresh = flushScratch
    for k in pairs(modulesToRefresh) do modulesToRefresh[k] = nil end
    for k, v in pairs(pendingRefreshModules) do
        modulesToRefresh[k] = v
    end
    for k in pairs(pendingRefreshModules) do pendingRefreshModules[k] = nil end
    ns.pendingRefresh = false

    for _, moduleKey in ipairs(REFRESH_MODULE_ORDER) do
        if modulesToRefresh[moduleKey] then
            RequestRefreshModule(moduleKey, modulesToRefresh)
        end
    end

    return true
end

local function RunFlush()
    refreshFlushScheduled = false
    if not FlushPendingRefreshes() then
        ns.pendingRefresh = HasPendingRefreshModules()
    end
end

local function SchedulePendingRefreshFlush()
    if refreshFlushScheduled then
        return
    end

    if InCombatLockdown() then
        ns.pendingRefresh = true
        return
    end

    refreshFlushScheduled = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, RunFlush)
    else
        RunFlush()
    end
end

function ns.RequestRefresh(...)
    local requestedModules, requestedCount = CollectRequestedRefreshModules(...)
    if requestedCount == 0 then
        return
    end

    for moduleKey in pairs(requestedModules) do
        pendingRefreshModules[moduleKey] = true
    end

    ns.pendingRefresh = true
    SchedulePendingRefreshFlush()
end

local function EnsureOptionsWindow()
    if ns.ShowOptionsWindow and ns.optionsWindow then
        return true
    end

    if ns.EnsureModuleImplementation and not ns.EnsureModuleImplementation("options") then
        return false
    end

    if ns.InitializeOptions then
        local ok, err = pcall(ns.InitializeOptions)
        if not ok then
            geterrorhandler()(err)
            return false
        end
    end

    return ns.ShowOptionsWindow ~= nil and ns.optionsWindow ~= nil
end

local function OpenRegisteredOptions(pageKey)
    if not EnsureOptionsWindow() then
        print("NomTools: failed to initialize the options window.")
        return false
    end

    ns.ShowOptionsWindow(pageKey)
    return true
end

function ns.OpenOptions(pageKey)
    if not ns.IsSetupComplete() and ns.ShowSetupWizard then
        ns.ShowSetupWizard()
        return
    end

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        if HideUIPanel then
            HideUIPanel(EditModeManagerFrame)
        else
            EditModeManagerFrame:Hide()
        end

        C_Timer.After(0, function()
            OpenRegisteredOptions(pageKey)
        end)
        return
    end

    OpenRegisteredOptions(pageKey)
end

function ns.ApplyModuleRuntimeState(moduleKey)
    local definition = moduleKey and MODULE_DEFINITIONS[moduleKey] or nil
    if not definition then
        return true
    end

    if definition.addonKey and not ns.IsModuleImplementationLoaded(moduleKey) then
        if IsModuleConfiguredEnabled(moduleKey) and ns.IsModuleRuntimeEnabled(moduleKey, true) then
            return ns.EnsureModuleImplementation(moduleKey)
        end

        return true
    end

    local refreshCallback = definition.refreshCallbackName and ns[definition.refreshCallbackName] or nil
    if type(refreshCallback) == "function" then
        return RunNamedCallback(moduleKey .. " runtime apply", refreshCallback)
    end

    return true
end

function ns.InitializeGameMenuButton()
    if not GameMenuFrame then
        return
    end

    if ns.gameMenuButton then
        if ns.RefreshGameMenuButton then
            ns.RefreshGameMenuButton()
        end
        return
    end

    local button = CreateFrame("Button", addonName .. "GameMenuButton", GameMenuFrame, "MainMenuFrameButtonTemplate")
    button:SetText("NomTools")
    button:SetScript("OnClick", function()
        if HideUIPanel then
            HideUIPanel(GameMenuFrame)
        else
            GameMenuFrame:Hide()
        end

        ns.OpenOptions()
    end)

    ns.gameMenuButton = button
    GameMenuFrame.NomToolsButton = button

    local baseHeight
    local buttonSpacing = 0

    local function GetAnchorButton()
        local fallbackButton

        if GameMenuFrame.buttonPool and GameMenuFrame.buttonPool.EnumerateActive then
            for menuButton in GameMenuFrame.buttonPool:EnumerateActive() do
                if menuButton ~= button and menuButton.IsShown and menuButton:IsShown() then
                    local text = menuButton.GetText and menuButton:GetText() or nil
                    if text == GAMEMENU_OPTIONS then
                        return menuButton
                    end

                    if not fallbackButton and text == BLIZZARD_STORE then
                        fallbackButton = menuButton
                    end
                end
            end
        end

        return fallbackButton or GameMenuButtonOptions or GameMenuButtonUIOptions or GameMenuButtonStore
    end

    local function LayoutButton()
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        if ns.db and ns.db.showGameMenuButton == false then
            button:Hide()
            if baseHeight then
                GameMenuFrame:SetHeight(baseHeight)
            end
            return
        end

        local anchorButton = GetAnchorButton()
        if not anchorButton then
            button:Hide()
            return
        end

        if not baseHeight then
            baseHeight = GameMenuFrame:GetHeight()
        end

        local buttonWidth = anchorButton:GetWidth() or 144
        local buttonHeight = anchorButton:GetHeight() or 20
        local verticalShift = buttonHeight + buttonSpacing

        button:SetSize(buttonWidth, buttonHeight)
        button:SetText("NomTools")
        button:ClearAllPoints()
        button:SetPoint("TOP", anchorButton, "BOTTOM", 0, -buttonSpacing)
        button:Show()

        local anchorBottom = anchorButton:GetBottom()
        if anchorBottom and GameMenuFrame.buttonPool and GameMenuFrame.buttonPool.EnumerateActive then
            for menuButton in GameMenuFrame.buttonPool:EnumerateActive() do
                if menuButton ~= anchorButton and menuButton ~= button and menuButton.IsShown and menuButton:IsShown() then
                    local top = menuButton:GetTop()
                    if top and top < anchorBottom + 2 then
                        local point, relativeTo, relativePoint, offsetX, offsetY = menuButton:GetPoint(1)
                        if point then
                            menuButton:ClearAllPoints()
                            menuButton:SetPoint(point, relativeTo, relativePoint, offsetX or 0, (offsetY or 0) - verticalShift)
                        end
                    end
                end
            end
        end

        GameMenuFrame:SetHeight(baseHeight + verticalShift)
    end

    ns.RefreshGameMenuButton = LayoutButton
    hooksecurefunc(GameMenuFrame, "Layout", LayoutButton)
    LayoutButton()
end

local function Trim(text)
    return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function HandleSlashCommand(message)
    local command = Trim(message):lower()

    if command == "" or command == "options" then
        ns.OpenOptions()
        return
    end

    if command == "refresh" then
        if ns.ResetStandaloneWindowPositions then
            ns.ResetStandaloneWindowPositions()
        end
        ns.RequestRefresh()
        return
    end

    if command == "setup" then
        if ns.ResetSetupWizard then
            ns.ResetSetupWizard()
        end
        if ns.ShowSetupWizard then
            ns.ShowSetupWizard()
        end
        return
    end

    if command == "help" then
        print("NomTools Commands:")
        print("  /nomtools, /nom, /nt - open the settings panel")
        print("  /nomtools refresh - force refresh all modules")
        print("  /nomtools setup - re-run the setup wizard")
        return
    end

    print("Unknown command. Type /nomtools help for a list of commands.")
end

local function RegisterSlashCommands()
    SLASH_NOMTOOLS1 = "/nomtools"
    SLASH_NOMTOOLS2 = "/nomtool"
    SLASH_NOMTOOLS3 = "/nom"
    SLASH_NOMTOOLS4 = "/nt"
    SlashCmdList.NOMTOOLS = HandleSlashCommand
end

local function SafeCall(stepName, callback)
    return RunNamedCallback(stepName, callback)
end

local function EnsureMiscellaneousImplementationIfNeeded()
    if IsModuleConfiguredEnabled("miscellaneous") or IsModuleConfiguredEnabled("characterStats") then
        ns.EnsureModuleImplementation("miscellaneous")
    end
end

local function EnsureMiscellaneousAutomationImplementationIfNeeded()
    if IsModuleConfiguredEnabled("miscellaneous") then
        ns.EnsureModuleImplementation("miscellaneous")
    end
end

local function ShowLoadedMessage()
    print("NomTools: Loaded. Type /nomtools help for commands")
end

local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then
            return
        end

        if ns.InitializeDatabase then
            ns.InitializeDatabase()
        end

        RegisterSlashCommands()

        SafeCall("game menu button initialization", ns.InitializeGameMenuButton)
        SafeCall("launcher UI initialization", ns.InitializeLauncherUI)

        SafeCall("Consumables addon initialization", function()
            if IsModuleConfiguredEnabled("consumables") then
                ns.EnsureModuleImplementation("consumables")
            end
        end)
        SafeCall("Objective tracker addon initialization", function()
            if IsModuleConfiguredEnabled("objectiveTracker") then
                ns.EnsureModuleImplementation("objectiveTracker")
            end
        end)
        SafeCall("Miscellaneous addon initialization", EnsureMiscellaneousImplementationIfNeeded)
        SafeCall("Great Vault addon initialization", function()
            if IsModuleConfiguredEnabled("greatVault") then
                ns.EnsureModuleImplementation("greatVault")
            end
        end)
        SafeCall("Dungeon difficulty addon initialization", function()
            if IsModuleConfiguredEnabled("dungeonDifficulty") then
                ns.EnsureModuleImplementation("dungeonDifficulty")
            end
        end)
        SafeCall("Classes addon initialization", function()
            if IsModuleConfiguredEnabled("classesMonk") then
                ns.EnsureModuleImplementation("classesMonk")
            end
        end)
        SafeCall("Housing addon initialization", function()
            if IsModuleConfiguredEnabled("housing") then
                ns.EnsureModuleImplementation("housing")
            end
        end)

        ns.RequestRefresh()

        if C_Timer and C_Timer.After then
            C_Timer.After(1, ShowLoadedMessage)
        else
            ShowLoadedMessage()
        end
        return
    end

    if event == "PLAY_MOVIE" then
        local movieID = ...
        EnsureMiscellaneousAutomationImplementationIfNeeded()
        if ns.HandlePlayMovie then
            ns.HandlePlayMovie(movieID)
        end
        return
    end

    if event == "CINEMATIC_START" then
        EnsureMiscellaneousAutomationImplementationIfNeeded()
        if ns.HandleCinematicStart then
            ns.HandleCinematicStart()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if ns.pendingRefresh then
            SchedulePendingRefreshFlush()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        local showedSetupWizard = false
        if ns.TryShowSetupWizard then
            showedSetupWizard = ns.TryShowSetupWizard() == true
        end

        local showedSettingsPrompt = false
        if ns.TryShowPostSetupSettingsPrompt then
            showedSettingsPrompt = ns.TryShowPostSetupSettingsPrompt() == true
        end

        if not showedSetupWizard and not showedSettingsPrompt and ns.TryShowChangelogPopup then
            ns.TryShowChangelogPopup()
        end

        if not ns.isEditMode then
            ns.RequestRefresh("launchers")
        end
        return
    end

    if event == "PLAYER_LOGOUT" then
        if ns.CommitHousingSettings then
            ns.CommitHousingSettings()
        end
        if ns.CaptureObjectiveTrackerUIState then
            ns.CaptureObjectiveTrackerUIState()
        end
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        if not ns.isEditMode then
            ns.RequestRefresh("launchers")
        end
        return
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CINEMATIC_START")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAY_MOVIE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", OnEvent)
