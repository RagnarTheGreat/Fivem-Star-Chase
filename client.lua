--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    STARCHASE GPS PURSUIT SYSTEM                    ║
    ║                          CLIENT SIDE                               ║
    ╚═══════════════════════════════════════════════════════════════════╝
]]

-- Local variables
local isLEO = false
local isAdmin = false
local dartCooldown = 0
local trackedVehicles = {}
local trackedBlips = {}
local trackingThreadActive = false

---------------------------------------------------------------
--                    PERMISSION HANDLING                     --
---------------------------------------------------------------

-- Check permissions on resource start
Citizen.CreateThread(function()
    Wait(3000) -- Wait for other resources to load (Discord API needs time)
    TriggerServerEvent('starchase:requestPermissions')
    
    -- Re-check permissions periodically (every 30 seconds)
    while true do
        Wait(30000)
        TriggerServerEvent('starchase:requestPermissions')
    end
end)

-- Receive permission status from server
RegisterNetEvent('starchase:permissionResult')
AddEventHandler('starchase:permissionResult', function(leo, admin)
    isLEO = leo
    isAdmin = admin
end)

-- Manual permission refresh command
RegisterCommand('refreshstarchase', function()
    TriggerServerEvent('starchase:requestPermissions')
end, false)

---------------------------------------------------------------
--                    NOTIFICATION SYSTEM                     --
---------------------------------------------------------------

function SendNotification(type, title, message, duration)
    SendNUIMessage({
        action = 'showNotification',
        type = type,
        title = title,
        message = message,
        duration = duration or Config.NotificationDuration
    })
    
    if Config.NotificationSound then
        PlaySoundFrontend(-1, "WEAPON_PURCHASE", "HUD_AMMO_SHOP_SOUNDSET", false)
    end
end

---------------------------------------------------------------
--                      KEY BINDINGS                          --
---------------------------------------------------------------

-- Main dart firing thread
Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        -- Check if player has LEO permission
        if not isLEO and not (Config.AdminBypass and isAdmin) then
            Wait(1000)
        else
            -- Check if fire key is pressed
            if IsControlJustPressed(0, Config.FireKey) then
                AttemptFireDart()
            end
        end
    end
end)

-- Cooldown handler
Citizen.CreateThread(function()
    while true do
        Wait(1000)
        if dartCooldown > 0 then
            dartCooldown = dartCooldown - 1
        end
    end
end)

---------------------------------------------------------------
--                    DART FIRING LOGIC                       --
---------------------------------------------------------------

function AttemptFireDart()
    local ped = PlayerPedId()
    
    -- Check if player is LEO
    if not isLEO and not (Config.AdminBypass and isAdmin) then
        SendNotification('error', '⛔ ACCESS DENIED', Config.Messages.NotLEO)
        return
    end
    
    -- Check if in vehicle
    if not IsPedInAnyVehicle(ped, false) then
        SendNotification('error', '⚠️ ERROR', Config.Messages.NotInVehicle)
        return
    end
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    -- Check if driver
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        SendNotification('error', '⚠️ ERROR', Config.Messages.NotDriver)
        return
    end
    
    -- Check if police vehicle (if required)
    if Config.RequirePoliceVehicle then
        local vehicleClass = GetVehicleClass(vehicle)
        local isAllowed = false
        
        for _, class in ipairs(Config.AllowedVehicleClasses) do
            if vehicleClass == class then
                isAllowed = true
                break
            end
        end
        
        if not isAllowed then
            SendNotification('error', '⚠️ ERROR', Config.Messages.NotPoliceVehicle)
            return
        end
    end
    
    -- Check cooldown
    if dartCooldown > 0 then
        SendNotification('warning', '⏱️ COOLDOWN', string.format(Config.Messages.CooldownRemaining, dartCooldown))
        return
    end
    
    -- Find target vehicle
    local targetVehicle = GetTargetVehicle()
    
    if not targetVehicle or targetVehicle == 0 then
        SendNotification('error', '❌ NO TARGET', Config.Messages.NoTarget)
        return
    end
    
    -- Get vehicle plate
    local plate = string.gsub(GetVehicleNumberPlateText(targetVehicle), "^%s*(.-)%s*$", "%1")
    
    -- Check if already tracked
    if trackedVehicles[plate] then
        SendNotification('warning', '⚠️ WARNING', Config.Messages.AlreadyTracked)
        return
    end
    
    -- Fire the dart!
    FireDart(targetVehicle, plate)
end

function GetTargetVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local coords = GetEntityCoords(vehicle)
    local forwardVector = GetEntityForwardVector(vehicle)
    
    -- Calculate end point
    local endCoords = vector3(
        coords.x + forwardVector.x * Config.MaxDartRange,
        coords.y + forwardVector.y * Config.MaxDartRange,
        coords.z + forwardVector.z * Config.MaxDartRange
    )
    
    -- Raycast to find vehicle
    local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z, endCoords.x, endCoords.y, endCoords.z, 10, vehicle, 0)
    local _, hit, hitCoords, _, entityHit = GetShapeTestResult(rayHandle)
    
    if hit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
        return entityHit
    end
    
    -- Alternative: check vehicles in range
    local closestVehicle = nil
    local closestDistance = Config.MaxDartRange
    
    for veh in EnumerateVehicles() do
        if veh ~= vehicle then
            local vehCoords = GetEntityCoords(veh)
            local distance = #(coords - vehCoords)
            
            if distance < closestDistance then
                -- Check if vehicle is in front of us
                local dirToVeh = vehCoords - coords
                local dot = forwardVector.x * dirToVeh.x + forwardVector.y * dirToVeh.y
                
                if dot > 0 then  -- Vehicle is in front
                    closestDistance = distance
                    closestVehicle = veh
                end
            end
        end
    end
    
    return closestVehicle
end

function FireDart(targetVehicle, plate)
    -- Set cooldown
    dartCooldown = Config.DartCooldown
    
    -- Play sound
    if Config.DartSound then
        PlaySoundFrontend(-1, Config.DartSoundName, Config.DartSoundSet, false)
    end
    
    -- Show hit effect
    if Config.ShowHitEffect then
        local targetCoords = GetEntityCoords(targetVehicle)
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("ent_sht_electrical_box", targetCoords.x, targetCoords.y, targetCoords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
    
    -- Send success notification
    SendNotification('success', '🎯 ' .. Config.Messages.DartHit, Config.Messages.TrackingActive .. '\n' .. string.format(Config.Messages.VehiclePlate, plate))
    
    -- Notify server to sync with all LEO
    TriggerServerEvent('starchase:dartHit', NetworkGetNetworkIdFromEntity(targetVehicle), plate)
    
    if Config.Debug then
        print('[StarChase] Dart fired at vehicle: ' .. plate)
    end
end

---------------------------------------------------------------
--                    TRACKING SYSTEM                         --
---------------------------------------------------------------

-- Receive tracking updates from server
RegisterNetEvent('starchase:startTracking')
AddEventHandler('starchase:startTracking', function(netId, plate, expireTime)
    -- Only LEO can see tracks
    if not isLEO and not (Config.AdminBypass and isAdmin) then
        return
    end
    
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        -- Check if already tracking this vehicle
        local isNewTrack = not trackedVehicles[plate]
        
        -- Store tracked vehicle
        trackedVehicles[plate] = {
            netId = netId,
            expireTime = expireTime,
            vehicle = vehicle
        }
        
        -- Create or update blip
        CreateTrackingBlip(plate, vehicle)
        
        -- Start tracking thread if not already running
        if not trackingThreadActive then
            StartTrackingThread()
        end
        
        -- Only send notification for new tracks
        if isNewTrack then
            SendNotification('info', '📡 NEW GPS TRACK', 'Vehicle ' .. plate .. ' is now being tracked\n' .. string.format(Config.Messages.TrackingTime, Config.TrackerDuration))
        end
    end
end)

-- Handle track removal
RegisterNetEvent('starchase:stopTracking')
AddEventHandler('starchase:stopTracking', function(plate, reason)
    if trackedVehicles[plate] then
        RemoveTrackingBlip(plate)
        trackedVehicles[plate] = nil
        
        if reason == 'expired' then
            SendNotification('warning', '⏱️ TRACK EXPIRED', 'GPS tracker on ' .. plate .. ' has expired')
        else
            SendNotification('info', '🔴 TRACK REMOVED', 'GPS tracker on ' .. plate .. ' removed')
        end
    end
end)

function CreateTrackingBlip(plate, vehicle)
    -- Remove existing blip if any
    if trackedBlips[plate] then
        RemoveBlip(trackedBlips[plate])
    end
    
    -- Use AddBlipForEntity instead of AddBlipForCoord so it automatically follows the vehicle
    local blip = AddBlipForEntity(vehicle)
    
    -- Configure blip appearance
    SetBlipSprite(blip, Config.BlipSprite)
    SetBlipColour(blip, Config.BlipColor)
    SetBlipScale(blip, Config.BlipScale)
    SetBlipAsShortRange(blip, false)
    
    -- Set blip name
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.BlipName .. " [" .. plate .. "]")
    EndTextCommandSetBlipName(blip)
    
    -- Flash effect
    if Config.BlipFlash then
        SetBlipFlashes(blip, true)
        SetBlipFlashInterval(blip, 500)
    end
    
    -- Show route
    if Config.ShowRoute then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, Config.RouteColor)
    end
    
    trackedBlips[plate] = blip
    
    if Config.Debug then
        print('[StarChase] Created blip for: ' .. plate)
    end
end

function RemoveTrackingBlip(plate)
    if trackedBlips[plate] then
        RemoveBlip(trackedBlips[plate])
        trackedBlips[plate] = nil
        
        if Config.Debug then
            print('[StarChase] Removed blip for: ' .. plate)
        end
    end
end

function StartTrackingThread()
    trackingThreadActive = true
    
    Citizen.CreateThread(function()
        while trackingThreadActive do
            local hasActiveTracking = false
            
            for plate, data in pairs(trackedVehicles) do
                hasActiveTracking = true
                
                local vehicle = NetworkGetEntityFromNetworkId(data.netId)
                
                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    local coords = GetEntityCoords(vehicle)
                    
                    -- Check if blip exists, recreate if lost (AddBlipForEntity automatically follows, no need to update coordinates)
                    if not trackedBlips[plate] or not DoesBlipExist(trackedBlips[plate]) then
                        -- Recreate blip if it was lost
                        CreateTrackingBlip(plate, vehicle)
                    end
                    
                    -- Draw 3D marker on target vehicle
                    if Config.DrawMarkerOnTarget then
                        local playerCoords = GetEntityCoords(PlayerPedId())
                        local distance = #(playerCoords - coords)
                        
                        if distance < 100.0 then  -- Only draw if within 100m
                            DrawMarker(
                                2,  -- Down arrow
                                coords.x, coords.y, coords.z + 2.5,
                                0.0, 0.0, 0.0,
                                0.0, 180.0, 0.0,
                                0.5, 0.5, 0.5,
                                Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a,
                                true, false, 2, false, nil, nil, false
                            )
                        end
                    end
                end
            end
            
            -- Stop thread if no active tracking
            if not hasActiveTracking then
                trackingThreadActive = false
                break
            end
            
            Wait(Config.BlipUpdateInterval)
        end
    end)
end

---------------------------------------------------------------
--                      COMMANDS                              --
---------------------------------------------------------------

-- Fire dart command
RegisterCommand(Config.DartCommand, function()
    AttemptFireDart()
end, false)

-- View tracks command
RegisterCommand(Config.ViewTracksCommand, function()
    if not isLEO and not (Config.AdminBypass and isAdmin) then
        SendNotification('error', '⛔ ACCESS DENIED', Config.Messages.NotLEO)
        return
    end
    
    local count = 0
    local trackList = ""
    
    for plate, data in pairs(trackedVehicles) do
        count = count + 1
        local timeLeft = math.ceil((data.expireTime - GetGameTimer()) / 60000)
        trackList = trackList .. "\n• " .. plate .. " (" .. timeLeft .. " min)"
    end
    
    if count == 0 then
        SendNotification('info', '📡 GPS TRACKS', Config.Messages.NoTracks)
    else
        SendNotification('info', '📡 ACTIVE GPS TRACKS (' .. count .. ')', trackList)
    end
end, false)

-- Remove track command
RegisterCommand(Config.RemoveTrackCommand, function(source, args)
    if not isLEO and not (Config.AdminBypass and isAdmin) then
        SendNotification('error', '⛔ ACCESS DENIED', Config.Messages.NotLEO)
        return
    end
    
    if not args[1] then
        SendNotification('warning', '⚠️ USAGE', '/untrack [plate]')
        return
    end
    
    local plate = string.upper(args[1])
    TriggerServerEvent('starchase:requestRemoveTrack', plate)
end, false)

---------------------------------------------------------------
--                    VEHICLE ITERATOR                        --
---------------------------------------------------------------

function EnumerateVehicles()
    return coroutine.wrap(function()
        local handle, vehicle = FindFirstVehicle()
        local success
        
        repeat
            coroutine.yield(vehicle)
            success, vehicle = FindNextVehicle(handle)
        until not success
        
        EndFindVehicle(handle)
    end)
end

---------------------------------------------------------------
--                    HELP TEXT DISPLAY                       --
---------------------------------------------------------------

Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        if isLEO or (Config.AdminBypass and isAdmin) then
            local ped = PlayerPedId()
            
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                
                -- Check if driver and in police vehicle
                if GetPedInVehicleSeat(vehicle, -1) == ped then
                    local vehicleClass = GetVehicleClass(vehicle)
                    local isPoliceVehicle = false
                    
                    for _, class in ipairs(Config.AllowedVehicleClasses) do
                        if vehicleClass == class then
                            isPoliceVehicle = true
                            break
                        end
                    end
                    
                    if isPoliceVehicle or not Config.RequirePoliceVehicle then
                        -- Show help text when conditions are met
                        if dartCooldown == 0 then
                            -- Only show every few frames
                            if GetGameTimer() % 500 < 50 then
                                -- Subtle hint - don't show constant text
                            end
                        end
                    end
                end
            end
        else
            Wait(1000)  -- Check less frequently if not LEO
        end
    end
end)

---------------------------------------------------------------
--                    NUI CALLBACKS                           --
---------------------------------------------------------------

-- Hide notification callback
RegisterNUICallback('hideNotification', function(data, cb)
    cb('ok')
end)

