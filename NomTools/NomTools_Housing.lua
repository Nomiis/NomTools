local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
end

if not ns then
    return
end

-- ============================================================
-- NomTools Housing: Custom Sort & "New" Markers
--
-- When Blizzard's "Sort by: Date Added" is selected in the
-- housing storage panel, NomTools overrides the sort with its own
-- acquisition-timestamp tracking so that recently obtained items
-- appear first — including duplicates of items you already own.
--
-- Items gained since the last home visit are also marked with
-- "New" text on their grid card.  The markers persist across
-- relogs but are cleared when the player leaves the neighborhood.
-- Sort timestamps persist forever.
-- ============================================================

-- ============================================================
-- Runtime state (session-only, rebuilt each session)
-- ============================================================
local hooksRegistered       = false
local entryHookInstalled    = false
local merchantFrameHooked   = false
local isAtOwnHome           = false
local detectionBaseline     = nil     -- runtime copy of lastHomeSnapshot; updated after each detect pass
local entryQuantityCache    = {}      -- "rid:sub:subId" → qty (per-stack, for live tracking)
local plotExitCheckPending  = false
local ownedHouseGuids       = {}
local ownedPlotIds          = {}
local hasOwnedHouseCache    = false

-- Scratch tables for catalog sort (reused to avoid per-sort allocations)
local housingSortKnownScratch   = {}
local housingSortUnknownScratch = {}
local housingSortEntriesScratch = {}
local housingSortTimestamps     = nil

local function HousingSortComparator(a, b)
    local ta = housingSortTimestamps[a.recordID]
    local tb = housingSortTimestamps[b.recordID]
    if ta ~= tb then return ta > tb end
    return (a.recordID or 0) > (b.recordID or 0)
end

-- ============================================================
-- Saved-var sub-table helpers
-- ============================================================
local function GetSettings()
    return ns.GetHousingSettings and ns.GetHousingSettings()
end

local function IsHousingModuleActive()
    local settings = GetSettings()
    local enabled = settings and settings.enabled
    if ns.IsModuleRuntimeEnabled then
        return ns.IsModuleRuntimeEnabled("housing", enabled)
    end

    return enabled ~= false
end

local function GetSortTimestamps()
    local s = GetSettings()
    if not s then return {} end
    if type(s.sortTimestamps) ~= "table" then s.sortTimestamps = {} end
    return s.sortTimestamps
end

local function GetLastHomeSnapshot()
    local s = GetSettings()
    if not s then return {} end
    if type(s.lastHomeSnapshot) ~= "table" then s.lastHomeSnapshot = {} end
    for recordID, quantity in pairs(s.lastHomeSnapshot) do
        if (tonumber(quantity) or 0) <= 0 then
            s.lastHomeSnapshot[recordID] = nil
        end
    end
    return s.lastHomeSnapshot
end

local function GetNewMarkers()
    local s = GetSettings()
    if not s then return {} end
    if type(s.newMarkers) ~= "table" then s.newMarkers = {} end
    return s.newMarkers
end

local function GetFirstOwnershipMarkers()
    local s = GetSettings()
    if not s then return {} end
    if type(s.firstOwnershipMarkers) ~= "table" then s.firstOwnershipMarkers = {} end
    return s.firstOwnershipMarkers
end

local function GetEverOwnedRecords()
    local s = GetSettings()
    if not s then return {} end
    if type(s.everOwnedRecords) ~= "table" then s.everOwnedRecords = {} end
    return s.everOwnedRecords
end

local function HasNewMarkers()
    local markers = GetNewMarkers()
    return next(markers) ~= nil
end

local function HaveNewMarkersBeenSeen()
    local s = GetSettings()
    return s and s.newMarkersSeen == true
end

local function MarkNewMarkersUnseen()
    local s = GetSettings()
    if s then
        s.newMarkersSeen = false
    end
end

local function MarkNewMarkersSeen()
    local s = GetSettings()
    if s and HasNewMarkers() then
        s.newMarkersSeen = true
    end
end

local function CopyQuantitySnapshot(source)
    if type(source) ~= "table" then return nil end

    local copy = {}
    for recordID, quantity in pairs(source) do
        local normalizedQuantity = tonumber(quantity) or 0
        if normalizedQuantity > 0 then
            copy[recordID] = normalizedQuantity
        end
    end

    return copy
end

local function RecordEverOwnedSnapshot(snapshot)
    if type(snapshot) ~= "table" then return end

    local everOwnedRecords = GetEverOwnedRecords()
    for recordID, quantity in pairs(snapshot) do
        if (quantity or 0) > 0 then
            everOwnedRecords[recordID] = true
        end
    end
end

local function ClearNewMarkers()
    local s = GetSettings()
    if s and type(s.newMarkers) == "table" then
        wipe(s.newMarkers)
    end
    if s and type(s.firstOwnershipMarkers) == "table" then
        wipe(s.firstOwnershipMarkers)
    end
    if s then
        s.newMarkersSeen = false
    end
end

local function NormalizeOwnerName(name)
    if type(name) ~= "string" or name == "" then return nil end
    return string.lower(name)
end

local function GetPlayerOwnerNames()
    local playerName, playerRealm = UnitFullName and UnitFullName("player")
    if not playerName or playerName == "" then return nil, nil end

    local normalizedShortName = NormalizeOwnerName(playerName)
    local normalizedFullName = normalizedShortName
    if playerRealm and playerRealm ~= "" then
        normalizedFullName = NormalizeOwnerName(playerName .. "-" .. playerRealm)
    end

    return normalizedShortName, normalizedFullName
end

local function UpdateOwnedHouseCache(houseList)
    wipe(ownedHouseGuids)
    wipe(ownedPlotIds)
    hasOwnedHouseCache = false

    if type(houseList) ~= "table" then
        return
    end

    for _, houseInfo in ipairs(houseList) do
        if type(houseInfo) == "table" then
            if houseInfo.houseGUID then
                ownedHouseGuids[houseInfo.houseGUID] = true
                hasOwnedHouseCache = true
            end
            if houseInfo.plotID then
                ownedPlotIds[houseInfo.plotID] = true
                hasOwnedHouseCache = true
            end
        end
    end
end

local function RequestOwnedHouseCacheRefresh()
    if C_Housing and C_Housing.GetPlayerOwnedHouses then
        C_Housing.GetPlayerOwnedHouses()
    end
end

local function IsCurrentPlotOwnedByPlayer()
    if not (C_Housing and C_Housing.GetCurrentHouseInfo) then
        return false
    end

    local currentHouseInfo = C_Housing.GetCurrentHouseInfo()
    if type(currentHouseInfo) ~= "table" then
        return false
    end

    if currentHouseInfo.houseGUID and ownedHouseGuids[currentHouseInfo.houseGUID] then
        return true
    end

    if currentHouseInfo.plotID and ownedPlotIds[currentHouseInfo.plotID] then
        return true
    end

    if not hasOwnedHouseCache then
        local normalizedShortName, normalizedFullName = GetPlayerOwnerNames()
        local normalizedOwnerName = NormalizeOwnerName(currentHouseInfo.ownerName)
        if normalizedOwnerName and (normalizedOwnerName == normalizedShortName or normalizedOwnerName == normalizedFullName) then
            return true
        end
    end

    return false
end

local function IsInsideOwnHousing()
    if C_Housing then
        if C_Housing.IsInsideOwnHouse and C_Housing.IsInsideOwnHouse() then
            return true
        end

        if C_Housing.IsInsidePlot and C_Housing.IsInsidePlot() then
            return IsCurrentPlotOwnedByPlayer()
        end
    end

    if C_HouseEditor and C_HouseEditor.GetActiveHouseEditorMode then
        local mode = C_HouseEditor.GetActiveHouseEditorMode()
        local noneMode = Enum.HouseEditorMode and Enum.HouseEditorMode.None
        return mode ~= nil and (noneMode == nil or mode ~= noneMode)
    end

    return false
end

-- ============================================================
-- Quantity snapshots
--
-- We use two representations:
--   recordQty   – recordID → total quantity (sum of all stacks)
--                 Used for arrival comparison against lastHomeSnapshot.
--   entryCacheKey → qty – per-stack (recordID:subtype:subtypeId)
--                 Used for live HOUSING_STORAGE_ENTRY_UPDATED tracking.
-- Both are built in a single pass over GetAllSearchItems().
-- ============================================================
local function GetEntryKey(entryID)
    return entryID.recordID .. ":" .. (entryID.entrySubtype or 0) .. ":" .. (entryID.subtypeIdentifier or 0)
end

-- Build a per-recordID quantity snapshot AND populate the live
-- entry-level cache.  Returns the recordID snapshot or nil.
-- NOTE: IsOwnedOnlyActive does not exist as a Lua API; we don't
-- check it here.  The storage tab always has owned-only = true
-- (Blizzard sets it in OnStorageTabSelected), and this function
-- is only reached from OnUpdateCatalogData which already guards
-- against the market tab via IsInMarketTab.
local function BuildQuantitySnapshot()
    local sp = HouseEditorFrame and HouseEditorFrame.StoragePanel
    if not sp or not sp.catalogSearcher then return nil end
    local allItems = sp.catalogSearcher:GetAllSearchItems()
    if not allItems or #allItems == 0 then return nil end

    local recordQty = {}
    for _, e in ipairs(allItems) do
        if e.recordID then
            local info = C_HousingCatalog.GetCatalogEntryInfo(e)
            if info then
                local qty = (info.quantity or 0) + (info.remainingRedeemable or 0)
                local entryKey = GetEntryKey(e)
                if qty > 0 then
                    recordQty[e.recordID] = (recordQty[e.recordID] or 0) + qty
                    entryQuantityCache[entryKey] = qty
                else
                    entryQuantityCache[entryKey] = nil
                end
            end
        end
    end
    return recordQty
end

-- ============================================================
-- Acquisition detection
--
-- Compares current owned quantities against detectionBaseline
-- (a runtime copy of lastHomeSnapshot, updated after each pass).
-- Any recordID whose quantity increased (or is brand new) gets
-- a sort timestamp and "New" marker.
--
-- Runs on EVERY UpdateCatalogData while at home, not just once,
-- so purchases made at neighborhood vendors (while the storage
-- panel was closed) are caught when the panel reopens.
-- ============================================================
local function DetectAcquisitions()
    local currentSnap = BuildQuantitySnapshot()
    if not currentSnap then return false end

    local s = GetSettings()
    if not s then return false end

    -- First-time install: baseline to current state; don't mark anything new.
    if not detectionBaseline then
        if type(s.lastHomeSnapshot) ~= "table" or not next(s.lastHomeSnapshot) then
            -- If the module was previously enabled, this is a data-recovery scenario
            -- (e.g. saved variables lost to a crash).  Assign a baseline sort timestamp
            -- to every owned item so the custom sort stays functional; future
            -- acquisitions will receive a higher timestamp and appear first.
            if s.enabled == true then
                local timestamps = GetSortTimestamps()
                for rid in pairs(currentSnap) do
                    if not timestamps[rid] then
                        timestamps[rid] = 1
                    end
                end
            end
            s.lastHomeSnapshot = currentSnap
            detectionBaseline = currentSnap
            RecordEverOwnedSnapshot(currentSnap)
            return true
        end
        -- Copy persisted snapshot into runtime baseline.
        detectionBaseline = CopyQuantitySnapshot(s.lastHomeSnapshot) or {}
        RecordEverOwnedSnapshot(detectionBaseline)
    end

    local timestamps = GetSortTimestamps()
    local markers = GetNewMarkers()
    local firstOwnershipMarkers = GetFirstOwnershipMarkers()
    local everOwnedRecords = GetEverOwnedRecords()
    local firstOwnershipOnly = s.newMarkersFirstOwnershipOnly == true
    local now = time()

    for rid, newQty in pairs(currentSnap) do
        local oldQty = detectionBaseline[rid] or 0
        if newQty > oldQty then
            local isFirstOwnership = everOwnedRecords[rid] ~= true
            timestamps[rid] = now
            if isFirstOwnership then
                firstOwnershipMarkers[rid] = true
            end
            if not firstOwnershipOnly or isFirstOwnership then
                markers[rid] = true
                MarkNewMarkersUnseen()
            end
            everOwnedRecords[rid] = true
        end
    end

    -- Advance baseline so the next pass only catches further increases.
    detectionBaseline = currentSnap
    s.lastHomeSnapshot = currentSnap
    RecordEverOwnedSnapshot(currentSnap)
    return true
end

-- Save current quantities as the home-departure baseline.
local function SaveLastHomeSnapshot()
    local snap = BuildQuantitySnapshot()
    if not snap and detectionBaseline then
        snap = CopyQuantitySnapshot(detectionBaseline)
    end
    if not snap then return end
    local s = GetSettings()
    if s then s.lastHomeSnapshot = snap end
    RecordEverOwnedSnapshot(snap)
end

-- ============================================================
-- Live tracking: HOUSING_STORAGE_ENTRY_UPDATED while at home
--
-- Uses the per-stack entryQuantityCache to detect increases
-- on individual entries, then updates the per-recordID sort
-- timestamp and "New" marker.
-- ============================================================
local function OnStorageEntryUpdatedWhileHome(entryID)
    if not entryID or not entryID.recordID then return end

    local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
    if not info then return end

    local s = GetSettings()
    if not s then return end

    if not detectionBaseline then
        detectionBaseline = CopyQuantitySnapshot(GetLastHomeSnapshot()) or {}
        RecordEverOwnedSnapshot(detectionBaseline)
    end

    local key = GetEntryKey(entryID)
    local newQty = (info.quantity or 0) + (info.remainingRedeemable or 0)
    local oldQty = entryQuantityCache[key] or 0
    entryQuantityCache[key] = newQty

    if newQty > oldQty then
        detectionBaseline[entryID.recordID] = (detectionBaseline[entryID.recordID] or 0) + (newQty - oldQty)
        if type(s.lastHomeSnapshot) == "table" then
            s.lastHomeSnapshot[entryID.recordID] = detectionBaseline[entryID.recordID]
        end
        local timestamps = GetSortTimestamps()
        local markers = GetNewMarkers()
        local firstOwnershipMarkers = GetFirstOwnershipMarkers()
        local everOwnedRecords = GetEverOwnedRecords()
        local isFirstOwnership = everOwnedRecords[entryID.recordID] ~= true
        timestamps[entryID.recordID] = time()
        if isFirstOwnership then
            firstOwnershipMarkers[entryID.recordID] = true
        end
        if s.newMarkersFirstOwnershipOnly ~= true or isFirstOwnership then
            markers[entryID.recordID] = true
            MarkNewMarkersUnseen()
        end
        everOwnedRecords[entryID.recordID] = true
    end
end

-- ============================================================
-- "New" marker injection on grid cards
--
-- Hooks catalog entry UpdateVisuals so that every time a grid
-- card refreshes, we check newMarkers for its recordID and
-- show/hide a small "New" FontString overlay.
--
-- HousingCatalogDecorEntryMixin is created via
-- CreateFromMixins(HousingCatalogEntryMixin) BEFORE we can
-- hook, so it has its own copy of UpdateVisuals.  The XML
-- template applies the derived mixin last, overwriting the
-- base.  We therefore hook BOTH the base (covers room entries)
-- and the decor-specific mixin (covers decor entries).
-- ============================================================
local function NewMarkerPostHook(self)
    local s = GetSettings()
    local markers = s and s.newMarkers
    local firstOwnershipMarkers = s and s.firstOwnershipMarkers
    local show = false
    if s and s.showNewMarkers ~= false and markers and self.entryID and self.entryID.recordID then
        local recordID = self.entryID.recordID
        show = markers[recordID] == true
        if show and s.newMarkersFirstOwnershipOnly == true then
            show = firstOwnershipMarkers and firstOwnershipMarkers[recordID] == true or false
        end
    end

    -- Lazily create the overlay matching Blizzard's NewFeatureLabelTemplate:
    -- GameFontHighlight text with a collections-newglow atlas glow behind it,
    -- plus a dark shadow FontString offset by (0.5, -0.5).
    if not self.NomToolsNewFrame then
        local f = CreateFrame("Frame", nil, self)
        f:SetFrameStrata("HIGH")
        f:SetFrameLevel(self:GetFrameLevel() + 10)
        f:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -8)

        -- Shadow text (offset behind the main label)
        local bg = f:CreateFontString(nil, "OVERLAY", "GameFontNormal_NoShadow")
        bg:SetText(NEW_CAPS or "NEW")
        if NEW_FEATURE_SHADOW_COLOR then
            bg:SetTextColor(NEW_FEATURE_SHADOW_COLOR:GetRGBA())
        else
            bg:SetTextColor(0, 0, 0, 0.8)
        end

        -- Main label
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetText(NEW_CAPS or "NEW")
        label:SetPoint("CENTER", f, "CENTER", 0, 0)
        if NEW_FEATURE_SHADOW_COLOR then
            label:SetShadowColor(NEW_FEATURE_SHADOW_COLOR:GetRGBA())
        end

        bg:SetPoint("CENTER", label, "CENTER", 0.5, -0.5)

        -- Glow texture behind the text
        local glow = f:CreateTexture(nil, "OVERLAY", nil, 0)
        glow:SetAtlas("collections-newglow")
        glow:SetPoint("TOPLEFT", label, "TOPLEFT", -20, 10)
        glow:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 20, -10)
        glow:SetAlpha(0.7)

        -- Size the frame to the label
        f:SetSize(label:GetStringWidth() + 4, label:GetStringHeight() + 2)

        f.label = label
        f.bg = bg
        f.glow = glow
        self.NomToolsNewFrame = f
    end

    self.NomToolsNewFrame:SetShown(show)
end

local function InstallEntryHook()
    if entryHookInstalled then return end
    if not HousingCatalogEntryMixin then return end
    entryHookInstalled = true

    hooksecurefunc(HousingCatalogEntryMixin, "UpdateVisuals", NewMarkerPostHook)
    if HousingCatalogDecorEntryMixin and HousingCatalogDecorEntryMixin.UpdateVisuals then
        hooksecurefunc(HousingCatalogDecorEntryMixin, "UpdateVisuals", NewMarkerPostHook)
    end
    if HousingCatalogRoomEntryMixin and HousingCatalogRoomEntryMixin.UpdateVisuals then
        hooksecurefunc(HousingCatalogRoomEntryMixin, "UpdateVisuals", NewMarkerPostHook)
    end
end

-- ============================================================
-- Vendor multi-buy (Shift+Right-Click on housing items)
-- ============================================================

-- Progress bar frame (created lazily on first use).
local multiBuyProgressFrame
local MULTIBUY_FRAME_W        = 240
local MULTIBUY_BAR_W          = 208   -- frame width minus 16 px padding each side
local MULTIBUY_BAR_FILL_MAXW  = MULTIBUY_BAR_W - 2

local function GetOrCreateProgressFrame()
    if multiBuyProgressFrame then return multiBuyProgressFrame end
    local f = CreateFrame("Frame", "NomToolsMultiBuyProgressFrame", UIParent, "BackdropTemplate")
    f:SetSize(MULTIBUY_FRAME_W, 66)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 32, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:Hide()
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    title:SetWidth(MULTIBUY_FRAME_W - 32)
    title:SetJustifyH("LEFT")
    f.title = title

    local barBg = f:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -30)
    barBg:SetSize(MULTIBUY_BAR_W, 14)
    barBg:SetColorTexture(0, 0, 0, 0.6)

    local barFill = f:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    barFill:SetSize(1, 12)
    barFill:SetColorTexture(1, 0.53, 0, 1)   -- NomTools orange
    f.barFill = barFill

    local countText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("TOP", barBg, "BOTTOM", 0, -4)
    f.countText = countText

    multiBuyProgressFrame = f
    return f
end

local function UpdateMultiBuyProgress(itemName, bought, total)
    local f = GetOrCreateProgressFrame()
    f.title:SetText("|cffff8800NomTools|r  " .. (itemName or "Buying Decor"))
    if total > 0 then
        f.barFill:SetWidth(math.max(1, MULTIBUY_BAR_FILL_MAXW * bought / total))
    end
    f.countText:SetText(bought .. " / " .. total)
    f:Show()
end

local function HideMultiBuyProgress()
    if multiBuyProgressFrame then
        multiBuyProgressFrame:Hide()
    end
end

-- Active session state; nil = no session running.
-- Fields: id, total, remaining, throttle, itemName, timeoutHandle.
local multiBuySession = nil

local multiBuyEventFrame = CreateFrame("Frame")

local function CancelMultiBuySession(reason)
    if not multiBuySession then return end
    if multiBuySession.timeoutHandle then
        multiBuySession.timeoutHandle:Cancel()
    end
    multiBuySession = nil
    multiBuyEventFrame:UnregisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
    HideMultiBuyProgress()
    if reason then
        print("|cffff8800NomTools|r Multi-Buy stopped: " .. reason)
    end
end

local function MultiBuyAdvance(session)
    if multiBuySession ~= session then return end   -- session superseded or cancelled
    if not (MerchantFrame and MerchantFrame:IsShown()) then
        CancelMultiBuySession(nil)   -- merchant closed between timer ticks — already reported
        return
    end
    if session.remaining <= 0 then
        -- Defensive: session should already be nil by the time remaining hits 0.
        multiBuySession = nil
        multiBuyEventFrame:UnregisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
        C_Timer.After(1, function() if not multiBuySession then HideMultiBuyProgress() end end)
        return
    end
    session.remaining = session.remaining - 1
    BuyMerchantItem(session.id)
    local bought = session.total - session.remaining
    UpdateMultiBuyProgress(session.itemName, bought, session.total)
    if session.remaining <= 0 then
        -- All purchases sent; clean up and hide progress after a brief delay.
        multiBuySession = nil
        multiBuyEventFrame:UnregisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
        C_Timer.After(1, function() if not multiBuySession then HideMultiBuyProgress() end end)
        return
    end
    -- Schedule the next purchase.
    if session.throttle then
        -- Throttled: wait for server confirmation via HOUSING_STORAGE_ENTRY_UPDATED,
        -- with a 3 s safety timeout in case an item ends up in a bag instead.
        session.timeoutHandle = C_Timer.NewTimer(3, function()
            if multiBuySession == session then
                CancelMultiBuySession(
                    "server did not confirm — remaining items not purchased " ..
                    "(item may have ended up in your bag)"
                )
            end
        end)
    else
        -- Unthrottled: fixed 0.1 s stagger.
        session.timeoutHandle = C_Timer.NewTimer(0.1, function()
            session.timeoutHandle = nil
            MultiBuyAdvance(session)
        end)
    end
end

multiBuyEventFrame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_CLOSED" then
        if multiBuySession and multiBuySession.remaining > 0 then
            local remaining = multiBuySession.remaining
            CancelMultiBuySession(remaining .. " item(s) not yet purchased — vendor was closed.")
        else
            CancelMultiBuySession(nil)
        end
    elseif event == "HOUSING_STORAGE_ENTRY_UPDATED" then
        local session = multiBuySession
        if session and session.throttle then
            -- Server confirmed the previous purchase; advance immediately.
            if session.timeoutHandle then
                session.timeoutHandle:Cancel()
                session.timeoutHandle = nil
            end
            MultiBuyAdvance(session)
        end
    end
end)
multiBuyEventFrame:RegisterEvent("MERCHANT_CLOSED")

local function StartMultiBuySession(id, count, throttle, itemName)
    CancelMultiBuySession(nil)   -- cancel any previous session silently
    if count < 1 then return end
    local session = {
        id            = id,
        total         = count,
        remaining     = count,
        throttle      = throttle,
        itemName      = itemName,
        timeoutHandle = nil,
    }
    multiBuySession = session
    -- Defer the first advance by one frame so the StackSplitFrame OK-click handler
    -- (which calls Hide() before SplitStack()) fully unwinds before any purchase
    -- fires.  Without this defer, the first BuyMerchantItem runs synchronously
    -- inside the click event, which can cause the item to land in bags instead of
    -- housing storage.  Also registering the throttle event here avoids a race
    -- where HOUSING_STORAGE_ENTRY_UPDATED fires before item 1 is even sent.
    C_Timer.After(0, function()
        if multiBuySession ~= session then return end
        if throttle then
            multiBuyEventFrame:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
        end
        MultiBuyAdvance(session)
    end)
end

-- Per-open cost display — a Blizzard-style frame attached immediately above StackSplitFrame.
-- Supports gold, item token costs, and named currencies (e.g. "Voidlight Marl"),
-- each rendered as [icon] [amount] [name] with tooltips. Zero hardcoded currencies.
local multiBuyCostFrame = nil   -- Frame parented to StackSplitFrame (created in InstallMerchantHook)
local multiBuyCostInfo  = nil   -- nil = not active; table of per-item cost data when frame is open

local COST_ROW_H   = 20
local COST_PAD_V   = 8    -- total vertical interior padding (4 top + 4 bottom)
local COST_FRAME_W = 172  -- matches StackSplitFrame width (set in ChooseFrameType)

-- Collects all cost components for vendor slot `index`.
-- Returns { goldPerItem, extCosts = { {texture, valuePerItem, itemLink, currencyName, label} } }
-- or nil if the item is free / cost data unavailable.
local function CollectItemCostInfo(index)
    local info = C_MerchantFrame.GetItemInfo(index)
    if not info then return nil end

    local result = {
        goldPerItem = (info.price and info.price > 0) and info.price or nil,
        extCosts    = {},
    }

    if info.hasExtendedCost then
        local numCostItems = GetMerchantItemCostInfo(index) or 0
        for i = 1, numCostItems do
            local texture, value, itemLink, currencyName = GetMerchantItemCostItem(index, i)
            if not texture then break end
            if value and value > 0 then
                local label
                if currencyName then
                    label = currencyName
                elseif itemLink then
                    label = GetItemInfo(itemLink) or itemLink
                else
                    label = ""
                end
                result.extCosts[#result.extCosts + 1] = {
                    texture      = texture,
                    valuePerItem = value,
                    itemLink     = (not currencyName and itemLink) and itemLink or nil,
                    currencyName = currencyName or nil,
                    label        = label,
                }
            end
        end
    end

    return (result.goldPerItem or #result.extCosts > 0) and result or nil
end

-- Refreshes all cost row widgets for `split` copies of the current item.
local function UpdateCostDisplay(split)
    local f = multiBuyCostFrame
    if not f or not multiBuyCostInfo then
        if f then f:Hide() end
        return
    end
    local count      = math.max(1, split or 1)
    local activeRows = 0

    -- Gold row (always rows[1]).
    local goldRow = f.rows[1]
    if multiBuyCostInfo.goldPerItem then
        activeRows = activeRows + 1
        goldRow.icon:Hide()
        goldRow.amtFs:ClearAllPoints()
        goldRow.amtFs:SetPoint("LEFT", goldRow, "LEFT", 0, 0)
        goldRow.amtFs:SetPoint("RIGHT", goldRow, "RIGHT", 0, 0)
        goldRow.amtFs:SetJustifyH("LEFT")
        goldRow.amtFs:SetText(GetCoinTextureString(multiBuyCostInfo.goldPerItem * count))
        goldRow.nameFs:SetText("")
        goldRow._itemLink     = nil
        goldRow._currencyName = nil
        goldRow:ClearAllPoints()
        goldRow:SetPoint("TOPLEFT", f, "TOPLEFT", 8,
            -(COST_PAD_V / 2 + (activeRows - 1) * COST_ROW_H))
        goldRow:SetWidth(COST_FRAME_W - 16)
        goldRow:Show()
    else
        goldRow:Hide()
    end

    -- Extended cost rows (rows[2+]).
    for i, ext in ipairs(multiBuyCostInfo.extCosts) do
        local row = f.rows[1 + i]
        if row then
            activeRows = activeRows + 1
            row.icon:Show()
            row.icon:SetTexture(ext.texture)
            row.amtFs:ClearAllPoints()
            row.amtFs:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
            row.amtFs:SetJustifyH("LEFT")
            row.amtFs:SetText(tostring(ext.valuePerItem * count))
            row.nameFs:SetText(ext.label or "")
            row._itemLink     = ext.itemLink
            row._currencyName = ext.currencyName
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 8,
                -(COST_PAD_V / 2 + (activeRows - 1) * COST_ROW_H))
            row:SetWidth(COST_FRAME_W - 16)
            row:Show()
        end
    end

    -- Hide unused rows.
    for i = #multiBuyCostInfo.extCosts + 2, #f.rows do
        f.rows[i]:Hide()
    end

    f:SetHeight(activeRows * COST_ROW_H + COST_PAD_V)
    f:SetShown(activeRows > 0)
end

local function IsHousingMerchantItem(index)
    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    if not link then return false end
    local classID = select(6, C_Item.GetItemInfoInstant(link))
    return classID == Enum.ItemClass.Housing
end

local function OnMerchantItemButtonModifiedClick(self, button)
    if button ~= "RightButton" then return end
    if not IsModifiedClick("SPLITSTACK") then return end
    local s = GetSettings()
    if not s or s.vendorMultiBuy == false then return end
    if not IsHousingModuleActive() then return end
    if not MerchantFrame or MerchantFrame.selectedTab ~= 1 then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return end
    local index = self:GetID()
    if not IsHousingMerchantItem(index) then return end
    if StackSplitFrame:IsShown() and StackSplitFrame.owner == self then return end
    local info = C_MerchantFrame.GetItemInfo(index)
    if not info or not info.isPurchasable then return end
    local maxAffordable
    if info.price and info.price > 0 then
        maxAffordable = math.floor(GetMoney() / info.price)
    else
        maxAffordable = 99
    end
    -- Also cap by item-token extended costs (mirrors Blizzard's own affordability
    -- check in MerchantItemButton_OnModifiedClick).  Named currencies are
    -- server-side only and cannot be checked client-side, so those are skipped.
    if info.hasExtendedCost then
        local numCostItems = GetMerchantItemCostInfo(index) or 0
        for i = 1, numCostItems do
            local _, value, itemLink, currencyName = GetMerchantItemCostItem(index, i)
            if itemLink and not currencyName and value and value > 0 then
                local myCount = C_Item.GetItemCount(itemLink, false, false, true) or 0
                maxAffordable = math.min(maxAffordable, math.floor(myCount / value))
            end
        end
    end
    local maxPurchasable = maxAffordable
    if info.numAvailable and info.numAvailable >= 0 then
        maxPurchasable = math.min(maxAffordable, info.numAvailable)
    end
    if maxPurchasable < 1 then return end
    -- Cap to 100 items (100 × 0.1 s unthrottled = 9.9 s; throttled completes on server ACK).
    maxPurchasable = math.min(maxPurchasable, 100)

    -- BuyMerchantItem(id, quantity) fails for housing items (routes to housing
    -- storage, not bags — C layer rejects explicit quantity > 1 with "Internal Bag Error").
    -- Override SplitStack so the OK button starts a managed buy session instead.
    if not self._nomtoolsOrigSplitStack then
        self._nomtoolsOrigSplitStack = self.SplitStack
    end
    self.SplitStack = function(btn, split)
        btn.SplitStack = btn._nomtoolsOrigSplitStack
        local count    = math.max(1, split or 1)
        local settings = GetSettings()
        local throttle = not (settings and settings.vendorThrottle == false)
        local itemInfo = C_MerchantFrame.GetItemInfo(btn:GetID())
        StartMultiBuySession(btn:GetID(), count, throttle, itemInfo and itemInfo.name)
    end

    multiBuyCostInfo = CollectItemCostInfo(index)
    StackSplitFrame:OpenStackSplitFrame(maxPurchasable, self, "BOTTOMLEFT", "TOPLEFT", 1)
end

local function InstallMerchantHook()
    if merchantFrameHooked then return end
    if not MerchantItemButton_OnModifiedClick then return end
    merchantFrameHooked = true
    hooksecurefunc("MerchantItemButton_OnModifiedClick", OnMerchantItemButtonModifiedClick)

    -- Auto-confirm Blizzard purchase confirmation dialogs.
    -- Case 1: always fires during an active multi-buy session (no item check needed,
    --         all items in a session are already validated as housing decor).
    -- Case 2: fires when the standalone autoConfirmDecorPurchase setting is enabled,
    --         but only for decor items (verified via C_Item.IsDecorItem).
    -- The item link is read from the popup's ItemFrame first; if not set (e.g. the
    -- gold-cost confirmation dialog), it falls back to extracting it from the popup text.
    hooksecurefunc("StaticPopup_Show", function(which)
        if which ~= "CONFIRM_PURCHASE_TOKEN_ITEM"
            and which ~= "CONFIRM_HIGH_COST_ITEM"
            and which ~= "CONFIRM_PURCHASE_NONREFUNDABLE_ITEM" then
            return
        end
        local popupFrame = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
        if not popupFrame then return end

        -- Case 1: active multi-buy session — confirm immediately without item check.
        if multiBuySession then
            C_Timer.After(0, function()
                popupFrame:GetButton1():Click()
            end)
            return
        end

        -- Case 2: standalone setting.
        local s = GetSettings()
        if not (s and s.autoConfirmDecorPurchase) then return end
        if not (C_Item and C_Item.IsDecorItem) then return end
        local itemLink = popupFrame.ItemFrame and popupFrame.ItemFrame.link
        if not itemLink then
            local textFrame = popupFrame.Text
            if textFrame and textFrame.GetText then
                local txt = textFrame:GetText()
                if txt then itemLink = txt:match("|c.+|h|r") end
            end
        end
        if not itemLink then return end
        if not C_Item.IsDecorItem(itemLink) then return end
        C_Timer.After(0, function()
            popupFrame:GetButton1():Click()
        end)
    end)

    -- Cost frame: parented to StackSplitFrame so it moves and hides with it automatically.
    -- Anchored with its bottom-left at the top-left of StackSplitFrame, extending upward.
    if StackSplitFrame then
        local maxRows = 1 + (MAX_ITEM_COST or 5)
        local f = CreateFrame("Frame", "NomToolsMultiBuyCostFrame", StackSplitFrame, "BackdropTemplate")
        f:SetSize(COST_FRAME_W, COST_ROW_H + COST_PAD_V)
        f:SetPoint("BOTTOMLEFT", StackSplitFrame, "TOPLEFT", 0, 0)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile     = true, tileSize = 16, edgeSize = 12,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:Hide()

        f.rows = {}
        for i = 1, maxRows do
            local row = CreateFrame("Button", nil, f)
            row:SetHeight(COST_ROW_H)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", row, "LEFT", 0, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon = icon

            local amtFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            amtFs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            row.amtFs = amtFs

            local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameFs:SetPoint("LEFT", amtFs, "RIGHT", 6, 0)
            nameFs:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            nameFs:SetJustifyH("LEFT")
            row.nameFs = nameFs

            row._itemLink     = nil
            row._currencyName = nil

            row:SetScript("OnEnter", function(self)
                if self._itemLink then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(self._itemLink)
                    GameTooltip:Show()
                elseif self._currencyName then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(self._currencyName, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)
            row:Hide()

            f.rows[i] = row
        end

        multiBuyCostFrame = f

        -- Update cost whenever the spinner value changes.
        hooksecurefunc(StackSplitFrame, "UpdateStackText", function()
            if multiBuyCostInfo then
                UpdateCostDisplay(StackSplitFrame.split)
            end
        end)

        -- Show cost on initial open (UpdateStackText is not called by OpenStackSplitFrame).
        hooksecurefunc(StackSplitFrame, "OpenStackSplitFrame", function()
            if multiBuyCostInfo then
                UpdateCostDisplay(StackSplitFrame.split)
            end
        end)

        -- Clear when StackSplitFrame closes (covers Cancel, Escape, and OK).
        -- multiBuyCostFrame auto-hides as a child of StackSplitFrame.
        StackSplitFrame:HookScript("OnHide", function()
            multiBuyCostInfo = nil
        end)
    end
end

-- ============================================================
-- Post-hook for StoragePanel:UpdateCatalogData()
--
-- 1. Runs the deferred acquisition detection on home arrival.
-- 2. Applies the NomTools custom sort when DateAdded is selected.
-- ============================================================
local function OnUpdateCatalogData(self)
    local s = GetSettings()
    if not s or not IsHousingModuleActive() then return end
    if self.customCatalogData then return end
    if not self.catalogSearcher then return end

    -- Skip if we're on the market tab.
    if self.IsInMarketTab and self:IsInMarketTab() then return end

    -- ---- Acquisition detection (runs every refresh while at home) ----
    if isAtOwnHome then
        DetectAcquisitions()
    end

    MarkNewMarkersSeen()

    -- ---- Custom sort (overrides DateAdded) ----
    if not s.customSort then return end

    local sortType = self.catalogSearcher:GetSortType()
    if sortType ~= Enum.HousingCatalogSortType.DateAdded then return end

    local timestamps = GetSortTimestamps()
    if not next(timestamps) then return end   -- no data yet, preserve C-side order

    local raw = self.catalogSearcher:GetCatalogSearchResults()
    if not raw or #raw == 0 then return end

    -- Split: items WITH a NomTools timestamp sort newest-first;
    -- items WITHOUT keep their C-side relative order.
    local known, unknown = housingSortKnownScratch, housingSortUnknownScratch
    for k in pairs(known) do known[k] = nil end
    for k in pairs(unknown) do unknown[k] = nil end
    for _, e in ipairs(raw) do
        if e.recordID and timestamps[e.recordID] then
            known[#known + 1] = e
        else
            unknown[#unknown + 1] = e
        end
    end

    housingSortTimestamps = timestamps
    table.sort(known, HousingSortComparator)

    local entries = housingSortEntriesScratch
    for k in pairs(entries) do entries[k] = nil end
    for _, e in ipairs(known)   do entries[#entries + 1] = e end
    for _, e in ipairs(unknown) do entries[#entries + 1] = e end

    self.OptionsContainer:SetCatalogData(entries, true)
end

-- ============================================================
-- Home detection
-- ============================================================
local function OnArrivedAtOwnHome()
    if isAtOwnHome then return end
    isAtOwnHome = true
    detectionBaseline = nil   -- force re-init from lastHomeSnapshot on next detect
end

local function OnLeftHome()
    if isAtOwnHome then
        SaveLastHomeSnapshot()
    end

    local shouldClearMarkers = HasNewMarkers() and HaveNewMarkersBeenSeen()

    isAtOwnHome = false
    detectionBaseline = nil
    for k in pairs(entryQuantityCache) do entryQuantityCache[k] = nil end

    -- Clear "New" markers only after they existed, were seen in editor mode,
    -- and the player actually left their housing plot.
    if shouldClearMarkers then
        ClearNewMarkers()
    end
end

local function RunPlotExitCheck()
    plotExitCheckPending = false
    if not IsInsideOwnHousing() then
        OnLeftHome()
    end
end

local function SchedulePlotExitCheck()
    if plotExitCheckPending then return end
    plotExitCheckPending = true

    if not (C_Timer and C_Timer.After) then
        plotExitCheckPending = false
        if not IsInsideOwnHousing() then
            OnLeftHome()
        end
        return
    end

    C_Timer.After(0, RunPlotExitCheck)
end

-- ============================================================
-- Hook registration (deferred until Blizzard_HouseEditor loads)
-- ============================================================
local function RegisterHooks()
    if hooksRegistered then return end
    local sp = HouseEditorFrame and HouseEditorFrame.StoragePanel
    if not sp then return end
    hooksecurefunc(sp, "UpdateCatalogData", OnUpdateCatalogData)
    hooksRegistered = true
end

-- ============================================================
-- Event listener
-- ============================================================
local housingFrame = CreateFrame("Frame")
housingFrame:RegisterEvent("ADDON_LOADED")
housingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
housingFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")

local function OnHouseEditorAddonLoaded(self)
    if not IsHousingModuleActive() then
        return
    end

    RegisterHooks()
    InstallEntryHook()
    self:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
    RequestOwnedHouseCacheRefresh()
    if IsInsideOwnHousing() then
        OnArrivedAtOwnHome()
    end
end

local function OnHousingEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Blizzard_HouseEditor" then
            OnHouseEditorAddonLoaded(self)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        local _, isReloadingUi = ...
        plotExitCheckPending = false
        detectionBaseline = nil
        for k in pairs(entryQuantityCache) do entryQuantityCache[k] = nil end
        RequestOwnedHouseCacheRefresh()
        if IsInsideOwnHousing() then
            OnArrivedAtOwnHome()
        else
            if not isReloadingUi and isAtOwnHome then
                OnLeftHome()
            else
                isAtOwnHome = false
            end
        end

    elseif event == "PLAYER_HOUSE_LIST_UPDATED" then
        local houseList = ...
        UpdateOwnedHouseCache(houseList)

    elseif event == "HOUSE_PLOT_ENTERED" then
        if IsInsideOwnHousing() then
            OnArrivedAtOwnHome()
        end

    elseif event == "HOUSE_EDITOR_MODE_CHANGED" then
        local mode = ...
        local noneMode = Enum.HouseEditorMode and Enum.HouseEditorMode.None
        if mode ~= nil and (noneMode == nil or mode ~= noneMode) then
            local wasAtHome = isAtOwnHome
            OnArrivedAtOwnHome()
            if not wasAtHome and isAtOwnHome then
                local sp = HouseEditorFrame and HouseEditorFrame.StoragePanel
                if sp and sp:IsShown() and hooksRegistered then
                    OnUpdateCatalogData(sp)
                end
            end
        end

    elseif event == "HOUSE_PLOT_EXITED" then
        SchedulePlotExitCheck()

    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Save snapshot so quantities persist across reloads, but do NOT
        -- clear "New" markers — the player may just be reloading UI while
        -- still in their neighborhood.  Markers only clear on HOUSE_PLOT_EXITED.
        if isAtOwnHome then
            SaveLastHomeSnapshot()
        end
        detectionBaseline = nil
        for k in pairs(entryQuantityCache) do entryQuantityCache[k] = nil end

    elseif event == "HOUSING_STORAGE_ENTRY_UPDATED" then
        local entryID = ...
        if isAtOwnHome then
            OnStorageEntryUpdatedWhileHome(entryID)
        end
    end
end

local function UpdateHousingEventRegistration(shouldRegister)
    if shouldRegister then
        housingFrame:RegisterEvent("ADDON_LOADED")
        housingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        housingFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
        housingFrame:RegisterEvent("HOUSE_PLOT_ENTERED")
        housingFrame:RegisterEvent("HOUSE_EDITOR_MODE_CHANGED")
        housingFrame:RegisterEvent("HOUSE_PLOT_EXITED")
        housingFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
        InstallMerchantHook()
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_HouseEditor") then
            OnHouseEditorAddonLoaded(housingFrame)
        end
        housingFrame:SetScript("OnEvent", OnHousingEvent)
        return
    end

    housingFrame:UnregisterEvent("ADDON_LOADED")
    housingFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    housingFrame:UnregisterEvent("PLAYER_HOUSE_LIST_UPDATED")
    housingFrame:UnregisterEvent("HOUSE_PLOT_ENTERED")
    housingFrame:UnregisterEvent("HOUSE_EDITOR_MODE_CHANGED")
    housingFrame:UnregisterEvent("HOUSE_PLOT_EXITED")
    housingFrame:UnregisterEvent("PLAYER_LEAVING_WORLD")
    housingFrame:UnregisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
    housingFrame:SetScript("OnEvent", nil)
    plotExitCheckPending = false
    detectionBaseline = nil
    isAtOwnHome = false
    for k in pairs(entryQuantityCache) do entryQuantityCache[k] = nil end
end

function ns.InitializeHousingModule()
    UpdateHousingEventRegistration(IsHousingModuleActive())
end

function ns.RefreshHousingModule()
    UpdateHousingEventRegistration(IsHousingModuleActive())
end

function ns.ShowMultiBuyProgressPreview(itemName, bought, total)
    UpdateMultiBuyProgress(itemName or "Rustic Armchair", bought, total)
end

function ns.HideMultiBuyProgressPreview()
    HideMultiBuyProgress()
end
