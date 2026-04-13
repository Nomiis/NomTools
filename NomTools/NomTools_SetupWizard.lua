local _, ns = ...

do
    local WIZARD_WIDTH = 520
    local WIZARD_MODULE_SPACING = 50
    local WIZARD_FRAME_HORIZONTAL_PADDING = 8
    local WIZARD_FRAME_VERTICAL_PADDING = 36
    local POST_SETUP_SETTINGS_PROMPT_PENDING_KEY = "_postSetupSettingsPromptPending"
    local wizardFrame
    local settingsPromptFrame
    local setupWizardShownThisSession = false
    local settingsPromptShownThisSession = false
    local settingsPromptPendingThisSession = false
    local wizardExplicitHidePending = false
    local settingsPromptExplicitHidePending = false
    local wizardReopenScheduled = false
    local settingsPromptReopenScheduled = false
    local previousSetupComplete

    local WIZARD_RELEASE_TAGS = {
        alpha = {
            text = "(Alpha)",
            color = { 0.96, 0.40, 0.40 },
            tooltip = "May not work as intended.",
        },
        beta = {
            text = "(Beta)",
            color = { 0.49, 0.78, 1.00 },
            tooltip = "May contain minor issues.",
        },
        experimental = {
            text = "(Experimental)",
            color = { 1.00, 0.63, 0.26 },
            tooltip = "May not be functional.",
        },
        prerelease = {
            text = "(Pre-Release)",
            color = { 0.63, 0.95, 0.55 },
            tooltip = "Mostly stable.",
        },
    }

    local WIZARD_MODULES = {
        {
            key = "objectiveTracker",
            dbKey = "objectiveTracker",
            name = "Objective Tracker",
            releaseTag = "beta",
            desc = "Adds a scrollbar and typography, colors, and organization customization to the quest tracker.",
        },
        {
            key = "consumables",
            dbKey = nil,
            name = "Consumables Reminder",
            releaseTag = "prerelease",
            desc = "Shows clickable reminders for flasks, food, weapon buffs, and runes.",
        },
        {
            key = "housing",
            dbKey = "housing",
            name = "Housing",
            releaseTag = "prerelease",
            desc = "Tracks new housing items and improves inventory sorting.",
        },
        {
            key = "worldQuests",
            dbKey = "worldQuests",
            name = "World Quests",
            releaseTag = "beta",
            desc = "Adds a world quest tab to your map with filters, search, and sorting.",
        },
        {
            key = "classesMonk",
            dbPath = { "classes" },
            name = "Classes",
            releaseTag = "prerelease",
            desc = "Enables class modules for class specific features.",
        },
        {
            key = "reminders",
            dbPath = { "reminders" },
            name = "Reminders",
            releaseTag = "",
            desc = "Dungeon difficulty, Great Vault, and Talent Loadout reminders for instance content.",
        },
        {
            key = "miscellaneous",
            dbKey = "miscellaneous",
            name = "Miscellaneous",
            releaseTag = "",
            desc = "Cutscene automation, menu bar positioning, and a customizable character stats display.",
        },
    }

    local function GetReleaseTagInfo(tagKey)
        if type(tagKey) ~= "string" or tagKey == "" then
            return nil
        end

        return WIZARD_RELEASE_TAGS[string.lower(tagKey)]
    end

    local function ShowReleaseTagTooltip(owner, tagInfo)
        if not owner or not tagInfo or not GameTooltip then
            return
        end

        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(tagInfo.text, tagInfo.color[1], tagInfo.color[2], tagInfo.color[3])
        GameTooltip:AddLine(tagInfo.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end

    local function HideReleaseTagTooltip()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end

    ---@param moduleInfo table
    ---@return table|nil
    local function GetWizardModuleSettingsTable(moduleInfo)
        if not ns.db or type(moduleInfo) ~= "table" then
            return nil
        end

        if type(moduleInfo.dbPath) == "table" then
            local current = ns.db
            for _, key in ipairs(moduleInfo.dbPath) do
                if type(current[key]) ~= "table" then
                    current[key] = {}
                end
                current = current[key]
            end
            return current
        end

        if type(moduleInfo.dbKey) == "string" and moduleInfo.dbKey ~= "" then
            if type(ns.db[moduleInfo.dbKey]) ~= "table" then
                ns.db[moduleInfo.dbKey] = {}
            end
            return ns.db[moduleInfo.dbKey]
        end

        return nil
    end

    ---@param moduleInfo table
    ---@param enabled boolean
    local function SetWizardModuleEnabled(moduleInfo, enabled)
        local settingsTable = GetWizardModuleSettingsTable(moduleInfo)
        if settingsTable then
            settingsTable.enabled = enabled and true or false
            return
        end

        if ns.db then
            ns.db.enabled = enabled and true or false
        end
    end

    local function ApplyWizardSelections(checkboxes)
        if not ns.db then
            return
        end

        local shouldPromptSettingsAfterReload = previousSetupComplete ~= true and ns.db.setupComplete ~= true

        for _, entry in ipairs(checkboxes) do
            local mod = entry.moduleInfo
            local enabled = entry.checkbox:GetChecked() and true or false
            SetWizardModuleEnabled(mod, enabled)
        end

        wizardExplicitHidePending = true
        ns.db.setupComplete = true
        ns.db[POST_SETUP_SETTINGS_PROMPT_PENDING_KEY] = shouldPromptSettingsAfterReload and true or nil
        ReloadUI()
    end

    function ns.ResetSetupWizard()
        if wizardFrame then
            wizardFrame.restoreSetupOnHide = false
            wizardFrame:Hide()
            wizardFrame = nil
        end
        if ns.db then
            previousSetupComplete = ns.db.setupComplete
            ns.db.setupComplete = false
        end
        setupWizardShownThisSession = false
        settingsPromptShownThisSession = false
        settingsPromptPendingThisSession = false
        wizardExplicitHidePending = false
        settingsPromptExplicitHidePending = false
        wizardReopenScheduled = false
        settingsPromptReopenScheduled = false
    end

    local function RestorePreviousSetupState()
        if previousSetupComplete and ns.db then
            ns.db.setupComplete = previousSetupComplete
        end
        previousSetupComplete = nil
    end

    local function ResetWizardSelections()
        if not wizardFrame or type(wizardFrame.checkboxes) ~= "table" then
            return
        end

        for _, entry in ipairs(wizardFrame.checkboxes) do
            local checkbox = entry and entry.checkbox or nil
            if checkbox and checkbox.SetChecked then
                checkbox:SetChecked(false)
            end
        end
    end

    local function AttachFrameDragHandle(frame)
        if not frame or frame.nomToolsDragHandle then
            return
        end

        frame:EnableMouse(true)
        frame:SetMovable(true)

        local dragHandle = CreateFrame("Frame", nil, frame)
        dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -4)
        dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -4)
        dragHandle:SetHeight(24)
        dragHandle:EnableMouse(true)
        dragHandle:RegisterForDrag("LeftButton")
        dragHandle:SetScript("OnDragStart", function()
            frame:StartMoving()
        end)
        dragHandle:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
        end)

        frame.nomToolsDragHandle = dragHandle
    end

    local function ResetStandaloneFramePosition(frame)
        if not frame then
            return
        end

        if frame.StopMovingOrSizing then
            frame:StopMovingOrSizing()
        end

        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
    end

    local function EnsureSpecialFrameRegistered(frameName)
        if type(frameName) ~= "string" or frameName == "" or type(UISpecialFrames) ~= "table" then
            return
        end

        for _, existingName in ipairs(UISpecialFrames) do
            if existingName == frameName then
                return
            end
        end

        UISpecialFrames[#UISpecialFrames + 1] = frameName
    end

    local function ScheduleWizardReopen()
        if wizardReopenScheduled then
            return
        end

        if ns.IsSetupComplete and ns.IsSetupComplete() then
            return
        end

        wizardReopenScheduled = true

        local function reopenWizard()
            wizardReopenScheduled = false
            if ns.IsSetupComplete and ns.IsSetupComplete() then
                return
            end
            if wizardFrame and wizardFrame:IsShown() then
                return
            end
            ns.ShowSetupWizard()
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0, reopenWizard)
        else
            reopenWizard()
        end
    end

    local function ScheduleSettingsPromptReopen()
        if settingsPromptReopenScheduled or not settingsPromptPendingThisSession then
            return
        end

        settingsPromptReopenScheduled = true

        local function reopenSettingsPrompt()
            settingsPromptReopenScheduled = false
            if not settingsPromptPendingThisSession then
                return
            end
            if settingsPromptFrame and settingsPromptFrame:IsShown() then
                return
            end
            ns.ShowPostSetupSettingsPrompt()
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0, reopenSettingsPrompt)
        else
            reopenSettingsPrompt()
        end
    end

    local function HideWizard(restorePreviousState, isExplicit)
        if not wizardFrame then
            return
        end

        wizardExplicitHidePending = isExplicit == true
        wizardFrame.restoreSetupOnHide = restorePreviousState == true
        wizardFrame:Hide()
    end

    local function HideSettingsPrompt(isExplicit)
        if settingsPromptFrame then
            settingsPromptExplicitHidePending = isExplicit == true
            if isExplicit then
                settingsPromptPendingThisSession = false
            end
            settingsPromptFrame:Hide()
        end
    end

    local function OpenSettingsFromPrompt()
        HideSettingsPrompt(true)
        if ns.OpenOptions then
            ns.OpenOptions()
        end
    end

    function ns.ShowPostSetupSettingsPrompt()
        if settingsPromptFrame then
            settingsPromptFrame:Show()
            return
        end

        settingsPromptFrame = CreateFrame("Frame", "NomToolsPostSetupPrompt", UIParent, "BasicFrameTemplateWithInset")
        settingsPromptFrame:SetSize(456, 148)
        settingsPromptFrame:SetPoint("CENTER")
        settingsPromptFrame:SetFrameStrata("DIALOG")
        settingsPromptFrame:SetFrameLevel(510)
        settingsPromptFrame:SetToplevel(true)
        settingsPromptFrame:SetClampedToScreen(true)
        AttachFrameDragHandle(settingsPromptFrame)
        if settingsPromptFrame.TitleText then
            settingsPromptFrame.TitleText:SetText("NomTools")
        end
        EnsureSpecialFrameRegistered(settingsPromptFrame:GetName())
        settingsPromptFrame:EnableKeyboard(true)
        settingsPromptFrame:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                HideSettingsPrompt(true)
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
        settingsPromptFrame:HookScript("OnHide", function()
            local wasExplicit = settingsPromptExplicitHidePending == true
            settingsPromptExplicitHidePending = false
            if not wasExplicit and settingsPromptPendingThisSession then
                ScheduleSettingsPromptReopen()
            end
        end)

        if settingsPromptFrame.CloseButton then
            settingsPromptFrame.CloseButton:SetScript("OnClick", function()
                HideSettingsPrompt(true)
            end)
        end

        local contentHost = CreateFrame("Frame", nil, settingsPromptFrame, "InsetFrameTemplate3")
        contentHost:SetPoint("TOPLEFT", settingsPromptFrame, "TOPLEFT", 8, -28)
        contentHost:SetPoint("BOTTOMRIGHT", settingsPromptFrame, "BOTTOMRIGHT", -8, 8)
        if ns.ApplyDefaultPanelChrome then
            ns.ApplyDefaultPanelChrome(contentHost)
        end

        local description = contentHost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        description:SetPoint("TOP", contentHost, "TOP", 0, -18)
        description:SetWidth(396)
        description:SetJustifyH("CENTER")
        description:SetText("Would you like to configure NomTools now or later?\nYou can open the settings at any time by typing /nomtools")
        description:SetTextColor(0.82, 0.82, 0.82)

        local openSettingsButton = CreateFrame("Button", nil, contentHost, "UIPanelButtonTemplate")
        openSettingsButton:SetSize(126, 26)
        openSettingsButton:SetPoint("BOTTOMRIGHT", contentHost, "BOTTOM", -6, 14)
        openSettingsButton:SetText("Open Settings")
        openSettingsButton:SetScript("OnClick", OpenSettingsFromPrompt)

        local laterButton = CreateFrame("Button", nil, contentHost, "UIPanelButtonTemplate")
        laterButton:SetSize(126, 26)
        laterButton:SetPoint("BOTTOMLEFT", contentHost, "BOTTOM", 6, 14)
        laterButton:SetText("Later")
        laterButton:SetScript("OnClick", function()
            HideSettingsPrompt(true)
        end)

        settingsPromptFrame:Show()
    end

    function ns.ResetSetupWizardWindowPositions()
        ResetStandaloneFramePosition(wizardFrame)
        ResetStandaloneFramePosition(settingsPromptFrame)
    end

    function ns.ShowSetupWizard()
        if wizardFrame then
            wizardFrame.restoreSetupOnHide = true
            wizardFrame:Show()
            return
        end

        local moduleCount = #WIZARD_MODULES
        local contentHeight = 100 + (moduleCount * WIZARD_MODULE_SPACING) + 80
        local frameHeight = math.max(contentHeight + WIZARD_FRAME_VERTICAL_PADDING, 436)

            wizardFrame = CreateFrame("Frame", "NomToolsSetupWizard", UIParent, "BasicFrameTemplateWithInset")
        wizardFrame:SetSize(WIZARD_WIDTH + (WIZARD_FRAME_HORIZONTAL_PADDING * 2), frameHeight)
        wizardFrame:SetPoint("CENTER")
        wizardFrame:SetFrameStrata("DIALOG")
        wizardFrame:SetFrameLevel(500)
        wizardFrame:SetToplevel(true)
        wizardFrame:SetClampedToScreen(true)
        AttachFrameDragHandle(wizardFrame)
        if wizardFrame.Inset then
            wizardFrame.Inset:Hide()
        end
        if wizardFrame.Bg then
            wizardFrame.Bg:SetAlpha(0.92)
        end
            if wizardFrame.InsetBg then
                wizardFrame.InsetBg:SetAlpha(0)
            end
            if wizardFrame.TitleText then
                wizardFrame.TitleText:SetText("NomTools Setup")
        end
        EnsureSpecialFrameRegistered(wizardFrame:GetName())
        wizardFrame:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                HideWizard(true, true)
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
        wizardFrame:EnableKeyboard(true)
        wizardFrame:HookScript("OnHide", function(self)
            local wasExplicit = wizardExplicitHidePending == true
            wizardExplicitHidePending = false
            if wasExplicit and self.restoreSetupOnHide then
                RestorePreviousSetupState()
                ResetWizardSelections()
            end
            self.restoreSetupOnHide = nil
            if not wasExplicit and not (ns.IsSetupComplete and ns.IsSetupComplete()) then
                ScheduleWizardReopen()
            end
        end)

        if wizardFrame.CloseButton then
            wizardFrame.CloseButton:SetScript("OnClick", function()
                HideWizard(true, true)
            end)
        end

        local contentHost = CreateFrame("Frame", nil, wizardFrame, "InsetFrameTemplate3")
        contentHost:SetPoint("TOPLEFT", wizardFrame, "TOPLEFT", WIZARD_FRAME_HORIZONTAL_PADDING, -28)
        contentHost:SetPoint("BOTTOMRIGHT", wizardFrame, "BOTTOMRIGHT", -WIZARD_FRAME_HORIZONTAL_PADDING, 8)
        if ns.ApplyDefaultPanelChrome then
            ns.ApplyDefaultPanelChrome(contentHost)
        end
        wizardFrame.contentHost = contentHost

        local content = CreateFrame("Frame", nil, contentHost)
        content:SetAllPoints(contentHost)
        wizardFrame.content = content

        local subtitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        subtitle:SetPoint("TOP", content, "TOP", 0, -18)
        subtitle:SetWidth(WIZARD_WIDTH - 60)
        subtitle:SetText("Welcome! Choose which modules to enable.\nYou can change these later with /nomtools.")
        subtitle:SetJustifyH("CENTER")
        subtitle:SetTextColor(0.82, 0.82, 0.82)

        local checkboxes = {}
        local startY = -62
        for index, mod in ipairs(WIZARD_MODULES) do
            local yOff = startY - (index - 1) * WIZARD_MODULE_SPACING
            local tagInfo = GetReleaseTagInfo(mod.releaseTag)

            local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 24, yOff)
            cb:SetSize(26, 26)
            cb:SetChecked(false)

            local nameText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", cb, "RIGHT", 6, 2)
            nameText:SetText(mod.name)
            nameText:SetTextColor(1.00, 0.88, 0.74)

            if tagInfo then
                local tagButton = CreateFrame("Frame", nil, content)
                tagButton:SetPoint("LEFT", nameText, "RIGHT", 6, 0)

                local tagText = tagButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                tagText:SetPoint("LEFT", tagButton, "LEFT", 0, 0)
                tagText:SetText(tagInfo.text)
                tagText:SetTextColor(tagInfo.color[1], tagInfo.color[2], tagInfo.color[3])

                local tagWidth = math.ceil(tagText:GetStringWidth() or 0)
                local tagHeight = math.ceil(tagText:GetStringHeight() or 0)
                tagButton:SetSize(math.max(tagWidth, 1), math.max(tagHeight, 14))
                tagButton:EnableMouse(true)
                tagButton:SetScript("OnEnter", function(self)
                    ShowReleaseTagTooltip(self, tagInfo)
                end)
                tagButton:SetScript("OnLeave", HideReleaseTagTooltip)
            end

            local descText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            descText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
            descText:SetWidth(WIZARD_WIDTH - 80)
            descText:SetJustifyH("LEFT")
            descText:SetText(mod.desc)
            descText:SetTextColor(0.65, 0.65, 0.65)

            checkboxes[index] = { checkbox = cb, moduleInfo = mod }
        end
        wizardFrame.checkboxes = checkboxes

        local enableAllBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        enableAllBtn:SetSize(120, 26)
        enableAllBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOM", -4, 54)
        enableAllBtn:SetText("Enable All")
        enableAllBtn:SetScript("OnClick", function()
            for _, entry in ipairs(checkboxes) do
                entry.checkbox:SetChecked(true)
            end
        end)

        local disableAllBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        disableAllBtn:SetSize(120, 26)
        disableAllBtn:SetPoint("BOTTOMLEFT", content, "BOTTOM", 4, 54)
        disableAllBtn:SetText("Disable All")
        disableAllBtn:SetScript("OnClick", function()
            for _, entry in ipairs(checkboxes) do
                entry.checkbox:SetChecked(false)
            end
        end)

        local continueBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        continueBtn:SetSize(140, 28)
        continueBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOM", -4, 18)
        continueBtn:SetText("Save & Reload")
        continueBtn:SetScript("OnClick", function()
            wizardFrame.restoreSetupOnHide = false
            ApplyWizardSelections(checkboxes)
        end)

        local cancelBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        cancelBtn:SetSize(140, 28)
        cancelBtn:SetPoint("BOTTOMLEFT", content, "BOTTOM", 4, 18)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function()
            HideWizard(true, true)
        end)

        wizardFrame.restoreSetupOnHide = true
        wizardFrame:Show()
    end

    function ns.IsSetupComplete()
        return ns.db and ns.db.setupComplete == true
    end

    function ns.ShouldShowSetupWizard()
        if setupWizardShownThisSession then
            return false
        end
        return not ns.IsSetupComplete()
    end

    function ns.TryShowSetupWizard()
        if not ns.ShouldShowSetupWizard() then
            return false
        end
        ResetWizardSelections()
        setupWizardShownThisSession = true
        ns.ShowSetupWizard()
        return true
    end

    function ns.TryShowPostSetupSettingsPrompt()
        if settingsPromptShownThisSession or not ns.db or ns.db[POST_SETUP_SETTINGS_PROMPT_PENDING_KEY] ~= true then
            return false
        end

        if not ns.IsSetupComplete() then
            return false
        end

        settingsPromptShownThisSession = true
    settingsPromptPendingThisSession = true
        ns.db[POST_SETUP_SETTINGS_PROMPT_PENDING_KEY] = nil

        if C_Timer and C_Timer.After then
            C_Timer.After(0, ns.ShowPostSetupSettingsPrompt)
        else
            ns.ShowPostSetupSettingsPrompt()
        end

        return true
    end
end