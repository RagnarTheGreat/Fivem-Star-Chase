--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    STARCHASE GPS PURSUIT SYSTEM                    ║
    ║                         by Rising RP                               ║
    ║                                                                    ║
    ║  GPS Dart Tracking System for Law Enforcement                      ║
    ║  - Fire GPS darts at fleeing vehicles                              ║
    ║  - Track tagged vehicles on the map                                ║
    ║  - LEO Only - Discord Permission Based                             ║
    ╚═══════════════════════════════════════════════════════════════════╝
]]

fx_version 'cerulean'
game 'gta5'

name 'starchase'
author 'Rising RP'
description 'GPS Pursuit Dart System - LEO Only'
version '1.0.1'

lua54 'yes'

-- Dependencies - ensure these load before starchase
dependencies {
    'Badger_Discord_API',
    'DiscordAcePerms'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

