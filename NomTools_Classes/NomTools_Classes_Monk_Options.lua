local addonName, ns = ...
local _G = _G

if addonName ~= "NomTools" then
    ns = _G["NomTools"]
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

do
    local CreateFrame = CreateFrame
    local floor = math.floor
    local strmatch = string.match
    local TAB_HEIGHT = 28
    local TAB_SPACING = 8
    local TAB_BOTTOM_SPACING = 18
    local TEXT_INPUT_BACKDROP = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3,
        },
    }
    local TAB_BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0,
        },
    }
    local EXPEL_HARM_TAB_KEY = "expel_harm_bar"
    local EXPEL_HARM_TAB_LABEL = "Expel Harm Bar"
    local VISIBILITY_CHOICES = ns.MONK_CHI_BAR_VISIBILITY_CHOICES or {
        { key = "always", name = "Always" },
        { key = "combat", name = "Only In Combat" },
    }

    local function MarkMeasured(object)
        if object then
            object.nomtoolsMeasure = true
        end

        return object
    end

    local function NormalizeFrameInput(value)
        if type(value) ~= "string" then
            return ""
        end

        return strmatch(value, "^%s*(.-)%s*$") or ""
    end

    ---@param parent Frame
    ---@param text string
    ---@param width number
    ---@param onClick fun()
    ---@return Button
    local function CreateMonkTabButton(parent, text, width, onClick)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(width, TAB_HEIGHT)
        button:SetBackdrop(TAB_BACKDROP)
        MarkMeasured(button)

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetText(text)
        button.label = label

        function button:SetSelected(selected)
            self.isSelected = selected and true or false
            if self.isSelected then
                self:SetBackdropColor(0.08, 0.12, 0.10, 0.98)
                self:SetBackdropBorderColor(0.38, 0.86, 0.62, 0.95)
                self.label:SetTextColor(0.38, 0.86, 0.62)
                return
            end

            self:SetBackdropColor(0.07, 0.08, 0.09, 0.98)
            self:SetBackdropBorderColor(0.28, 0.31, 0.36, 0.9)
            self.label:SetTextColor(0.76, 0.80, 0.86)
        end

        button:SetScript("OnClick", function()
            onClick()
        end)
        button:SetScript("OnEnter", function(self)
            if self.isSelected then
                return
            end

            self:SetBackdropColor(0.10, 0.11, 0.12, 0.98)
            if _G["HIGHLIGHT_FONT_COLOR"] then
                self.label:SetTextColor(_G["HIGHLIGHT_FONT_COLOR"]:GetRGB())
            else
                self.label:SetTextColor(1, 1, 1)
            end
        end)
        button:SetScript("OnLeave", function(self)
            self:SetSelected(self.isSelected)
        end)

        button:SetSelected(false)
        return button
    end

    ---@param parent any
    ---@param x number
    ---@param y number
    ---@param labelText string
    ---@param width number
    ---@param getter fun(): string
    ---@param setter fun(value: string)
    ---@return Frame
    local function CreateMonkTextInput(parent, x, y, labelText, width, getter, setter)
        if parent and parent.nomtoolsSectionCard then
            y = y + (parent.nomtoolsContentYOffset or 0)
        end

        local control = CreateFrame("Frame", nil, parent)
        control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        control:SetSize(width, 58)
        MarkMeasured(control)

        local label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)
        label:SetText(labelText)
        label:SetTextColor(0.82, 0.82, 0.82)
        control.label = label

        local editBox = CreateFrame("EditBox", nil, control, "BackdropTemplate")
        editBox:SetAutoFocus(false)
        editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
        editBox:SetSize(width, 26)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetJustifyH("LEFT")
        editBox:SetTextColor(0.82, 0.82, 0.82)
        editBox:SetBackdrop(TEXT_INPUT_BACKDROP)
        editBox:SetBackdropColor(0.00, 0.00, 0.00, 0.90)
        editBox:SetBackdropBorderColor(0.28, 0.31, 0.36, 0.90)
        if editBox.SetTextInsets then
            editBox:SetTextInsets(8, 8, 0, 0)
        end
        control.editBox = editBox

        local function CommitValue(self)
            setter(NormalizeFrameInput(self:GetText()))
        end

        editBox:SetScript("OnEnterPressed", function(self)
            CommitValue(self)
            self:ClearFocus()
        end)
        editBox:SetScript("OnEscapePressed", function(self)
            self:SetText(NormalizeFrameInput(getter()))
            self:ClearFocus()
        end)
        editBox:SetScript("OnEditFocusLost", function(self)
            CommitValue(self)
        end)

        control.Refresh = function(self)
            if self.editBox and self.editBox:HasFocus() then
                return
            end

            self.editBox:SetText(NormalizeFrameInput(getter()))
        end

        return control
    end

    local function SetMonkTextInputEnabled(control, enabled)
        if not control then
            return
        end

        local alpha = enabled and 1 or 0.45
        control:SetAlpha(alpha)
        if control.label then
            control.label:SetAlpha(alpha)
        end

        if control.editBox then
            if control.editBox.SetEnabled then
                control.editBox:SetEnabled(enabled)
            elseif control.editBox.EnableMouse then
                control.editBox:EnableMouse(enabled)
            end
            control.editBox:SetAlpha(enabled and 1 or 0.60)
        end
    end

    function ns.CreateClassesMonkOptionsPage(context)
        if type(context) ~= "table" or type(context.CreateModulePage) ~= "function" then
            return nil
        end

        local monkDefaults = ns.DEFAULTS and ns.DEFAULTS.classes and ns.DEFAULTS.classes.monk or {
            moduleEnabled = true,
            enabled = false,
        }
        local standaloneDefaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.monkChiBar or {
            point = "CENTER",
            x = 0,
            y = -160,
        }

        local function GetSettings()
            return ns.GetMonkChiBarSettings and ns.GetMonkChiBarSettings() or monkDefaults
        end

        local function GetVisibilitySettings()
            local settings = GetSettings()
            settings.visibility = type(settings.visibility) == "table" and settings.visibility or {}
            return settings.visibility
        end

        local function GetAttachSettings()
            local settings = GetSettings()
            settings.attach = type(settings.attach) == "table" and settings.attach or {}
            return settings.attach
        end

        local function GetAppearanceSettings()
            local settings = GetSettings()
            settings.appearance = type(settings.appearance) == "table" and settings.appearance or {}
            return settings.appearance
        end

        local function GetStandaloneConfig()
            return ns.GetEditModeConfig and ns.GetEditModeConfig("monkChiBar", standaloneDefaults) or standaloneDefaults
        end

        local function IsMonkModuleEnabled()
            return GetSettings().moduleEnabled == true
        end

        local function IsClassesModuleConfiguredEnabled()
            local settings = ns.GetClassesSettings and ns.GetClassesSettings() or nil
            return settings and settings.enabled == true or false
        end

        local function IsClassesModuleActiveInSession()
            local settings = ns.GetClassesSettings and ns.GetClassesSettings() or nil
            if not settings then
                return false
            end

            if ns.IsModuleActiveInSession then
                return ns.IsModuleActiveInSession("classesMonk")
            end

            return settings.enabled == true
        end

        local function SyncMonkPreviewState()
            if not context.SetActiveOptionsPreviewPage then
                return
            end

            local settings = GetSettings()
            if IsClassesModuleActiveInSession() and settings.moduleEnabled == true and settings.enabled == true then
                context.SetActiveOptionsPreviewPage("classes_monk")
            else
                context.SetActiveOptionsPreviewPage(nil)
            end
        end

        local page, content = context.CreateModulePage(
            "NomToolsClassesMonkPanel",
            "Classes",
            "Monk",
            "Display-only Brewmaster Expel Harm tracker with safe attachment targets and a standalone Edit Mode fallback.",
            {
                showEditModeButton = true,
                moduleEnabledGetter = function()
                    return IsClassesModuleConfiguredEnabled()
                end,
                moduleEnabledSetter = function(value)
                    local classesSettings = ns.GetClassesSettings and ns.GetClassesSettings() or nil
                    if not classesSettings then
                        return
                    end

                    if ns.SetModuleEnabled then
                        ns.SetModuleEnabled("classesMonk", value, function(enabled)
                            classesSettings.enabled = enabled and true or false
                        end, { forceReloadPrompt = true })
                    else
                        classesSettings.enabled = value and true or false
                    end

                    SyncMonkPreviewState()
                end,
                resetHandler = function()
                    if not ns.db then
                        return
                    end

                    ns.db.classes = ns.db.classes or {}
                    ns.db.classes.monk = ns.CopyTableRecursive and ns.CopyTableRecursive(monkDefaults) or monkDefaults

                    local standaloneConfig = ns.GetEditModeConfig and ns.GetEditModeConfig("monkChiBar", standaloneDefaults) or nil
                    if type(standaloneConfig) == "table" then
                        for key in pairs(standaloneConfig) do
                            standaloneConfig[key] = nil
                        end
                        for key, value in pairs(standaloneDefaults) do
                            standaloneConfig[key] = ns.CopyTableRecursive and ns.CopyTableRecursive(value) or value
                        end
                    end

                    SyncMonkPreviewState()
                end,
            }
        )

        local function RefreshMonkOptionsPanel()
            if ns.RequestRefresh then
                ns.RequestRefresh("classesMonk")
            end
            if page and page.RefreshAll then
                page:RefreshAll()
            end
        end

        local tabStrip = CreateFrame("Frame", nil, content)
        tabStrip:SetSize(context.sectionWidth, TAB_HEIGHT)
        MarkMeasured(tabStrip)

        local moduleEnabledCheckbox = context.CreateCheckbox(
            content,
            "Enable Monk Module",
            context.sectionX,
            context.PAGE_SECTION_START_Y,
            function()
                return IsMonkModuleEnabled()
            end,
            function(value)
                local settings = GetSettings()
                settings.moduleEnabled = value and true or false
                SyncMonkPreviewState()
                RefreshMonkOptionsPanel()
            end
        )
        page.refreshers[#page.refreshers + 1] = moduleEnabledCheckbox

        local tabDivider = tabStrip:CreateTexture(nil, "ARTWORK")
        tabDivider:SetColorTexture(0.28, 0.31, 0.36, 0.85)
        tabDivider:SetPoint("BOTTOMLEFT", tabStrip, "BOTTOMLEFT", 0, -8)
        tabDivider:SetPoint("BOTTOMRIGHT", tabStrip, "BOTTOMRIGHT", 0, -8)
        tabDivider:SetHeight(1)

        local generalCard = context.CreateSectionCard(
            content,
            context.sectionX,
            -96,
            context.sectionWidth,
            190,
            "General",
            "Controls the Brewmaster-only Expel Harm tracker. The bar uses Blizzard's Expel Harm stack count and still previews correctly in options and Edit Mode on other Monk specializations."
        )

        local appearanceCard = context.CreateSectionCard(
            content,
            context.sectionX,
            -306,
            context.sectionWidth,
            506,
            "Appearance",
            "Adjust the fill, background, charge dividers, and border used by the Brewmaster Expel Harm tracker."
        )

        local positionCard = context.CreateSectionCard(
            content,
            context.sectionX,
            -832,
            context.sectionWidth,
            760,
            "Attachment & Size",
            "Attachment settings move only the Expel Harm bar. Standalone placement below is the Edit Mode fallback used whenever the selected target cannot be resolved safely."
        )

        local enabledCheckbox = context.CreateCheckbox(
            generalCard,
            "Enable Brewmaster Expel Harm Bar",
            18,
            -82,
            function()
                return GetSettings().enabled == true
            end,
            function(value)
                local settings = GetSettings()
                settings.enabled = value and true or false
                SyncMonkPreviewState()
                RefreshMonkOptionsPanel()
            end
        )
        page.refreshers[#page.refreshers + 1] = enabledCheckbox

        local visibilityDropdown = context.CreateStaticDropdown(
            generalCard,
            18,
            -122,
            "Visibility",
            context.APPEARANCE_COLUMN_WIDTH,
            VISIBILITY_CHOICES,
            function()
                return GetVisibilitySettings().mode
            end,
            function(value)
                GetVisibilitySettings().mode = value
                RefreshMonkOptionsPanel()
            end,
            "Only In Combat"
        )
        page.refreshers[#page.refreshers + 1] = visibilityDropdown

        local skyridingCheckbox = context.CreateCheckbox(
            generalCard,
            "Hide While Skyriding",
            context.APPEARANCE_RIGHT_COLUMN_X,
            -122,
            function()
                return GetVisibilitySettings().hideWhileSkyriding ~= false
            end,
            function(value)
                GetVisibilitySettings().hideWhileSkyriding = value and true or false
                RefreshMonkOptionsPanel()
            end
        )
        page.refreshers[#page.refreshers + 1] = skyridingCheckbox

        local textureDropdown = context.CreateStatusBarTextureDropdown(
            appearanceCard,
            18,
            -82,
            "Bar Texture",
            context.APPEARANCE_COLUMN_WIDTH,
            function()
                return GetAppearanceSettings().texture
            end,
            function(value)
                GetAppearanceSettings().texture = value
                RefreshMonkOptionsPanel()
            end,
            "Default Status Bar"
        )
        page.refreshers[#page.refreshers + 1] = textureDropdown

        local borderTextureDropdown = context.CreateStatusBarTextureDropdown(
            appearanceCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -82,
            "Border Texture",
            context.APPEARANCE_COLUMN_WIDTH,
            function()
                return GetAppearanceSettings().borderTexture
            end,
            function(value)
                GetAppearanceSettings().borderTexture = value
                RefreshMonkOptionsPanel()
            end,
            "Global",
            {
                choiceProvider = ns.GetBorderTextureChoices,
                labelProvider = ns.GetBorderTextureLabel,
                previewMode = "border",
                texturePathResolver = ns.GetBorderTexturePath,
            }
        )
        page.refreshers[#page.refreshers + 1] = borderTextureDropdown

        local activeColorButton = context.CreateColorButton(
            appearanceCard,
            18,
            -156,
            "Fill Color",
            function()
                return GetAppearanceSettings().activeColor
            end,
            function(value)
                GetAppearanceSettings().activeColor = value
                RefreshMonkOptionsPanel()
            end,
            { width = context.APPEARANCE_COLUMN_WIDTH }
        )
        page.refreshers[#page.refreshers + 1] = activeColorButton

        local backgroundColorButton = context.CreateColorButton(
            appearanceCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -156,
            "Background Color",
            function()
                return GetAppearanceSettings().backgroundColor
            end,
            function(value)
                GetAppearanceSettings().backgroundColor = value
                RefreshMonkOptionsPanel()
            end,
            { width = context.APPEARANCE_COLUMN_WIDTH }
        )
        page.refreshers[#page.refreshers + 1] = backgroundColorButton

        local borderColorButton = context.CreateColorButton(
            appearanceCard,
            18,
            -230,
            "Border Color",
            function()
                return GetAppearanceSettings().borderColor
            end,
            function(value)
                GetAppearanceSettings().borderColor = value
                RefreshMonkOptionsPanel()
            end,
            { hasOpacity = false, width = context.APPEARANCE_COLUMN_WIDTH }
        )
        page.refreshers[#page.refreshers + 1] = borderColorButton

        local dividerColorButton = context.CreateColorButton(
            appearanceCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -230,
            "Divider Color",
            function()
                return GetAppearanceSettings().dividerColor or GetAppearanceSettings().borderColor
            end,
            function(value)
                GetAppearanceSettings().dividerColor = value
                RefreshMonkOptionsPanel()
            end,
            { hasOpacity = false, width = context.APPEARANCE_COLUMN_WIDTH }
        )
        page.refreshers[#page.refreshers + 1] = dividerColorButton

        local gapSlider = context.CreateSlider(
            appearanceCard,
            18,
            -304,
            "Divider Width",
            context.APPEARANCE_COLUMN_WIDTH,
            0,
            16,
            1,
            function()
                return GetAppearanceSettings().segmentGap or 2
            end,
            function(value)
                GetAppearanceSettings().segmentGap = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = gapSlider

        local borderSizeSlider = context.CreateSlider(
            appearanceCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -304,
            "Border Size",
            context.APPEARANCE_COLUMN_WIDTH,
            -10,
            10,
            1,
            function()
                return GetAppearanceSettings().borderSize or 1
            end,
            function(value)
                GetAppearanceSettings().borderSize = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = borderSizeSlider

        local attachTargetDropdown = context.CreateStaticDropdown(
            positionCard,
            18,
            -82,
            "Attach Target",
            context.APPEARANCE_COLUMN_WIDTH,
            function()
                return ns.GetMonkChiBarAttachTargetChoices and ns.GetMonkChiBarAttachTargetChoices(GetAttachSettings().target) or {}
            end,
            function()
                return GetAttachSettings().target
            end,
            function(value)
                GetAttachSettings().target = value
                RefreshMonkOptionsPanel()
            end,
            "Standalone"
        )
        page.refreshers[#page.refreshers + 1] = attachTargetDropdown

        local matchWidthCheckbox = context.CreateCheckbox(
            positionCard,
            "Match Width Of Target",
            context.APPEARANCE_RIGHT_COLUMN_X,
            -82,
            function()
                return GetAttachSettings().matchWidth == true
            end,
            function(value)
                GetAttachSettings().matchWidth = value and true or false
                RefreshMonkOptionsPanel()
            end
        )
        page.refreshers[#page.refreshers + 1] = matchWidthCheckbox

        local attachStatusText = MarkMeasured(context.CreateBodyText(
            positionCard,
            "Standalone mode uses the Edit Mode fallback controls below.",
            18,
            -146,
            context.sectionWidth - 36
        ))

        local customFrameInput = CreateMonkTextInput(
            positionCard,
            18,
            -156,
            "Custom Frame Name",
            context.sectionWidth - 36,
            function()
                return GetAttachSettings().customFrameName or ""
            end,
            function(value)
                GetAttachSettings().customFrameName = value
                RefreshMonkOptionsPanel()
            end
        )
        page.refreshers[#page.refreshers + 1] = customFrameInput

        local anchorDropdown = context.CreateStaticDropdown(
            positionCard,
            18,
            -254,
            "Bar Anchor",
            context.APPEARANCE_COLUMN_WIDTH,
            context.REMINDER_POSITION_POINT_CHOICES,
            function()
                return GetAttachSettings().point
            end,
            function(value)
                GetAttachSettings().point = value
                RefreshMonkOptionsPanel()
            end,
            "Center"
        )
        page.refreshers[#page.refreshers + 1] = anchorDropdown

        local relativeAnchorDropdown = context.CreateStaticDropdown(
            positionCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -254,
            "Target Anchor",
            context.APPEARANCE_COLUMN_WIDTH,
            context.REMINDER_POSITION_POINT_CHOICES,
            function()
                return GetAttachSettings().relativePoint
            end,
            function(value)
                GetAttachSettings().relativePoint = value
                RefreshMonkOptionsPanel()
            end,
            "Center"
        )
        page.refreshers[#page.refreshers + 1] = relativeAnchorDropdown

        local offsetXSlider = context.CreateSlider(
            positionCard,
            18,
            -328,
            "X Offset",
            context.APPEARANCE_COLUMN_WIDTH,
            -4000,
            4000,
            1,
            function()
                return GetAttachSettings().x or 0
            end,
            function(value)
                GetAttachSettings().x = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = offsetXSlider

        local offsetYSlider = context.CreateSlider(
            positionCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -328,
            "Y Offset",
            context.APPEARANCE_COLUMN_WIDTH,
            -4000,
            4000,
            1,
            function()
                return GetAttachSettings().y or 0
            end,
            function(value)
                GetAttachSettings().y = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = offsetYSlider

        local widthSlider = context.CreateSlider(
            positionCard,
            18,
            -402,
            "Width",
            context.APPEARANCE_COLUMN_WIDTH,
            60,
            1200,
            1,
            function()
                return GetAppearanceSettings().width or 180
            end,
            function(value)
                GetAppearanceSettings().width = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = widthSlider

        local heightSlider = context.CreateSlider(
            positionCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -402,
            "Height",
            context.APPEARANCE_COLUMN_WIDTH,
            4,
            64,
            1,
            function()
                return GetAppearanceSettings().height or 18
            end,
            function(value)
                GetAppearanceSettings().height = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = heightSlider

        local standaloneTitle = MarkMeasured(context.CreateSubsectionTitle(positionCard, "Standalone Fallback", 18, -492))
        local standaloneBody = MarkMeasured(context.CreateBodyText(
            positionCard,
            "These controls are used whenever Attach Target is set to Standalone, or when the selected target frame cannot be resolved safely.",
            18,
            -516,
            context.sectionWidth - 36
        ))

        local standaloneAnchorDropdown = context.CreateStaticDropdown(
            positionCard,
            18,
            -574,
            "Standalone Anchor",
            context.APPEARANCE_COLUMN_WIDTH,
            context.REMINDER_POSITION_POINT_CHOICES,
            function()
                return GetStandaloneConfig().point
            end,
            function(value)
                GetStandaloneConfig().point = value
                RefreshMonkOptionsPanel()
            end,
            "Center"
        )
        page.refreshers[#page.refreshers + 1] = standaloneAnchorDropdown

        local standaloneXSlider = context.CreateSlider(
            positionCard,
            18,
            -648,
            "Standalone X",
            context.APPEARANCE_COLUMN_WIDTH,
            -4000,
            4000,
            1,
            function()
                return GetStandaloneConfig().x or 0
            end,
            function(value)
                GetStandaloneConfig().x = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = standaloneXSlider

        local standaloneYSlider = context.CreateSlider(
            positionCard,
            context.APPEARANCE_RIGHT_COLUMN_X,
            -648,
            "Standalone Y",
            context.APPEARANCE_COLUMN_WIDTH,
            -4000,
            4000,
            1,
            function()
                return GetStandaloneConfig().y or 0
            end,
            function(value)
                GetStandaloneConfig().y = value
                RefreshMonkOptionsPanel()
            end,
            function(value)
                return context.FormatSliderValue(value, 0, " px")
            end
        )
        page.refreshers[#page.refreshers + 1] = standaloneYSlider

        local monkTabs = {
            {
                key = EXPEL_HARM_TAB_KEY,
                label = EXPEL_HARM_TAB_LABEL,
                cards = { generalCard, appearanceCard, positionCard },
            },
        }

        ---@param tabKey string
        ---@return nil
        local function SetActiveMonkTab(tabKey)
            if page.activeMonkTabKey == tabKey then
                return
            end

            page.activeMonkTabKey = tabKey
            if page.scrollFrame and page.scrollFrame.SetVerticalScroll then
                page.scrollFrame:SetVerticalScroll(0)
            end
            page:RefreshAll()
        end

        local tabButtonWidth = floor((context.sectionWidth - ((#monkTabs - 1) * TAB_SPACING)) / #monkTabs)
        for index, tab in ipairs(monkTabs) do
            local tabKey = tab.key
            local button = CreateMonkTabButton(tabStrip, tab.label, tabButtonWidth, function()
                SetActiveMonkTab(tabKey)
            end)
            button:SetPoint("TOPLEFT", tabStrip, "TOPLEFT", (index - 1) * (tabButtonWidth + TAB_SPACING), 0)
            tab.button = button
        end

        page.activeMonkTabKey = page.activeMonkTabKey or monkTabs[1].key

        page.UpdateLayout = function(self)
            local cardSpacing = 20
            local currentY = context.PAGE_SECTION_START_Y
            local attachSettings = GetAttachSettings()
            local classOptionsEnabled = IsClassesModuleActiveInSession() and IsMonkModuleEnabled()
            local usingAttachedTarget = attachSettings.target ~= "none"
            local usingCustomTarget = attachSettings.target == "custom"
            local attachedFrame
            local attachedFrameName
            local isValidAttach = false
            local statusText = ""
            local statusColor = { r = 0.72, g = 0.78, b = 0.88 }
            local activeTab = monkTabs[1]
            local attachStatusY = -134
            local anchorRowY = -170
            local offsetRowY = -244
            local sizeRowY = -318
            local standaloneTitleY = -398
            local standaloneBodyY = -422
            local standaloneAnchorY = -480
            local standaloneOffsetY = -554

            if ns.ResolveMonkChiBarAttachFrame then
                attachedFrame, attachedFrameName, isValidAttach = ns.ResolveMonkChiBarAttachFrame(GetSettings())
            end

            if usingAttachedTarget then
                if usingCustomTarget and (GetAttachSettings().customFrameName or "") == "" then
                    statusText = "Enter a frame name to resolve a custom attach target. You can use a global frame name or dotted path."
                    statusColor = { r = 0.95, g = 0.82, b = 0.46 }
                elseif isValidAttach and attachedFrameName then
                    statusText = "Resolved target: " .. attachedFrameName
                    statusColor = { r = 0.56, g = 0.92, b = 0.66 }
                else
                    statusText = "The selected target is not available right now. The Expel Harm bar will fall back to the standalone position below."
                    statusColor = { r = 0.95, g = 0.54, b = 0.54 }
                end
            else
                statusText = "Standalone mode uses the Edit Mode fallback controls below."
            end

            if usingCustomTarget then
                attachStatusY = -214
                anchorRowY = -250
                offsetRowY = -324
                sizeRowY = -398
                standaloneTitleY = -478
                standaloneBodyY = -502
                standaloneAnchorY = -560
                standaloneOffsetY = -634
            end

            context.PositionControl(moduleEnabledCheckbox, content, context.sectionX, currentY)
            currentY = currentY - 38

            tabStrip:ClearAllPoints()
            tabStrip:SetPoint("TOPLEFT", content, "TOPLEFT", context.sectionX, currentY)
            currentY = currentY - TAB_HEIGHT - TAB_BOTTOM_SPACING

            for _, tab in ipairs(monkTabs) do
                local isSelected = tab.key == self.activeMonkTabKey
                tab.button:SetSelected(isSelected)
                for _, card in ipairs(tab.cards or {}) do
                    card:SetShown(isSelected)
                end
                if isSelected then
                    activeTab = tab
                end
            end

            self.activeMonkTabKey = activeTab.key
            activeTab.button:SetSelected(true)
            for _, card in ipairs(activeTab.cards or {}) do
                card:SetShown(true)
            end

            generalCard:ClearAllPoints()
            generalCard:SetPoint("TOPLEFT", content, "TOPLEFT", context.sectionX, currentY)
            context.PositionControl(enabledCheckbox, generalCard, 18, -82)
            context.PositionControl(visibilityDropdown, generalCard, 18, -122)
            context.PositionControl(skyridingCheckbox, generalCard, context.APPEARANCE_RIGHT_COLUMN_X, -122)
            context.SetControlEnabled(enabledCheckbox, classOptionsEnabled)
            context.SetControlEnabled(visibilityDropdown, classOptionsEnabled)
            context.SetControlEnabled(skyridingCheckbox, classOptionsEnabled)
            local generalCardHeight = context.FitSectionCardHeight(generalCard, 20)
            currentY = currentY - generalCardHeight - cardSpacing

            appearanceCard:ClearAllPoints()
            appearanceCard:SetPoint("TOPLEFT", content, "TOPLEFT", context.sectionX, currentY)
            context.PositionControl(textureDropdown, appearanceCard, 18, -82)
            context.PositionControl(borderTextureDropdown, appearanceCard, context.APPEARANCE_RIGHT_COLUMN_X, -82)
            context.PositionControl(activeColorButton, appearanceCard, 18, -156)
            context.PositionControl(backgroundColorButton, appearanceCard, context.APPEARANCE_RIGHT_COLUMN_X, -156)
            context.PositionControl(borderColorButton, appearanceCard, 18, -230)
            context.PositionControl(dividerColorButton, appearanceCard, context.APPEARANCE_RIGHT_COLUMN_X, -230)
            context.PositionControl(gapSlider, appearanceCard, 18, -304)
            context.PositionControl(borderSizeSlider, appearanceCard, context.APPEARANCE_RIGHT_COLUMN_X, -304)
            context.SetControlEnabled(textureDropdown, classOptionsEnabled)
            context.SetControlEnabled(borderTextureDropdown, classOptionsEnabled)
            context.SetControlEnabled(activeColorButton, classOptionsEnabled)
            context.SetControlEnabled(backgroundColorButton, classOptionsEnabled)
            context.SetControlEnabled(borderColorButton, classOptionsEnabled)
            context.SetControlEnabled(dividerColorButton, classOptionsEnabled)
            context.SetControlEnabled(gapSlider, classOptionsEnabled)
            context.SetControlEnabled(borderSizeSlider, classOptionsEnabled)
            local appearanceCardHeight = context.FitSectionCardHeight(appearanceCard, 20)
            currentY = currentY - appearanceCardHeight - cardSpacing

            attachStatusText:SetText(statusText)
            attachStatusText:SetTextColor(statusColor.r, statusColor.g, statusColor.b)

            positionCard:ClearAllPoints()
            positionCard:SetPoint("TOPLEFT", content, "TOPLEFT", context.sectionX, currentY)
            context.PositionControl(attachTargetDropdown, positionCard, 18, -82)
            context.PositionControl(matchWidthCheckbox, positionCard, context.APPEARANCE_RIGHT_COLUMN_X, -82)
            customFrameInput:SetShown(usingCustomTarget)
            if usingCustomTarget then
                context.PositionControl(customFrameInput, positionCard, 18, -156)
            end
            if context.SetTextBlockPosition then
                context.SetTextBlockPosition(attachStatusText, positionCard, 18, attachStatusY, context.sectionWidth - 36)
                context.SetTextBlockPosition(standaloneTitle, positionCard, 18, standaloneTitleY)
                context.SetTextBlockPosition(standaloneBody, positionCard, 18, standaloneBodyY, context.sectionWidth - 36)
            end
            context.PositionControl(anchorDropdown, positionCard, 18, anchorRowY)
            context.PositionControl(relativeAnchorDropdown, positionCard, context.APPEARANCE_RIGHT_COLUMN_X, anchorRowY)
            context.PositionControl(offsetXSlider, positionCard, 18, offsetRowY)
            context.PositionControl(offsetYSlider, positionCard, context.APPEARANCE_RIGHT_COLUMN_X, offsetRowY)
            context.PositionControl(widthSlider, positionCard, 18, sizeRowY)
            context.PositionControl(heightSlider, positionCard, context.APPEARANCE_RIGHT_COLUMN_X, sizeRowY)
            context.PositionControl(standaloneAnchorDropdown, positionCard, 18, standaloneAnchorY)
            context.PositionControl(standaloneXSlider, positionCard, 18, standaloneOffsetY)
            context.PositionControl(standaloneYSlider, positionCard, context.APPEARANCE_RIGHT_COLUMN_X, standaloneOffsetY)

            context.SetControlEnabled(attachTargetDropdown, classOptionsEnabled)
            context.SetControlEnabled(matchWidthCheckbox, classOptionsEnabled and usingAttachedTarget)
            context.SetControlEnabled(anchorDropdown, classOptionsEnabled and usingAttachedTarget)
            context.SetControlEnabled(relativeAnchorDropdown, classOptionsEnabled and usingAttachedTarget)
            context.SetControlEnabled(offsetXSlider, classOptionsEnabled and usingAttachedTarget)
            context.SetControlEnabled(offsetYSlider, classOptionsEnabled and usingAttachedTarget)
            context.SetControlEnabled(widthSlider, classOptionsEnabled and not (usingAttachedTarget and attachSettings.matchWidth == true and isValidAttach))
            context.SetControlEnabled(heightSlider, classOptionsEnabled)
            context.SetControlEnabled(standaloneAnchorDropdown, classOptionsEnabled)
            context.SetControlEnabled(standaloneXSlider, classOptionsEnabled)
            context.SetControlEnabled(standaloneYSlider, classOptionsEnabled)
            SetMonkTextInputEnabled(customFrameInput, classOptionsEnabled and usingCustomTarget)
            context.FitSectionCardHeight(positionCard, 20)

            standaloneTitle:SetShown(true)
            standaloneBody:SetShown(true)
            context.FitScrollContentHeight(content, self:GetHeight() - 16, 36)
        end

        page:UpdateLayout()
        return page
    end
end