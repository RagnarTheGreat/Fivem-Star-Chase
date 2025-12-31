--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    STARCHASE GPS PURSUIT SYSTEM                    ║
    ║                          SERVER SIDE                               ║
    ╚═══════════════════════════════════════════════════════════════════╝
]]

-- Active GPS tracks storage
local activeTrackers = {}

---------------------------------------------------------------
--                  PERMISSION CHECKING                       --
---------------------------------------------------------------

-- Check if player has LEO permission (Discord role based)
function IsPlayerLEO(source)
    return IsPlayerAceAllowed(source, Config.LEOPermission)
end

-- Check if player has Admin permission
function IsPlayerAdmin(source)
    return IsPlayerAceAllowed(source, Config.AdminPermission)
end

-- Permission request handler
RegisterNetEvent('starchase:requestPermissions')
AddEventHandler('starchase:requestPermissions', function()
    local source = source
    local isLEO = IsPlayerLEO(source)
    local isAdmin = IsPlayerAdmin(source)
    
    TriggerClientEvent('starchase:permissionResult', source, isLEO, isAdmin)
    
    if Config.Debug then
        print('[StarChase] Permission check for ' .. GetPlayerName(source) .. ' - LEO: ' .. tostring(isLEO) .. ', Admin: ' .. tostring(isAdmin))
    end
end)

---------------------------------------------------------------
--                    DART HIT HANDLING                       --
---------------------------------------------------------------

RegisterNetEvent('starchase:dartHit')
AddEventHandler('starchase:dartHit', function(netId, plate)
    local source = source
    
    -- Verify player has permission
    if not IsPlayerLEO(source) and not (Config.AdminBypass and IsPlayerAdmin(source)) then
        if Config.Debug then
            print('[StarChase] Unauthorized dart attempt from: ' .. GetPlayerName(source))
        end
        return
    end
    
    -- Check if vehicle is already tracked
    if activeTrackers[plate] then
        TriggerClientEvent('starchase:alreadyTracked', source)
        return
    end
    
    -- Calculate expiration time
    local expireTime = GetGameTimer() + (Config.TrackerDuration * 60 * 1000)
    
    -- Store tracker info
    activeTrackers[plate] = {
        netId = netId,
        expireTime = expireTime,
        trackedBy = source,
        trackedByName = GetPlayerName(source),
        startTime = os.time()
    }
    
    -- Notify all LEO players
    for _, playerId in ipairs(GetPlayers()) do
        if IsPlayerLEO(playerId) or (Config.AdminBypass and IsPlayerAdmin(playerId)) then
            TriggerClientEvent('starchase:startTracking', playerId, netId, plate, expireTime)
        end
    end
    
    -- Log the tracking
    print('[StarChase] 🎯 Vehicle ' .. plate .. ' tagged by ' .. GetPlayerName(source))
    
    -- Start expiration timer
    StartExpirationTimer(plate)
end)

---------------------------------------------------------------
--                  EXPIRATION HANDLING                       --
---------------------------------------------------------------

function StartExpirationTimer(plate)
    Citizen.CreateThread(function()
        Wait(Config.TrackerDuration * 60 * 1000)
        
        if activeTrackers[plate] then
            -- Remove the tracker
            activeTrackers[plate] = nil
            
            -- Notify all LEO players
            for _, playerId in ipairs(GetPlayers()) do
                if IsPlayerLEO(playerId) or (Config.AdminBypass and IsPlayerAdmin(playerId)) then
                    TriggerClientEvent('starchase:stopTracking', playerId, plate, 'expired')
                end
            end
            
            print('[StarChase] ⏱️ GPS tracker on ' .. plate .. ' has expired')
        end
    end)
end

---------------------------------------------------------------
--                  TRACK REMOVAL                             --
---------------------------------------------------------------

RegisterNetEvent('starchase:requestRemoveTrack')
AddEventHandler('starchase:requestRemoveTrack', function(plate)
    local source = source
    
    -- Verify player has permission
    if not IsPlayerLEO(source) and not (Config.AdminBypass and IsPlayerAdmin(source)) then
        return
    end
    
    plate = string.upper(plate)
    
    if activeTrackers[plate] then
        -- Remove the tracker
        activeTrackers[plate] = nil
        
        -- Notify all LEO players
        for _, playerId in ipairs(GetPlayers()) do
            if IsPlayerLEO(playerId) or (Config.AdminBypass and IsPlayerAdmin(playerId)) then
                TriggerClientEvent('starchase:stopTracking', playerId, plate, 'removed')
            end
        end
        
        print('[StarChase] 🔴 GPS tracker on ' .. plate .. ' removed by ' .. GetPlayerName(source))
    end
end)

---------------------------------------------------------------
--              NEW PLAYER SYNC                               --
---------------------------------------------------------------

-- When a new player joins, send them all active tracks
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    -- Handled in separate event
end)

-- Sync active tracks to newly joined LEO players
RegisterNetEvent('starchase:requestActiveTrackers')
AddEventHandler('starchase:requestActiveTrackers', function()
    local source = source
    
    if not IsPlayerLEO(source) and not (Config.AdminBypass and IsPlayerAdmin(source)) then
        return
    end
    
    -- Send all active trackers to the player
    for plate, data in pairs(activeTrackers) do
        TriggerClientEvent('starchase:startTracking', source, data.netId, plate, data.expireTime)
    end
end)

-- Also trigger sync when permissions are requested
RegisterNetEvent('starchase:requestPermissions')
AddEventHandler('starchase:requestPermissions', function()
    local source = source
    
    -- Delayed sync to ensure permissions are processed first
    Citizen.SetTimeout(1000, function()
        if IsPlayerLEO(source) or (Config.AdminBypass and IsPlayerAdmin(source)) then
            for plate, data in pairs(activeTrackers) do
                TriggerClientEvent('starchase:startTracking', source, data.netId, plate, data.expireTime)
            end
        end
    end)
end)

---------------------------------------------------------------
--                    ADMIN COMMANDS                          --
---------------------------------------------------------------

-- Clear all tracks (admin only)
RegisterCommand('clearalltracks', function(source, args, rawCommand)
    if source == 0 or IsPlayerAdmin(source) then
        local count = 0
        
        for plate, _ in pairs(activeTrackers) do
            count = count + 1
            
            -- Notify all LEO players
            for _, playerId in ipairs(GetPlayers()) do
                if IsPlayerLEO(playerId) or (Config.AdminBypass and IsPlayerAdmin(playerId)) then
                    TriggerClientEvent('starchase:stopTracking', playerId, plate, 'admin_cleared')
                end
            end
        end
        
        activeTrackers = {}
        
        print('[StarChase] 🧹 All ' .. count .. ' GPS trackers cleared by ' .. (source == 0 and 'Console' or GetPlayerName(source)))
        
        if source ~= 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 100, 100},
                args = {'StarChase', 'Cleared ' .. count .. ' active GPS trackers'}
            })
        end
    end
end, true)

-- List all active tracks (admin only)
RegisterCommand('listtracks', function(source, args, rawCommand)
    if source == 0 or IsPlayerAdmin(source) or IsPlayerLEO(source) then
        local count = 0
        
        print('[StarChase] ════════════════════════════════')
        print('[StarChase] Active GPS Trackers:')
        
        for plate, data in pairs(activeTrackers) do
            count = count + 1
            local timeLeft = math.ceil((data.expireTime - GetGameTimer()) / 60000)
            print('[StarChase] • ' .. plate .. ' - Tagged by: ' .. data.trackedByName .. ' - Time left: ' .. timeLeft .. ' min')
        end
        
        if count == 0 then
            print('[StarChase] No active trackers')
        end
        
        print('[StarChase] ════════════════════════════════')
        print('[StarChase] Total active trackers: ' .. count)
        
        if source ~= 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {100, 200, 255},
                args = {'StarChase', 'There are ' .. count .. ' active GPS trackers. Check server console for details.'}
            })
        end
    end
end, false)

---------------------------------------------------------------
--                    UTILITY FUNCTIONS                       --
---------------------------------------------------------------

-- Get all connected players
function GetPlayers()
    local players = {}
    
    for i = 0, GetNumPlayerIndices() - 1 do
        local player = GetPlayerFromIndex(i)
        if player then
            table.insert(players, player)
        end
    end
    
    return players
end

---------------------------------------------------------------
--                    STARTUP MESSAGE                         --
---------------------------------------------------------------

Citizen.CreateThread(function()
    print('')
    print('^2╔═══════════════════════════════════════════════════════════════════╗')
    print('^2║                    STARCHASE GPS PURSUIT SYSTEM                    ^2║')
    print('^2║                          ^3Server Loaded^2                            ^2║')
    print('^2╠═══════════════════════════════════════════════════════════════════╣')
    print('^2║  ^7Commands:^2                                                        ^2║')
    print('^2║  ^3/starchase^2     - Fire GPS dart                                   ^2║')
    print('^2║  ^3/tracks^2        - View active GPS tracks                          ^2║')
    print('^2║  ^3/untrack^2 [plate] - Remove GPS tracker                            ^2║')
    print('^2║  ^3/listtracks^2    - List all tracks (admin)                         ^2║')
    print('^2║  ^3/clearalltracks^2- Clear all tracks (admin)                        ^2║')
    print('^2╠═══════════════════════════════════════════════════════════════════╣')
    print('^2║  ^7Keybind: ^3G^7 - Fire GPS Dart (in police vehicle)                   ^2║')
    print('^2╚═══════════════════════════════════════════════════════════════════╝^0')
    print('')
end)

