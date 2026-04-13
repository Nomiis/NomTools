local _, ns = ...

do
    local CHANGELOG_POPUP_WIDTH = 560
    local CHANGELOG_POPUP_HEIGHT = 440
    local CHANGELOG_POPUP_MODE_CHOICES = {
        { key = "off", name = "Off" },
        { key = "important", name = "Important Only" },
        { key = "all", name = "All Updates" },
    }

    -- Keep the newest entry first. This table is intended to be edited by hand.
    local CHANGELOG_ENTRIES = {
        {
            id = 2026041401,
            title = "1.2.0 - 14 April 2026",
            description = "Objective Tracker gains search, filtering, and sorting, along with zone grouping. Housing gets an auto-confirm option and a multi-buy error fix.",
            important = true,
            sections = {
                {
                    title = "Objective Tracker",
                    bullets = {
                        { text = "Added search, filtering, and sorting to the objective tracker", new = true },
                        { text = "Added an option to group quests by zone", new = true },
                        "Fixed an issue causing the objective tracker to be wider than intended",
                        "Fixed several visual inconsistencies and improved visuals",
                    },
                    new = {
                        optionRows = {
                            {
                                page = "objective_tracker_general",
                                label = "Filter Button",
                            },
                            {
                                page = "objective_tracker_general",
                                label = "Group Quests by Zone",
                            },
                            {
                                page = "objective_tracker_sections",
                                label = "Show Search Bar Section",
                            },
                        },
                    },
                },
                {
                    title = "Housing",
                    bullets = {
                        { text = "Added an option to auto-confirm decor purchases", new = true },
                        "Potentially fixed an issue causing an error when multi-buying decor items",
                    },
                    new = {
                        optionRows = {
                            {
                                page = "housing",
                                label = "Auto-Confirm Decor Purchase Prompts",
                            },
                        },
                    },
                },
                {
                    title = "World Quests",
                    bullets = {
                        "Added a Reset Filters button to the filter dropdown",
                    },
                },
            },
        },
        {
            id = 2026041301,
            title = "1.1.0 - 13 April 2026",
            description = "World Quests received major quality and performance fixes, with additional Objective Tracker, Classes, Housing, Miscellaneous, and Reminders updates.",
            important = true,
            sections = {
                {
                    title = "General",
                    bullets = {
                        "Improved addon structure for better long-term maintainability across modules.",
                    },
                },
                {
                    title = "Options Panel",
                    bullets = {
                        "Adjusted slider values for clearer and more consistent control ranges.",
                        "Layout improvements across the options UI.",
                    },
                },
                {
                    title = "World Quests",
                    bullets = {
                        "World Quest list now includes special assignments, with a filter option for them.",
                        "Added an option to select which maps to scan.",
                        "Improved World Quests visuals for clearer readability.",
                        "Implemented significant performance improvements for World Quests updates and list handling.",
                        "Fixed an issue causing constant World Quests background updates while the map was closed.",
                        "Fixed an issue causing completed quests to not always be removed correctly.",
                        "Fixed an issue causing rewards to sometimes fail to load.",
                        "Fixed an issue causing rewards to sometimes display incorrect information.",
                        "Note: older zones and special assignments may still show incorrect information; a fix is coming soon.",
                    },
                    new = {
                        pages = { "world_quests" },
                        optionRows = {
                            {
                                page = "world_quests",
                                label = "Enabled Maps",
                            },
                        },
                    },
                },
                {
                    title = "Objective Tracker",
                    bullets = {
                        "Added title color options for Important and Meta quests.",
                        "Moved Header Bar options under Appearance for clearer organization.",
                    },
                },
                {
                    title = "Classes",
                    bullets = {
                        "Added the new Classes module.",
                        "Added Monk as the first class implementation.",
                        "Added a segmented Brewmaster Expel Harm tracker bar with attachment and customization options, attached above the stagger bar by default.",
                    },
                    new = {
                        pages = { "classes_general", "classes_monk" },
                        optionRows = {
                            {
                                page = "classes_general",
                                label = "Enable Classes Module",
                            },
                            {
                                page = "classes_monk",
                                label = "Enable Monk Module",
                            },
                            {
                                page = "classes_monk",
                                label = "Enable Brewmaster Expel Harm Bar",
                            },
                        },
                    },
                },
                {
                    title = "Housing",
                    bullets = {
                        "Fixed a critical issue that could wipe housing data when using Reset to Defaults on the housing page.",
                        "Fixed an issue where decor could be sorted or marked incorrectly if the game was closed before going home after earning new decor.",
                    },
                },
                {
                    title = "Miscellaneous",
                    bullets = {
                        "Split Other features into the dedicated Miscellaneous module.",
                        "Added character stats display features.",
                        "Moved Menu Bar options under Miscellaneous.",
                    },
                    new = {
                        pages = { "miscellaneous_general", "menu_bar" },
                        optionRows = {
                            {
                                page = "miscellaneous_general",
                                label = "Enable Miscellaneous Module",
                            },
                        },
                    },
                },
                {
                    title = "Reminders",
                    bullets = {
                        "Consolidated Great Vault and Dungeon Difficulty reminders into one configurable Reminders module.",
                        "Added talent page reminders.",
                        "Consolidated reminder to use unified appearance options."
                    },
                    new = {
                        pages = { "reminders_appearance", "talent_loadout" },
                        optionRows = {
                            {
                                page = "talent_loadout",
                                label = "Enable Talent Loadout Reminder",
                            },
                        },
                    },
                },
                {
                    title = "Other",
                    bullets = {
                        "Various other small fixes and changes.",
                    },
                },
            },
        },
        {
            id = 2026041002,
            title = "1.0.2 - 10 April 2026",
            description = "Changelog support and NEW indicators are now in place, alongside additional World Quests fixes and options.",
            important = true,
            sections = {
                {
                    title = "General",
                    bullets = {
                        "Added changelogs.",
                        "Added NEW indicators for new functionality.",
                        "Note: Changelog popup settings can be found on the Change Log options page."
                    },
                },
                {
                    title = "World Quests",
                    bullets = {
                        "Added an optional setting to the World Quests module that always opens the World Map directly on the World Quests tab when enabled.",
                        "Fixed an issue causing World Quest List's zone sorting to not always correctly apply.",
                        "Fixed an issue causing World Quests to not immediately get removed from the list upon expiration.",
                    },
                    new = {
                        pages = {},
                    },
                },
            },
        },
        {
            id = 2026041001,
            title = "1.0.1 - 10 April 2026",
            description = "A substantial settings panel refresh with clearer layout, broader border controls, and World Quests, Reminders, and Consumables improvements.",
            important = true,
            sections = {
                {
                    title = "Settings Panel",
                    bullets = {
                        "Significant layout changes and improvements to the settings panel.",
                        "It should be a lot more clear and easy to use now.",
                        "Layout is not entirely final and may have additional small adjustments in the coming days.",
                    },
                },
                {
                    title = "General",
                    bullets = {
                        "Added border texture options.",
                        "Added finer controls for borders - now supports outward as well as inward size growth.",
                        "Fixed an issue causing some borders to display incorrectly.",
                        "Fixed an issue causing dropdowns to not always update properly.",
                        "Various other small fixes and improvements.",
                    },
                },
                {
                    title = "World Quests",
                    bullets = {
                        "Added the ability to sort zones by time remaining in the World Quest list rather than only alphabetically. Sort by time remaining is the new default.",
                    },
                },
                {
                    title = "Reminders & Consumables",
                    bullets = {
                        "Added option to turn off reminder accents when using Custom preset.",
                        "Added border settings to reminders and consumables.",
                    },
                },
            },
        },
    }

    local newTagRegistry
    local popupFrame
    local popupShownThisSession = false
    local popupExplicitHidePending = false
    local popupReopenScheduled = false

    local function NormalizePopupMode(popupMode)
        if popupMode == "off" or popupMode == "all" then
            return popupMode
        end

        return "important"
    end

    local function NormalizeEntryId(entryId)
        return tonumber(entryId) or 0
    end

    local function NormalizeTagText(tagText)
        if type(tagText) ~= "string" then
            return nil
        end

        tagText = tagText:gsub("^%s+", ""):gsub("%s+$", "")
        if tagText == "" then
            return nil
        end

        return tagText:gsub("%s+", " "):lower()
    end

    local function NormalizePageKey(pageKey)
        if type(pageKey) ~= "string" then
            return nil
        end

        pageKey = pageKey:gsub("^%s+", ""):gsub("%s+$", "")
        if pageKey == "" then
            return nil
        end

        return pageKey
    end

    local function GetChangelogSettingsTable()
        if ns.GetChangelogSettings then
            return ns.GetChangelogSettings()
        end

        if not ns.db then
            return {
                popupMode = "important",
                lastSeenEntryId = 0,
            }
        end

        if type(ns.db.changelog) ~= "table" then
            ns.db.changelog = {}
        end

        return ns.db.changelog
    end

    local function AddPageTag(pageTags, pageKey)
        local normalizedPageKey = NormalizePageKey(pageKey)
        if normalizedPageKey then
            pageTags[normalizedPageKey] = true
        end
    end

    local function AddOptionTag(optionTags, pageTags, optionKey)
        if type(optionKey) ~= "string" or optionKey == "" then
            return
        end

        optionTags[optionKey] = true

        local pageKey = optionKey:match("^(.*)%.")
        if pageKey and pageKey ~= "" then
            pageTags[pageKey] = true
        end
    end

    local function AddOptionRowTag(optionRowTags, pageTags, rowData)
        if type(rowData) ~= "table" then
            return
        end

        local pageKey = NormalizePageKey(rowData.page)
        local labelKey = NormalizeTagText(rowData.label)
        if not pageKey or not labelKey then
            return
        end

        if type(optionRowTags[pageKey]) ~= "table" then
            optionRowTags[pageKey] = {}
        end

        optionRowTags[pageKey][labelKey] = true
        pageTags[pageKey] = true
    end

    local function AddTagBlock(optionTags, pageTags, optionRowTags, tagBlock)
        if type(tagBlock) ~= "table" then
            return
        end

        for _, optionKey in ipairs(tagBlock.options or {}) do
            AddOptionTag(optionTags, pageTags, optionKey)
        end

        for _, optionRow in ipairs(tagBlock.optionRows or {}) do
            AddOptionRowTag(optionRowTags, pageTags, optionRow)
        end

        for _, pageKey in ipairs(tagBlock.pages or {}) do
            AddPageTag(pageTags, pageKey)
        end
    end

    local function BuildNewTagRegistry()
        local optionTags = {}
        local pageTags = {}
        local optionRowTags = {}

        local entry = CHANGELOG_ENTRIES[1]
        if entry then
            AddTagBlock(optionTags, pageTags, optionRowTags, entry.new)

            for _, section in ipairs(entry.sections or {}) do
                AddTagBlock(optionTags, pageTags, optionRowTags, section.new)
            end
        end

        return {
            options = optionTags,
            pages = pageTags,
            optionRows = optionRowTags,
        }
    end

    local function GetNewTagRegistry()
        if not newTagRegistry then
            newTagRegistry = BuildNewTagRegistry()
        end

        return newTagRegistry
    end

    local function BuildEntryBodyText(entry)
        local lines = {}
        local bulletPrefix = "\226\128\162 "
        local newTag = "|cffffd100[NEW]|r "

        for index, section in ipairs(entry and entry.sections or {}) do
            if type(section.title) == "string" and section.title ~= "" then
                lines[#lines + 1] = "|cffffd100" .. section.title .. "|r"
            end

            for _, bullet in ipairs(section.bullets or {}) do
                local bulletText, isNew
                if type(bullet) == "table" then
                    bulletText = bullet.text
                    isNew = bullet.new == true
                else
                    bulletText = bullet
                    isNew = false
                end

                if type(bulletText) == "string" and bulletText ~= "" then
                    if isNew then
                        lines[#lines + 1] = bulletPrefix .. newTag .. bulletText
                    else
                        lines[#lines + 1] = bulletPrefix .. bulletText
                    end
                end
            end

            if index < #(entry.sections or {}) then
                lines[#lines + 1] = ""
            end
        end

        return table.concat(lines, "\n")
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

    local function EnsureNewFeatureBadge(target)
        if not target then
            return nil
        end

        if target.nomtoolsNewFeatureBadge then
            return target.nomtoolsNewFeatureBadge
        end

        local badge = CreateFrame("Frame", nil, target)

        local shadow = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal_NoShadow")
        shadow:SetText(NEW_CAPS or "NEW")
        if NEW_FEATURE_SHADOW_COLOR then
            shadow:SetTextColor(NEW_FEATURE_SHADOW_COLOR:GetRGBA())
        else
            shadow:SetTextColor(0, 0, 0, 0.8)
        end

        local label = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetText(NEW_CAPS or "NEW")
        label:SetPoint("CENTER", badge, "CENTER", 0, 0)
        if NEW_FEATURE_SHADOW_COLOR then
            label:SetShadowColor(NEW_FEATURE_SHADOW_COLOR:GetRGBA())
        end

        shadow:SetPoint("CENTER", label, "CENTER", 0.5, -0.5)

        local glow = badge:CreateTexture(nil, "OVERLAY", nil, 0)
        glow:SetAtlas("collections-newglow")
        glow:SetPoint("TOPLEFT", label, "TOPLEFT", -20, 10)
        glow:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 20, -10)
        glow:SetAlpha(0.7)

        badge:SetSize(label:GetStringWidth() + 4, label:GetStringHeight() + 2)
        badge.label = label
        badge.shadow = shadow
        badge.glow = glow
        target.nomtoolsNewFeatureBadge = badge
        return badge
    end

    local function IsChangelogPopupEntryEligible(entry)
        if not entry then
            return false
        end

        if ns.IsSetupComplete and not ns.IsSetupComplete() then
            return false
        end

        local settings = GetChangelogSettingsTable()
        local popupMode = NormalizePopupMode(settings.popupMode)
        settings.popupMode = popupMode

        if popupMode == "off" then
            return false
        end

        if popupMode == "important" and entry.important ~= true then
            return false
        end

        if NormalizeEntryId(settings.lastSeenEntryId) == NormalizeEntryId(entry.id) then
            return false
        end

        return true
    end

    local function ScheduleChangelogPopupReopen()
        if popupReopenScheduled or not popupFrame or not IsChangelogPopupEntryEligible(popupFrame.entry) then
            return
        end

        popupReopenScheduled = true

        local function reopenPopup()
            popupReopenScheduled = false

            if not popupFrame or popupFrame:IsShown() then
                return
            end

            if not IsChangelogPopupEntryEligible(popupFrame.entry) then
                return
            end

            ns.ShowChangelogPopup(popupFrame.entry)
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0, reopenPopup)
        else
            reopenPopup()
        end
    end

    local function HideChangelogPopup(markSeen, isExplicit)
        if not popupFrame then
            return
        end

        popupExplicitHidePending = isExplicit == true

        if markSeen and popupFrame.entry then
            ns.MarkChangelogEntrySeen(popupFrame.entry.id)
        end

        popupFrame:Hide()
    end

    local function OpenChangeLogFromPopup()
        HideChangelogPopup(true, true)

        if ns.OpenOptions then
            ns.OpenOptions("change_log")
        end
    end

    local function CreatePopupFrame()
        popupFrame = CreateFrame("Frame", "NomToolsChangelogPopup", UIParent, "BasicFrameTemplateWithInset")
        popupFrame:SetSize(CHANGELOG_POPUP_WIDTH, CHANGELOG_POPUP_HEIGHT)
        popupFrame:SetPoint("CENTER")
        popupFrame:SetFrameStrata("DIALOG")
        popupFrame:SetFrameLevel(505)
        popupFrame:SetToplevel(true)
        popupFrame:SetClampedToScreen(true)
        popupFrame:EnableKeyboard(true)
        AttachFrameDragHandle(popupFrame)

        if popupFrame.Inset then
            popupFrame.Inset:Hide()
        end
        if popupFrame.Bg then
            popupFrame.Bg:SetAlpha(0.92)
        end
        if popupFrame.InsetBg then
            popupFrame.InsetBg:SetAlpha(0)
        end

        if popupFrame.TitleText then
            popupFrame.TitleText:SetText("NomTools Change Log")
            local fontPath, fontSize = popupFrame.TitleText:GetFont()
            if fontPath and fontSize then
                popupFrame.TitleText:SetFont(fontPath, fontSize + 1, "OUTLINE")
            end
        end

        EnsureSpecialFrameRegistered(popupFrame:GetName())

        popupFrame:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                HideChangelogPopup(true, true)
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)

        popupFrame:HookScript("OnHide", function()
            local wasExplicit = popupExplicitHidePending == true
            popupExplicitHidePending = false

            if not wasExplicit then
                ScheduleChangelogPopupReopen()
            end
        end)

        if popupFrame.CloseButton then
            popupFrame.CloseButton:SetScript("OnClick", function()
                HideChangelogPopup(true, true)
            end)
        end

        local contentHost = CreateFrame("Frame", nil, popupFrame, "InsetFrameTemplate3")
        contentHost:SetPoint("TOPLEFT", popupFrame, "TOPLEFT", 8, -28)
        contentHost:SetPoint("BOTTOMRIGHT", popupFrame, "BOTTOMRIGHT", -8, 8)
        if ns.ApplyDefaultPanelChrome then
            ns.ApplyDefaultPanelChrome(contentHost)
        end
        popupFrame.contentHost = contentHost

        local entryTitle = contentHost:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        entryTitle:SetPoint("TOPLEFT", contentHost, "TOPLEFT", 18, -18)
        entryTitle:SetPoint("TOPRIGHT", contentHost, "TOPRIGHT", -18, -18)
        entryTitle:SetJustifyH("LEFT")
        entryTitle:SetTextColor(1.0, 0.82, 0.0)
        do
            local fontPath, fontSize = entryTitle:GetFont()
            if fontPath and fontSize then
                entryTitle:SetFont(fontPath, fontSize + 1, "OUTLINE")
            end
        end
        popupFrame.entryTitle = entryTitle

        local importanceLabel = contentHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        importanceLabel:SetPoint("TOPRIGHT", contentHost, "TOPRIGHT", -18, -20)
        importanceLabel:SetText("Important Update")
        importanceLabel:SetTextColor(1.0, 0.82, 0.0)
        popupFrame.importanceLabel = importanceLabel

        local description = contentHost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        description:SetPoint("TOPLEFT", contentHost, "TOPLEFT", 18, -52)
        description:SetPoint("TOPRIGHT", contentHost, "TOPRIGHT", -18, -52)
        description:SetJustifyH("LEFT")
        description:SetJustifyV("TOP")
        description:SetTextColor(0.82, 0.82, 0.82)
        popupFrame.description = description

        local scrollFrame = CreateFrame("ScrollFrame", nil, contentHost, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", contentHost, "TOPLEFT", 14, -116)
        scrollFrame:SetPoint("BOTTOMRIGHT", contentHost, "BOTTOMRIGHT", -30, 50)
        popupFrame.scrollFrame = scrollFrame

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(1, 1)
        scrollFrame:SetScrollChild(scrollChild)
        popupFrame.scrollChild = scrollChild

        local bodyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bodyText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        bodyText:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
        bodyText:SetWidth(470)
        bodyText:SetJustifyH("LEFT")
        bodyText:SetJustifyV("TOP")
        bodyText:SetSpacing(2)
        bodyText:SetTextColor(0.82, 0.82, 0.82)
        popupFrame.bodyText = bodyText

        local openButton = CreateFrame("Button", nil, contentHost, "UIPanelButtonTemplate")
        openButton:SetSize(148, 28)
        openButton:SetPoint("BOTTOMRIGHT", contentHost, "BOTTOM", -8, 14)
        openButton:SetText("Open Change Log")
        openButton:SetScript("OnClick", OpenChangeLogFromPopup)
        popupFrame.openButton = openButton

        local dismissButton = CreateFrame("Button", nil, contentHost, "UIPanelButtonTemplate")
        dismissButton:SetSize(148, 28)
        dismissButton:SetPoint("BOTTOMLEFT", contentHost, "BOTTOM", 8, 14)
        dismissButton:SetText("Dismiss")
        dismissButton:SetScript("OnClick", function()
            HideChangelogPopup(true, true)
        end)
        popupFrame.dismissButton = dismissButton
    end

    function ns.GetChangelogEntries()
        return CHANGELOG_ENTRIES
    end

    function ns.GetLatestChangelogEntry()
        return CHANGELOG_ENTRIES[1]
    end

    function ns.GetChangelogEntryBodyText(entry)
        return BuildEntryBodyText(entry)
    end

    function ns.GetChangelogPopupModeChoices()
        return CHANGELOG_POPUP_MODE_CHOICES
    end

    function ns.GetChangelogPopupMode()
        local settings = GetChangelogSettingsTable()
        settings.popupMode = NormalizePopupMode(settings.popupMode)
        return settings.popupMode
    end

    function ns.IsNewTaggedOption(optionKey)
        return GetNewTagRegistry().options[optionKey] == true
    end

    function ns.IsNewTaggedOptionRow(pageKey, labelText)
        local normalizedPageKey = NormalizePageKey(pageKey)
        local normalizedLabel = NormalizeTagText(labelText)
        if not normalizedPageKey or not normalizedLabel then
            return false
        end

        local pageRows = GetNewTagRegistry().optionRows[normalizedPageKey]
        return type(pageRows) == "table" and pageRows[normalizedLabel] == true
    end

    function ns.IsNewTaggedPage(pageKey)
        return GetNewTagRegistry().pages[pageKey] == true
    end

    function ns.IsAnyNewTaggedPage(pageKeys)
        if type(pageKeys) ~= "table" then
            return false
        end

        for _, pageKey in ipairs(pageKeys) do
            if ns.IsNewTaggedPage(pageKey) then
                return true
            end
        end

        return false
    end

    function ns.SetNewFeatureBadgeShown(target, shown, options)
        if not target then
            return nil
        end

        local badge = EnsureNewFeatureBadge(target)
        if not badge then
            return nil
        end

        local relativeTo = options and options.relativeTo or target
        local point = options and options.point or "LEFT"
        local relativePoint = options and options.relativePoint or "RIGHT"
        local xOffset = options and options.x or 0
        local yOffset = options and options.y or 0
        local relativeLevel = relativeTo and relativeTo.GetFrameLevel and relativeTo:GetFrameLevel() or nil
        local targetLevel = target.GetFrameLevel and target:GetFrameLevel() or 0

        badge:ClearAllPoints()
        badge:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
        badge:SetFrameLevel((relativeLevel or targetLevel or 0) + (options and options.frameLevelOffset or 8))
        badge:SetShown(shown == true)
        return badge
    end

    function ns.MarkChangelogEntrySeen(entryId)
        local resolvedId = NormalizeEntryId(entryId)

        if ns.SetChangelogSetting then
            ns.SetChangelogSetting("lastSeenEntryId", resolvedId)
            return
        end

        GetChangelogSettingsTable().lastSeenEntryId = resolvedId
    end

    function ns.ShouldShowChangelogPopup()
        if popupShownThisSession then
            return false
        end

        local entry = ns.GetLatestChangelogEntry()
        return IsChangelogPopupEntryEligible(entry)
    end

    function ns.ResetChangelogPopupWindowPositions()
        ResetStandaloneFramePosition(popupFrame)
    end

    function ns.ShowChangelogPopup(entry)
        entry = entry or ns.GetLatestChangelogEntry()
        if not entry then
            return
        end

        if not popupFrame then
            CreatePopupFrame()
        end

        popupFrame.entry = entry
        popupFrame.entryTitle:SetText(entry.title or "Change Log")
        popupFrame.importanceLabel:SetShown(entry.important == true)

        local hasDescription = type(entry.description) == "string" and entry.description ~= ""
        popupFrame.description:SetShown(hasDescription)
        popupFrame.description:SetText(hasDescription and entry.description or "")

        local bodyText = BuildEntryBodyText(entry)
        popupFrame.bodyText:SetText(bodyText)
        popupFrame.scrollChild:SetWidth((popupFrame.scrollFrame:GetWidth() or 470) - 4)
        popupFrame.scrollChild:SetHeight(math.max(popupFrame.bodyText:GetStringHeight() or 0, 1))
        popupFrame.scrollFrame:SetVerticalScroll(0)
        popupFrame:Show()
        popupFrame:Raise()
    end

    function ns.TryShowChangelogPopup()
        if not ns.ShouldShowChangelogPopup() then
            return false
        end

        popupShownThisSession = true

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                ns.ShowChangelogPopup(ns.GetLatestChangelogEntry())
            end)
        else
            ns.ShowChangelogPopup(ns.GetLatestChangelogEntry())
        end

        return true
    end
end