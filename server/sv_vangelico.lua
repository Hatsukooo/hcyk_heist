local ESX = exports["es_extended"]:getSharedObject()

-- State management
local activeRobberies = {} -- Players currently robbing
local globalCooldown = { active = false, timer = Config.Vangelico.GlobalCooldown }

-- Utility functions
local function debugLog(message, ...)
    if Config.Debug then
        print("[DEBUG] [Vangelico] " .. string.format(message, ...))
    end
end

-- Discord logging system
local function logToDiscord(title, description, color, fields)
    if not Config.Discord.Enabled then return end
    
    local embed = {
        {
            ["title"] = '**[Vangelico]** ' .. title,
            ["description"] = description,
            ["type"] = "rich",
            ["color"] = color or Config.Discord.Colors.Info,
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            ["fields"] = fields or {},
            ["footer"] = {
                ["text"] = "Heist Logger",
            },
        }
    }

    PerformHttpRequest(Config.Discord.Webhook, function(err, text, headers) end, 'POST', 
        json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Security verification functions
local function verifyPlayerInRobbery(playerId)
    if not activeRobberies[playerId] then
        exports["rx_utils"]:fg_BanPlayer(playerId, "Unauthorized Vangelico heist event usage detected.", true)
        
        local xPlayer = ESX.GetPlayerFromId(playerId)
        local playerName = xPlayer and xPlayer.getName() or "Unknown"
        
        logToDiscord(
            "Cheat Attempt: Unauthorized Event Usage",
            "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Attempted to use a protected event without initiating heist.",
            Config.Discord.Colors.Error
        )
        return false
    end
    return true
end

local function verifyPlayerPosition(playerId, position, maxDistance)
    if #(GetEntityCoords(GetPlayerPed(playerId)) - vector3(position.x, position.y, position.z)) > maxDistance then
        exports["rx_utils"]:fg_BanPlayer(playerId, "Attempted to start heist from unauthorized location.", true)
        
        local xPlayer = ESX.GetPlayerFromId(playerId)
        local playerName = xPlayer and xPlayer.getName() or "Unknown"
        
        logToDiscord(
            "Cheat Attempt: Invalid Location",
            "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Attempted to start heist from unauthorized distance.",
            Config.Discord.Colors.Error
        )
        return false
    end
    return true
end

-- Core robbery functions
local function startHeistCooldown()
    globalCooldown.active = true
    TriggerClientEvent('hcyk_heists:vangelico:globaltimer', -1, true)
    
    -- Create a timer to track cooldown
    Citizen.CreateThread(function()
        local remainingTime = globalCooldown.timer
        
        while remainingTime > 0 do
            Citizen.Wait(1000)
            remainingTime = remainingTime - 1
        end
        
        globalCooldown.active = false
        TriggerClientEvent('hcyk_heists:vangelico:globaltimer', -1, false)
        
        logToDiscord(
            "Vangelico Heist: Cooldown Ended",
            "**Cooldown:** Global cooldown has ended and heist is now available again.",
            Config.Discord.Colors.Info
        )
    end)
end

local function notifyPolice()
    TriggerClientEvent('cd_dispatch:AddNotification', -1, {
        job_table = Config.Police.Jobs, 
        coords = Config.Vangelico.Dispatch.Coords,
        title = Config.Vangelico.Dispatch.Title,
        message = Config.Vangelico.Dispatch.Message, 
        flash = 1,
        unique_id = tostring(math.random(0000000,9999999)),
        sound = 1,
        blip = Config.Vangelico.Dispatch.Blip
    })
    
    logToDiscord(
        "Vangelico Heist: Police Notified",
        "**Action:** Police dispatch notification sent for Vangelico Heist.",
        Config.Discord.Colors.Info
    )
end

-- Register server events
RegisterServerEvent('hcyk_heists:vangelico:giveitem')
AddEventHandler('hcyk_heists:vangelico:giveitem', function()
    local playerId = source
    if not verifyPlayerInRobbery(playerId) then return end
    
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    local jewelCount = math.random(Config.Vangelico.Rewards.JewelsMin, Config.Vangelico.Rewards.JewelsMax)
    exports.ox_inventory:AddItem(xPlayer.source, 'jewels', jewelCount)
    
    logToDiscord(
        "Vangelico Heist: Reward Given",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Received **" .. jewelCount .. "x** jewels.",
        Config.Discord.Colors.Success
    )
end)

RegisterServerEvent('hcyk_heists:vangelico:removeitem')
AddEventHandler('hcyk_heists:vangelico:removeitem', function(item, count)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    exports.ox_inventory:RemoveItem(xPlayer.source, item, count)
    
    logToDiscord(
        "Vangelico Heist: Item Removed",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Removed **" .. count .. "x** " .. item .. ".",
        Config.Discord.Colors.Info
    )
end)

RegisterServerEvent('hcyk_heists:vangelico:syncSachta')
AddEventHandler('hcyk_heists:vangelico:syncSachta', function(sachta)
    TriggerClientEvent("hcyk_heists:vangelico:SyncSachtaWithServer", -1, sachta)
    
    logToDiscord(
        "Vangelico Heist: Vent Synchronized",
        "**Action:** Vent state synchronized with clients.\n**State:** " .. tostring(sachta),
        Config.Discord.Colors.Info
    )
end)

RegisterServerEvent('hcyk_heists:vangelico:syncVent')
AddEventHandler('hcyk_heists:vangelico:syncVent', function(vent)
    TriggerClientEvent("hcyk_heists:vangelico:SyncOpenedVentWithServer", -1, vent)
    
    logToDiscord(
        "Vangelico Heist: Vent Synchronized",
        "**Action:** Vent state synchronized with clients.\n**State:** " .. tostring(vent),
        Config.Discord.Colors.Info
    )
end)

RegisterServerEvent('hcyk_heists:vangelico:effect')
AddEventHandler('hcyk_heists:vangelico:effect', function(carga, boolean)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    -- Security checks
    if boolean ~= false and boolean ~= true then
        exports["rx_utils"]:fg_BanPlayer(playerId, "Attempted to use heist effect event with invalid parameters.", true)
        
        logToDiscord(
            "Cheat Attempt: Invalid Parameters",
            "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Used effect event with invalid boolean value.",
            Config.Discord.Colors.Error
        )
        return
    end
    
    if boolean and not verifyPlayerPosition(playerId, Config.Vangelico.AirVent, Config.Vangelico.MaxDistance) then
        return
    end
    
    -- Register the player as actively robbing
    activeRobberies[playerId] = boolean
    
    logToDiscord(
        "Vangelico Heist: Heist Started",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Started Vangelico Heist.",
        Config.Discord.Colors.Success
    )
    
    -- Trigger visual effects and notify police
    TriggerClientEvent('hcyk_heists:vangelico:bombaFx', -1, carga)
    Wait(25000) -- Delay before police notification
    notifyPolice()
end)

RegisterServerEvent('hcyk_heists:vangelico:gas')
AddEventHandler('hcyk_heists:vangelico:gas', function()
    TriggerClientEvent('hcyk_heists:vangelico:smoke', -1)
    
    logToDiscord(
        "Vangelico Heist: Gas Released",
        "**Action:** Released gas smoke effect to all clients.",
        Config.Discord.Colors.Info
    )
end)

RegisterServerEvent('hcyk_heists:vangelico:globaltimer')
AddEventHandler('hcyk_heists:vangelico:globaltimer', function(newGlobalTimer)
    local playerId = source
    if not verifyPlayerInRobbery(playerId) then return end
    
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    if newGlobalTimer == true then
        startHeistCooldown()
    end
    
    logToDiscord(
        "Vangelico Heist: Global Timer Updated",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**New Global Timer:** " .. tostring(newGlobalTimer),
        Config.Discord.Colors.Success
    )
end)

-- Server callbacks
ESX.RegisterServerCallback('hcyk_heists:vangelico:pdcount', function(source, cb)
    local xPlayers = ESX.GetPlayers()
    local policeCount = 0
    
    for i = 1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer then
            local job = xPlayer.getJob().name
            if job and Config.HasValue(Config.Police.Jobs, job) then
                policeCount = policeCount + 1
            end
        end
    end
    
    if globalCooldown.active then
        cb(0) -- Cooldown is active, return 0 cops
        
        logToDiscord(
            "Vangelico Heist: PD Count Requested During Cooldown",
            "**Cooldown Active:** Police count request returned 0 due to active cooldown.",
            Config.Discord.Colors.Warning
        )
    else
        cb(policeCount)
        
        logToDiscord(
            "Vangelico Heist: PD Count Requested",
            "**Active Police Count:** " .. policeCount,
            Config.Discord.Colors.Info
        )
    end
end)

-- Handle player disconnection
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local playerName = xPlayer.getName()
    
    if activeRobberies[playerId] then
        debugLog("Player %s (ID: %d) disconnected during heist. Reason: %s", playerName, playerId, reason)
        
        -- Notify police that the robbery has ended
        local xPlayers = ESX.GetPlayers()
        for _, targetId in ipairs(xPlayers) do
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            if targetPlayer and targetPlayer.job and Config.HasValue(Config.Police.Jobs, targetPlayer.job.name) then
                TriggerClientEvent('hcyk_heists:vangelico:stopalertcops', targetId, playerId)
            end
        end
        
        -- Clean up
        activeRobberies[playerId] = nil
        
        logToDiscord(
            "Vangelico Heist: Player Disconnected",
            "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Reason:** " .. reason .. "\n**Action:** Heist ended due to disconnection.",
            Config.Discord.Colors.Error
        )
    end
end)