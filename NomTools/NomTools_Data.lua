local addonName, ns = ...

ns.ADDON_NAME = addonName
_G[addonName] = ns
ns.MAX_PRIORITY_CHOICES = 3
ns.GLOBAL_CHOICE_KEY = "global"
ns.GLOBAL_STYLE_FONT_AUTO_KEY = "__nomtools_preferred_global_font__"
ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY = "__nomtools_preferred_global_texture__"

local DEFAULT_INSTANCE_FILTERS = {
    open_world = false,
    city_rest_area = false,
    party_normal = false,
    party_heroic = false,
    party_mythic = true,
    party_timewalking = false,
    raid_lfr = false,
    raid_normal = false,
    raid_heroic = true,
    raid_mythic = true,
    raid_timewalking = false,
    raid_story = false,
    scenario_normal = false,
    scenario_heroic = false,
    delve = false,
    battleground = false,
    arena = false,
    other_instance = false,
}

local function CopyBooleanMap(source)
    local copy = {}

    for key, value in pairs(source or {}) do
        copy[key] = value and true or false
    end

    return copy
end

local function CreateAllTrueBooleanMap(source)
    local copy = {}

    for key in pairs(source or {}) do
        copy[key] = true
    end

    return copy
end

local function CreateAllFalseBooleanMap(source)
    local copy = {}

    for key in pairs(source or {}) do
        copy[key] = false
    end

    return copy
end

local function CreateDefaultConsumableVisibilityConfig(enabledFilters)
    return {
        showDuringCombat = false,
        showDuringMythicPlus = false,
        enabledFilters = CopyBooleanMap(enabledFilters or DEFAULT_INSTANCE_FILTERS),
    }
end

local function CreateDefaultConsumableVisibilityMap()
    return {
        flask = CreateDefaultConsumableVisibilityConfig(),
        food = CreateDefaultConsumableVisibilityConfig(),
        weapon = CreateDefaultConsumableVisibilityConfig(),
        poisons = CreateDefaultConsumableVisibilityConfig(CreateAllTrueBooleanMap(DEFAULT_INSTANCE_FILTERS)),
        rune = CreateDefaultConsumableVisibilityConfig(),
    }
end

local function CreateDefaultSecondaryConsumableSetupMap()
    local emptyFilters = CreateAllFalseBooleanMap(DEFAULT_INSTANCE_FILTERS)

    return {
        flask = {
            enabled = false,
            choices = { "none", "none", "none" },
            reapply = {
                enabled = false,
                thresholdSeconds = 1800,
            },
            visibility = CreateDefaultConsumableVisibilityConfig(emptyFilters),
        },
        food = {
            enabled = false,
            choices = { "none", "none", "none" },
            reapply = {
                enabled = false,
                thresholdSeconds = 1800,
            },
            visibility = CreateDefaultConsumableVisibilityConfig(emptyFilters),
        },
        weapon = {
            enabled = false,
            choices = { "none", "none", "none" },
            reapply = {
                enabled = false,
                thresholdSeconds = 1800,
            },
            visibility = CreateDefaultConsumableVisibilityConfig(emptyFilters),
        },
        poisons = {
            enabled = false,
            choices = {
                lethal = "none",
                non_lethal = "none",
            },
            reapply = {
                enabled = false,
                thresholdSeconds = 1800,
            },
            visibility = CreateDefaultConsumableVisibilityConfig(emptyFilters),
        },
        rune = {
            enabled = false,
            choice = "none",
            reapply = {
                enabled = false,
                thresholdSeconds = 1800,
            },
            visibility = CreateDefaultConsumableVisibilityConfig(emptyFilters),
        },
    }
end

ns.DEFAULTS = {
    setupComplete = false,
    enabled = false,
    automation = {
        skipSeenCutscenes = false,
        seenMovies = {},
        seenCinematics = {},
    },
    miscellaneous = {
        enabled = false,
    },
    showGameMenuButton = true,
    globalSettings = {
        font = ns.GLOBAL_STYLE_FONT_AUTO_KEY,
        fontOutline = "OUTLINE",
        texture = ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY,
        borderTexture = ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY,
        enableDebug = false,
        debugModeCPU = false,
        debugModeMemory = false,
        showMinimapButton = true,
        showAddonCompartment = true,
    },
    optionsWindow = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
    changelog = {
        popupMode = "important",
        lastSeenEntryId = 0,
    },
    reminders = {
        enabled = false,
        appearance = {
            preset = "blizzard",
            blizzard = {
                font = ns.GLOBAL_CHOICE_KEY,
                fontOutline = ns.GLOBAL_CHOICE_KEY,
                titleFontSize = 14,
                primaryFontSize = 13,
                hintFontSize = 11,
                titleColor = {
                    r = 1,
                    g = 0.82,
                    b = 0,
                    a = 1,
                },
                primaryColor = {
                    r = 1,
                    g = 1,
                    b = 1,
                    a = 1,
                },
                hintColor = {
                    r = 0.75,
                    g = 0.78,
                    b = 0.82,
                    a = 1,
                },
            },
            nomtools = {
                font = ns.GLOBAL_CHOICE_KEY,
                fontOutline = ns.GLOBAL_CHOICE_KEY,
                titleFontSize = 14,
                primaryFontSize = 13,
                hintFontSize = 11,
                titleColor = {
                    r = 1,
                    g = 0.88,
                    b = 0.74,
                    a = 1,
                },
                primaryColor = {
                    r = 1,
                    g = 1,
                    b = 1,
                    a = 1,
                },
                hintColor = {
                    r = 0.72,
                    g = 0.78,
                    b = 0.88,
                    a = 1,
                },
                showAccent = true,
                accentColor = {
                    r = 0.96,
                    g = 0.64,
                    b = 0.22,
                    a = 1,
                },
                opacity = 80,
                texture = ns.GLOBAL_CHOICE_KEY,
                backgroundColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 0.8,
                },
                borderColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderTexture = ns.GLOBAL_CHOICE_KEY,
                borderSize = 1,
            },
        },
    },
    dungeonDifficulty = {
        enabled = false,
    },
    objectiveTracker = {
        enabled = false,
        focusedQuest = {
            enabled = true,
        },
        search = {
            enabled = true,
            showBackground = true,
            backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 },
            backgroundTexture = ns.GLOBAL_CHOICE_KEY,
            borderTexture = ns.GLOBAL_CHOICE_KEY,
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0, a = 1 },
            font = ns.GLOBAL_CHOICE_KEY,
            fontSize = 11,
            fontOutline = ns.GLOBAL_CHOICE_KEY,
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            placeholderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
            height = 16,
        },
        filter = {
            enabled = true,
            questTypes = {},
            sortBy = "default",
            sortDirection = "asc",
            zoneSortDirection = "asc",
            groupByZone = false,
            showTrivial = true,
            zoneDividerAlign = "center",
            zoneDividerShowLines = true,
        },
        order = {
            "search",
            "scenario",
            "uiWidget",
            "focusedQuest",
            "campaign",
            "zone",
            "quest",
            "adventure",
            "achievement",
            "monthlyActivities",
            "initiativeTasks",
            "professionsRecipe",
            "bonusObjective",
            "worldQuest",
        },
        zone = {
            regularQuests = true,
            campaignQuests = false,
            worldQuests = true,
            bonusObjectives = true,
            titleColors = {
                quest = {
                    r = 1,
                    g = 0.82,
                    b = 0,
                    a = 1,
                },
                campaign = {
                    r = 0.78,
                    g = 0.58,
                    b = 1,
                    a = 1,
                },
                worldQuest = {
                    r = 0.46,
                    g = 0.84,
                    b = 1,
                    a = 1,
                },
                bonusObjective = {
                    r = 0.18,
                    g = 0.88,
                    b = 0.76,
                    a = 1,
                },
            },
        },
        typography = {
            font = ns.GLOBAL_CHOICE_KEY,
            fontSize = 13,
            fontOutline = ns.GLOBAL_CHOICE_KEY,
            levelPrefixMode = "trivial",
            showWarbandCompletedIndicator = true,
            showQuestLogCount = true,
            titleColors = {
                quest = {
                    r = 1,
                    g = 0.82,
                    b = 0,
                    a = 1,
                },
                worldQuest = {
                    r = 0.46,
                    g = 0.84,
                    b = 1,
                    a = 1,
                },
                bonusObjective = {
                    r = 0.18,
                    g = 0.88,
                    b = 0.76,
                    a = 1,
                },
                daily = {
                    r = 0.32,
                    g = 0.63,
                    b = 1,
                    a = 1,
                },
                weekly = {
                    r = 0.32,
                    g = 0.63,
                    b = 1,
                    a = 1,
                },
                meta = {
                    r = 0.32,
                    g = 0.63,
                    b = 1,
                    a = 1,
                },
                important = {
                    r = 0.52,
                    g = 0.38,
                    b = 0.74,
                    a = 1,
                },
                prey = {
                    r = 0.92,
                    g = 0.18,
                    b = 0.18,
                    a = 1,
                },
                campaign = {
                    r = 1,
                    g = 0.4,
                    b = 0.7,
                    a = 1,
                },
                trivial = {
                    r = 0.58,
                    g = 0.58,
                    b = 0.58,
                    a = 1,
                },
                useTrivialColor = true,
                legendary = {
                    r = 1,
                    g = 0.5,
                    b = 0,
                    a = 1,
                },
            },
            uncompletedColor = {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
            },
            completedColor = {
                r = 0.36,
                g = 0.95,
                b = 0.45,
                a = 1,
            },
        },
        scrollBar = {
            enabled = true,
            visible = true,
            texture = ns.GLOBAL_CHOICE_KEY,
            color = {
                r = 1,
                g = 0.82,
                b = 0,
                a = 0.9,
            },
            backgroundColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 0.8,
            },
            width = 4,
            borderTexture = ns.GLOBAL_CHOICE_KEY,
            borderSize = 0,
            borderColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 1,
            },
        },
        progressBar = {
            texture = ns.GLOBAL_CHOICE_KEY,
            fillMode = "progress",
            fillColor = {
                r = 0.26,
                g = 0.42,
                b = 1,
                a = 1,
            },
            lowFillColor = {
                r = 0.90,
                g = 0.18,
                b = 0.18,
                a = 1,
            },
            mediumFillColor = {
                r = 0.95,
                g = 0.82,
                b = 0.18,
                a = 1,
            },
            highFillColor = {
                r = 0.28,
                g = 0.82,
                b = 0.32,
                a = 1,
            },
            backgroundColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 0.8,
            },
            borderTexture = ns.GLOBAL_CHOICE_KEY,
            borderSize = 1,
            borderColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 1,
            },
            hideRewardIcon = false,
        },
        zoneDivider = {
            align = "center",
            showLines = true,
            lineFadeOut = true,
            showBackground = false,
            backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 },
            backgroundTexture = ns.GLOBAL_CHOICE_KEY,
            borderTexture = ns.GLOBAL_CHOICE_KEY,
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0, a = 1 },
            font = ns.GLOBAL_CHOICE_KEY,
            fontSize = 12,
            fontOutline = ns.GLOBAL_CHOICE_KEY,
            textColor = { r = 0.8, g = 0.72, b = 0.42, a = 1 },
            lineColor = { r = 0.8, g = 0.72, b = 0.42, a = 0.5 },
            lineThickness = 1,
            height = 20,
        },
        appearance = {
            preset = "blizzard",
            texture = ns.GLOBAL_CHOICE_KEY,
            opacity = 80,
            color = {
                r = 0,
                g = 0,
                b = 0,
                a = 1,
            },
            borderColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 1,
            },
            borderTexture = ns.GLOBAL_CHOICE_KEY,
            mainHeader = {
                texture = ns.GLOBAL_CHOICE_KEY,
                opacity = 80,
                color = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderTexture = ns.GLOBAL_CHOICE_KEY,
                borderSize = 1,
            },
            categoryHeader = {
                texture = ns.GLOBAL_CHOICE_KEY,
                opacity = 80,
                color = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderTexture = ns.GLOBAL_CHOICE_KEY,
                borderSize = 1,
            },
            button = {
                texture = ns.GLOBAL_CHOICE_KEY,
                opacity = 80,
                color = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderTexture = ns.GLOBAL_CHOICE_KEY,
                borderSize = 1,
            },
            trackerBackground = {
                enabled = false,
                texture = ns.GLOBAL_CHOICE_KEY,
                opacity = 80,
                color = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderTexture = ns.GLOBAL_CHOICE_KEY,
                borderSize = 1,
            },
        },
        layout = {
            width = 255,
            height = 650,
            matchMinimapWidth = false,
            attachToMinimap = false,
            minimapYOffset = 0,
            minimapAttachEdge = "bottom",
        },
        header = {
            enabled = true,
            showBackground = true,
            showTitle = true,
        },
        buttons = {
            trackAll = true,
            minimize = true,
            filterButton = true,
        },
    },
    menuBar = {
        enabled = false,
        scale = 1.0,
        queueEye = {
            attachToMinimap = true,
            minimapAnchor = "BOTTOMLEFT",
            minimapOffsetX = 5,
            minimapOffsetY = 5,
            scale = 1.0,
        },
    },
    greatVault = {
        enabled = false,
    },
    talentLoadout = {
        enabled = false,
        enabledFilters = {
            open_world = false,
            city_rest_area = false,
            party_normal = true,
            party_heroic = true,
            party_mythic = true,
            party_timewalking = false,
            raid_lfr = false,
            raid_normal = true,
            raid_heroic = true,
            raid_mythic = true,
            raid_timewalking = false,
            raid_story = false,
            scenario_normal = false,
            scenario_heroic = false,
            delve = false,
            battleground = false,
            arena = false,
            other_instance = false,
        },
        checkPreferredLoadout = false,
    },
    housing = {
        enabled = false,
        customSort = true,
        showNewMarkers = true,
        newMarkersFirstOwnershipOnly = false,
        vendorMultiBuy = true,
        vendorThrottle = true,
        autoConfirmDecorPurchase = false,
    },
    characterStats = {
        enabled = false,
        stats = {
            mainStat = { enabled = true, color = { r = 1.00, g = 0.82, b = 0.00, a = 1 } },
            stamina = { enabled = false, color = { r = 0.00, g = 0.80, b = 0.00, a = 1 } },
            criticalStrike = { enabled = true, color = { r = 1.00, g = 0.40, b = 0.20, a = 1 } },
            haste = { enabled = true, color = { r = 0.80, g = 0.90, b = 0.20, a = 1 } },
            mastery = { enabled = true, color = { r = 0.40, g = 0.60, b = 1.00, a = 1 } },
            versatility = { enabled = true, color = { r = 0.20, g = 0.90, b = 0.40, a = 1 } },
            leech = { enabled = true, color = { r = 0.70, g = 0.30, b = 0.90, a = 1 } },
            avoidance = { enabled = true, color = { r = 0.18, g = 0.74, b = 0.70, a = 1 } },
            speed = { enabled = true, color = { r = 0.40, g = 0.85, b = 1.00, a = 1 } },
            dodge = { enabled = false, color = { r = 1.00, g = 0.60, b = 0.20, a = 1 } },
            parry = { enabled = false, color = { r = 0.85, g = 0.55, b = 0.35, a = 1 } },
            block = { enabled = false, color = { r = 0.65, g = 0.65, b = 0.65, a = 1 } },
            armor = { enabled = false, color = { r = 0.75, g = 0.70, b = 0.50, a = 1 } },
        },
        appearance = {
            preset = "blizzard",
            blizzard = {
                font = ns.GLOBAL_CHOICE_KEY,
                fontOutline = ns.GLOBAL_CHOICE_KEY,
                fontSize = 12,
            },
            nomtools = {
                font = ns.GLOBAL_CHOICE_KEY,
                fontOutline = ns.GLOBAL_CHOICE_KEY,
                fontSize = 12,
                texture = ns.GLOBAL_CHOICE_KEY,
                backgroundColor = { r = 0, g = 0, b = 0, a = 1 },
                backgroundOpacity = 80,
                borderTexture = ns.GLOBAL_CHOICE_KEY,
                borderColor = { r = 0, g = 0, b = 0, a = 1 },
                borderSize = 1,
            },
        },
    },
    worldQuests = {
        enabled          = false,
        openOnWorldQuestsTab = false,
        panelWidth       = 260,
        font             = ns.GLOBAL_CHOICE_KEY,
        fontOutline      = ns.GLOBAL_CHOICE_KEY,
        titleFontSize    = 14,
        detailFontSize   = 11,
        rewardFontSize   = 10,
        filterVersion = 2,
        filterTypes   = {},
        filterRewards    = {},
        sortMode         = "time",
        zoneSortMode     = "time",
        excludedMaps     = nil,  -- populated from ns.WORLD_QUEST_DEFAULT_EXCLUDED_MAPS at runtime
    },
    classes = {
        enabled = false,
        monk = {
            moduleEnabled = true,
            enabled = false,
            visibility = {
                mode = "always",
                hideWhileSkyriding = false,
            },
            attach = {
                target = "secondary_power_bar",
                customFrameName = "",
                point = "BOTTOM",
                relativePoint = "TOP",
                x = 0,
                y = 0,
                matchWidth = true,
            },
            appearance = {
                width = 180,
                height = 18,
                segmentGap = 2,
                texture = ns.GLOBAL_CHOICE_KEY,
                borderTexture = ns.GLOBAL_CHOICE_KEY,
                activeColor = {
                    r = 0.38,
                    g = 0.86,
                    b = 0.62,
                    a = 1,
                },
                backgroundColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 0.8,
                },
                borderColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                dividerColor = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 1,
                },
                borderSize = 1,
            },
        },
    },
    consumables = {
        flaskEnabled = true,
        foodEnabled = true,
        weaponEnabled = true,
        poisonsEnabled = true,
        runeEnabled = true,
        flaskChoice = "auto",
        foodChoice = "auto",
        weaponChoice = "auto",
        runeChoice = "auto",
        flaskChoices = { "auto", "none", "none" },
        foodChoices = { "auto", "none", "none" },
        weaponChoices = { "auto", "none", "none" },
        weaponPoisonChoices = {
            lethal = "auto",
            non_lethal = "auto",
        },
        reapply = {
            flask = {
                enabled = true,
                thresholdSeconds = 1800,
            },
            food = {
                enabled = true,
                thresholdSeconds = 1800,
            },
            weapon = {
                enabled = true,
                thresholdSeconds = 1800,
            },
            poisons = {
                enabled = true,
                thresholdSeconds = 1800,
            },
            rune = {
                enabled = true,
                thresholdSeconds = 1800,
            },
        },
        appearance = {
            showBorder = true,
            borderTexture = ns.GLOBAL_CHOICE_KEY,
            borderSize = 1,
            borderColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 1,
            },
            iconSize = 40,
            spacing = 5,
            iconZoom = 0.30,
            font = ns.GLOBAL_CHOICE_KEY,
            fontSize = 12,
            labelTextEnabled = true,
            labelFontSize = 12,
            labelAnchor = "bottom",
            labelOffsetY = 0,
            durationTextEnabled = true,
            durationFontSize = 12,
            durationAnchor = "top",
            durationOffsetY = 0,
            countTextEnabled = true,
            countFontSize = 11,
            countAnchor = "bottom_right",
            countOffsetX = 0,
            countOffsetY = 0,
            fontOutline = ns.GLOBAL_CHOICE_KEY,
            glowMode = "ready_check",
            glowType = "proc",
            readyCheckGlowDuration = 5,
            glowFrequency = 0.5,
            glowSize = 1.5,
            glowPixelLines = 8,
            glowPixelLength = 10,
            glowPixelThickness = 2,
            glowAutocastParticles = 4,
            glowProcStartAnimation = true,
            glowColor = {
                r = 0.95,
                g = 0.95,
                b = 0.32,
                a = 1,
            },
        },
        visibility = CreateDefaultConsumableVisibilityMap(),
        secondary = CreateDefaultSecondaryConsumableSetupMap(),
    },
    editMode = {
        reminder = {
            point = "TOP",
            x = 0,
            y = -140,
            scale = 1,
            strata = "HIGH",
        },
        utilityBar = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
        menuBar = {
            point = "BOTTOMRIGHT",
            x = 0,
            y = 0,
        },
        queueEye = {
            point = "BOTTOMLEFT",
            x = 10,
            y = 10,
        },
        monkChiBar = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
        greatVault = {
            point = "TOP",
            x = 0,
            y = -220,
        },
        dungeonDifficulty = {
            point = "TOP",
            x = 0,
            y = -324,
        },
        talentLoadout = {
            point = "TOP",
            x = 0,
            y = -428,
        },
        characterStats = { point = "TOPLEFT", x = 20, y = -200 },
        objectiveTracker = {
            point = "RIGHT",
            x = -5,
            y = 0,
        },
    },
}

ns.FONT_CHOICES = {
    { key = "Friz Quadrata TT", name = "Friz Quadrata TT", path = "Fonts\\FRIZQT__.TTF" },
    { key = "Arial Narrow", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "Morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS_CYR.TTF" },
    { key = "Skurri", name = "Skurri", path = "Fonts\\skurri.ttf" },
}

ns.FONT_OUTLINE_CHOICES = {
    { key = "NONE", name = "None", flags = "" },
    { key = "OUTLINE", name = "Outline", flags = "OUTLINE" },
    { key = "THICKOUTLINE", name = "Thick Outline", flags = "THICKOUTLINE" },
    { key = "MONOCHROMEOUTLINE", name = "Monochrome Outline", flags = "MONOCHROME,OUTLINE" },
}

ns.GLOW_CHOICES = {
    { key = "never", name = "Never" },
    { key = "ready_check", name = "Ready Check" },
    { key = "always", name = "Always" },
}

ns.GLOW_TYPE_CHOICES = {
    { key = "button", name = "Action Button Glow" },
    { key = "pixel", name = "Pixel Glow" },
    { key = "autocast", name = "Autocast Shine" },
    { key = "proc", name = "Proc Glow" },
}

ns.GLOW_SIZE_LABELS = {
    button = "Glow Size",
    pixel = "Pixel Length",
    autocast = "Shine Scale",
    proc = "Proc Size",
}

ns.GLOW_SIZE_SUFFIX = {
    button = "x",
    pixel = " px",
    autocast = "x",
    proc = "x",
}

ns.INSTANCE_FILTERS = {
    { key = "party_timewalking", name = "Timewalking", difficulties = { 24 } },
    { key = "party_normal", name = "Normal", difficulties = { 1, 150, 173 } },
    { key = "party_heroic", name = "Heroic", difficulties = { 2, 174, 230 } },
    { key = "party_mythic", name = "Mythic", difficulties = { 23 } },
    { key = "raid_story", name = "Story", difficulties = { 220 } },
    { key = "raid_timewalking", name = "Timewalking", difficulties = { 33 } },
    { key = "raid_lfr", name = "LFR", difficulties = { 7, 17, 151 } },
    { key = "raid_normal", name = "Normal", difficulties = { 3, 4, 9, 14 } },
    { key = "raid_heroic", name = "Heroic", difficulties = { 5, 6, 15 } },
    { key = "raid_mythic", name = "Mythic", difficulties = { 16 } },
    { key = "open_world", name = "Open World" },
    { key = "city_rest_area", name = "City / Rest Area" },
    { key = "delve", name = "Delve", difficulties = { 208 } },
    { key = "scenario_normal", name = "Scenario: Normal", difficulties = { 12 } },
    { key = "scenario_heroic", name = "Scenario: Heroic", difficulties = { 11 } },
    { key = "battleground", name = "Battleground", instanceTypes = { "pvp" } },
    { key = "arena", name = "Arena", instanceTypes = { "arena" } },
    { key = "other_instance", name = "Other / Misc. Instance", instanceTypes = { "other" } },
}

ns.CONSUMABLE_VISIBILITY_GROUPS = {
    {
        key = "dungeons",
        name = "Dungeons",
        filterKeys = {
            "party_timewalking",
            "party_normal",
            "party_heroic",
            "party_mythic",
        },
    },
    {
        key = "raids",
        name = "Raid",
        filterKeys = {
            "raid_story",
            "raid_timewalking",
            "raid_lfr",
            "raid_normal",
            "raid_heroic",
            "raid_mythic",
        },
    },
    {
        key = "other",
        name = "Other",
        filterKeys = {
            "open_world",
            "city_rest_area",
            "delve",
            "scenario_normal",
            "scenario_heroic",
            "battleground",
            "arena",
            "other_instance",
        },
    },
}

local DEFAULT_FONT_NAME = "Friz Quadrata TT"
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local DEFAULT_STATUSBAR_TEXTURE_KEY = "blizzard"
local DEFAULT_STATUSBAR_TEXTURE_PATH = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_BORDER_TEXTURE_KEY = "solid"
local DEFAULT_BORDER_TEXTURE_PATH = "Interface\\Buttons\\WHITE8x8"
local PREFERRED_GLOBAL_FONT_NAME = "Roboto Condensed Bold"
local PREFERRED_GLOBAL_TEXTURE_KEY = "solid"
local PREFERRED_GLOBAL_BORDER_TEXTURE_KEY = "solid"
local FONT_LEGACY_ALIASES = {
    frizqt = "Friz Quadrata TT",
    arialn = "Arial Narrow",
    morpheus = "Morpheus",
    skurri = "Skurri",
}

ns.STATUSBAR_TEXTURE_CHOICES = {
    {
        key = "blizzard",
        name = "Default Status Bar",
        path = DEFAULT_STATUSBAR_TEXTURE_PATH,
    },
    {
        key = "solid",
        name = "Solid",
        path = "Interface\\Buttons\\WHITE8x8",
    },
    {
        key = "raid_hp",
        name = "Raid HP Fill",
        path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    },
    {
        key = "raid_resource",
        name = "Raid Resource Fill",
        path = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill",
    },
    {
        key = "skills",
        name = "Skills Bar",
        path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
    },
}

local NormalizeBorderTextureKey

ns.BORDER_TEXTURE_CHOICES = {
    {
        key = "solid",
        name = "Solid Line",
        path = DEFAULT_BORDER_TEXTURE_PATH,
        tile = true,
        tileSize = 8,
        edgeSize = 1,
        previewEdgeSize = 2,
        scaleStep = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        preserveColor = false,
    },
    {
        key = "tooltip",
        name = "Tooltip Border",
        path = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        previewEdgeSize = 4,
        scaleStep = 2,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
        preserveColor = true,
    },
    {
        key = "slider",
        name = "Slider Border",
        path = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        previewEdgeSize = 4,
        scaleStep = 1,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
        preserveColor = true,
    },
    {
        key = "dialog",
        name = "Dialog Border",
        path = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        previewEdgeSize = 5,
        scaleStep = 2,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
        preserveColor = true,
    },
}

local function ClampNumber(value, minimum, maximum)
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

local function NormalizeBackdropInsets(insets, fallback)
    fallback = ClampNumber(fallback, 0, 128)
    if type(insets) ~= "table" then
        return {
            left = fallback,
            right = fallback,
            top = fallback,
            bottom = fallback,
        }
    end

    return {
        left = ClampNumber(insets.left, 0, 128),
        right = ClampNumber(insets.right, 0, 128),
        top = ClampNumber(insets.top, 0, 128),
        bottom = ClampNumber(insets.bottom, 0, 128),
    }
end

local function BuildBorderTextureDefinition(choice, overridePath)
    local edgeSize = ClampNumber(choice and choice.edgeSize or 1, 1, 128)
    local previewEdgeSize = ClampNumber(
        choice and choice.previewEdgeSize or math.max(2, math.floor(edgeSize / 3)),
        1,
        48
    )

    return {
        key = NormalizeBorderTextureKey(choice and choice.key or overridePath or DEFAULT_BORDER_TEXTURE_KEY),
        name = (choice and choice.name) or overridePath or DEFAULT_BORDER_TEXTURE_KEY,
        path = overridePath or (choice and choice.path) or DEFAULT_BORDER_TEXTURE_PATH,
        tile = choice and choice.tile ~= false or true,
        tileSize = ClampNumber(choice and choice.tileSize or 8, 1, 128),
        edgeSize = edgeSize,
        previewEdgeSize = previewEdgeSize,
        scaleStep = ClampNumber(choice and choice.scaleStep or 1, 0, 32),
        supportsVariableThickness = choice == nil or choice.supportsVariableThickness ~= false,
        preserveColor = choice and choice.preserveColor == true or false,
        insets = NormalizeBackdropInsets(choice and choice.insets, math.max(1, math.floor(edgeSize / 4))),
    }
end

local function FindBorderTextureChoiceByPath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    for _, choice in ipairs(ns.BORDER_TEXTURE_CHOICES) do
        if choice.path == path then
            return choice
        end
    end

    return nil
end

local function NormalizeFontKey(key)
    if type(key) ~= "string" or key == "" then
        return DEFAULT_FONT_NAME
    end

    return FONT_LEGACY_ALIASES[key] or key
end

local function NormalizeStatusBarTextureKey(key)
    if type(key) ~= "string" or key == "" then
        return DEFAULT_STATUSBAR_TEXTURE_KEY
    end

    return key
end

NormalizeBorderTextureKey = function(key)
    if type(key) ~= "string" or key == "" then
        return DEFAULT_BORDER_TEXTURE_KEY
    end

    return key
end

local function GetSharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function GetResolvedGlobalFontKey()
    local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
    local fontKey = settings and settings.font or ns.GLOBAL_STYLE_FONT_AUTO_KEY
    if fontKey == ns.GLOBAL_STYLE_FONT_AUTO_KEY then
        return PREFERRED_GLOBAL_FONT_NAME
    end

    return fontKey
end

local function GetResolvedGlobalTextureKey()
    local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
    local textureKey = settings and settings.texture or ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY
    if textureKey == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY then
        return PREFERRED_GLOBAL_TEXTURE_KEY
    end

    return textureKey
end

local function GetResolvedGlobalBorderTextureKey()
    local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
    local textureKey = settings and settings.borderTexture or ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY
    if textureKey == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY then
        return PREFERRED_GLOBAL_BORDER_TEXTURE_KEY
    end

    return textureKey
end

local function BuildFontChoiceList(includeGlobalChoice)
    local choices = {}
    local seen = {}

    local function AddChoice(key, name, path)
        local normalizedKey = NormalizeFontKey(key)
        local lookup = normalizedKey:lower()
        if seen[lookup] then
            return
        end

        seen[lookup] = true
        choices[#choices + 1] = {
            key = normalizedKey,
            name = name or normalizedKey,
            path = path,
        }
    end

    if includeGlobalChoice == true then
        choices[#choices + 1] = {
            key = ns.GLOBAL_CHOICE_KEY,
            name = "Global",
            path = nil,
        }
        seen[ns.GLOBAL_CHOICE_KEY] = true
    end

    for _, choice in ipairs(ns.FONT_CHOICES) do
        AddChoice(choice.key, choice.name, choice.path)
    end

    local sharedMedia = GetSharedMedia()
    if sharedMedia and sharedMedia.HashTable then
        local fontTable = sharedMedia:HashTable("font")
        if type(fontTable) == "table" then
            local names = {}
            for fontName in pairs(fontTable) do
                names[#names + 1] = fontName
            end
            table.sort(names, function(left, right)
                return left:upper() < right:upper()
            end)

            for _, fontName in ipairs(names) do
                AddChoice(fontName, fontName, fontTable[fontName])
            end
        end
    end

    return choices
end

local function BuildStatusBarTextureChoiceList(includeGlobalChoice)
    local choices = {}
    local seen = {}

    local function AddChoice(key, name, path)
        local normalizedKey = NormalizeStatusBarTextureKey(key)
        local lookup = normalizedKey:lower()
        if seen[lookup] then
            return
        end

        seen[lookup] = true
        choices[#choices + 1] = {
            key = normalizedKey,
            name = name or normalizedKey,
            path = path,
        }
    end

    if includeGlobalChoice == true then
        choices[#choices + 1] = {
            key = ns.GLOBAL_CHOICE_KEY,
            name = "Global",
            path = nil,
        }
        seen[ns.GLOBAL_CHOICE_KEY] = true
    end

    for _, choice in ipairs(ns.STATUSBAR_TEXTURE_CHOICES) do
        AddChoice(choice.key, choice.name, choice.path)
    end

    local sharedMedia = GetSharedMedia()
    if sharedMedia and sharedMedia.HashTable then
        local textureTable = sharedMedia:HashTable("statusbar")
        if type(textureTable) == "table" then
            local names = {}
            for textureName in pairs(textureTable) do
                names[#names + 1] = textureName
            end
            table.sort(names, function(left, right)
                return left:upper() < right:upper()
            end)

            for _, textureName in ipairs(names) do
                AddChoice(textureName, textureName, textureTable[textureName])
            end
        end
    end

    return choices
end

local function BuildBorderTextureChoiceList(includeGlobalChoice)
    local choices = {}
    local seen = {}

    local function AddChoice(choice, name, path)
        local choiceData = choice
        if type(choiceData) ~= "table" then
            choiceData = {
                key = choice,
                name = name,
                path = path,
            }
        end

        local normalizedKey = NormalizeBorderTextureKey(choiceData.key)
        local lookup = normalizedKey:lower()
        if seen[lookup] then
            return
        end

        seen[lookup] = true
        choices[#choices + 1] = {
            key = normalizedKey,
            name = choiceData.name or normalizedKey,
            path = choiceData.path,
            tile = choiceData.tile,
            tileSize = choiceData.tileSize,
            edgeSize = choiceData.edgeSize,
            previewEdgeSize = choiceData.previewEdgeSize,
            scaleStep = choiceData.scaleStep,
            supportsVariableThickness = choiceData.supportsVariableThickness,
            preserveColor = choiceData.preserveColor,
            insets = choiceData.insets,
        }
    end

    if includeGlobalChoice == true then
        choices[#choices + 1] = {
            key = ns.GLOBAL_CHOICE_KEY,
            name = "Global",
            path = nil,
        }
        seen[ns.GLOBAL_CHOICE_KEY] = true
    end

    for _, choice in ipairs(ns.BORDER_TEXTURE_CHOICES) do
        AddChoice(choice)
    end

    local sharedMedia = GetSharedMedia()
    if sharedMedia and sharedMedia.HashTable then
        local textureTable = sharedMedia:HashTable("border")
        if type(textureTable) == "table" then
            local names = {}
            for textureName in pairs(textureTable) do
                names[#names + 1] = textureName
            end
            table.sort(names, function(left, right)
                return left:upper() < right:upper()
            end)

            for _, textureName in ipairs(names) do
                AddChoice({
                    key = textureName,
                    name = textureName,
                    path = textureTable[textureName],
                })
            end
        end
    end

    return choices
end

local fontOutlinesByKey = {}
for _, choice in ipairs(ns.FONT_OUTLINE_CHOICES) do
    fontOutlinesByKey[choice.key] = choice
end

local glowChoicesByKey = {}
for _, choice in ipairs(ns.GLOW_CHOICES) do
    glowChoicesByKey[choice.key] = choice
end

local glowTypesByKey = {}
for _, choice in ipairs(ns.GLOW_TYPE_CHOICES) do
    glowTypesByKey[choice.key] = choice
end

function ns.GetPreferredGlobalFontKey()
    local preferredKey = NormalizeFontKey(PREFERRED_GLOBAL_FONT_NAME)

    for _, choice in ipairs(BuildFontChoiceList(false)) do
        if NormalizeFontKey(choice.key) == preferredKey then
            return choice.key
        end
    end

    return DEFAULT_FONT_NAME
end

function ns.GetPreferredGlobalTextureKey()
    local preferredKey = NormalizeStatusBarTextureKey(PREFERRED_GLOBAL_TEXTURE_KEY)

    for _, choice in ipairs(BuildStatusBarTextureChoiceList(false)) do
        if NormalizeStatusBarTextureKey(choice.key) == preferredKey then
            return choice.key
        end
    end

    return DEFAULT_STATUSBAR_TEXTURE_KEY
end

function ns.GetPreferredGlobalBorderTextureKey()
    local preferredKey = NormalizeBorderTextureKey(PREFERRED_GLOBAL_BORDER_TEXTURE_KEY)

    for _, choice in ipairs(BuildBorderTextureChoiceList(false)) do
        if NormalizeBorderTextureKey(choice.key) == preferredKey then
            return choice.key
        end
    end

    return DEFAULT_BORDER_TEXTURE_KEY
end

function ns.GetFontChoices(includeGlobalChoice)
    return BuildFontChoiceList(includeGlobalChoice == true)
end

function ns.GetFontPath(key)
    local normalizedKey = NormalizeFontKey(key)

    if normalizedKey == ns.GLOBAL_CHOICE_KEY then
        normalizedKey = NormalizeFontKey(GetResolvedGlobalFontKey())
    elseif normalizedKey == ns.GLOBAL_STYLE_FONT_AUTO_KEY then
        normalizedKey = NormalizeFontKey(ns.GetPreferredGlobalFontKey())
    end

    if normalizedKey:find("\\") or normalizedKey:find("/") then
        return normalizedKey
    end

    local sharedMedia = GetSharedMedia()
    if sharedMedia and sharedMedia.Fetch and sharedMedia:IsValid("font", normalizedKey) then
        local fontPath = sharedMedia:Fetch("font", normalizedKey, true)
        if fontPath then
            return fontPath
        end
    end

    for _, choice in ipairs(ns.FONT_CHOICES) do
        if NormalizeFontKey(choice.key) == normalizedKey then
            return choice.path or DEFAULT_FONT_PATH
        end
    end

    return DEFAULT_FONT_PATH
end

function ns.GetFontLabel(key)
    local normalizedKey = NormalizeFontKey(key)

    if normalizedKey == ns.GLOBAL_CHOICE_KEY then
        return "Global"
    elseif normalizedKey == ns.GLOBAL_STYLE_FONT_AUTO_KEY then
        normalizedKey = NormalizeFontKey(ns.GetPreferredGlobalFontKey())
    end

    for _, choice in ipairs(BuildFontChoiceList(false)) do
        if choice.key == normalizedKey then
            return choice.name or normalizedKey
        end
    end

    if normalizedKey:find("\\") or normalizedKey:find("/") then
        return normalizedKey
    end

    return DEFAULT_FONT_NAME
end

function ns.GetStatusBarTextureChoices(includeGlobalChoice)
    return BuildStatusBarTextureChoiceList(includeGlobalChoice == true)
end

function ns.GetBorderTextureChoices(includeGlobalChoice)
    return BuildBorderTextureChoiceList(includeGlobalChoice == true)
end

function ns.GetStatusBarTexturePath(key)
    local normalizedKey = NormalizeStatusBarTextureKey(key)

    if normalizedKey == ns.GLOBAL_CHOICE_KEY then
        normalizedKey = NormalizeStatusBarTextureKey(GetResolvedGlobalTextureKey())
    elseif normalizedKey == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY then
        normalizedKey = NormalizeStatusBarTextureKey(ns.GetPreferredGlobalTextureKey())
    end

    if normalizedKey:find("\\") or normalizedKey:find("/") then
        return normalizedKey
    end

    local sharedMedia = GetSharedMedia()
    if sharedMedia and sharedMedia.Fetch and sharedMedia:IsValid("statusbar", normalizedKey) then
        local texturePath = sharedMedia:Fetch("statusbar", normalizedKey, true)
        if texturePath then
            return texturePath
        end
    end

    for _, choice in ipairs(ns.STATUSBAR_TEXTURE_CHOICES) do
        if choice.key == normalizedKey then
            return choice.path or DEFAULT_STATUSBAR_TEXTURE_PATH
        end
    end

    return DEFAULT_STATUSBAR_TEXTURE_PATH
end

function ns.GetBorderTexturePath(key)
    local definition = ns.GetBorderTextureDefinition and ns.GetBorderTextureDefinition(key) or nil
    return (definition and definition.path) or DEFAULT_BORDER_TEXTURE_PATH
end

function ns.GetBorderTextureDefinition(key)
    local normalizedKey = NormalizeBorderTextureKey(key)

    if normalizedKey == ns.GLOBAL_CHOICE_KEY then
        normalizedKey = NormalizeBorderTextureKey(GetResolvedGlobalBorderTextureKey())
    elseif normalizedKey == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY then
        normalizedKey = NormalizeBorderTextureKey(ns.GetPreferredGlobalBorderTextureKey())
    end

    if normalizedKey:find("\\") or normalizedKey:find("/") then
        local matchedChoice = FindBorderTextureChoiceByPath(normalizedKey)
        if matchedChoice then
            return BuildBorderTextureDefinition(matchedChoice)
        end

        return BuildBorderTextureDefinition({
            key = normalizedKey,
            name = normalizedKey,
            path = normalizedKey,
        })
    end

    local sharedMedia = GetSharedMedia()
    if sharedMedia and sharedMedia.Fetch and sharedMedia:IsValid("border", normalizedKey) then
        local texturePath = sharedMedia:Fetch("border", normalizedKey, true)
        if texturePath then
            local matchedChoice = FindBorderTextureChoiceByPath(texturePath)
            if matchedChoice then
                return BuildBorderTextureDefinition(matchedChoice)
            end

            return BuildBorderTextureDefinition({
                key = normalizedKey,
                name = normalizedKey,
                path = texturePath,
            })
        end
    end

    for _, choice in ipairs(ns.BORDER_TEXTURE_CHOICES) do
        if choice.key == normalizedKey then
            return BuildBorderTextureDefinition(choice)
        end
    end

    return BuildBorderTextureDefinition(ns.BORDER_TEXTURE_CHOICES[1])
end

function ns.GetBorderTextureLabel(key)
    local normalizedKey = NormalizeBorderTextureKey(key)

    if normalizedKey == ns.GLOBAL_CHOICE_KEY then
        return "Global"
    elseif normalizedKey == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY then
        normalizedKey = NormalizeBorderTextureKey(ns.GetPreferredGlobalBorderTextureKey())
    end

    for _, choice in ipairs(BuildBorderTextureChoiceList(false)) do
        if choice.key == normalizedKey then
            return choice.name or normalizedKey
        end
    end

    if normalizedKey:find("\\") or normalizedKey:find("/") then
        return normalizedKey
    end

    return "Solid Line"
end

function ns.GetStatusBarTextureLabel(key)
    local normalizedKey = NormalizeStatusBarTextureKey(key)

    if normalizedKey == ns.GLOBAL_CHOICE_KEY then
        return "Global"
    elseif normalizedKey == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY then
        normalizedKey = NormalizeStatusBarTextureKey(ns.GetPreferredGlobalTextureKey())
    end

    for _, choice in ipairs(BuildStatusBarTextureChoiceList(false)) do
        if choice.key == normalizedKey then
            return choice.name or normalizedKey
        end
    end

    if normalizedKey:find("\\") or normalizedKey:find("/") then
        return normalizedKey
    end

    return "Default Status Bar"
end

function ns.GetFontOutlineChoices(includeGlobalChoice)
    if includeGlobalChoice ~= true then
        return ns.FONT_OUTLINE_CHOICES
    end

    local choices = {
        {
            key = ns.GLOBAL_CHOICE_KEY,
            name = "Global",
            flags = nil,
        },
    }

    for _, choice in ipairs(ns.FONT_OUTLINE_CHOICES) do
        choices[#choices + 1] = choice
    end

    return choices
end

function ns.GetFontOutlineFlags(key)
    if key == ns.GLOBAL_CHOICE_KEY then
        local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
        key = settings and settings.fontOutline or "OUTLINE"
    end

    local choice = fontOutlinesByKey[key or ""] or fontOutlinesByKey.OUTLINE
    return choice and choice.flags or "OUTLINE"
end

function ns.GetFontOutlineLabel(key)
    if key == ns.GLOBAL_CHOICE_KEY then
        return "Global"
    end

    local choice = fontOutlinesByKey[key or ""] or fontOutlinesByKey.OUTLINE
    return choice and choice.name or "Outline"
end

function ns.GetGlowChoices()
    return ns.GLOW_CHOICES
end

function ns.GetGlowLabel(key)
    local choice = glowChoicesByKey[key or ""] or glowChoicesByKey.ready_check
    return choice and choice.name or "Ready Check"
end

function ns.GetGlowTypeChoices()
    return ns.GLOW_TYPE_CHOICES
end

function ns.GetGlowTypeLabel(key)
    local choice = glowTypesByKey[key or ""] or glowTypesByKey.button
    return choice and choice.name or "Action Button Glow"
end

function ns.GetGlowSizeLabel(key)
    return ns.GLOW_SIZE_LABELS[key or "button"] or ns.GLOW_SIZE_LABELS.button
end

function ns.GetGlowSizeSuffix(key)
    return ns.GLOW_SIZE_SUFFIX[key or "button"] or ns.GLOW_SIZE_SUFFIX.button
end

function ns.GetInstanceFilters()
    return ns.INSTANCE_FILTERS
end

function ns.CycleChoice(kind, currentKey, direction)
    local choices = ns.GetChoices(kind)
    local index = 1

    for candidateIndex, choice in ipairs(choices) do
        if choice.key == currentKey then
            index = candidateIndex
            break
        end
    end

    index = index + direction
    if index < 1 then
        index = #choices
    elseif index > #choices then
        index = 1
    end

    return choices[index] and choices[index].key or currentKey
end
