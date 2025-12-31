--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    STARCHASE GPS PURSUIT SYSTEM                    ║
    ║                         CONFIGURATION                              ║
    ╚═══════════════════════════════════════════════════════════════════╝
]]

Config = {}

---------------------------------------------------------------
--                    PERMISSION SETTINGS                     --
---------------------------------------------------------------

-- Discord permission group for LEO access (ACE permission name)
-- This matches the group.leo from DiscordAcePerms
Config.LEOPermission = "group.leo"

-- Discord Role ID for LEO (from your Discord server)
-- This is used as a fallback to check Discord roles directly via Badger_Discord_API
-- Get this from Discord: Right-click role > Copy ID (Enable Developer Mode in Discord settings)
Config.LEODiscordRole = "1223050790260965478"  -- Your LEO role ID

-- Additional admin permission (can also use the system)
Config.AdminPermission = "group.admin"

-- Discord Role ID for Admin
Config.AdminDiscordRole = "1223050790344593509"  -- Your Admin role ID

-- Allow admins to tag any vehicle (even without being in pursuit)
Config.AdminBypass = true

---------------------------------------------------------------
--                      DART SETTINGS                         --
---------------------------------------------------------------

-- Key to fire the GPS dart (Default: G key)
-- https://docs.fivem.net/docs/game-references/controls/
Config.FireKey = 47  -- G

-- Maximum range to fire dart (in meters)
Config.MaxDartRange = 25.0

-- Cooldown between dart fires (in seconds)
Config.DartCooldown = 5

-- Must be in a police vehicle to use (class 18 = Emergency)
Config.RequirePoliceVehicle = true

-- Allowed vehicle classes (18 = Emergency vehicles)
Config.AllowedVehicleClasses = {18}

-- Sound when firing dart
Config.DartSound = true
Config.DartSoundName = "WEAPON_PURCHASE"
Config.DartSoundSet = "HUD_AMMO_SHOP_SOUNDSET"

---------------------------------------------------------------
--                      BLIP SETTINGS                         --
---------------------------------------------------------------

-- Blip sprite for tracked vehicle
-- Full list: https://docs.fivem.net/docs/game-references/blips/
Config.BlipSprite = 225  -- Target/crosshair icon

-- Blip color (red for suspect)
-- Full list: https://docs.fivem.net/docs/game-references/blips/#blip-colors
Config.BlipColor = 1  -- Red

-- Blip scale
Config.BlipScale = 1.0

-- Blip flashes on minimap
Config.BlipFlash = true

-- Blip name shown on map
Config.BlipName = "🎯 GPS Tracked Vehicle"

-- How long the GPS tracker lasts (in minutes)
Config.TrackerDuration = 15

-- Update blip position interval (in milliseconds)
Config.BlipUpdateInterval = 500

-- Show route to blip
Config.ShowRoute = true
Config.RouteColor = 1  -- Red route

---------------------------------------------------------------
--                  NOTIFICATION SETTINGS                     --
---------------------------------------------------------------

-- Notification duration (in milliseconds)
Config.NotificationDuration = 5000

-- Notification position (top-right, top-left, bottom-right, bottom-left)
Config.NotificationPosition = "top-right"

-- Enable notification sounds
Config.NotificationSound = true

---------------------------------------------------------------
--                    VISUAL SETTINGS                         --
---------------------------------------------------------------

-- Show particle effect on dart hit
Config.ShowHitEffect = true

-- Dart projectile color (RGB)
Config.DartColor = {r = 0, g = 150, b = 255}  -- Blue

-- Draw marker on tagged vehicle
Config.DrawMarkerOnTarget = true
Config.MarkerColor = {r = 255, g = 0, b = 0, a = 150}  -- Red transparent

---------------------------------------------------------------
--                     COMMAND SETTINGS                       --
---------------------------------------------------------------

-- Command to fire dart (alternative to key)
Config.DartCommand = "starchase"

-- Command to view active tracks (LEO only)
Config.ViewTracksCommand = "tracks"

-- Command to remove a track (by plate)
Config.RemoveTrackCommand = "untrack"

---------------------------------------------------------------
--                      DEBUG SETTINGS                        --
---------------------------------------------------------------

-- Enable debug mode (shows extra console info)
Config.Debug = false

---------------------------------------------------------------
--                   NOTIFICATION MESSAGES                    --
---------------------------------------------------------------

Config.Messages = {
    -- Success messages
    DartFired = "GPS Dart Deployed",
    DartHit = "Target Acquired",
    TrackingActive = "Now tracking vehicle",
    TrackingExpired = "GPS tracker expired",
    TrackRemoved = "GPS tracker removed",
    
    -- Error messages
    NotLEO = "You must be Law Enforcement to use this",
    NotInVehicle = "You must be in a vehicle",
    NotPoliceVehicle = "You must be in a police vehicle",
    NotDriver = "You must be the driver",
    NoCooldown = "GPS dart on cooldown",
    NoTarget = "No valid target in range",
    AlreadyTracked = "Vehicle is already being tracked",
    NoTracks = "No active GPS tracks",
    
    -- Info messages
    CooldownRemaining = "Cooldown: %s seconds",
    TrackingTime = "Time remaining: %s minutes",
    VehiclePlate = "Plate: %s",
}

