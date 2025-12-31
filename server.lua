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

-- Helper function to check if player has a specific Discord role
function HasDiscordRole(source, roleId)
    if not roleId or roleId == "" then
        return false
    end
    
    -- Get player's Discord roles using Badger Discord API
    local roles = exports.Badger_Discord_API:GetDiscordRoles(source)
    
    if roles and type(roles) == "table" then
        for _, role in ipairs(roles) do
            -- Compare as strings since role IDs are large numbers
            if tostring(role) == tostring(roleId) then
                return true
            end
        end
    end
    
    return false
end

-- Check if player has LEO permission (Discord role based)
function IsPlayerLEO(source)
    -- Method 1: Check ACE permission (if using add_ace in server.cfg)
    if IsPlayerAceAllowed(source, Config.LEOPermission) then
        return true
    end
    
    -- Method 2: Check Discord role directly via Badger Discord API
    if Config.LEODiscordRole and Config.LEODiscordRole ~= "" then
        if HasDiscordRole(source, Config.LEODiscordRole) then
            return true
        end
    end
    
    return false
end

-- Check if player has Admin permission
function IsPlayerAdmin(source)
    -- Check ACE permission
    if IsPlayerAceAllowed(source, Config.AdminPermission) then
        return true
    end
    
    -- Check Discord role directly
    if Config.AdminDiscordRole and Config.AdminDiscordRole ~= "" then
        if HasDiscordRole(source, Config.AdminDiscordRole) then
            return true
        end
    end
    
    return false
end

-- Permission request handler
RegisterNetEvent('starchase:requestPermissions')
AddEventHandler('starchase:requestPermissions', function()
    local source = source
    
    -- Small delay to ensure Discord API has loaded roles
    Citizen.Wait(500)
    
    local isLEO = IsPlayerLEO(source)
    local isAdmin = IsPlayerAdmin(source)
    
    TriggerClientEvent('starchase:permissionResult', source, isLEO, isAdmin)
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
    end
end, true)

-- List all active tracks (admin only) - use /tracks command in-game instead
RegisterCommand('listtracks', function(source, args, rawCommand)
    -- This command is for console use only now
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

-- StarChase GPS Pursuit System loaded silently

