local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

local OPTIONS_SCROLL_STEP = 40
local OPTIONS_WINDOW_WIDTH = 1000
local OPTIONS_WINDOW_HEIGHT = 760
local DROPDOWN_MAX_MENU_HEIGHT = 320
local STANDARD_DROPDOWN_WIDTH = 300
local COMPACT_DROPDOWN_WIDTH = 210
local FULL_DROPDOWN_WIDTH = 640
local STANDARD_COLOR_BUTTON_WIDTH = STANDARD_DROPDOWN_WIDTH
local COMPACT_COLOR_BUTTON_WIDTH = 200
local APPEARANCE_COLUMN_WIDTH = 310
local APPEARANCE_RIGHT_COLUMN_X = 348
local ACCENT_R = 1.00
local ACCENT_G = 0.82
local ACCENT_B = 0.00
local ACCENT_TEXT_R = 1.00
local ACCENT_TEXT_G = 0.82
local ACCENT_TEXT_B = 0.00
local ACCENT_SUBTLE_R = 0.82
local ACCENT_SUBTLE_G = 0.82
local ACCENT_SUBTLE_B = 0.82
local SURFACE_BG_R = 0.10
local SURFACE_BG_G = 0.11
local SURFACE_BG_B = 0.13
local SURFACE_BG_A = 0.96
local SURFACE_BORDER_R = 0.28
local SURFACE_BORDER_G = 0.30
local SURFACE_BORDER_B = 0.34
local SURFACE_BORDER_A = 1
local SURFACE_HIGHLIGHT_A = 0.10
local TEXT_VERTICAL_ANCHOR_CHOICES = {
    { key = "top", name = "Top" },
    { key = "bottom", name = "Bottom" },
}
local COUNT_ANCHOR_CHOICES = {
    { key = "top_left", name = "Top Left" },
    { key = "top_right", name = "Top Right" },
    { key = "bottom_left", name = "Bottom Left" },
    { key = "bottom_right", name = "Bottom Right" },
}
local REMINDER_PRESET_CHOICES = {
    { key = "blizzard", name = "Default" },
    { key = "nomtools", name = "Custom" },
}
local MINIMAP_ATTACH_EDGE_CHOICES = {
    { key = "bottom", name = "Bottom of Minimap" },
    { key = "top",    name = "Top of Minimap" },
}
local REMINDER_POSITION_POINT_CHOICES = {
    { key = "TOPLEFT", name = "Top Left" },
    { key = "TOP", name = "Top" },
    { key = "TOPRIGHT", name = "Top Right" },
    { key = "LEFT", name = "Left" },
    { key = "CENTER", name = "Center" },
    { key = "RIGHT", name = "Right" },
    { key = "BOTTOMLEFT", name = "Bottom Left" },
    { key = "BOTTOM", name = "Bottom" },
    { key = "BOTTOMRIGHT", name = "Bottom Right" },
}
local sliderSequence = 0
local fontPickerSequence = 0
local texturePickerSequence = 0
local activeFontPickerPopup
local activeTexturePickerPopup
local EnsureFontPickerPopup
local EnsureTexturePickerPopup

local PANEL_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local FIELD_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local SLIDER_VALUE_BACKDROP = FIELD_BACKDROP

local function EnsureBlizzardEditModeLoaded()
    if EditModeManagerFrame then
        return true
    end

    local loader = (C_AddOns and C_AddOns.LoadAddOn) or UIParentLoadAddOn
    if loader then
        loader("Blizzard_EditMode")
    end

    return EditModeManagerFrame ~= nil
end

local function OpenBlizzardEditMode()
    if not EnsureBlizzardEditModeLoaded() then
        return
    end

    if ShowUIPanel then
        ShowUIPanel(EditModeManagerFrame)
    elseif EditModeManagerFrame and EditModeManagerFrame.Show then
        EditModeManagerFrame:Show()
    end
end

local function GetOptionsModuleKey(pageKey)
    if pageKey == "consumables" or pageKey == "consumables_general" or pageKey == "consumables_tracking" or pageKey == "consumables_appearance" then
        return "consumables"
    end

    if pageKey == "objective_tracker" or pageKey == "objective_tracker_general" or pageKey == "objective_tracker_layout" or pageKey == "objective_tracker_appearance" or pageKey == "objective_tracker_sections" then
        return "objectiveTracker"
    end

    if pageKey == "great_vault" then
        return "greatVault"
    end

    if pageKey == "dungeon_difficulty" then
        return "dungeonDifficulty"
    end

    if pageKey == "talent_loadout" then
        return "talentLoadout"
    end

    if pageKey == "reminders_general" or pageKey == "reminders_appearance" then
        return "reminders"
    end

    if pageKey == "classes_general" or pageKey == "classes_monk" then
        return "classesMonk"
    end

    if pageKey == "menu_bar" then
        return "miscellaneous"
    end

    if pageKey == "housing" then
        return "housing"
    end

    if pageKey == "world_quests" then
        return "worldQuests"
    end

    if pageKey == "miscellaneous" or pageKey == "miscellaneous_general" or pageKey == "miscellaneous_cutscenes" or pageKey == "miscellaneous_character_stats" then
        return "miscellaneous"
    end

    return nil
end

local function GetModuleAddonUnavailableReason(moduleKey)
    if not moduleKey or not ns.GetModuleAddonUnavailableReason then
        return nil
    end

    return ns.GetModuleAddonUnavailableReason(moduleKey)
end

local function GetOptionsPreviewPage(pageKey)
    if pageKey == "consumables" or pageKey == "consumables_general" or pageKey == "consumables_tracking" or pageKey == "consumables_appearance" then
        return "consumables"
    end

    if pageKey == "reminders_appearance" then
        return "reminders_appearance"
    end

    if pageKey == "great_vault" or pageKey == "dungeon_difficulty" or pageKey == "talent_loadout" or pageKey == "menu_bar" then
        return pageKey
    end

    if pageKey == "classes_monk" then
        return pageKey
    end

    return nil
end

local function IsPreviewModuleEnabled(previewPage)
    if not previewPage or not ns.db then
        return false
    end

    local previewModuleKey = GetOptionsModuleKey(previewPage)
    if previewModuleKey then
        if GetModuleAddonUnavailableReason(previewModuleKey) then
            return false
        end

        if ns.IsModuleRuntimeEnabled and ns.IsModuleConfiguredEnabled then
            local runtimeEnabled = ns.IsModuleRuntimeEnabled(previewModuleKey, ns.IsModuleConfiguredEnabled(previewModuleKey))
            if runtimeEnabled == false then
                return false
            end

            if previewPage ~= "classes_monk" then
                return true
            end
        end
    end

    if previewPage == "consumables" then
        return ns.db.enabled ~= false
    elseif previewPage == "great_vault" then
        return type(ns.db.greatVault) == "table" and ns.db.greatVault.enabled ~= false
    elseif previewPage == "dungeon_difficulty" then
        return type(ns.db.dungeonDifficulty) == "table" and ns.db.dungeonDifficulty.enabled ~= false
    elseif previewPage == "talent_loadout" then
        return type(ns.db.talentLoadout) == "table" and ns.db.talentLoadout.enabled ~= false
    elseif previewPage == "menu_bar" then
        local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
        if not miscSettings or miscSettings.enabled == false then
            if ns.IsModuleRuntimeEnabled then
                return ns.IsModuleRuntimeEnabled("miscellaneous", false)
            end
            return false
        end

        return type(ns.db.menuBar) == "table" and ns.db.menuBar.enabled ~= false
    elseif previewPage == "classes_monk" then
        local classesSettings = ns.GetClassesSettings and ns.GetClassesSettings() or nil
        local monkSettings = ns.GetMonkChiBarSettings and ns.GetMonkChiBarSettings() or nil
        local classesEnabled = type(classesSettings) == "table" and classesSettings.enabled == true
        if ns.IsModuleRuntimeEnabled and ns.IsModuleConfiguredEnabled then
            classesEnabled = ns.IsModuleRuntimeEnabled("classesMonk", ns.IsModuleConfiguredEnabled("classesMonk"))
        end

        return classesEnabled
            and type(monkSettings) == "table"
            and monkSettings.moduleEnabled == true
            and monkSettings.enabled == true
    end

    return true
end

local function SetActiveOptionsPreviewPage(pageKey, allowDisabledPreview)
    local previousPreviewPage = ns.activeOptionsPreviewPage
    local previewPage = GetOptionsPreviewPage(pageKey)

    -- Block preview activation for disabled modules.
    if previewPage and not allowDisabledPreview and not IsPreviewModuleEnabled(previewPage) then
        previewPage = nil
    end

    if previousPreviewPage == previewPage then
        return
    end

    ns.activeOptionsPreviewPage = previewPage
    if ns.RequestRefresh then
        local requestedModules = {}

        if previousPreviewPage == "consumables" or previewPage == "consumables" then
            requestedModules[#requestedModules + 1] = "consumables"
        end
        if previousPreviewPage == "great_vault" or previewPage == "great_vault" then
            requestedModules[#requestedModules + 1] = "greatVault"
        end
        if previousPreviewPage == "dungeon_difficulty" or previewPage == "dungeon_difficulty" then
            requestedModules[#requestedModules + 1] = "dungeonDifficulty"
        end
        if previousPreviewPage == "talent_loadout" or previewPage == "talent_loadout" then
            requestedModules[#requestedModules + 1] = "talentLoadout"
        end
        if previousPreviewPage == "reminders_appearance" or previewPage == "reminders_appearance" then
            requestedModules[#requestedModules + 1] = "talentLoadout"
        end
        if previousPreviewPage == "menu_bar" or previewPage == "menu_bar" then
            requestedModules[#requestedModules + 1] = "menuBar"
        end
        if previousPreviewPage == "classes_monk" or previewPage == "classes_monk" then
            requestedModules[#requestedModules + 1] = "classesMonk"
        end

        if #requestedModules > 0 then
            ns.RequestRefresh(requestedModules)
        else
            ns.RequestRefresh("options")
        end
    end
end

function ns.GetActiveOptionsPreviewPage()
    return ns.activeOptionsPreviewPage
end

local function GetOptionsRefreshTarget(pageKey)
    local resolvedPageKey = pageKey
    if not resolvedPageKey and ns.optionsWindow then
        resolvedPageKey = ns.optionsWindow.currentPage
    end

    if resolvedPageKey == "consumables"
        or resolvedPageKey == "consumables_general"
        or resolvedPageKey == "consumables_tracking"
        or resolvedPageKey == "consumables_appearance"
    then
        return "consumables"
    end

    if resolvedPageKey == "objective_tracker"
        or resolvedPageKey == "objective_tracker_general"
        or resolvedPageKey == "objective_tracker_layout"
        or resolvedPageKey == "objective_tracker_appearance"
        or resolvedPageKey == "objective_tracker_sections"
    then
        return "objectiveTracker"
    end

    if resolvedPageKey == "reminders_general" or resolvedPageKey == "reminders_appearance" then
        return "reminders"
    end

    if resolvedPageKey == "great_vault" then
        return "greatVault"
    end

    if resolvedPageKey == "dungeon_difficulty" then
        return "dungeonDifficulty"
    end

    if resolvedPageKey == "talent_loadout" then
        return "talentLoadout"
    end

    if resolvedPageKey == "classes_general" or resolvedPageKey == "classes_monk" then
        return "classesMonk"
    end

    if resolvedPageKey == "menu_bar" then
        return "menuBar"
    end

    if resolvedPageKey == "miscellaneous" or resolvedPageKey == "miscellaneous_general" or resolvedPageKey == "miscellaneous_cutscenes" or resolvedPageKey == "miscellaneous_character_stats" then
        return "miscellaneous"
    end

    return nil
end

local function RequestOptionsRefresh(pageKey, reason)
    if not ns.RequestRefresh and not ns.RefreshObjectiveTrackerUI then
        return
    end

    local target = GetOptionsRefreshTarget(pageKey)
    if target == "objectiveTracker" and ns.RefreshObjectiveTrackerUI then
        if reason == "reset" then
            ns.RefreshObjectiveTrackerUI("full")
        else
            ns.RefreshObjectiveTrackerUI("soft")
        end
        return
    end

    if target then
        ns.RequestRefresh(target)
        return
    end

    if ns.RequestRefresh then
        ns.RequestRefresh()
    end
end

local function SetNewTagBadge(target, shown, options)
    if ns.SetNewFeatureBadgeShown then
        ns.SetNewFeatureBadgeShown(target, shown == true, options)
    end
end

local function ResolveOptionsPageKey(frame)
    local current = frame
    while current do
        if type(current.nomtoolsPageKey) == "string" and current.nomtoolsPageKey ~= "" then
            return current.nomtoolsPageKey
        end

        current = current.GetParent and current:GetParent() or nil
    end

    return nil
end

local function IsOptionRowMarkedNew(parent, labelText, options)
    if options and options.newTagKey and ns.IsNewTaggedOption and ns.IsNewTaggedOption(options.newTagKey) then
        return true
    end

    local pageKey = options and options.pageKey or ResolveOptionsPageKey(parent)
    return pageKey ~= nil
        and ns.IsNewTaggedOptionRow ~= nil
        and ns.IsNewTaggedOptionRow(pageKey, labelText)
end

local function CreateTitle(parent, text, x, y)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(text)
    title:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
    return title
end

local function CreateSectionTitle(parent, text, x, y)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(text)
    title:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
    return title
end

local function CreateSubsectionTitle(parent, text, x, y)
    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(text)
    title:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
    local fontPath, fontSize, fontFlags = title:GetFont()
    if fontPath and fontSize then
        title:SetFont(fontPath, fontSize + 1, fontFlags or "")
    end
    title:SetShadowOffset(0, 0)
    title:SetShadowColor(0, 0, 0, 0)
    return title
end

local function CreateBodyText(parent, text, x, y, width)
    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then label:SetWidth(width) end
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    return label
end

local function MarkAutoFitChild(object)
    if object then
        object.nomtoolsMeasure = true
    end
    return object
end

local function GetFrameContentBottomOffset(frame, exclusions)
    if not frame or not frame.GetTop then
        return nil
    end

    local frameTop = frame:GetTop()
    if not frameTop then
        return nil
    end

    local deepestBottom

    local function ConsiderObject(object)
        if not object or (exclusions and exclusions[object]) then
            return
        end

        local objectType = object.GetObjectType and object:GetObjectType() or nil
        if objectType == "Texture" or objectType == "MaskTexture" or objectType == "Line" then
            return
        end

        if object.IsShown and not object:IsShown() then
            return
        end

        local objectTop = object.GetTop and object:GetTop() or nil
        local objectBottom = object.GetBottom and object:GetBottom() or nil
        if not objectTop or not objectBottom then
            return
        end

        if objectTop < objectBottom then
            objectTop, objectBottom = objectBottom, objectTop
        end

        deepestBottom = deepestBottom and math.min(deepestBottom, objectBottom) or objectBottom
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        if child.nomtoolsMeasure then
            ConsiderObject(child)
        end
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        local regionType = region.GetObjectType and region:GetObjectType() or nil
        if regionType == "FontString" then
            ConsiderObject(region)
        end
    end

    if not deepestBottom then
        return nil
    end

    return math.max(0, frameTop - deepestBottom)
end

local function AutoFitFrameHeight(frame, options)
    options = options or {}

    local contentBottomOffset = GetFrameContentBottomOffset(frame, options.exclusions)
    if not contentBottomOffset then
        return frame and frame.GetHeight and frame:GetHeight() or 0
    end

    local desiredHeight = math.max(options.minHeight or 0, math.ceil(contentBottomOffset + (options.bottomPadding or 0)))
    frame:SetHeight(desiredHeight)
    return desiredHeight
end

local function FitSectionCardHeight(card, bottomPadding, minHeight)
    return AutoFitFrameHeight(card, {
        minHeight = minHeight or 0,
        bottomPadding = bottomPadding or 18,
    })
end

local function FitSidebarCardHeight(card, bottomPadding, minHeight)
    return AutoFitFrameHeight(card, {
        minHeight = minHeight or 0,
        bottomPadding = bottomPadding or 18,
    })
end

local function FitScrollContentHeight(content, minHeight, bottomPadding)
    return AutoFitFrameHeight(content, {
        minHeight = minHeight or 1,
        bottomPadding = bottomPadding or 24,
    })
end

local function ApplyInsetPanelChrome(frame, options)
    if not frame then
        return
    end

    options = options or {}

    if frame.Bg then
        frame.Bg:SetAlpha(0)
    end
    if frame.InsetBg then
        frame.InsetBg:SetAlpha(0)
    end
    if frame.Background then
        frame.Background:SetAlpha(0)
    end
    if frame.NineSlice and frame.NineSlice.Center then
        frame.NineSlice.Center:SetAlpha(0)
    end

    local inset = tonumber(options.inset) or 5
    local bgFrame = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bgFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    bgFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    bgFrame:SetBackdrop(FIELD_BACKDROP)
    bgFrame:SetBackdropColor(
        tonumber(options.r) or (SURFACE_BG_R + 0.025),
        tonumber(options.g) or (SURFACE_BG_G + 0.025),
        tonumber(options.b) or (SURFACE_BG_B + 0.025),
        tonumber(options.a) or 0.92
    )
    bgFrame:SetBackdropBorderColor(
        tonumber(options.borderR) or SURFACE_BORDER_R,
        tonumber(options.borderG) or SURFACE_BORDER_G,
        tonumber(options.borderB) or SURFACE_BORDER_B,
        tonumber(options.borderA) or 0.92
    )
    bgFrame:EnableMouse(false)
    if frame.GetFrameStrata and bgFrame.SetFrameStrata then
        bgFrame:SetFrameStrata(frame:GetFrameStrata())
    end
    bgFrame:SetFrameLevel(math.max(0, (frame:GetFrameLevel() or 1) - 1))

    local vignetteInset = tonumber(options.vignetteInset) or 1
    local vignetteAlpha = tonumber(options.vignetteAlpha) or 0.10
    local vignetteThickness = tonumber(options.vignetteThickness) or 26
    local function CreateVignetteEdge(layer)
        local tex = bgFrame:CreateTexture(nil, layer or "BORDER")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetVertexColor(0, 0, 0, 1)
        return tex
    end

    local topVignette = CreateVignetteEdge("BORDER")
    topVignette:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", vignetteInset, -vignetteInset)
    topVignette:SetPoint("TOPRIGHT", bgFrame, "TOPRIGHT", -vignetteInset, -vignetteInset)
    topVignette:SetHeight(vignetteThickness)

    local bottomVignette = CreateVignetteEdge("BORDER")
    bottomVignette:SetPoint("BOTTOMLEFT", bgFrame, "BOTTOMLEFT", vignetteInset, vignetteInset)
    bottomVignette:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", -vignetteInset, vignetteInset)
    bottomVignette:SetHeight(vignetteThickness)

    local leftVignette = CreateVignetteEdge("BORDER")
    leftVignette:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", vignetteInset, -vignetteInset)
    leftVignette:SetPoint("BOTTOMLEFT", bgFrame, "BOTTOMLEFT", vignetteInset, vignetteInset)
    leftVignette:SetWidth(vignetteThickness)

    local rightVignette = CreateVignetteEdge("BORDER")
    rightVignette:SetPoint("TOPRIGHT", bgFrame, "TOPRIGHT", -vignetteInset, -vignetteInset)
    rightVignette:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", -vignetteInset, vignetteInset)
    rightVignette:SetWidth(vignetteThickness)

    local setGradientAlpha = topVignette["SetGradientAlpha"]
    if type(setGradientAlpha) == "function" then
        setGradientAlpha(topVignette, "VERTICAL", 0, 0, 0, vignetteAlpha, 0, 0, 0, 0)
        setGradientAlpha(bottomVignette, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, vignetteAlpha)
        setGradientAlpha(leftVignette, "HORIZONTAL", 0, 0, 0, vignetteAlpha, 0, 0, 0, 0)
        setGradientAlpha(rightVignette, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, vignetteAlpha)
    else
        topVignette:SetVertexColor(0, 0, 0, vignetteAlpha * 0.65)
        bottomVignette:SetVertexColor(0, 0, 0, vignetteAlpha * 0.65)
        leftVignette:SetVertexColor(0, 0, 0, vignetteAlpha * 0.45)
        rightVignette:SetVertexColor(0, 0, 0, vignetteAlpha * 0.45)
    end

    bgFrame.topVignette = topVignette
    bgFrame.bottomVignette = bottomVignette
    bgFrame.leftVignette = leftVignette
    bgFrame.rightVignette = rightVignette
    frame.nomtoolsBackgroundFrame = bgFrame
    return bgFrame
end

local function CreateSectionCard(parent, x, y, width, height, title, _)
    local card = CreateFrame("Frame", nil, parent, "InsetFrameTemplate3")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    card:SetSize(width, height)
    MarkAutoFitChild(card)
    card.nomtoolsSectionCard = true
    card.nomtoolsContentYOffset = 28
    card.RefreshAll = function(self)
        if parent and parent.RefreshAll then
            parent:RefreshAll()
        end
    end
    ApplyInsetPanelChrome(card, {
        inset = 5,
        r = 0.145,
        g = 0.145,
        b = 0.148,
        a = 0.94,
        borderA = 0.88,
        vignetteAlpha = 0.03,
        vignetteThickness = 24,
    })

    local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -14)
    titleText:SetText(title)
    titleText:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
    card.titleText = titleText

    return card
end

local function CreateInsetSection(parent, width, title)
    local panel = CreateFrame("Frame", nil, parent, "InsetFrameTemplate3")
    panel:SetSize(width, 100)
    MarkAutoFitChild(panel)
    panel.nomtoolsContentYOffset = 28
    ApplyInsetPanelChrome(panel, {
        inset = 4,
        r = 0.154,
        g = 0.154,
        b = 0.157,
        a = 0.95,
        borderA = 0.95,
        vignetteAlpha = 0.028,
        vignetteThickness = 22,
    })

    local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
    titleText:SetText(title)
    titleText:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
    panel.titleText = titleText

    return panel
end

local function CreateInlineHeader(parent, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetText(text)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    label:SetShadowOffset(0, 0)
    label:SetShadowColor(0, 0, 0, 0)
    return label
end

local ResolvePreviewBorderStyle

local function ApplyTexturePreviewSwatch(frame, texture, texturePath, previewMode)
    if not frame or not texture then
        return
    end

    if previewMode == "border" then
        local borderStyle = ResolvePreviewBorderStyle(texturePath, 1, true)
        local previousBackdropInfo = frame.nomtoolsPreviewBackdropInfo
        local backdropInfo = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            tile = true,
            tileSize = 8,
            insets = {},
        }
        backdropInfo.edgeFile = borderStyle.edgeFile
        backdropInfo.tile = borderStyle.tile
        backdropInfo.tileSize = borderStyle.tileSize
        backdropInfo.edgeSize = borderStyle.edgeSize
        backdropInfo.insets.left = borderStyle.insets.left
        backdropInfo.insets.right = borderStyle.insets.right
        backdropInfo.insets.top = borderStyle.insets.top
        backdropInfo.insets.bottom = borderStyle.insets.bottom
        frame.nomtoolsPreviewBackdropInfo = backdropInfo
        if previousBackdropInfo and previousBackdropInfo.edgeFile ~= backdropInfo.edgeFile then
            frame:SetBackdrop(nil)
        end
        frame:SetBackdrop(backdropInfo)
        frame:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 1)
        frame:SetBackdropBorderColor(1, 1, 1, 1)
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        texture:SetVertexColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 1)
        return
    end

    frame:SetBackdrop(FIELD_BACKDROP)
    frame:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 1)
    frame:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.9)
    texture:SetTexture(texturePath)
    texture:SetVertexColor(1, 1, 1, 1)
end

local function CreateButton(parent, text, x, y, width, height, onClick)
    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, height)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    MarkAutoFitChild(button)
    return button
end

local function NormalizeColorValue(color, fallback)
    fallback = fallback or { r = 1, g = 1, b = 1, a = 1 }
    if type(color) ~= "table" then
        return {
            r = fallback.r,
            g = fallback.g,
            b = fallback.b,
            a = fallback.a,
        }
    end

    return {
        r = tonumber(color.r or color[1]) or fallback.r,
        g = tonumber(color.g or color[2]) or fallback.g,
        b = tonumber(color.b or color[3]) or fallback.b,
        a = tonumber(color.a or color[4]) or fallback.a,
    }
end

local function RoundWholeNumber(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

---@param axis string
---@return number
function ns.GetPositionSliderLimit(axis)
    local fallbackSize = axis == "x" and 1920 or 1080
    local parentSize

    if UIParent then
        if axis == "x" and UIParent.GetWidth then
            parentSize = UIParent:GetWidth()
        elseif axis == "y" and UIParent.GetHeight then
            parentSize = UIParent:GetHeight()
        end
    end

    parentSize = tonumber(parentSize)
    if not parentSize or parentSize <= 0 then
        parentSize = fallbackSize
    end

    return math.max(400, RoundWholeNumber(parentSize * 0.75))
end

local function NormalizeSignedBorderSize(value, defaultValue)
    local fallback = tonumber(defaultValue)
    if fallback == nil then
        fallback = 1
    end

    value = tonumber(value)
    if value == nil then
        value = fallback
    end

    return math.max(-10, math.min(10, RoundWholeNumber(value)))
end

local function ClampPreviewNumber(value, minimum, maximum)
    value = tonumber(value)
    if value == nil then
        return minimum
    end

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function CopyPreviewInsets(insets, fallback)
    fallback = ClampPreviewNumber(fallback, 0, 128)
    if type(insets) ~= "table" then
        return {
            left = fallback,
            right = fallback,
            top = fallback,
            bottom = fallback,
        }
    end

    return {
        left = ClampPreviewNumber(insets.left, 0, 128),
        right = ClampPreviewNumber(insets.right, 0, 128),
        top = ClampPreviewNumber(insets.top, 0, 128),
        bottom = ClampPreviewNumber(insets.bottom, 0, 128),
    }
end

ResolvePreviewBorderStyle = function(texturePath, borderSize, usePreviewSize)
    local borderDefinition = ns.GetBorderTextureDefinition and ns.GetBorderTextureDefinition(texturePath) or nil
    local magnitude = math.abs(tonumber(borderSize) or 0)
    local baseEdgeSize = ClampPreviewNumber(
        borderDefinition and (usePreviewSize and borderDefinition.previewEdgeSize or borderDefinition.edgeSize) or (usePreviewSize and 2 or 1),
        1,
        128
    )
    local scaleStep = ClampPreviewNumber(borderDefinition and borderDefinition.scaleStep or 1, 0, 32)
    local edgeSize = baseEdgeSize
    if magnitude > 0 and (not borderDefinition or borderDefinition.supportsVariableThickness ~= false) then
        edgeSize = edgeSize + (math.max(magnitude - 1, 0) * scaleStep)
    end

    edgeSize = ClampPreviewNumber(edgeSize, 1, 128)
    return {
        edgeFile = (borderDefinition and borderDefinition.path) or texturePath or "Interface\\Buttons\\WHITE8x8",
        tile = borderDefinition and borderDefinition.tile ~= false or true,
        tileSize = ClampPreviewNumber(borderDefinition and borderDefinition.tileSize or 8, 1, 128),
        baseEdgeSize = baseEdgeSize,
        edgeSize = edgeSize,
        preserveColor = borderDefinition and borderDefinition.preserveColor == true or false,
        insets = CopyPreviewInsets(borderDefinition and borderDefinition.insets, math.max(1, math.floor(edgeSize / 4))),
    }
end

local function ClampOptionValue(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value ~= value then
        value = nil
    end
    if value == nil then
        value = tonumber(fallback)
    end
    if value ~= value then
        value = nil
    end
    if value == nil then
        value = minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end

    return value
end

local function NormalizeReminderPresetValue(preset, fallback)
    if preset == "nomtools" then
        return "nomtools"
    end

    return fallback or "blizzard"
end

local function NormalizeReminderPointValue(point, fallback)
    if type(point) == "string" then
        for _, choice in ipairs(REMINDER_POSITION_POINT_CHOICES) do
            if choice.key == point then
                return point
            end
        end
    end

    return fallback or "TOP"
end

local function NormalizeReminderAppearanceProfile(profile, defaults, includeNomToolsExtras)
    local resolvedProfile = type(profile) == "table" and profile or {}
    local resolvedDefaults = type(defaults) == "table" and defaults or {}

    if type(resolvedProfile.font) ~= "string" or resolvedProfile.font == "" then
        resolvedProfile.font = resolvedDefaults.font or ns.GLOBAL_CHOICE_KEY
    end
    if type(resolvedProfile.fontOutline) ~= "string" or resolvedProfile.fontOutline == "" then
        resolvedProfile.fontOutline = resolvedDefaults.fontOutline or ns.GLOBAL_CHOICE_KEY
    end

    resolvedProfile.titleFontSize = RoundWholeNumber(ClampOptionValue(resolvedProfile.titleFontSize, 8, 30, resolvedDefaults.titleFontSize or 14))
    resolvedProfile.primaryFontSize = RoundWholeNumber(ClampOptionValue(resolvedProfile.primaryFontSize, 8, 30, resolvedDefaults.primaryFontSize or 13))
    resolvedProfile.hintFontSize = RoundWholeNumber(ClampOptionValue(resolvedProfile.hintFontSize, 8, 30, resolvedDefaults.hintFontSize or 11))

    resolvedProfile.titleColor = NormalizeColorValue(resolvedProfile.titleColor, resolvedDefaults.titleColor or { r = 1, g = 0.82, b = 0, a = 1 })
    resolvedProfile.primaryColor = NormalizeColorValue(resolvedProfile.primaryColor, resolvedDefaults.primaryColor or { r = 1, g = 1, b = 1, a = 1 })
    resolvedProfile.hintColor = NormalizeColorValue(resolvedProfile.hintColor, resolvedDefaults.hintColor or { r = 0.75, g = 0.78, b = 0.82, a = 1 })

    if includeNomToolsExtras then
        resolvedProfile.opacity = RoundWholeNumber(ClampOptionValue(resolvedProfile.opacity, 0, 100, resolvedDefaults.opacity or 80))
        if type(resolvedProfile.texture) ~= "string" or resolvedProfile.texture == "" then
            resolvedProfile.texture = resolvedDefaults.texture or ns.GLOBAL_CHOICE_KEY
        end
        if resolvedProfile.showAccent == nil then
            resolvedProfile.showAccent = resolvedDefaults.showAccent ~= false
        else
            resolvedProfile.showAccent = resolvedProfile.showAccent ~= false
        end
        resolvedProfile.accentColor = NormalizeColorValue(resolvedProfile.accentColor, resolvedDefaults.accentColor or { r = 1, g = 0.82, b = 0, a = 1 })
        resolvedProfile.backgroundColor = NormalizeColorValue(resolvedProfile.backgroundColor, resolvedDefaults.backgroundColor or { r = 0, g = 0, b = 0, a = 1 })
        resolvedProfile.borderColor = NormalizeColorValue(resolvedProfile.borderColor, resolvedDefaults.borderColor or { r = 0.28, g = 0.30, b = 0.34, a = 1 })
        if type(resolvedProfile.borderTexture) ~= "string" or resolvedProfile.borderTexture == "" then
            resolvedProfile.borderTexture = resolvedDefaults.borderTexture or ns.GLOBAL_CHOICE_KEY
        end
        resolvedProfile.borderSize = NormalizeSignedBorderSize(resolvedProfile.borderSize, resolvedDefaults.borderSize or 1)
    end

    return resolvedProfile
end

local function GetReminderAppearanceState(settingsGetter, moduleDefaults)
    local settings = settingsGetter and settingsGetter() or {}
    settings.appearance = type(settings.appearance) == "table" and settings.appearance or {}

    local appearance = settings.appearance
    local defaultAppearance = moduleDefaults and moduleDefaults.appearance or {}
    appearance.preset = NormalizeReminderPresetValue(appearance.preset, defaultAppearance.preset or "blizzard")
    appearance.blizzard = NormalizeReminderAppearanceProfile(appearance.blizzard, defaultAppearance.blizzard or {}, false)
    appearance.nomtools = NormalizeReminderAppearanceProfile(appearance.nomtools, defaultAppearance.nomtools or {}, true)

    return settings, appearance, appearance[appearance.preset]
end

local function GetReminderPositionConfig(configKey, defaults)
    local fallback = defaults or {
        point = "TOP",
        x = 0,
        y = 0,
    }
    local config = ns.GetEditModeConfig and ns.GetEditModeConfig(configKey, fallback) or fallback
    local xLimit = ns.GetPositionSliderLimit("x")
    local yLimit = ns.GetPositionSliderLimit("y")

    config.point = NormalizeReminderPointValue(config.point, fallback.point or "TOP")
    config.x = RoundWholeNumber(ClampOptionValue(config.x, -xLimit, xLimit, fallback.x or 0))
    config.y = RoundWholeNumber(ClampOptionValue(config.y, -yLimit, yLimit, fallback.y or 0))
    return config
end

local function CopyTableRecursive(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyTableRecursive(value)
    end

    return copy
end

local function ReplaceTableContents(target, source)
    if type(target) ~= "table" then
        return CopyTableRecursive(source or {})
    end

    for key in pairs(target) do
        target[key] = nil
    end

    for key, value in pairs(source or {}) do
        target[key] = CopyTableRecursive(value)
    end

    return target
end

local function ClampUnitInterval(value, fallback)
    value = tonumber(value)
    if value == nil then
        value = tonumber(fallback)
    end
    if value == nil then
        value = 1
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end

    return value
end

local function GetColorValueWithOpacity(colorValue, opacityValue, fallback)
    local color = NormalizeColorValue(colorValue, fallback)
    local opacity = tonumber(opacityValue)
    if opacity ~= nil then
        color.a = math.max(0, math.min(100, opacity)) / 100
    end

    return color
end

local function SetTableColorWithOpacity(target, colorKey, opacityKey, value, fallback)
    if type(target) ~= "table" then
        return
    end

    local color = NormalizeColorValue(value, fallback or target[colorKey] or { r = 1, g = 1, b = 1, a = 1 })
    target[colorKey] = {
        r = color.r,
        g = color.g,
        b = color.b,
        a = color.a,
    }

    if opacityKey then
        target[opacityKey] = math.floor((ClampUnitInterval(color.a, 1) * 100) + 0.5)
    end
end

local function FormatColorPickerPercent(alpha)
    local percent = ClampUnitInterval(alpha, 1) * 100
    local rounded = math.floor((percent * 10) + 0.5) / 10
    if math.abs(rounded - math.floor(rounded + 0.5)) < 0.05 then
        return tostring(math.floor(rounded + 0.5))
    end

    return string.format("%.1f", rounded)
end

local function GetActiveColorPickerAlpha(defaultAlpha)
    if not ColorPickerFrame then
        return ClampUnitInterval(defaultAlpha, 1)
    end

    if ColorPickerFrame.GetColorAlpha then
        local alpha = ColorPickerFrame:GetColorAlpha()
        if alpha ~= nil then
            return ClampUnitInterval(alpha, defaultAlpha)
        end
    end

    if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and ColorPickerFrame.Content.ColorPicker.GetColorAlpha then
        local alpha = ColorPickerFrame.Content.ColorPicker:GetColorAlpha()
        if alpha ~= nil then
            return ClampUnitInterval(alpha, defaultAlpha)
        end
    end

    return ClampUnitInterval(ColorPickerFrame.opacity, defaultAlpha)
end

local function SyncColorPickerAlphaInput()
    if not ColorPickerFrame or not ColorPickerFrame.nomtoolsAlphaInput then
        return
    end

    local input = ColorPickerFrame.nomtoolsAlphaInput
    local label = ColorPickerFrame.nomtoolsAlphaLabel
    local visible = ColorPickerFrame.nomtoolsHasOpacity == true
    input:SetShown(visible)
    if label then
        label:SetShown(visible)
    end
    if not visible then
        return
    end

    input.isUpdating = true
    input:SetText(FormatColorPickerPercent(GetActiveColorPickerAlpha(1)))
    input.isUpdating = false
end

local function PositionColorPickerAlphaInput()
    if not ColorPickerFrame or not ColorPickerFrame.nomtoolsAlphaInput then
        return
    end

    local input = ColorPickerFrame.nomtoolsAlphaInput
    local label = ColorPickerFrame.nomtoolsAlphaLabel
    local hexBox = ColorPickerFrame.Content and ColorPickerFrame.Content.HexBox or nil
    local footer = ColorPickerFrame.Footer or ColorPickerFrame
    local footerAnchor = (footer and (footer.CancelButton or footer.OkayButton)) or footer or ColorPickerFrame

    input:ClearAllPoints()
    if label then
        label:ClearAllPoints()
    end

    if hexBox then
        input:SetPoint("BOTTOM", hexBox, "TOP", 0, 10)
        if label then
            label:SetPoint("BOTTOM", input, "TOP", 0, 4)
        end
        return
    end

    input:SetPoint("RIGHT", footerAnchor, "LEFT", -18, 0)
    if label then
        label:SetPoint("RIGHT", input, "LEFT", -6, 0)
    end
end

local function SetActiveColorPickerAlpha(alpha)
    if not ColorPickerFrame then
        return
    end

    alpha = ClampUnitInterval(alpha, 1)
    if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and ColorPickerFrame.Content.ColorPicker.SetColorAlpha then
        ColorPickerFrame.Content.ColorPicker:SetColorAlpha(alpha)
    end
    if ColorPickerFrame.SetColorAlpha then
        ColorPickerFrame:SetColorAlpha(alpha)
    end
    ColorPickerFrame.opacity = alpha

    if ColorPickerFrame.opacityFunc then
        ColorPickerFrame.opacityFunc()
    end

    SyncColorPickerAlphaInput()
end

local function ApplyColorPickerAlphaInput(editBox)
    if not editBox or editBox.isUpdating then
        return
    end

    local value = tonumber(editBox:GetText())
    if value == nil then
        SyncColorPickerAlphaInput()
        return
    end

    value = math.max(0, math.min(100, value))
    SetActiveColorPickerAlpha(value / 100)
end

local function EnsureColorPickerAlphaInput()
    if not ColorPickerFrame or ColorPickerFrame.nomtoolsAlphaInput then
        return
    end

    local parent = (ColorPickerFrame.Footer and ColorPickerFrame.Footer.CancelButton and ColorPickerFrame.Footer) or ColorPickerFrame
    local anchorButton = parent.CancelButton or parent.OkayButton or parent

    local input = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetAutoFocus(false)
    input:SetSize(52, 22)
    input:SetJustifyH("CENTER")
    input:SetFontObject(GameFontHighlightSmall)
    input:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    input:SetBackdrop(SLIDER_VALUE_BACKDROP)
    input:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 1)
    input:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.9)
    input:SetScript("OnEnterPressed", function(self)
        ApplyColorPickerAlphaInput(self)
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        SyncColorPickerAlphaInput()
        self:ClearFocus()
    end)
    input:SetScript("OnEditFocusLost", function(self)
        ApplyColorPickerAlphaInput(self)
    end)
    input:Hide()

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetText("Alpha %")
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    label:Hide()

    ColorPickerFrame.nomtoolsAlphaInput = input
    ColorPickerFrame.nomtoolsAlphaLabel = label
    PositionColorPickerAlphaInput()
    ColorPickerFrame:HookScript("OnHide", function(self)
        if self.nomtoolsAlphaInput then
            self.nomtoolsAlphaInput:Hide()
            self.nomtoolsAlphaInput.isUpdating = false
        end
        if self.nomtoolsAlphaLabel then
            self.nomtoolsAlphaLabel:Hide()
        end
    end)
end

local function ConfigureColorPickerAlphaInput(hasOpacity)
    if not ColorPickerFrame then
        return
    end

    EnsureColorPickerAlphaInput()
    ColorPickerFrame.nomtoolsHasOpacity = hasOpacity == true
    PositionColorPickerAlphaInput()
    SyncColorPickerAlphaInput()
end

local function CreateColorButton(parent, x, y, labelText, getter, setter, options)
    options = options or {}

    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

    local hasOpacity = options.hasOpacity ~= false
    local hasEmbeddedToggle = type(options.toggleGetter) == "function" and type(options.toggleSetter) == "function"
    local swatchWidth = math.max(60, tonumber(options.width) or tonumber(options.swatchWidth) or STANDARD_COLOR_BUTTON_WIDTH)
    local swatchHeight = math.max(28, tonumber(options.swatchHeight) or 28)

    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    button:SetSize(swatchWidth, swatchHeight)
    MarkAutoFitChild(button)

    local previewFrame = CreateFrame("Frame", nil, button)
    previewFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    previewFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.previewFrame = previewFrame

    local outerBorder = previewFrame:CreateTexture(nil, "BACKGROUND")
    outerBorder:SetAllPoints(previewFrame)
    outerBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    button.outerBorder = outerBorder

    local innerBorder = previewFrame:CreateTexture(nil, "BORDER")
    innerBorder:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 1, -1)
    innerBorder:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -1, 1)
    innerBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    button.innerBorder = innerBorder

    local fillInsetLeft = hasEmbeddedToggle and math.max(20, tonumber(options.toggleWidth) or 22) or 2
    local fillFrame = CreateFrame("Frame", nil, previewFrame)
    fillFrame:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", fillInsetLeft, -2)
    fillFrame:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -2, 2)
    button.fillFrame = fillFrame

    local fillTexture = fillFrame:CreateTexture(nil, "ARTWORK")
    fillTexture:SetAllPoints(fillFrame)
    fillTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    button.fillTexture = fillTexture

    local sheenTexture = fillFrame:CreateTexture(nil, "OVERLAY")
    sheenTexture:SetAllPoints(fillFrame)
    sheenTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    sheenTexture:SetVertexColor(1, 1, 1, 0.05)
    button.sheenTexture = sheenTexture

    local shadowTexture = fillFrame:CreateTexture(nil, "OVERLAY")
    shadowTexture:SetAllPoints(fillFrame)
    shadowTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    shadowTexture:SetVertexColor(0, 0, 0, 0)
    button.shadowTexture = shadowTexture

    if hasEmbeddedToggle then
        local toggleHost = CreateFrame("Frame", nil, previewFrame)
        toggleHost:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 0, 0)
        toggleHost:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 0, 0)
        toggleHost:SetWidth(math.max(20, tonumber(options.toggleWidth) or 22))
        toggleHost:SetFrameLevel((previewFrame:GetFrameLevel() or 0) + 10)
        button.toggleHost = toggleHost

        local toggle = CreateFrame("CheckButton", nil, toggleHost, "UICheckButtonTemplate")
        toggle:SetPoint("LEFT", previewFrame, "LEFT", -4, 0)
        toggle:SetFrameLevel((toggleHost:GetFrameLevel() or 0) + 1)
        button.toggleControl = toggle

        toggle:SetScript("OnClick", function(self)
            options.toggleSetter(self:GetChecked() == true)
            if parent.RefreshAll then
                parent:RefreshAll()
            end
        end)
    end

    local function IsEmbeddedToggleActive()
        if not hasEmbeddedToggle then
            return true
        end

        return options.toggleGetter() == true
    end

    local function RefreshChrome(self)
        local toggleActive = IsEmbeddedToggleActive()
        if not self:IsEnabled() then
            self.outerBorder:SetVertexColor(0.56, 0.56, 0.58, 0.70)
            self.innerBorder:SetVertexColor(0, 0, 0, 0.45)
            self.sheenTexture:SetAlpha(0.02)
            self.shadowTexture:SetAlpha(toggleActive and 0.16 or 0.28)
            return
        end

        if self.isHovered then
            self.outerBorder:SetVertexColor(0.96, 0.96, 0.98, 0.95)
            self.innerBorder:SetVertexColor(0, 0, 0, 0.78)
            self.sheenTexture:SetAlpha(0.08)
            self.shadowTexture:SetAlpha(toggleActive and 0.04 or 0.22)
            return
        end

        self.outerBorder:SetVertexColor(0.82, 0.82, 0.85, 0.88)
        self.innerBorder:SetVertexColor(0, 0, 0, 0.68)
        self.sheenTexture:SetAlpha(0.05)
        self.shadowTexture:SetAlpha(toggleActive and 0.08 or 0.24)
    end

    local function ApplyDisplay()
        local color = NormalizeColorValue(getter(), { r = 0.95, g = 0.95, b = 0.32, a = 1 })
        local toggleActive = IsEmbeddedToggleActive()
        button.fillTexture:SetVertexColor(color.r, color.g, color.b, toggleActive and (hasOpacity and color.a or 1) or 0.22)
        if button.toggleControl then
            button.toggleControl:SetChecked(toggleActive)
        end
        RefreshChrome(button)
    end

    local function CommitColor(color)
        setter({
            r = color.r,
            g = color.g,
            b = color.b,
            a = hasOpacity and color.a or NormalizeColorValue(getter(), { r = 1, g = 1, b = 1, a = 1 }).a,
        })
        if parent.RefreshAll then
            parent:RefreshAll()
        end
    end

    button:SetScript("OnClick", function()
        if hasEmbeddedToggle and not IsEmbeddedToggleActive() then
            return
        end

        local current = NormalizeColorValue(getter(), { r = 0.95, g = 0.95, b = 0.32, a = 1 })
        local previous = {
            r = current.r,
            g = current.g,
            b = current.b,
            a = current.a,
        }

        ColorPickerFrame:SetupColorPickerAndShow({
            r = current.r,
            g = current.g,
            b = current.b,
            opacity = current.a,
            hasOpacity = hasOpacity,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = hasOpacity and ((ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or current.a) or current.a
                CommitColor({ r = r, g = g, b = b, a = a })
                SyncColorPickerAlphaInput()
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = hasOpacity and ((ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or current.a) or current.a
                CommitColor({ r = r, g = g, b = b, a = a })
                SyncColorPickerAlphaInput()
            end,
            cancelFunc = function()
                CommitColor(previous)
                SyncColorPickerAlphaInput()
            end,
        })
        ConfigureColorPickerAlphaInput(hasOpacity)
    end)

    button.label = label
    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        RefreshChrome(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        RefreshChrome(self)
    end)
    button:SetScript("OnDisable", function(self)
        self.isHovered = false
        RefreshChrome(self)
    end)
    button:SetScript("OnEnable", function(self)
        RefreshChrome(self)
    end)
    button.nomtoolsControlType = "color"
    button.Refresh = ApplyDisplay
    RefreshChrome(button)
    ApplyDisplay()
    return button
end

local function CreateCheckbox(parent, text, x, y, getter, setter, options)
    options = options or {}

    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    MarkAutoFitChild(checkbox)

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    label:SetText(text)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    checkbox.label = label

    checkbox:SetScript("OnClick", function(self)
        local newValue = self:GetChecked() and true or false
        self:SetChecked(newValue)
        setter(newValue)
        if parent.RefreshAll then
            parent:RefreshAll()
        end
    end)

    local function RefreshNewTagBadge(target)
        SetNewTagBadge(target, IsOptionRowMarkedNew(parent, label:GetText() or text, options), {
            relativeTo = label,
            point = "LEFT",
            relativePoint = "RIGHT",
            x = 8,
            y = 0,
        })
    end

    checkbox.nomtoolsControlType = "checkbox"
    checkbox.Refresh = function(self)
        self:SetChecked(getter())
        RefreshNewTagBadge(self)
    end

    RefreshNewTagBadge(checkbox)

    return checkbox
end

local function ApplyModuleEnabledSetting(moduleKey, enabled, applySetting, refreshCallback, options)
    local shouldRefresh = true

    if ns.SetModuleEnabled then
        shouldRefresh = ns.SetModuleEnabled(moduleKey, enabled, applySetting, options) ~= false
    elseif type(applySetting) == "function" then
        applySetting(enabled and true or false)
    end

    if shouldRefresh and type(refreshCallback) == "function" then
        refreshCallback()
    end
end

local function ApplyRaidMarkerIcon(texture, iconIndex)
    if not texture or type(iconIndex) ~= "number" or iconIndex <= 0 then
        if texture then
            texture:SetTexture(nil)
            texture:Hide()
        end
        return
    end

    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. tostring(iconIndex))
    texture:SetTexCoord(0, 1, 0, 1)
    texture:Show()
end

local function UpdateDropdownDisplayText(dropdown, fallbackText)
    if not dropdown or not dropdown.Text then
        return
    end

    local displayText = dropdown.getText and dropdown.getText() or fallbackText or ""
    dropdown.Text:SetText(displayText)
end

local function CreateDropdown(parent, x, y, labelText, width, getText, setupMenu, menuMaxHeight, options)
    if type(menuMaxHeight) == "table" and options == nil then
        options = menuMaxHeight
        menuMaxHeight = nil
    end
    options = options or {}

    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    dropdown:SetSize(width or 280, 28)
    MarkAutoFitChild(dropdown)

    dropdown:SetupMenu(function(owner, rootDescription)
        if menuMaxHeight and menuMaxHeight < DROPDOWN_MAX_MENU_HEIGHT then
            rootDescription:SetScrollMode(menuMaxHeight)
        end
        local multiSel = owner and owner.multiSelect or false
        local entries = setupMenu(owner) or {}
        for _, entry in ipairs(entries) do
            if entry.type == "title" then
                rootDescription:CreateTitle(entry.text or "")
            elseif entry.type == "divider" then
                if rootDescription.CreateDivider then
                    rootDescription:CreateDivider()
                end
            else
                local isCheckedFn
                if type(entry.isChecked) == "function" then
                    isCheckedFn = entry.isChecked
                else
                    local snap = entry.checked == true
                    isCheckedFn = function() return snap end
                end
                local entryOnSelect = entry.onSelect
                local entryValue = entry.value
                local entryText = entry.text or ""
                local selectFn = function()
                    if entryOnSelect then
                        entryOnSelect(entryValue)
                    end

                    if owner then
                        UpdateDropdownDisplayText(owner, entryText)
                        if owner.refreshParentOnSelect ~= false and owner.parent and owner.parent.RefreshAll then
                            owner.parent:RefreshAll()
                        end
                    end
                end
                if multiSel then
                    rootDescription:CreateCheckbox(entryText, isCheckedFn, selectFn)
                else
                    rootDescription:CreateRadio(entryText, isCheckedFn, selectFn)
                end
            end
        end
    end)

    dropdown.label = label
    dropdown.parent = parent
    dropdown.nomtoolsControlType = "dropdown"
    dropdown.multiSelect = false
    dropdown.getText = getText

    local function RefreshNewTagBadge(target)
        SetNewTagBadge(target, IsOptionRowMarkedNew(parent, label:GetText() or labelText, options), {
            relativeTo = label,
            point = "LEFT",
            relativePoint = "RIGHT",
            x = 8,
            y = 0,
        })
    end

    dropdown.Refresh = function(self)
        UpdateDropdownDisplayText(self)
        RefreshNewTagBadge(self)
        if self.GenerateMenu then
            self:GenerateMenu()
        end
    end

    RefreshNewTagBadge(dropdown)

    return dropdown
end

local function SetPreviewFont(fontString, fontPath, fontSize, fontFlags)
    if not fontString then
        return false
    end

    if fontString:SetFont(fontPath or STANDARD_TEXT_FONT, fontSize or 12, fontFlags or "") then
        return true
    end

    return fontString:SetFont(STANDARD_TEXT_FONT, fontSize or 12, fontFlags or "")
end

local function ResetStandardOptionFont(fontString, fontSize)
    if not fontString then
        return
    end

    fontString:SetFontObject((fontSize and fontSize <= 12) and GameFontHighlightSmall or GameFontHighlight)
    fontString:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
end

local function ForwardPopupMouseWheel(popup, delta)
    if not popup or not popup.scrollFrame then
        return
    end

    local scrollFrame = popup.scrollFrame
    local current = scrollFrame:GetVerticalScroll() or 0
    local childHeight = popup.scrollChild:GetHeight() or 0
    local frameHeight = scrollFrame:GetHeight() or 0
    local maxScroll = math.max(childHeight - frameHeight, 0)
    local nextValue = math.max(0, math.min(maxScroll, current - (delta * 18)))
    scrollFrame:SetVerticalScroll(nextValue)
end

local function CreatePickerPopup(frameName, scrollFrameName, options)
    local allowPreviewFonts = false
    local allowPreviewTextures = false
    if type(options) == "table" then
        allowPreviewFonts = options.previewFonts == true
        allowPreviewTextures = options.previewTextures == true
    else
        allowPreviewFonts = options and true or false
    end

    local popup = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    popup:SetClampedToScreen(true)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup.allowPreviewFonts = allowPreviewFonts
    popup.allowPreviewTextures = allowPreviewTextures
    popup:SetBackdrop(PANEL_BACKDROP)
    popup:SetBackdropColor(SURFACE_BG_R - 0.05, SURFACE_BG_G - 0.04, SURFACE_BG_B - 0.03, 0.98)
    popup:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.95)
    popup:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", scrollFrameName, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -12)
    scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -30, 12)
    scrollFrame:EnableMouseWheel(true)
    popup.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollChild:EnableMouseWheel(true)
    scrollFrame:SetScrollChild(scrollChild)
    popup.scrollChild = scrollChild

    local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 2, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 2, 16)
    end
    popup.scrollBar = scrollBar

    popup.rows = {}

    local function HidePopup()
        local owner = popup.owner
        if owner then
            owner.isOpen = false
        end
        popup.owner = nil
        popup:Hide()
    end

    popup.HidePicker = HidePopup

    popup:SetScript("OnMouseWheel", function(_, delta)
        ForwardPopupMouseWheel(popup, delta)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        ForwardPopupMouseWheel(popup, delta)
    end)
    scrollChild:SetScript("OnMouseWheel", function(_, delta)
        ForwardPopupMouseWheel(popup, delta)
    end)

    popup:SetScript("OnHide", function()
        if popup.owner then
            popup.owner.isOpen = false
        end
    end)

    local function CreateRow(index)
        local row = CreateFrame("Button", nil, popup.scrollChild)
        row:SetHeight(20)
        row:EnableMouse(true)
        row:EnableMouseWheel(true)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        local check = row:CreateTexture(nil, "OVERLAY")
        check:SetSize(16, 16)
        check:SetPoint("LEFT", row, "LEFT", 1, -1)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.check = check

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        text:SetPoint("TOPLEFT", check, "TOPRIGHT", 2, 0)
        text:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        local icon = row:CreateTexture(nil, "OVERLAY")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", check, "RIGHT", 4, -1)
        icon:Hide()
        row.icon = icon

        local texturePreviewFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
        texturePreviewFrame:SetSize(60, 14)
        texturePreviewFrame:SetPoint("LEFT", check, "RIGHT", 4, -1)
        texturePreviewFrame:SetBackdrop(FIELD_BACKDROP)
        texturePreviewFrame:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 1)
        texturePreviewFrame:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.9)
        texturePreviewFrame:Hide()
        row.texturePreviewFrame = texturePreviewFrame

        local texturePreview = texturePreviewFrame:CreateTexture(nil, "ARTWORK")
        texturePreview:SetPoint("TOPLEFT", texturePreviewFrame, "TOPLEFT", 1, -1)
        texturePreview:SetPoint("BOTTOMRIGHT", texturePreviewFrame, "BOTTOMRIGHT", -1, 1)
        row.texturePreview = texturePreview

        local divider = row:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("LEFT", row, "LEFT", 6, 0)
        divider:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        divider:SetHeight(1)
        divider:SetColorTexture(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 1)
        divider:Hide()
        row.divider = divider

        row:SetScript("OnClick", function(self)
            if not popup.owner or self.entryType ~= "option" then
                return
            end

            if self.onSelect then
                self.onSelect(self.value)
            elseif popup.owner.setter then
                popup.owner.setter(self.value)
            end

            if popup.owner.Refresh then
                popup.owner:Refresh()
            end

            if popup.owner.refreshParentOnSelect ~= false and popup.owner.parent and popup.owner.parent.RefreshAll then
                popup.owner.parent:RefreshAll()
            end
            if not popup.owner.multiSelect then
                HidePopup()
            end
        end)

        row:SetScript("OnMouseWheel", function(_, delta)
            ForwardPopupMouseWheel(popup, delta)
        end)

        if index == 1 then
            row:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", popup.rows[index - 1], "BOTTOMLEFT", 0, 0)
        end
        row:SetPoint("RIGHT", popup.scrollChild, "RIGHT", 0, 0)

        popup.rows[index] = row
        return row
    end

    function popup:Refresh(resetScroll)
        if not self.owner then
            return
        end

        local entries = self.owner.getEntries and self.owner:getEntries() or {}
        local width = math.max((self.owner:GetWidth() or 240) - 10, 220)
        local currentScroll = self.scrollFrame:GetVerticalScroll() or 0
        local totalHeight = 0

        self.scrollChild:SetWidth(width)

        for index, entry in ipairs(entries) do
            local row = self.rows[index] or CreateRow(index)
            row.entryType = entry.type or "option"
            row.value = entry.value
            row.onSelect = entry.onSelect
            row.text:ClearAllPoints()
            row.text:SetPoint("TOPLEFT", row.check, "TOPRIGHT", 2, 0)
            row.text:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
            row.texturePreviewFrame:Hide()

            if row.entryType == "divider" then
                row:SetHeight(10)
                row:Disable()
                row.check:Hide()
                row.icon:Hide()
                row.text:Hide()
                row.divider:Show()
            elseif row.entryType == "title" then
                row:SetHeight(20)
                row:Disable()
                row.check:Hide()
                row.icon:Hide()
                row.divider:Hide()
                row.text:Show()
                row.text:SetFontObject(GameFontNormalSmall)
                row.text:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
                row.text:SetText(entry.text or "")
            else
                row:SetHeight((self.allowPreviewTextures and entry.texturePath) and 24 or 20)
                row:Enable()
                row.check:SetShown(entry.checked == true)
                row.divider:Hide()
                row.text:Show()
                row.text:ClearAllPoints()

                if entry.raidTargetIcon and entry.raidTargetIcon > 0 then
                    row.texturePreviewFrame:Hide()
                    ApplyRaidMarkerIcon(row.icon, entry.raidTargetIcon)
                    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
                elseif self.allowPreviewTextures and entry.texturePath then
                    ApplyRaidMarkerIcon(row.icon, 0)
                    row.texturePreviewFrame:Show()
                    ApplyTexturePreviewSwatch(row.texturePreviewFrame, row.texturePreview, entry.texturePath, entry.previewMode)
                    row.text:SetPoint("TOPLEFT", row.texturePreviewFrame, "TOPRIGHT", 8, 0)
                else
                    row.texturePreviewFrame:Hide()
                    ApplyRaidMarkerIcon(row.icon, 0)
                    row.text:SetPoint("TOPLEFT", row.check, "TOPRIGHT", 2, 0)
                end

                row.text:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
                row.text:SetText(entry.text or "")
                if self.allowPreviewFonts and entry.fontPath then
                    SetPreviewFont(row.text, entry.fontPath, 13, "")
                    row.text:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
                else
                    row.text:SetFontObject(GameFontHighlightSmall)
                    row.text:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
                end
            end

            totalHeight = totalHeight + row:GetHeight()
            row:Show()
        end

        for index = #entries + 1, #self.rows do
            self.rows[index]:Hide()
        end

        totalHeight = math.max(totalHeight, 20)
        local maxVisibleHeight = math.min(self.owner.menuMaxHeight or DROPDOWN_MAX_MENU_HEIGHT, math.floor((UIParent:GetHeight() or 800) * 0.45))
        local visibleHeight = math.min(totalHeight, maxVisibleHeight)

        self.scrollChild:SetHeight(totalHeight)
        self:SetWidth(math.max((self.owner:GetWidth() or 240) + 18, 238))
        self:SetHeight(visibleHeight + 24)

        if resetScroll then
            self.scrollFrame:SetVerticalScroll(0)
        else
            local maxScroll = math.max(totalHeight - visibleHeight, 0)
            self.scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, currentScroll)))
        end

        if self.scrollBar then
            self.scrollBar:SetShown(totalHeight > visibleHeight)
        end
    end

    return popup
end

function EnsureFontPickerPopup()
    if activeFontPickerPopup then
        return activeFontPickerPopup
    end

    activeFontPickerPopup = CreatePickerPopup("NomToolsFontPickerPopup", "NomToolsFontPickerPopupScrollFrame", { previewFonts = true })
    return activeFontPickerPopup
end

function EnsureTexturePickerPopup()
    if activeTexturePickerPopup then
        return activeTexturePickerPopup
    end

    activeTexturePickerPopup = CreatePickerPopup("NomToolsTexturedPickerPopup", "NomToolsTexturedPickerPopupScrollFrame", { previewTextures = true })
    return activeTexturePickerPopup
end

local function RefreshPanel(panel)
    for _, control in ipairs(panel.refreshers or {}) do
        local canRefresh = type(control.Refresh) == "function"

        if canRefresh and control.IsVisible and not control:IsVisible() then
            canRefresh = false
        end

        if canRefresh then
            control:Refresh()
        end
    end
end

local function SchedulePanelRefresh(panel)
    if not panel or panel.refreshScheduled then
        return
    end

    panel.refreshScheduled = true
    C_Timer.After(0, function()
        if not panel then
            return
        end

        if panel.IsShown and not panel:IsShown() then
            panel.refreshScheduled = false
            return
        end

        panel.refreshScheduled = false

        if type(panel.RefreshAll) == "function" then
            panel:RefreshAll()
        end
    end)
end

local function FindStaticChoiceLabel(choices, key, fallback)
    if type(choices) == "function" then
        choices = choices()
    end

    for _, choice in ipairs(choices) do
        if choice.key == key then
            return choice.name
        end
    end

    return fallback or "Unknown"
end

local function FindStaticChoiceEntry(choices, key)
    if type(choices) == "function" then
        choices = choices()
    end

    for _, choice in ipairs(choices) do
        if choice.key == key then
            return choice
        end
    end

    return nil
end

local function FormatSliderValue(value, decimals, suffix)
    local precision = decimals or 0
    local formatted = string.format("%0." .. precision .. "f", value)
    if precision == 0 then
        formatted = tostring(math.floor((value or 0) + 0.5))
    end

    return suffix and (formatted .. suffix) or formatted
end

local function FormatChoiceMenuLabel(item)
    if item.count and item.count > 0 then
        return string.format("%s (%d)", item.name, item.count)
    end

    return item.name
end

local function CreateStaticDropdown(parent, x, y, labelText, width, choices, getter, setter, fallbackText)
    local dropdown = CreateDropdown(
        parent,
        x,
        y,
        labelText,
        width,
        function()
            return FindStaticChoiceLabel(choices, getter(), fallbackText)
        end,
        function(_, rootDescription)
            local resolvedChoices = type(choices) == "function" and choices() or choices
            local entries = {}
            local function IsSelected(value)
                return getter() == value
            end

            local function SetSelected(value)
                setter(value)
            end

            for _, choice in ipairs(resolvedChoices) do
                entries[#entries + 1] = {
                    type = "option",
                    text = choice.name,
                    raidTargetIcon = choice.icon,
                    value = choice.key,
                    checked = IsSelected(choice.key),
                    isChecked = function()
                        return IsSelected(choice.key)
                    end,
                    onSelect = SetSelected,
                }
            end
            return entries
        end
    )

    dropdown.getPreviewData = function()
        local currentKey = getter()
        local choice = FindStaticChoiceEntry(choices, currentKey)
        if choice then
            return {
                text = choice.name,
                raidTargetIcon = choice.icon,
            }
        end

        return {
            text = fallbackText or FindStaticChoiceLabel(choices, currentKey, fallbackText),
        }
    end

    return dropdown
end

local function CreateFontDropdown(parent, x, y, labelText, width, getter, setter, fallbackText, options)
    options = options or {}

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

    fontPickerSequence = fontPickerSequence + 1

    local button = CreateFrame("DropdownButton", "NomToolsFontPicker" .. fontPickerSequence, parent, "WowStyle1DropdownTemplate")
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    button:SetSize(width or 320, 28)
    MarkAutoFitChild(button)

    -- Feed the current selection as a checked radio so GenerateMenu (called by the
    -- template whenever any menu state changes globally) always has a checked entry
    -- and correctly sets self.Text instead of clearing it.
    button:SetupMenu(function(owner, rootDescription)
        local fontKey = getter()
        local fontName = ns.GetFontLabel(fontKey) or fallbackText or "Friz Quadrata TT"
        rootDescription:CreateRadio(fontName, function() return true end, function() end)
    end)

    -- Open the custom font picker popup (which renders each font in its own typeface) on click.
    button:SetScript("OnClick", function(self)
        local popup = EnsureFontPickerPopup()
        if popup.owner == self and popup:IsShown() then
            popup:HidePicker()
            return
        end

        if activeTexturePickerPopup and activeTexturePickerPopup:IsShown() then
            activeTexturePickerPopup:HidePicker()
        end

        popup.owner = self
        self.isOpen = true
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        popup:Refresh(true)
        popup:Show()
        popup:Raise()
    end)

    button:SetScript("OnHide", function(self)
        if activeFontPickerPopup and activeFontPickerPopup.owner == self then
            activeFontPickerPopup:HidePicker()
        end
    end)

    button.label = label
    button.parent = parent
    button.getter = getter
    button.setter = setter
    button.nomtoolsControlType = "fontpicker"
    button.isOpen = false
    button.menuMaxHeight = DROPDOWN_MAX_MENU_HEIGHT
    button.getEntries = function()
        local choices = ns.GetFontChoices and ns.GetFontChoices(options.includeGlobalChoice ~= false) or {}
        local selected = button.getter()
        local entries = {}

        for _, choice in ipairs(choices) do
            entries[#entries + 1] = {
                type = "option",
                text = choice.name,
                value = choice.key,
                checked = choice.key == selected,
                fontPath = choice.path or ns.GetFontPath(choice.key),
            }
        end

        return entries
    end

    local function RefreshText(self)
        -- GenerateMenu re-runs the SetupMenu callback (which calls getter() for the
        -- current selection) and updates self.Text content, just like CreateDropdown does.
        if self.GenerateMenu then
            self:GenerateMenu()
        end
        -- SetFont / SetPreviewFont only affects the font face; it does not get reset by
        -- GenerateMenu's SetText call, so re-applying it here keeps the text rendering
        -- in the chosen typeface after every refresh.
        local fontKey = self.getter()
        local fontName = ns.GetFontLabel(fontKey) or fallbackText or "Friz Quadrata TT"
        local fontPath = ns.GetFontPath(fontKey)
        if self.Text then
            self.Text:SetText(fontName)
            SetPreviewFont(self.Text, fontPath, 13, "")
        end

        if activeFontPickerPopup and activeFontPickerPopup.owner == self and activeFontPickerPopup:IsShown() then
            activeFontPickerPopup:Refresh(false)
        end
    end

    button.Refresh = RefreshText

    return button
end

local function CreateStatusBarTextureDropdown(parent, x, y, labelText, width, getter, setter, fallbackText, options)
    options = options or {}
    local textureChoiceProvider = options.choiceProvider or ns.GetStatusBarTextureChoices
    local textureLabelProvider = options.labelProvider or ns.GetStatusBarTextureLabel
    local texturePathResolver = options.texturePathResolver or ns.GetStatusBarTexturePath
    local previewMode = options.previewMode or "fill"

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

    texturePickerSequence = texturePickerSequence + 1

    local button = CreateFrame("DropdownButton", "NomToolsTexturePicker" .. texturePickerSequence, parent, "WowStyle1DropdownTemplate")
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    button:SetSize(width or 320, 28)
    MarkAutoFitChild(button)

    -- Texture swatch preview embedded inside the button.
    local previewFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
    previewFrame:SetPoint("LEFT", button, "LEFT", 8, 0)
    previewFrame:SetSize(64, 12)
    previewFrame:SetBackdrop(FIELD_BACKDROP)
    previewFrame:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 1)
    previewFrame:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.9)
    button.previewFrame = previewFrame

    local previewTexture = previewFrame:CreateTexture(nil, "ARTWORK")
    previewTexture:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 1, -1)
    previewTexture:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -1, 1)
    button.previewTexture = previewTexture

    -- Reposition the template's text label to sit to the right of the swatch.
    if button.Text then
        button.Text:ClearAllPoints()
        button.Text:SetPoint("LEFT", previewFrame, "RIGHT", 6, 0)
        button.Text:SetPoint("RIGHT", button, "RIGHT", -24, 0)
        button.Text:SetJustifyH("LEFT")
    end

    -- Feed the current selection as a checked radio so GenerateMenu (called by the
    -- template whenever any menu state changes globally) always has a checked entry
    -- and correctly sets self.Text instead of clearing it.
    button:SetupMenu(function(owner, rootDescription)
        local textureKey = getter()
            local textureName = (textureLabelProvider and textureLabelProvider(textureKey)) or fallbackText or "Default Status Bar"
        rootDescription:CreateRadio(textureName, function() return true end, function() end)
    end)

    -- Open the custom texture picker popup (which shows texture swatches in the list) on click.
    button:SetScript("OnClick", function(self)
        local popup = EnsureTexturePickerPopup()
        if popup.owner == self and popup:IsShown() then
            popup:HidePicker()
            return
        end

        if activeFontPickerPopup and activeFontPickerPopup:IsShown() then
            activeFontPickerPopup:HidePicker()
        end

        popup.owner = self
        self.isOpen = true
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        popup:Refresh(true)
        popup:Show()
        popup:Raise()
    end)

    button:SetScript("OnHide", function(self)
        if activeTexturePickerPopup and activeTexturePickerPopup.owner == self then
            activeTexturePickerPopup:HidePicker()
        end
    end)

    button.label = label
    button.parent = parent
    button.getter = getter
    button.setter = setter
    button.nomtoolsControlType = "texturepicker"
    button.isOpen = false
    button.menuMaxHeight = DROPDOWN_MAX_MENU_HEIGHT
    button.getEntries = function()
        local choices = textureChoiceProvider and textureChoiceProvider(options.includeGlobalChoice ~= false) or {}
        local selected = button.getter()
        local entries = {}

        for _, choice in ipairs(choices) do
            entries[#entries + 1] = {
                type = "option",
                text = choice.name,
                value = choice.key,
                checked = choice.key == selected,
                texturePath = choice.path or (texturePathResolver and texturePathResolver(choice.key)) or choice.key,
                previewMode = previewMode,
            }
        end

        return entries
    end

    local function RefreshTexture(self)
        -- GenerateMenu re-runs the SetupMenu callback (which calls getter() for the
        -- current selection) and updates self.Text content, just like CreateDropdown does.
        if self.GenerateMenu then
            self:GenerateMenu()
        end
        local textureKey = self.getter()
            local textureName = (textureLabelProvider and textureLabelProvider(textureKey)) or fallbackText or "Default Status Bar"
        local texturePath = (texturePathResolver and texturePathResolver(textureKey)) or textureKey
        ApplyTexturePreviewSwatch(self.previewFrame, self.previewTexture, texturePath, previewMode)
        if self.Text then
            self.Text:SetText(textureName)
        end

        if activeTexturePickerPopup and activeTexturePickerPopup.owner == self and activeTexturePickerPopup:IsShown() then
            activeTexturePickerPopup:Refresh(false)
        end
    end

    button.Refresh = RefreshTexture

    return button
end

local function CreateSlider(parent, x, y, labelText, width, minValue, maxValue, valueStep, getter, setter, formatter)
    sliderSequence = sliderSequence + 1
    local resolvedWidth = math.max(tonumber(width) or 0, STANDARD_DROPDOWN_WIDTH)

    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    local control = CreateFrame("Frame", "NomToolsOptionsSlider" .. sliderSequence, parent)
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    control:SetSize(resolvedWidth, 58)
    MarkAutoFitChild(control)

    local label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)
    label:SetPoint("TOPRIGHT", control, "TOPRIGHT", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetText(labelText)
    label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    control.label = label

    local sliderFrame = CreateFrame("Frame", nil, control, "MinimalSliderWithSteppersTemplate")
    sliderFrame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    sliderFrame:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -4)
    sliderFrame:SetHeight(20)
    sliderFrame:EnableMouseWheel(false)

    local slider = sliderFrame.Slider or sliderFrame
    if sliderFrame.LeftText then sliderFrame.LeftText:Hide() end
    if sliderFrame.RightText then sliderFrame.RightText:Hide() end
    if sliderFrame.TopText then sliderFrame.TopText:Hide() end
    if sliderFrame.MinText then sliderFrame.MinText:Hide() end
    if sliderFrame.MaxText then sliderFrame.MaxText:Hide() end

    if slider and slider.ClearAllPoints then
        slider:ClearAllPoints()
        slider:SetPoint("TOPLEFT", sliderFrame, "TOPLEFT", 16, 0)
        slider:SetPoint("BOTTOMRIGHT", sliderFrame, "BOTTOMRIGHT", -16, 0)
    end

    local totalSteps = math.max(1, math.floor(((maxValue - minValue) / valueStep) + 0.5))
    if sliderFrame.Init then
        sliderFrame:Init(getter(), minValue, maxValue, totalSteps, nil)
    end

    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(valueStep)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(false)
    control.sliderFrame = sliderFrame
    control.slider = slider

    local unitSuffix = ""
    if formatter then
        local sample = formatter(0)
        unitSuffix = sample:match("^%s*[-+]?%d+%.?%d*%s*(.-)%s*$") or ""
    end
    local editBoxWidth = (unitSuffix ~= "") and 52 or 76

    local editBox = CreateFrame("EditBox", nil, control, "BackdropTemplate")
    editBox:SetAutoFocus(false)
    editBox:SetPoint("TOP", sliderFrame, "BOTTOM", 0, -3)
    editBox:SetSize(editBoxWidth, 18)
    editBox:SetJustifyH("CENTER")
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    editBox:SetBackdrop(SLIDER_VALUE_BACKDROP)
    editBox:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 1)
    editBox:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.9)
    control.editBox = editBox

    if unitSuffix ~= "" then
        local unitLabel = control:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        unitLabel:SetPoint("LEFT", editBox, "RIGHT", 4, 0)
        unitLabel:SetText(unitSuffix)
        unitLabel:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
        control.unitLabel = unitLabel
    end

    local suppressCallback = false

    local function ClampToStep(value)
        local offset = value - minValue
        local steps = math.floor((offset / valueStep) + 0.5)
        local normalized = minValue + (steps * valueStep)
        if normalized < minValue then
            normalized = minValue
        elseif normalized > maxValue then
            normalized = maxValue
        end
        return normalized
    end

    local function ParseValue(text)
        if type(text) ~= "string" then
            return nil
        end

        local numeric = text:match("[-+]?%d+%.?%d*") or text:match("[-+]?%.%d+")
        if not numeric then
            return nil
        end

        return tonumber(numeric)
    end

    local function FormatEditBoxValue(value)
        local normalized = ClampToStep(value)
        if formatter then
            local full = formatter(normalized)
            return full:match("^([-+]?%d+%.?%d*)") or tostring(math.floor(normalized + 0.5))
        end
        return FormatSliderValue(normalized)
    end

    local function ApplyValue(value, fireCallback)
        local normalized = ClampToStep(value)
        suppressCallback = true
        if sliderFrame.SetValue then
            sliderFrame:SetValue(normalized)
        else
            slider:SetValue(normalized)
        end
        suppressCallback = false
        editBox:SetText(FormatEditBoxValue(normalized))

        if fireCallback then
            setter(normalized)
            if parent.RefreshAll then
                parent:RefreshAll()
            end
        end
    end

    local function OnSliderValueChanged(_, value)
        local normalized = ClampToStep(value)
        if math.abs(normalized - value) > 0.0001 then
            suppressCallback = true
            slider:SetValue(normalized)
            suppressCallback = false
            return
        end

        editBox:SetText(FormatEditBoxValue(normalized))

        if suppressCallback then
            return
        end

        setter(normalized)
        if parent.RefreshAll then
            parent:RefreshAll()
        end
    end

    if sliderFrame.RegisterCallback and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
        sliderFrame:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, OnSliderValueChanged)
    else
        slider:SetScript("OnValueChanged", OnSliderValueChanged)
    end

    editBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text == "" then
            ApplyValue(0, true)
        else
            local parsed = ParseValue(text)
            if parsed == nil then
                ApplyValue(getter(), false)
            else
                ApplyValue(parsed, true)
            end
        end
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        ApplyValue(getter(), false)
        self:ClearFocus()
    end)

    control.Refresh = function(self)
        if editBox:HasFocus() then return end
        ApplyValue(getter(), false)
    end

    control.nomtoolsControlType = "slider"
    return control
end

---@param parent Frame
---@param x number
---@param y number
---@param labelText string
---@param axis string
---@param getter function
---@param setter function
---@return Frame
function ns.CreateOptionsPositionSlider(parent, x, y, labelText, axis, getter, setter)
    local limit = ns.GetPositionSliderLimit(axis)
    return CreateSlider(
        parent,
        x,
        y,
        labelText,
        APPEARANCE_COLUMN_WIDTH,
        -limit,
        limit,
        1,
        getter,
        setter,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
end

local function SetTextBlockPosition(textBlock, parent, x, y, width)
    if not textBlock then
        return
    end

    textBlock:ClearAllPoints()
    textBlock:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then
        textBlock:SetWidth(width)
    end
end

local function SetControlShown(control, shown)
    if not control then
        return
    end

    control:SetShown(shown)

    if control.label then
        control.label:SetShown(shown)
    end
    if control.valueLabel then
        control.valueLabel:SetShown(shown)
    end
    if control.textLabel then
        control.textLabel:SetShown(shown)
    end
    if control.lowLabel then
        control.lowLabel:SetShown(shown)
    end
    if control.highLabel then
        control.highLabel:SetShown(shown)
    end
    if control.unitLabel then
        control.unitLabel:SetShown(shown)
    end
end

local function SetControlEnabled(control, enabled)
    if not control then
        return
    end

    local alpha = enabled and 1 or 0.45
    control:SetAlpha(alpha)

    if control.label then
        control.label:SetAlpha(alpha)
    end
    if control.valueLabel then
        control.valueLabel:SetAlpha(alpha)
    end
    if control.textLabel then
        control.textLabel:SetAlpha(alpha)
    end
    if control.lowLabel then
        control.lowLabel:SetAlpha(alpha)
    end
    if control.highLabel then
        control.highLabel:SetAlpha(alpha)
    end
    if control.unitLabel then
        control.unitLabel:SetAlpha(alpha)
    end

    if control.nomtoolsControlType == "slider" then
        if control.sliderFrame and control.sliderFrame.SetEnabled then
            control.sliderFrame:SetEnabled(enabled)
        end
        if control.slider then
            if control.slider.EnableMouse then
                control.slider:EnableMouse(enabled)
            end
            if control.slider.EnableMouseWheel then
                control.slider:EnableMouseWheel(enabled)
            end
            local thumb = control.slider.GetThumbTexture and control.slider:GetThumbTexture() or nil
            if thumb then
                thumb:SetAlpha(enabled and 1 or 0.35)
            end
        end
        if control.editBox then
            if control.editBox.SetEnabled then
                control.editBox:SetEnabled(enabled)
            elseif control.editBox.EnableMouse then
                control.editBox:EnableMouse(enabled)
            end
            control.editBox:SetAlpha(enabled and 1 or 0.6)
        end
        return
    end

    if control.nomtoolsControlType == "color" or control.nomtoolsControlType == "checkbox" or control.nomtoolsControlType == "dropdown" or control.nomtoolsControlType == "fontpicker" or control.nomtoolsControlType == "texturepicker" then
        if enabled then
            if control.Enable then
                control:Enable()
            end
        else
            if control.Disable then
                control:Disable()
            end
        end
        if control.nomtoolsControlType == "color" and control.toggleControl then
            if enabled then
                control.toggleControl:Enable()
            else
                control.toggleControl:Disable()
            end
        end
        if control.nomtoolsControlType == "color" and control.Refresh then
            control:Refresh()
        end
    end
end

local function SetControlGroupEnabled(controls, enabled)
    if type(controls) ~= "table" then
        return
    end

    for _, control in ipairs(controls) do
        SetControlEnabled(control, enabled)
    end
end

local function PositionControl(control, parent, x, y)
    if not control then
        return
    end

    if parent and parent.nomtoolsSectionCard then
        y = y + (parent.nomtoolsContentYOffset or 0)
    end

    if control.nomtoolsControlType == "checkbox" then
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        return
    end

    if control.nomtoolsControlType == "dropdown" then
        if control.label then
            control.label:ClearAllPoints()
            control.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        end
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -6)
        return
    end

    if control.nomtoolsControlType == "fontpicker" then
        if control.label then
            control.label:ClearAllPoints()
            control.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        end
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -6)
        return
    end

    if control.nomtoolsControlType == "texturepicker" then
        if control.label then
            control.label:ClearAllPoints()
            control.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        end
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -6)
        return
    end

    if control.nomtoolsControlType == "color" then
        if control.label then
            control.label:ClearAllPoints()
            control.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        end
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -6)
        return
    end

    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

local function CreateConsumableDropdown(parent, x, y, labelText, kind, getter, setter, options)
    options = options or {}

    return CreateDropdown(
        parent,
        x,
        y,
        labelText,
        options.width or STANDARD_DROPDOWN_WIDTH,
        function()
            return ns.GetChoiceLabel(kind, getter() or "auto")
        end,
        function(_, rootDescription)
            local function SetSelected(value)
                setter(value)
                if parent.RefreshAll then
                    parent:RefreshAll()
                end
            end

            local function IsSelected(value)
                return (getter() or "auto") == value
            end

            local entries = {
                {
                    type = "title",
                    text = "Special",
                },
                {
                    type = "option",
                    text = ns.GetChoiceLabel(kind, "auto"),
                    value = "auto",
                    checked = (getter() or "auto") == "auto",
                    isChecked = function()
                        return IsSelected("auto")
                    end,
                    onSelect = SetSelected,
                },
            }

            if options.allowNone then
                entries[#entries + 1] = {
                    type = "option",
                    text = ns.GetChoiceLabel(kind, "none"),
                    value = "none",
                    checked = IsSelected("none"),
                    isChecked = function()
                        return IsSelected("none")
                    end,
                    onSelect = SetSelected,
                }
            end

            local owned, missing = ns.GetChoiceMenuEntries(kind)
            local ownedTitle = "In Bags"
            local missingTitle = "Not in Bags"
            if ns.GetChoiceMenuBucketLabels then
                ownedTitle, missingTitle = ns.GetChoiceMenuBucketLabels(kind)
            end

            local function PassesFilter(item)
                if type(options.filter) == "function" then
                    return options.filter(item)
                end

                return true
            end

            local filteredOwned = {}
            for _, item in ipairs(owned) do
                if PassesFilter(item) then
                    filteredOwned[#filteredOwned + 1] = item
                end
            end

            local filteredMissing = {}
            for _, item in ipairs(missing) do
                if PassesFilter(item) then
                    filteredMissing[#filteredMissing + 1] = item
                end
            end

            if #filteredOwned > 0 then
                entries[#entries + 1] = { type = "divider" }
                entries[#entries + 1] = { type = "title", text = ownedTitle }
                for _, item in ipairs(filteredOwned) do
                    entries[#entries + 1] = {
                        type = "option",
                        text = FormatChoiceMenuLabel(item),
                        value = item.key,
                        checked = IsSelected(item.key),
                        isChecked = function()
                            return IsSelected(item.key)
                        end,
                        onSelect = SetSelected,
                    }
                end
            end

            if #filteredMissing > 0 then
                entries[#entries + 1] = { type = "divider" }
                entries[#entries + 1] = { type = "title", text = missingTitle }
                for _, item in ipairs(filteredMissing) do
                    entries[#entries + 1] = {
                        type = "option",
                        text = item.name,
                        value = item.key,
                        checked = IsSelected(item.key),
                        isChecked = function()
                            return IsSelected(item.key)
                        end,
                        onSelect = SetSelected,
                    }
                end
            end

            return entries
        end
    )
end

local function CreateExplicitEntryDropdown(parent, x, y, labelText, entries, getter, setter, options)
    options = options or {}

    local function GetLabel(key)
        if key == "auto" then
            return options.autoLabel or "Auto"
        end
        if key == "none" then
            return "None"
        end

        for _, entry in ipairs(entries or {}) do
            if entry.key == key then
                return entry.name or key
            end
        end

        return options.autoLabel or "Auto"
    end

    return CreateDropdown(
        parent,
        x,
        y,
        labelText,
        options.width or STANDARD_DROPDOWN_WIDTH,
        function()
            return GetLabel(getter() or "auto")
        end,
        function()
            local function SetSelected(value)
                setter(value)
                if parent.RefreshAll then
                    parent:RefreshAll()
                end
            end

            local selectedValue = getter() or "auto"
            local function IsSelected(value)
                return (getter() or "auto") == value
            end

            local menuEntries = {
                {
                    type = "title",
                    text = "Special",
                },
                {
                    type = "option",
                    text = options.autoLabel or "Auto",
                    value = "auto",
                    checked = selectedValue == "auto",
                    isChecked = function()
                        return IsSelected("auto")
                    end,
                    onSelect = SetSelected,
                },
            }

            if options.allowNone then
                menuEntries[#menuEntries + 1] = {
                    type = "option",
                    text = "None",
                    value = "none",
                    checked = selectedValue == "none",
                    isChecked = function()
                        return IsSelected("none")
                    end,
                    onSelect = SetSelected,
                }
            end

            local available = {}
            local unavailable = {}
            for _, entry in ipairs(entries or {}) do
                local item = {
                    entry = entry,
                    key = entry.key,
                    name = entry.name,
                    count = entry.items and ns.GetEntryItemCount and ns.GetEntryItemCount(entry) or 0,
                }
                local isAvailable = options.isEntryAvailable and options.isEntryAvailable(entry)
                if isAvailable then
                    available[#available + 1] = item
                else
                    unavailable[#unavailable + 1] = item
                end
            end

            if #available > 0 then
                menuEntries[#menuEntries + 1] = { type = "divider" }
                menuEntries[#menuEntries + 1] = { type = "title", text = options.availableLabel or "Available" }
                for _, item in ipairs(available) do
                    menuEntries[#menuEntries + 1] = {
                        type = "option",
                        text = FormatChoiceMenuLabel(item),
                        value = item.key,
                        checked = selectedValue == item.key,
                        isChecked = function()
                            return IsSelected(item.key)
                        end,
                        onSelect = SetSelected,
                    }
                end
            end

            if #unavailable > 0 then
                menuEntries[#menuEntries + 1] = { type = "divider" }
                menuEntries[#menuEntries + 1] = { type = "title", text = options.unavailableLabel or "Unavailable" }
                for _, item in ipairs(unavailable) do
                    menuEntries[#menuEntries + 1] = {
                        type = "option",
                        text = item.name,
                        value = item.key,
                        checked = selectedValue == item.key,
                        isChecked = function()
                            return IsSelected(item.key)
                        end,
                        onSelect = SetSelected,
                    }
                end
            end

            return menuEntries
        end
    )
end

local function GetConsumableFilterLabel(filterKey)
    for _, filter in ipairs(ns.GetInstanceFilters and ns.GetInstanceFilters() or {}) do
        if filter.key == filterKey then
            return filter.name or filterKey
        end
    end

    return filterKey
end

local function GetConsumableVisibilityPreviewText(kind, filterKeys, setupIndex)
    local selected = {}

    for _, filterKey in ipairs(filterKeys or {}) do
        if ns.IsConsumableTrackerFilterEnabled and ns.IsConsumableTrackerFilterEnabled(kind, filterKey, setupIndex) then
            selected[#selected + 1] = GetConsumableFilterLabel(filterKey)
        end
    end

    if #selected == 0 then
        return "None"
    end

    if #selected == #(filterKeys or {}) then
        return "All"
    end

    return table.concat(selected, ", ")
end

local function CreateConsumableVisibilityDropdown(page, parent, x, y, labelText, kind, filterKeys, setupIndex)
    local dropdown = CreateDropdown(
        parent,
        x,
        y,
        labelText,
        FULL_DROPDOWN_WIDTH,
        function()
            return GetConsumableVisibilityPreviewText(kind, filterKeys, setupIndex)
        end,
        function()
            local entries = {}

            for _, filterKey in ipairs(filterKeys or {}) do
                local currentFilterKey = filterKey
                entries[#entries + 1] = {
                    type = "option",
                    text = GetConsumableFilterLabel(currentFilterKey),
                    value = currentFilterKey,
                    checked = ns.IsConsumableTrackerFilterEnabled and ns.IsConsumableTrackerFilterEnabled(kind, currentFilterKey, setupIndex),
                    isChecked = function()
                        return ns.IsConsumableTrackerFilterEnabled and ns.IsConsumableTrackerFilterEnabled(kind, currentFilterKey, setupIndex)
                    end,
                    onSelect = function(value)
                        if ns.SetConsumableTrackerFilterEnabled then
                            ns.SetConsumableTrackerFilterEnabled(kind, value, not ns.IsConsumableTrackerFilterEnabled(kind, value, setupIndex), setupIndex)
                        end
                        ns.RequestRefresh("consumables")
                        if page.RefreshAll then
                            page:RefreshAll()
                        end
                    end,
                }
            end

            return entries
        end
    )

    dropdown.multiSelect = true
    dropdown.refreshParentOnSelect = false
    page.refreshers[#page.refreshers + 1] = dropdown
    return dropdown
end

local TRACKING_CARD_COLUMN_WIDTH = 200
local TRACKING_CARD_COLUMN_SPACING = 20
local TRACKING_CARD_RIGHT_COLUMN_X = 338
local TRACKING_CARD_SLIDER_WIDTH = 310

local function CreateConsumableVisibilityCheckbox(page, card, kind, fieldKey, labelText, y, setupIndex)
    local checkbox = CreateCheckbox(
        card,
        labelText,
        18,
        y,
        function()
            local visibility = ns.GetConsumableVisibility and ns.GetConsumableVisibility(kind, setupIndex)
            return visibility and visibility[fieldKey]
        end,
        function(value)
            local visibility = ns.GetConsumableVisibility and ns.GetConsumableVisibility(kind, setupIndex)
            if visibility then
                visibility[fieldKey] = value and true or false
            end
            ns.RequestRefresh("consumables")
        end
    )
    page.refreshers[#page.refreshers + 1] = checkbox
    return checkbox
end

local function CreateConsumableLocationDropdownRow(page, card, kind, y, setupIndex)
    local dropdowns = {}

    for index, group in ipairs(ns.CONSUMABLE_VISIBILITY_GROUPS or {}) do
        local x = 18 + ((index - 1) * (TRACKING_CARD_COLUMN_WIDTH + TRACKING_CARD_COLUMN_SPACING))
        local dropdown = CreateDropdown(
            card,
            x,
            y,
            group.name,
            TRACKING_CARD_COLUMN_WIDTH,
            function()
                return GetConsumableVisibilityPreviewText(kind, group.filterKeys, setupIndex)
            end,
            function()
                local entries = {}

                for _, filterKey in ipairs(group.filterKeys or {}) do
                    local currentFilterKey = filterKey
                    entries[#entries + 1] = {
                        type = "option",
                        text = GetConsumableFilterLabel(currentFilterKey),
                        value = currentFilterKey,
                        checked = ns.IsConsumableTrackerFilterEnabled and ns.IsConsumableTrackerFilterEnabled(kind, currentFilterKey, setupIndex),
                        isChecked = function()
                            return ns.IsConsumableTrackerFilterEnabled and ns.IsConsumableTrackerFilterEnabled(kind, currentFilterKey, setupIndex)
                        end,
                        onSelect = function(value)
                            if ns.SetConsumableTrackerFilterEnabled then
                                ns.SetConsumableTrackerFilterEnabled(kind, value, not ns.IsConsumableTrackerFilterEnabled(kind, value, setupIndex), setupIndex)
                            end
                            ns.RequestRefresh("consumables")
                            if page.RefreshAll then
                                page:RefreshAll()
                            end
                        end,
                    }
                end

                return entries
            end
        )

        dropdown.multiSelect = true
        dropdown.refreshParentOnSelect = false
        page.refreshers[#page.refreshers + 1] = dropdown
        dropdowns[#dropdowns + 1] = dropdown
    end

    return dropdowns
end

local function CreatePrioritySection(parent, topY, sectionTitle, kind, setupIndex)
    local card = CreateSectionCard(
        parent,
        12,
        topY,
        676,
        420,
        sectionTitle,
        nil
    )
    card.nomtoolsContentYOffset = 0

    local enabledCheckbox = CreateCheckbox(
        card,
        "Enabled",
        18,
        -52,
        function()
            return ns.GetConsumableTrackerEnabled and ns.GetConsumableTrackerEnabled(kind, setupIndex)
        end,
        function(value)
            if ns.SetConsumableTrackerEnabled then
                ns.SetConsumableTrackerEnabled(kind, setupIndex, value)
            end
            RequestOptionsRefresh()
        end
    )
    parent.refreshers[#parent.refreshers + 1] = enabledCheckbox

    local showDuringCombatCheckbox = CreateConsumableVisibilityCheckbox(parent, card, kind, "showDuringCombat", "Show in Combat", -84, setupIndex)
    local showDuringMythicPlusCheckbox = CreateConsumableVisibilityCheckbox(parent, card, kind, "showDuringMythicPlus", "Show during Mythic+ Runs", -116, setupIndex)

    local reapplyCheckbox = CreateCheckbox(
        card,
        "Show when buff is expiring",
        18,
        -148,
        function()
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig(kind, setupIndex)
            return config and config.enabled
        end,
        function(value)
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig(kind, setupIndex)
            if config then
                config.enabled = value and true or false
            end
            RequestOptionsRefresh()
        end
    )
    parent.refreshers[#parent.refreshers + 1] = reapplyCheckbox

    local reapplySlider = CreateSlider(
        card,
        TRACKING_CARD_RIGHT_COLUMN_X,
        -140,
        "Reapply Threshold",
        TRACKING_CARD_SLIDER_WIDTH,
        1,
        60,
        1,
        function()
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig(kind, setupIndex)
            return math.floor(((config and config.thresholdSeconds) or 1800) / 60)
        end,
        function(value)
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig(kind, setupIndex)
            if config then
                config.thresholdSeconds = value * 60
            end
            RequestOptionsRefresh()
        end,
        function(value)
            return (value or 0) .. "m"
        end
    )
    local baseReapplySliderRefresh = reapplySlider.Refresh
    reapplySlider.Refresh = function(self)
        if baseReapplySliderRefresh then
            baseReapplySliderRefresh(self)
        end

        local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig(kind, setupIndex)
        SetControlEnabled(self, config and config.enabled == true)
    end
    parent.refreshers[#parent.refreshers + 1] = reapplySlider

    local priorityDropdowns = {}
    for priorityIndex = 1, ns.MAX_PRIORITY_CHOICES or 3 do
        local currentIndex = priorityIndex
        local priorityDropdown = CreateConsumableDropdown(
            card,
            18 + ((currentIndex - 1) * (TRACKING_CARD_COLUMN_WIDTH + TRACKING_CARD_COLUMN_SPACING)),
            -220,
            string.format("Priority %d", currentIndex),
            kind,
            function()
                local choices = ns.GetPriorityChoices(kind, setupIndex)
                return choices[currentIndex] or "none"
            end,
            function(value)
                ns.SetPriorityChoice(kind, currentIndex, value, setupIndex)
                RequestOptionsRefresh()
            end,
            {
                allowNone = true,
                width = TRACKING_CARD_COLUMN_WIDTH,
                filter = function(item)
                    if not item or type(item.key) ~= "string" then
                        return false
                    end

                    local choices = ns.GetPriorityChoices(kind, setupIndex) or {}
                    local currentValue = choices[currentIndex] or nil
                    if item.key == currentValue then
                        return true
                    end

                    for choiceIndex, choiceKey in ipairs(choices) do
                        if choiceIndex ~= currentIndex and choiceKey == item.key then
                            return false
                        end
                    end

                    return true
                end,
            }
        )
        parent.refreshers[#parent.refreshers + 1] = priorityDropdown
        priorityDropdowns[#priorityDropdowns + 1] = priorityDropdown
    end

    local locationDropdowns = CreateConsumableLocationDropdownRow(parent, card, kind, -294, setupIndex)

    function card:UpdateDisabledState()
        local trackerEnabled = ns.GetConsumableTrackerEnabled and ns.GetConsumableTrackerEnabled(kind, setupIndex) == true
        local reapplyConfig = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig(kind, setupIndex) or nil

        SetControlEnabled(showDuringCombatCheckbox, trackerEnabled)
        SetControlEnabled(showDuringMythicPlusCheckbox, trackerEnabled)
        SetControlEnabled(reapplyCheckbox, trackerEnabled)
        SetControlEnabled(reapplySlider, trackerEnabled and reapplyConfig and reapplyConfig.enabled == true)
        SetControlGroupEnabled(priorityDropdowns, trackerEnabled)
        SetControlGroupEnabled(locationDropdowns, trackerEnabled)
    end

    local fittedHeight = FitSectionCardHeight(card, 18)
    return card, topY - fittedHeight - 18
end

local function CreateRoguePoisonSection(parent, topY, sectionTitle, setupIndex)
    local card = CreateSectionCard(
        parent,
        12,
        topY,
        676,
        400,
        sectionTitle,
        nil
    )
    card.nomtoolsContentYOffset = 0

    local enabledCheckbox = CreateCheckbox(
        card,
        "Enabled",
        18,
        -52,
        function()
            return ns.GetConsumableTrackerEnabled and ns.GetConsumableTrackerEnabled("poisons", setupIndex)
        end,
        function(value)
            if ns.SetConsumableTrackerEnabled then
                ns.SetConsumableTrackerEnabled("poisons", setupIndex, value)
            end
            RequestOptionsRefresh()
        end
    )
    parent.refreshers[#parent.refreshers + 1] = enabledCheckbox

    local showDuringCombatCheckbox = CreateConsumableVisibilityCheckbox(parent, card, "poisons", "showDuringCombat", "Show in Combat", -84, setupIndex)
    local showDuringMythicPlusCheckbox = CreateConsumableVisibilityCheckbox(parent, card, "poisons", "showDuringMythicPlus", "Show during Mythic+ Runs", -116, setupIndex)

    local reapplyCheckbox = CreateCheckbox(
        card,
        "Show when poison is expiring",
        18,
        -148,
        function()
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("poisons", setupIndex)
            return config and config.enabled
        end,
        function(value)
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("poisons", setupIndex)
            if config then
                config.enabled = value and true or false
            end
            RequestOptionsRefresh()
        end
    )
    parent.refreshers[#parent.refreshers + 1] = reapplyCheckbox

    local reapplySlider = CreateSlider(
        card,
        TRACKING_CARD_RIGHT_COLUMN_X,
        -140,
        "Reapply Threshold",
        TRACKING_CARD_SLIDER_WIDTH,
        1,
        60,
        1,
        function()
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("poisons", setupIndex)
            return math.floor(((config and config.thresholdSeconds) or 1800) / 60)
        end,
        function(value)
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("poisons", setupIndex)
            if config then
                config.thresholdSeconds = value * 60
            end
            RequestOptionsRefresh()
        end,
        function(value)
            return (value or 0) .. "m"
        end
    )
    local baseReapplySliderRefresh = reapplySlider.Refresh
    reapplySlider.Refresh = function(self)
        if baseReapplySliderRefresh then
            baseReapplySliderRefresh(self)
        end

        local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("poisons", setupIndex)
        SetControlEnabled(self, config and config.enabled == true)
    end
    parent.refreshers[#parent.refreshers + 1] = reapplySlider

    local function IsPoisonKnown(entry)
        return ns.IsChoiceEntryAvailable and ns.IsChoiceEntryAvailable(entry) or false
    end

    local lethalEntries = {}
    local nonLethalEntries = {}
    for _, entry in ipairs(ns.ROGUE_POISONS or {}) do
        if entry.poisonCategory == "lethal" then
            lethalEntries[#lethalEntries + 1] = entry
        elseif entry.poisonCategory == "non_lethal" then
            nonLethalEntries[#nonLethalEntries + 1] = entry
        end
    end

    local lethalDropdown = CreateExplicitEntryDropdown(
        card,
        18,
        -220,
        "Lethal Poison",
        lethalEntries,
        function()
            return ns.GetRoguePoisonChoice and ns.GetRoguePoisonChoice("lethal", setupIndex) or "auto"
        end,
        function(value)
            if ns.SetRoguePoisonChoice then
                ns.SetRoguePoisonChoice("lethal", value, setupIndex)
            end
            RequestOptionsRefresh()
        end,
        {
            allowNone = true,
            width = STANDARD_DROPDOWN_WIDTH,
            autoLabel = "First Known",
            availableLabel = "Known",
            unavailableLabel = "Not Known",
            isEntryAvailable = IsPoisonKnown,
        }
    )
    parent.refreshers[#parent.refreshers + 1] = lethalDropdown

    local nonLethalDropdown = CreateExplicitEntryDropdown(
        card,
        TRACKING_CARD_RIGHT_COLUMN_X,
        -220,
        "Non-Lethal Poison",
        nonLethalEntries,
        function()
            return ns.GetRoguePoisonChoice and ns.GetRoguePoisonChoice("non_lethal", setupIndex) or "auto"
        end,
        function(value)
            if ns.SetRoguePoisonChoice then
                ns.SetRoguePoisonChoice("non_lethal", value, setupIndex)
            end
            RequestOptionsRefresh()
        end,
        {
            allowNone = true,
            width = STANDARD_DROPDOWN_WIDTH,
            autoLabel = "First Known",
            availableLabel = "Known",
            unavailableLabel = "Not Known",
            isEntryAvailable = IsPoisonKnown,
        }
    )
    parent.refreshers[#parent.refreshers + 1] = nonLethalDropdown

    local locationDropdowns = CreateConsumableLocationDropdownRow(parent, card, "poisons", -294, setupIndex)

    function card:UpdateDisabledState()
        local trackerEnabled = ns.GetConsumableTrackerEnabled and ns.GetConsumableTrackerEnabled("poisons", setupIndex) == true
        local reapplyConfig = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("poisons", setupIndex) or nil

        SetControlEnabled(showDuringCombatCheckbox, trackerEnabled)
        SetControlEnabled(showDuringMythicPlusCheckbox, trackerEnabled)
        SetControlEnabled(reapplyCheckbox, trackerEnabled)
        SetControlEnabled(reapplySlider, trackerEnabled and reapplyConfig and reapplyConfig.enabled == true)
        SetControlEnabled(lethalDropdown, trackerEnabled)
        SetControlEnabled(nonLethalDropdown, trackerEnabled)
        SetControlGroupEnabled(locationDropdowns, trackerEnabled)
    end

    local fittedHeight = FitSectionCardHeight(card, 18)
    return card, topY - fittedHeight - 18
end

local function CreateRuneSection(parent, topY, sectionTitle, setupIndex)
    local card = CreateSectionCard(
        parent,
        12,
        topY,
        676,
        360,
        sectionTitle,
        nil
    )
    card.nomtoolsContentYOffset = 0

    local enabledCheckbox = CreateCheckbox(
        card,
        "Enabled",
        18,
        -52,
        function()
            return ns.GetConsumableTrackerEnabled and ns.GetConsumableTrackerEnabled("rune", setupIndex)
        end,
        function(value)
            if ns.SetConsumableTrackerEnabled then
                ns.SetConsumableTrackerEnabled("rune", setupIndex, value)
            end
            RequestOptionsRefresh()
        end
    )
    parent.refreshers[#parent.refreshers + 1] = enabledCheckbox

    local showDuringCombatCheckbox = CreateConsumableVisibilityCheckbox(parent, card, "rune", "showDuringCombat", "Show in Combat", -84, setupIndex)
    local showDuringMythicPlusCheckbox = CreateConsumableVisibilityCheckbox(parent, card, "rune", "showDuringMythicPlus", "Show during Mythic+ Runs", -116, setupIndex)

    local reapplyCheckbox = CreateCheckbox(
        card,
        "Show when buff is expiring",
        18,
        -148,
        function()
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("rune", setupIndex)
            return config and config.enabled
        end,
        function(value)
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("rune", setupIndex)
            if config then
                config.enabled = value and true or false
            end
            RequestOptionsRefresh()
        end
    )
    parent.refreshers[#parent.refreshers + 1] = reapplyCheckbox

    local reapplySlider = CreateSlider(
        card,
        TRACKING_CARD_RIGHT_COLUMN_X,
        -140,
        "Reapply Threshold",
        TRACKING_CARD_SLIDER_WIDTH,
        1,
        60,
        1,
        function()
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("rune", setupIndex)
            return math.floor(((config and config.thresholdSeconds) or 1800) / 60)
        end,
        function(value)
            local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("rune", setupIndex)
            if config then
                config.thresholdSeconds = value * 60
            end
            RequestOptionsRefresh()
        end,
        function(value)
            return (value or 0) .. "m"
        end
    )
    local baseReapplySliderRefresh = reapplySlider.Refresh
    reapplySlider.Refresh = function(self)
        if baseReapplySliderRefresh then
            baseReapplySliderRefresh(self)
        end

        local config = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("rune", setupIndex)
        SetControlEnabled(self, config and config.enabled == true)
    end
    parent.refreshers[#parent.refreshers + 1] = reapplySlider

    local choiceDropdown = CreateConsumableDropdown(
        card,
        18,
        -220,
        "Preferred Rune",
        "rune",
        function()
            return ns.GetConsumableChoice and ns.GetConsumableChoice("rune", setupIndex) or "auto"
        end,
        function(value)
            if ns.SetConsumableChoice then
                ns.SetConsumableChoice("rune", value, setupIndex)
            end
            RequestOptionsRefresh()
        end,
        { allowNone = true, width = FULL_DROPDOWN_WIDTH }
    )
    parent.refreshers[#parent.refreshers + 1] = choiceDropdown

    local locationDropdowns = CreateConsumableLocationDropdownRow(parent, card, "rune", -294, setupIndex)

    function card:UpdateDisabledState()
        local trackerEnabled = ns.GetConsumableTrackerEnabled and ns.GetConsumableTrackerEnabled("rune", setupIndex) == true
        local reapplyConfig = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig("rune", setupIndex) or nil

        SetControlEnabled(showDuringCombatCheckbox, trackerEnabled)
        SetControlEnabled(showDuringMythicPlusCheckbox, trackerEnabled)
        SetControlEnabled(reapplyCheckbox, trackerEnabled)
        SetControlEnabled(reapplySlider, trackerEnabled and reapplyConfig and reapplyConfig.enabled == true)
        SetControlEnabled(choiceDropdown, trackerEnabled)
        SetControlGroupEnabled(locationDropdowns, trackerEnabled)
    end

    local fittedHeight = FitSectionCardHeight(card, 18)
    return card, topY - fittedHeight - 18
end

local function CreateScrollContainer(parent, contentHeight)
    local scrollFrame = CreateFrame("ScrollFrame", parent:GetName() .. "ScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -22, 8)
    scrollFrame:EnableMouseWheel(true)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(700, contentHeight or 1)
    scrollChild:EnableMouseWheel(true)
    scrollFrame:SetScrollChild(scrollChild)

    local function ScrollByDelta(delta)
        local current = scrollFrame:GetVerticalScroll() or 0
        local maxScroll = math.max((scrollChild:GetHeight() or 0) - (scrollFrame:GetHeight() or 0), 0)
        local target = math.max(0, math.min(maxScroll, current - (delta * OPTIONS_SCROLL_STEP)))
        scrollFrame:SetVerticalScroll(target)
    end

    scrollFrame:SetScript("OnSizeChanged", function(self, width)
        local contentWidth = math.max((width or 1) - 8, 1)
        scrollChild:SetWidth(contentWidth)
    end)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        ScrollByDelta(delta)
    end)
    scrollChild:SetScript("OnMouseWheel", function(_, delta)
        ScrollByDelta(delta)
    end)

    -- === Hide the entire template scrollbar (slider + arrows) ===
    local templateBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if templateBar then
        templateBar:SetAlpha(0)
        templateBar:EnableMouse(false)
        templateBar:SetWidth(1)
        local scrollUpButton = _G[scrollFrame:GetName() .. "ScrollBarScrollUpButton"]
        local scrollDownButton = _G[scrollFrame:GetName() .. "ScrollBarScrollDownButton"]
        if scrollUpButton then scrollUpButton:SetAlpha(0); scrollUpButton:EnableMouse(false); scrollUpButton:SetSize(1,1) end
        if scrollDownButton then scrollDownButton:SetAlpha(0); scrollDownButton:EnableMouse(false); scrollDownButton:SetSize(1,1) end
    end

    -- === Build a custom MinimalScrollBar-style scrollbar ===
    local barWidth = 8
    local stepperW, stepperH = 17, 11
    local barFrame = CreateFrame("Frame", nil, scrollFrame)
    barFrame:SetWidth(barWidth)
    barFrame:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, 0)
    barFrame:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 0)

    -- Back (up) arrow stepper
    local backBtn = CreateFrame("Button", nil, barFrame)
    backBtn:SetSize(stepperW, stepperH)
    backBtn:SetPoint("TOP", barFrame, "TOP", 0, 0)
    local backTex = backBtn:CreateTexture(nil, "BACKGROUND")
    backTex:SetAllPoints()
    backTex:SetAtlas("minimal-scrollbar-arrow-top")
    backBtn.tex = backTex
    backBtn:SetScript("OnMouseDown", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-top-down") end)
    backBtn:SetScript("OnMouseUp", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-top-over") end)
    backBtn:SetScript("OnEnter", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-top-over") end)
    backBtn:SetScript("OnLeave", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-top") end)
    backBtn:SetScript("OnClick", function() ScrollByDelta(1) end)

    -- Forward (down) arrow stepper
    local fwdBtn = CreateFrame("Button", nil, barFrame)
    fwdBtn:SetSize(stepperW, stepperH)
    fwdBtn:SetPoint("BOTTOM", barFrame, "BOTTOM", 0, 0)
    local fwdTex = fwdBtn:CreateTexture(nil, "BACKGROUND")
    fwdTex:SetAllPoints()
    fwdTex:SetAtlas("minimal-scrollbar-arrow-bottom")
    fwdBtn.tex = fwdTex
    fwdBtn:SetScript("OnMouseDown", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-bottom-down") end)
    fwdBtn:SetScript("OnMouseUp", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-bottom-over") end)
    fwdBtn:SetScript("OnEnter", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-bottom-over") end)
    fwdBtn:SetScript("OnLeave", function(self) self.tex:SetAtlas("minimal-scrollbar-arrow-bottom") end)
    fwdBtn:SetScript("OnClick", function() ScrollByDelta(-1) end)

    -- Track frame (between the two arrows)
    local track = CreateFrame("Frame", nil, barFrame)
    track:SetWidth(barWidth)
    track:SetPoint("TOP", backBtn, "BOTTOM", 0, 0)
    track:SetPoint("BOTTOM", fwdBtn, "TOP", 0, 0)

    local trackTop = track:CreateTexture(nil, "ARTWORK")
    trackTop:SetAtlas("minimal-scrollbar-track-top", true)
    trackTop:SetPoint("TOPLEFT")

    local trackBot = track:CreateTexture(nil, "ARTWORK")
    trackBot:SetAtlas("minimal-scrollbar-track-bottom", true)
    trackBot:SetPoint("BOTTOMLEFT")

    local trackMid = track:CreateTexture(nil, "ARTWORK")
    trackMid:SetAtlas("!minimal-scrollbar-track-middle", true)
    trackMid:SetPoint("TOPLEFT", trackTop, "BOTTOMLEFT")
    trackMid:SetPoint("BOTTOMRIGHT", trackBot, "TOPRIGHT")

    -- Thumb (3-piece)
    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(barWidth)
    thumb:EnableMouse(true)
    thumb:SetMovable(true)

    local thumbBegin = thumb:CreateTexture(nil, "ARTWORK")
    thumbBegin:SetAtlas("minimal-scrollbar-small-thumb-top", true)
    thumbBegin:SetPoint("TOPLEFT")

    local thumbEnd = thumb:CreateTexture(nil, "ARTWORK")
    thumbEnd:SetAtlas("minimal-scrollbar-small-thumb-bottom", true)
    thumbEnd:SetPoint("BOTTOMLEFT")

    local thumbMid = thumb:CreateTexture(nil, "ARTWORK")
    thumbMid:SetAtlas("minimal-scrollbar-small-thumb-middle", true)
    thumbMid:SetPoint("TOPLEFT", thumbBegin, "BOTTOMLEFT")
    thumbMid:SetPoint("BOTTOMRIGHT", thumbEnd, "TOPRIGHT")

    thumb.Begin = thumbBegin
    thumb.Mid = thumbMid
    thumb.End = thumbEnd
    local minThumbH = 23

    local function SetThumbTextures(prefix)
        thumb.Begin:SetAtlas("minimal-scrollbar-small-thumb-top" .. prefix, true)
        thumb.Mid:SetAtlas("minimal-scrollbar-small-thumb-middle" .. prefix, true)
        thumb.End:SetAtlas("minimal-scrollbar-small-thumb-bottom" .. prefix, true)
    end

    thumb:SetScript("OnEnter", function() if not thumb.isDragging then SetThumbTextures("-over") end end)
    thumb:SetScript("OnLeave", function() if not thumb.isDragging then SetThumbTextures("") end end)

    -- Thumb dragging
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self.isDragging = true
        SetThumbTextures("-down")
        local trackHeight = track:GetHeight()
        local thumbH = self:GetHeight()
        local maxScroll = math.max((scrollChild:GetHeight() or 0) - (scrollFrame:GetHeight() or 0), 0)
        if maxScroll <= 0 or trackHeight <= thumbH then return end
        self.dragStartY = select(5, self:GetPoint(1)) or 0
        self.dragStartCursor = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
        self:SetScript("OnUpdate", function(self2)
            local cursorY = select(2, GetCursorPosition()) / (self2:GetEffectiveScale() or 1)
            local delta = cursorY - self2.dragStartCursor
            local newOffset = math.max(-(trackHeight - thumbH), math.min(0, self2.dragStartY + delta))
            local scrollPct = math.abs(newOffset) / (trackHeight - thumbH)
            scrollFrame:SetVerticalScroll(scrollPct * maxScroll)
        end)
    end)
    thumb:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        if self:IsMouseOver() then SetThumbTextures("-over") else SetThumbTextures("") end
    end)

    -- Click-on-track to jump
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local trackHeight = self:GetHeight()
        local thumbH = thumb:GetHeight()
        if trackHeight <= thumbH then return end
        local maxScroll = math.max((scrollChild:GetHeight() or 0) - (scrollFrame:GetHeight() or 0), 0)
        if maxScroll <= 0 then return end
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / (self:GetEffectiveScale() or 1)
        local trackTop2 = self:GetTop()
        local clickOffset = trackTop2 - cursorY
        local scrollPct = math.max(0, math.min(1, (clickOffset - thumbH / 2) / (trackHeight - thumbH)))
        scrollFrame:SetVerticalScroll(scrollPct * maxScroll)
    end)

    -- Update thumb position/size whenever scroll changes
    local function UpdateThumb()
        local maxScroll = math.max((scrollChild:GetHeight() or 0) - (scrollFrame:GetHeight() or 0), 0)
        local trackHeight = track:GetHeight() or 1
        if maxScroll <= 0 then
            thumb:Hide()
            return
        end
        thumb:Show()
        local viewRatio = (scrollFrame:GetHeight() or 1) / (scrollChild:GetHeight() or 1)
        local thumbH = math.max(minThumbH, trackHeight * viewRatio)
        thumbH = math.min(thumbH, trackHeight)
        thumb:SetHeight(thumbH)
        local currentScroll = scrollFrame:GetVerticalScroll() or 0
        local scrollPct = currentScroll / maxScroll
        local yOffset = -scrollPct * (trackHeight - thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, yOffset)
    end

    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateThumb() end)
    hooksecurefunc(scrollFrame, "SetVerticalScroll", function() UpdateThumb() end)
    barFrame:SetScript("OnShow", function() UpdateThumb() end)
    barFrame:SetScript("OnSizeChanged", function() UpdateThumb() end)

    return scrollFrame, scrollChild
end

local function ShowUnavailableSidebarTooltip(owner, message)
    if not GameTooltip or not owner or type(message) ~= "string" or message == "" then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Module Unavailable", 1, 0.82, 0.00)
    GameTooltip:AddLine(message, 0.90, 0.90, 0.90, true)
    GameTooltip:Show()
end

local function AddSidebarBadgePageKey(pageKeys, pageKey)
    if type(pageKey) == "string" and pageKey ~= "" then
        pageKeys[#pageKeys + 1] = pageKey
    end
end

local function ResolveSidebarBadgePageKeys(options)
    if type(options) ~= "table" then
        return nil
    end

    local pageKeys = {}
    AddSidebarBadgePageKey(pageKeys, options.pageKey)
    AddSidebarBadgePageKey(pageKeys, options.newPageKey)

    for _, pageKey in ipairs(options.pageKeys or {}) do
        AddSidebarBadgePageKey(pageKeys, pageKey)
    end

    for _, pageKey in ipairs(options.newPageKeys or {}) do
        AddSidebarBadgePageKey(pageKeys, pageKey)
    end

    return #pageKeys > 0 and pageKeys or nil
end

local function IsAnySidebarBadgePageTagged(pageKeys)
    if type(pageKeys) ~= "table" then
        return false
    end

    for _, pageKey in ipairs(pageKeys) do
        if ns.IsNewTaggedPage and ns.IsNewTaggedPage(pageKey) then
            return true
        end
    end

    return false
end

local function CreateSidebarButton(parent, title, description, width, onClick, options)
    options = options or {}
    local badgePageKeys = ResolveSidebarBadgePageKeys(options)
    local hasTaggedPage = IsAnySidebarBadgePageTagged(badgePageKeys)

    local button = CreateFrame("Button", nil, parent, "OptionsListButtonTemplate")
    button:SetSize(width, 20)
    MarkAutoFitChild(button)
    button:SetNormalFontObject(GameFontHighlight)
    button:SetHighlightFontObject(GameFontHighlight)
    if button.toggle then
        button.toggle:Hide()
    end

    local titleText = button.text
    titleText:ClearAllPoints()
    titleText:SetPoint("LEFT", button, "LEFT", 8, 2)
    titleText:SetPoint("RIGHT", button, "RIGHT", -(hasTaggedPage and 62 or 8), 2)
    titleText:SetJustifyH("LEFT")
    titleText:SetJustifyV("MIDDLE")
    titleText:SetHeight(14)
    titleText:SetText(title)
    titleText:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    button.titleText = titleText

    local function UpdateVisualState(self)
        if badgePageKeys then
            local isTagged = IsAnySidebarBadgePageTagged(badgePageKeys)
            SetNewTagBadge(self, isTagged, {
                relativeTo = self,
                point = "RIGHT",
                relativePoint = "RIGHT",
                x = -30,
                y = 0,
            })
        end

        if self.isAvailable == false then
            self:UnlockHighlight()
            self:SetAlpha(0.60)
            self.titleText:SetTextColor(0.42, 0.42, 0.42)
            return
        end

        self:SetAlpha(1)
        if self.isSelected then
            self:LockHighlight()
            self.titleText:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
        else
            self:UnlockHighlight()
            self.titleText:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
        end
    end

    button.SetSelected = function(self, selected)
        self.isSelected = selected and true or false
        UpdateVisualState(self)
    end

    button.SetAvailable = function(self, isAvailable, unavailableReason)
        self.isAvailable = isAvailable ~= false
        self.unavailableReason = self.isAvailable and nil or unavailableReason
        UpdateVisualState(self)
    end

    button:SetScript("OnClick", function(self, ...)
        if self.isAvailable == false then
            return
        end

        if onClick then
            onClick(self, ...)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if self.isAvailable == false then
            ShowUnavailableSidebarTooltip(self, self.unavailableReason)
            return
        end

        if not self.isSelected then
            self.titleText:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        end
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip then
            GameTooltip:Hide()
        end
        self:SetSelected(self.isSelected)
    end)

    button:SetAvailable(true)
    button:SetSelected(false)
    return button
end

local function CreateSidebarToggleButton(parent, width, height, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 16, height or 16)
    button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    MarkAutoFitChild(button)

    function button:SetExpanded(expanded)
        if expanded then
            self:SetNormalTexture(130821)
            self:SetPushedTexture(130820)
            self:SetDisabledTexture(130822)
        else
            self:SetNormalTexture(130838)
            self:SetPushedTexture(130836)
            self:SetDisabledTexture(130837)
        end
    end

    button.SetAvailable = function(self, isAvailable, unavailableReason)
        self.isAvailable = isAvailable ~= false
        self.unavailableReason = self.isAvailable and nil or unavailableReason
        self:SetAlpha(self.isAvailable and 1 or 0.45)
    end

    button:SetScript("OnClick", function(self, ...)
        if self.isAvailable == false then
            return
        end

        if onClick then
            onClick(self, ...)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if self.isAvailable == false and GameTooltip and self.unavailableReason then
            ShowUnavailableSidebarTooltip(self, self.unavailableReason)
        end
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    button:SetAvailable(true)

    return button
end

local function CreateSidebarSubButton(parent, title, width, onClick, options)
    options = options or {}
    local badgePageKeys = ResolveSidebarBadgePageKeys(options)
    local hasTaggedPage = IsAnySidebarBadgePageTagged(badgePageKeys)

    local button = CreateFrame("Button", nil, parent, "OptionsListButtonTemplate")
    button:SetSize(width, 18)
    MarkAutoFitChild(button)
    button:SetNormalFontObject(GameFontHighlightSmall)
    button:SetHighlightFontObject(GameFontHighlightSmall)
    if button.toggle then
        button.toggle:Hide()
    end

    local titleText = button.text
    titleText:ClearAllPoints()
    titleText:SetPoint("LEFT", button, "LEFT", 18, 2)
    titleText:SetPoint("RIGHT", button, "RIGHT", -(hasTaggedPage and 62 or 8), 2)
    titleText:SetJustifyH("LEFT")
    titleText:SetHeight(14)
    titleText:SetText(title)
    titleText:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
    button.titleText = titleText

    local function UpdateVisualState(self)
        if badgePageKeys then
            local isTagged = IsAnySidebarBadgePageTagged(badgePageKeys)
            SetNewTagBadge(self, isTagged, {
                relativeTo = self,
                point = "RIGHT",
                relativePoint = "RIGHT",
                x = -30,
                y = 0,
            })
        end

        if self.isAvailable == false then
            self:UnlockHighlight()
            self:SetAlpha(0.60)
            self.titleText:SetTextColor(0.42, 0.42, 0.42)
            return
        end

        self:SetAlpha(1)
        if self.isSelected then
            self:LockHighlight()
            self.titleText:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
        else
            self:UnlockHighlight()
            self.titleText:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
        end
    end

    button.SetSelected = function(self, selected)
        self.isSelected = selected and true or false
        UpdateVisualState(self)
    end

    button.SetAvailable = function(self, isAvailable, unavailableReason)
        self.isAvailable = isAvailable ~= false
        self.unavailableReason = self.isAvailable and nil or unavailableReason
        UpdateVisualState(self)
    end

    button:SetScript("OnClick", function(self, ...)
        if self.isAvailable == false then
            return
        end

        if onClick then
            onClick(self, ...)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if self.isAvailable == false then
            ShowUnavailableSidebarTooltip(self, self.unavailableReason)
            return
        end

        if not self.isSelected then
            self.titleText:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        end
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip then
            GameTooltip:Hide()
        end
        self:SetSelected(self.isSelected)
    end)

    button:SetAvailable(true)
    button:SetSelected(false)
    return button
end

local function CreateSidebarSectionHeader(parent, title, width, headerIndex)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(width, 30)
    MarkAutoFitChild(header)

    local background = header:CreateTexture(nil, "ARTWORK")
    background:SetPoint("TOPLEFT")
    local atlas = "Options_CategoryHeader_" .. (headerIndex or 1)
    background:SetAtlas(atlas, true)
    header.background = background

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    label:SetPoint("LEFT", header, "LEFT", 20, -1)
    label:SetJustifyH("LEFT")
    label:SetText(title)
    header.label = label

    return header
end

local function CreateSidebarDivider(parent, width)
    local divider = CreateFrame("Frame", nil, parent)
    divider:SetSize(width, 10)
    MarkAutoFitChild(divider)

    local line = divider:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", divider, "TOPLEFT", 24, -5)
    line:SetPoint("TOPRIGHT", divider, "TOPRIGHT", -18, -5)
    line:SetHeight(1)
    line:SetColorTexture(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.42)
    divider.line = line

    return divider
end

local function CreateSidebarCard(parent, x, y, width, height, title, body)
    local card = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    card:SetSize(width, height)
    MarkAutoFitChild(card)

    local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    titleText:SetText(title)
    titleText:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)

    local bodyText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bodyText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -8)
    bodyText:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetJustifyV("TOP")
    bodyText:SetText(body)
    bodyText:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

    card.titleText = titleText
    card.bodyText = bodyText
    return card
end

local OPTIONS_INITIALIZE_SHARED = {
    STANDARD_DROPDOWN_WIDTH = STANDARD_DROPDOWN_WIDTH,
    COMPACT_DROPDOWN_WIDTH = COMPACT_DROPDOWN_WIDTH,
    FULL_DROPDOWN_WIDTH = FULL_DROPDOWN_WIDTH,
    TEXT_VERTICAL_ANCHOR_CHOICES = TEXT_VERTICAL_ANCHOR_CHOICES,
    COUNT_ANCHOR_CHOICES = COUNT_ANCHOR_CHOICES,
    REMINDER_PRESET_CHOICES = REMINDER_PRESET_CHOICES,
    REMINDER_POSITION_POINT_CHOICES = REMINDER_POSITION_POINT_CHOICES,
    OpenBlizzardEditMode = OpenBlizzardEditMode,
    GetOptionsPreviewPage = GetOptionsPreviewPage,
    SetActiveOptionsPreviewPage = SetActiveOptionsPreviewPage,
    CreateTitle = CreateTitle,
    CreateSectionTitle = CreateSectionTitle,
    CreateSubsectionTitle = CreateSubsectionTitle,
    CreateBodyText = CreateBodyText,
    CreateButton = CreateButton,
    CreateCheckbox = CreateCheckbox,
    ApplyModuleEnabledSetting = ApplyModuleEnabledSetting,
    ApplyRaidMarkerIcon = ApplyRaidMarkerIcon,
    CreateDropdown = CreateDropdown,
    FindStaticChoiceLabel = FindStaticChoiceLabel,
    FormatSliderValue = FormatSliderValue,
    CreateStaticDropdown = CreateStaticDropdown,
    CreateFontDropdown = CreateFontDropdown,
    CreateStatusBarTextureDropdown = CreateStatusBarTextureDropdown,
    CreateSlider = CreateSlider,
    SetTextBlockPosition = SetTextBlockPosition,
    SetControlShown = SetControlShown,
    SetControlEnabled = SetControlEnabled,
    PositionControl = PositionControl,
    CreateConsumableDropdown = CreateConsumableDropdown,
    CreatePrioritySection = CreatePrioritySection,
    CreateScrollContainer = CreateScrollContainer,
    CreateSidebarButton = CreateSidebarButton,
    CreateSidebarToggleButton = CreateSidebarToggleButton,
    CreateSidebarSubButton = CreateSidebarSubButton,
    CreateSidebarSectionHeader = CreateSidebarSectionHeader,
    CreateSidebarCard = CreateSidebarCard,
    SchedulePanelRefresh = SchedulePanelRefresh,
    RefreshPanel = RefreshPanel,
    FitSectionCardHeight = FitSectionCardHeight,
    FitScrollContentHeight = FitScrollContentHeight,
    CreateSectionCard = CreateSectionCard,
    CreateColorButton = CreateColorButton,
    NormalizeReminderPresetValue = NormalizeReminderPresetValue,
    NormalizeReminderPointValue = NormalizeReminderPointValue,
    GetReminderAppearanceState = GetReminderAppearanceState,
    GetReminderPositionConfig = GetReminderPositionConfig,
    CopyTableRecursive = CopyTableRecursive,
    ReplaceTableContents = ReplaceTableContents,
}

function ns.InitializeOptions()
    if ns.optionsWindow and ns.optionsPanel and ns.rootOptionsPanel then
        return
    end

    if ns.EnsureModuleImplementation then
        ns.EnsureModuleImplementation("consumables")
        ns.EnsureModuleImplementation("classesMonk")
    end

    local optionsInitializeShared = OPTIONS_INITIALIZE_SHARED
    local STANDARD_DROPDOWN_WIDTH = optionsInitializeShared.STANDARD_DROPDOWN_WIDTH
    local COMPACT_DROPDOWN_WIDTH = optionsInitializeShared.COMPACT_DROPDOWN_WIDTH
    local FULL_DROPDOWN_WIDTH = optionsInitializeShared.FULL_DROPDOWN_WIDTH
    local TEXT_VERTICAL_ANCHOR_CHOICES = optionsInitializeShared.TEXT_VERTICAL_ANCHOR_CHOICES
    local COUNT_ANCHOR_CHOICES = optionsInitializeShared.COUNT_ANCHOR_CHOICES
    local REMINDER_PRESET_CHOICES = optionsInitializeShared.REMINDER_PRESET_CHOICES
    local REMINDER_POSITION_POINT_CHOICES = optionsInitializeShared.REMINDER_POSITION_POINT_CHOICES
    local OpenBlizzardEditMode = optionsInitializeShared.OpenBlizzardEditMode
    local GetOptionsPreviewPage = optionsInitializeShared.GetOptionsPreviewPage
    local SetActiveOptionsPreviewPage = optionsInitializeShared.SetActiveOptionsPreviewPage
    local CreateTitle = optionsInitializeShared.CreateTitle
    local CreateSectionTitle = optionsInitializeShared.CreateSectionTitle
    local CreateSubsectionTitle = optionsInitializeShared.CreateSubsectionTitle
    local CreateBodyText = optionsInitializeShared.CreateBodyText
    local CreateButton = optionsInitializeShared.CreateButton
    local CreateCheckbox = optionsInitializeShared.CreateCheckbox
    local ApplyModuleEnabledSetting = optionsInitializeShared.ApplyModuleEnabledSetting
    local ApplyRaidMarkerIcon = optionsInitializeShared.ApplyRaidMarkerIcon
    local CreateDropdown = optionsInitializeShared.CreateDropdown
    local FindStaticChoiceLabel = optionsInitializeShared.FindStaticChoiceLabel
    local FormatSliderValue = optionsInitializeShared.FormatSliderValue
    local CreateStaticDropdown = optionsInitializeShared.CreateStaticDropdown
    local CreateFontDropdown = optionsInitializeShared.CreateFontDropdown
    local CreateStatusBarTextureDropdown = optionsInitializeShared.CreateStatusBarTextureDropdown
    local CreateSlider = optionsInitializeShared.CreateSlider
    local SetTextBlockPosition = optionsInitializeShared.SetTextBlockPosition
    local SetControlShown = optionsInitializeShared.SetControlShown
    local SetControlEnabled = optionsInitializeShared.SetControlEnabled
    local PositionControl = optionsInitializeShared.PositionControl
    local CreateConsumableDropdown = optionsInitializeShared.CreateConsumableDropdown
    local CreatePrioritySection = optionsInitializeShared.CreatePrioritySection
    local CreateScrollContainer = optionsInitializeShared.CreateScrollContainer
    local CreateSidebarButton = optionsInitializeShared.CreateSidebarButton
    local CreateSidebarToggleButton = optionsInitializeShared.CreateSidebarToggleButton
    local CreateSidebarSubButton = optionsInitializeShared.CreateSidebarSubButton
    local CreateSidebarSectionHeader = optionsInitializeShared.CreateSidebarSectionHeader
    local CreateSidebarCard = optionsInitializeShared.CreateSidebarCard
    local SchedulePanelRefresh = optionsInitializeShared.SchedulePanelRefresh
    local RefreshPanel = optionsInitializeShared.RefreshPanel
    local FitSectionCardHeight = optionsInitializeShared.FitSectionCardHeight
    local FitScrollContentHeight = optionsInitializeShared.FitScrollContentHeight
    local CreateSectionCard = optionsInitializeShared.CreateSectionCard
    local CreateColorButton = optionsInitializeShared.CreateColorButton
    local NormalizeReminderPresetValue = optionsInitializeShared.NormalizeReminderPresetValue
    local NormalizeReminderPointValue = optionsInitializeShared.NormalizeReminderPointValue
    local GetReminderAppearanceState = optionsInitializeShared.GetReminderAppearanceState
    local GetReminderPositionConfig = optionsInitializeShared.GetReminderPositionConfig
    local CopyTableRecursive = optionsInitializeShared.CopyTableRecursive
    local ReplaceTableContents = optionsInitializeShared.ReplaceTableContents

    local function GetOptionsWindowSettings()
        return ns.GetOptionsWindowSettings and ns.GetOptionsWindowSettings() or {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        }
    end

    local function NormalizeOptionsWindowPoint(point, fallback)
        if type(point) == "string" and point ~= "" then
            return point
        end

        return fallback or "CENTER"
    end

    local function ApplySavedOptionsWindowPosition(frame)
        if not frame then
            return
        end

        local settings = GetOptionsWindowSettings()
        local point = NormalizeOptionsWindowPoint(settings.point, "CENTER")
        local relativePoint = NormalizeOptionsWindowPoint(settings.relativePoint, point)
        local x = tonumber(settings.x) or 0
        local y = tonumber(settings.y) or 0

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relativePoint, x, y)
    end

    local function SaveOptionsWindowPosition(frame)
        if not frame then
            return
        end

        local settings = GetOptionsWindowSettings()
        if frame.GetPoint then
            local point, _, relativePoint, x, y = frame:GetPoint(1)
            x = tonumber(x)
            y = tonumber(y)
            if x and y then
                settings.point = NormalizeOptionsWindowPoint(point, "CENTER")
                settings.relativePoint = NormalizeOptionsWindowPoint(relativePoint, settings.point)
                settings.x = x
                settings.y = y
                return
            end
        end

        if not frame.GetCenter or not UIParent or not UIParent.GetCenter then
            return
        end

        local frameCenterX, frameCenterY = frame:GetCenter()
        local parentCenterX, parentCenterY = UIParent:GetCenter()
        local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if not frameCenterX or not frameCenterY or not parentCenterX or not parentCenterY or scale == 0 then
            return
        end

        settings.point = "CENTER"
        settings.relativePoint = "CENTER"
        settings.x = (frameCenterX - parentCenterX) / scale
        settings.y = (frameCenterY - parentCenterY) / scale
    end

    function ns.ResetOptionsWindowPosition()
        local settings = GetOptionsWindowSettings()
        settings.point = "CENTER"
        settings.relativePoint = "CENTER"
        settings.x = 0
        settings.y = 0

        if ns.optionsWindow then
            ApplySavedOptionsWindowPosition(ns.optionsWindow)
        end
    end

    local function StartOptionsWindowMove(frame)
        if frame and frame.StartMoving then
            frame:StartMoving()
        end
    end

    local function StopOptionsWindowMove(frame)
        if not frame then
            return
        end

        if frame.StopMovingOrSizing then
            frame:StopMovingOrSizing()
        end
        SaveOptionsWindowPosition(frame)
    end

    local window = CreateFrame("Frame", "NomToolsOptionsWindow", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(OPTIONS_WINDOW_WIDTH, OPTIONS_WINDOW_HEIGHT)
    ApplySavedOptionsWindowPosition(window)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:Hide()

    if window.Inset then
        window.Inset:Hide()
    end
    if window.Bg then
        window.Bg:SetAlpha(0.92)
    end
    if window.InsetBg then
        window.InsetBg:SetAlpha(0)
    end
    if window.TitleText then
        window.TitleText:SetText("NomTools")
    end
    if window.CloseButton then
        window.CloseButton:SetScript("OnClick", function()
            window:Hide()
        end)
    end
    ns.optionsWindow = window
    window.closeButton = window.CloseButton
    window.RestoreSavedPosition = function(self)
        ApplySavedOptionsWindowPosition(self)
    end
    window:HookScript("OnHide", function()
        SaveOptionsWindowPosition(window)
        SetActiveOptionsPreviewPage(nil)
        if window.pages then
            for _, page in pairs(window.pages) do
                page:Hide()
            end
        end
        window.currentPage = nil
    end)

    local dragHandle = CreateFrame("Frame", nil, window)
    dragHandle:SetPoint("TOPLEFT", window, "TOPLEFT", 24, -4)
    dragHandle:SetPoint("TOPRIGHT", window, "TOPRIGHT", -44, -4)
    dragHandle:SetHeight(24)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        StartOptionsWindowMove(window)
    end)
    dragHandle:SetScript("OnDragStop", function()
        StopOptionsWindowMove(window)
    end)
    window.dragHandle = dragHandle

    table.insert(UISpecialFrames, window:GetName())

    local sidebar = CreateFrame("Frame", nil, window, "InsetFrameTemplate3")
    sidebar:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -28)
    sidebar:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 8, 8)
    sidebar:SetWidth(230)
    window.sidebar = sidebar

    -- No brand/tag heading — sidebar items start from the top, matching Blizzard's Options layout.

    local contentHost = CreateFrame("Frame", nil, window, "InsetFrameTemplate3")
    contentHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
    contentHost:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8)
    window.contentHost = contentHost

    -- Vignette overlay matching Blizzard's Options_InnerFrame (stretched to fit NomTools' wider panel)
    local vignette = window:CreateTexture(nil, "OVERLAY", nil, 2)
    vignette:SetAtlas("Options_InnerFrame", false)
    vignette:SetPoint("TOPLEFT", sidebar, "TOPLEFT", -1, 1)
    vignette:SetPoint("BOTTOMRIGHT", contentHost, "BOTTOMRIGHT", 1, -1)

    local rootPanel = CreateFrame("Frame", "NomToolsOptionsRootPanel", contentHost)
    rootPanel:SetAllPoints(contentHost)
    rootPanel.refreshers = {}
    local rootScrollFrame, rootContent = CreateScrollContainer(rootPanel, rootPanel:GetHeight())
    rootPanel.scrollFrame = rootScrollFrame
    rootPanel.content = rootContent
    rootContent.refreshers = rootPanel.refreshers
    rootContent.RefreshAll = function()
        rootPanel:RefreshAll()
    end
    rootPanel.RefreshAll = function(self)
        if self.UpdateGlobalSettingsLayout then
            self:UpdateGlobalSettingsLayout()
        elseif self.UpdateOverviewLayout then
            self:UpdateOverviewLayout()
        end
        RefreshPanel(self)
    end
    rootPanel:SetScript("OnShow", function(self)
        if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
            self.scrollFrame:SetVerticalScroll(0)
        end
        SchedulePanelRefresh(self)
    end)
    ns.rootOptionsPanel = rootPanel

    local function ResetModuleEnabledSetting(moduleKey, defaultEnabled, applySetting)
        -- No-op: module resets preserve the current enabled/disabled state.
        -- Each reset handler captures and restores the enabled state around
        -- the CopyTableRecursive call.
    end

    local function ResetEditModeConfig(configKey, defaults)
        if not configKey then
            return
        end

        local config = ns.GetEditModeConfig and ns.GetEditModeConfig(configKey, defaults or {}) or nil
        if type(config) ~= "table" then
            return
        end

        ReplaceTableContents(config, defaults or {})
    end

    local globalResetPopupKey = addonName .. "ConfirmGlobalReset"

    local function EnsureGlobalResetPopupRegistered()
        if not StaticPopupDialogs or StaticPopupDialogs[globalResetPopupKey] then
            return
        end

        StaticPopupDialogs[globalResetPopupKey] = {
            text = "Reset all NomTools settings to defaults?\n\nThis will reset every module, shared default, and NomTools Edit Mode position.",
            button1 = RESET or "Reset",
            button2 = CANCEL or "Cancel",
            OnAccept = function(_, data)
                if data and data.onAccept then
                    data.onAccept()
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = STATICPOPUP_NUMDIALOGS,
        }
    end

    local function ShowGlobalResetConfirmation(onAccept)
        EnsureGlobalResetPopupRegistered()
        if StaticPopup_Show then
            StaticPopup_Show(globalResetPopupKey, nil, nil, { onAccept = onAccept })
            return
        end

        if onAccept then
            onAccept()
        end
    end

    do

    local function GetGlobalSettings()
        return ns.GetGlobalSettings and ns.GetGlobalSettings() or (ns.DEFAULTS and ns.DEFAULTS.globalSettings) or {}
    end

        CreateTitle(rootContent, "Global Settings", 16, -16)

        local rootSubtitle = rootContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        rootSubtitle:SetPoint("TOPLEFT", rootContent, "TOPLEFT", 16, -42)
        rootSubtitle:SetText("Shared Defaults & Launchers")
        rootSubtitle:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

    local rootResetAllButton = CreateButton(rootContent, "Reset to Defaults", 528, -20, 148, 24, function()
        ShowGlobalResetConfirmation(function()
            if ns.ResetOptionsToDefaults then
                ns.ResetOptionsToDefaults()
            end
            if ns.SyncAndRefreshWorldQuests then
                ns.SyncAndRefreshWorldQuests(true)
            end
            if window and window.RestoreSavedPosition then
                window:RestoreSavedPosition()
            end
            if ns.RequestRefresh then
                RequestOptionsRefresh("overview")
            end
            if rootPanel and rootPanel.RefreshAll then
                rootPanel:RefreshAll()
            end
        end)
    end)

    local globalStyleCard = CreateSectionCard(
        rootContent,
        12,
        -64,
        676,
        182,
        "Shared Style Defaults",
        "Choose the addon-wide text font, text outline, and texture. Any module dropdown set to Global will inherit these values by default."
    )

    local globalFontDropdown = CreateFontDropdown(
        globalStyleCard,
        18,
        -82,
        "Text Font",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetGlobalSettings().font
        end,
        function(value)
            GetGlobalSettings().font = value
            RequestOptionsRefresh("overview")
        end,
        "Roboto Condensed Bold",
        { includeGlobalChoice = false }
    )
    rootPanel.refreshers[#rootPanel.refreshers + 1] = globalFontDropdown

    local globalFontOutlineDropdown = CreateStaticDropdown(
        globalStyleCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -82,
        "Text Outline",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(false) or {}
        end,
        function()
            return GetGlobalSettings().fontOutline
        end,
        function(value)
            GetGlobalSettings().fontOutline = value
            RequestOptionsRefresh("overview")
        end,
        "Outline"
    )
    rootPanel.refreshers[#rootPanel.refreshers + 1] = globalFontOutlineDropdown

    local globalTextureDropdown = CreateStatusBarTextureDropdown(
        globalStyleCard,
        18,
        -156,
        "Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetGlobalSettings().texture
        end,
        function(value)
            GetGlobalSettings().texture = value
            RequestOptionsRefresh("overview")
        end,
        "Solid",
        { includeGlobalChoice = false }
    )
    rootPanel.refreshers[#rootPanel.refreshers + 1] = globalTextureDropdown

    local globalBorderTextureDropdown = CreateStatusBarTextureDropdown(
        globalStyleCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Border Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetGlobalSettings().borderTexture
        end,
        function(value)
            GetGlobalSettings().borderTexture = value
            RequestOptionsRefresh("overview")
        end,
        "Solid",
        {
            includeGlobalChoice = false,
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    rootPanel.refreshers[#rootPanel.refreshers + 1] = globalBorderTextureDropdown

    local escapeMenuCard = CreateSectionCard(
        rootContent,
        12,
        -298,
        676,
        152,
        "Launchers",
        "Toggle the NomTools launchers in the escape menu, on the minimap, and inside Blizzard's addon compartment."
    )

    local escapeMenuCheckbox = CreateCheckbox(
        escapeMenuCard,
        "Show NomTools button in the escape menu",
        18,
        -78,
        function()
            if not ns.db then return true end
            return ns.db.showGameMenuButton ~= false
        end,
        function(value)
            if not ns.db then return end
            ns.db.showGameMenuButton = value and true or false
            if ns.RefreshGameMenuButton then
                ns.RefreshGameMenuButton()
            end
        end
    )
    rootPanel.refreshers[#rootPanel.refreshers + 1] = escapeMenuCheckbox

    local minimapButtonCheckbox = CreateCheckbox(
        escapeMenuCard,
        "Show NomTools button on the minimap",
        18,
        -106,
        function()
            return GetGlobalSettings().showMinimapButton ~= false
        end,
        function(value)
            GetGlobalSettings().showMinimapButton = value and true or false
            if ns.RefreshLauncherUI then
                ns.RefreshLauncherUI()
            end
        end
    )
    rootPanel.refreshers[#rootPanel.refreshers + 1] = minimapButtonCheckbox

    local addonCompartmentCheckbox = CreateCheckbox(
        escapeMenuCard,
        "Show NomTools in Blizzard's addon compartment",
        18,
        -134,
        function()
            return GetGlobalSettings().showAddonCompartment ~= false
        end,
        function(value)
            GetGlobalSettings().showAddonCompartment = value and true or false
            if ns.RefreshLauncherUI then
                ns.RefreshLauncherUI()
            end
        end
    )
    rootPanel.refreshers[#rootPanel.refreshers + 1] = addonCompartmentCheckbox

    function rootPanel:UpdateGlobalSettingsLayout()
        local currentY = -64
        local cardSpacing = 20

        rootResetAllButton:ClearAllPoints()
        rootResetAllButton:SetPoint("TOPLEFT", rootContent, "TOPLEFT", 528, -20)

        globalStyleCard:ClearAllPoints()
        globalStyleCard:SetPoint("TOPLEFT", rootContent, "TOPLEFT", 12, currentY)
        PositionControl(globalFontDropdown, globalStyleCard, 18, -82)
        PositionControl(globalFontOutlineDropdown, globalStyleCard, APPEARANCE_RIGHT_COLUMN_X, -82)
        PositionControl(globalTextureDropdown, globalStyleCard, 18, -156)
        PositionControl(globalBorderTextureDropdown, globalStyleCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        local globalStyleCardHeight = FitSectionCardHeight(globalStyleCard, 20)
        currentY = currentY - globalStyleCardHeight - cardSpacing

        escapeMenuCard:ClearAllPoints()
        escapeMenuCard:SetPoint("TOPLEFT", rootContent, "TOPLEFT", 12, currentY)
        PositionControl(escapeMenuCheckbox, escapeMenuCard, 18, -78)
        PositionControl(minimapButtonCheckbox, escapeMenuCard, 18, -106)
        PositionControl(addonCompartmentCheckbox, escapeMenuCard, 18, -134)
        FitSectionCardHeight(escapeMenuCard, 20)

        FitScrollContentHeight(rootContent, rootPanel:GetHeight() - 16, 36)
    end

    end

    local sectionWidth = 676
    local sectionX = 12
    local PAGE_SECTION_START_Y = -64

    local function CreateModulePage(frameName, titleText, subtitleText, descriptionText, options)
        local pageOptions = options or {}
        local page = CreateFrame("Frame", frameName, contentHost)
        page.refreshers = {}
        page:SetAllPoints(contentHost)

        local scrollFrame, content = CreateScrollContainer(page, page:GetHeight())
        page.scrollFrame = scrollFrame
        page.content = content
        content.refreshers = page.refreshers
        content.RefreshAll = function()
            page:RefreshAll()
        end
        content:SetScript("OnShow", function()
            SchedulePanelRefresh(page)
        end)

        function page:RefreshAll()
            if self.UpdateLayout then
                self:UpdateLayout()
            elseif self.UpdateAppearanceLayout then
                self:UpdateAppearanceLayout()
            end
            RefreshPanel(self)
            if self.UpdateDisabledState then
                self:UpdateDisabledState()
            end
        end

        CreateTitle(content, titleText, 16, -16)

        if subtitleText and subtitleText ~= "" then
            local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            subtitle:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -42)
            subtitle:SetText(subtitleText)
            subtitle:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
            page.subtitleText = subtitle
        end

        CreateButton(content, "Reset to Defaults", 528, -20, 148, 24, function()
            local shouldRefresh = true

            if pageOptions.resetHandler then
                shouldRefresh = pageOptions.resetHandler(page) ~= false
            elseif ns.ResetOptionsToDefaults then
                ns.ResetOptionsToDefaults()
            end

            if not shouldRefresh then
                return
            end

            if ns.RequestRefresh then
                RequestOptionsRefresh(window and window.currentPage, "reset")
            end
            page:RefreshAll()
        end)

        if pageOptions.showEditModeButton then
            page.openEditModeButton = CreateButton(content, "Open Edit Mode", 372, -20, 148, 24, function()
                if pageOptions.editModeHandler then
                    pageOptions.editModeHandler(page)
                    return
                end

                OpenBlizzardEditMode()
            end)
        end

        -- Disabled overlay: shown when the module is disabled to block settings interaction.
        if pageOptions.moduleEnabledGetter then
            local overlay = CreateFrame("Frame", nil, page, "BackdropTemplate")
            overlay:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
            overlay:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
            overlay:SetFrameLevel(page:GetFrameLevel() + 100)
            overlay:EnableMouse(true)
            overlay:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            })
            overlay:SetBackdropColor(0.06, 0.07, 0.08, 0.85)

            local overlayMessage = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            overlayMessage:SetPoint("CENTER", overlay, "CENTER", 0, 20)
            overlayMessage:SetText("This module is disabled.")
            overlayMessage:SetTextColor(0.65, 0.65, 0.65)

            local overlayHint = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            overlayHint:SetPoint("TOP", overlayMessage, "BOTTOM", 0, -8)
            overlayHint:SetText("Enable it to configure these settings.")
            overlayHint:SetTextColor(0.50, 0.50, 0.50)

            local overlayButton = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
            overlayButton:SetPoint("TOP", overlayHint, "BOTTOM", 0, -12)
            overlayButton:SetSize(180, 28)
            overlayButton:SetText("Enable Module")

            local function UpdateDisabledOverlayCopy(pendingEnableReload, pendingDisableReload)
                if pendingEnableReload then
                    overlayMessage:SetText("This module will enable after reload.")
                    overlayHint:SetText("It is still disabled until the UI reloads. Cancel the pending enable here if you want to keep it off.")
                    overlayButton:SetText("Cancel Pending Enable")
                    overlayButton.nomtoolsTargetEnabled = false
                    return
                end

                if pendingDisableReload then
                    overlayMessage:SetText("This module will disable after reload.")
                    overlayHint:SetText("It is still running until the UI reloads. Cancel the pending disable here if you want to keep it on.")
                    overlayButton:SetText("Cancel Pending Disable")
                    overlayButton.nomtoolsTargetEnabled = true
                    return
                end

                overlayMessage:SetText("This module is disabled.")
                overlayHint:SetText("Enable it to configure these settings.")
                overlayButton:SetText("Enable Module")
                overlayButton.nomtoolsTargetEnabled = true
            end

            overlayButton:SetScript("OnClick", function(self)
                if pageOptions.moduleEnabledSetter then
                    pageOptions.moduleEnabledSetter(self.nomtoolsTargetEnabled ~= false)
                end
                page:UpdateDisabledState()
                page:RefreshAll()
            end)

            page.disabledOverlay = overlay

            function page:UpdateDisabledState()
                local enabled = pageOptions.moduleEnabledGetter()
                local moduleKey = GetOptionsModuleKey(self.nomtoolsPageKey)
                local pendingEnableReload = false
                local pendingDisableReload = false
                if moduleKey and ns.IsModuleRuntimeEnabled and ns.IsModuleConfiguredEnabled then
                    enabled = ns.IsModuleRuntimeEnabled(moduleKey, ns.IsModuleConfiguredEnabled(moduleKey))
                    if enabled == false and ns.IsModulePendingEnableReload then
                        pendingEnableReload = ns.IsModulePendingEnableReload(moduleKey)
                    end
                    if enabled == true and ns.IsModulePendingDisableReload then
                        pendingDisableReload = ns.IsModulePendingDisableReload(moduleKey)
                    end
                end

                local showOverlay = not enabled or pendingDisableReload
                if self.disabledOverlay then
                    self.disabledOverlay:SetShown(showOverlay)
                    if showOverlay then
                        UpdateDisabledOverlayCopy(pendingEnableReload, pendingDisableReload)
                    end
                end
                -- Sync preview state with the module's enabled state.
                if enabled and not pendingDisableReload then
                    if self:IsShown() then
                        SetActiveOptionsPreviewPage(window.currentPage)
                    end
                else
                    if self:IsShown() and self.nomtoolsPageKey == "menu_bar" then
                        SetActiveOptionsPreviewPage(self.nomtoolsPageKey, true)
                    else
                        SetActiveOptionsPreviewPage(nil)
                    end
                end
            end
        end

        page:SetScript("OnShow", function(self)
            if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
                self.scrollFrame:SetVerticalScroll(0)
            end
            if self.UpdateDisabledState then
                self:UpdateDisabledState()
            end
            SchedulePanelRefresh(self)
        end)

        return page, content
    end

    local generalPanel
    local trackingPanel
    local appearancePanelPage
    local changeLogPanel
    local debugPanel
    local objectiveTrackerPanel
    local objectiveTrackerLayoutPanel
    local objectiveTrackerAppearancePanel
    local objectiveTrackerSectionsPanel
    local greatVaultPanel
    local dungeonDifficultyPanel
    local talentLoadoutPanel
    local menuBarPanel
    local miscMiscGeneralPanel
    local miscCutscenesPanel
    local miscCharStatsPanel
    local housingPanel
    local housingButton
    local worldQuestsPanel
    local worldQuestsButton
    local remindersGeneralPanel
    local remindersAppearancePanel
    local classesGeneralPanel
    local classesMonkPanel

    if ns.CreateChangeLogOptionsPage then
        changeLogPanel = ns.CreateChangeLogOptionsPage({
            contentHost = contentHost,
            CreateButton = CreateButton,
            CreateModulePage = CreateModulePage,
            CreateSectionCard = CreateSectionCard,
            CreateStaticDropdown = CreateStaticDropdown,
            FitScrollContentHeight = FitScrollContentHeight,
            FitSectionCardHeight = FitSectionCardHeight,
            PositionControl = PositionControl,
            APPEARANCE_COLUMN_WIDTH = APPEARANCE_COLUMN_WIDTH,
            PAGE_SECTION_START_Y = PAGE_SECTION_START_Y,
            sectionWidth = sectionWidth,
            sectionX = sectionX,
        })
    end

    do
    local classesGeneralContent
    local classesDefaults = ns.DEFAULTS and ns.DEFAULTS.classes or { enabled = false }

    local function GetClassesModuleSettings()
        return ns.GetClassesSettings and ns.GetClassesSettings() or classesDefaults
    end

    local function IsClassesModuleEnabled()
        local settings = GetClassesModuleSettings()
        return settings and settings.enabled == true or false
    end

    classesGeneralPanel, classesGeneralContent = CreateModulePage(
        "NomToolsClassesGeneralPanel",
        "Classes",
        "General",
        "Control whether the shared Classes addon is enabled before configuring any individual class pages.",
        {
            moduleEnabledGetter = function()
                return IsClassesModuleEnabled()
            end,
            moduleEnabledSetter = function(enabled)
                local settings = GetClassesModuleSettings()
                ApplyModuleEnabledSetting("classesMonk", enabled, function(value)
                    settings.enabled = value and true or false
                end, ns.RequestRefresh, { forceReloadPrompt = true })
            end,
            resetHandler = function()
                if not ns.db then
                    return
                end

                ns.db.classes = ns.db.classes or {}
                ResetModuleEnabledSetting("classesMonk", classesDefaults.enabled, function(enabled)
                    ns.db.classes.enabled = enabled and true or false
                end)
            end,
        }
    )

    local classesGeneralCard = CreateSectionCard(
        classesGeneralContent,
        sectionX,
        -96,
        sectionWidth,
        172,
        "General",
        "Enable or disable the shared Classes addon here. Individual class pages such as Monk stay enabled by default, while tabbed class features stay disabled by default until you turn them on."
    )

    local classesEnabledCheckbox = CreateCheckbox(
        classesGeneralCard,
        "Enable Classes Module",
        18,
        -82,
        function()
            return IsClassesModuleEnabled()
        end,
        function(value)
            local settings = GetClassesModuleSettings()
            ApplyModuleEnabledSetting("classesMonk", value, function(enabled)
                settings.enabled = enabled and true or false
            end, ns.RequestRefresh, { forceReloadPrompt = true })
        end
    )
    classesGeneralPanel.refreshers[#classesGeneralPanel.refreshers + 1] = classesEnabledCheckbox

    classesGeneralPanel.UpdateLayout = function(self)
        classesGeneralCard:ClearAllPoints()
        classesGeneralCard:SetPoint("TOPLEFT", classesGeneralContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        PositionControl(classesEnabledCheckbox, classesGeneralCard, 18, -82)
        FitSectionCardHeight(classesGeneralCard, 20)
        FitScrollContentHeight(classesGeneralContent, self:GetHeight() - 16, 36)
    end

    classesGeneralPanel:UpdateLayout()
    end

    if ns.CreateClassesMonkOptionsPage then
        classesMonkPanel = ns.CreateClassesMonkOptionsPage({
            ApplyModuleEnabledSetting = ApplyModuleEnabledSetting,
            CreateBodyText = CreateBodyText,
            CreateButton = CreateButton,
            CreateCheckbox = CreateCheckbox,
            CreateColorButton = CreateColorButton,
            CreateDropdown = CreateDropdown,
            CreateFontDropdown = CreateFontDropdown,
            CreateModulePage = CreateModulePage,
            CreateSectionCard = CreateSectionCard,
            CreateSubsectionTitle = CreateSubsectionTitle,
            CreateStaticDropdown = CreateStaticDropdown,
            CreateStatusBarTextureDropdown = CreateStatusBarTextureDropdown,
            CreateSlider = CreateSlider,
            FitScrollContentHeight = FitScrollContentHeight,
            FitSectionCardHeight = FitSectionCardHeight,
            FormatSliderValue = FormatSliderValue,
            OpenBlizzardEditMode = OpenBlizzardEditMode,
            PositionControl = PositionControl,
            REMINDER_POSITION_POINT_CHOICES = REMINDER_POSITION_POINT_CHOICES,
            SetControlEnabled = SetControlEnabled,
            SetControlShown = SetControlShown,
            APPEARANCE_COLUMN_WIDTH = APPEARANCE_COLUMN_WIDTH,
            APPEARANCE_RIGHT_COLUMN_X = APPEARANCE_RIGHT_COLUMN_X,
            PAGE_SECTION_START_Y = PAGE_SECTION_START_Y,
            sectionWidth = sectionWidth,
            sectionX = sectionX,
        })
    end

    do
    local debugContent
    local globalDefaults = ns.DEFAULTS and ns.DEFAULTS.globalSettings or {}

    local function GetDebugGlobalSettings()
        return ns.GetGlobalSettings and ns.GetGlobalSettings() or (ns.DEFAULTS and ns.DEFAULTS.globalSettings) or {}
    end

    local function RefreshDebugOverlayOptions()
        if ns.RequestRefresh then
            ns.RequestRefresh("debugOverlay")
        elseif ns.RefreshDebugOverlay then
            ns.RefreshDebugOverlay()
        end
    end

    debugPanel, debugContent = CreateModulePage(
        "NomToolsDebugPanel",
        "Debug",
            "Diagnostics",
        "Control NomTools diagnostic overlays. CPU profiling requires Blizzard's AddOn profiler to be enabled before reload.",
        {
            resetHandler = function()
                local globalSettings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
                if not globalSettings then
                    return
                end

                globalSettings.enableDebug = globalDefaults.enableDebug == true
                globalSettings.debugModeCPU = globalDefaults.debugModeCPU == true
                globalSettings.debugModeMemory = globalDefaults.debugModeMemory == true
                RefreshDebugOverlayOptions()
            end,
        }
    )

    local enableDebugCard = CreateSectionCard(
        debugContent,
        sectionX,
        -96,
        sectionWidth,
        112,
        "Debug",
        "Enable debug mode to print diagnostic information to chat. This is useful for troubleshooting hard-to-reproduce issues."
    )

    local enableDebugCheckbox = CreateCheckbox(
        enableDebugCard,
        "Enable Debug",
        18,
        -78,
        function()
            return GetDebugGlobalSettings().enableDebug == true
        end,
        function(value)
            GetDebugGlobalSettings().enableDebug = value and true or false
        end
    )
    debugPanel.refreshers[#debugPanel.refreshers + 1] = enableDebugCheckbox

    local diagnosticsCard = CreateSectionCard(
        debugContent,
        sectionX,
        -220,
        sectionWidth,
        154,
        "Diagnostics",
        "Show a lightweight debug overlay in the top-left corner. CPU uses the Blizzard AddOn profiler (enable before reload). Memory calls UpdateAddOnMemoryUsage every 5 seconds, which can cause a brief hitch; enable only when needed."
    )

    local debugModeCPUCheckbox = CreateCheckbox(
        diagnosticsCard,
        "Show NomTools CPU overlay",
        18,
        -78,
        function()
            return GetDebugGlobalSettings().debugModeCPU == true
        end,
        function(value)
            GetDebugGlobalSettings().debugModeCPU = value and true or false
            RefreshDebugOverlayOptions()
        end
    )
    debugPanel.refreshers[#debugPanel.refreshers + 1] = debugModeCPUCheckbox

    local debugModeMemoryCheckbox = CreateCheckbox(
        diagnosticsCard,
        "Show NomTools memory overlay",
        18,
        -106,
        function()
            return GetDebugGlobalSettings().debugModeMemory == true
        end,
        function(value)
            GetDebugGlobalSettings().debugModeMemory = value and true or false
            RefreshDebugOverlayOptions()
        end
    )
    debugPanel.refreshers[#debugPanel.refreshers + 1] = debugModeMemoryCheckbox

    debugPanel.UpdateLayout = function(self)
        enableDebugCard:ClearAllPoints()
        enableDebugCard:SetPoint("TOPLEFT", debugContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        PositionControl(enableDebugCheckbox, enableDebugCard, 18, -78)
        FitSectionCardHeight(enableDebugCard, 20)

        diagnosticsCard:ClearAllPoints()
        diagnosticsCard:SetPoint("TOPLEFT", enableDebugCard, "BOTTOMLEFT", 0, -16)
        PositionControl(debugModeCPUCheckbox, diagnosticsCard, 18, -78)
        PositionControl(debugModeMemoryCheckbox, diagnosticsCard, 18, -106)
        FitSectionCardHeight(diagnosticsCard, 20)

        FitScrollContentHeight(debugContent, self:GetHeight() - 16, 36)
    end

    debugPanel:UpdateLayout()
    end

    do
    local miscMiscGeneralContent
    local miscDefaults = ns.DEFAULTS and ns.DEFAULTS.miscellaneous or {}

    miscMiscGeneralPanel, miscMiscGeneralContent = CreateModulePage(
        "NomToolsMiscGeneralPanel",
        "Miscellaneous",
        "General",
        "Enable or disable the Miscellaneous module.",
        {
            moduleEnabledGetter = function()
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                return miscSettings and miscSettings.enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                if miscSettings then
                    ns.SetModuleEnabled("miscellaneous", enabled, function(v)
                        miscSettings.enabled = v and true or false
                    end)
                end
            end,
            resetHandler = function(page)
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                if miscSettings then
                    ns.SetModuleEnabled("miscellaneous", miscDefaults.enabled == true, function(v) miscSettings.enabled = v end)
                end
            end,
        }
    )

    local miscGeneralCard = CreateSectionCard(
        miscMiscGeneralContent,
        sectionX,
        PAGE_SECTION_START_Y,
        sectionWidth,
        148,
        "General",
        "Enable or disable the Miscellaneous module. Includes cutscene automation, menu bar positioning, and the character stats display."
    )

    local miscEnabledCheckbox = CreateCheckbox(
        miscGeneralCard,
        "Enable Miscellaneous Module",
        18,
        -82,
        function()
            local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
            return miscSettings and miscSettings.enabled
        end,
        function(value)
            local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
            if miscSettings then
                ApplyModuleEnabledSetting("miscellaneous", value, function(v)
                    miscSettings.enabled = v and true or false
                end)
            end
        end
    )
    miscMiscGeneralPanel.refreshers[#miscMiscGeneralPanel.refreshers + 1] = miscEnabledCheckbox

    miscMiscGeneralPanel.UpdateLayout = function(self)
        miscGeneralCard:ClearAllPoints()
        miscGeneralCard:SetPoint("TOPLEFT", miscMiscGeneralContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        PositionControl(miscEnabledCheckbox, miscGeneralCard, 18, -82)
        FitSectionCardHeight(miscGeneralCard, 20)
        FitScrollContentHeight(miscMiscGeneralContent, self:GetHeight() - 16, 36)
    end

    miscMiscGeneralPanel:UpdateLayout()
    end

    do
    local miscCutscenesContent
    local miscDefaults = ns.DEFAULTS and ns.DEFAULTS.miscellaneous or {}
    local automationDefaults = ns.DEFAULTS and ns.DEFAULTS.automation or {}

    miscCutscenesPanel, miscCutscenesContent = CreateModulePage(
        "NomToolsMiscCutscenesPanel",
        "Miscellaneous",
        "Cutscenes",
        "Cutscene automation settings.",
        {
            moduleEnabledGetter = function()
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                local enabled = miscSettings and miscSettings.enabled
                if ns.IsModuleRuntimeEnabled then
                    return ns.IsModuleRuntimeEnabled("miscellaneous", enabled)
                end
                return enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                if miscSettings then
                    ns.SetModuleEnabled("miscellaneous", enabled, function(v) miscSettings.enabled = v end)
                end
            end,
            resetHandler = function(page)
                local automation = ns.GetAutomationSettings and ns.GetAutomationSettings() or nil
                if automation then
                    automation.skipSeenCutscenes = automationDefaults.skipSeenCutscenes == true
                end
            end,
        }
    )

    local cutscenesCard = CreateSectionCard(
        miscCutscenesContent,
        sectionX,
        PAGE_SECTION_START_Y,
        sectionWidth,
        132,
        "Cutscenes",
        "Automatically skips cinematics and movies only after NomTools has already seen that exact scene before. New cutscenes are never auto-skipped."
    )

    local cutsceneCheckbox = CreateCheckbox(
        cutscenesCard,
        "Automatically skip previously seen cutscenes",
        18,
        -78,
        function()
            local automation = ns.GetAutomationSettings and ns.GetAutomationSettings() or nil
            return automation and automation.skipSeenCutscenes
        end,
        function(value)
            local automation = ns.GetAutomationSettings and ns.GetAutomationSettings() or nil
            if automation then
                automation.skipSeenCutscenes = value and true or false
            end
        end
    )
    miscCutscenesPanel.refreshers[#miscCutscenesPanel.refreshers + 1] = cutsceneCheckbox

    miscCutscenesPanel.UpdateLayout = function(self)
        cutscenesCard:ClearAllPoints()
        cutscenesCard:SetPoint("TOPLEFT", miscCutscenesContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        PositionControl(cutsceneCheckbox, cutscenesCard, 18, -78)
        FitSectionCardHeight(cutscenesCard, 20)
        FitScrollContentHeight(miscCutscenesContent, self:GetHeight() - 16, 36)
    end

    miscCutscenesPanel:UpdateLayout()
    end

    do
    local miscCharStatsContent
    local charStatsDefaults = ns.DEFAULTS and ns.DEFAULTS.characterStats or {}
    local charStatsAppearanceDefaults = charStatsDefaults.appearance or {}
    local charStatsPositionDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.characterStats or {}

    miscCharStatsPanel, miscCharStatsContent = CreateModulePage(
        "NomToolsMiscCharStatsPanel",
        "Miscellaneous",
        "Character Stats",
        "Character stats display settings.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function()
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                local enabled = miscSettings and miscSettings.enabled
                if ns.IsModuleRuntimeEnabled then
                    return ns.IsModuleRuntimeEnabled("miscellaneous", enabled)
                end
                return enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                if miscSettings then
                    ns.SetModuleEnabled("miscellaneous", enabled, function(v) miscSettings.enabled = v end)
                end
            end,
            resetHandler = function(page)
                local charStats = ns.GetCharacterStatsSettings and ns.GetCharacterStatsSettings() or nil
                if charStats then
                    local defaultEnabled = charStatsDefaults.enabled == true
                    ns.SetModuleEnabled("characterStats", defaultEnabled, function(v) charStats.enabled = v end)
                    local defaultStats = charStatsDefaults.stats or {}
                    if type(charStats.stats) == "table" then
                        for key, def in pairs(defaultStats) do
                            if type(charStats.stats[key]) == "table" and type(def) == "table" then
                                charStats.stats[key].enabled = def.enabled == true
                            end
                        end
                    end
                    if type(charStats.appearance) == "table" then
                        local blizDefaults = charStatsAppearanceDefaults.blizzard or {}
                        local nomDefaults = charStatsAppearanceDefaults.nomtools or {}
                        charStats.appearance.preset = charStatsAppearanceDefaults.preset or "blizzard"
                        if type(charStats.appearance.blizzard) == "table" then
                            charStats.appearance.blizzard.font = blizDefaults.font or ns.GLOBAL_CHOICE_KEY
                            charStats.appearance.blizzard.fontOutline = blizDefaults.fontOutline or ns.GLOBAL_CHOICE_KEY
                            charStats.appearance.blizzard.fontSize = blizDefaults.fontSize or 12
                        end
                        if type(charStats.appearance.nomtools) == "table" then
                            charStats.appearance.nomtools.font = nomDefaults.font or ns.GLOBAL_CHOICE_KEY
                            charStats.appearance.nomtools.fontOutline = nomDefaults.fontOutline or ns.GLOBAL_CHOICE_KEY
                            charStats.appearance.nomtools.fontSize = nomDefaults.fontSize or 12
                            charStats.appearance.nomtools.backgroundOpacity = nomDefaults.backgroundOpacity or 80
                            local bgDef = nomDefaults.backgroundColor or { r = 0.05, g = 0.05, b = 0.05, a = 1 }
                            charStats.appearance.nomtools.backgroundColor = { r = bgDef.r, g = bgDef.g, b = bgDef.b, a = bgDef.a }
                            local bdDef = nomDefaults.borderColor or { r = 0.25, g = 0.25, b = 0.25, a = 1 }
                            charStats.appearance.nomtools.borderColor = { r = bdDef.r, g = bdDef.g, b = bdDef.b, a = bdDef.a }
                            charStats.appearance.nomtools.borderSize = nomDefaults.borderSize or 1
                            charStats.appearance.nomtools.texture = nomDefaults.texture or ns.GLOBAL_CHOICE_KEY
                            charStats.appearance.nomtools.borderTexture = nomDefaults.borderTexture or ns.GLOBAL_CHOICE_KEY
                        end
                    end
                end
                local posConfig = ns.GetEditModeConfig and ns.GetEditModeConfig("characterStats", charStatsPositionDefaults) or nil
                if posConfig then
                    posConfig.point = charStatsPositionDefaults.point
                    posConfig.x = charStatsPositionDefaults.x
                    posConfig.y = charStatsPositionDefaults.y
                end
                RequestOptionsRefresh("miscellaneous_character_stats", "reset")
            end,
        }
    )

    local function RefreshCharStatsPanel()
        ns.RequestRefresh("characterStats")
    end

    local charStatsCard = CreateSectionCard(
        miscCharStatsContent,
        sectionX,
        PAGE_SECTION_START_Y,
        sectionWidth,
        600,
        "Character Stats",
        "Color-coded display of your character's current stats. Each stat can be individually toggled."
    )

    local charStatsEnabledCheckbox = CreateCheckbox(
        charStatsCard,
        "Enable Character Stats Display",
        18,
        -78,
        function()
            local s = ns.GetCharacterStatsSettings and ns.GetCharacterStatsSettings() or {}
            return s.enabled ~= false
        end,
        function(value)
            local s = ns.GetCharacterStatsSettings and ns.GetCharacterStatsSettings() or nil
            if s then ns.SetModuleEnabled("characterStats", value, function(v) s.enabled = v end) end
        end
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = charStatsEnabledCheckbox

    local STAT_CHECKBOX_DEFS = {
        { key = "mainStat", label = "Main Stat (Str/Agi/Int)", col = 1, row = 1 },
        { key = "criticalStrike", label = "Critical Strike", col = 1, row = 2 },
        { key = "haste", label = "Haste", col = 1, row = 3 },
        { key = "mastery", label = "Mastery", col = 1, row = 4 },
        { key = "versatility", label = "Versatility", col = 1, row = 5 },
        { key = "leech", label = "Leech", col = 1, row = 6 },
        { key = "avoidance", label = "Avoidance", col = 1, row = 7 },
        { key = "stamina", label = "Stamina", col = 2, row = 1 },
        { key = "speed", label = "Speed", col = 2, row = 2 },
        { key = "dodge", label = "Dodge", col = 2, row = 3 },
        { key = "parry", label = "Parry", col = 2, row = 4 },
        { key = "block", label = "Block", col = 2, row = 5 },
        { key = "armor", label = "Armor", col = 2, row = 6 },
    }

    local statCheckboxes = {}
    for _, def in ipairs(STAT_CHECKBOX_DEFS) do
        local statKey = def.key
        local xPos = def.col == 1 and 18 or APPEARANCE_RIGHT_COLUMN_X
        local yPos = -110 - (def.row - 1) * 32
        local cb = CreateCheckbox(
            charStatsCard,
            def.label,
            xPos,
            yPos,
            function()
                local s = ns.GetCharacterStatsSettings and ns.GetCharacterStatsSettings() or {}
                local stats = s.stats
                return stats and stats[statKey] and stats[statKey].enabled
            end,
            function(value)
                local s = ns.GetCharacterStatsSettings and ns.GetCharacterStatsSettings() or {}
                local stats = s.stats
                if stats and stats[statKey] then
                    stats[statKey].enabled = value and true or false
                    RefreshCharStatsPanel()
                end
            end
        )
        statCheckboxes[#statCheckboxes + 1] = cb
        miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = cb
    end

    local function GetCharStatsSettings()
        return ns.GetCharacterStatsSettings and ns.GetCharacterStatsSettings() or {}
    end

    local function GetCharStatsAppearance()
        local settings = GetCharStatsSettings()
        local appearance = settings.appearance
        if type(appearance) ~= "table" then return {} end
        return appearance
    end

    local function GetCharStatsActiveProfile()
        local appearance = GetCharStatsAppearance()
        local preset = appearance.preset or "blizzard"
        local profile = appearance[preset]
        if type(profile) ~= "table" then return {} end
        return profile
    end

    local function GetCharStatsNomToolsProfile()
        local appearance = GetCharStatsAppearance()
        local profile = appearance.nomtools
        if type(profile) ~= "table" then return {} end
        return profile
    end

    local function GetCharStatsPositionConfig()
        return ns.GetEditModeConfig and ns.GetEditModeConfig("characterStats", charStatsPositionDefaults) or charStatsPositionDefaults
    end

    local function RefreshCharStatsAppearance()
        ns.RequestRefresh("characterStats")
        if miscCharStatsPanel and miscCharStatsPanel.RefreshAll then
            miscCharStatsPanel:RefreshAll()
        end
    end

    local appearanceCard = CreateSectionCard(
        miscCharStatsContent,
        sectionX,
        PAGE_SECTION_START_Y,
        sectionWidth,
        600,
        "Appearance",
        "Switch between the default look and a fully customizable style."
    )

    local presetDropdown = CreateStaticDropdown(
        appearanceCard, 18, -82,
        "Preset", APPEARANCE_COLUMN_WIDTH,
        REMINDER_PRESET_CHOICES,
        function() return GetCharStatsAppearance().preset end,
        function(value)
            GetCharStatsAppearance().preset = NormalizeReminderPresetValue(value, "blizzard")
            RefreshCharStatsAppearance()
        end,
        "Default"
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = presetDropdown

    local fontDropdown = CreateFontDropdown(
        appearanceCard, 18, -156,
        "Font", APPEARANCE_COLUMN_WIDTH,
        function() return GetCharStatsActiveProfile().font end,
        function(value)
            GetCharStatsActiveProfile().font = value
            RefreshCharStatsAppearance()
        end,
        "Friz Quadrata TT"
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = fontDropdown

    local fontOutlineDropdown = CreateStaticDropdown(
        appearanceCard, APPEARANCE_RIGHT_COLUMN_X, -156,
        "Font Outline", APPEARANCE_COLUMN_WIDTH,
        function() return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(true) or {} end,
        function() return GetCharStatsActiveProfile().fontOutline end,
        function(value)
            GetCharStatsActiveProfile().fontOutline = value
            RefreshCharStatsAppearance()
        end,
        "Outline"
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = fontOutlineDropdown

    local fontSizeSlider = CreateSlider(
        appearanceCard, 18, -230,
        "Font Size", APPEARANCE_COLUMN_WIDTH,
        6, 48, 1,
        function() return GetCharStatsActiveProfile().fontSize end,
        function(value)
            GetCharStatsActiveProfile().fontSize = value
            RefreshCharStatsAppearance()
        end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = fontSizeSlider

    local bgColorButton = CreateColorButton(
        appearanceCard, 18, -300,
        "Background",
        function()
            return GetColorValueWithOpacity(
                GetCharStatsNomToolsProfile().backgroundColor,
                GetCharStatsNomToolsProfile().backgroundOpacity,
                { r = 0.05, g = 0.05, b = 0.05, a = 0.8 }
            )
        end,
        function(value)
            SetTableColorWithOpacity(
                GetCharStatsNomToolsProfile(),
                "backgroundColor", "backgroundOpacity",
                value,
                { r = 0.05, g = 0.05, b = 0.05, a = 0.8 }
            )
            RefreshCharStatsAppearance()
        end,
        { hasOpacity = true }
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = bgColorButton

    local borderColorButton = CreateColorButton(
        appearanceCard, APPEARANCE_RIGHT_COLUMN_X, -300,
        "Border Color",
        function()
            return NormalizeColorValue(GetCharStatsNomToolsProfile().borderColor, { r = 0.25, g = 0.25, b = 0.25, a = 1 })
        end,
        function(value)
            local profile = GetCharStatsNomToolsProfile()
            local color = NormalizeColorValue(value, { r = 0.25, g = 0.25, b = 0.25, a = 1 })
            profile.borderColor = { r = color.r, g = color.g, b = color.b, a = color.a }
            RefreshCharStatsAppearance()
        end,
        { hasOpacity = false }
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = borderColorButton

    local borderSizeSlider = CreateSlider(
        appearanceCard, 18, -374,
        "Border Size", APPEARANCE_COLUMN_WIDTH,
        0, 10, 1,
        function() return GetCharStatsNomToolsProfile().borderSize end,
        function(value)
            GetCharStatsNomToolsProfile().borderSize = value
            RefreshCharStatsAppearance()
        end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = borderSizeSlider

    local textureDropdown = CreateStatusBarTextureDropdown(
        appearanceCard,
        18,
        -448,
        "Background Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetCharStatsNomToolsProfile().texture
        end,
        function(value)
            GetCharStatsNomToolsProfile().texture = value
            RefreshCharStatsAppearance()
        end,
        "Global",
        { includeGlobalChoice = true }
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = textureDropdown

    local borderTextureDropdown = CreateStatusBarTextureDropdown(
        appearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -448,
        "Border Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetCharStatsNomToolsProfile().borderTexture
        end,
        function(value)
            GetCharStatsNomToolsProfile().borderTexture = value
            RefreshCharStatsAppearance()
        end,
        "Global",
        {
            includeGlobalChoice = true,
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = borderTextureDropdown

    local positionCard = CreateSectionCard(
        miscCharStatsContent,
        sectionX,
        PAGE_SECTION_START_Y,
        sectionWidth,
        256,
        "Position",
        "Anchor point and offset for the character stats display. You can also drag it in Edit Mode."
    )

    local anchorDropdown = CreateStaticDropdown(
        positionCard, 18, -82,
        "Anchor Point", APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function() return GetCharStatsPositionConfig().point end,
        function(value)
            GetCharStatsPositionConfig().point = NormalizeReminderPointValue(value, charStatsPositionDefaults.point)
            ns.RequestRefresh("characterStats")
        end,
        "Top Left"
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = anchorDropdown

    local xSlider = ns.CreateOptionsPositionSlider(positionCard, 18, -146, "Horizontal Offset", "x",
        function() return GetCharStatsPositionConfig().x end,
        function(value)
            GetCharStatsPositionConfig().x = value
            ns.RequestRefresh("characterStats")
        end
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = xSlider

    local ySlider = ns.CreateOptionsPositionSlider(positionCard, APPEARANCE_RIGHT_COLUMN_X, -146, "Vertical Offset", "y",
        function() return GetCharStatsPositionConfig().y end,
        function(value)
            GetCharStatsPositionConfig().y = value
            ns.RequestRefresh("characterStats")
        end
    )
    miscCharStatsPanel.refreshers[#miscCharStatsPanel.refreshers + 1] = ySlider

    miscCharStatsPanel.UpdateLayout = function(self)
        local cardSpacing = 20
        local currentY = PAGE_SECTION_START_Y
        local useNomToolsAppearance = GetCharStatsAppearance().preset == "nomtools"

        charStatsCard:ClearAllPoints()
        charStatsCard:SetPoint("TOPLEFT", miscCharStatsContent, "TOPLEFT", sectionX, currentY)
        PositionControl(charStatsEnabledCheckbox, charStatsCard, 18, -78)
        for idx, def in ipairs(STAT_CHECKBOX_DEFS) do
            local xPos = def.col == 1 and 18 or APPEARANCE_RIGHT_COLUMN_X
            local yPos = -110 - (def.row - 1) * 32
            PositionControl(statCheckboxes[idx], charStatsCard, xPos, yPos)
        end
        currentY = currentY - FitSectionCardHeight(charStatsCard, 20) - cardSpacing

        appearanceCard:ClearAllPoints()
        appearanceCard:SetPoint("TOPLEFT", miscCharStatsContent, "TOPLEFT", sectionX, currentY)
        PositionControl(presetDropdown, appearanceCard, 18, -82)
        PositionControl(fontDropdown, appearanceCard, 18, -156)
        PositionControl(fontOutlineDropdown, appearanceCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        PositionControl(fontSizeSlider, appearanceCard, 18, -230)
        PositionControl(textureDropdown, appearanceCard, 18, -300)
        PositionControl(borderTextureDropdown, appearanceCard, APPEARANCE_RIGHT_COLUMN_X, -300)
        PositionControl(bgColorButton, appearanceCard, 18, -374)
        PositionControl(borderColorButton, appearanceCard, APPEARANCE_RIGHT_COLUMN_X, -374)
        PositionControl(borderSizeSlider, appearanceCard, 18, -448)
        SetControlEnabled(textureDropdown, useNomToolsAppearance)
        SetControlEnabled(borderTextureDropdown, useNomToolsAppearance)
        SetControlEnabled(bgColorButton, useNomToolsAppearance)
        SetControlEnabled(borderColorButton, useNomToolsAppearance)
        SetControlEnabled(borderSizeSlider, useNomToolsAppearance)
        currentY = currentY - FitSectionCardHeight(appearanceCard, 20) - cardSpacing

        positionCard:ClearAllPoints()
        positionCard:SetPoint("TOPLEFT", miscCharStatsContent, "TOPLEFT", sectionX, currentY)
        PositionControl(anchorDropdown, positionCard, 18, -82)
        PositionControl(xSlider, positionCard, 18, -146)
        PositionControl(ySlider, positionCard, APPEARANCE_RIGHT_COLUMN_X, -146)
        currentY = currentY - FitSectionCardHeight(positionCard, 20) - cardSpacing

        FitScrollContentHeight(miscCharStatsContent, self:GetHeight() - 16, 36)
    end

    miscCharStatsPanel:UpdateLayout()
    end

    do
    local generalContent
    local consumableDefaults = ns.DEFAULTS and ns.DEFAULTS.consumables or {}
    generalPanel, generalContent = CreateModulePage(
        "NomToolsConsumablesGeneralPanel",
        "Consumables",
        "General",
        "Control whether the consumables reminder module is enabled.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function() return ns.db and ns.db.enabled ~= false end,
            moduleEnabledSetter = function(enabled)
                if ns.db then ns.db.enabled = enabled and true or false end
                if ns.SetModuleEnabled then ns.SetModuleEnabled("consumables", enabled, function(v) if ns.db then ns.db.enabled = v end end) end
            end,
            resetHandler = function()
                if not ns.db then
                    return
                end

                ns.db.consumables = ns.db.consumables or {}
                ResetModuleEnabledSetting("consumables", ns.DEFAULTS and ns.DEFAULTS.enabled, function(enabled)
                    ns.db.enabled = enabled and true or false
                end)
            end,
        }
    )
    ns.optionsPanel = generalPanel

    local generalCard = CreateSectionCard(
        generalContent,
        sectionX,
        -96,
        sectionWidth,
        148,
        "General",
        "Enable or disable the consumables reminder module. Individual tracking sections control their own combat, Mythic+, and location visibility."
    )

    local enabledCheckbox = CreateCheckbox(
        generalCard,
        "Enable Consumables Module",
        18,
        -82,
        function()
            return ns.db and ns.db.enabled
        end,
        function(value)
            ApplyModuleEnabledSetting("consumables", value, function(enabled)
                ns.db.enabled = enabled and true or false
            end, ns.RequestRefresh)
        end
    )
    generalPanel.refreshers[#generalPanel.refreshers + 1] = enabledCheckbox

    generalPanel.UpdateLayout = function(self)
        generalCard:ClearAllPoints()
        generalCard:SetPoint("TOPLEFT", generalContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        FitSectionCardHeight(generalCard, 20)
        FitScrollContentHeight(generalContent, generalPanel:GetHeight() - 16, 36)
    end

    generalPanel:UpdateLayout()

    end

    do
    local objectiveTrackerContent
    local objectiveTrackerLayoutContent
    local objectiveTrackerAppearanceContent
    local objectiveTrackerSectionsContent
    local objectiveTrackerDefaults = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker or { enabled = true }
    local otPositionDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.objectiveTracker
        or { point = "RIGHT", x = -5, y = 0 }
    local function OTModuleEnabledGetter()
        local s = ns.GetObjectiveTrackerSettings and ns.GetObjectiveTrackerSettings() or nil
        return s and s.enabled ~= false
    end
    local function OTModuleEnabledSetter(enabled)
        local s = ns.GetObjectiveTrackerSettings and ns.GetObjectiveTrackerSettings() or nil
        if s then ns.SetModuleEnabled("objectiveTracker", enabled, function(v) s.enabled = v end) end
    end
    local function OTGeneralResetHandler()
        if not ns.db or not ns.db.objectiveTracker then return end
        local s = ns.db.objectiveTracker
        s.focusedQuest = CopyTableRecursive(objectiveTrackerDefaults.focusedQuest or {})
        s.header = CopyTableRecursive(objectiveTrackerDefaults.header or {})
        s.buttons = CopyTableRecursive(objectiveTrackerDefaults.buttons or {})
        ResetModuleEnabledSetting("objectiveTracker", objectiveTrackerDefaults.enabled, function(enabled)
            s.enabled = enabled and true or false
        end)
    end
    local function OTLayoutResetHandler()
        if not ns.db or not ns.db.objectiveTracker then return end
        local s = ns.db.objectiveTracker
        s.layout = CopyTableRecursive(objectiveTrackerDefaults.layout or {})
        ResetEditModeConfig("objectiveTracker", otPositionDefaults)
    end
    local function OTAppearanceResetHandler()
        if not ns.db or not ns.db.objectiveTracker then return end
        local s = ns.db.objectiveTracker
        s.appearance = CopyTableRecursive(objectiveTrackerDefaults.appearance or {})
        s.typography = CopyTableRecursive(objectiveTrackerDefaults.typography or {})
        s.scrollBar = CopyTableRecursive(objectiveTrackerDefaults.scrollBar or {})
        s.progressBar = CopyTableRecursive(objectiveTrackerDefaults.progressBar or {})
    end
    local function OTSectionsResetHandler()
        if not ns.db or not ns.db.objectiveTracker then return end
        local s = ns.db.objectiveTracker
        s.zone = CopyTableRecursive(objectiveTrackerDefaults.zone or {})
        s.order = CopyTableRecursive(objectiveTrackerDefaults.order or {})
    end
    objectiveTrackerPanel, objectiveTrackerContent = CreateModulePage(
        "NomToolsObjectiveTrackerPanel",
        "Objective Tracker",
        "General",
        "Control the module state, main header visibility and components, focused quest section, and Track All buttons.",
        { showEditModeButton = true, moduleEnabledGetter = OTModuleEnabledGetter, moduleEnabledSetter = OTModuleEnabledSetter, resetHandler = OTGeneralResetHandler }
    )
    objectiveTrackerLayoutPanel, objectiveTrackerLayoutContent = CreateModulePage(
        "NomToolsObjectiveTrackerLayoutPanel",
        "Objective Tracker",
        "Size & Position",
        "Set the tracker width, height, and screen position. Attach to the minimap or use manual X/Y coordinates.",
        { showEditModeButton = true, moduleEnabledGetter = OTModuleEnabledGetter, moduleEnabledSetter = OTModuleEnabledSetter, resetHandler = OTLayoutResetHandler }
    )
    objectiveTrackerAppearancePanel, objectiveTrackerAppearanceContent = CreateModulePage(
        "NomToolsObjectiveTrackerAppearancePanel",
        "Objective Tracker",
        "Appearance",
        "Configure header and button presets, typography, scrollbar style, and progress bar colors.",
        { moduleEnabledGetter = OTModuleEnabledGetter, moduleEnabledSetter = OTModuleEnabledSetter, resetHandler = OTAppearanceResetHandler }
    )
    objectiveTrackerSectionsPanel, objectiveTrackerSectionsContent = CreateModulePage(
        "NomToolsObjectiveTrackerSectionsPanel",
        "Objective Tracker",
        "Sections",
        "Choose which quest types appear in the Zone category and reorder the tracker sections.",
        { moduleEnabledGetter = OTModuleEnabledGetter, moduleEnabledSetter = OTModuleEnabledSetter, resetHandler = OTSectionsResetHandler }
    )

    local function GetObjectiveTrackerOptions()
        return ns.GetObjectiveTrackerSettings and ns.GetObjectiveTrackerSettings() or nil
    end

    local function GetObjectiveTrackerZoneOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.zone = settings.zone or {}
        settings.zone.titleColors = settings.zone.titleColors or {}
        return settings.zone
    end

    local function GetObjectiveTrackerTypographyOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.typography = settings.typography or {}
        return settings.typography
    end

    local OBJECTIVE_TRACKER_LEVEL_PREFIX_CHOICES = {
        { key = "trivial", name = "Only Trivial Quests" },
        { key = "all", name = "All Quests" },
        { key = "none", name = "Disabled" },
    }

    local OBJECTIVE_TRACKER_PROGRESS_BAR_FILL_MODE_CHOICES = {
        { key = "progress", name = "Based on Progress" },
        { key = "static", name = "Solid Color" },
    }

    local function GetObjectiveTrackerLevelPrefixMode()
        local typography = GetObjectiveTrackerTypographyOptions()
        local mode = typography.levelPrefixMode
        if mode == "all" or mode == "trivial" or mode == "none" then
            return mode
        end

        if typography.showLevelPrefix == false then
            return "none"
        end

        return "trivial"
    end

    local function GetObjectiveTrackerTitleColorOptions()
        local typography = GetObjectiveTrackerTypographyOptions()
        typography.titleColors = typography.titleColors or {}
        return typography.titleColors
    end

    local function GetObjectiveTrackerFocusedQuestOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.focusedQuest = settings.focusedQuest or {}
        return settings.focusedQuest
    end

    local function GetObjectiveTrackerScrollBarOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.scrollBar = settings.scrollBar or {}
        return settings.scrollBar
    end

    local function GetObjectiveTrackerProgressBarOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.progressBar = settings.progressBar or {}
        local progressBar = settings.progressBar
        if progressBar.borderEnabled == false and tonumber(progressBar.borderSize or 1) ~= 0 then
            progressBar.borderSize = 0
        end
        progressBar.borderColor = NormalizeColorValue(progressBar.borderColor, { r = 0, g = 0, b = 0, a = 1 })
        if type(progressBar.borderTexture) ~= "string" or progressBar.borderTexture == "" then
            progressBar.borderTexture = progressBar.texture or ns.GLOBAL_CHOICE_KEY
        end
        progressBar.borderSize = NormalizeSignedBorderSize(progressBar.borderSize, 1)
        return progressBar
    end

    local function GetObjectiveTrackerProgressBarFillMode()
        local progressBar = GetObjectiveTrackerProgressBarOptions()
        if progressBar.fillMode == "static" then
            return "static"
        end

        return "progress"
    end

    local function GetObjectiveTrackerButtonOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.buttons = settings.buttons or {}
        if settings.buttons.minimize == nil then
            settings.buttons.minimize = true
        end
        if settings.buttons.trackerTrackAll == nil then
            if settings.buttons.trackAll ~= nil then
                settings.buttons.trackerTrackAll = settings.buttons.trackAll ~= false
            else
                settings.buttons.trackerTrackAll = true
            end
        end
        if settings.buttons.questLogTrackAll == nil then
            if settings.buttons.trackAll ~= nil then
                settings.buttons.questLogTrackAll = settings.buttons.trackAll ~= false
            else
                settings.buttons.questLogTrackAll = true
            end
        end
        return settings.buttons
    end

    local function GetObjectiveTrackerHeaderOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.header = settings.header or {}
        return settings.header
    end

    local OBJECTIVE_TRACKER_HEADER_PRESET_CHOICES = {
           { key = "blizzard", name = "Default" },
        { key = "nomtools", name = "Custom" },
    }

    local function GetObjectiveTrackerAppearanceOptions()
        local settings = GetObjectiveTrackerOptions()
        local defaults = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.appearance or {}

        settings.appearance = settings.appearance or {}

        local appearance = settings.appearance
        if appearance.preset ~= "nomtools" then
            appearance.preset = defaults.preset or "blizzard"
        end

        return appearance
    end

    local function GetSectionAppearanceOptions(sectionKey)
        local appearance = GetObjectiveTrackerAppearanceOptions()
        if not appearance[sectionKey] then
            local defCol = { r = 0, g = 0, b = 0, a = 1 }
            appearance[sectionKey] = {
                texture = "blizzard",
                opacity = 80,
                color = defCol,
                borderColor = defCol,
                borderTexture = "blizzard",
                borderSize = 1,
            }
        end
        local s = appearance[sectionKey]
        s.opacity = math.max(0, math.min(100, math.floor((tonumber(s.opacity) or 80) + 0.5)))
        s.color = NormalizeColorValue(s.color, { r = 0, g = 0, b = 0, a = 1 })
        s.borderColor = NormalizeColorValue(s.borderColor, { r = 0, g = 0, b = 0, a = 1 })
        if s.borderEnabled == false and tonumber(s.borderSize or 1) ~= 0 then
            s.borderSize = 0
        end
        if type(s.borderTexture) ~= "string" or s.borderTexture == "" then
            s.borderTexture = s.texture or ns.GLOBAL_CHOICE_KEY
        end
        s.borderSize = NormalizeSignedBorderSize(s.borderSize, 1)
        return s
    end

    local function GetObjectiveTrackerMainHeaderAppearanceOptions()
        return GetSectionAppearanceOptions("mainHeader")
    end

    local function GetObjectiveTrackerCategoryHeaderAppearanceOptions()
        return GetSectionAppearanceOptions("categoryHeader")
    end

    local function GetObjectiveTrackerButtonAppearanceOptions()
        return GetSectionAppearanceOptions("button")
    end

    local function GetObjectiveTrackerTrackerBackgroundOptions()
        local appearance = GetObjectiveTrackerAppearanceOptions()
        local defaults = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.appearance and ns.DEFAULTS.objectiveTracker.appearance.trackerBackground or {}
        if type(appearance.trackerBackground) ~= "table" then
            appearance.trackerBackground = {}
        end
        local tbg = appearance.trackerBackground
        if tbg.enabled == nil then
            tbg.enabled = appearance.preset == "nomtools"
        end
        if type(tbg.texture) ~= "string" or tbg.texture == "" then
            tbg.texture = defaults.texture or ns.GLOBAL_CHOICE_KEY
        end
        tbg.opacity = math.max(0, math.min(100, math.floor((tonumber(tbg.opacity) or 60) + 0.5)))
        tbg.color = NormalizeColorValue(tbg.color, { r = 0, g = 0, b = 0, a = 1 })
        tbg.borderColor = NormalizeColorValue(tbg.borderColor, { r = 0, g = 0, b = 0, a = 1 })
        if tbg.borderEnabled == false and tonumber(tbg.borderSize or 1) ~= 0 then
            tbg.borderSize = 0
        end
        if type(tbg.borderTexture) ~= "string" or tbg.borderTexture == "" then
            tbg.borderTexture = defaults.borderTexture or tbg.texture or ns.GLOBAL_CHOICE_KEY
        end
        tbg.borderSize = NormalizeSignedBorderSize(tbg.borderSize, 1)
        return tbg
    end

    local function GetObjectiveTrackerLayoutOptions()
        local settings = GetObjectiveTrackerOptions()
        settings.layout = settings.layout or {}
        local s = settings.layout
        local defaults = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.layout or {}
        s.width  = math.max(150, math.min(500,  math.floor((tonumber(s.width)  or tonumber(defaults.width)  or 235) + 0.5)))
        s.height = math.max(200, math.min(1400, math.floor((tonumber(s.height) or tonumber(defaults.height) or 800) + 0.5)))
        if s.matchMinimapWidth == nil then
            s.matchMinimapWidth = defaults.matchMinimapWidth == true
        end
        if s.attachToMinimap == nil then
            s.attachToMinimap = defaults.attachToMinimap == true
        end
        s.minimapYOffset = math.max(-200, math.min(200, math.floor((tonumber(s.minimapYOffset) or tonumber(defaults.minimapYOffset) or 0) + 0.5)))
        local ae = s.minimapAttachEdge
        if ae ~= "top" and ae ~= "bottom" then
            s.minimapAttachEdge = defaults.minimapAttachEdge or "bottom"
        end
        return s
    end

    local function GetObjectiveTrackerPositionConfig()
        return GetReminderPositionConfig("objectiveTracker", otPositionDefaults)
    end

    local function GetObjectiveTrackerMainHeaderTypographyOptions()
        local typography = GetObjectiveTrackerTypographyOptions()
        typography.mainHeader = typography.mainHeader or {}
        return typography.mainHeader
    end

    local function GetObjectiveTrackerCategoryHeaderTypographyOptions()
        local typography = GetObjectiveTrackerTypographyOptions()
        typography.categoryHeader = typography.categoryHeader or {}
        return typography.categoryHeader
    end

    local function RefreshObjectiveTrackerOptionsPanel(refreshMode)
        if ns.RefreshObjectiveTrackerUI then
            ns.RefreshObjectiveTrackerUI(refreshMode == "full" and "full" or "soft")
        end
        if objectiveTrackerPanel and objectiveTrackerPanel.RefreshAll then
            objectiveTrackerPanel:RefreshAll()
        end
        if objectiveTrackerLayoutPanel and objectiveTrackerLayoutPanel.RefreshAll then
            objectiveTrackerLayoutPanel:RefreshAll()
        end
        if objectiveTrackerAppearancePanel and objectiveTrackerAppearancePanel.RefreshAll then
            objectiveTrackerAppearancePanel:RefreshAll()
        end
        if objectiveTrackerSectionsPanel and objectiveTrackerSectionsPanel.RefreshAll then
            objectiveTrackerSectionsPanel:RefreshAll()
        end
    end

    local objectiveTrackerAppearanceRefreshVersion = 0
    local function ScheduleObjectiveTrackerAppearanceSoftRefresh()
        if objectiveTrackerAppearancePanel and objectiveTrackerAppearancePanel.RefreshAll then
            objectiveTrackerAppearancePanel:RefreshAll()
        end

        objectiveTrackerAppearanceRefreshVersion = objectiveTrackerAppearanceRefreshVersion + 1
        local scheduledVersion = objectiveTrackerAppearanceRefreshVersion

        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if scheduledVersion ~= objectiveTrackerAppearanceRefreshVersion then
                    return
                end

                if ns.RefreshObjectiveTrackerUI then
                    ns.RefreshObjectiveTrackerUI("soft")
                end
            end)
            return
        end

        if ns.RefreshObjectiveTrackerUI then
            ns.RefreshObjectiveTrackerUI("soft")
        end
    end

    local function RefreshObjectiveTrackerStructureOptionsPanel()
        RefreshObjectiveTrackerOptionsPanel("full")
    end

    local objectiveTrackerCards = {}
    local objectiveTrackerControls = {
        zoneFilters = {},
        orderRows = {},
    }

    objectiveTrackerCards.general = CreateSectionCard(
        objectiveTrackerContent,
        sectionX,
        -96,
        sectionWidth,
        100,
        "General",
        "Control the overall module state and quest log Track All button."
    )

    objectiveTrackerControls.enabled = CreateCheckbox(
        objectiveTrackerCards.general,
        "Enable Objective Tracker Module",
        18,
        -82,
        function()
            local settings = GetObjectiveTrackerOptions()
            return settings and settings.enabled
        end,
        function(value)
            local settings = GetObjectiveTrackerOptions()
            if settings then
                ApplyModuleEnabledSetting("objectiveTracker", value, function(enabled)
                    settings.enabled = enabled and true or false
                end, RefreshObjectiveTrackerStructureOptionsPanel)
            end
        end
    )
    objectiveTrackerPanel.refreshers[#objectiveTrackerPanel.refreshers + 1] = objectiveTrackerControls.enabled

    objectiveTrackerControls.questLogTrackAll = CreateCheckbox(
        objectiveTrackerCards.general,
        "Show Quest Log Track All Button",
        18,
        -112,
        function()
            return GetObjectiveTrackerButtonOptions().questLogTrackAll ~= false
        end,
        function(value)
            GetObjectiveTrackerButtonOptions().questLogTrackAll = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerPanel.refreshers[#objectiveTrackerPanel.refreshers + 1] = objectiveTrackerControls.questLogTrackAll

    objectiveTrackerCards.position = CreateSectionCard(
        objectiveTrackerLayoutContent,
        sectionX,
        -96,
        sectionWidth,
        100,
        "Position",
        "Set the tracker position and size."
    )

    objectiveTrackerCards.minimap = CreateSectionCard(
        objectiveTrackerLayoutContent,
        sectionX,
        -96,
        sectionWidth,
        100,
        "Minimap Attachment",
        "Attach the tracker to the minimap and optionally match its width."
    )

    objectiveTrackerControls.generalMatchMinimapWidth = CreateCheckbox(
        objectiveTrackerCards.minimap,
        "Match Minimap Width",
        18,
        -82,
        function()
            return GetObjectiveTrackerLayoutOptions().matchMinimapWidth == true
        end,
        function(value)
            GetObjectiveTrackerLayoutOptions().matchMinimapWidth = value and true or false
            RefreshObjectiveTrackerStructureOptionsPanel()
        end
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalMatchMinimapWidth

    objectiveTrackerControls.generalAttachToMinimap = CreateCheckbox(
        objectiveTrackerCards.minimap,
        "Attach to Minimap",
        18,
        -112,
        function()
            return GetObjectiveTrackerLayoutOptions().attachToMinimap == true
        end,
        function(value)
            GetObjectiveTrackerLayoutOptions().attachToMinimap = value and true or false
            RefreshObjectiveTrackerStructureOptionsPanel()
        end
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalAttachToMinimap

    objectiveTrackerControls.generalMinimapAttachEdgeDropdown = CreateStaticDropdown(
        objectiveTrackerCards.minimap,
        18,
        -148,
        "Attach Edge",
        APPEARANCE_COLUMN_WIDTH,
        MINIMAP_ATTACH_EDGE_CHOICES,
        function()
            return GetObjectiveTrackerLayoutOptions().minimapAttachEdge
        end,
        function(value)
            GetObjectiveTrackerLayoutOptions().minimapAttachEdge = (value == "top") and "top" or "bottom"
            RefreshObjectiveTrackerStructureOptionsPanel()
        end,
        "bottom"
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalMinimapAttachEdgeDropdown

    objectiveTrackerControls.generalMinimapYOffsetSlider = CreateSlider(
        objectiveTrackerCards.minimap,
        18,
        -222,
        "Y Offset",
        APPEARANCE_COLUMN_WIDTH,
        -50,
        200,
        1,
        function()
            return GetObjectiveTrackerLayoutOptions().minimapYOffset
        end,
        function(value)
            GetObjectiveTrackerLayoutOptions().minimapYOffset = value
            RefreshObjectiveTrackerStructureOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalMinimapYOffsetSlider

    objectiveTrackerControls.generalAnchorPointDropdown = CreateStaticDropdown(
        objectiveTrackerCards.position,
        18,
        -82,
        "Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetObjectiveTrackerPositionConfig().point
        end,
        function(value)
            GetObjectiveTrackerPositionConfig().point = NormalizeReminderPointValue(value, otPositionDefaults.point)
            RefreshObjectiveTrackerStructureOptionsPanel()
        end,
        "Right"
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalAnchorPointDropdown

    objectiveTrackerControls.generalPositionXSlider = ns.CreateOptionsPositionSlider(
        objectiveTrackerCards.position,
        18,
        -156,
        "X Position",
        "x",
        function()
            return GetObjectiveTrackerPositionConfig().x
        end,
        function(value)
            GetObjectiveTrackerPositionConfig().x = value
            RefreshObjectiveTrackerStructureOptionsPanel()
        end
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalPositionXSlider

    objectiveTrackerControls.generalPositionYSlider = ns.CreateOptionsPositionSlider(
        objectiveTrackerCards.position,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Y Position",
        "y",
        function()
            return GetObjectiveTrackerPositionConfig().y
        end,
        function(value)
            GetObjectiveTrackerPositionConfig().y = value
            RefreshObjectiveTrackerStructureOptionsPanel()
        end
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalPositionYSlider

    objectiveTrackerControls.generalWidthSlider = CreateSlider(
        objectiveTrackerCards.position,
        18,
        -230,
        "Width",
        APPEARANCE_COLUMN_WIDTH,
        150,
        500,
        5,
        function()
            return GetObjectiveTrackerLayoutOptions().width
        end,
        function(value)
            GetObjectiveTrackerLayoutOptions().width = value
            RefreshObjectiveTrackerStructureOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalWidthSlider

    objectiveTrackerControls.generalHeightSlider = CreateSlider(
        objectiveTrackerCards.position,
        APPEARANCE_RIGHT_COLUMN_X,
        -230,
        "Height",
        APPEARANCE_COLUMN_WIDTH,
        200,
        1400,
        10,
        function()
            return GetObjectiveTrackerLayoutOptions().height
        end,
        function(value)
            GetObjectiveTrackerLayoutOptions().height = value
            RefreshObjectiveTrackerStructureOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    objectiveTrackerLayoutPanel.refreshers[#objectiveTrackerLayoutPanel.refreshers + 1] = objectiveTrackerControls.generalHeightSlider

    -- Expose a slider refresh callback so edit mode drag can update these controls.
    ns.RefreshObjectiveTrackerOptionsSliders = function()
        if objectiveTrackerLayoutPanel and objectiveTrackerLayoutPanel.RefreshAll then
            objectiveTrackerLayoutPanel:RefreshAll()
        end
    end



    objectiveTrackerCards.preset = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        100,
        "Style Preset",
        "Choose Blizzard for stock styling or Custom for full control over surface textures, colors, and borders."
    )

    objectiveTrackerCards.appearance = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        1240,
        "Surface Appearance",
        "Texture, fill color, border, and border size for the tracker background, main header, category headers, and buttons. Only available with the Custom preset."
    )

    objectiveTrackerControls.appearancePresetDropdown = CreateStaticDropdown(
        objectiveTrackerCards.preset,
        18,
        -68,
        "Preset",
        FULL_DROPDOWN_WIDTH,
        OBJECTIVE_TRACKER_HEADER_PRESET_CHOICES,
        function()
            return GetObjectiveTrackerAppearanceOptions().preset
        end,
        function(value)
            GetObjectiveTrackerAppearanceOptions().preset = value
            GetObjectiveTrackerTrackerBackgroundOptions().enabled = (value == "nomtools")
            RefreshObjectiveTrackerOptionsPanel()
        end,
            "Default"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearancePresetDropdown

    -- Tracker Background sub-section
    objectiveTrackerControls.trackerBgLabel = CreateSubsectionTitle(objectiveTrackerCards.appearance, "Tracker Background", 18, -130)
    objectiveTrackerControls.trackerBgEnabledCheckbox = CreateCheckbox(
        objectiveTrackerCards.appearance,
        "Enable tracker background",
        18, -168,
        function() return GetObjectiveTrackerTrackerBackgroundOptions().enabled == true end,
        function(value) GetObjectiveTrackerTrackerBackgroundOptions().enabled = value; RefreshObjectiveTrackerOptionsPanel() end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.trackerBgEnabledCheckbox
    objectiveTrackerControls.trackerBgTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -208, "Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerTrackerBackgroundOptions().texture end,
        function(value) GetObjectiveTrackerTrackerBackgroundOptions().texture = value; RefreshObjectiveTrackerOptionsPanel() end,
            "Default Status Bar"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.trackerBgTextureDropdown
    objectiveTrackerControls.trackerBgColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -208, "Fill Color",
        function()
            local settings = GetObjectiveTrackerTrackerBackgroundOptions()
            return GetColorValueWithOpacity(settings.color, settings.opacity, { r = 0, g = 0, b = 0, a = 0.6 })
        end,
        function(value)
            local settings = GetObjectiveTrackerTrackerBackgroundOptions()
            SetTableColorWithOpacity(settings, "color", "opacity", value, { r = 0, g = 0, b = 0, a = 0.6 })
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.trackerBgColorButton
    objectiveTrackerControls.trackerBgBorderColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, 18, -354, "Border Color",
        function() return GetObjectiveTrackerTrackerBackgroundOptions().borderColor end,
        function(value) GetObjectiveTrackerTrackerBackgroundOptions().borderColor = value; RefreshObjectiveTrackerOptionsPanel() end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.trackerBgBorderColorButton
    objectiveTrackerControls.trackerBgBorderTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -282, "Border Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerTrackerBackgroundOptions().borderTexture end,
        function(value) GetObjectiveTrackerTrackerBackgroundOptions().borderTexture = value; RefreshObjectiveTrackerOptionsPanel() end,
        "Solid Line",
        {
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.trackerBgBorderTextureDropdown
    objectiveTrackerControls.trackerBgBorderSizeSlider = CreateSlider(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -282, "Border Size", APPEARANCE_COLUMN_WIDTH, -10, 10, 1,
        function() return GetObjectiveTrackerTrackerBackgroundOptions().borderSize or 1 end,
        function(value) GetObjectiveTrackerTrackerBackgroundOptions().borderSize = value; ScheduleObjectiveTrackerAppearanceSoftRefresh() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.trackerBgBorderSizeSlider

    -- Main Header sub-section
    objectiveTrackerControls.appearanceMainHeaderLabel = CreateSubsectionTitle(objectiveTrackerCards.appearance, "Main Header", 18, -454)
    objectiveTrackerControls.appearanceMainHeaderTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -492, "Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerMainHeaderAppearanceOptions().texture end,
        function(value) GetObjectiveTrackerMainHeaderAppearanceOptions().texture = value; RefreshObjectiveTrackerOptionsPanel() end,
            "Default Status Bar"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceMainHeaderTextureDropdown
    objectiveTrackerControls.appearanceMainHeaderColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -492, "Fill Color",
        function()
            local settings = GetObjectiveTrackerMainHeaderAppearanceOptions()
            return GetColorValueWithOpacity(settings.color, settings.opacity, { r = 0.08, g = 0.08, b = 0.08, a = 0.8 })
        end,
        function(value)
            local settings = GetObjectiveTrackerMainHeaderAppearanceOptions()
            SetTableColorWithOpacity(settings, "color", "opacity", value, { r = 0.08, g = 0.08, b = 0.08, a = 0.8 })
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceMainHeaderColorButton
    objectiveTrackerControls.appearanceMainHeaderBorderColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, 18, -656, "Border Color",
        function() return GetObjectiveTrackerMainHeaderAppearanceOptions().borderColor end,
        function(value) GetObjectiveTrackerMainHeaderAppearanceOptions().borderColor = value; RefreshObjectiveTrackerOptionsPanel() end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceMainHeaderBorderColorButton
    objectiveTrackerControls.appearanceMainHeaderBorderTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -582, "Border Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerMainHeaderAppearanceOptions().borderTexture end,
        function(value) GetObjectiveTrackerMainHeaderAppearanceOptions().borderTexture = value; RefreshObjectiveTrackerOptionsPanel() end,
        "Global",
        {
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceMainHeaderBorderTextureDropdown
    objectiveTrackerControls.appearanceMainHeaderBorderSizeSlider = CreateSlider(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -582, "Border Size", APPEARANCE_COLUMN_WIDTH, -10, 10, 1,
        function() return GetObjectiveTrackerMainHeaderAppearanceOptions().borderSize or 1 end,
        function(value) GetObjectiveTrackerMainHeaderAppearanceOptions().borderSize = value; ScheduleObjectiveTrackerAppearanceSoftRefresh() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceMainHeaderBorderSizeSlider

    -- Category Headers sub-section
    objectiveTrackerControls.appearanceCategoryHeaderLabel = CreateSubsectionTitle(objectiveTrackerCards.appearance, "Category Headers", 18, -738)
    objectiveTrackerControls.appearanceCategoryHeaderTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -776, "Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerCategoryHeaderAppearanceOptions().texture end,
        function(value) GetObjectiveTrackerCategoryHeaderAppearanceOptions().texture = value; RefreshObjectiveTrackerOptionsPanel() end,
            "Default Status Bar"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceCategoryHeaderTextureDropdown
    objectiveTrackerControls.appearanceCategoryHeaderColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -776, "Fill Color",
        function()
            local settings = GetObjectiveTrackerCategoryHeaderAppearanceOptions()
            return GetColorValueWithOpacity(settings.color, settings.opacity, { r = 0.08, g = 0.08, b = 0.08, a = 0.8 })
        end,
        function(value)
            local settings = GetObjectiveTrackerCategoryHeaderAppearanceOptions()
            SetTableColorWithOpacity(settings, "color", "opacity", value, { r = 0.08, g = 0.08, b = 0.08, a = 0.8 })
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceCategoryHeaderColorButton
    objectiveTrackerControls.appearanceCategoryHeaderBorderColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, 18, -958, "Border Color",
        function() return GetObjectiveTrackerCategoryHeaderAppearanceOptions().borderColor end,
        function(value) GetObjectiveTrackerCategoryHeaderAppearanceOptions().borderColor = value; RefreshObjectiveTrackerOptionsPanel() end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceCategoryHeaderBorderColorButton
    objectiveTrackerControls.appearanceCategoryHeaderBorderTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -884, "Border Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerCategoryHeaderAppearanceOptions().borderTexture end,
        function(value) GetObjectiveTrackerCategoryHeaderAppearanceOptions().borderTexture = value; RefreshObjectiveTrackerOptionsPanel() end,
        "Global",
        {
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceCategoryHeaderBorderTextureDropdown
    objectiveTrackerControls.appearanceCategoryHeaderBorderSizeSlider = CreateSlider(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -884, "Border Size", APPEARANCE_COLUMN_WIDTH, -10, 10, 1,
        function() return GetObjectiveTrackerCategoryHeaderAppearanceOptions().borderSize or 1 end,
        function(value) GetObjectiveTrackerCategoryHeaderAppearanceOptions().borderSize = value; ScheduleObjectiveTrackerAppearanceSoftRefresh() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceCategoryHeaderBorderSizeSlider

    -- Buttons sub-section
    objectiveTrackerControls.appearanceButtonLabel = CreateSubsectionTitle(objectiveTrackerCards.appearance, "Buttons", 18, -1022)
    objectiveTrackerControls.appearanceButtonTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -1060, "Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerButtonAppearanceOptions().texture end,
        function(value) GetObjectiveTrackerButtonAppearanceOptions().texture = value; RefreshObjectiveTrackerOptionsPanel() end,
            "Default Status Bar"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceButtonTextureDropdown
    objectiveTrackerControls.appearanceButtonColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -1060, "Fill Color",
        function()
            local settings = GetObjectiveTrackerButtonAppearanceOptions()
            return GetColorValueWithOpacity(settings.color, settings.opacity, { r = 0.08, g = 0.08, b = 0.08, a = 0.8 })
        end,
        function(value)
            local settings = GetObjectiveTrackerButtonAppearanceOptions()
            SetTableColorWithOpacity(settings, "color", "opacity", value, { r = 0.08, g = 0.08, b = 0.08, a = 0.8 })
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceButtonColorButton
    objectiveTrackerControls.appearanceButtonBorderColorButton = CreateColorButton(
        objectiveTrackerCards.appearance, 18, -1260, "Border Color",
        function() return GetObjectiveTrackerButtonAppearanceOptions().borderColor end,
        function(value) GetObjectiveTrackerButtonAppearanceOptions().borderColor = value; RefreshObjectiveTrackerOptionsPanel() end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceButtonBorderColorButton
    objectiveTrackerControls.appearanceButtonBorderTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.appearance, 18, -1186, "Border Texture", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerButtonAppearanceOptions().borderTexture end,
        function(value) GetObjectiveTrackerButtonAppearanceOptions().borderTexture = value; RefreshObjectiveTrackerOptionsPanel() end,
        "Global",
        {
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceButtonBorderTextureDropdown
    objectiveTrackerControls.appearanceButtonBorderSizeSlider = CreateSlider(
        objectiveTrackerCards.appearance, APPEARANCE_RIGHT_COLUMN_X, -1186, "Border Size", APPEARANCE_COLUMN_WIDTH, -10, 10, 1,
        function() return GetObjectiveTrackerButtonAppearanceOptions().borderSize or 1 end,
        function(value) GetObjectiveTrackerButtonAppearanceOptions().borderSize = value; ScheduleObjectiveTrackerAppearanceSoftRefresh() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.appearanceButtonBorderSizeSlider

    objectiveTrackerCards.progressBars = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        500,
        "Progress Bars",
        "Bar texture, fill color, border, and a live preview. Only available with the Custom preset."
    )

    objectiveTrackerCards.typography = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        400,
        "Typography",
        "Font face, size, and outline for quest headers, objective text, and progress-bar labels. Display options control extra indicators."
    )

    objectiveTrackerCards.questColors = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        400,
        "Quest Colors",
        "Objective completion colors and per-quest-type title tint overrides."
    )

    objectiveTrackerCards.headerOverrides = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        620,
        "Header Text Overrides",
        "Override font, size, outline, color, and text offset for the main header and category headers."
    )

    objectiveTrackerControls.fontDropdown = CreateFontDropdown(
        objectiveTrackerCards.typography,
        18,
        -82,
        "Font",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetObjectiveTrackerTypographyOptions().font
        end,
        function(value)
            GetObjectiveTrackerTypographyOptions().font = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        "Friz Quadrata TT"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.fontDropdown

    objectiveTrackerControls.fontOutlineDropdown = CreateStaticDropdown(
        objectiveTrackerCards.typography,
        338,
        -82,
        "Font Outline",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(true) or {}
        end,
        function()
            return GetObjectiveTrackerTypographyOptions().fontOutline
        end,
        function(value)
            GetObjectiveTrackerTypographyOptions().fontOutline = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        "Outline"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.fontOutlineDropdown

    objectiveTrackerControls.levelPrefixMode = CreateStaticDropdown(
        objectiveTrackerCards.typography,
        18,
        -156,
        "Quest Level Prefix",
        APPEARANCE_COLUMN_WIDTH,
        OBJECTIVE_TRACKER_LEVEL_PREFIX_CHOICES,
        function()
            return GetObjectiveTrackerLevelPrefixMode()
        end,
        function(value)
            local typography = GetObjectiveTrackerTypographyOptions()
            typography.levelPrefixMode = value
            typography.showLevelPrefix = nil
            RefreshObjectiveTrackerOptionsPanel()
        end,
        "Only Trivial Quests"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.levelPrefixMode

    objectiveTrackerControls.showWarbandCompletedIndicator = CreateCheckbox(
        objectiveTrackerCards.typography,
        "Show Warband Completion Icon",
        338,
        -156,
        function()
            return GetObjectiveTrackerTypographyOptions().showWarbandCompletedIndicator ~= false
        end,
        function(value)
            GetObjectiveTrackerTypographyOptions().showWarbandCompletedIndicator = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.showWarbandCompletedIndicator

    objectiveTrackerControls.showQuestLogCount = CreateCheckbox(
        objectiveTrackerCards.typography,
        "Show Quest Count in Quests Header",
        338,
        -186,
        function()
            return GetObjectiveTrackerTypographyOptions().showQuestLogCount ~= false
        end,
        function(value)
            GetObjectiveTrackerTypographyOptions().showQuestLogCount = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.showQuestLogCount

    objectiveTrackerControls.fontSizeSlider = CreateSlider(
        objectiveTrackerCards.typography,
        18,
        -230,
        "Font Size",
        APPEARANCE_COLUMN_WIDTH,
        10,
        22,
        1,
        function()
            return GetObjectiveTrackerTypographyOptions().fontSize or 13
        end,
        function(value)
            GetObjectiveTrackerTypographyOptions().fontSize = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.fontSizeSlider

    objectiveTrackerControls.typographyDisplayLabel = CreateSubsectionTitle(
        objectiveTrackerCards.typography,
        "Display",
        18,
        -230
    )

    objectiveTrackerControls.questColorsCompletionLabel = CreateSubsectionTitle(
        objectiveTrackerCards.questColors,
        "Completion",
        18,
        -82
    )

    objectiveTrackerControls.questColorsNormalLabel = CreateSubsectionTitle(
        objectiveTrackerCards.questColors,
        "Normal",
        18,
        -194
    )

    objectiveTrackerControls.questColorsSpecialLabel = CreateSubsectionTitle(
        objectiveTrackerCards.questColors,
        "Special",
        18,
        -306
    )

    objectiveTrackerControls.questColorsRepeatingLabel = CreateSubsectionTitle(
        objectiveTrackerCards.questColors,
        "Repeating",
        18,
        -418
    )

    objectiveTrackerControls.questColorsWorldContentLabel = CreateSubsectionTitle(
        objectiveTrackerCards.questColors,
        "World Content",
        18,
        -530
    )

    objectiveTrackerControls.questColorsOtherLabel = CreateSubsectionTitle(
        objectiveTrackerCards.questColors,
        "Other",
        18,
        -642
    )

    objectiveTrackerControls.uncompletedColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        420,
        -230,
        "Uncompleted Color",
        function()
            return GetObjectiveTrackerTypographyOptions().uncompletedColor
        end,
        function(value)
            GetObjectiveTrackerTypographyOptions().uncompletedColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.uncompletedColorButton

    objectiveTrackerControls.completedColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        420,
        -304,
        "Completed Color",
        function()
            return GetObjectiveTrackerTypographyOptions().completedColor
        end,
        function(value)
            GetObjectiveTrackerTypographyOptions().completedColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.completedColorButton

    objectiveTrackerControls.dailyTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        18,
        -304,
        "Daily Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().daily
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().daily = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.dailyTitleColorButton

    objectiveTrackerControls.weeklyTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        220,
        -304,
        "Weekly Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().weekly
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().weekly = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.weeklyTitleColorButton

    objectiveTrackerControls.importantTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        420,
        -304,
        "Important Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().important
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().important = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.importantTitleColorButton

    objectiveTrackerControls.preyTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        18,
        -378,
        "Prey Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().prey
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().prey = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.preyTitleColorButton

    objectiveTrackerControls.campaignTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        220,
        -378,
        "Campaign Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().campaign
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().campaign = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.campaignTitleColorButton

    objectiveTrackerControls.trivialTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        18,
        -378,
        "Trivial Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().trivial
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().trivial = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.trivialTitleColorButton

    objectiveTrackerControls.metaTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        420,
        -378,
        "Meta Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().meta
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().meta = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.metaTitleColorButton

    objectiveTrackerControls.useTrivialTitleColor = CreateCheckbox(
        objectiveTrackerCards.questColors,
        "Use Trivial Quest Title Color",
        220,
        -378,
        function()
            return GetObjectiveTrackerTitleColorOptions().useTrivialColor ~= false
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().useTrivialColor = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.useTrivialTitleColor

    objectiveTrackerControls.questTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        18,
        -452,
        "Regular Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().quest
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().quest = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.questTitleColorButton

    objectiveTrackerControls.worldQuestTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        220,
        -452,
        "World Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().worldQuest
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().worldQuest = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.worldQuestTitleColorButton

    objectiveTrackerControls.bonusObjectiveTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        420,
        -452,
        "Bonus Objective Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().bonusObjective
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().bonusObjective = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.bonusObjectiveTitleColorButton

    objectiveTrackerControls.legendaryTitleColorButton = CreateColorButton(
        objectiveTrackerCards.questColors,
        18,
        -526,
        "Legendary Quest Title",
        function()
            return GetObjectiveTrackerTitleColorOptions().legendary
        end,
        function(value)
            GetObjectiveTrackerTitleColorOptions().legendary = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.legendaryTitleColorButton

    -- Main Header Text overrides
    objectiveTrackerControls.mainHeaderTypographyLabel = CreateSubsectionTitle(objectiveTrackerCards.headerOverrides, "Main Header Text", 18, -82)
    objectiveTrackerControls.mainHeaderOverrideTypographyCheckbox = CreateCheckbox(
        objectiveTrackerCards.headerOverrides,
        "Override font, size & outline",
        18,
        -624,
        function()
            return GetObjectiveTrackerMainHeaderTypographyOptions().overrideTypography == true
        end,
        function(value)
            GetObjectiveTrackerMainHeaderTypographyOptions().overrideTypography = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.mainHeaderOverrideTypographyCheckbox
    objectiveTrackerControls.mainHeaderFontDropdown = CreateFontDropdown(
        objectiveTrackerCards.headerOverrides, 18, -664, "Font", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerMainHeaderTypographyOptions().font end,
        function(value) GetObjectiveTrackerMainHeaderTypographyOptions().font = value; RefreshObjectiveTrackerOptionsPanel() end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.mainHeaderFontDropdown
    objectiveTrackerControls.mainHeaderFontOutlineDropdown = CreateStaticDropdown(
        objectiveTrackerCards.headerOverrides, 338, -664, "Font Outline", APPEARANCE_COLUMN_WIDTH,
        function() return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(true) or {} end,
        function() return GetObjectiveTrackerMainHeaderTypographyOptions().fontOutline end,
        function(value) GetObjectiveTrackerMainHeaderTypographyOptions().fontOutline = value; RefreshObjectiveTrackerOptionsPanel() end,
        "Outline"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.mainHeaderFontOutlineDropdown
    objectiveTrackerControls.mainHeaderFontSizeSlider = CreateSlider(
        objectiveTrackerCards.headerOverrides, 18, -738, "Font Size", APPEARANCE_COLUMN_WIDTH, 8, 28, 1,
        function() return GetObjectiveTrackerMainHeaderTypographyOptions().fontSize or 13 end,
        function(value) GetObjectiveTrackerMainHeaderTypographyOptions().fontSize = value; RefreshObjectiveTrackerOptionsPanel() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.mainHeaderFontSizeSlider
    objectiveTrackerControls.mainHeaderTextColorButton = CreateColorButton(
        objectiveTrackerCards.headerOverrides, 338, -738, "Text Color",
        function() return GetObjectiveTrackerMainHeaderTypographyOptions().textColor end,
        function(value) GetObjectiveTrackerMainHeaderTypographyOptions().textColor = value; RefreshObjectiveTrackerOptionsPanel() end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.mainHeaderTextColorButton
    objectiveTrackerControls.mainHeaderXOffsetSlider = CreateSlider(
        objectiveTrackerCards.headerOverrides, 18, -812, "Text X Offset", APPEARANCE_COLUMN_WIDTH, -100, 100, 1,
        function() return GetObjectiveTrackerMainHeaderTypographyOptions().xOffset or 0 end,
        function(value) GetObjectiveTrackerMainHeaderTypographyOptions().xOffset = value; RefreshObjectiveTrackerOptionsPanel() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.mainHeaderXOffsetSlider
    objectiveTrackerControls.mainHeaderYOffsetSlider = CreateSlider(
        objectiveTrackerCards.headerOverrides, 338, -812, "Text Y Offset", APPEARANCE_COLUMN_WIDTH, -100, 100, 1,
        function() return GetObjectiveTrackerMainHeaderTypographyOptions().yOffset or 0 end,
        function(value) GetObjectiveTrackerMainHeaderTypographyOptions().yOffset = value; RefreshObjectiveTrackerOptionsPanel() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.mainHeaderYOffsetSlider

    -- Category Headers Text overrides
    objectiveTrackerControls.categoryHeaderTypographyLabel = CreateSubsectionTitle(objectiveTrackerCards.headerOverrides, "Category Headers Text", 18, -376)
    objectiveTrackerControls.categoryHeaderOverrideTypographyCheckbox = CreateCheckbox(
        objectiveTrackerCards.headerOverrides,
        "Override font, size & outline",
        18,
        -912,
        function()
            return GetObjectiveTrackerCategoryHeaderTypographyOptions().overrideTypography == true
        end,
        function(value)
            GetObjectiveTrackerCategoryHeaderTypographyOptions().overrideTypography = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.categoryHeaderOverrideTypographyCheckbox
    objectiveTrackerControls.categoryHeaderFontDropdown = CreateFontDropdown(
        objectiveTrackerCards.headerOverrides, 18, -952, "Font", APPEARANCE_COLUMN_WIDTH,
        function() return GetObjectiveTrackerCategoryHeaderTypographyOptions().font end,
        function(value) GetObjectiveTrackerCategoryHeaderTypographyOptions().font = value; RefreshObjectiveTrackerOptionsPanel() end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.categoryHeaderFontDropdown
    objectiveTrackerControls.categoryHeaderFontOutlineDropdown = CreateStaticDropdown(
        objectiveTrackerCards.headerOverrides, 338, -952, "Font Outline", APPEARANCE_COLUMN_WIDTH,
        function() return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(true) or {} end,
        function() return GetObjectiveTrackerCategoryHeaderTypographyOptions().fontOutline end,
        function(value) GetObjectiveTrackerCategoryHeaderTypographyOptions().fontOutline = value; RefreshObjectiveTrackerOptionsPanel() end,
        "Outline"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.categoryHeaderFontOutlineDropdown
    objectiveTrackerControls.categoryHeaderFontSizeSlider = CreateSlider(
        objectiveTrackerCards.headerOverrides, 18, -1026, "Font Size", APPEARANCE_COLUMN_WIDTH, 8, 28, 1,
        function() return GetObjectiveTrackerCategoryHeaderTypographyOptions().fontSize or 13 end,
        function(value) GetObjectiveTrackerCategoryHeaderTypographyOptions().fontSize = value; RefreshObjectiveTrackerOptionsPanel() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.categoryHeaderFontSizeSlider
    objectiveTrackerControls.categoryHeaderTextColorButton = CreateColorButton(
        objectiveTrackerCards.headerOverrides, 338, -1026, "Text Color",
        function() return GetObjectiveTrackerCategoryHeaderTypographyOptions().textColor end,
        function(value) GetObjectiveTrackerCategoryHeaderTypographyOptions().textColor = value; RefreshObjectiveTrackerOptionsPanel() end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.categoryHeaderTextColorButton
    objectiveTrackerControls.categoryHeaderXOffsetSlider = CreateSlider(
        objectiveTrackerCards.headerOverrides, 18, -1100, "Text X Offset", APPEARANCE_COLUMN_WIDTH, -100, 100, 1,
        function() return GetObjectiveTrackerCategoryHeaderTypographyOptions().xOffset or 0 end,
        function(value) GetObjectiveTrackerCategoryHeaderTypographyOptions().xOffset = value; RefreshObjectiveTrackerOptionsPanel() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.categoryHeaderXOffsetSlider
    objectiveTrackerControls.categoryHeaderYOffsetSlider = CreateSlider(
        objectiveTrackerCards.headerOverrides, 338, -1100, "Text Y Offset", APPEARANCE_COLUMN_WIDTH, -100, 100, 1,
        function() return GetObjectiveTrackerCategoryHeaderTypographyOptions().yOffset or 0 end,
        function(value) GetObjectiveTrackerCategoryHeaderTypographyOptions().yOffset = value; RefreshObjectiveTrackerOptionsPanel() end,
        function(value) return FormatSliderValue(value, 0, " px") end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.categoryHeaderYOffsetSlider

    objectiveTrackerCards.scrollBar = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        262,
        "Scrollbar",
        "Disable scrolling entirely, keep the scrollbar visible, or hide the art while still retaining mouse-wheel scrolling."
    )

    objectiveTrackerControls.scrollEnabled = CreateCheckbox(
        objectiveTrackerCards.scrollBar,
        "Enable Scrollbar",
        18,
        -82,
        function()
            return GetObjectiveTrackerScrollBarOptions().enabled ~= false
        end,
        function(value)
            GetObjectiveTrackerScrollBarOptions().enabled = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.scrollEnabled

    objectiveTrackerControls.scrollVisible = CreateCheckbox(
        objectiveTrackerCards.scrollBar,
        "Show Scrollbar",
        18,
        -112,
        function()
            return GetObjectiveTrackerScrollBarOptions().visible ~= false
        end,
        function(value)
            GetObjectiveTrackerScrollBarOptions().visible = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.scrollVisible

    objectiveTrackerControls.scrollTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.scrollBar,
        18,
        -154,
        "Scrollbar Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetObjectiveTrackerScrollBarOptions().texture
        end,
        function(value)
            GetObjectiveTrackerScrollBarOptions().texture = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
            "Default Status Bar"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.scrollTextureDropdown

    objectiveTrackerControls.scrollColorButton = CreateColorButton(
        objectiveTrackerCards.scrollBar,
        338,
        -154,
        "Scrollbar Color",
        function()
            return GetObjectiveTrackerScrollBarOptions().color
        end,
        function(value)
            GetObjectiveTrackerScrollBarOptions().color = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.scrollColorButton

    objectiveTrackerControls.scrollWidthSlider = CreateSlider(
        objectiveTrackerCards.scrollBar,
        18,
        -228,
        "Scrollbar Width",
        APPEARANCE_COLUMN_WIDTH,
        4,
        24,
        1,
        function()
            return GetObjectiveTrackerScrollBarOptions().width or 4
        end,
        function(value)
            GetObjectiveTrackerScrollBarOptions().width = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.scrollWidthSlider

    objectiveTrackerControls.progressTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.progressBars,
        18,
        -1048,
        "Bar Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetObjectiveTrackerProgressBarOptions().texture
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().texture = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
            "Default Status Bar"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressTextureDropdown

    objectiveTrackerControls.progressFillModeDropdown = CreateStaticDropdown(
        objectiveTrackerCards.progressBars,
        APPEARANCE_RIGHT_COLUMN_X,
        -1048,
        "Fill Color Mode",
        APPEARANCE_COLUMN_WIDTH,
        OBJECTIVE_TRACKER_PROGRESS_BAR_FILL_MODE_CHOICES,
        function()
            return GetObjectiveTrackerProgressBarFillMode()
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().fillMode = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        "Based on Progress"
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressFillModeDropdown

    objectiveTrackerControls.progressFillColorButton = CreateColorButton(
        objectiveTrackerCards.progressBars,
        18,
        -1418,
        "Solid Fill Color",
        function()
            return GetObjectiveTrackerProgressBarOptions().fillColor
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().fillColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressFillColorButton

    objectiveTrackerControls.progressBackgroundColorButton = CreateColorButton(
        objectiveTrackerCards.progressBars,
        APPEARANCE_RIGHT_COLUMN_X,
        -1418,
        "Background Color",
        function()
            return GetObjectiveTrackerProgressBarOptions().backgroundColor
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().backgroundColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressBackgroundColorButton

    objectiveTrackerControls.progressLowFillColorButton = CreateColorButton(
        objectiveTrackerCards.progressBars,
        18,
        -1492,
        "Low Progress Color",
        function()
            return GetObjectiveTrackerProgressBarOptions().lowFillColor
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().lowFillColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressLowFillColorButton

    objectiveTrackerControls.progressMediumFillColorButton = CreateColorButton(
        objectiveTrackerCards.progressBars,
        220,
        -1492,
        "Mid Progress Color",
        function()
            return GetObjectiveTrackerProgressBarOptions().mediumFillColor
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().mediumFillColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressMediumFillColorButton

    objectiveTrackerControls.progressHighFillColorButton = CreateColorButton(
        objectiveTrackerCards.progressBars,
        420,
        -1492,
        "High Progress Color",
        function()
            return GetObjectiveTrackerProgressBarOptions().highFillColor
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().highFillColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressHighFillColorButton

    objectiveTrackerControls.progressBorderColorButton = CreateColorButton(
        objectiveTrackerCards.progressBars,
        18,
        -1884,
        "Border Color",
        function()
            return GetObjectiveTrackerProgressBarOptions().borderColor
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().borderColor = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressBorderColorButton

    objectiveTrackerControls.progressBorderTextureDropdown = CreateStatusBarTextureDropdown(
        objectiveTrackerCards.progressBars,
        18,
        -1810,
        "Border Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetObjectiveTrackerProgressBarOptions().borderTexture
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().borderTexture = value
            RefreshObjectiveTrackerOptionsPanel()
        end,
        "Global",
        {
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressBorderTextureDropdown

    objectiveTrackerControls.progressBorderSizeSlider = CreateSlider(
        objectiveTrackerCards.progressBars,
        APPEARANCE_RIGHT_COLUMN_X,
        -1810,
        "Border Size",
        APPEARANCE_COLUMN_WIDTH,
        -10,
        10,
        1,
        function()
            return GetObjectiveTrackerProgressBarOptions().borderSize or 1
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().borderSize = value
            ScheduleObjectiveTrackerAppearanceSoftRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressBorderSizeSlider

    objectiveTrackerControls.progressHideRewardIcon = CreateCheckbox(
        objectiveTrackerCards.progressBars,
        "Hide Reward Icon",
        18,
        -1958,
        function()
            return GetObjectiveTrackerProgressBarOptions().hideRewardIcon == true
        end,
        function(value)
            GetObjectiveTrackerProgressBarOptions().hideRewardIcon = value and true or false
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.progressHideRewardIcon

    do
        local previewPanelWidth = sectionWidth - 36
        local previewPanel = CreateInsetSection(objectiveTrackerCards.progressBars, previewPanelWidth, "Preview")
        previewPanel:SetHeight(120)
        objectiveTrackerControls.progressPreviewPanel = previewPanel

        local previewBarWidth = previewPanelWidth - 32
        local previewBarHeight = 14
        local previewStartY = -44

        local PREVIEW_PERCENTS = { 20, 55, 90 }
        local previewEntries = {}

        for i, pct in ipairs(PREVIEW_PERCENTS) do
            local barY = previewStartY - 10 - (i - 1) * (previewBarHeight + 6)

            local barHolder = CreateFrame("Frame", nil, previewPanel)
            barHolder:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", 16, barY)
            barHolder:SetSize(previewBarWidth, previewBarHeight)
            MarkAutoFitChild(barHolder)

            local bgTex = barHolder:CreateTexture(nil, "BACKGROUND", nil, -1)
            bgTex:SetAllPoints(barHolder)

            local bar = CreateFrame("StatusBar", nil, barHolder)
            bar:SetAllPoints(barHolder)
            bar:SetMinMaxValues(0, 100)
            bar:SetValue(pct)
            bar:SetOrientation("HORIZONTAL")

            local pctLabel = barHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            pctLabel:SetPoint("RIGHT", barHolder, "RIGHT", -4, 0)
            pctLabel:SetText(pct .. "%")
            pctLabel:SetTextColor(1, 1, 1, 0.8)

            local borderFrame = CreateFrame("Frame", nil, barHolder, "BackdropTemplate")
            borderFrame:SetAllPoints(barHolder)
            borderFrame:SetFrameLevel((barHolder:GetFrameLevel() or 0) + 4)

            previewEntries[i] = { holder = barHolder, bar = bar, bgTex = bgTex, borderFrame = borderFrame, pct = pct }
        end
        objectiveTrackerControls.progressPreviewBars = previewEntries

        local function ApplyPreviewBorder(borderFrame, bar, borderSize, color, texturePath)
            local signedSize = NormalizeSignedBorderSize(borderSize, 1)
            local thickness = math.abs(signedSize)
            if thickness == 0 then
                borderFrame:Hide()
                return
            end
            local borderStyle = ResolvePreviewBorderStyle(texturePath, thickness, false)
            local previousBackdropInfo = borderFrame.nomtoolsPreviewBackdropInfo
            local backdropInfo = {
                bgFile = nil,
                tile = false,
                insets = {},
            }
            backdropInfo.edgeFile = borderStyle.edgeFile
            backdropInfo.tile = borderStyle.tile
            backdropInfo.tileSize = borderStyle.tileSize
            backdropInfo.edgeSize = borderStyle.edgeSize
            backdropInfo.insets.left = borderStyle.insets.left
            backdropInfo.insets.right = borderStyle.insets.right
            backdropInfo.insets.top = borderStyle.insets.top
            backdropInfo.insets.bottom = borderStyle.insets.bottom
            borderFrame.nomtoolsPreviewBackdropInfo = backdropInfo
            local layoutPadding = math.max(borderStyle.edgeSize - (borderStyle.baseEdgeSize or borderStyle.edgeSize), 0)
            if signedSize > 0 then
                borderFrame:ClearAllPoints()
                borderFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", -layoutPadding, layoutPadding)
                borderFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", layoutPadding, -layoutPadding)
            elseif signedSize < 0 then
                borderFrame:ClearAllPoints()
                borderFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", layoutPadding, -layoutPadding)
                borderFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -layoutPadding, layoutPadding)
            else
                borderFrame:ClearAllPoints()
                borderFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
                borderFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            end
            if previousBackdropInfo and previousBackdropInfo.edgeFile ~= backdropInfo.edgeFile then
                borderFrame:SetBackdrop(nil)
            end
            borderFrame:SetBackdrop(backdropInfo)
            borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
            borderFrame:Show()
        end

        local progressBarPreviewRefresher = {}
        progressBarPreviewRefresher.Refresh = function(self)
            local opts = GetObjectiveTrackerProgressBarOptions()
            local texturePath = (ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(opts.texture))
                or "Interface\\TargetingFrame\\UI-StatusBar"
            local bgColor      = NormalizeColorValue(opts.backgroundColor, { r = 0, g = 0, b = 0, a = 1 })
            local borderColor  = NormalizeColorValue(opts.borderColor, { r = 0.5, g = 0.5, b = 0.5, a = 1 })
            local borderSize   = NormalizeSignedBorderSize(opts.borderSize, 1)
            local borderTexture = (ns.GetBorderTexturePath and ns.GetBorderTexturePath(opts.borderTexture or opts.texture))
                or texturePath
            local fillMode     = opts.fillMode

            for _, entry in ipairs(previewEntries) do
                entry.bgTex:SetTexture(texturePath)
                entry.bar:SetStatusBarTexture(texturePath)

                local fillColor
                if fillMode ~= "progress" then
                    fillColor = NormalizeColorValue(opts.fillColor, { r = 0, g = 0.6, b = 1, a = 1 })
                else
                    if entry.pct < 33 then
                        fillColor = NormalizeColorValue(opts.lowFillColor, { r = 1, g = 0.2, b = 0, a = 1 })
                    elseif entry.pct < 66 then
                        fillColor = NormalizeColorValue(opts.mediumFillColor, { r = 1, g = 0.8, b = 0, a = 1 })
                    else
                        fillColor = NormalizeColorValue(opts.highFillColor, { r = 0, g = 0.9, b = 0, a = 1 })
                    end
                end
                entry.bar:SetStatusBarColor(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
                entry.bgTex:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)

                ApplyPreviewBorder(entry.borderFrame, entry.bar, borderSize, borderColor, borderTexture)
            end
        end
        objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = progressBarPreviewRefresher
    end

    objectiveTrackerCards.header = CreateSectionCard(
        objectiveTrackerAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        100,
        "Header Bar",
        "Control the main header bar and its components."
    )

    local GetHeaderComponentState
    local HasAnyHeaderComponentsSelected
    local SyncHeaderEnabledToComponentState
    local SetHeaderComponentState
    local HEADER_COMPONENT_CHOICES

    objectiveTrackerControls.headerEnabled = CreateCheckbox(
        objectiveTrackerCards.header,
        "Show Main Header Bar",
        18,
        -142,
        function()
            return HasAnyHeaderComponentsSelected() and GetObjectiveTrackerHeaderOptions().enabled ~= false
        end,
        function(value)
            if value then
                -- Turning on: if no components are selected, enable all of them.
                if not HasAnyHeaderComponentsSelected() then
                    for _, choice in ipairs(HEADER_COMPONENT_CHOICES) do
                        SetHeaderComponentState(choice.key, true)
                    end
                end
                GetObjectiveTrackerHeaderOptions().enabled = true
            else
                -- Turning off: disable all header components.
                for _, choice in ipairs(HEADER_COMPONENT_CHOICES) do
                    SetHeaderComponentState(choice.key, false)
                end
                GetObjectiveTrackerHeaderOptions().enabled = false
            end
            RefreshObjectiveTrackerOptionsPanel()
        end
    )
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.headerEnabled

    HEADER_COMPONENT_CHOICES = {
        { key = "background", name = "Background" },
        { key = "title",      name = "Title" },
        { key = "minimize",   name = "Minimize Button" },
        { key = "trackerTrackAll", name = "Track All Button" },
    }

    GetHeaderComponentState = function(key)
        if key == "background" then
            return GetObjectiveTrackerHeaderOptions().showBackground ~= false
        elseif key == "title" then
            return GetObjectiveTrackerHeaderOptions().showTitle ~= false
        elseif key == "minimize" then
            return GetObjectiveTrackerButtonOptions().minimize ~= false
        elseif key == "trackerTrackAll" then
            return GetObjectiveTrackerButtonOptions().trackerTrackAll ~= false
        end
        return false
    end

    HasAnyHeaderComponentsSelected = function()
        for _, choice in ipairs(HEADER_COMPONENT_CHOICES) do
            if GetHeaderComponentState(choice.key) then
                return true
            end
        end

        return false
    end

    SyncHeaderEnabledToComponentState = function()
        local enabled = HasAnyHeaderComponentsSelected()
        GetObjectiveTrackerHeaderOptions().enabled = enabled and true or false
        return enabled
    end

    SetHeaderComponentState = function(key, value)
        if key == "background" then
            GetObjectiveTrackerHeaderOptions().showBackground = value and true or false
        elseif key == "title" then
            GetObjectiveTrackerHeaderOptions().showTitle = value and true or false
        elseif key == "minimize" then
            GetObjectiveTrackerButtonOptions().minimize = value and true or false
        elseif key == "trackerTrackAll" then
            GetObjectiveTrackerButtonOptions().trackerTrackAll = value and true or false
        end
        SyncHeaderEnabledToComponentState()
    end

    local function GetHeaderComponentsPreviewText()
        local selected = {}
        for _, choice in ipairs(HEADER_COMPONENT_CHOICES) do
            if GetHeaderComponentState(choice.key) then
                selected[#selected + 1] = choice.name
            end
        end
        if #selected == 0 then
            return "None"
        end
        if #selected == #HEADER_COMPONENT_CHOICES then
            return "All"
        end
        return table.concat(selected, ", ")
    end

    objectiveTrackerControls.headerComponentsDropdown = CreateDropdown(
        objectiveTrackerCards.header,
        18,
        -172,
        "Header Components",
        STANDARD_DROPDOWN_WIDTH,
        GetHeaderComponentsPreviewText,
        function()
            local entries = {}
            for _, choice in ipairs(HEADER_COMPONENT_CHOICES) do
                local choiceKey = choice.key
                entries[#entries + 1] = {
                    type = "option",
                    text = choice.name,
                    value = choiceKey,
                    checked = GetHeaderComponentState(choiceKey),
                    isChecked = function() return GetHeaderComponentState(choiceKey) end,
                    onSelect = function(key)
                        SetHeaderComponentState(key, not GetHeaderComponentState(key))
                        RefreshObjectiveTrackerOptionsPanel()
                    end,
                }
            end
            return entries
        end
    )
    objectiveTrackerControls.headerComponentsDropdown.multiSelect = true
    objectiveTrackerControls.headerComponentsDropdown.refreshParentOnSelect = false
    objectiveTrackerAppearancePanel.refreshers[#objectiveTrackerAppearancePanel.refreshers + 1] = objectiveTrackerControls.headerComponentsDropdown

    objectiveTrackerCards.sectionsGeneral = CreateSectionCard(
        objectiveTrackerSectionsContent,
        sectionX,
        -96,
        sectionWidth,
        100,
        "General",
        "Control section-level visibility."
    )

    objectiveTrackerControls.focusedQuestSection = CreateCheckbox(
        objectiveTrackerCards.sectionsGeneral,
        "Show Focused Quest Section",
        18,
        -82,
        function()
            return GetObjectiveTrackerFocusedQuestOptions().enabled ~= false
        end,
        function(value)
            GetObjectiveTrackerFocusedQuestOptions().enabled = value and true or false
            RefreshObjectiveTrackerStructureOptionsPanel()
        end
    )
    objectiveTrackerSectionsPanel.refreshers[#objectiveTrackerSectionsPanel.refreshers + 1] = objectiveTrackerControls.focusedQuestSection

    objectiveTrackerCards.zone = CreateSectionCard(
        objectiveTrackerSectionsContent,
        sectionX,
        -96,
        sectionWidth,
        220,
        "Zone Category",
        "Choose which tracked quest types move into the Zone section when they belong to your current zone. Title colors are configured in Typography so they apply consistently across tracker sections."
    )

    local zoneFilterKeys = ns.GetObjectiveTrackerZoneFilterKeys and ns.GetObjectiveTrackerZoneFilterKeys() or {}
    local filterColumns = 2
    local filterRowHeight = 34
    local filterColumnWidth = math.floor((sectionWidth - 52) / filterColumns)
    local filtersPerColumn = math.max(1, math.ceil(#zoneFilterKeys / filterColumns))
    for index, filterKey in ipairs(zoneFilterKeys) do
        local currentFilterKey = filterKey
        local column = math.floor((index - 1) / filtersPerColumn)
        local row = (index - 1) % filtersPerColumn
        local checkbox = CreateCheckbox(
            objectiveTrackerCards.zone,
            ns.GetObjectiveTrackerZoneFilterLabel and ns.GetObjectiveTrackerZoneFilterLabel(currentFilterKey) or currentFilterKey,
            18 + (column * (filterColumnWidth + 16)),
            -92 - (row * filterRowHeight),
            function()
                local settings = GetObjectiveTrackerOptions()
                return settings and settings.zone and settings.zone[currentFilterKey] == true
            end,
            function(value)
                local settings = GetObjectiveTrackerOptions()
                if settings then
                    settings.zone = settings.zone or {}
                    settings.zone[currentFilterKey] = value and true or false
                    RefreshObjectiveTrackerStructureOptionsPanel()
                end
            end
        )
        if checkbox.label then
            checkbox.label:SetFontObject(GameFontHighlightSmall)
            checkbox.label:SetWidth(filterColumnWidth - 28)
            checkbox.label:SetJustifyH("LEFT")
            checkbox.label:SetJustifyV("MIDDLE")
            checkbox.label:ClearAllPoints()
            checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        end
        objectiveTrackerControls.zoneFilters[#objectiveTrackerControls.zoneFilters + 1] = checkbox
        objectiveTrackerSectionsPanel.refreshers[#objectiveTrackerSectionsPanel.refreshers + 1] = checkbox
    end

    objectiveTrackerCards.order = CreateSectionCard(
        objectiveTrackerSectionsContent,
        sectionX,
        -96,
        sectionWidth,
        436,
        "Category Order",
        "Move tracker sections up or down. Each row owns its own controls so it is clear which category you are reordering."
    )

    objectiveTrackerControls.orderHeaderPosition = CreateInlineHeader(objectiveTrackerCards.order, "Order")
    objectiveTrackerControls.orderHeaderCategory = CreateInlineHeader(objectiveTrackerCards.order, "Category")
    objectiveTrackerControls.orderHeaderMove = CreateInlineHeader(objectiveTrackerCards.order, "Move")

    local function CreateObjectiveTrackerOrderRow(parent)
        local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        row:SetHeight(30)
        row:SetBackdrop(FIELD_BACKDROP)
        row:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.9)
        row:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 0.98)
        MarkAutoFitChild(row)

        row.indexText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.indexText:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.indexText:SetWidth(26)
        row.indexText:SetJustifyH("CENTER")
        row.indexText:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.indexText, "RIGHT", 12, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -138, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetJustifyV("MIDDLE")
        row.label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)

        row.upButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.upButton:SetSize(44, 20)
        row.upButton:SetText("Up")

        row.downButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.downButton:SetSize(56, 20)
        row.downButton:SetText("Down")
        row.downButton:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.upButton:SetPoint("RIGHT", row.downButton, "LEFT", -8, 0)

        row.upButton:SetScript("OnClick", function()
            if row.position and ns.MoveObjectiveTrackerOrderEntry and ns.MoveObjectiveTrackerOrderEntry(row.position, -1) then
                RefreshObjectiveTrackerStructureOptionsPanel()
            end
        end)

        row.downButton:SetScript("OnClick", function()
            if row.position and ns.MoveObjectiveTrackerOrderEntry and ns.MoveObjectiveTrackerOrderEntry(row.position, 1) then
                RefreshObjectiveTrackerStructureOptionsPanel()
            end
        end)

        function row:UpdateRow(position, key, total)
            self.position = position
            self.indexText:SetText(string.format("%d", position or 0))
            self.label:SetText((ns.GetObjectiveTrackerCategoryLabel and ns.GetObjectiveTrackerCategoryLabel(key)) or key or "")
            self.upButton:SetEnabled(position > 1)
            self.downButton:SetEnabled(position < total)
            if position % 2 == 0 then
                self:SetBackdropColor(SURFACE_BG_R - 0.06, SURFACE_BG_G - 0.05, SURFACE_BG_B - 0.04, 0.98)
            else
                self:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 0.98)
            end
        end

        return row
    end

    objectiveTrackerControls.resetOrderButton = CreateButton(objectiveTrackerCards.order, "Reset Order", 18, -92, 110, 22, function()
        if ns.ResetObjectiveTrackerOrder then
            ns.ResetObjectiveTrackerOrder()
            RefreshObjectiveTrackerStructureOptionsPanel()
        end
    end)

    objectiveTrackerPanel.UpdateLayout = function(self)
        objectiveTrackerCards.general:ClearAllPoints()
        objectiveTrackerCards.general:SetPoint("TOPLEFT", objectiveTrackerContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        PositionControl(objectiveTrackerControls.enabled, objectiveTrackerCards.general, 18, -82)
        SetControlEnabled(objectiveTrackerControls.questLogTrackAll, true)
        PositionControl(objectiveTrackerControls.questLogTrackAll, objectiveTrackerCards.general, 18, -112)
        FitSectionCardHeight(objectiveTrackerCards.general, 20)
        FitScrollContentHeight(objectiveTrackerContent, self:GetHeight() - 16, 36)
    end

    objectiveTrackerLayoutPanel.UpdateLayout = function(self)
        local cardSpacing = 20
        local currentY = PAGE_SECTION_START_Y
        objectiveTrackerCards.position:ClearAllPoints()
        objectiveTrackerCards.position:SetPoint("TOPLEFT", objectiveTrackerLayoutContent, "TOPLEFT", sectionX, currentY)
        local layoutOptions = GetObjectiveTrackerLayoutOptions()
        local matchMinimap = layoutOptions.matchMinimapWidth == true
        local attachMinimap = layoutOptions.attachToMinimap == true
        SetControlEnabled(objectiveTrackerControls.generalMatchMinimapWidth, attachMinimap)
        SetControlEnabled(objectiveTrackerControls.generalWidthSlider, not (attachMinimap and matchMinimap))
        SetControlEnabled(objectiveTrackerControls.generalMinimapAttachEdgeDropdown, attachMinimap)
        SetControlEnabled(objectiveTrackerControls.generalMinimapYOffsetSlider, attachMinimap)
        SetControlEnabled(objectiveTrackerControls.generalAnchorPointDropdown, not attachMinimap)
        SetControlEnabled(objectiveTrackerControls.generalPositionXSlider, not attachMinimap)
        SetControlEnabled(objectiveTrackerControls.generalPositionYSlider, not attachMinimap)
        PositionControl(objectiveTrackerControls.generalAnchorPointDropdown, objectiveTrackerCards.position, 18, -82)
        PositionControl(objectiveTrackerControls.generalPositionXSlider, objectiveTrackerCards.position, 18, -156)
        PositionControl(objectiveTrackerControls.generalPositionYSlider, objectiveTrackerCards.position, APPEARANCE_RIGHT_COLUMN_X, -156)
        PositionControl(objectiveTrackerControls.generalWidthSlider, objectiveTrackerCards.position, 18, -230)
        PositionControl(objectiveTrackerControls.generalHeightSlider, objectiveTrackerCards.position, APPEARANCE_RIGHT_COLUMN_X, -230)
        local positionCardHeight = FitSectionCardHeight(objectiveTrackerCards.position, 20)
        currentY = currentY - positionCardHeight - cardSpacing

        objectiveTrackerCards.minimap:ClearAllPoints()
        objectiveTrackerCards.minimap:SetPoint("TOPLEFT", objectiveTrackerLayoutContent, "TOPLEFT", sectionX, currentY)
        PositionControl(objectiveTrackerControls.generalMatchMinimapWidth, objectiveTrackerCards.minimap, 18, -82)
        PositionControl(objectiveTrackerControls.generalAttachToMinimap, objectiveTrackerCards.minimap, 18, -112)
        PositionControl(objectiveTrackerControls.generalMinimapAttachEdgeDropdown, objectiveTrackerCards.minimap, 18, -148)
        PositionControl(objectiveTrackerControls.generalMinimapYOffsetSlider, objectiveTrackerCards.minimap, APPEARANCE_RIGHT_COLUMN_X, -148)
        FitSectionCardHeight(objectiveTrackerCards.minimap, 20)
        FitScrollContentHeight(objectiveTrackerLayoutContent, self:GetHeight() - 16, 36)
    end

    objectiveTrackerAppearancePanel.UpdateLayout = function(self)
        local cardSpacing = 20
        local currentY = PAGE_SECTION_START_Y
        local useNomToolsHeaderAppearance = GetObjectiveTrackerAppearanceOptions().preset == "nomtools"
        local progressFillMode = GetObjectiveTrackerProgressBarFillMode()
        local scrollEnabled = GetObjectiveTrackerScrollBarOptions().enabled ~= false
        local scrollVisible = GetObjectiveTrackerScrollBarOptions().visible ~= false
        local trackerBgEnabled = GetObjectiveTrackerTrackerBackgroundOptions().enabled == true
        local compactColumnLeftX = 18
        local compactColumnMiddleX = 238
        local compactColumnRightX = 458
        local appearanceRightColumnX = APPEARANCE_RIGHT_COLUMN_X

        local function PositionSurfaceTitle(title, y, shown)
            if not title then return end
            title:SetShown(shown ~= false)
            if shown ~= false then
                SetTextBlockPosition(title, objectiveTrackerCards.appearance, 18, y + (objectiveTrackerCards.appearance.nomtoolsContentYOffset or 0))
            end
        end

        local function PositionSurfaceControl(control, x, y, shown)
            SetControlShown(control, shown ~= false)
            if shown ~= false then
                PositionControl(control, objectiveTrackerCards.appearance, x, y)
            end
        end

        local function PositionProgressControl(control, x, y, shown)
            SetControlShown(control, shown ~= false)
            if shown ~= false then
                PositionControl(control, objectiveTrackerCards.progressBars, x, y)
            end
        end

        -- Card 1: Style Preset (always visible)
        objectiveTrackerCards.preset:ClearAllPoints()
        objectiveTrackerCards.preset:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)
        PositionControl(objectiveTrackerControls.appearancePresetDropdown, objectiveTrackerCards.preset, 18, -68)
        local presetCardHeight = FitSectionCardHeight(objectiveTrackerCards.preset, 20)
        currentY = currentY - presetCardHeight - cardSpacing

        -- Card 2: Surface Appearance (Custom preset only)
        objectiveTrackerCards.appearance:ClearAllPoints()
        objectiveTrackerCards.appearance:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)

        if useNomToolsHeaderAppearance then
            objectiveTrackerCards.appearance:SetShown(true)
            SetControlEnabled(objectiveTrackerControls.trackerBgEnabledCheckbox, true)
            SetControlEnabled(objectiveTrackerControls.trackerBgTextureDropdown, trackerBgEnabled)
            SetControlEnabled(objectiveTrackerControls.trackerBgColorButton, trackerBgEnabled)
            SetControlEnabled(objectiveTrackerControls.trackerBgBorderTextureDropdown, trackerBgEnabled)
            SetControlEnabled(objectiveTrackerControls.trackerBgBorderColorButton, trackerBgEnabled)
            SetControlEnabled(objectiveTrackerControls.trackerBgBorderSizeSlider, trackerBgEnabled)
            SetControlEnabled(objectiveTrackerControls.appearanceMainHeaderTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.appearanceMainHeaderColorButton, true)
            SetControlEnabled(objectiveTrackerControls.appearanceMainHeaderBorderTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.appearanceMainHeaderBorderColorButton, true)
            SetControlEnabled(objectiveTrackerControls.appearanceMainHeaderBorderSizeSlider, true)
            SetControlEnabled(objectiveTrackerControls.appearanceCategoryHeaderTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.appearanceCategoryHeaderColorButton, true)
            SetControlEnabled(objectiveTrackerControls.appearanceCategoryHeaderBorderTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.appearanceCategoryHeaderBorderColorButton, true)
            SetControlEnabled(objectiveTrackerControls.appearanceCategoryHeaderBorderSizeSlider, true)
            SetControlEnabled(objectiveTrackerControls.appearanceButtonTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.appearanceButtonColorButton, true)
            SetControlEnabled(objectiveTrackerControls.appearanceButtonBorderTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.appearanceButtonBorderColorButton, true)
            SetControlEnabled(objectiveTrackerControls.appearanceButtonBorderSizeSlider, true)

            local surfaceY = -82

            -- Tracker Background subsection
            PositionSurfaceTitle(objectiveTrackerControls.trackerBgLabel, surfaceY, true)
            PositionSurfaceControl(objectiveTrackerControls.trackerBgEnabledCheckbox, 18, surfaceY - 36, true)

            if trackerBgEnabled then
                PositionSurfaceControl(objectiveTrackerControls.trackerBgTextureDropdown, 18, surfaceY - 76, true)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgColorButton, appearanceRightColumnX, surfaceY - 76, true)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderTextureDropdown, 18, surfaceY - 150, true)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderColorButton, appearanceRightColumnX, surfaceY - 150, true)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderSizeSlider, 18, surfaceY - 224, true)
                surfaceY = surfaceY - 300
            else
                PositionSurfaceControl(objectiveTrackerControls.trackerBgTextureDropdown, 18, 0, false)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgColorButton, 18, 0, false)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderTextureDropdown, 18, 0, false)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderSizeSlider, 18, 0, false)
                PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderColorButton, 18, 0, false)
                surfaceY = surfaceY - 112
            end

            -- Main Header subsection
            PositionSurfaceTitle(objectiveTrackerControls.appearanceMainHeaderLabel, surfaceY, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderTextureDropdown, 18, surfaceY - 38, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderColorButton, appearanceRightColumnX, surfaceY - 38, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderBorderTextureDropdown, 18, surfaceY - 112, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderBorderColorButton, appearanceRightColumnX, surfaceY - 112, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderBorderSizeSlider, 18, surfaceY - 186, true)
            surfaceY = surfaceY - 262

            -- Category Headers subsection
            PositionSurfaceTitle(objectiveTrackerControls.appearanceCategoryHeaderLabel, surfaceY, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderTextureDropdown, 18, surfaceY - 38, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderColorButton, appearanceRightColumnX, surfaceY - 38, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderBorderTextureDropdown, 18, surfaceY - 112, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderBorderColorButton, appearanceRightColumnX, surfaceY - 112, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderBorderSizeSlider, 18, surfaceY - 186, true)
            surfaceY = surfaceY - 262

            -- Buttons subsection
            PositionSurfaceTitle(objectiveTrackerControls.appearanceButtonLabel, surfaceY, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonTextureDropdown, 18, surfaceY - 38, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonColorButton, appearanceRightColumnX, surfaceY - 38, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonBorderTextureDropdown, 18, surfaceY - 112, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonBorderColorButton, appearanceRightColumnX, surfaceY - 112, true)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonBorderSizeSlider, 18, surfaceY - 186, true)

            local appearanceCardHeight = FitSectionCardHeight(objectiveTrackerCards.appearance, 20)
            currentY = currentY - appearanceCardHeight - cardSpacing
        else
            objectiveTrackerCards.appearance:SetShown(false)
            PositionSurfaceTitle(objectiveTrackerControls.trackerBgLabel, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.trackerBgEnabledCheckbox, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.trackerBgTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.trackerBgColorButton, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderSizeSlider, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.trackerBgBorderColorButton, 18, 0, false)
            PositionSurfaceTitle(objectiveTrackerControls.appearanceMainHeaderLabel, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderColorButton, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderBorderTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderBorderSizeSlider, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceMainHeaderBorderColorButton, 18, 0, false)
            PositionSurfaceTitle(objectiveTrackerControls.appearanceCategoryHeaderLabel, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderColorButton, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderBorderTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderBorderSizeSlider, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceCategoryHeaderBorderColorButton, 18, 0, false)
            PositionSurfaceTitle(objectiveTrackerControls.appearanceButtonLabel, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonColorButton, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonBorderTextureDropdown, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonBorderSizeSlider, 18, 0, false)
            PositionSurfaceControl(objectiveTrackerControls.appearanceButtonBorderColorButton, 18, 0, false)
        end

        -- Card 3: Progress Bars (Custom preset only)
        objectiveTrackerCards.progressBars:ClearAllPoints()
        objectiveTrackerCards.progressBars:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)

        if useNomToolsHeaderAppearance then
            objectiveTrackerCards.progressBars:SetShown(true)
            SetControlEnabled(objectiveTrackerControls.progressTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.progressFillModeDropdown, true)
            SetControlEnabled(objectiveTrackerControls.progressBackgroundColorButton, true)
            SetControlEnabled(objectiveTrackerControls.progressHideRewardIcon, true)
            SetControlEnabled(objectiveTrackerControls.progressFillColorButton, progressFillMode == "static")
            SetControlEnabled(objectiveTrackerControls.progressLowFillColorButton, progressFillMode == "progress")
            SetControlEnabled(objectiveTrackerControls.progressMediumFillColorButton, progressFillMode == "progress")
            SetControlEnabled(objectiveTrackerControls.progressHighFillColorButton, progressFillMode == "progress")
            SetControlEnabled(objectiveTrackerControls.progressBorderTextureDropdown, true)
            SetControlEnabled(objectiveTrackerControls.progressBorderColorButton, true)
            SetControlEnabled(objectiveTrackerControls.progressBorderSizeSlider, true)

            local progressY = -82
            PositionProgressControl(objectiveTrackerControls.progressTextureDropdown, 18, progressY, true)
            PositionProgressControl(objectiveTrackerControls.progressFillModeDropdown, appearanceRightColumnX, progressY, true)
            PositionProgressControl(objectiveTrackerControls.progressBackgroundColorButton, appearanceRightColumnX, progressY - 74, true)

            local showStaticFillColor = progressFillMode == "static"
            local showProgressFillColors = progressFillMode == "progress"
            PositionProgressControl(objectiveTrackerControls.progressFillColorButton, 18, progressY - 74, showStaticFillColor)
            PositionProgressControl(objectiveTrackerControls.progressLowFillColorButton, compactColumnLeftX, progressY - 148, showProgressFillColors)
            PositionProgressControl(objectiveTrackerControls.progressMediumFillColorButton, compactColumnMiddleX, progressY - 148, showProgressFillColors)
            PositionProgressControl(objectiveTrackerControls.progressHighFillColorButton, compactColumnRightX, progressY - 148, showProgressFillColors)

            local lastProgressFillY = showProgressFillColors and (progressY - 148) or (progressY - 74)
            local progressPreviewPanelY = lastProgressFillY - 96
            local progressBorderRowY = progressPreviewPanelY - 126

            PositionProgressControl(objectiveTrackerControls.progressBorderTextureDropdown, 18, progressBorderRowY, true)
            PositionProgressControl(objectiveTrackerControls.progressBorderColorButton, appearanceRightColumnX, progressBorderRowY, true)
            PositionProgressControl(objectiveTrackerControls.progressBorderSizeSlider, 18, progressBorderRowY - 74, true)
            PositionProgressControl(objectiveTrackerControls.progressHideRewardIcon, 18, progressBorderRowY - 148, true)

            if objectiveTrackerControls.progressPreviewPanel then
                objectiveTrackerControls.progressPreviewPanel:ClearAllPoints()
                objectiveTrackerControls.progressPreviewPanel:SetPoint("TOPLEFT", objectiveTrackerCards.progressBars, "TOPLEFT", 18, progressPreviewPanelY + (objectiveTrackerCards.progressBars.nomtoolsContentYOffset or 0))
                objectiveTrackerControls.progressPreviewPanel:SetShown(true)
            end

            local progressBarsCardHeight = FitSectionCardHeight(objectiveTrackerCards.progressBars, 20)
            currentY = currentY - progressBarsCardHeight - cardSpacing
        else
            objectiveTrackerCards.progressBars:SetShown(false)
            PositionProgressControl(objectiveTrackerControls.progressTextureDropdown, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressFillModeDropdown, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressFillColorButton, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressBackgroundColorButton, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressLowFillColorButton, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressMediumFillColorButton, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressHighFillColorButton, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressBorderTextureDropdown, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressBorderSizeSlider, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressBorderColorButton, 18, 0, false)
            PositionProgressControl(objectiveTrackerControls.progressHideRewardIcon, 18, 0, false)
            if objectiveTrackerControls.progressPreviewPanel then
                objectiveTrackerControls.progressPreviewPanel:SetShown(false)
            end
        end

        -- Card 4: Typography
        objectiveTrackerCards.typography:ClearAllPoints()
        objectiveTrackerCards.typography:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)
        PositionControl(objectiveTrackerControls.fontDropdown, objectiveTrackerCards.typography, 18, -82)
        PositionControl(objectiveTrackerControls.fontOutlineDropdown, objectiveTrackerCards.typography, appearanceRightColumnX, -82)
        PositionControl(objectiveTrackerControls.fontSizeSlider, objectiveTrackerCards.typography, 18, -156)
        PositionControl(objectiveTrackerControls.typographyDisplayLabel, objectiveTrackerCards.typography, 18, -244)
        PositionControl(objectiveTrackerControls.showWarbandCompletedIndicator, objectiveTrackerCards.typography, 18, -282)
        PositionControl(objectiveTrackerControls.showQuestLogCount, objectiveTrackerCards.typography, appearanceRightColumnX, -282)
        PositionControl(objectiveTrackerControls.levelPrefixMode, objectiveTrackerCards.typography, 18, -322)
        local typographyCardHeight = FitSectionCardHeight(objectiveTrackerCards.typography, 20)
        currentY = currentY - typographyCardHeight - cardSpacing

        -- Card 5: Quest Colors
        objectiveTrackerCards.questColors:ClearAllPoints()
        objectiveTrackerCards.questColors:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)
        local useTrivialTitleColor = GetObjectiveTrackerTitleColorOptions().useTrivialColor ~= false
        PositionControl(objectiveTrackerControls.questColorsCompletionLabel, objectiveTrackerCards.questColors, 18, -82)
        PositionControl(objectiveTrackerControls.uncompletedColorButton, objectiveTrackerCards.questColors, compactColumnLeftX, -120)
        PositionControl(objectiveTrackerControls.completedColorButton, objectiveTrackerCards.questColors, compactColumnMiddleX, -120)

        PositionControl(objectiveTrackerControls.questColorsNormalLabel, objectiveTrackerCards.questColors, 18, -194)
        PositionControl(objectiveTrackerControls.questTitleColorButton, objectiveTrackerCards.questColors, compactColumnLeftX, -232)
        PositionControl(objectiveTrackerControls.campaignTitleColorButton, objectiveTrackerCards.questColors, compactColumnMiddleX, -232)

        PositionControl(objectiveTrackerControls.questColorsSpecialLabel, objectiveTrackerCards.questColors, 18, -306)
        PositionControl(objectiveTrackerControls.importantTitleColorButton, objectiveTrackerCards.questColors, compactColumnLeftX, -344)
        PositionControl(objectiveTrackerControls.metaTitleColorButton, objectiveTrackerCards.questColors, compactColumnMiddleX, -344)
        PositionControl(objectiveTrackerControls.legendaryTitleColorButton, objectiveTrackerCards.questColors, compactColumnRightX, -344)

        PositionControl(objectiveTrackerControls.questColorsRepeatingLabel, objectiveTrackerCards.questColors, 18, -418)
        PositionControl(objectiveTrackerControls.dailyTitleColorButton, objectiveTrackerCards.questColors, compactColumnLeftX, -456)
        PositionControl(objectiveTrackerControls.weeklyTitleColorButton, objectiveTrackerCards.questColors, compactColumnMiddleX, -456)

        PositionControl(objectiveTrackerControls.questColorsWorldContentLabel, objectiveTrackerCards.questColors, 18, -530)
        PositionControl(objectiveTrackerControls.preyTitleColorButton, objectiveTrackerCards.questColors, compactColumnLeftX, -568)
        PositionControl(objectiveTrackerControls.worldQuestTitleColorButton, objectiveTrackerCards.questColors, compactColumnMiddleX, -568)
        PositionControl(objectiveTrackerControls.bonusObjectiveTitleColorButton, objectiveTrackerCards.questColors, compactColumnRightX, -568)

        PositionControl(objectiveTrackerControls.questColorsOtherLabel, objectiveTrackerCards.questColors, 18, -642)
        PositionControl(objectiveTrackerControls.trivialTitleColorButton, objectiveTrackerCards.questColors, compactColumnLeftX, -680)
        SetControlEnabled(objectiveTrackerControls.trivialTitleColorButton, useTrivialTitleColor)
        PositionControl(objectiveTrackerControls.useTrivialTitleColor, objectiveTrackerCards.questColors, compactColumnMiddleX, -680)
        local questColorsCardHeight = FitSectionCardHeight(objectiveTrackerCards.questColors, 20)
        currentY = currentY - questColorsCardHeight - cardSpacing

        -- Card 6: Header Text Overrides
        objectiveTrackerCards.headerOverrides:ClearAllPoints()
        objectiveTrackerCards.headerOverrides:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)
        PositionControl(objectiveTrackerControls.mainHeaderTypographyLabel, objectiveTrackerCards.headerOverrides, 18, -82)
        PositionControl(objectiveTrackerControls.mainHeaderOverrideTypographyCheckbox, objectiveTrackerCards.headerOverrides, 18, -114)
        local useMainHdrOverride = GetObjectiveTrackerMainHeaderTypographyOptions().overrideTypography == true
        PositionControl(objectiveTrackerControls.mainHeaderFontDropdown, objectiveTrackerCards.headerOverrides, 18, -154)
        PositionControl(objectiveTrackerControls.mainHeaderFontOutlineDropdown, objectiveTrackerCards.headerOverrides, appearanceRightColumnX, -154)
        PositionControl(objectiveTrackerControls.mainHeaderFontSizeSlider, objectiveTrackerCards.headerOverrides, 18, -228)
        PositionControl(objectiveTrackerControls.mainHeaderTextColorButton, objectiveTrackerCards.headerOverrides, appearanceRightColumnX, -228)
        PositionControl(objectiveTrackerControls.mainHeaderXOffsetSlider, objectiveTrackerCards.headerOverrides, 18, -302)
        PositionControl(objectiveTrackerControls.mainHeaderYOffsetSlider, objectiveTrackerCards.headerOverrides, appearanceRightColumnX, -302)
        SetControlEnabled(objectiveTrackerControls.mainHeaderFontDropdown, useMainHdrOverride)
        SetControlEnabled(objectiveTrackerControls.mainHeaderFontOutlineDropdown, useMainHdrOverride)
        SetControlEnabled(objectiveTrackerControls.mainHeaderFontSizeSlider, useMainHdrOverride)
        SetControlEnabled(objectiveTrackerControls.mainHeaderTextColorButton, useMainHdrOverride)
        SetControlEnabled(objectiveTrackerControls.mainHeaderXOffsetSlider, useMainHdrOverride)
        SetControlEnabled(objectiveTrackerControls.mainHeaderYOffsetSlider, useMainHdrOverride)
        PositionControl(objectiveTrackerControls.categoryHeaderTypographyLabel, objectiveTrackerCards.headerOverrides, 18, -376)
        PositionControl(objectiveTrackerControls.categoryHeaderOverrideTypographyCheckbox, objectiveTrackerCards.headerOverrides, 18, -408)
        local useCatHdrOverride = GetObjectiveTrackerCategoryHeaderTypographyOptions().overrideTypography == true
        PositionControl(objectiveTrackerControls.categoryHeaderFontDropdown, objectiveTrackerCards.headerOverrides, 18, -448)
        PositionControl(objectiveTrackerControls.categoryHeaderFontOutlineDropdown, objectiveTrackerCards.headerOverrides, appearanceRightColumnX, -448)
        PositionControl(objectiveTrackerControls.categoryHeaderFontSizeSlider, objectiveTrackerCards.headerOverrides, 18, -522)
        PositionControl(objectiveTrackerControls.categoryHeaderTextColorButton, objectiveTrackerCards.headerOverrides, appearanceRightColumnX, -522)
        PositionControl(objectiveTrackerControls.categoryHeaderXOffsetSlider, objectiveTrackerCards.headerOverrides, 18, -596)
        PositionControl(objectiveTrackerControls.categoryHeaderYOffsetSlider, objectiveTrackerCards.headerOverrides, appearanceRightColumnX, -596)
        SetControlEnabled(objectiveTrackerControls.categoryHeaderFontDropdown, useCatHdrOverride)
        SetControlEnabled(objectiveTrackerControls.categoryHeaderFontOutlineDropdown, useCatHdrOverride)
        SetControlEnabled(objectiveTrackerControls.categoryHeaderFontSizeSlider, useCatHdrOverride)
        SetControlEnabled(objectiveTrackerControls.categoryHeaderTextColorButton, useCatHdrOverride)
        SetControlEnabled(objectiveTrackerControls.categoryHeaderXOffsetSlider, useCatHdrOverride)
        SetControlEnabled(objectiveTrackerControls.categoryHeaderYOffsetSlider, useCatHdrOverride)
        local headerOverridesCardHeight = FitSectionCardHeight(objectiveTrackerCards.headerOverrides, 20)
        currentY = currentY - headerOverridesCardHeight - cardSpacing

        -- Card 7: Scrollbar
        objectiveTrackerCards.scrollBar:ClearAllPoints()
        objectiveTrackerCards.scrollBar:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)
        PositionControl(objectiveTrackerControls.scrollEnabled, objectiveTrackerCards.scrollBar, 18, -82)
        PositionControl(objectiveTrackerControls.scrollVisible, objectiveTrackerCards.scrollBar, appearanceRightColumnX, -82)
        PositionControl(objectiveTrackerControls.scrollTextureDropdown, objectiveTrackerCards.scrollBar, 18, -154)
        PositionControl(objectiveTrackerControls.scrollColorButton, objectiveTrackerCards.scrollBar, appearanceRightColumnX, -154)
        PositionControl(objectiveTrackerControls.scrollWidthSlider, objectiveTrackerCards.scrollBar, 18, -228)
        SetControlEnabled(objectiveTrackerControls.scrollVisible, scrollEnabled)
        SetControlEnabled(objectiveTrackerControls.scrollTextureDropdown, scrollEnabled and scrollVisible)
        SetControlEnabled(objectiveTrackerControls.scrollColorButton, scrollEnabled and scrollVisible)
        SetControlEnabled(objectiveTrackerControls.scrollWidthSlider, scrollEnabled and scrollVisible)
        local scrollBarCardHeight = FitSectionCardHeight(objectiveTrackerCards.scrollBar, 20)
        currentY = currentY - scrollBarCardHeight - cardSpacing

        -- Card 8: Header Bar
        objectiveTrackerCards.header:ClearAllPoints()
        objectiveTrackerCards.header:SetPoint("TOPLEFT", objectiveTrackerAppearanceContent, "TOPLEFT", sectionX, currentY)
        local headerEnabled = SyncHeaderEnabledToComponentState()
        SetControlEnabled(objectiveTrackerControls.headerEnabled, true)
        SetControlEnabled(objectiveTrackerControls.headerComponentsDropdown, headerEnabled)
        PositionControl(objectiveTrackerControls.headerEnabled, objectiveTrackerCards.header, 18, -82)
        PositionControl(objectiveTrackerControls.headerComponentsDropdown, objectiveTrackerCards.header, 18, -122)
        local headerBarCardHeight = FitSectionCardHeight(objectiveTrackerCards.header, 20)
        currentY = currentY - headerBarCardHeight - cardSpacing

        FitScrollContentHeight(objectiveTrackerAppearanceContent, self:GetHeight() - 16, 36)
    end

    objectiveTrackerSectionsPanel.UpdateLayout = function(self)
        local cardSpacing = 20
        local currentY = PAGE_SECTION_START_Y
        local currentOrder = ns.GetObjectiveTrackerCategoryOrder and ns.GetObjectiveTrackerCategoryOrder() or {}

        objectiveTrackerCards.sectionsGeneral:ClearAllPoints()
        objectiveTrackerCards.sectionsGeneral:SetPoint("TOPLEFT", objectiveTrackerSectionsContent, "TOPLEFT", sectionX, currentY)
        PositionControl(objectiveTrackerControls.focusedQuestSection, objectiveTrackerCards.sectionsGeneral, 18, -82)
        local sectionsGeneralCardHeight = FitSectionCardHeight(objectiveTrackerCards.sectionsGeneral, 20)
        currentY = currentY - sectionsGeneralCardHeight - cardSpacing

        objectiveTrackerCards.zone:ClearAllPoints()
        objectiveTrackerCards.zone:SetPoint("TOPLEFT", objectiveTrackerSectionsContent, "TOPLEFT", sectionX, currentY)
        local zoneCardHeight = FitSectionCardHeight(objectiveTrackerCards.zone, 20)
        currentY = currentY - zoneCardHeight - cardSpacing

        objectiveTrackerCards.order:ClearAllPoints()
        objectiveTrackerCards.order:SetPoint("TOPLEFT", objectiveTrackerSectionsContent, "TOPLEFT", sectionX, currentY)
        objectiveTrackerControls.orderHeaderPosition:ClearAllPoints()
        objectiveTrackerControls.orderHeaderPosition:SetPoint("TOPLEFT", objectiveTrackerCards.order, "TOPLEFT", 28, -58)
        objectiveTrackerControls.orderHeaderCategory:ClearAllPoints()
        objectiveTrackerControls.orderHeaderCategory:SetPoint("TOPLEFT", objectiveTrackerCards.order, "TOPLEFT", 74, -58)
        objectiveTrackerControls.orderHeaderMove:ClearAllPoints()
        objectiveTrackerControls.orderHeaderMove:SetPoint("TOPRIGHT", objectiveTrackerCards.order, "TOPRIGHT", -100, -58)

        while #objectiveTrackerControls.orderRows < #currentOrder do
            objectiveTrackerControls.orderRows[#objectiveTrackerControls.orderRows + 1] = CreateObjectiveTrackerOrderRow(objectiveTrackerCards.order)
        end

        local rowY = -82
        for index, row in ipairs(objectiveTrackerControls.orderRows) do
            if index <= #currentOrder then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", objectiveTrackerCards.order, "TOPLEFT", 18, rowY)
                row:SetPoint("RIGHT", objectiveTrackerCards.order, "RIGHT", -18, 0)
                row:UpdateRow(index, currentOrder[index], #currentOrder)
                row:Show()
                rowY = rowY - 36
            else
                row:Hide()
            end
        end

        objectiveTrackerControls.resetOrderButton:ClearAllPoints()
        objectiveTrackerControls.resetOrderButton:SetPoint("TOPLEFT", objectiveTrackerCards.order, "TOPLEFT", 18, rowY - 6)
        FitSectionCardHeight(objectiveTrackerCards.order, 20)

        FitScrollContentHeight(objectiveTrackerSectionsContent, self:GetHeight() - 16, 36)
    end

    objectiveTrackerPanel:UpdateLayout()
    objectiveTrackerLayoutPanel:UpdateLayout()
    objectiveTrackerAppearancePanel:UpdateLayout()
    objectiveTrackerSectionsPanel:UpdateLayout()

    end

    do
    local greatVaultContent
    local greatVaultDefaults = ns.DEFAULTS and ns.DEFAULTS.greatVault or { enabled = true }
    local greatVaultPositionDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.greatVault or {
        point = "TOP",
        x = 0,
        y = -220,
    }
    greatVaultPanel, greatVaultContent = CreateModulePage(
        "NomToolsGreatVaultPanel",
        "Great Vault",
        "Loot Spec Reminder",
        "Control the Silvermoon Great Vault reminder. This page previews the frame while it is open, and still supports both mouse placement in Edit Mode and exact per-layout positioning here.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function()
                local s = ns.GetGreatVaultSettings and ns.GetGreatVaultSettings() or nil
                return s and s.enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local s = ns.GetGreatVaultSettings and ns.GetGreatVaultSettings() or nil
                if s then ns.SetModuleEnabled("greatVault", enabled, function(v) s.enabled = v end) end
            end,
            resetHandler = function()
                if not ns.db then
                    return
                end

                local savedGvEnabled = ns.db.greatVault and ns.db.greatVault.enabled
                ns.db.greatVault = CopyTableRecursive(greatVaultDefaults)
                ns.db.greatVault.enabled = savedGvEnabled
                ResetModuleEnabledSetting("greatVault", greatVaultDefaults.enabled, function(enabled)
                    ns.db.greatVault.enabled = enabled and true or false
                end)
                ResetEditModeConfig("greatVault", greatVaultPositionDefaults)
            end,
        }
    )

    local function GetGreatVaultPositionConfig()
        return GetReminderPositionConfig("greatVault", greatVaultPositionDefaults)
    end

    local function RefreshGreatVaultOptionsPanel()
        if ns.RequestRefresh then
            RequestOptionsRefresh("great_vault")
        end
        if greatVaultPanel and greatVaultPanel.RefreshAll then
            greatVaultPanel:RefreshAll()
        end
    end

    local greatVaultCardGeneral = CreateSectionCard(
        greatVaultContent,
        sectionX,
        -96,
        sectionWidth,
        220,
        "General",
        "The reminder appears in The Bazaar in Silvermoon City while you still have an unopened Great Vault reward. Configure visuals in Reminders > Appearance, or use Edit Mode for drag placement."
    )

    local greatVaultPositionCard = CreateSectionCard(
        greatVaultContent,
        sectionX,
        -336,
        sectionWidth,
        256,
        "Position",
        "These controls update the current Blizzard Edit Mode layout with 1 px precision. Use the Open Edit Mode button above when you want to drag the frame instead."
    )

    local greatVaultEnabledCheckbox = CreateCheckbox(
        greatVaultCardGeneral,
        "Enable Great Vault Loot Spec Reminder",
        18,
        -82,
        function()
            local settings = ns.GetGreatVaultSettings and ns.GetGreatVaultSettings() or nil
            return settings and settings.enabled
        end,
        function(value)
            local settings = ns.GetGreatVaultSettings and ns.GetGreatVaultSettings() or nil
            if settings then
                ApplyModuleEnabledSetting("greatVault", value, function(enabled)
                    settings.enabled = enabled and true or false
                end, RefreshGreatVaultOptionsPanel)
            end
        end
    )
    greatVaultPanel.refreshers[#greatVaultPanel.refreshers + 1] = greatVaultEnabledCheckbox

    local greatVaultAnchorDropdown = CreateStaticDropdown(
        greatVaultPositionCard,
        18,
        -82,
        "Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetGreatVaultPositionConfig().point
        end,
        function(value)
            GetGreatVaultPositionConfig().point = NormalizeReminderPointValue(value, greatVaultPositionDefaults.point)
            RefreshGreatVaultOptionsPanel()
        end,
        "Top"
    )
    greatVaultPanel.refreshers[#greatVaultPanel.refreshers + 1] = greatVaultAnchorDropdown

    local greatVaultXSlider = ns.CreateOptionsPositionSlider(
        greatVaultPositionCard,
        18,
        -156,
        "X Position",
        "x",
        function()
            return GetGreatVaultPositionConfig().x
        end,
        function(value)
            GetGreatVaultPositionConfig().x = value
            RefreshGreatVaultOptionsPanel()
        end
    )
    greatVaultPanel.refreshers[#greatVaultPanel.refreshers + 1] = greatVaultXSlider

    local greatVaultYSlider = ns.CreateOptionsPositionSlider(
        greatVaultPositionCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Y Position",
        "y",
        function()
            return GetGreatVaultPositionConfig().y
        end,
        function(value)
            GetGreatVaultPositionConfig().y = value
            RefreshGreatVaultOptionsPanel()
        end
    )
    greatVaultPanel.refreshers[#greatVaultPanel.refreshers + 1] = greatVaultYSlider

    greatVaultPanel.UpdateLayout = function(self)
        local cardSpacing = 20
        local currentY = PAGE_SECTION_START_Y

        greatVaultCardGeneral:ClearAllPoints()
        greatVaultCardGeneral:SetPoint("TOPLEFT", greatVaultContent, "TOPLEFT", sectionX, currentY)
        local generalCardHeight = FitSectionCardHeight(greatVaultCardGeneral, 20)
        currentY = currentY - generalCardHeight - cardSpacing

        greatVaultPositionCard:ClearAllPoints()
        greatVaultPositionCard:SetPoint("TOPLEFT", greatVaultContent, "TOPLEFT", sectionX, currentY)
        PositionControl(greatVaultAnchorDropdown, greatVaultPositionCard, 18, -82)
        PositionControl(greatVaultXSlider, greatVaultPositionCard, 18, -156)
        PositionControl(greatVaultYSlider, greatVaultPositionCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        FitSectionCardHeight(greatVaultPositionCard, 20)
        FitScrollContentHeight(greatVaultContent, greatVaultPanel:GetHeight() - 16, 36)
    end

    greatVaultPanel:UpdateLayout()

    end

    do
    local remindersGeneralContent
    local remindersDefaults = ns.DEFAULTS and ns.DEFAULTS.reminders or { enabled = false }

    local function GetRemindersModuleSettings()
        return ns.GetRemindersSettings and ns.GetRemindersSettings() or remindersDefaults
    end

    local function IsRemindersModuleEnabled()
        local settings = GetRemindersModuleSettings()
        return settings and settings.enabled == true or false
    end

    remindersGeneralPanel, remindersGeneralContent = CreateModulePage(
        "NomToolsRemindersGeneralPanel",
        "Reminders",
        "General",
        "Control whether the Reminders addon is enabled before configuring individual reminders.",
        {
            moduleEnabledGetter = function()
                return IsRemindersModuleEnabled()
            end,
            moduleEnabledSetter = function(enabled)
                local settings = GetRemindersModuleSettings()
                ApplyModuleEnabledSetting("reminders", enabled, function(value)
                    settings.enabled = value and true or false
                end, ns.RequestRefresh, { forceReloadPrompt = true })
            end,
            resetHandler = function()
                if not ns.db then return end
                ns.db.reminders = ns.db.reminders or {}
                ResetModuleEnabledSetting("reminders", remindersDefaults.enabled, function(enabled)
                    ns.db.reminders.enabled = enabled and true or false
                end)
            end,
        }
    )

    local remindersGeneralCard = CreateSectionCard(
        remindersGeneralContent,
        sectionX,
        -96,
        sectionWidth,
        172,
        "General",
        "Enable or disable all reminder modules here. Individual reminders can each be configured in their own pages below."
    )

    local remindersEnabledCheckbox = CreateCheckbox(
        remindersGeneralCard,
        "Enable Reminders Module",
        18,
        -82,
        function()
            return IsRemindersModuleEnabled()
        end,
        function(value)
            local settings = GetRemindersModuleSettings()
            ApplyModuleEnabledSetting("reminders", value, function(enabled)
                settings.enabled = enabled and true or false
            end, ns.RequestRefresh, { forceReloadPrompt = true })
        end
    )
    remindersGeneralPanel.refreshers[#remindersGeneralPanel.refreshers + 1] = remindersEnabledCheckbox

    remindersGeneralPanel.UpdateLayout = function(self)
        remindersGeneralCard:ClearAllPoints()
        remindersGeneralCard:SetPoint("TOPLEFT", remindersGeneralContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        PositionControl(remindersEnabledCheckbox, remindersGeneralCard, 18, -82)
        FitSectionCardHeight(remindersGeneralCard, 20)
        FitScrollContentHeight(remindersGeneralContent, self:GetHeight() - 16, 36)
    end

    remindersGeneralPanel:UpdateLayout()
    end

    do
    local remindersAppearanceContent
    local remindersDefaults = ns.DEFAULTS and ns.DEFAULTS.reminders or { enabled = false }

    local function GetRemindersModuleSettings()
        return ns.GetRemindersSettings and ns.GetRemindersSettings() or remindersDefaults
    end

    local function IsRemindersModuleEnabled()
        local settings = GetRemindersModuleSettings()
        return settings and settings.enabled == true or false
    end

    local function GetRemindersAppearanceState()
        return GetReminderAppearanceState(ns.GetRemindersSettings, ns.DEFAULTS and ns.DEFAULTS.reminders or {})
    end

    local function GetRemindersAppearanceProfile()
        local _, _, profile = GetRemindersAppearanceState()
        return profile
    end

    local function GetRemindersNomToolsAppearanceProfile()
        local _, appearance = GetRemindersAppearanceState()
        return appearance.nomtools
    end

    local function RefreshRemindersAppearanceOptionsPanel()
        if ns.RequestRefresh then
            RequestOptionsRefresh("reminders_appearance")
        end
        if remindersAppearancePanel and remindersAppearancePanel.RefreshAll then
            remindersAppearancePanel:RefreshAll()
        end
    end

    remindersAppearancePanel, remindersAppearanceContent = CreateModulePage(
        "NomToolsRemindersAppearancePanel",
        "Reminders",
        "Appearance",
        "Shared appearance settings for all reminder modules. These settings apply to Dungeon Difficulty, Great Vault, and Talent Loadout reminders.",
        {
            moduleEnabledGetter = function()
                return IsRemindersModuleEnabled()
            end,
            moduleEnabledSetter = function(enabled)
                local settings = GetRemindersModuleSettings()
                ApplyModuleEnabledSetting("reminders", enabled, function(value)
                    settings.enabled = value and true or false
                end, ns.RequestRefresh, { forceReloadPrompt = true })
            end,
            resetHandler = function()
                if not ns.db then return end
                ns.db.reminders = ns.db.reminders or {}
                ns.db.reminders.appearance = CopyTableRecursive(remindersDefaults.appearance or {})
                if ns.RequestRefresh then
                    RequestOptionsRefresh("reminders_appearance")
                end
            end,
        }
    )

    local remindersAppearanceCard = CreateSectionCard(
        remindersAppearanceContent,
        sectionX,
        -96,
        sectionWidth,
        724,
        "Appearance",
        "Each preset keeps its own font sizes and colors for the visible title, primary, and hint text. The Custom preset additionally exposes texture, border, accent, and background controls."
    )

    local remindersAppearancePresetDropdown = CreateStaticDropdown(
        remindersAppearanceCard,
        18,
        -82,
        "Preset",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_PRESET_CHOICES,
        function()
            local _, appearance = GetRemindersAppearanceState()
            return appearance.preset
        end,
        function(value)
            local _, appearance = GetRemindersAppearanceState()
            appearance.preset = NormalizeReminderPresetValue(value, "blizzard")
            RefreshRemindersAppearanceOptionsPanel()
        end,
            "Default"
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearancePresetDropdown

    local remindersAppearanceFontDropdown = CreateFontDropdown(
        remindersAppearanceCard,
        18,
        -156,
        "Font",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetRemindersAppearanceProfile().font
        end,
        function(value)
            GetRemindersAppearanceProfile().font = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        "Friz Quadrata TT"
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceFontDropdown

    local remindersAppearanceFontOutlineDropdown = CreateStaticDropdown(
        remindersAppearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Font Outline",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(true) or {}
        end,
        function()
            return GetRemindersAppearanceProfile().fontOutline
        end,
        function(value)
            GetRemindersAppearanceProfile().fontOutline = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        "Outline"
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceFontOutlineDropdown

    local remindersAppearanceTitleFontSizeSlider = CreateSlider(
        remindersAppearanceCard,
        18,
        -230,
        "Title Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        30,
        1,
        function()
            return GetRemindersAppearanceProfile().titleFontSize
        end,
        function(value)
            GetRemindersAppearanceProfile().titleFontSize = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceTitleFontSizeSlider

    local remindersAppearancePrimaryFontSizeSlider = CreateSlider(
        remindersAppearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -230,
        "Primary Text Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        30,
        1,
        function()
            return GetRemindersAppearanceProfile().primaryFontSize
        end,
        function(value)
            GetRemindersAppearanceProfile().primaryFontSize = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearancePrimaryFontSizeSlider

    local remindersAppearanceHintFontSizeSlider = CreateSlider(
        remindersAppearanceCard,
        18,
        -304,
        "Hint Text Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        30,
        1,
        function()
            return GetRemindersAppearanceProfile().hintFontSize
        end,
        function(value)
            GetRemindersAppearanceProfile().hintFontSize = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceHintFontSizeSlider

    local remindersAppearanceTitleColorButton = CreateColorButton(
        remindersAppearanceCard,
        18,
        -378,
        "Title Color",
        function()
            return GetRemindersAppearanceProfile().titleColor
        end,
        function(value)
            GetRemindersAppearanceProfile().titleColor = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        { hasOpacity = false, width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceTitleColorButton

    local remindersAppearancePrimaryColorButton = CreateColorButton(
        remindersAppearanceCard,
        238,
        -378,
        "Primary Text Color",
        function()
            return GetRemindersAppearanceProfile().primaryColor
        end,
        function(value)
            GetRemindersAppearanceProfile().primaryColor = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        { hasOpacity = false, width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearancePrimaryColorButton

    local remindersAppearanceHintColorButton = CreateColorButton(
        remindersAppearanceCard,
        458,
        -378,
        "Hint Text Color",
        function()
            return GetRemindersAppearanceProfile().hintColor
        end,
        function(value)
            GetRemindersAppearanceProfile().hintColor = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        { hasOpacity = false, width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceHintColorButton

    local remindersAppearanceTextureDropdown = CreateStatusBarTextureDropdown(
        remindersAppearanceCard,
        18,
        -452,
        "Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetRemindersNomToolsAppearanceProfile().texture
        end,
        function(value)
            GetRemindersNomToolsAppearanceProfile().texture = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
            "Default Status Bar"
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceTextureDropdown

    local remindersAppearanceBorderTextureDropdown = CreateStatusBarTextureDropdown(
        remindersAppearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -452,
        "Border Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return GetRemindersNomToolsAppearanceProfile().borderTexture
        end,
        function(value)
            GetRemindersNomToolsAppearanceProfile().borderTexture = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        "Global",
        {
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceBorderTextureDropdown

    local remindersAppearanceShowAccentCheckbox = CreateCheckbox(
        remindersAppearanceCard,
        "Show Accent Bar",
        18,
        -526,
        function()
            return GetRemindersNomToolsAppearanceProfile().showAccent ~= false
        end,
        function(value)
            GetRemindersNomToolsAppearanceProfile().showAccent = value and true or false
            RefreshRemindersAppearanceOptionsPanel()
        end
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceShowAccentCheckbox

    local remindersAppearanceAccentColorButton = CreateColorButton(
        remindersAppearanceCard,
        18,
        -600,
        "Accent Color",
        function()
            return GetRemindersNomToolsAppearanceProfile().accentColor
        end,
        function(value)
            GetRemindersNomToolsAppearanceProfile().accentColor = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceAccentColorButton

    local remindersAppearanceBackgroundColorButton = CreateColorButton(
        remindersAppearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -600,
        "Background Color",
        function()
            local profile = GetRemindersNomToolsAppearanceProfile()
            return GetColorValueWithOpacity(profile.backgroundColor, profile.opacity, { r = 0, g = 0, b = 0, a = 0.8 })
        end,
        function(value)
            local profile = GetRemindersNomToolsAppearanceProfile()
            SetTableColorWithOpacity(profile, "backgroundColor", "opacity", value, { r = 0, g = 0, b = 0, a = 0.8 })
            RefreshRemindersAppearanceOptionsPanel()
        end,
        { width = APPEARANCE_COLUMN_WIDTH }
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceBackgroundColorButton

    local remindersAppearanceBorderColorButton = CreateColorButton(
        remindersAppearanceCard,
        18,
        -674,
        "Border Color",
        function()
            return GetRemindersNomToolsAppearanceProfile().borderColor
        end,
        function(value)
            GetRemindersNomToolsAppearanceProfile().borderColor = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceBorderColorButton

    local remindersAppearanceBorderSizeSlider = CreateSlider(
        remindersAppearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -674,
        "Border Size",
        APPEARANCE_COLUMN_WIDTH,
        -10,
        10,
        1,
        function()
            return GetRemindersNomToolsAppearanceProfile().borderSize or 1
        end,
        function(value)
            GetRemindersNomToolsAppearanceProfile().borderSize = value
            RefreshRemindersAppearanceOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    remindersAppearancePanel.refreshers[#remindersAppearancePanel.refreshers + 1] = remindersAppearanceBorderSizeSlider

    remindersAppearancePanel.UpdateLayout = function(self)
        local _, appearance = GetRemindersAppearanceState()
        local useNomToolsAppearance = appearance.preset == "nomtools"
        local showAccent = useNomToolsAppearance and GetRemindersNomToolsAppearanceProfile().showAccent ~= false

        remindersAppearanceCard:ClearAllPoints()
        remindersAppearanceCard:SetPoint("TOPLEFT", remindersAppearanceContent, "TOPLEFT", sectionX, PAGE_SECTION_START_Y)
        PositionControl(remindersAppearancePresetDropdown, remindersAppearanceCard, 18, -82)
        PositionControl(remindersAppearanceFontDropdown, remindersAppearanceCard, 18, -156)
        PositionControl(remindersAppearanceFontOutlineDropdown, remindersAppearanceCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        PositionControl(remindersAppearanceTitleFontSizeSlider, remindersAppearanceCard, 18, -230)
        PositionControl(remindersAppearancePrimaryFontSizeSlider, remindersAppearanceCard, APPEARANCE_RIGHT_COLUMN_X, -230)
        PositionControl(remindersAppearanceHintFontSizeSlider, remindersAppearanceCard, 18, -304)
        PositionControl(remindersAppearanceTitleColorButton, remindersAppearanceCard, 18, -378)
        PositionControl(remindersAppearancePrimaryColorButton, remindersAppearanceCard, 238, -378)
        PositionControl(remindersAppearanceHintColorButton, remindersAppearanceCard, 458, -378)
        PositionControl(remindersAppearanceTextureDropdown, remindersAppearanceCard, 18, -452)
        PositionControl(remindersAppearanceBorderTextureDropdown, remindersAppearanceCard, APPEARANCE_RIGHT_COLUMN_X, -452)
        PositionControl(remindersAppearanceShowAccentCheckbox, remindersAppearanceCard, 18, -526)
        PositionControl(remindersAppearanceAccentColorButton, remindersAppearanceCard, 18, -600)
        PositionControl(remindersAppearanceBackgroundColorButton, remindersAppearanceCard, APPEARANCE_RIGHT_COLUMN_X, -600)
        PositionControl(remindersAppearanceBorderColorButton, remindersAppearanceCard, 18, -674)
        PositionControl(remindersAppearanceBorderSizeSlider, remindersAppearanceCard, APPEARANCE_RIGHT_COLUMN_X, -674)
        SetControlEnabled(remindersAppearanceTextureDropdown, useNomToolsAppearance)
        SetControlEnabled(remindersAppearanceBorderTextureDropdown, useNomToolsAppearance)
        SetControlEnabled(remindersAppearanceShowAccentCheckbox, useNomToolsAppearance)
        SetControlEnabled(remindersAppearanceAccentColorButton, showAccent)
        SetControlEnabled(remindersAppearanceBackgroundColorButton, useNomToolsAppearance)
        SetControlEnabled(remindersAppearanceBorderColorButton, useNomToolsAppearance)
        SetControlEnabled(remindersAppearanceBorderSizeSlider, useNomToolsAppearance)
        FitSectionCardHeight(remindersAppearanceCard, 20)
        FitScrollContentHeight(remindersAppearanceContent, self:GetHeight() - 16, 36)
    end

    remindersAppearancePanel:UpdateLayout()
    end

    do
    local dungeonDifficultyContent
    local dungeonDifficultyDefaults = ns.DEFAULTS and ns.DEFAULTS.dungeonDifficulty or { enabled = true }
    local dungeonDifficultyPositionDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.dungeonDifficulty or {
        point = "TOP",
        x = 0,
        y = -324,
    }
    dungeonDifficultyPanel, dungeonDifficultyContent = CreateModulePage(
        "NomToolsDungeonDifficultyPanel",
        "Dungeon Difficulty",
        "Mythic Reminder",
        "Control the reminder that appears when your premade 5-player party is set to a non-Mythic dungeon difficulty. This page previews the frame while it is open, and still supports both mouse placement in Edit Mode and exact per-layout positioning here.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function()
                local s = ns.GetDungeonDifficultySettings and ns.GetDungeonDifficultySettings() or nil
                return s and s.enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local s = ns.GetDungeonDifficultySettings and ns.GetDungeonDifficultySettings() or nil
                if s then ns.SetModuleEnabled("dungeonDifficulty", enabled, function(v) s.enabled = v end) end
            end,
            resetHandler = function()
                if not ns.db then
                    return
                end

                local savedDdEnabled = ns.db.dungeonDifficulty and ns.db.dungeonDifficulty.enabled
                ns.db.dungeonDifficulty = CopyTableRecursive(dungeonDifficultyDefaults)
                ns.db.dungeonDifficulty.enabled = savedDdEnabled
                ResetModuleEnabledSetting("dungeonDifficulty", dungeonDifficultyDefaults.enabled, function(enabled)
                    ns.db.dungeonDifficulty.enabled = enabled and true or false
                end)
                ResetEditModeConfig("dungeonDifficulty", dungeonDifficultyPositionDefaults)
            end,
        }
    )

    local function GetDungeonDifficultyPositionConfig()
        return GetReminderPositionConfig("dungeonDifficulty", dungeonDifficultyPositionDefaults)
    end

    local function RefreshDungeonDifficultyOptionsPanel()
        if ns.RequestRefresh then
            RequestOptionsRefresh("dungeon_difficulty")
        end
        if dungeonDifficultyPanel and dungeonDifficultyPanel.RefreshAll then
            dungeonDifficultyPanel:RefreshAll()
        end
    end

    local dungeonDifficultyCardGeneral = CreateSectionCard(
        dungeonDifficultyContent,
        sectionX,
        -96,
        sectionWidth,
        220,
        "General",
        "The reminder appears when you are in a full 5-player party and your party dungeon difficulty is not Mythic. Configure visuals in Reminders > Appearance, or use Edit Mode for drag placement."
    )

    local dungeonDifficultyPositionCard = CreateSectionCard(
        dungeonDifficultyContent,
        sectionX,
        -336,
        sectionWidth,
        256,
        "Position",
        "These controls update the current Blizzard Edit Mode layout with 1 px precision. Use the Open Edit Mode button above when you want to drag the frame instead."
    )

    local dungeonDifficultyEnabledCheckbox = CreateCheckbox(
        dungeonDifficultyCardGeneral,
        "Enable Dungeon Difficulty Reminder",
        18,
        -82,
        function()
            local settings = ns.GetDungeonDifficultySettings and ns.GetDungeonDifficultySettings() or nil
            return settings and settings.enabled
        end,
        function(value)
            local settings = ns.GetDungeonDifficultySettings and ns.GetDungeonDifficultySettings() or nil
            if settings then
                ApplyModuleEnabledSetting("dungeonDifficulty", value, function(enabled)
                    settings.enabled = enabled and true or false
                end, RefreshDungeonDifficultyOptionsPanel)
            end
        end
    )
    dungeonDifficultyPanel.refreshers[#dungeonDifficultyPanel.refreshers + 1] = dungeonDifficultyEnabledCheckbox

    local dungeonDifficultyAnchorDropdown = CreateStaticDropdown(
        dungeonDifficultyPositionCard,
        18,
        -82,
        "Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetDungeonDifficultyPositionConfig().point
        end,
        function(value)
            GetDungeonDifficultyPositionConfig().point = NormalizeReminderPointValue(value, dungeonDifficultyPositionDefaults.point)
            RefreshDungeonDifficultyOptionsPanel()
        end,
        "Top"
    )
    dungeonDifficultyPanel.refreshers[#dungeonDifficultyPanel.refreshers + 1] = dungeonDifficultyAnchorDropdown

    local dungeonDifficultyXSlider = ns.CreateOptionsPositionSlider(
        dungeonDifficultyPositionCard,
        18,
        -156,
        "X Position",
        "x",
        function()
            return GetDungeonDifficultyPositionConfig().x
        end,
        function(value)
            GetDungeonDifficultyPositionConfig().x = value
            RefreshDungeonDifficultyOptionsPanel()
        end
    )
    dungeonDifficultyPanel.refreshers[#dungeonDifficultyPanel.refreshers + 1] = dungeonDifficultyXSlider

    local dungeonDifficultyYSlider = ns.CreateOptionsPositionSlider(
        dungeonDifficultyPositionCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Y Position",
        "y",
        function()
            return GetDungeonDifficultyPositionConfig().y
        end,
        function(value)
            GetDungeonDifficultyPositionConfig().y = value
            RefreshDungeonDifficultyOptionsPanel()
        end
    )
    dungeonDifficultyPanel.refreshers[#dungeonDifficultyPanel.refreshers + 1] = dungeonDifficultyYSlider

    dungeonDifficultyPanel.UpdateLayout = function(self)
        local cardSpacing = 20
        local currentY = PAGE_SECTION_START_Y

        dungeonDifficultyCardGeneral:ClearAllPoints()
        dungeonDifficultyCardGeneral:SetPoint("TOPLEFT", dungeonDifficultyContent, "TOPLEFT", sectionX, currentY)
        local generalCardHeight = FitSectionCardHeight(dungeonDifficultyCardGeneral, 20)
        currentY = currentY - generalCardHeight - cardSpacing

        dungeonDifficultyPositionCard:ClearAllPoints()
        dungeonDifficultyPositionCard:SetPoint("TOPLEFT", dungeonDifficultyContent, "TOPLEFT", sectionX, currentY)
        PositionControl(dungeonDifficultyAnchorDropdown, dungeonDifficultyPositionCard, 18, -82)
        PositionControl(dungeonDifficultyXSlider, dungeonDifficultyPositionCard, 18, -156)
        PositionControl(dungeonDifficultyYSlider, dungeonDifficultyPositionCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        FitSectionCardHeight(dungeonDifficultyPositionCard, 20)
        FitScrollContentHeight(dungeonDifficultyContent, dungeonDifficultyPanel:GetHeight() - 16, 36)
    end

    dungeonDifficultyPanel:UpdateLayout()

    end

    do
    local talentLoadoutContent
    local talentLoadoutDefaults = ns.DEFAULTS and ns.DEFAULTS.talentLoadout or { enabled = false }
    local talentLoadoutPositionDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.talentLoadout or {
        point = "TOP",
        x = 0,
        y = -428,
    }
    talentLoadoutPanel, talentLoadoutContent = CreateModulePage(
        "NomToolsTalentLoadoutPanel",
        "Talent Loadout",
        "Loadout Reminder",
        "Control the reminder that appears when you enter a dungeon or raid, allowing you to verify and switch your talent loadout. This page previews the frame while it is open, and supports both mouse placement in Edit Mode and exact per-layout positioning here.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function()
                local s = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
                return s and s.enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local s = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
                if s then ns.SetModuleEnabled("talentLoadout", enabled, function(v) s.enabled = v end) end
            end,
            resetHandler = function()
                if not ns.db then
                    return
                end

                local savedEnabled = ns.db.talentLoadout and ns.db.talentLoadout.enabled
                local savedDungeonPreferences = ns.db.talentLoadout and ns.db.talentLoadout.dungeonPreferences
                ns.db.talentLoadout = CopyTableRecursive(talentLoadoutDefaults)
                ns.db.talentLoadout.enabled = savedEnabled
                ns.db.talentLoadout.dungeonPreferences = savedDungeonPreferences
                ResetModuleEnabledSetting("talentLoadout", talentLoadoutDefaults.enabled, function(enabled)
                    ns.db.talentLoadout.enabled = enabled and true or false
                end)
                ResetEditModeConfig("talentLoadout", talentLoadoutPositionDefaults)
            end,
        }
    )

    local function GetTalentLoadoutPositionConfig()
        return GetReminderPositionConfig("talentLoadout", talentLoadoutPositionDefaults)
    end

    local function RefreshTalentLoadoutOptionsPanel()
        if ns.RequestRefresh then
            RequestOptionsRefresh("talent_loadout")
        end
        if talentLoadoutPanel and talentLoadoutPanel.RefreshAll then
            talentLoadoutPanel:RefreshAll()
        end
    end

    local function GetTalentLoadoutFilterLabel(filterKey)
        local filters = ns.INSTANCE_FILTERS or {}
        for _, filter in ipairs(filters) do
            if filter.key == filterKey then
                return filter.name
            end
        end
        return filterKey
    end

    local function GetTalentLoadoutFilterPreviewText(filterKeys)
        local s = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
        local enabledFilters = s and s.enabledFilters or {}
        local selected = {}
        for _, filterKey in ipairs(filterKeys or {}) do
            if enabledFilters[filterKey] then
                selected[#selected + 1] = GetTalentLoadoutFilterLabel(filterKey)
            end
        end
        if #selected == 0 then return "None" end
        if #selected == #filterKeys then return "All" end
        return table.concat(selected, ", ")
    end

    local function GetDungeonPreference(dungeonName)
        if not ns.db or type(ns.db.talentLoadout) ~= "table" then return 0 end
        local prefs = ns.db.talentLoadout.dungeonPreferences
        return (type(prefs) == "table" and prefs[dungeonName]) or 0
    end

    local function SetDungeonPreference(dungeonName, configID)
        if not ns.db then return end
        if type(ns.db.talentLoadout) ~= "table" then ns.db.talentLoadout = {} end
        if type(ns.db.talentLoadout.dungeonPreferences) ~= "table" then
            ns.db.talentLoadout.dungeonPreferences = {}
        end
        if not configID or configID == 0 then
            ns.db.talentLoadout.dungeonPreferences[dungeonName] = nil
        else
            ns.db.talentLoadout.dungeonPreferences[dungeonName] = configID
        end
    end

    local talentLoadoutCardGeneral = CreateSectionCard(
        talentLoadoutContent,
        sectionX,
        -96,
        sectionWidth,
        220,
        "General",
        "The reminder activates when you enter an instance matching the filters in the Show In section. Configure visuals in Reminders > Appearance, and use Position here for placement."
    )

    local talentLoadoutCardShowIn = CreateSectionCard(
        talentLoadoutContent,
        sectionX,
        -336,
        sectionWidth,
        240,
        "Show In",
        "Choose which instance types trigger the reminder. Each dropdown selects one category."
    )

    local talentLoadoutPreferredCard = CreateSectionCard(
        talentLoadoutContent,
        sectionX,
        -596,
        sectionWidth,
        400,
        "Preferred Loadouts",
        "Assign a preferred talent loadout to each current-season Mythic+ dungeon. When enabled, the reminder is suppressed if you are already on that loadout for that dungeon."
    )

    local talentLoadoutPositionCard = CreateSectionCard(
        talentLoadoutContent,
        sectionX,
        -856,
        sectionWidth,
        256,
        "Position",
        "These controls update the current Blizzard Edit Mode layout with 1 px precision. Use the Open Edit Mode button above when you want to drag the frame instead."
    )

    local talentLoadoutEnabledCheckbox = CreateCheckbox(
        talentLoadoutCardGeneral,
        "Enable Talent Loadout Reminder",
        18,
        -82,
        function()
            local settings = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
            return settings and settings.enabled
        end,
        function(value)
            local settings = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
            if settings then
                ApplyModuleEnabledSetting("talentLoadout", value, function(enabled)
                    settings.enabled = enabled and true or false
                end, RefreshTalentLoadoutOptionsPanel)
            end
        end
    )
    talentLoadoutPanel.refreshers[#talentLoadoutPanel.refreshers + 1] = talentLoadoutEnabledCheckbox

    -- Show In: three multi-select dropdowns, one per visibility group
    local talentLoadoutShowInDropdowns = {}
    do
        local visibilityGroups = ns.CONSUMABLE_VISIBILITY_GROUPS or {}
        local colWidth = 200
        local colSpacing = 20
        for groupIdx, group in ipairs(visibilityGroups) do
            local capturedKeys = group.filterKeys
            local capturedName = group.name
            local dropX = 18 + ((groupIdx - 1) * (colWidth + colSpacing))
            local showInDropdown = CreateDropdown(
                talentLoadoutCardShowIn,
                dropX,
                -82,
                capturedName,
                colWidth,
                function()
                    return GetTalentLoadoutFilterPreviewText(capturedKeys)
                end,
                function()
                    local entries = {}
                    for _, filterKey in ipairs(capturedKeys or {}) do
                        local capturedKey = filterKey
                        entries[#entries + 1] = {
                            type = "option",
                            text = GetTalentLoadoutFilterLabel(capturedKey),
                            value = capturedKey,
                            isChecked = function()
                                local s = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
                                local ef = s and s.enabledFilters or {}
                                return ef[capturedKey] == true
                            end,
                            onSelect = function(value)
                                local s = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
                                if s then
                                    if type(s.enabledFilters) ~= "table" then s.enabledFilters = {} end
                                    s.enabledFilters[value] = not (s.enabledFilters[value] == true)
                                end
                                if ns.RequestRefresh then ns.RequestRefresh("talentLoadout") end
                                RefreshTalentLoadoutOptionsPanel()
                            end,
                        }
                    end
                    return entries
                end
            )
            showInDropdown.multiSelect = true
            talentLoadoutPanel.refreshers[#talentLoadoutPanel.refreshers + 1] = showInDropdown
            talentLoadoutShowInDropdowns[#talentLoadoutShowInDropdowns + 1] = { dropdown = showInDropdown, dropX = dropX }
        end
    end

    -- Preferred Loadouts: checkbox + per-dungeon preference dropdowns
    local talentLoadoutCheckPreferredCheckbox = CreateCheckbox(
        talentLoadoutPreferredCard,
        "Enable Preferred Loadouts",
        18,
        -82,
        function()
            local s = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
            return s and s.checkPreferredLoadout == true
        end,
        function(value)
            local s = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
            if s then s.checkPreferredLoadout = value and true or false end
            RefreshTalentLoadoutOptionsPanel()
        end
    )
    talentLoadoutPanel.refreshers[#talentLoadoutPanel.refreshers + 1] = talentLoadoutCheckPreferredCheckbox

    local talentLoadoutDungeonDropdowns = {}
    do
        local mapIDs = C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {}
        for _, mapID in ipairs(mapIDs) do
            local dungeonName = C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID) or nil
            if type(dungeonName) == "string" and dungeonName ~= "" then
                local capturedDungeonName = dungeonName
                local dungeonDropdown = CreateDropdown(
                    talentLoadoutPreferredCard,
                    18,
                    -82,
                    capturedDungeonName,
                    sectionWidth - 36,
                    function()
                        local configID = GetDungeonPreference(capturedDungeonName)
                        if not configID or configID == 0 then return "None (always remind)" end
                        local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID) or nil
                        return (info and info.name and info.name ~= "") and info.name or "Unknown"
                    end,
                    function()
                        local entries = {}
                        local capturedDN = capturedDungeonName
                        entries[#entries + 1] = {
                            type = "option",
                            text = "None (always remind)",
                            value = 0,
                            isChecked = function() return GetDungeonPreference(capturedDN) == 0 end,
                            onSelect = function()
                                SetDungeonPreference(capturedDN, 0)
                                RefreshTalentLoadoutOptionsPanel()
                            end,
                        }
                        local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
                        if specID and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
                            local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
                            for _, configID in ipairs(configIDs) do
                                local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID) or nil
                                if info and info.ID and info.name and info.name ~= "" then
                                    local capturedConfigID = info.ID
                                    local capturedName = info.name
                                    entries[#entries + 1] = {
                                        type = "option",
                                        text = capturedName,
                                        value = capturedConfigID,
                                        isChecked = function()
                                            return GetDungeonPreference(capturedDN) == capturedConfigID
                                        end,
                                        onSelect = function()
                                            SetDungeonPreference(capturedDN, capturedConfigID)
                                            RefreshTalentLoadoutOptionsPanel()
                                        end,
                                    }
                                end
                            end
                        end
                        return entries
                    end
                )
                talentLoadoutPanel.refreshers[#talentLoadoutPanel.refreshers + 1] = dungeonDropdown
                talentLoadoutDungeonDropdowns[#talentLoadoutDungeonDropdowns + 1] = dungeonDropdown
            end
        end
    end

    local talentLoadoutAnchorDropdown = CreateStaticDropdown(
        talentLoadoutPositionCard,
        18,
        -82,
        "Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetTalentLoadoutPositionConfig().point
        end,
        function(value)
            GetTalentLoadoutPositionConfig().point = NormalizeReminderPointValue(value, talentLoadoutPositionDefaults.point)
            RefreshTalentLoadoutOptionsPanel()
        end,
        "Top"
    )
    talentLoadoutPanel.refreshers[#talentLoadoutPanel.refreshers + 1] = talentLoadoutAnchorDropdown

    local talentLoadoutXSlider = ns.CreateOptionsPositionSlider(
        talentLoadoutPositionCard,
        18,
        -156,
        "X Position",
        "x",
        function()
            return GetTalentLoadoutPositionConfig().x
        end,
        function(value)
            GetTalentLoadoutPositionConfig().x = value
            RefreshTalentLoadoutOptionsPanel()
        end
    )
    talentLoadoutPanel.refreshers[#talentLoadoutPanel.refreshers + 1] = talentLoadoutXSlider

    local talentLoadoutYSlider = ns.CreateOptionsPositionSlider(
        talentLoadoutPositionCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Y Position",
        "y",
        function()
            return GetTalentLoadoutPositionConfig().y
        end,
        function(value)
            GetTalentLoadoutPositionConfig().y = value
            RefreshTalentLoadoutOptionsPanel()
        end
    )
    talentLoadoutPanel.refreshers[#talentLoadoutPanel.refreshers + 1] = talentLoadoutYSlider

    talentLoadoutPanel.UpdateLayout = function(self)
        local cardSpacing = 20
        local currentY = PAGE_SECTION_START_Y
        local tlSettings = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or {}
        local checkPreferredEnabled = tlSettings.checkPreferredLoadout == true

        talentLoadoutCardGeneral:ClearAllPoints()
        talentLoadoutCardGeneral:SetPoint("TOPLEFT", talentLoadoutContent, "TOPLEFT", sectionX, currentY)
        local generalCardHeight = FitSectionCardHeight(talentLoadoutCardGeneral, 20)
        currentY = currentY - generalCardHeight - cardSpacing

        talentLoadoutCardShowIn:ClearAllPoints()
        talentLoadoutCardShowIn:SetPoint("TOPLEFT", talentLoadoutContent, "TOPLEFT", sectionX, currentY)
        for _, entry in ipairs(talentLoadoutShowInDropdowns) do
            PositionControl(entry.dropdown, talentLoadoutCardShowIn, entry.dropX, -82)
        end
        local showInCardHeight = FitSectionCardHeight(talentLoadoutCardShowIn, 20)
        currentY = currentY - showInCardHeight - cardSpacing

        talentLoadoutPreferredCard:ClearAllPoints()
        talentLoadoutPreferredCard:SetPoint("TOPLEFT", talentLoadoutContent, "TOPLEFT", sectionX, currentY)
        PositionControl(talentLoadoutCheckPreferredCheckbox, talentLoadoutPreferredCard, 18, -82)
        local dungeonRowY = -156
        for _, dungeonDropdown in ipairs(talentLoadoutDungeonDropdowns) do
            PositionControl(dungeonDropdown, talentLoadoutPreferredCard, 18, dungeonRowY)
            SetControlEnabled(dungeonDropdown, checkPreferredEnabled)
            dungeonRowY = dungeonRowY - 74
        end
        local preferredCardHeight = FitSectionCardHeight(talentLoadoutPreferredCard, 20)
        currentY = currentY - preferredCardHeight - cardSpacing

        talentLoadoutPositionCard:ClearAllPoints()
        talentLoadoutPositionCard:SetPoint("TOPLEFT", talentLoadoutContent, "TOPLEFT", sectionX, currentY)
        PositionControl(talentLoadoutAnchorDropdown, talentLoadoutPositionCard, 18, -82)
        PositionControl(talentLoadoutXSlider, talentLoadoutPositionCard, 18, -156)
        PositionControl(talentLoadoutYSlider, talentLoadoutPositionCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        FitSectionCardHeight(talentLoadoutPositionCard, 20)
        FitScrollContentHeight(talentLoadoutContent, talentLoadoutPanel:GetHeight() - 16, 36)
    end

    talentLoadoutPanel:UpdateLayout()

    end

    do
    local housingContent
    local housingDefaults = ns.DEFAULTS and ns.DEFAULTS.housing or { enabled = true, customSort = true, showNewMarkers = true, newMarkersFirstOwnershipOnly = false, vendorMultiBuy = true, vendorThrottle = true }
    local function CommitHousingOption(settingKey, value)
        local normalizedValue = value and true or false

        if ns.SetHousingSetting then
            ns.SetHousingSetting(settingKey, normalizedValue)
        else
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            if s then
                s[settingKey] = normalizedValue
            end
            if type(NomToolsDB) == "table" then
                if type(NomToolsDB.housing) ~= "table" then
                    NomToolsDB.housing = {}
                end
                NomToolsDB.housing[settingKey] = normalizedValue
            end
        end

        if ns.CommitHousingSettings then
            ns.CommitHousingSettings()
        end

        return normalizedValue
    end

    housingPanel, housingContent = CreateModulePage(
        "NomToolsHousingPanel",
        "Housing",
        "Housing",
        "Sort housing storage by most recently acquired items and mark new arrivals.",
        {
            moduleEnabledGetter = function()
                local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
                return s and s.enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
                if s then
                    ns.SetModuleEnabled("housing", enabled, function(v)
                        if ns.SetHousingSetting then
                            ns.SetHousingSetting("enabled", v and true or false)
                        else
                            s.enabled = v and true or false
                        end
                    end)
                end
            end,
            resetHandler = function()
                if not ns.db then return end
                if ns.db.housing then
                    if ns.SetHousingSetting then
                        ns.SetHousingSetting("customSort", housingDefaults.customSort)
                        ns.SetHousingSetting("showNewMarkers", housingDefaults.showNewMarkers)
                        ns.SetHousingSetting("newMarkersFirstOwnershipOnly", housingDefaults.newMarkersFirstOwnershipOnly)
                        ns.SetHousingSetting("vendorMultiBuy", housingDefaults.vendorMultiBuy)
                        ns.SetHousingSetting("vendorThrottle", housingDefaults.vendorThrottle)
                    else
                        ns.db.housing.customSort = housingDefaults.customSort
                        ns.db.housing.showNewMarkers = housingDefaults.showNewMarkers
                        ns.db.housing.newMarkersFirstOwnershipOnly = housingDefaults.newMarkersFirstOwnershipOnly
                        ns.db.housing.vendorMultiBuy = housingDefaults.vendorMultiBuy
                        ns.db.housing.vendorThrottle = housingDefaults.vendorThrottle
                    end
                end
            end,
        }
    )

    local housingCardGeneral = CreateSectionCard(
        housingContent,
        sectionX,
        -96,
        sectionWidth,
        112,
        "General",
        "Enable or disable housing enhancements. Reload the UI after enable or disable changes to apply them fully."
    )

    local housingEnabledCheckbox = CreateCheckbox(
        housingCardGeneral,
        "Enable Housing Module",
        18,
        -82,
        function()
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            return s and s.enabled
        end,
        function(value)
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            if s then
                ApplyModuleEnabledSetting("housing", value, function(enabled)
                    s.enabled = enabled and true or false
                end)
            end
        end
    )
    housingPanel.refreshers[#housingPanel.refreshers + 1] = housingEnabledCheckbox

    local housingCardImprovements = CreateSectionCard(
        housingContent,
        sectionX,
        -228,
        sectionWidth,
        332,
        "Improvements",
        "Configure storage and vendor enhancements for the housing UI."
    )

    local housingStorageLabel = CreateSubsectionTitle(housingCardImprovements, "Storage", 18, -82)

    local customSortCheckbox = CreateCheckbox(
        housingCardImprovements,
        "Fix Blizzard \"Sort By\"",
        18,
        -120,
        function()
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            return s and s.customSort
        end,
        function(value)
            CommitHousingOption("customSort", value)
        end
    )
    housingPanel.refreshers[#housingPanel.refreshers + 1] = customSortCheckbox

    local showNewMarkersCheckbox = CreateCheckbox(
        housingCardImprovements,
        "Show \"New\" Markers on Items",
        18,
        -152,
        function()
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            return s and s.showNewMarkers ~= false
        end,
        function(value)
            CommitHousingOption("showNewMarkers", value)
        end
    )
    housingPanel.refreshers[#housingPanel.refreshers + 1] = showNewMarkersCheckbox

    local firstOwnershipOnlyCheckbox = CreateCheckbox(
        housingCardImprovements,
        'Only Mark Items New on First Ownership',
        18,
        -184,
        function()
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            return s and s.newMarkersFirstOwnershipOnly == true
        end,
        function(value)
            CommitHousingOption("newMarkersFirstOwnershipOnly", value)
        end
    )
    housingPanel.refreshers[#housingPanel.refreshers + 1] = firstOwnershipOnlyCheckbox

    local housingVendorsLabel = CreateSubsectionTitle(housingCardImprovements, "Decor Vendors", 18, -232)

    local vendorMultiBuyCheckbox = CreateCheckbox(
        housingCardImprovements,
        'Multi-Buy from Decor Vendors (Shift+Right-Click)',
        18,
        -270,
        function()
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            return s and s.vendorMultiBuy ~= false
        end,
        function(value)
            CommitHousingOption("vendorMultiBuy", value)
        end
    )
    housingPanel.refreshers[#housingPanel.refreshers + 1] = vendorMultiBuyCheckbox

    local vendorThrottleCheckbox = CreateCheckbox(
        housingCardImprovements,
        'Wait for Server Confirmation Between Purchases',
        18,
        -302,
        function()
            local s = ns.GetHousingSettings and ns.GetHousingSettings() or nil
            return s and s.vendorThrottle ~= false
        end,
        function(value)
            CommitHousingOption("vendorThrottle", value)
        end
    )
    housingPanel.refreshers[#housingPanel.refreshers + 1] = vendorThrottleCheckbox

    housingPanel.UpdateLayout = function(self)
        local currentY = PAGE_SECTION_START_Y
        local cardSpacing = 20
        local housingSettings = ns.GetHousingSettings and ns.GetHousingSettings() or nil
        local showNewMarkers = housingSettings == nil or housingSettings.showNewMarkers ~= false
        local vendorMultiBuy = housingSettings == nil or housingSettings.vendorMultiBuy ~= false

        housingCardGeneral:ClearAllPoints()
        housingCardGeneral:SetPoint("TOPLEFT", housingContent, "TOPLEFT", sectionX, currentY)
        local generalCardHeight = FitSectionCardHeight(housingCardGeneral, 20)
        currentY = currentY - generalCardHeight - cardSpacing

        housingCardImprovements:ClearAllPoints()
        housingCardImprovements:SetPoint("TOPLEFT", housingContent, "TOPLEFT", sectionX, currentY)
        PositionControl(housingStorageLabel, housingCardImprovements, 18, -82)
        PositionControl(customSortCheckbox, housingCardImprovements, 18, -120)
        PositionControl(showNewMarkersCheckbox, housingCardImprovements, 18, -152)
        PositionControl(firstOwnershipOnlyCheckbox, housingCardImprovements, 18, -184)
        PositionControl(housingVendorsLabel, housingCardImprovements, 18, -232)
        PositionControl(vendorMultiBuyCheckbox, housingCardImprovements, 18, -270)
        PositionControl(vendorThrottleCheckbox, housingCardImprovements, 18, -302)
        SetControlEnabled(firstOwnershipOnlyCheckbox, showNewMarkers)
        SetControlEnabled(vendorThrottleCheckbox, vendorMultiBuy)
        FitSectionCardHeight(housingCardImprovements, 20)
        FitScrollContentHeight(housingContent, housingPanel:GetHeight() - 16, 36)
    end

    housingPanel:UpdateLayout()

    end

    do
    local worldQuestsContent
    local worldQuestsDefaults = ns.DEFAULTS and ns.DEFAULTS.worldQuests
        or {
            enabled = false,
            openOnWorldQuestsTab = false,
            panelWidth = 260,
            font = ns.GLOBAL_CHOICE_KEY,
            fontOutline = ns.GLOBAL_CHOICE_KEY,
            titleFontSize = 14,
            detailFontSize = 11,
            rewardFontSize = 10,
        }
    local function RefreshWorldQuestsOptionsPanel(clearSearch)
        if ns.SyncAndRefreshWorldQuests then
            ns.SyncAndRefreshWorldQuests(clearSearch == true)
        end
        if worldQuestsPanel and worldQuestsPanel.RefreshAll then
            worldQuestsPanel:RefreshAll()
        end
    end
    local function CommitWorldQuestsSetting(settingKey, value)
        if ns.SetWorldQuestsSetting then
            ns.SetWorldQuestsSetting(settingKey, value)
        else
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            if s then s[settingKey] = value end
            if type(NomToolsDB) == "table" then
                if type(NomToolsDB.worldQuests) ~= "table" then
                    NomToolsDB.worldQuests = {}
                end
                NomToolsDB.worldQuests[settingKey] = value
            end
        end
    end

    worldQuestsPanel, worldQuestsContent = CreateModulePage(
        "NomToolsWorldQuestsPanel",
        "World Quests",
        "World Quests",
        "Show a list of active world quests overlaid on the left side of the world map.",
        {
            moduleEnabledGetter = function()
                local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
                return s and s.enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
                if s then
                    ns.SetModuleEnabled("worldQuests", enabled, function(v)
                        if ns.SetWorldQuestsSetting then
                            ns.SetWorldQuestsSetting("enabled", v and true or false)
                        else
                            s.enabled = v and true or false
                        end
                    end)
                end
            end,
            resetHandler = function()
                if not ns.db then return end
                CommitWorldQuestsSetting("openOnWorldQuestsTab", worldQuestsDefaults.openOnWorldQuestsTab == true)
                CommitWorldQuestsSetting("panelWidth",       worldQuestsDefaults.panelWidth)
                CommitWorldQuestsSetting("font",             worldQuestsDefaults.font or ns.GLOBAL_CHOICE_KEY)
                CommitWorldQuestsSetting("fontOutline",      worldQuestsDefaults.fontOutline or ns.GLOBAL_CHOICE_KEY)
                CommitWorldQuestsSetting("titleFontSize",    worldQuestsDefaults.titleFontSize or 14)
                CommitWorldQuestsSetting("detailFontSize",   worldQuestsDefaults.detailFontSize or 11)
                CommitWorldQuestsSetting("rewardFontSize",   worldQuestsDefaults.rewardFontSize or 10)
                CommitWorldQuestsSetting("filterVersion", 2)
                CommitWorldQuestsSetting("filterTypes",   {})
                CommitWorldQuestsSetting("filterRewards",    {})
                CommitWorldQuestsSetting("sortMode",         worldQuestsDefaults.sortMode or "time")
                CommitWorldQuestsSetting("zoneSortMode",     worldQuestsDefaults.zoneSortMode or "time")
                CommitWorldQuestsSetting("excludedMaps", nil)
                RefreshWorldQuestsOptionsPanel(true)
            end,
        }
    )

    local wqCardGeneral = CreateSectionCard(
        worldQuestsContent,
        sectionX,
        -96,
        sectionWidth,
        184,
        "General",
        "Enable the World Quests tab. When enabled, a \"World Quests\" tab appears in the World Map side panel alongside Quests, Events, and Map Legend."
    )

    local wqEnabledCheckbox = CreateCheckbox(
        wqCardGeneral,
        "Enable World Quests Module",
        18,
        -82,
        function()
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            return s and s.enabled
        end,
        function(value)
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            if s then
                ApplyModuleEnabledSetting("worldQuests", value, function(enabled)
                    s.enabled = enabled and true or false
                end)
            end
        end
    )
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqEnabledCheckbox

    local wqOpenOnTabCheckbox = CreateCheckbox(
        wqCardGeneral,
        "Open World Map on World Quests tab",
        18,
        -116,
        function()
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            return s and s.openOnWorldQuestsTab == true
        end,
        function(value)
            CommitWorldQuestsSetting("openOnWorldQuestsTab", value and true or false)
        end
    )
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqOpenOnTabCheckbox

    local wqScanningCard = CreateSectionCard(
        worldQuestsContent,
        sectionX,
        -296,
        sectionWidth,
        150,
        "Scanning",
        "Choose which map levels show world quests. Disabling high-level maps like World and Azeroth reduces lag when opening the world map."
    )

    local wqExcludedMapsDropdown = CreateDropdown(
        wqScanningCard,
        18,
        -82,
        "Enabled Maps",
        FULL_DROPDOWN_WIDTH,
        function()
            local mapOrder = ns.WORLD_QUEST_SCAN_MAP_ORDER or {}
            local labels = ns.WORLD_QUEST_SCAN_MAP_LABELS or {}
            local enabledNames = {}
            for _, mapID in ipairs(mapOrder) do
                if not (ns.IsWorldQuestMapExcluded and ns.IsWorldQuestMapExcluded(mapID)) then
                    enabledNames[#enabledNames + 1] = labels[mapID] or tostring(mapID)
                end
            end
            if #enabledNames == 0 then
                return "None"
            elseif #enabledNames == #mapOrder then
                return "All"
            elseif #enabledNames <= 3 then
                return table.concat(enabledNames, ", ")
            else
                return #enabledNames .. " of " .. #mapOrder .. " enabled"
            end
        end,
        function()
            local entries = {}
            local mapOrder = ns.WORLD_QUEST_SCAN_MAP_ORDER or {}
            local labels = ns.WORLD_QUEST_SCAN_MAP_LABELS or {}

            for _, mapID in ipairs(mapOrder) do
                local currentMapID = mapID
                entries[#entries + 1] = {
                    type = "option",
                    text = labels[currentMapID] or tostring(currentMapID),
                    value = currentMapID,
                    checked = not (ns.IsWorldQuestMapExcluded and ns.IsWorldQuestMapExcluded(currentMapID)),
                    isChecked = function()
                        return not (ns.IsWorldQuestMapExcluded and ns.IsWorldQuestMapExcluded(currentMapID))
                    end,
                    onSelect = function(value)
                        if ns.SetWorldQuestMapExcluded then
                            local isCurrentlyExcluded = ns.IsWorldQuestMapExcluded and ns.IsWorldQuestMapExcluded(value)
                            ns.SetWorldQuestMapExcluded(value, not isCurrentlyExcluded)
                        end
                    end,
                }
            end

            return entries
        end,
        nil,
        {
            pageKey = "world_quests",
        }
    )
    wqExcludedMapsDropdown.multiSelect = true
    wqExcludedMapsDropdown.refreshParentOnSelect = false
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqExcludedMapsDropdown

    local wqAppearanceCard = CreateSectionCard(
        worldQuestsContent,
        sectionX,
        -460,
        sectionWidth,
        270,
        "Typography",
        "Customize the font used by world quest titles, details, and reward item level labels in the map tab."
    )

    local wqFontDropdown = CreateFontDropdown(
        wqAppearanceCard,
        18,
        -82,
        "Font",
        APPEARANCE_COLUMN_WIDTH,
        function()
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            return s and s.font or (worldQuestsDefaults.font or ns.GLOBAL_CHOICE_KEY)
        end,
        function(value)
            CommitWorldQuestsSetting("font", value)
            RefreshWorldQuestsOptionsPanel()
        end,
        "Friz Quadrata TT"
    )
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqFontDropdown

    local wqFontOutlineDropdown = CreateStaticDropdown(
        wqAppearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -82,
        "Font Outline",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(true) or {}
        end,
        function()
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            return s and s.fontOutline or (worldQuestsDefaults.fontOutline or ns.GLOBAL_CHOICE_KEY)
        end,
        function(value)
            CommitWorldQuestsSetting("fontOutline", value)
            RefreshWorldQuestsOptionsPanel()
        end,
        "Outline"
    )
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqFontOutlineDropdown

    local wqTitleFontSizeSlider = CreateSlider(
        wqAppearanceCard,
        18,
        -156,
        "Title Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        30,
        1,
        function()
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            return s and s.titleFontSize or (worldQuestsDefaults.titleFontSize or 14)
        end,
        function(value)
            CommitWorldQuestsSetting("titleFontSize", value)
            RefreshWorldQuestsOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqTitleFontSizeSlider

    local wqDetailFontSizeSlider = CreateSlider(
        wqAppearanceCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Detail Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        30,
        1,
        function()
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            return s and s.detailFontSize or (worldQuestsDefaults.detailFontSize or 11)
        end,
        function(value)
            CommitWorldQuestsSetting("detailFontSize", value)
            RefreshWorldQuestsOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqDetailFontSizeSlider

    local wqRewardFontSizeSlider = CreateSlider(
        wqAppearanceCard,
        18,
        -230,
        "Reward Label Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        30,
        1,
        function()
            local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
            return s and s.rewardFontSize or (worldQuestsDefaults.rewardFontSize or 10)
        end,
        function(value)
            CommitWorldQuestsSetting("rewardFontSize", value)
            RefreshWorldQuestsOptionsPanel()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    worldQuestsPanel.refreshers[#worldQuestsPanel.refreshers + 1] = wqRewardFontSizeSlider

    worldQuestsPanel.UpdateLayout = function(self)
        local currentY = PAGE_SECTION_START_Y
        local cardSpacing = 20

        wqCardGeneral:ClearAllPoints()
        wqCardGeneral:SetPoint("TOPLEFT", worldQuestsContent, "TOPLEFT", sectionX, currentY)
        local generalCardHeight = FitSectionCardHeight(wqCardGeneral, 20)
        currentY = currentY - generalCardHeight - cardSpacing

        wqScanningCard:ClearAllPoints()
        wqScanningCard:SetPoint("TOPLEFT", worldQuestsContent, "TOPLEFT", sectionX, currentY)
        PositionControl(wqExcludedMapsDropdown, wqScanningCard, 18, -82)
        local scanningCardHeight = FitSectionCardHeight(wqScanningCard, 20)
        currentY = currentY - scanningCardHeight - cardSpacing

        wqAppearanceCard:ClearAllPoints()
        wqAppearanceCard:SetPoint("TOPLEFT", worldQuestsContent, "TOPLEFT", sectionX, currentY)
        PositionControl(wqFontDropdown, wqAppearanceCard, 18, -82)
        PositionControl(wqFontOutlineDropdown, wqAppearanceCard, APPEARANCE_RIGHT_COLUMN_X, -82)
        PositionControl(wqTitleFontSizeSlider, wqAppearanceCard, 18, -156)
        PositionControl(wqDetailFontSizeSlider, wqAppearanceCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        PositionControl(wqRewardFontSizeSlider, wqAppearanceCard, 18, -230)
        FitSectionCardHeight(wqAppearanceCard, 20)

        FitScrollContentHeight(worldQuestsContent, worldQuestsPanel:GetHeight() - 16, 36)
    end

    worldQuestsPanel:UpdateLayout()

    end

    do
    local function GetMenuBarOptions()
        return ns.GetMenuBarSettings and ns.GetMenuBarSettings() or nil
    end

    local function GetMenuBarQueueEyeOptions()
        local settings = GetMenuBarOptions()
        if not settings then return {} end
        if type(settings.queueEye) ~= "table" then settings.queueEye = {} end
        return settings.queueEye
    end

    local function RefreshMenuBarOptions()
        ns.RequestRefresh("menuBar")
        if menuBarPanel and menuBarPanel.RefreshAll then
            menuBarPanel:RefreshAll()
        end
    end

    local menuBarContent
    local menuBarDefaults = ns.DEFAULTS and ns.DEFAULTS.menuBar or { enabled = true }
    local menuBarEditModeDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.menuBar or {
        point = "BOTTOMRIGHT",
        x = 0,
        y = 0,
    }
    local queueEyeEditModeDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.queueEye or {
        point = "BOTTOMLEFT",
        x = 10,
        y = 10,
    }
    local queueEyeDefaults = (menuBarDefaults and menuBarDefaults.queueEye) or {
        attachToMinimap = true,
        minimapAnchor = "BOTTOMLEFT",
        minimapOffsetX = 5,
        minimapOffsetY = 5,
        scale = 1.0,
    }

    local function GetMenuBarPositionConfig()
        return GetReminderPositionConfig("menuBar", menuBarEditModeDefaults)
    end

    local function GetQueueEyePositionConfig()
        return GetReminderPositionConfig("queueEye", queueEyeEditModeDefaults)
    end

    menuBarPanel, menuBarContent = CreateModulePage(
        "NomToolsMenuBarPanel",
        "Miscellaneous",
        "Menu Bar",
        "Move Blizzard's real menu bar and queue eye independently through Edit Mode. NomTools no longer rebuilds, restyles, or filters the micro buttons.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function()
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                local enabled = miscSettings and miscSettings.enabled
                if ns.IsModuleRuntimeEnabled then
                    return ns.IsModuleRuntimeEnabled("miscellaneous", enabled)
                end
                return enabled ~= false
            end,
            moduleEnabledSetter = function(enabled)
                local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
                if miscSettings then
                    ns.SetModuleEnabled("miscellaneous", enabled, function(v) miscSettings.enabled = v end)
                end
            end,
            resetHandler = function()
                if not ns.db then
                    return
                end

                local savedMbEnabled = ns.db.menuBar and ns.db.menuBar.enabled
                ns.db.menuBar = CopyTableRecursive(menuBarDefaults)
                ns.db.menuBar.enabled = savedMbEnabled
                ResetModuleEnabledSetting("menuBar", menuBarDefaults.enabled, function(enabled)
                    ns.db.menuBar.enabled = enabled and true or false
                end)
                ResetEditModeConfig("menuBar", menuBarEditModeDefaults)
                ResetEditModeConfig("queueEye", queueEyeEditModeDefaults)
                RefreshMenuBarOptions()
            end,
        }
    )

    -- ── General card ──────────────────────────────────────────────────────────

    local menuBarGeneralCard = CreateSectionCard(
        menuBarContent,
        sectionX,
        -96,
        sectionWidth,
        214,
        "General",
        "This feature lives under Miscellaneous and keeps Blizzard's original menu bar and queue eye intact while repositioning them through separate NomTools Edit Mode holders."
    )

    local menuBarEnabledCheckbox = CreateCheckbox(
        menuBarGeneralCard,
        "Enable Menu Bar Feature",
        18,
        -82,
        function()
            local settings = GetMenuBarOptions()
            return settings and settings.enabled
        end,
        function(value)
            local settings = GetMenuBarOptions()
            if settings then
                ApplyModuleEnabledSetting("menuBar", value, function(enabled)
                    settings.enabled = enabled and true or false
                end, RefreshMenuBarOptions)
            end
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarEnabledCheckbox

    -- ── Queue Eye Position card ───────────────────────────────────────────────

    local menuBarQueueEyeCard = CreateSectionCard(
        menuBarContent,
        sectionX,
        -330,
        sectionWidth,
        100,
        "Queue Eye Position",
        "Snap the queue eye to a corner or edge of the minimap using an anchor point and optional offsets, or place it anywhere on screen using the free-position controls below."
    )

    local menuBarQueueEyeAttachCheckbox = CreateCheckbox(
        menuBarQueueEyeCard,
        "Attach to Minimap",
        18,
        -82,
        function()
            local qe = GetMenuBarQueueEyeOptions()
            return qe.attachToMinimap ~= false
        end,
        function(value)
            local qe = GetMenuBarQueueEyeOptions()
            qe.attachToMinimap = value and true or false
            RefreshMenuBarOptions()
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyeAttachCheckbox

    local menuBarQueueEyeAnchorDropdown = CreateStaticDropdown(
        menuBarQueueEyeCard,
        18,
        -118,
        "Minimap Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetMenuBarQueueEyeOptions().minimapAnchor
        end,
        function(value)
            GetMenuBarQueueEyeOptions().minimapAnchor = NormalizeReminderPointValue(value, queueEyeDefaults.minimapAnchor)
            RefreshMenuBarOptions()
        end,
        "BOTTOMLEFT"
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyeAnchorDropdown

    local menuBarQueueEyeMinimapXSlider = CreateSlider(
        menuBarQueueEyeCard,
        18,
        -192,
        "X Offset",
        APPEARANCE_COLUMN_WIDTH,
        -200,
        200,
        1,
        function()
            return ClampOptionValue(GetMenuBarQueueEyeOptions().minimapOffsetX, -200, 200, 0)
        end,
        function(value)
            GetMenuBarQueueEyeOptions().minimapOffsetX = value
            RefreshMenuBarOptions()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyeMinimapXSlider

    local menuBarQueueEyeMinimapYSlider = CreateSlider(
        menuBarQueueEyeCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -192,
        "Y Offset",
        APPEARANCE_COLUMN_WIDTH,
        -200,
        200,
        1,
        function()
            return ClampOptionValue(GetMenuBarQueueEyeOptions().minimapOffsetY, -200, 200, 0)
        end,
        function(value)
            GetMenuBarQueueEyeOptions().minimapOffsetY = value
            RefreshMenuBarOptions()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyeMinimapYSlider

    local menuBarQueueEyeScaleSlider = CreateSlider(
        menuBarQueueEyeCard,
        18,
        -266,
        "Queue Eye Size",
        APPEARANCE_COLUMN_WIDTH,
        0.70,
        1.60,
        0.01,
        function()
            local qe = GetMenuBarQueueEyeOptions()
            return ClampOptionValue(qe.scale, 0.70, 1.60, 1.0)
        end,
        function(value)
            local qe = GetMenuBarQueueEyeOptions()
            qe.scale = value
            RefreshMenuBarOptions()
        end,
        function(value)
            return FormatSliderValue(value, 2, "x")
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyeScaleSlider

    local menuBarQueueEyePositionLabel = CreateBodyText(
        menuBarQueueEyeCard,
        "Free Position",
        18,
        -340
    )

    local menuBarQueueEyePositionAnchorDropdown = CreateStaticDropdown(
        menuBarQueueEyeCard,
        18,
        -366,
        "Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetQueueEyePositionConfig().point
        end,
        function(value)
            GetQueueEyePositionConfig().point = NormalizeReminderPointValue(value, queueEyeEditModeDefaults.point)
            RefreshMenuBarOptions()
        end,
        "BOTTOMLEFT"
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyePositionAnchorDropdown

    local menuBarQueueEyePositionXSlider = ns.CreateOptionsPositionSlider(
        menuBarQueueEyeCard,
        18,
        -440,
        "X Position",
        "x",
        function()
            return GetQueueEyePositionConfig().x
        end,
        function(value)
            GetQueueEyePositionConfig().x = value
            RefreshMenuBarOptions()
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyePositionXSlider

    local menuBarQueueEyePositionYSlider = ns.CreateOptionsPositionSlider(
        menuBarQueueEyeCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -440,
        "Y Position",
        "y",
        function()
            return GetQueueEyePositionConfig().y
        end,
        function(value)
            GetQueueEyePositionConfig().y = value
            RefreshMenuBarOptions()
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarQueueEyePositionYSlider

    -- ── Menu Bar Position card ────────────────────────────────────────────────

    local menuBarPositionCard = CreateSectionCard(
        menuBarContent,
        sectionX,
        -830,
        sectionWidth,
        100,
        "Menu Bar Position",
        "Set the on-screen anchor and coordinates for the menu bar. You can also drag the bar in Edit Mode."
    )

    local menuBarPositionAnchorDropdown = CreateStaticDropdown(
        menuBarPositionCard,
        18,
        -82,
        "Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetMenuBarPositionConfig().point
        end,
        function(value)
            GetMenuBarPositionConfig().point = NormalizeReminderPointValue(value, menuBarEditModeDefaults.point)
            RefreshMenuBarOptions()
        end,
        "BOTTOMRIGHT"
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarPositionAnchorDropdown

    local menuBarScaleSlider = CreateSlider(
        menuBarPositionCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -82,
        "Menu Bar Size",
        APPEARANCE_COLUMN_WIDTH,
        0.70,
        1.60,
        0.01,
        function()
            local settings = GetMenuBarOptions()
            return ClampOptionValue(settings and settings.scale, 0.70, 1.60, 1.0)
        end,
        function(value)
            local settings = GetMenuBarOptions()
            if settings then
                settings.scale = value
                RefreshMenuBarOptions()
            end
        end,
        function(value)
            return FormatSliderValue(value, 2, "x")
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarScaleSlider

    local menuBarPositionXSlider = ns.CreateOptionsPositionSlider(
        menuBarPositionCard,
        18,
        -156,
        "X Position",
        "x",
        function()
            return GetMenuBarPositionConfig().x
        end,
        function(value)
            GetMenuBarPositionConfig().x = value
            RefreshMenuBarOptions()
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarPositionXSlider

    local menuBarPositionYSlider = ns.CreateOptionsPositionSlider(
        menuBarPositionCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Y Position",
        "y",
        function()
            return GetMenuBarPositionConfig().y
        end,
        function(value)
            GetMenuBarPositionConfig().y = value
            RefreshMenuBarOptions()
        end
    )
    menuBarPanel.refreshers[#menuBarPanel.refreshers + 1] = menuBarPositionYSlider

    -- ── UpdateLayout ──────────────────────────────────────────────────────────

    menuBarPanel.UpdateLayout = function(self)
        local currentY = PAGE_SECTION_START_Y
        local cardSpacing = 20

        -- General card
        menuBarGeneralCard:ClearAllPoints()
        menuBarGeneralCard:SetPoint("TOPLEFT", menuBarContent, "TOPLEFT", sectionX, currentY)
        currentY = currentY - FitSectionCardHeight(menuBarGeneralCard, 20) - cardSpacing

        -- Queue Eye Position card
        menuBarQueueEyeCard:ClearAllPoints()
        menuBarQueueEyeCard:SetPoint("TOPLEFT", menuBarContent, "TOPLEFT", sectionX, currentY)
        local attachMinimap = GetMenuBarQueueEyeOptions().attachToMinimap ~= false
        SetControlEnabled(menuBarQueueEyeAnchorDropdown, attachMinimap)
        SetControlEnabled(menuBarQueueEyeMinimapXSlider, attachMinimap)
        SetControlEnabled(menuBarQueueEyeMinimapYSlider, attachMinimap)
        SetControlEnabled(menuBarQueueEyePositionAnchorDropdown, not attachMinimap)
        SetControlEnabled(menuBarQueueEyePositionXSlider, not attachMinimap)
        SetControlEnabled(menuBarQueueEyePositionYSlider, not attachMinimap)
        PositionControl(menuBarQueueEyeAttachCheckbox, menuBarQueueEyeCard, 18, -82)
        PositionControl(menuBarQueueEyeAnchorDropdown, menuBarQueueEyeCard, 18, -118)
        PositionControl(menuBarQueueEyeMinimapXSlider, menuBarQueueEyeCard, 18, -192)
        PositionControl(menuBarQueueEyeMinimapYSlider, menuBarQueueEyeCard, APPEARANCE_RIGHT_COLUMN_X, -192)
        PositionControl(menuBarQueueEyeScaleSlider, menuBarQueueEyeCard, 18, -266)
        PositionControl(menuBarQueueEyePositionLabel, menuBarQueueEyeCard, 18, -340)
        PositionControl(menuBarQueueEyePositionAnchorDropdown, menuBarQueueEyeCard, 18, -366)
        PositionControl(menuBarQueueEyePositionXSlider, menuBarQueueEyeCard, 18, -440)
        PositionControl(menuBarQueueEyePositionYSlider, menuBarQueueEyeCard, APPEARANCE_RIGHT_COLUMN_X, -440)
        currentY = currentY - FitSectionCardHeight(menuBarQueueEyeCard, 20) - cardSpacing

        -- Menu Bar Position card
        menuBarPositionCard:ClearAllPoints()
        menuBarPositionCard:SetPoint("TOPLEFT", menuBarContent, "TOPLEFT", sectionX, currentY)
        PositionControl(menuBarPositionAnchorDropdown, menuBarPositionCard, 18, -82)
        PositionControl(menuBarScaleSlider, menuBarPositionCard, APPEARANCE_RIGHT_COLUMN_X, -82)
        PositionControl(menuBarPositionXSlider, menuBarPositionCard, 18, -156)
        PositionControl(menuBarPositionYSlider, menuBarPositionCard, APPEARANCE_RIGHT_COLUMN_X, -156)
        currentY = currentY - FitSectionCardHeight(menuBarPositionCard, 20) - cardSpacing

        FitScrollContentHeight(menuBarContent, menuBarPanel:GetHeight() - 16, 36)
    end

    menuBarPanel:UpdateLayout()

    end

    do
    local trackingContent
    local consumableDefaults = ns.DEFAULTS and ns.DEFAULTS.consumables or {}
    local _, playerClassFile = UnitClass and UnitClass("player")
    local roguePoisonsAvailable = playerClassFile == "ROGUE"
    local TRACKING_TAB_LABELS = {
        flask = "Flasks",
        food = "Food",
        weapon = "Weapon Buffs",
        poisons = "Rogue Poisons",
        rune = "Augment Runes",
    }

    local function GetTrackingSetupTitle(kind, setupIndex)
        local label = TRACKING_TAB_LABELS[kind] or kind
        return string.format("%s - Setup %d", label, setupIndex)
    end

    trackingPanel, trackingContent = CreateModulePage(
        "NomToolsConsumablesTrackingPanel",
        "Consumables",
        "Tracking",
        "Choose which consumables NomTools tracks and define the priority order for each tracker.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function() return ns.db and ns.db.enabled ~= false end,
            moduleEnabledSetter = function(enabled)
                if ns.db then ns.db.enabled = enabled and true or false end
                if ns.SetModuleEnabled then ns.SetModuleEnabled("consumables", enabled, function(v) if ns.db then ns.db.enabled = v end end) end
            end,
            resetHandler = function(page)
                if not ns.db then
                    return true
                end

                local trackingSettings = ns.GetConsumableTrackingSettings and ns.GetConsumableTrackingSettings() or nil
                if type(trackingSettings) ~= "table" then
                    return true
                end

                local function ResetConsumableTrackerTab(kind)
                    trackingSettings.reapply = trackingSettings.reapply or {}
                    trackingSettings.visibility = trackingSettings.visibility or {}
                    trackingSettings.secondary = trackingSettings.secondary or {}

                    if kind == "poisons" then
                        trackingSettings.poisonsEnabled = consumableDefaults.poisonsEnabled and true or false
                        trackingSettings.weaponPoisonChoices = CopyTableRecursive(consumableDefaults.weaponPoisonChoices or {
                            lethal = "auto",
                            non_lethal = "auto",
                        })
                    elseif kind == "rune" then
                        trackingSettings.runeEnabled = consumableDefaults.runeEnabled and true or false
                        trackingSettings.runeChoice = consumableDefaults.runeChoice or "auto"
                    else
                        trackingSettings[kind .. "Enabled"] = consumableDefaults[kind .. "Enabled"] and true or false
                        trackingSettings[kind .. "Choice"] = consumableDefaults[kind .. "Choice"] or "auto"
                        trackingSettings[kind .. "Choices"] = CopyTableRecursive(consumableDefaults[kind .. "Choices"] or { "auto", "none", "none" })
                    end

                    trackingSettings.reapply[kind] = CopyTableRecursive((consumableDefaults.reapply or {})[kind] or {})
                    trackingSettings.visibility[kind] = CopyTableRecursive((consumableDefaults.visibility or {})[kind] or {})
                    trackingSettings.secondary[kind] = CopyTableRecursive((consumableDefaults.secondary or {})[kind] or {})
                end

                local function ResetAllConsumableTrackerTabs()
                    for _, kind in ipairs({ "flask", "food", "weapon", "poisons", "rune" }) do
                        ResetConsumableTrackerTab(kind)
                    end
                end

                local resetPopupKey = addonName .. "ConsumablesTrackingResetChoice"
                local function EnsureTrackingResetPopupRegistered()
                    if not StaticPopupDialogs or StaticPopupDialogs[resetPopupKey] then
                        return
                    end

                    StaticPopupDialogs[resetPopupKey] = {
                        text = "Choose what to reset.\n\nPress Escape to cancel.",
                        button1 = "Current Tab",
                        button2 = "All Tabs",
                        OnAccept = function(_, data)
                            if data and data.onCurrentTab then
                                data.onCurrentTab()
                            end
                        end,
                        OnCancel = function(_, data, reason)
                            if reason == "clicked" and data and data.onAllTabs then
                                data.onAllTabs()
                            end
                        end,
                        timeout = 0,
                        whileDead = 1,
                        hideOnEscape = 1,
                        preferredIndex = STATICPOPUP_NUMDIALOGS,
                    }
                end

                local activeTabKey = page and page.activeTrackingTabKey or "flask"
                local activeTabLabel = TRACKING_TAB_LABELS[activeTabKey] or "Current Tab"

                local function ApplyReset(resetAllTabs)
                    if resetAllTabs then
                        ResetAllConsumableTrackerTabs()
                    else
                        ResetConsumableTrackerTab(activeTabKey)
                    end

                    if ns.RequestRefresh then
                        RequestOptionsRefresh("consumables_tracking")
                    end
                    if page and page.RefreshAll then
                        page:RefreshAll()
                    end
                end

                EnsureTrackingResetPopupRegistered()
                if StaticPopup_Show then
                    local dialog = StaticPopup_Show(resetPopupKey, activeTabLabel, nil, {
                        onCurrentTab = function()
                            ApplyReset(false)
                        end,
                        onAllTabs = function()
                            ApplyReset(true)
                        end,
                    })

                    if dialog and dialog.text then
                        dialog.text:SetText("Choose what to reset.\n\nPress Escape to cancel.")
                    end
                else
                    ApplyReset(false)
                end

                return false
            end,
        }
    )

    local TRACKING_TAB_TOP_Y = PAGE_SECTION_START_Y
    local TRACKING_TAB_HEIGHT = 28
    local TRACKING_TAB_SPACING = 8
    local TRACKING_TAB_BOTTOM_SPACING = 18

    local function CreateTrackingTabButton(parent, text, width, onClick)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(width, TRACKING_TAB_HEIGHT)
        button:SetBackdrop(FIELD_BACKDROP)
        MarkAutoFitChild(button)

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
        label:SetText(text)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        button.label = label
        button.isUnavailable = false

        function button:SetSelected(selected)
            self.isSelected = selected and self.isUnavailable ~= true or false
            if self.isUnavailable then
                self:SetBackdropColor(SURFACE_BG_R - 0.12, SURFACE_BG_G - 0.11, SURFACE_BG_B - 0.10, 0.98)
                self:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.55)
                self.label:SetTextColor(0.46, 0.48, 0.52)
                return
            end

            if self.isSelected then
                self:SetBackdropColor(SURFACE_BG_R - 0.03, SURFACE_BG_G - 0.02, SURFACE_BG_B - 0.01, 0.98)
                self:SetBackdropBorderColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B, 0.95)
                self.label:SetTextColor(ACCENT_TEXT_R, ACCENT_TEXT_G, ACCENT_TEXT_B)
            else
                self:SetBackdropColor(SURFACE_BG_R - 0.10, SURFACE_BG_G - 0.09, SURFACE_BG_B - 0.08, 0.98)
                self:SetBackdropBorderColor(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.9)
                self.label:SetTextColor(ACCENT_SUBTLE_R, ACCENT_SUBTLE_G, ACCENT_SUBTLE_B)
            end
        end

        function button:SetUnavailable(unavailable)
            self.isUnavailable = unavailable and true or false
            if self.isUnavailable then
                self.isSelected = false
            end
            self:SetSelected(self.isSelected)
        end

        button:SetScript("OnClick", function(self)
            if self.isUnavailable then
                return
            end

            onClick()
        end)
        button:SetScript("OnEnter", function(self)
            if self.isUnavailable then
                return
            end

            if not self.isSelected then
                self:SetBackdropColor(SURFACE_BG_R - 0.07, SURFACE_BG_G - 0.06, SURFACE_BG_B - 0.05, 0.98)
                self.label:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            end
        end)
        button:SetScript("OnLeave", function(self)
            self:SetSelected(self.isSelected)
        end)

        button:SetSelected(false)
        return button
    end

    local sectionY = TRACKING_TAB_TOP_Y + 2
    local function CreateTrackingSetupCards(createCard)
        local cards = {}
        local nextY = sectionY

        for setupIndex = 1, 2 do
            local card
            card, nextY = createCard(trackingContent, nextY, setupIndex)
            cards[#cards + 1] = card
        end

        return cards, nextY
    end

    local flaskCards
    flaskCards, sectionY = CreateTrackingSetupCards(function(parent, topY, setupIndex)
        return CreatePrioritySection(parent, topY, GetTrackingSetupTitle("flask", setupIndex), "flask", setupIndex)
    end)

    local foodCards
    foodCards, sectionY = CreateTrackingSetupCards(function(parent, topY, setupIndex)
        return CreatePrioritySection(parent, topY, GetTrackingSetupTitle("food", setupIndex), "food", setupIndex)
    end)

    local weaponCards
    weaponCards, sectionY = CreateTrackingSetupCards(function(parent, topY, setupIndex)
        return CreatePrioritySection(parent, topY, GetTrackingSetupTitle("weapon", setupIndex), "weapon", setupIndex)
    end)

    local roguePoisonCards
    roguePoisonCards, sectionY = CreateTrackingSetupCards(function(parent, topY, setupIndex)
        return CreateRoguePoisonSection(parent, topY, GetTrackingSetupTitle("poisons", setupIndex), setupIndex)
    end)

    local runeCards
    runeCards, sectionY = CreateTrackingSetupCards(function(parent, topY, setupIndex)
        return CreateRuneSection(parent, topY, GetTrackingSetupTitle("rune", setupIndex), setupIndex)
    end)

    trackingPanel.copySourceCharacterKey = trackingPanel.copySourceCharacterKey or ""

    local function GetTrackingCopyCharacterChoices()
        local choices = ns.GetConsumableTrackingCharacterSources and ns.GetConsumableTrackingCharacterSources() or {}
        if #choices == 0 then
            return {
                { key = "", name = "No Saved Characters" },
            }
        end

        return choices
    end

    local trackingCopyDropdown = CreateStaticDropdown(
        trackingContent,
        sectionX,
        TRACKING_TAB_TOP_Y,
        "Copy From Character",
        240,
        GetTrackingCopyCharacterChoices,
        function()
            return trackingPanel.copySourceCharacterKey or ""
        end,
        function(value)
            trackingPanel.copySourceCharacterKey = value or ""
        end,
        "Select Character"
    )
    local baseTrackingCopyDropdownRefresh = trackingCopyDropdown.Refresh
    trackingCopyDropdown.Refresh = function(self)
        local choices = GetTrackingCopyCharacterChoices()
        local hasChoices = #choices > 0 and choices[1].key ~= ""
        local selectedKey = trackingPanel.copySourceCharacterKey or ""
        local hasSelectedKey = false

        for _, choice in ipairs(choices) do
            if choice.key == selectedKey then
                hasSelectedKey = true
                break
            end
        end

        if not hasSelectedKey then
            trackingPanel.copySourceCharacterKey = hasChoices and choices[1].key or ""
        end

        if baseTrackingCopyDropdownRefresh then
            baseTrackingCopyDropdownRefresh(self)
        end

        SetControlEnabled(self, hasChoices)
    end
    trackingPanel.refreshers[#trackingPanel.refreshers + 1] = trackingCopyDropdown

    local trackingCopyButton = CreateButton(trackingContent, "Copy Settings", sectionX + 256, TRACKING_TAB_TOP_Y - 24, 120, 24, function()
        local sourceCharacterKey = trackingPanel.copySourceCharacterKey or ""
        if sourceCharacterKey == "" then
            return
        end

        if ns.CopyConsumableTrackingSettingsFromCharacter and ns.CopyConsumableTrackingSettingsFromCharacter(sourceCharacterKey) then
            if ns.RequestRefresh then
                ns.RequestRefresh("consumables")
            end
            trackingPanel:RefreshAll()
        end
    end)
    trackingCopyButton.Refresh = function(self)
        local choices = GetTrackingCopyCharacterChoices()
        local hasChoices = #choices > 0 and choices[1].key ~= ""
        self:SetEnabled(hasChoices and (trackingPanel.copySourceCharacterKey or "") ~= "")
        self:SetAlpha((hasChoices and (trackingPanel.copySourceCharacterKey or "") ~= "") and 1 or 0.55)
    end
    trackingPanel.refreshers[#trackingPanel.refreshers + 1] = trackingCopyButton

    local trackingTabStrip = CreateFrame("Frame", nil, trackingContent)
    trackingTabStrip:SetSize(sectionWidth, TRACKING_TAB_HEIGHT)
    MarkAutoFitChild(trackingTabStrip)

    local trackingTabDivider = trackingTabStrip:CreateTexture(nil, "ARTWORK")
    trackingTabDivider:SetColorTexture(SURFACE_BORDER_R, SURFACE_BORDER_G, SURFACE_BORDER_B, 0.85)
    trackingTabDivider:SetPoint("BOTTOMLEFT", trackingTabStrip, "BOTTOMLEFT", 0, -8)
    trackingTabDivider:SetPoint("BOTTOMRIGHT", trackingTabStrip, "BOTTOMRIGHT", 0, -8)
    trackingTabDivider:SetHeight(1)

    local trackingTabs = {
        { key = "flask", label = TRACKING_TAB_LABELS.flask, cards = flaskCards },
        { key = "food", label = TRACKING_TAB_LABELS.food, cards = foodCards },
        { key = "rune", label = TRACKING_TAB_LABELS.rune, cards = runeCards },
        { key = "weapon", label = TRACKING_TAB_LABELS.weapon, cards = weaponCards },
        { key = "poisons", label = TRACKING_TAB_LABELS.poisons, cards = roguePoisonCards, disabled = not roguePoisonsAvailable },
    }

    local function GetTrackingTabByKey(tabKey)
        for _, tab in ipairs(trackingTabs) do
            if tab.key == tabKey then
                return tab
            end
        end

        return nil
    end

    local function SetActiveTrackingTab(tabKey)
        local tab = GetTrackingTabByKey(tabKey)
        if tab and tab.disabled then
            return
        end

        if trackingPanel.activeTrackingTabKey == tabKey then
            return
        end

        trackingPanel.activeTrackingTabKey = tabKey
        if trackingPanel.scrollFrame and trackingPanel.scrollFrame.SetVerticalScroll then
            trackingPanel.scrollFrame:SetVerticalScroll(0)
        end
        trackingPanel:RefreshAll()
    end

    local tabButtonWidth = math.floor((sectionWidth - ((#trackingTabs - 1) * TRACKING_TAB_SPACING)) / #trackingTabs)
    for index, tab in ipairs(trackingTabs) do
        local tabKey = tab.key
        local button = CreateTrackingTabButton(trackingTabStrip, tab.label, tabButtonWidth, function()
            SetActiveTrackingTab(tabKey)
        end)
        button:SetPoint("TOPLEFT", trackingTabStrip, "TOPLEFT", (index - 1) * (tabButtonWidth + TRACKING_TAB_SPACING), 0)
        tab.button = button
    end

    trackingPanel.activeTrackingTabKey = trackingPanel.activeTrackingTabKey or trackingTabs[1].key

    trackingPanel.UpdateLayout = function(self)
        local currentY = TRACKING_TAB_TOP_Y
        local activeTab = nil

        PositionControl(trackingCopyDropdown, trackingContent, sectionX, currentY)
        trackingCopyButton:ClearAllPoints()
        trackingCopyButton:SetPoint("LEFT", trackingCopyDropdown, "RIGHT", 16, 0)
        currentY = currentY - 58

        trackingTabStrip:ClearAllPoints()
        trackingTabStrip:SetPoint("TOPLEFT", trackingContent, "TOPLEFT", sectionX, currentY)
        currentY = currentY - TRACKING_TAB_HEIGHT - TRACKING_TAB_BOTTOM_SPACING

        for _, tab in ipairs(trackingTabs) do
            local isSelected = tab.key == self.activeTrackingTabKey and tab.disabled ~= true
            tab.button:SetUnavailable(tab.disabled == true)
            tab.button:SetSelected(isSelected)
            for _, card in ipairs(tab.cards or {}) do
                card:SetShown(isSelected)
            end
            if isSelected and tab.disabled ~= true then
                activeTab = tab
            end
        end

        if not activeTab then
            for _, tab in ipairs(trackingTabs) do
                if tab.disabled ~= true then
                    activeTab = tab
                    break
                end
            end
        end

        activeTab = activeTab or trackingTabs[1]
        if activeTab then
            self.activeTrackingTabKey = activeTab.key
            activeTab.button:SetSelected(true)
            for _, card in ipairs(activeTab.cards or {}) do
                card:SetShown(true)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", trackingContent, "TOPLEFT", sectionX, currentY)
                if card.UpdateDisabledState then
                    card:UpdateDisabledState()
                end
                currentY = currentY - FitSectionCardHeight(card, 18) - 18
            end
        end

        FitScrollContentHeight(trackingContent, trackingPanel:GetHeight() - 16, 36)
    end

    local baseTrackingPanelUpdateDisabledState = trackingPanel.UpdateDisabledState
    trackingPanel.UpdateDisabledState = function(self)
        if baseTrackingPanelUpdateDisabledState then
            baseTrackingPanelUpdateDisabledState(self)
        end

        for _, tab in ipairs(trackingTabs) do
            if tab.key == self.activeTrackingTabKey and tab.disabled ~= true then
                for _, card in ipairs(tab.cards or {}) do
                    if card:IsShown() and card.UpdateDisabledState then
                        card:UpdateDisabledState()
                    end
                end
                break
            end
        end
    end

    trackingPanel:UpdateLayout()

    end

    do
    local appearanceContent
    local consumableDefaults = ns.DEFAULTS and ns.DEFAULTS.consumables or {}
    local consumablePositionDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.reminder or {
        point = "TOP",
        x = 0,
        y = -140,
    }
    appearancePanelPage, appearanceContent = CreateModulePage(
        "NomToolsConsumablesAppearancePanel",
        "Consumables",
        "Appearance",
        "Adjust typography, icon presentation, and glow behavior. This page shows a live preview of the reminder bar while it is open.",
        {
            showEditModeButton = true,
            moduleEnabledGetter = function() return ns.db and ns.db.enabled ~= false end,
            moduleEnabledSetter = function(enabled)
                if ns.db then ns.db.enabled = enabled and true or false end
                if ns.SetModuleEnabled then ns.SetModuleEnabled("consumables", enabled, function(v) if ns.db then ns.db.enabled = v end end) end
            end,
            resetHandler = function()
                if not ns.db then
                    return
                end

                ns.db.consumables = ns.db.consumables or {}
                ns.db.consumables.appearance = CopyTableRecursive(consumableDefaults.appearance or {})
                ResetEditModeConfig("reminder", consumablePositionDefaults)
            end,
        }
    )

    local function GetConsumablePositionConfig()
        return GetReminderPositionConfig("reminder", consumablePositionDefaults)
    end

    local appearanceCardTopY = PAGE_SECTION_START_Y
    local typographyCard = CreateSectionCard(
        appearanceContent,
        sectionX,
        appearanceCardTopY,
        sectionWidth,
        172,
        "Typography",
        "Configure the shared font face and outline used by the consumables reminder text elements."
    )
    local buffLabelCard = CreateSectionCard(
        appearanceContent,
        sectionX,
        appearanceCardTopY - 192,
        sectionWidth,
        204,
        "Buff Label",
        "Control the main label shown for flask, food, rune, and weapon buff reminders."
    )
    local timerCard = CreateSectionCard(
        appearanceContent,
        sectionX,
        appearanceCardTopY - 416,
        sectionWidth,
        204,
        "Reapply Timer",
        "Show or hide the red duration text and position it independently from the other reminder text."
    )
    local countCard = CreateSectionCard(
        appearanceContent,
        sectionX,
        appearanceCardTopY - 640,
        sectionWidth,
        238,
        "Bag Count",
        "Control the stack-count text shown on each reminder icon and place it where it reads best for your layout."
    )
    local iconCard = CreateSectionCard(
        appearanceContent,
        sectionX,
        appearanceCardTopY - 898,
        sectionWidth,
        320,
        "Icons",
        "Adjust the icon border, icon size, spacing, and crop amount for the reminder bar."
    )
    local glowCard = CreateSectionCard(
        appearanceContent,
        sectionX,
        appearanceCardTopY - 1138,
        sectionWidth,
        320,
        "Glow",
        "Choose when icon glows appear and tune the glow style for ready checks or persistent reminders."
    )
    local positionCard = CreateSectionCard(
        appearanceContent,
        sectionX,
        appearanceCardTopY - 1478,
        sectionWidth,
        170,
        "Position",
        "Set the exact screen anchor and X/Y pixel offsets used by the consumables reminder bar."
    )
    local borderTextureDropdown = CreateStatusBarTextureDropdown(
        iconCard,
        18,
        -72,
        "Border Texture",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return ns.GetConsumableAppearance().borderTexture
        end,
        function(value)
            ns.GetConsumableAppearance().borderTexture = value
            RequestOptionsRefresh()
        end,
        "Global",
        {
            choiceProvider = ns.GetBorderTextureChoices,
            labelProvider = ns.GetBorderTextureLabel,
            previewMode = "border",
            texturePathResolver = ns.GetBorderTexturePath,
        }
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = borderTextureDropdown

    local borderColorButton = CreateColorButton(
        iconCard,
        18,
        -72,
        "Border Color",
        function()
            return ns.GetConsumableAppearance().borderColor
        end,
        function(value)
            ns.GetConsumableAppearance().borderColor = value
            RequestOptionsRefresh()
        end,
        { hasOpacity = false, width = APPEARANCE_COLUMN_WIDTH }
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = borderColorButton

    local borderSizeSlider = CreateSlider(
        iconCard,
        18,
        -72,
        "Border Size",
        APPEARANCE_COLUMN_WIDTH,
        -10,
        10,
        1,
        function()
            local appearance = ns.GetConsumableAppearance()
            return appearance.borderSize or (appearance.showBorder ~= false and 1 or 0)
        end,
        function(value)
            local appearance = ns.GetConsumableAppearance()
            appearance.borderSize = value
            appearance.showBorder = nil
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = borderSizeSlider

    local fontDropdown = CreateFontDropdown(
        typographyCard,
        18,
        -72,
        "Font",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return ns.GetConsumableAppearance().font
        end,
        function(value)
            ns.GetConsumableAppearance().font = value
            RequestOptionsRefresh()
        end,
        "Friz Quadrata TT"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = fontDropdown

    local fontOutlineDropdown = CreateStaticDropdown(
        typographyCard,
        18,
        -72,
        "Font Outline",
        APPEARANCE_COLUMN_WIDTH,
        function()
            return ns.GetFontOutlineChoices and ns.GetFontOutlineChoices(true) or {}
        end,
        function()
            return ns.GetConsumableAppearance().fontOutline
        end,
        function(value)
            ns.GetConsumableAppearance().fontOutline = value
            RequestOptionsRefresh()
        end,
        "Outline"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = fontOutlineDropdown

    local fontSizeSlider = CreateSlider(
        buffLabelCard,
        18,
        -72,
        "Buff Text Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        24,
        1,
        function()
            return ns.GetConsumableAppearance().labelFontSize or ns.GetConsumableAppearance().fontSize
        end,
        function(value)
            ns.GetConsumableAppearance().labelFontSize = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = fontSizeSlider

    local labelTextCheckbox = CreateCheckbox(
        buffLabelCard,
        "Show Buff Text",
        18,
        -72,
        function()
            return ns.GetConsumableAppearance().labelTextEnabled ~= false
        end,
        function(value)
            ns.GetConsumableAppearance().labelTextEnabled = value and true or false
            RequestOptionsRefresh()
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = labelTextCheckbox

    local labelAnchorDropdown = CreateStaticDropdown(
        buffLabelCard,
        18,
        -72,
        "Buff Text Anchor",
        APPEARANCE_COLUMN_WIDTH,
        TEXT_VERTICAL_ANCHOR_CHOICES,
        function()
            return ns.GetConsumableAppearance().labelAnchor or "bottom"
        end,
        function(value)
            ns.GetConsumableAppearance().labelAnchor = value
            RequestOptionsRefresh()
        end,
        "Bottom"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = labelAnchorDropdown

    local labelOffsetSlider = CreateSlider(
        buffLabelCard,
        18,
        -72,
        "Buff Text Y Offset",
        APPEARANCE_COLUMN_WIDTH,
        -20,
        20,
        1,
        function()
            return ns.GetConsumableAppearance().labelOffsetY or 0
        end,
        function(value)
            ns.GetConsumableAppearance().labelOffsetY = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = labelOffsetSlider

    local durationTextCheckbox = CreateCheckbox(
        timerCard,
        "Show Reapply Timer",
        18,
        -72,
        function()
            return ns.GetConsumableAppearance().durationTextEnabled ~= false
        end,
        function(value)
            ns.GetConsumableAppearance().durationTextEnabled = value and true or false
            RequestOptionsRefresh()
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = durationTextCheckbox

    local durationFontSizeSlider = CreateSlider(
        timerCard,
        18,
        -72,
        "Timer Text Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        24,
        1,
        function()
            return ns.GetConsumableAppearance().durationFontSize or ns.GetConsumableAppearance().fontSize
        end,
        function(value)
            ns.GetConsumableAppearance().durationFontSize = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = durationFontSizeSlider

    local durationAnchorDropdown = CreateStaticDropdown(
        timerCard,
        18,
        -72,
        "Timer Anchor",
        APPEARANCE_COLUMN_WIDTH,
        TEXT_VERTICAL_ANCHOR_CHOICES,
        function()
            return ns.GetConsumableAppearance().durationAnchor or "top"
        end,
        function(value)
            ns.GetConsumableAppearance().durationAnchor = value
            RequestOptionsRefresh()
        end,
        "Top"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = durationAnchorDropdown

    local durationOffsetSlider = CreateSlider(
        timerCard,
        18,
        -72,
        "Timer Y Offset",
        APPEARANCE_COLUMN_WIDTH,
        -20,
        20,
        1,
        function()
            return ns.GetConsumableAppearance().durationOffsetY or 0
        end,
        function(value)
            ns.GetConsumableAppearance().durationOffsetY = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = durationOffsetSlider

    local countTextCheckbox = CreateCheckbox(
        countCard,
        "Show Bag Count",
        18,
        -72,
        function()
            return ns.GetConsumableAppearance().countTextEnabled ~= false
        end,
        function(value)
            ns.GetConsumableAppearance().countTextEnabled = value and true or false
            RequestOptionsRefresh()
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = countTextCheckbox

    local countFontSizeSlider = CreateSlider(
        countCard,
        18,
        -72,
        "Bag Count Size",
        APPEARANCE_COLUMN_WIDTH,
        8,
        24,
        1,
        function()
            return ns.GetConsumableAppearance().countFontSize or math.max(9, (ns.GetConsumableAppearance().labelFontSize or ns.GetConsumableAppearance().fontSize or 12) - 1)
        end,
        function(value)
            ns.GetConsumableAppearance().countFontSize = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = countFontSizeSlider

    local countAnchorDropdown = CreateStaticDropdown(
        countCard,
        18,
        -72,
        "Bag Count Anchor",
        APPEARANCE_COLUMN_WIDTH,
        COUNT_ANCHOR_CHOICES,
        function()
            return ns.GetConsumableAppearance().countAnchor or "bottom_right"
        end,
        function(value)
            ns.GetConsumableAppearance().countAnchor = value
            RequestOptionsRefresh()
        end,
        "Bottom Right"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = countAnchorDropdown

    local countOffsetXSlider = CreateSlider(
        countCard,
        18,
        -72,
        "Bag Count X Offset",
        APPEARANCE_COLUMN_WIDTH,
        -20,
        20,
        1,
        function()
            return ns.GetConsumableAppearance().countOffsetX or 0
        end,
        function(value)
            ns.GetConsumableAppearance().countOffsetX = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = countOffsetXSlider

    local countOffsetYSlider = CreateSlider(
        countCard,
        18,
        -72,
        "Bag Count Y Offset",
        APPEARANCE_COLUMN_WIDTH,
        -20,
        20,
        1,
        function()
            return ns.GetConsumableAppearance().countOffsetY or 0
        end,
        function(value)
            ns.GetConsumableAppearance().countOffsetY = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = countOffsetYSlider

    local iconSizeSlider = CreateSlider(
        iconCard,
        18,
        -72,
        "Icon Size",
        APPEARANCE_COLUMN_WIDTH,
        24,
        72,
        1,
        function()
            return ns.GetConsumableAppearance().iconSize
        end,
        function(value)
            ns.GetConsumableAppearance().iconSize = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = iconSizeSlider

    local iconSpacingSlider = CreateSlider(
        iconCard,
        18,
        -72,
        "Icon Spacing",
        APPEARANCE_COLUMN_WIDTH,
        0,
        24,
        1,
        function()
            return ns.GetConsumableAppearance().spacing
        end,
        function(value)
            ns.GetConsumableAppearance().spacing = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = iconSpacingSlider

    local iconZoomSlider = CreateSlider(
        iconCard,
        18,
        -72,
        "Icon Zoom",
        APPEARANCE_COLUMN_WIDTH,
        0,
        0.45,
        0.01,
        function()
            return ns.GetConsumableAppearance().iconZoom
        end,
        function(value)
            ns.GetConsumableAppearance().iconZoom = value
            RequestOptionsRefresh()
        end,
        function(value)
            return string.format("%d%%", math.floor((value * 100) + 0.5))
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = iconZoomSlider

    local glowDropdown = CreateStaticDropdown(
        glowCard,
        18,
        -72,
        "Glow Trigger",
        COMPACT_DROPDOWN_WIDTH,
        ns.GetGlowChoices(),
        function()
            return ns.GetConsumableAppearance().glowMode
        end,
        function(value)
            ns.GetConsumableAppearance().glowMode = value
            RequestOptionsRefresh()
        end,
        "Ready Check"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowDropdown

    local glowTypeDropdown = CreateStaticDropdown(
        glowCard,
        18,
        -72,
        "Glow Type",
        COMPACT_DROPDOWN_WIDTH,
        ns.GetGlowTypeChoices(),
        function()
            return ns.GetConsumableAppearance().glowType
        end,
        function(value)
            ns.GetConsumableAppearance().glowType = value
            RequestOptionsRefresh()
        end,
        "Proc Glow"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowTypeDropdown

    local glowColorButton = CreateColorButton(
        glowCard,
        18,
        -72,
        "Glow Color",
        function()
            return ns.GetConsumableAppearance().glowColor
        end,
        function(value)
            ns.GetConsumableAppearance().glowColor = value
            RequestOptionsRefresh()
        end,
        { width = COMPACT_COLOR_BUTTON_WIDTH }
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowColorButton

    local readyCheckDurationSlider = CreateSlider(
        glowCard,
        18,
        -72,
        "Ready Check Hold",
        APPEARANCE_COLUMN_WIDTH,
        0,
        15,
        0.5,
        function()
            return ns.GetConsumableAppearance().readyCheckGlowDuration
        end,
        function(value)
            ns.GetConsumableAppearance().readyCheckGlowDuration = value
            RequestOptionsRefresh()
        end,
        function(value)
            return string.format("%.1f s", value)
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = readyCheckDurationSlider

    local glowSpeedSlider = CreateSlider(
        glowCard,
        18,
        -72,
        "Glow Speed",
        APPEARANCE_COLUMN_WIDTH,
        0.2,
        3,
        0.1,
        function()
            return ns.GetConsumableAppearance().glowFrequency
        end,
        function(value)
            ns.GetConsumableAppearance().glowFrequency = value
            RequestOptionsRefresh()
        end,
        function(value)
            return string.format("%.1fx", value)
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowSpeedSlider

    local glowSizeSlider = CreateSlider(
        glowCard,
        18,
        -72,
        "Glow Size",
        APPEARANCE_COLUMN_WIDTH,
        0.6,
        2.5,
        0.1,
        function()
            return ns.GetConsumableAppearance().glowSize
        end,
        function(value)
            ns.GetConsumableAppearance().glowSize = value
            RequestOptionsRefresh()
        end,
        function(value)
            return string.format("%.1fx", value)
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowSizeSlider

    local glowPixelLengthSlider = CreateSlider(
        glowCard,
        18,
        -72,
        "Pixel Length",
        APPEARANCE_COLUMN_WIDTH,
        4,
        32,
        1,
        function()
            return ns.GetConsumableAppearance().glowPixelLength
        end,
        function(value)
            ns.GetConsumableAppearance().glowPixelLength = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0, " px")
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowPixelLengthSlider

    local glowLinesSlider = CreateSlider(
        glowCard,
        18,
        -72,
        "Pixel Lines",
        APPEARANCE_COLUMN_WIDTH,
        4,
        16,
        1,
        function()
            return ns.GetConsumableAppearance().glowPixelLines
        end,
        function(value)
            ns.GetConsumableAppearance().glowPixelLines = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0)
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowLinesSlider

    local glowThicknessSlider = CreateSlider(
        glowCard,
        18,
        -72,
        "Pixel Thickness",
        APPEARANCE_COLUMN_WIDTH,
        1,
        6,
        0.5,
        function()
            return ns.GetConsumableAppearance().glowPixelThickness
        end,
        function(value)
            ns.GetConsumableAppearance().glowPixelThickness = value
            RequestOptionsRefresh()
        end,
        function(value)
            return string.format("%.1f px", value)
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowThicknessSlider

    local glowParticlesSlider = CreateSlider(
        glowCard,
        18,
        -72,
        "Autocast Particles",
        APPEARANCE_COLUMN_WIDTH,
        2,
        8,
        1,
        function()
            return ns.GetConsumableAppearance().glowAutocastParticles
        end,
        function(value)
            ns.GetConsumableAppearance().glowAutocastParticles = value
            RequestOptionsRefresh()
        end,
        function(value)
            return FormatSliderValue(value, 0)
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowParticlesSlider

    local glowProcStartCheckbox = CreateCheckbox(
        glowCard,
        "Start Animation",
        18,
        -72,
        function()
            return ns.GetConsumableAppearance().glowProcStartAnimation ~= false
        end,
        function(value)
            ns.GetConsumableAppearance().glowProcStartAnimation = value
            RequestOptionsRefresh()
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = glowProcStartCheckbox

    local consumablesAnchorDropdown = CreateStaticDropdown(
        positionCard,
        18,
        -82,
        "Anchor Point",
        APPEARANCE_COLUMN_WIDTH,
        REMINDER_POSITION_POINT_CHOICES,
        function()
            return GetConsumablePositionConfig().point
        end,
        function(value)
            GetConsumablePositionConfig().point = NormalizeReminderPointValue(value, consumablePositionDefaults.point)
            RequestOptionsRefresh()
        end,
        "Top"
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = consumablesAnchorDropdown

    local consumablesXSlider = ns.CreateOptionsPositionSlider(
        positionCard,
        18,
        -156,
        "X Position",
        "x",
        function()
            return GetConsumablePositionConfig().x
        end,
        function(value)
            GetConsumablePositionConfig().x = value
            RequestOptionsRefresh()
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = consumablesXSlider

    local consumablesYSlider = ns.CreateOptionsPositionSlider(
        positionCard,
        APPEARANCE_RIGHT_COLUMN_X,
        -156,
        "Y Position",
        "y",
        function()
            return GetConsumablePositionConfig().y
        end,
        function(value)
            GetConsumablePositionConfig().y = value
            RequestOptionsRefresh()
        end
    )
    appearancePanelPage.refreshers[#appearancePanelPage.refreshers + 1] = consumablesYSlider

    local baseAppearancePanelUpdateDisabledState = appearancePanelPage.UpdateDisabledState
    function appearancePanelPage:UpdateDisabledState()
        if baseAppearancePanelUpdateDisabledState then
            baseAppearancePanelUpdateDisabledState(self)
        end

        local appearance = ns.GetConsumableAppearance()
        local glowType = appearance.glowType or "button"
        local glowMode = appearance.glowMode or "ready_check"
        local labelTextEnabled = appearance.labelTextEnabled ~= false
        local durationTextEnabled = appearance.durationTextEnabled ~= false
        local countTextEnabled = appearance.countTextEnabled ~= false
        local glowEnabled = glowMode ~= "never"

        SetControlEnabled(fontSizeSlider, labelTextEnabled)
        SetControlEnabled(labelAnchorDropdown, labelTextEnabled)
        SetControlEnabled(labelOffsetSlider, labelTextEnabled)

        SetControlEnabled(durationFontSizeSlider, durationTextEnabled)
        SetControlEnabled(durationAnchorDropdown, durationTextEnabled)
        SetControlEnabled(durationOffsetSlider, durationTextEnabled)

        SetControlEnabled(countFontSizeSlider, countTextEnabled)
        SetControlEnabled(countAnchorDropdown, countTextEnabled)
        SetControlEnabled(countOffsetXSlider, countTextEnabled)
        SetControlEnabled(countOffsetYSlider, countTextEnabled)

        SetControlEnabled(glowTypeDropdown, glowEnabled)
        SetControlEnabled(glowColorButton, glowEnabled)
        SetControlEnabled(readyCheckDurationSlider, glowEnabled and glowMode == "ready_check")
        SetControlEnabled(glowSpeedSlider, glowEnabled)
        SetControlEnabled(glowSizeSlider, glowEnabled and glowType ~= "pixel")
        SetControlEnabled(glowPixelLengthSlider, glowEnabled and glowType == "pixel")
        SetControlEnabled(glowLinesSlider, glowEnabled and glowType == "pixel")
        SetControlEnabled(glowThicknessSlider, glowEnabled and glowType == "pixel")
        SetControlEnabled(glowParticlesSlider, glowEnabled and glowType == "autocast")
        SetControlEnabled(glowProcStartCheckbox, glowEnabled and glowType == "proc")
    end

    function appearancePanelPage:UpdateAppearanceLayout()
        local panelLeftX = 18
        local panelRightX = APPEARANCE_RIGHT_COLUMN_X
        local glowTypeX = 238
        local glowColorX = 458
        local compactRowHeight = 52
        local standardRowHeight = 74
        local tallRowHeight = 84
        local headerSpacing = 30
        local panelBottomPadding = 34
        local cardSpacing = 20
        local cardContentStartY = -88
        local appearance = ns.GetConsumableAppearance()
        local glowType = appearance.glowType or "button"
        local glowMode = appearance.glowMode or "ready_check"
        local labelTextEnabled = appearance.labelTextEnabled ~= false
        local durationTextEnabled = appearance.durationTextEnabled ~= false
        local countTextEnabled = appearance.countTextEnabled ~= false
        local typographyCardY = appearanceCardTopY

        local function PositionRow(parent, rowY, leftControl, rightControl, leftShown, rightShown, rowHeight)
            local visibleControls = {}

            if leftControl then
                SetControlShown(leftControl, leftShown ~= false)
                if leftShown ~= false then
                    visibleControls[#visibleControls + 1] = leftControl
                end
            end

            if rightControl then
                SetControlShown(rightControl, rightShown ~= false)
                if rightShown ~= false then
                    visibleControls[#visibleControls + 1] = rightControl
                end
            end

            if #visibleControls == 0 then
                return rowY
            end

            if #visibleControls == 1 then
                PositionControl(visibleControls[1], parent, panelLeftX, rowY)
            else
                PositionControl(visibleControls[1], parent, panelLeftX, rowY)
                PositionControl(visibleControls[2], parent, panelRightX, rowY)
            end

            return rowY - rowHeight
        end

        local function PositionGlowHeaderRow(parent, rowY)
            SetControlShown(glowDropdown, true)
            SetControlShown(glowTypeDropdown, true)
            SetControlShown(glowColorButton, true)
            PositionControl(glowDropdown, parent, panelLeftX, rowY)
            PositionControl(glowTypeDropdown, parent, glowTypeX, rowY)
            PositionControl(glowColorButton, parent, glowColorX, rowY)
            return rowY - tallRowHeight
        end

        typographyCard:ClearAllPoints()
        typographyCard:SetPoint("TOPLEFT", appearanceContent, "TOPLEFT", sectionX, typographyCardY)
        local typographyY = cardContentStartY
        typographyY = PositionRow(typographyCard, typographyY, fontDropdown, fontOutlineDropdown, true, true, standardRowHeight)
        local typographyCardHeight = FitSectionCardHeight(typographyCard, panelBottomPadding)

        local buffLabelCardY = typographyCardY - typographyCardHeight - cardSpacing
        buffLabelCard:ClearAllPoints()
        buffLabelCard:SetPoint("TOPLEFT", appearanceContent, "TOPLEFT", sectionX, buffLabelCardY)
        local buffY = cardContentStartY
        buffY = PositionRow(buffLabelCard, buffY, labelTextCheckbox, fontSizeSlider, true, true, standardRowHeight)
        buffY = PositionRow(buffLabelCard, buffY, labelAnchorDropdown, labelOffsetSlider, true, true, tallRowHeight)
        local buffLabelCardHeight = FitSectionCardHeight(buffLabelCard, panelBottomPadding)

        local timerCardY = buffLabelCardY - buffLabelCardHeight - cardSpacing
        timerCard:ClearAllPoints()
        timerCard:SetPoint("TOPLEFT", appearanceContent, "TOPLEFT", sectionX, timerCardY)
        local timerY = cardContentStartY
        timerY = PositionRow(timerCard, timerY, durationTextCheckbox, durationFontSizeSlider, true, true, standardRowHeight)
        timerY = PositionRow(timerCard, timerY, durationAnchorDropdown, durationOffsetSlider, true, true, tallRowHeight)
        local timerCardHeight = FitSectionCardHeight(timerCard, panelBottomPadding)

        local countCardY = timerCardY - timerCardHeight - cardSpacing
        countCard:ClearAllPoints()
        countCard:SetPoint("TOPLEFT", appearanceContent, "TOPLEFT", sectionX, countCardY)
        local countY = cardContentStartY
        countY = PositionRow(countCard, countY, countTextCheckbox, nil, true, false, standardRowHeight)
        countY = PositionRow(countCard, countY, countAnchorDropdown, countFontSizeSlider, true, true, tallRowHeight)
        countY = PositionRow(countCard, countY, countOffsetYSlider, countOffsetXSlider, true, true, standardRowHeight)
        local countCardHeight = FitSectionCardHeight(countCard, panelBottomPadding)

        local iconCardY = countCardY - countCardHeight - cardSpacing
        iconCard:ClearAllPoints()
        iconCard:SetPoint("TOPLEFT", appearanceContent, "TOPLEFT", sectionX, iconCardY)
        local iconY = cardContentStartY
        iconY = PositionRow(iconCard, iconY, borderTextureDropdown, borderSizeSlider, true, true, standardRowHeight)
        iconY = PositionRow(iconCard, iconY, borderColorButton, iconSizeSlider, true, true, standardRowHeight)
        iconY = PositionRow(iconCard, iconY, iconSpacingSlider, iconZoomSlider, true, true, standardRowHeight)
        local iconCardHeight = FitSectionCardHeight(iconCard, panelBottomPadding)

        local glowCardY = iconCardY - iconCardHeight - cardSpacing
        glowCard:ClearAllPoints()
        glowCard:SetPoint("TOPLEFT", appearanceContent, "TOPLEFT", sectionX, glowCardY)
        local glowY = cardContentStartY
        glowY = PositionGlowHeaderRow(glowCard, glowY)
        glowY = PositionRow(glowCard, glowY, readyCheckDurationSlider, nil, glowMode == "ready_check", false, tallRowHeight)
        glowY = PositionRow(glowCard, glowY, glowSpeedSlider, glowSizeSlider, true, glowType ~= "pixel", standardRowHeight)
        glowY = PositionRow(glowCard, glowY, glowPixelLengthSlider, glowLinesSlider, glowType == "pixel", glowType == "pixel", standardRowHeight)
        glowY = PositionRow(glowCard, glowY, glowThicknessSlider, glowParticlesSlider, glowType == "pixel", glowType == "autocast", standardRowHeight)
        glowY = PositionRow(glowCard, glowY, glowProcStartCheckbox, nil, glowType == "proc", false, compactRowHeight)

        local glowCardHeight = FitSectionCardHeight(glowCard, panelBottomPadding)

        local positionCardY = glowCardY - glowCardHeight - cardSpacing
        positionCard:ClearAllPoints()
        positionCard:SetPoint("TOPLEFT", appearanceContent, "TOPLEFT", sectionX, positionCardY)
        local positionY = cardContentStartY
        positionY = PositionRow(positionCard, positionY, consumablesAnchorDropdown, nil, true, false, standardRowHeight)
        positionY = PositionRow(positionCard, positionY, consumablesXSlider, consumablesYSlider, true, true, tallRowHeight)
        FitSectionCardHeight(positionCard, panelBottomPadding)

        FitScrollContentHeight(appearanceContent, appearancePanelPage:GetHeight() - 16, 36)
    end

    end

    local sidebarButtons = {}
    local consumablesSubButtons = {}
    local consumablesExpanded = false
    local classesExpanded = false
    local remindersExpanded = false
    local miscellaneousExpanded = false
    local objectiveTrackerSubButtons = {}
    local objectiveTrackerExpanded = false
    local overviewButton
    local debugButton
    local consumablesButton
    local consumablesToggleButton
    local classesToggleButton
    local remindersButton
    local remindersToggleButton
    local objectiveTrackerButton
    local objectiveTrackerToggleButton
    local otGeneralSubButton
    local otLayoutSubButton
    local otAppearanceSubButton
    local otSectionsSubButton
    local menuBarButton
    local miscellaneousButton
    local miscellaneousToggleButton
    local miscGeneralSubButton
    local miscCutscenesSubButton
    local miscCharStatsSubButton
    local remindersGeneralButton
    local remindersAppearanceButton
    local remindersModulesDivider
    local greatVaultButton
    local dungeonDifficultyButton
    local talentLoadoutButton
    local changeLogButton
    local generalSubButton
    local trackingSubButton
    local appearanceSubButton
    local generalSectionHeader
    local interfaceSectionHeader
    local gameplaySectionHeader
    local sidebarSectionWidth = 206

    local function UpdateSidebarAvailabilityStates()
        local consumablesReason = GetModuleAddonUnavailableReason("consumables")
        local remindersReason = GetModuleAddonUnavailableReason("reminders")
        local objectiveTrackerReason = GetModuleAddonUnavailableReason("objectiveTracker")
        local housingReason = GetModuleAddonUnavailableReason("housing")
        local worldQuestsReason = GetModuleAddonUnavailableReason("worldQuests")
        local miscellaneousReason = GetModuleAddonUnavailableReason("miscellaneous")
        local classesReason = GetModuleAddonUnavailableReason("classesMonk")

        if consumablesReason and consumablesExpanded then
            consumablesExpanded = false
        end
        if classesReason and classesExpanded then
            classesExpanded = false
        end
        if remindersReason and remindersExpanded then
            remindersExpanded = false
        end
        if miscellaneousReason and miscellaneousExpanded then
            miscellaneousExpanded = false
        end
        if objectiveTrackerReason and objectiveTrackerExpanded then
            objectiveTrackerExpanded = false
        end

        consumablesButton:SetAvailable(consumablesReason == nil, consumablesReason)
        consumablesToggleButton:SetAvailable(consumablesReason == nil, consumablesReason)
        generalSubButton:SetAvailable(consumablesReason == nil, consumablesReason)
        trackingSubButton:SetAvailable(consumablesReason == nil, consumablesReason)
        appearanceSubButton:SetAvailable(consumablesReason == nil, consumablesReason)

        sidebarButtons.classes:SetAvailable(classesReason == nil, classesReason)
        classesToggleButton:SetAvailable(classesReason == nil, classesReason)
        sidebarButtons.classes_general:SetAvailable(classesReason == nil, classesReason)
        sidebarButtons.classes_monk:SetAvailable(classesReason == nil, classesReason)

        remindersButton:SetAvailable(remindersReason == nil, remindersReason)
        remindersToggleButton:SetAvailable(remindersReason == nil, remindersReason)
        remindersGeneralButton:SetAvailable(remindersReason == nil, remindersReason)
        remindersAppearanceButton:SetAvailable(remindersReason == nil, remindersReason)
        dungeonDifficultyButton:SetAvailable(remindersReason == nil, remindersReason)
        greatVaultButton:SetAvailable(remindersReason == nil, remindersReason)
        talentLoadoutButton:SetAvailable(remindersReason == nil, remindersReason)

        objectiveTrackerButton:SetAvailable(objectiveTrackerReason == nil, objectiveTrackerReason)
        objectiveTrackerToggleButton:SetAvailable(objectiveTrackerReason == nil, objectiveTrackerReason)
        otGeneralSubButton:SetAvailable(objectiveTrackerReason == nil, objectiveTrackerReason)
        otLayoutSubButton:SetAvailable(objectiveTrackerReason == nil, objectiveTrackerReason)
        otAppearanceSubButton:SetAvailable(objectiveTrackerReason == nil, objectiveTrackerReason)
        otSectionsSubButton:SetAvailable(objectiveTrackerReason == nil, objectiveTrackerReason)

        miscellaneousButton:SetAvailable(miscellaneousReason == nil, miscellaneousReason)
        miscellaneousToggleButton:SetAvailable(miscellaneousReason == nil, miscellaneousReason)
        menuBarButton:SetAvailable(miscellaneousReason == nil, miscellaneousReason)
        miscGeneralSubButton:SetAvailable(miscellaneousReason == nil, miscellaneousReason)
        miscCutscenesSubButton:SetAvailable(miscellaneousReason == nil, miscellaneousReason)
        miscCharStatsSubButton:SetAvailable(miscellaneousReason == nil, miscellaneousReason)
        housingButton:SetAvailable(housingReason == nil, housingReason)
        worldQuestsButton:SetAvailable(worldQuestsReason == nil, worldQuestsReason)
    end

    local function IsConsumablesPage(pageKey)
        return pageKey == "consumables_general" or pageKey == "consumables_tracking" or pageKey == "consumables_appearance" or pageKey == "consumables"
    end

    local function IsGreatVaultPage(pageKey)
        return pageKey == "great_vault"
    end

    local function IsClassesPage(pageKey)
        return pageKey == "classes_general" or pageKey == "classes_monk"
    end

    local function IsChangeLogPage(pageKey)
        return pageKey == "change_log"
    end

    local function IsObjectiveTrackerPage(pageKey)
        return pageKey == "objective_tracker" or
               pageKey == "objective_tracker_general" or
               pageKey == "objective_tracker_layout" or
               pageKey == "objective_tracker_appearance" or
               pageKey == "objective_tracker_sections"
    end

    local function IsMenuBarPage(pageKey)
        return pageKey == "menu_bar"
    end

    local function IsHousingPage(pageKey)
        return pageKey == "housing"
    end

    local function IsWorldQuestsPage(pageKey)
        return pageKey == "world_quests"
    end

    local function IsDungeonDifficultyPage(pageKey)
        return pageKey == "dungeon_difficulty"
    end

    local function IsTalentLoadoutPage(pageKey)
        return pageKey == "talent_loadout"
    end

    local function IsRemindersPage(pageKey)
        return pageKey == "reminders_general" or pageKey == "reminders_appearance" or IsDungeonDifficultyPage(pageKey) or IsGreatVaultPage(pageKey) or IsTalentLoadoutPage(pageKey)
    end

    local function IsMiscellaneousPage(pageKey)
        return pageKey == "menu_bar" or pageKey == "miscellaneous_general" or pageKey == "miscellaneous_cutscenes" or pageKey == "miscellaneous_character_stats"
    end

    local function LayoutSidebarButtons()
        local currentY = -8
        local sectionSpacing = 8

        local function PlaceHeader(header)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 12, currentY)
            currentY = currentY - 30
        end

        local function PlaceButton(button, offsetX, step)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", offsetX or 12, currentY)
            currentY = currentY - (step or 24)
        end

        local function PlaceDivider(divider, offsetX, step)
            divider:ClearAllPoints()
            divider:SetPoint("TOPLEFT", sidebar, "TOPLEFT", offsetX or 12, currentY)
            currentY = currentY - (step or 12)
        end

        PlaceHeader(generalSectionHeader)
        PlaceButton(overviewButton)
        PlaceButton(debugButton)
        PlaceButton(changeLogButton)
        currentY = currentY - sectionSpacing

        PlaceHeader(interfaceSectionHeader)
        PlaceButton(objectiveTrackerButton)

        objectiveTrackerToggleButton:ClearAllPoints()
        objectiveTrackerToggleButton:SetPoint("RIGHT", objectiveTrackerButton, "RIGHT", -4, 0)

        if objectiveTrackerExpanded then
            otGeneralSubButton:Show()
            otLayoutSubButton:Show()
            otAppearanceSubButton:Show()
            otSectionsSubButton:Show()

            PlaceButton(otGeneralSubButton, 24, 20)
            PlaceButton(otLayoutSubButton, 24, 20)
            PlaceButton(otAppearanceSubButton, 24, 20)
            PlaceButton(otSectionsSubButton, 24, 22)
        else
            otGeneralSubButton:Hide()
            otLayoutSubButton:Hide()
            otAppearanceSubButton:Hide()
            otSectionsSubButton:Hide()
        end

        PlaceButton(miscellaneousButton)
        miscellaneousToggleButton:ClearAllPoints()
        miscellaneousToggleButton:SetPoint("RIGHT", miscellaneousButton, "RIGHT", -4, 0)

        if miscellaneousExpanded then
            miscGeneralSubButton:Show()
            menuBarButton:Show()
            miscCutscenesSubButton:Show()
            miscCharStatsSubButton:Show()
            PlaceButton(miscGeneralSubButton, 24, 20)
            PlaceButton(menuBarButton, 24, 20)
            PlaceButton(miscCutscenesSubButton, 24, 20)
            PlaceButton(miscCharStatsSubButton, 24, 22)
        else
            miscGeneralSubButton:Hide()
            menuBarButton:Hide()
            miscCutscenesSubButton:Hide()
            miscCharStatsSubButton:Hide()
        end

        currentY = currentY - sectionSpacing

        PlaceHeader(gameplaySectionHeader)
        PlaceButton(consumablesButton)

        consumablesToggleButton:ClearAllPoints()
        consumablesToggleButton:SetPoint("RIGHT", consumablesButton, "RIGHT", -4, 0)

        if consumablesExpanded then
            generalSubButton:Show()
            trackingSubButton:Show()
            appearanceSubButton:Show()

            PlaceButton(generalSubButton, 24, 20)
            PlaceButton(trackingSubButton, 24, 20)
            PlaceButton(appearanceSubButton, 24, 22)
        else
            generalSubButton:Hide()
            trackingSubButton:Hide()
            appearanceSubButton:Hide()
        end

        PlaceButton(housingButton)

        PlaceButton(worldQuestsButton)

        PlaceButton(sidebarButtons.classes)
        classesToggleButton:ClearAllPoints()
        classesToggleButton:SetPoint("RIGHT", sidebarButtons.classes, "RIGHT", -4, 0)

        if classesExpanded then
            sidebarButtons.classes_general:Show()
            sidebarButtons.classes_monk:Show()
            PlaceButton(sidebarButtons.classes_general, 24, 20)
            PlaceButton(sidebarButtons.classes_monk, 24, 22)
        else
            sidebarButtons.classes_general:Hide()
            sidebarButtons.classes_monk:Hide()
        end

        PlaceButton(remindersButton)
        remindersToggleButton:ClearAllPoints()
        remindersToggleButton:SetPoint("RIGHT", remindersButton, "RIGHT", -4, 0)

        if remindersExpanded then
            remindersGeneralButton:Show()
            remindersAppearanceButton:Show()
            remindersModulesDivider:Show()
            dungeonDifficultyButton:Show()
            greatVaultButton:Show()
            talentLoadoutButton:Show()

            PlaceButton(remindersGeneralButton, 24, 20)
            PlaceButton(remindersAppearanceButton, 24, 20)
            PlaceDivider(remindersModulesDivider, 12, 14)
            PlaceButton(dungeonDifficultyButton, 24, 20)
            PlaceButton(greatVaultButton, 24, 20)
            PlaceButton(talentLoadoutButton, 24, 22)
        else
            remindersGeneralButton:Hide()
            remindersAppearanceButton:Hide()
            remindersModulesDivider:Hide()
            dungeonDifficultyButton:Hide()
            greatVaultButton:Hide()
            talentLoadoutButton:Hide()
        end

        currentY = currentY - sectionSpacing
    end

    local function SetConsumablesExpanded(expanded)
        consumablesExpanded = expanded and true or false
        if consumablesButton and consumablesButton.descriptionText then
            consumablesButton.descriptionText:SetText(consumablesExpanded and "General, tracking, and appearance settings." or "Expand to navigate the consumables module.")
        end
        if consumablesButton and consumablesButton.titleText then
            consumablesButton.titleText:SetText("Consumables")
        end
        if consumablesToggleButton and consumablesToggleButton.SetExpanded then
            consumablesToggleButton:SetExpanded(consumablesExpanded)
        end
        LayoutSidebarButtons()
    end

    local function SetClassesExpanded(expanded)
        classesExpanded = expanded and true or false
        if sidebarButtons.classes and sidebarButtons.classes.descriptionText then
            sidebarButtons.classes.descriptionText:SetText(classesExpanded and "General and class-specific module settings." or "Expand to navigate class modules.")
        end
        if sidebarButtons.classes and sidebarButtons.classes.titleText then
            sidebarButtons.classes.titleText:SetText("Classes")
        end
        if classesToggleButton and classesToggleButton.SetExpanded then
            classesToggleButton:SetExpanded(classesExpanded)
        end
        LayoutSidebarButtons()
    end

    local function SetRemindersExpanded(expanded)
        remindersExpanded = expanded and true or false
        if remindersButton and remindersButton.descriptionText then
            remindersButton.descriptionText:SetText(remindersExpanded and "General, Appearance, Dungeon Difficulty, Great Vault, and Talent Loadout reminder settings." or "Expand to navigate reminder modules.")
        end
        if remindersButton and remindersButton.titleText then
            remindersButton.titleText:SetText("Reminders")
        end
        if remindersToggleButton and remindersToggleButton.SetExpanded then
            remindersToggleButton:SetExpanded(remindersExpanded)
        end
        LayoutSidebarButtons()
    end

    local function SetMiscellaneousExpanded(expanded)
        miscellaneousExpanded = expanded and true or false
        if miscellaneousButton and miscellaneousButton.descriptionText then
            miscellaneousButton.descriptionText:SetText(miscellaneousExpanded and "Menu bar, general, cutscenes, and character stats settings." or "Expand to navigate the Miscellaneous module.")
        end
        if miscellaneousButton and miscellaneousButton.titleText then
            miscellaneousButton.titleText:SetText("Miscellaneous")
        end
        if miscellaneousToggleButton and miscellaneousToggleButton.SetExpanded then
            miscellaneousToggleButton:SetExpanded(miscellaneousExpanded)
        end
        LayoutSidebarButtons()
    end

    local function SetObjectiveTrackerExpanded(expanded)
        objectiveTrackerExpanded = expanded and true or false
        if objectiveTrackerButton and objectiveTrackerButton.descriptionText then
            objectiveTrackerButton.descriptionText:SetText(objectiveTrackerExpanded and "General, layout, appearance, and section settings." or "Expand to navigate the Objective Tracker module.")
        end
        if objectiveTrackerButton and objectiveTrackerButton.titleText then
            objectiveTrackerButton.titleText:SetText("Objective Tracker")
        end
        if objectiveTrackerToggleButton and objectiveTrackerToggleButton.SetExpanded then
            objectiveTrackerToggleButton:SetExpanded(objectiveTrackerExpanded)
        end
        LayoutSidebarButtons()
    end

    window.pages = {
        overview = rootPanel,
        debug = debugPanel,
        change_log = changeLogPanel,
        reminders_general = remindersGeneralPanel,
        reminders_appearance = remindersAppearancePanel,
        dungeon_difficulty = dungeonDifficultyPanel,
        talent_loadout = talentLoadoutPanel,
        great_vault = greatVaultPanel,
        menu_bar = menuBarPanel,
        miscellaneous_general = miscMiscGeneralPanel,
        miscellaneous_cutscenes = miscCutscenesPanel,
        miscellaneous_character_stats = miscCharStatsPanel,
        objective_tracker_general = objectiveTrackerPanel,
        objective_tracker_layout = objectiveTrackerLayoutPanel,
        objective_tracker_appearance = objectiveTrackerAppearancePanel,
        objective_tracker_sections = objectiveTrackerSectionsPanel,
        classes_general = classesGeneralPanel,
        classes_monk = classesMonkPanel,
        housing = housingPanel,
        world_quests = worldQuestsPanel,
        consumables_general = generalPanel,
        consumables_tracking = trackingPanel,
        consumables_appearance = appearancePanelPage,
    }

    for pageKey, page in pairs(window.pages) do
        page.nomtoolsPageKey = pageKey
        if page.content then
            page.content.nomtoolsPageKey = pageKey
        end
    end

    function window:ShowPage(pageKey)
        local requestedPage = pageKey
        if requestedPage == "consumables" then
            requestedPage = "consumables_general"
        elseif requestedPage == "classes" then
            requestedPage = "classes_general"
        elseif requestedPage == "reminders" then
            requestedPage = "reminders_general"
        elseif requestedPage == "objective_tracker" then
            requestedPage = "objective_tracker_general"
        elseif requestedPage == "miscellaneous" then
            requestedPage = "miscellaneous_general"
        elseif requestedPage == "other_general" then
            requestedPage = "miscellaneous_general"
        elseif requestedPage == "other_appearance" then
            requestedPage = "miscellaneous_character_stats"
        end

        local requestedModuleKey = GetOptionsModuleKey(requestedPage)
        if requestedModuleKey and GetModuleAddonUnavailableReason(requestedModuleKey) then
            requestedPage = "overview"
        end

        local resolvedPage = self.pages[requestedPage] and requestedPage or "overview"

        if ns.EnsureOptionsPageDependencies then
            ns.EnsureOptionsPageDependencies(resolvedPage)
        end

        UpdateSidebarAvailabilityStates()

        self.currentPage = resolvedPage
        ns.lastOptionsPage = resolvedPage

        if IsConsumablesPage(resolvedPage) then
            SetConsumablesExpanded(true)
        end
        if IsClassesPage(resolvedPage) then
            SetClassesExpanded(true)
        end
        if IsRemindersPage(resolvedPage) then
            SetRemindersExpanded(true)
        end
        if IsObjectiveTrackerPage(resolvedPage) then
            SetObjectiveTrackerExpanded(true)
        end
        if IsMiscellaneousPage(resolvedPage) then
            SetMiscellaneousExpanded(true)
        end

        for key, page in pairs(self.pages) do
            page:SetShown(key == resolvedPage)
            if key == resolvedPage then
                if page.scrollFrame and page.scrollFrame.SetVerticalScroll then
                    page.scrollFrame:SetVerticalScroll(0)
                end
                SchedulePanelRefresh(page)
            end
        end

        sidebarButtons.overview.isSelected = resolvedPage == "overview"
        sidebarButtons.overview:SetSelected(sidebarButtons.overview.isSelected)
        sidebarButtons.debug.isSelected = resolvedPage == "debug"
        sidebarButtons.debug:SetSelected(sidebarButtons.debug.isSelected)
        sidebarButtons.change_log.isSelected = IsChangeLogPage(resolvedPage)
        sidebarButtons.change_log:SetSelected(sidebarButtons.change_log.isSelected)
        sidebarButtons.consumables.isSelected = IsConsumablesPage(resolvedPage)
        sidebarButtons.consumables:SetSelected(sidebarButtons.consumables.isSelected)
        sidebarButtons.classes.isSelected = IsClassesPage(resolvedPage)
        sidebarButtons.classes:SetSelected(sidebarButtons.classes.isSelected)
        sidebarButtons.reminders.isSelected = IsRemindersPage(resolvedPage)
        sidebarButtons.reminders:SetSelected(sidebarButtons.reminders.isSelected)
        sidebarButtons.objective_tracker.isSelected = IsObjectiveTrackerPage(resolvedPage)
        sidebarButtons.objective_tracker:SetSelected(sidebarButtons.objective_tracker.isSelected)
        sidebarButtons.great_vault.isSelected = IsGreatVaultPage(resolvedPage)
        sidebarButtons.great_vault:SetSelected(sidebarButtons.great_vault.isSelected)
        sidebarButtons.classes_general.isSelected = resolvedPage == "classes_general"
        sidebarButtons.classes_general:SetSelected(sidebarButtons.classes_general.isSelected)
        sidebarButtons.classes_monk.isSelected = resolvedPage == "classes_monk"
        sidebarButtons.classes_monk:SetSelected(sidebarButtons.classes_monk.isSelected)

        sidebarButtons.objective_tracker_general.isSelected = resolvedPage == "objective_tracker_general"
        sidebarButtons.objective_tracker_general:SetSelected(sidebarButtons.objective_tracker_general.isSelected)
        sidebarButtons.objective_tracker_layout.isSelected = resolvedPage == "objective_tracker_layout"
        sidebarButtons.objective_tracker_layout:SetSelected(sidebarButtons.objective_tracker_layout.isSelected)
        sidebarButtons.objective_tracker_appearance.isSelected = resolvedPage == "objective_tracker_appearance"
        sidebarButtons.objective_tracker_appearance:SetSelected(sidebarButtons.objective_tracker_appearance.isSelected)
        sidebarButtons.objective_tracker_sections.isSelected = resolvedPage == "objective_tracker_sections"
        sidebarButtons.objective_tracker_sections:SetSelected(sidebarButtons.objective_tracker_sections.isSelected)
        sidebarButtons.menu_bar.isSelected = IsMenuBarPage(resolvedPage)
        sidebarButtons.menu_bar:SetSelected(sidebarButtons.menu_bar.isSelected)
        sidebarButtons.miscellaneous.isSelected = IsMiscellaneousPage(resolvedPage)
        sidebarButtons.miscellaneous:SetSelected(sidebarButtons.miscellaneous.isSelected)
        sidebarButtons.miscellaneous_general.isSelected = resolvedPage == "miscellaneous_general"
        sidebarButtons.miscellaneous_general:SetSelected(sidebarButtons.miscellaneous_general.isSelected)
        sidebarButtons.miscellaneous_cutscenes.isSelected = resolvedPage == "miscellaneous_cutscenes"
        sidebarButtons.miscellaneous_cutscenes:SetSelected(sidebarButtons.miscellaneous_cutscenes.isSelected)
        sidebarButtons.miscellaneous_character_stats.isSelected = resolvedPage == "miscellaneous_character_stats"
        sidebarButtons.miscellaneous_character_stats:SetSelected(sidebarButtons.miscellaneous_character_stats.isSelected)
        sidebarButtons.housing.isSelected = IsHousingPage(resolvedPage)
        sidebarButtons.housing:SetSelected(sidebarButtons.housing.isSelected)
        sidebarButtons.world_quests.isSelected = IsWorldQuestsPage(resolvedPage)
        sidebarButtons.world_quests:SetSelected(sidebarButtons.world_quests.isSelected)
        sidebarButtons.reminders_general.isSelected = resolvedPage == "reminders_general"
        sidebarButtons.reminders_general:SetSelected(sidebarButtons.reminders_general.isSelected)
        sidebarButtons.reminders_appearance.isSelected = resolvedPage == "reminders_appearance"
        sidebarButtons.reminders_appearance:SetSelected(sidebarButtons.reminders_appearance.isSelected)
        sidebarButtons.dungeon_difficulty.isSelected = IsDungeonDifficultyPage(resolvedPage)
        sidebarButtons.dungeon_difficulty:SetSelected(sidebarButtons.dungeon_difficulty.isSelected)
        sidebarButtons.talent_loadout.isSelected = IsTalentLoadoutPage(resolvedPage)
        sidebarButtons.talent_loadout:SetSelected(sidebarButtons.talent_loadout.isSelected)

        sidebarButtons.consumables_general.isSelected = resolvedPage == "consumables_general"
        sidebarButtons.consumables_general:SetSelected(sidebarButtons.consumables_general.isSelected)
        sidebarButtons.consumables_tracking.isSelected = resolvedPage == "consumables_tracking"
        sidebarButtons.consumables_tracking:SetSelected(sidebarButtons.consumables_tracking.isSelected)
        sidebarButtons.consumables_appearance.isSelected = resolvedPage == "consumables_appearance"
        sidebarButtons.consumables_appearance:SetSelected(sidebarButtons.consumables_appearance.isSelected)

        SetActiveOptionsPreviewPage(resolvedPage, resolvedPage == "menu_bar")
    end

    overviewButton = CreateSidebarButton(sidebar, "Global Settings", "Shared style defaults and launcher visibility.", 194, function()
        window:ShowPage("overview")
    end, {
        pageKey = "overview",
    })
    sidebarButtons.overview = overviewButton

    debugButton = CreateSidebarButton(sidebar, "Debug", "Diagnostic overlays and lightweight profiling controls.", 194, function()
        window:ShowPage("debug")
    end, {
        pageKey = "debug",
    })
    sidebarButtons.debug = debugButton

    changeLogButton = CreateSidebarButton(sidebar, "Change Log", "Read the latest NomTools changes and control login popup behavior.", 194, function()
        window:ShowPage("change_log")
    end, {
        pageKey = "change_log",
    })
    sidebarButtons.change_log = changeLogButton

    generalSectionHeader = CreateSidebarSectionHeader(sidebar, "General", sidebarSectionWidth, 1)
    interfaceSectionHeader = CreateSidebarSectionHeader(sidebar, "Interface", sidebarSectionWidth, 2)
    gameplaySectionHeader = CreateSidebarSectionHeader(sidebar, "Gameplay", sidebarSectionWidth, 3)

    consumablesButton = CreateSidebarButton(sidebar, "Consumables", "Expand to navigate the consumables module.", 194, function()
        if not consumablesExpanded then
            SetConsumablesExpanded(true)
            window:ShowPage("consumables_general")
            return
        end

        window:ShowPage("consumables_general")
    end, {
        pageKeys = { "consumables_general", "consumables_tracking", "consumables_appearance" },
    })
    consumablesButton.titleText:ClearAllPoints()
    consumablesButton.titleText:SetPoint("LEFT", consumablesButton, "LEFT", 8, 2)
    consumablesButton.titleText:SetPoint("RIGHT", consumablesButton, "RIGHT", -56, 2)
    sidebarButtons.consumables = consumablesButton

    consumablesToggleButton = CreateSidebarToggleButton(sidebar, 16, 16, function()
        SetConsumablesExpanded(not consumablesExpanded)
    end)
    consumablesToggleButton:SetFrameLevel(consumablesButton:GetFrameLevel() + 5)

    sidebarButtons.classes = CreateSidebarButton(sidebar, "Classes", "Expand to navigate class modules.", 194, function()
        if not classesExpanded then
            SetClassesExpanded(true)
            window:ShowPage("classes_general")
            return
        end

        window:ShowPage("classes_general")
    end, {
        pageKeys = { "classes_general", "classes_monk" },
    })
    sidebarButtons.classes.titleText:ClearAllPoints()
    sidebarButtons.classes.titleText:SetPoint("LEFT", sidebarButtons.classes, "LEFT", 8, 2)
    sidebarButtons.classes.titleText:SetPoint("RIGHT", sidebarButtons.classes, "RIGHT", -56, 2)

    classesToggleButton = CreateSidebarToggleButton(sidebar, 16, 16, function()
        SetClassesExpanded(not classesExpanded)
    end)
    classesToggleButton:SetFrameLevel(sidebarButtons.classes:GetFrameLevel() + 5)

    sidebarButtons.classes_general = CreateSidebarSubButton(sidebar, "General", 182, function()
        window:ShowPage("classes_general")
    end, {
        pageKey = "classes_general",
    })

    sidebarButtons.classes_monk = CreateSidebarSubButton(sidebar, "Monk", 182, function()
        window:ShowPage("classes_monk")
    end, {
        pageKey = "classes_monk",
    })

    remindersButton = CreateSidebarButton(sidebar, "Reminders", "Expand to navigate reminder modules.", 194, function()
        if not remindersExpanded then
            SetRemindersExpanded(true)
            window:ShowPage("reminders_general")
            return
        end

        window:ShowPage("reminders_general")
    end, {
        pageKeys = { "reminders_general", "reminders_appearance", "dungeon_difficulty", "great_vault", "talent_loadout" },
    })
    remindersButton.titleText:ClearAllPoints()
    remindersButton.titleText:SetPoint("LEFT", remindersButton, "LEFT", 8, 2)
    remindersButton.titleText:SetPoint("RIGHT", remindersButton, "RIGHT", -56, 2)
    sidebarButtons.reminders = remindersButton

    remindersToggleButton = CreateSidebarToggleButton(sidebar, 16, 16, function()
        SetRemindersExpanded(not remindersExpanded)
    end)
    remindersToggleButton:SetFrameLevel(remindersButton:GetFrameLevel() + 5)

    objectiveTrackerButton = CreateSidebarButton(sidebar, "Objective Tracker", "Expand to navigate the Objective Tracker module.", 194, function()
        if not objectiveTrackerExpanded then
            SetObjectiveTrackerExpanded(true)
            window:ShowPage("objective_tracker_general")
            return
        end

        window:ShowPage("objective_tracker_general")
    end, {
        pageKeys = {
            "objective_tracker_general",
            "objective_tracker_layout",
            "objective_tracker_appearance",
            "objective_tracker_sections",
        },
    })
    objectiveTrackerButton.titleText:ClearAllPoints()
    objectiveTrackerButton.titleText:SetPoint("LEFT", objectiveTrackerButton, "LEFT", 8, 2)
    objectiveTrackerButton.titleText:SetPoint("RIGHT", objectiveTrackerButton, "RIGHT", -56, 2)
    sidebarButtons.objective_tracker = objectiveTrackerButton

    objectiveTrackerToggleButton = CreateSidebarToggleButton(sidebar, 16, 16, function()
        SetObjectiveTrackerExpanded(not objectiveTrackerExpanded)
    end)
    objectiveTrackerToggleButton:SetFrameLevel(objectiveTrackerButton:GetFrameLevel() + 5)

    otGeneralSubButton = CreateSidebarSubButton(sidebar, "General", 182, function()
        window:ShowPage("objective_tracker_general")
    end, {
        pageKey = "objective_tracker_general",
    })
    sidebarButtons.objective_tracker_general = otGeneralSubButton
    objectiveTrackerSubButtons[#objectiveTrackerSubButtons + 1] = otGeneralSubButton

    otLayoutSubButton = CreateSidebarSubButton(sidebar, "Size & Position", 182, function()
        window:ShowPage("objective_tracker_layout")
    end, {
        pageKey = "objective_tracker_layout",
    })
    sidebarButtons.objective_tracker_layout = otLayoutSubButton
    objectiveTrackerSubButtons[#objectiveTrackerSubButtons + 1] = otLayoutSubButton

    otAppearanceSubButton = CreateSidebarSubButton(sidebar, "Appearance", 182, function()
        window:ShowPage("objective_tracker_appearance")
    end, {
        pageKey = "objective_tracker_appearance",
    })
    sidebarButtons.objective_tracker_appearance = otAppearanceSubButton
    objectiveTrackerSubButtons[#objectiveTrackerSubButtons + 1] = otAppearanceSubButton

    otSectionsSubButton = CreateSidebarSubButton(sidebar, "Sections", 182, function()
        window:ShowPage("objective_tracker_sections")
    end, {
        pageKey = "objective_tracker_sections",
    })
    sidebarButtons.objective_tracker_sections = otSectionsSubButton
    objectiveTrackerSubButtons[#objectiveTrackerSubButtons + 1] = otSectionsSubButton

    menuBarButton = CreateSidebarSubButton(sidebar, "Menu Bar", 182, function()
        window:ShowPage("menu_bar")
    end, {
        pageKey = "menu_bar",
    })
    sidebarButtons.menu_bar = menuBarButton

    miscellaneousButton = CreateSidebarButton(sidebar, "Miscellaneous", "Expand to navigate the Miscellaneous module.", 194, function()
        if not miscellaneousExpanded then
            SetMiscellaneousExpanded(true)
            window:ShowPage("miscellaneous_general")
            return
        end
        window:ShowPage("miscellaneous_general")
    end, {
        pageKeys = { "menu_bar", "miscellaneous_general", "miscellaneous_cutscenes", "miscellaneous_character_stats" },
    })
    miscellaneousButton.titleText:ClearAllPoints()
    miscellaneousButton.titleText:SetPoint("LEFT", miscellaneousButton, "LEFT", 8, 2)
    miscellaneousButton.titleText:SetPoint("RIGHT", miscellaneousButton, "RIGHT", -56, 2)
    sidebarButtons.miscellaneous = miscellaneousButton

    miscellaneousToggleButton = CreateSidebarToggleButton(sidebar, 16, 16, function()
        SetMiscellaneousExpanded(not miscellaneousExpanded)
    end)
    miscellaneousToggleButton:SetFrameLevel(miscellaneousButton:GetFrameLevel() + 5)

    miscGeneralSubButton = CreateSidebarSubButton(sidebar, "General", 182, function()
        window:ShowPage("miscellaneous_general")
    end, {
        pageKey = "miscellaneous_general",
    })
    sidebarButtons.miscellaneous_general = miscGeneralSubButton

    miscCutscenesSubButton = CreateSidebarSubButton(sidebar, "Cutscenes", 182, function()
        window:ShowPage("miscellaneous_cutscenes")
    end, {
        pageKey = "miscellaneous_cutscenes",
    })
    sidebarButtons.miscellaneous_cutscenes = miscCutscenesSubButton

    miscCharStatsSubButton = CreateSidebarSubButton(sidebar, "Character Stats", 182, function()
        window:ShowPage("miscellaneous_character_stats")
    end, {
        pageKey = "miscellaneous_character_stats",
    })
    sidebarButtons.miscellaneous_character_stats = miscCharStatsSubButton

    housingButton = CreateSidebarButton(sidebar, "Housing", "Custom sort and new-item markers in the housing editor.", 194, function()
        window:ShowPage("housing")
    end, {
        pageKey = "housing",
    })
    worldQuestsButton = CreateSidebarButton(sidebar, "World Quests", "Scrollable world quest list panel inside the world map.", 194, function()
        window:ShowPage("world_quests")
    end, {
        pageKey = "world_quests",
    })
    sidebarButtons.world_quests = worldQuestsButton

    sidebarButtons.housing = housingButton

    remindersGeneralButton = CreateSidebarSubButton(sidebar, "General", 182, function()
        window:ShowPage("reminders_general")
    end, {
        pageKey = "reminders_general",
    })
    sidebarButtons.reminders_general = remindersGeneralButton

    remindersAppearanceButton = CreateSidebarSubButton(sidebar, "Appearance", 182, function()
        window:ShowPage("reminders_appearance")
    end, {
        pageKey = "reminders_appearance",
    })
    sidebarButtons.reminders_appearance = remindersAppearanceButton

    remindersModulesDivider = CreateSidebarDivider(sidebar, 194)

    dungeonDifficultyButton = CreateSidebarSubButton(sidebar, "Dungeon Difficulty", 182, function()
        window:ShowPage("dungeon_difficulty")
    end, {
        pageKey = "dungeon_difficulty",
    })
    sidebarButtons.dungeon_difficulty = dungeonDifficultyButton

    greatVaultButton = CreateSidebarSubButton(sidebar, "Great Vault", 182, function()
        window:ShowPage("great_vault")
    end, {
        pageKey = "great_vault",
    })
    sidebarButtons.great_vault = greatVaultButton

    talentLoadoutButton = CreateSidebarSubButton(sidebar, "Talent Loadout", 182, function()
        window:ShowPage("talent_loadout")
    end, {
        pageKey = "talent_loadout",
    })
    sidebarButtons.talent_loadout = talentLoadoutButton

    generalSubButton = CreateSidebarSubButton(sidebar, "General", 182, function()
        window:ShowPage("consumables_general")
    end, {
        pageKey = "consumables_general",
    })
    sidebarButtons.consumables_general = generalSubButton
    consumablesSubButtons[#consumablesSubButtons + 1] = generalSubButton

    trackingSubButton = CreateSidebarSubButton(sidebar, "Tracking", 182, function()
        window:ShowPage("consumables_tracking")
    end, {
        pageKey = "consumables_tracking",
    })
    sidebarButtons.consumables_tracking = trackingSubButton
    consumablesSubButtons[#consumablesSubButtons + 1] = trackingSubButton

    appearanceSubButton = CreateSidebarSubButton(sidebar, "Appearance", 182, function()
        window:ShowPage("consumables_appearance")
    end, {
        pageKey = "consumables_appearance",
    })
    sidebarButtons.consumables_appearance = appearanceSubButton
    consumablesSubButtons[#consumablesSubButtons + 1] = appearanceSubButton

    sidebarButtons.discord = CreateSidebarButton(sidebar, "Discord", "Join the NomTools Discord.", 194, function()
        local popupKey = addonName .. "DiscordInvite"
        local function GetDiscordPopupEditBox(dialog)
            if not dialog then
                return nil
            end

            if dialog.GetEditBox then
                return dialog:GetEditBox()
            end

            return dialog.editBox
        end

        if StaticPopupDialogs and not StaticPopupDialogs[popupKey] then
            StaticPopupDialogs[popupKey] = {
                text = "Join the NomTools Discord. Copy the invite link below.",
                button1 = CLOSE,
                hasEditBox = 1,
                editBoxWidth = 260,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
                OnShow = function(self)
                    local editBox = GetDiscordPopupEditBox(self)
                    if not editBox then
                        return
                    end

                    editBox:SetAutoFocus(false)
                    editBox:SetText("https://discord.gg/FVuJ3XSwxQ")
                    editBox:HighlightText()
                    editBox:SetFocus()
                end,
                EditBoxOnEnterPressed = function(self)
                    self:HighlightText()
                end,
                EditBoxOnEscapePressed = function(self)
                    self:GetParent():Hide()
                end,
                OnHide = function(self)
                    local editBox = GetDiscordPopupEditBox(self)
                    if editBox then
                        editBox:SetText("")
                    end
                end,
            }
        end

        if StaticPopup_Show then
            local dialog = StaticPopup_Show(popupKey)
            local editBox = GetDiscordPopupEditBox(dialog)
            if editBox then
                editBox:SetText("https://discord.gg/FVuJ3XSwxQ")
                editBox:HighlightText()
                editBox:SetFocus()
            end
        end
    end)
    sidebarButtons.discord:ClearAllPoints()
    sidebarButtons.discord:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 12, 12)
    sidebarButtons.discord.icon = sidebarButtons.discord:CreateTexture(nil, "ARTWORK")
    sidebarButtons.discord.icon:SetPoint("LEFT", sidebarButtons.discord, "LEFT", 8, 0)
    sidebarButtons.discord.icon:SetSize(16, 16)
    sidebarButtons.discord.icon:SetTexture("Interface\\AddOns\\NomTools\\media\\discord.png")
    sidebarButtons.discord.titleText:ClearAllPoints()
    sidebarButtons.discord.titleText:SetPoint("LEFT", sidebarButtons.discord.icon, "RIGHT", 6, 2)
    sidebarButtons.discord.titleText:SetPoint("RIGHT", sidebarButtons.discord, "RIGHT", -8, 2)
    sidebarButtons.discord.titleText:SetText("Discord")

    SetConsumablesExpanded(false)
    SetClassesExpanded(false)
    SetRemindersExpanded(false)
    SetObjectiveTrackerExpanded(false)
    SetMiscellaneousExpanded(false)
    UpdateSidebarAvailabilityStates()


    function ns.RefreshOptionsPanel()
        if not ns.optionsWindow or not ns.optionsWindow.IsShown or not ns.optionsWindow:IsShown() then
            return
        end

        UpdateSidebarAvailabilityStates()

        if ns.optionsWindow.currentPage and ns.optionsWindow.pages then
            local currentPage = ns.optionsWindow.pages[ns.optionsWindow.currentPage]
            if currentPage then
                SchedulePanelRefresh(currentPage)
                return
            end
        end
    end

    function ns.ShowOptionsWindow(pageKey)
        if not ns.optionsWindow then
            return
        end

        local targetPage = pageKey or ns.lastOptionsPage or "overview"

        if not ns.optionsWindow:IsShown() then
            ns.optionsWindow:ShowPage(targetPage)

            if ns.optionsWindow.RestoreSavedPosition then
                ns.optionsWindow:RestoreSavedPosition()
            end
            ns.optionsWindow:Show()
            ns.optionsWindow:Raise()
            return
        end

        ns.optionsWindow:Show()
        ns.optionsWindow:Raise()
        ns.optionsWindow:ShowPage(targetPage)
    end

    generalPanel:RefreshAll()
    debugPanel:RefreshAll()
    if changeLogPanel and changeLogPanel.RefreshAll then
        changeLogPanel:RefreshAll()
    end
    if remindersGeneralPanel and remindersGeneralPanel.RefreshAll then
        remindersGeneralPanel:RefreshAll()
    end
    if classesGeneralPanel and classesGeneralPanel.RefreshAll then
        classesGeneralPanel:RefreshAll()
    end
    if classesMonkPanel and classesMonkPanel.RefreshAll then
        classesMonkPanel:RefreshAll()
    end
    greatVaultPanel:RefreshAll()
    menuBarPanel:RefreshAll()
    miscCutscenesPanel:RefreshAll()
    miscCharStatsPanel:RefreshAll()
    trackingPanel:RefreshAll()
    appearancePanelPage:RefreshAll()
    housingPanel:RefreshAll()
    objectiveTrackerPanel:RefreshAll()
    objectiveTrackerLayoutPanel:RefreshAll()
    objectiveTrackerAppearancePanel:RefreshAll()
    objectiveTrackerSectionsPanel:RefreshAll()
    SchedulePanelRefresh(generalPanel)
    window:ShowPage(ns.lastOptionsPage or "overview")
end
