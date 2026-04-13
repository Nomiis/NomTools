local _, ns = ...

local function CanAutoSkipSeenCutscenes()
    local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
    if not miscSettings or miscSettings.enabled == false then
        return false
    end
    local automation = ns.GetAutomationSettings and ns.GetAutomationSettings() or nil
    return automation and automation.skipSeenCutscenes == true
end

local function BuildCinematicKey()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    if not mapID or mapID <= 0 then
        return nil
    end

    local _, instanceType, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()
    local subZone = GetSubZoneText() or ""
    local xBucket = 0
    local yBucket = 0

    if C_Map and C_Map.GetPlayerMapPosition then
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            xBucket = math.floor((position.x or 0) * 1000 + 0.5)
            yBucket = math.floor((position.y or 0) * 1000 + 0.5)
        end
    end

    return table.concat({
        tostring(mapID),
        tostring(instanceMapID or 0),
        tostring(difficultyID or 0),
        tostring(instanceType or "none"),
        subZone,
        tostring(xBucket),
        tostring(yBucket),
    }, ":")
end

local function TrySkipCurrentCinematic()
    if StopCinematic and CinematicFrame and CinematicFrame.isRealCinematic then
        StopCinematic()
        return true
    end

    if CanCancelScene and CanCancelScene() and CancelScene then
        CancelScene()
        return true
    end

    if CinematicFrame_CancelCinematic then
        CinematicFrame_CancelCinematic()
        return true
    end

    return false
end

function ns.HandlePlayMovie(movieID)
    if type(movieID) ~= "number" then
        return
    end

    local automation = ns.GetAutomationSettings()
    if automation.seenMovies[movieID] then
        if CanAutoSkipSeenCutscenes() then
            C_Timer.After(0, function()
                if MovieFrame and MovieFrame:IsShown() then
                    MovieFrame:Hide()
                end
            end)
        end
        return
    end

    automation.seenMovies[movieID] = true
end

function ns.HandleCinematicStart()
    local automation = ns.GetAutomationSettings()
    local cinematicKey = BuildCinematicKey()
    if not cinematicKey then
        return
    end

    if automation.seenCinematics[cinematicKey] then
        if CanAutoSkipSeenCutscenes() then
            C_Timer.After(0, TrySkipCurrentCinematic)
        end
        return
    end

    automation.seenCinematics[cinematicKey] = true
end