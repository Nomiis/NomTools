local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

do
    local function MarkMeasured(object)
        if object then
            object.nomtoolsMeasure = true
        end

        return object
    end

    local function EnsureEntryCard(context, entryCards, parent, index)
        local card = entryCards[index]
        if card then
            return card
        end

        card = context.CreateSectionCard(parent, context.sectionX, context.PAGE_SECTION_START_Y, context.sectionWidth, 160, " ", nil)
        if card and card.titleText and card.titleText.GetFont and card.titleText.SetFont then
            local fontPath, fontSize = card.titleText:GetFont()
            if fontPath and fontSize then
                card.titleText:SetFont(fontPath, fontSize + 1, "OUTLINE")
            end
        end

        local descriptionText = MarkMeasured(card:CreateFontString(nil, "ARTWORK", "GameFontHighlight"))
        descriptionText:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -52)
        descriptionText:SetPoint("RIGHT", card, "RIGHT", -18, 0)
        descriptionText:SetJustifyH("LEFT")
        descriptionText:SetJustifyV("TOP")
        descriptionText:SetTextColor(0.82, 0.82, 0.82)
        card.descriptionText = descriptionText

        local sectionsText = MarkMeasured(card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"))
        sectionsText:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -88)
        sectionsText:SetPoint("RIGHT", card, "RIGHT", -18, 0)
        sectionsText:SetJustifyH("LEFT")
        sectionsText:SetJustifyV("TOP")
        sectionsText:SetSpacing(2)
        sectionsText:SetTextColor(0.82, 0.82, 0.82)
        card.sectionsText = sectionsText

        local importanceText = MarkMeasured(card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        importanceText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -18, -18)
        importanceText:SetText("Important Update")
        importanceText:SetTextColor(1.0, 0.82, 0.0)
        card.importanceText = importanceText

        entryCards[index] = card
        return card
    end

    function ns.CreateChangeLogOptionsPage(context)
        if type(context) ~= "table" or type(context.CreateModulePage) ~= "function" then
            return nil
        end

        local defaults = ns.DEFAULTS and ns.DEFAULTS.changelog or {
            popupMode = "important",
            lastSeenEntryId = 0,
        }

        local page, content = context.CreateModulePage(
            "NomToolsChangeLogPanel",
            "Change Log",
            "Release Notes",
            "Review the latest NomTools changes and choose whether changelog popups appear on login.",
            {
                resetHandler = function()
                    if ns.ResetChangelogSettingsToDefaults then
                        ns.ResetChangelogSettingsToDefaults({ preserveSeenState = true })
                    elseif ns.SetChangelogSetting then
                        ns.SetChangelogSetting("popupMode", defaults.popupMode or "important")
                    end
                end,
            }
        )

        local settingsCard = context.CreateSectionCard(
            content,
            context.sectionX,
            -96,
            context.sectionWidth,
            156,
            "Popup Behavior",
            nil
        )

        local popupModeDropdown = context.CreateStaticDropdown(
            settingsCard,
            18,
            -78,
            "Login Popup",
            context.APPEARANCE_COLUMN_WIDTH,
            function()
                return ns.GetChangelogPopupModeChoices and ns.GetChangelogPopupModeChoices() or {}
            end,
            function()
                return ns.GetChangelogPopupMode and ns.GetChangelogPopupMode() or "important"
            end,
            function(value)
                if ns.SetChangelogSetting then
                    ns.SetChangelogSetting("popupMode", value)
                end
            end,
            "Important Only"
        )
        page.refreshers[#page.refreshers + 1] = popupModeDropdown

        local previewButton = context.CreateButton(content, "Show Latest Popup", 372, -20, 148, 24, function()
            if ns.ShowChangelogPopup then
                ns.ShowChangelogPopup(ns.GetLatestChangelogEntry and ns.GetLatestChangelogEntry() or nil)
            end
        end)
        previewButton.Refresh = function(self)
            local hasEntry = ns.GetLatestChangelogEntry and ns.GetLatestChangelogEntry() ~= nil
            self:SetEnabled(hasEntry)
            self:SetAlpha(hasEntry and 1 or 0.55)
        end
        page.refreshers[#page.refreshers + 1] = previewButton

        local entryCards = {}

        page.UpdateLayout = function(self)
            local currentY = context.PAGE_SECTION_START_Y
            local cardSpacing = 20
            local entries = ns.GetChangelogEntries and ns.GetChangelogEntries() or {}

            settingsCard:ClearAllPoints()
            settingsCard:SetPoint("TOPLEFT", content, "TOPLEFT", context.sectionX, currentY)
            context.PositionControl(popupModeDropdown, settingsCard, 18, -78)
            local settingsCardHeight = context.FitSectionCardHeight(settingsCard, 20)
            currentY = currentY - settingsCardHeight - cardSpacing

            for index, entry in ipairs(entries) do
                local card = EnsureEntryCard(context, entryCards, content, index)
                local hasDescription = type(entry.description) == "string" and entry.description ~= ""

                card.titleText:SetText(entry.title or "Change Log")
                card.importanceText:SetShown(entry.important == true)
                card.descriptionText:SetShown(hasDescription)
                card.descriptionText:SetText(hasDescription and entry.description or "")
                card.sectionsText:SetText(ns.GetChangelogEntryBodyText and ns.GetChangelogEntryBodyText(entry) or "")
                card.sectionsText:ClearAllPoints()

                if hasDescription then
                    card.sectionsText:SetPoint("TOPLEFT", card.descriptionText, "BOTTOMLEFT", 0, -12)
                else
                    card.sectionsText:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -52)
                end

                card.sectionsText:SetPoint("RIGHT", card, "RIGHT", -18, 0)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", content, "TOPLEFT", context.sectionX, currentY)
                card:Show()
                currentY = currentY - context.FitSectionCardHeight(card, 20) - cardSpacing
            end

            for index = #entries + 1, #entryCards do
                entryCards[index]:Hide()
            end

            context.FitScrollContentHeight(content, self:GetHeight() - 16, 36)
        end

        page:UpdateLayout()
        return page
    end
end