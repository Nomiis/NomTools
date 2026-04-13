local addonName, ns = ...

local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

local DEBUG_OVERLAY_MARGIN = 12
local DEBUG_OVERLAY_MIN_WIDTH = 240
local DEBUG_OVERLAY_MIN_HEIGHT = 60
local DEBUG_OVERLAY_CPU_INTERVAL = 1
local DEBUG_OVERLAY_MEMORY_INTERVAL = 5
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local debugOverlayFrame
local debugOverlayCPUElapsed = 0
local debugOverlayMemoryElapsed = 0
local debugOverlayCachedMemory = nil

local NOMTOOLS_MODULE_ADDONS = {
    { addonKey = "NomTools",                  label = "Core" },
    { addonKey = "NomTools_Classes",          label = "Classes" },
    { addonKey = "NomTools_Consumables",      label = "Consumables" },
    { addonKey = "NomTools_Housing",          label = "Housing" },
    { addonKey = "NomTools_ObjectiveTracker", label = "ObjTracker" },
    { addonKey = "NomTools_Options",          label = "Options" },
    { addonKey = "NomTools_Reminders",        label = "Reminders" },
    { addonKey = "NomTools_WorldQuests",      label = "WorldQuests" },
}

local function IsCPUDebugEnabled()
    local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
    return settings and settings.debugModeCPU == true or false
end

local function IsMemoryDebugEnabled()
    local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
    return settings and settings.debugModeMemory == true or false
end

local function IsAnyDebugEnabled()
    return IsCPUDebugEnabled() or IsMemoryDebugEnabled()
end

local function CanUseAddonProfiler()
    return C_AddOnProfiler
        and C_AddOnProfiler.IsEnabled
        and C_AddOnProfiler.GetAddOnMetric
        and C_AddOnProfiler.GetApplicationMetric
        and C_AddOnProfiler.GetOverallMetric
        and Enum
        and Enum.AddOnProfilerMetric
        and C_AddOnProfiler.IsEnabled()
end

local function FormatMemoryUsage(memoryKilobytes)
    if type(memoryKilobytes) ~= "number" then
        return "n/a"
    end

    if memoryKilobytes >= 1024 then
        return string.format("%.2f MB", memoryKilobytes / 1024)
    end

    return string.format("%.0f KB", memoryKilobytes)
end

local function FormatTime(ms)
    if type(ms) ~= "number" or ms <= 0 then
        return "0µs"
    end
    if ms >= 1 then
        return string.format("%.2fms", ms)
    end
    return string.format("%.0fµs", ms * 1000)
end

local function FormatCPUPercent(cpuPercent)
    if type(cpuPercent) ~= "number" then
        return "n/a"
    end

    cpuPercent = math.max(0, cpuPercent)
    if cpuPercent >= 1 then
        return string.format("%.0f%%", cpuPercent)
    elseif cpuPercent >= 0.1 then
        return string.format("%.1f%%", cpuPercent)
    elseif cpuPercent >= 0.01 then
        return string.format("%.2f%%", cpuPercent)
    end

    return "0%"
end

local function GetApplicationPercent(rawValue, applicationValue)
    if type(applicationValue) ~= "number" or applicationValue <= 0 then
        return 0
    end
    if type(rawValue) ~= "number" or rawValue <= 0 then
        return 0
    end
    return (rawValue / applicationValue) * 100
end

local function GetCPUStats()
    if not CanUseAddonProfiler() then
        return { available = false }
    end

    local metric = Enum.AddOnProfilerMetric
    local appCurrent = C_AddOnProfiler.GetApplicationMetric(metric.RecentAverageTime)

    if type(appCurrent) ~= "number" or appCurrent <= 0 then
        return { available = true, source = "profiler", noData = true }
    end

    local totalCurrentRaw = 0
    local totalAverageRaw = 0
    local totalPeakRaw    = 0
    local modules = {}

    for _, mod in ipairs(NOMTOOLS_MODULE_ADDONS) do
        if isAddOnLoaded(mod.addonKey) then
            local cur = tonumber(C_AddOnProfiler.GetAddOnMetric(mod.addonKey, metric.RecentAverageTime)) or 0
            local avg = tonumber(C_AddOnProfiler.GetAddOnMetric(mod.addonKey, metric.SessionAverageTime)) or 0
            local pk  = tonumber(C_AddOnProfiler.GetAddOnMetric(mod.addonKey, metric.PeakTime)) or 0
            totalCurrentRaw = totalCurrentRaw + cur
            totalAverageRaw = totalAverageRaw + avg
            if pk > totalPeakRaw then
                totalPeakRaw = pk
            end
            modules[#modules + 1] = { label = mod.label, avgMs = avg, currentPercent = GetApplicationPercent(cur, appCurrent) }
        end
    end

    table.sort(modules, function(a, b) return a.avgMs > b.avgMs end)

    return {
        available = true,
        source = "profiler",
        totalCurrentPercent = GetApplicationPercent(totalCurrentRaw, appCurrent),
        totalAverageMs      = totalAverageRaw,
        totalPeakMs         = totalPeakRaw,
        modules = modules,
    }
end

local function GetDebugOverlayFrame()
    if debugOverlayFrame then
        return debugOverlayFrame
    end

    local frame = CreateFrame("Frame", addonName .. "DebugOverlay", UIParent)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEBUG_OVERLAY_MARGIN, -DEBUG_OVERLAY_MARGIN)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.8)
    frame.background = background

    local text = frame:CreateFontString(nil, "ARTWORK")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(3)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    frame.text = text

    debugOverlayFrame = frame
    return debugOverlayFrame
end

local function ApplyDebugOverlayStyle(frame)
    local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or (ns.DEFAULTS and ns.DEFAULTS.globalSettings) or {}
    local fontPath = ns.GetFontPath and ns.GetFontPath(settings.font) or DEFAULT_FONT_PATH
    local fontOutline = settings.fontOutline or "OUTLINE"

    frame.text:SetFont(fontPath, 12, fontOutline)
    frame.text:SetTextColor(1, 1, 1)
end

local function UpdateDebugOverlayMemory()
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
        debugOverlayCachedMemory = GetAddOnMemoryUsage(addonName)
    end
end

local function UpdateDebugOverlayText()
    local frame = GetDebugOverlayFrame()
    local lines = "|cffffd100NomTools Debug|r"

    if IsMemoryDebugEnabled() then
        lines = lines .. "\nMemory: " .. FormatMemoryUsage(debugOverlayCachedMemory)
    end

    if IsCPUDebugEnabled() then
        local cpuStats = GetCPUStats()
        if not cpuStats.available then
            lines = lines .. "\nCPU: unavailable (enable Blizzard AddOn profiler)"
        elseif cpuStats.noData then
            lines = lines .. "\nCPU: profiler enabled, no data yet"
        else
            lines = lines .. "\nCPU: " .. FormatCPUPercent(cpuStats.totalCurrentPercent)
                .. "  avg " .. FormatTime(cpuStats.totalAverageMs)
                .. "  peak " .. FormatTime(cpuStats.totalPeakMs)
            for _, mod in ipairs(cpuStats.modules) do
                lines = lines .. "\n  " .. mod.label .. ": " .. FormatTime(mod.avgMs) .. " avg"
                if mod.currentPercent >= 0.005 then
                    lines = lines .. "  (" .. FormatCPUPercent(mod.currentPercent) .. " now)"
                end
            end
        end
    end

    frame.text:SetText(lines)

    local width = math.max(DEBUG_OVERLAY_MIN_WIDTH, math.ceil(frame.text:GetStringWidth()) + 16)
    local height = math.max(DEBUG_OVERLAY_MIN_HEIGHT, math.ceil(frame.text:GetStringHeight()) + 16)
    frame:SetSize(width, height)
end

local function DebugOverlayOnUpdate(_, elapsed)
    elapsed = elapsed or 0
    local needsTextUpdate = false

    if IsCPUDebugEnabled() then
        debugOverlayCPUElapsed = debugOverlayCPUElapsed + elapsed
        if debugOverlayCPUElapsed >= DEBUG_OVERLAY_CPU_INTERVAL then
            debugOverlayCPUElapsed = 0
            needsTextUpdate = true
        end
    end

    if IsMemoryDebugEnabled() then
        debugOverlayMemoryElapsed = debugOverlayMemoryElapsed + elapsed
        if debugOverlayMemoryElapsed >= DEBUG_OVERLAY_MEMORY_INTERVAL then
            debugOverlayMemoryElapsed = 0
            UpdateDebugOverlayMemory()
            needsTextUpdate = true
        end
    end

    if needsTextUpdate then
        UpdateDebugOverlayText()
    end
end

function ns.IsDebugEnabled()
    local settings = ns.GetGlobalSettings and ns.GetGlobalSettings() or nil
    return settings and settings.enableDebug == true or false
end

function ns.DebugPrint(...)
    if not ns.IsDebugEnabled() then
        return
    end
    print("[NomTools]", ...)
end

function ns.RefreshDebugOverlay()
    local frame = GetDebugOverlayFrame()

    if not IsAnyDebugEnabled() then
        debugOverlayCPUElapsed = 0
        debugOverlayMemoryElapsed = 0
        debugOverlayCachedMemory = nil
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        return
    end

    debugOverlayCPUElapsed = 0
    debugOverlayMemoryElapsed = 0
    ApplyDebugOverlayStyle(frame)
    if IsMemoryDebugEnabled() then
        UpdateDebugOverlayMemory()
    end
    UpdateDebugOverlayText()
    frame:SetScript("OnUpdate", DebugOverlayOnUpdate)
    frame:Show()
end