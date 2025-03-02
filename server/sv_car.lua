local ESX = exports["es_extended"]:getSharedObject()

-- State management
local activeRobberies = {} -- Active car heists by player ID
local globalCooldown = false -- Global cooldown state

-- Utility functions
local function debugLog(message, ...)
    if Config.Debug then
        print("[DEBUG] [Car Heist] " .. string.format(message, ...))
    end
end

-- Discord logging system
local function logToDiscord(title, description, color, fields)
    if not Config.Discord.Enabled then return end
    
    local embed = {
        {
            ["title"] = '**[CAR]** ' .. title,
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
        exports["rx_utils"]:fg_BanPlayer(playerId, "Unauthorized Car heist event usage detected.", true)
        
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

-- Register server events
RegisterServerEvent('hcyk_heists:car:stealing')
AddEventHandler('hcyk_heists:car:stealing', function(value)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    -- Security checks
    if value ~= false and value ~= true then
        exports["rx_utils"]:fg_BanPlayer(playerId, "Attempted to use car heist stealing event with invalid parameters.", true)
        
        logToDiscord(
            "Cheat Attempt: Invalid Parameters",
            "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Used stealing event with invalid boolean value.",
            Config.Discord.Colors.Error
        )
        return
    end
    
    if value and not verifyPlayerPosition(playerId, Config.Car.NPCpoint, Config.Car.MaxDistance) then
        return
    end
    
    -- Register the player as actively stealing
    activeRobberies[playerId] = value
    
    logToDiscord(
        "Car Heist: Stealing Status Changed",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Stealing Started:** " .. tostring(value),
        Config.Discord.Colors.Success
    )
end)

RegisterServerEvent('hcyk_heists:car:changeStatus')
AddEventHandler('hcyk_heists:car:changeStatus', function(status, value)
    local playerId = source
    if not verifyPlayerInRobbery(playerId) then return end
    
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    TriggerClientEvent('hcyk_heists:car:changeStatus', -1, status, value)
    
    if status == 'Cooldown' then
        globalCooldown = value
        
        if value then
            -- Set a timer to end the cooldown
            SetTimeout(Config.Car.GlobalCooldown * 60 * 1000, function()
                globalCooldown = false
                TriggerClientEvent('hcyk_heists:car:changeStatus', -1, 'Cooldown', false)
                
                logToDiscord(
                    "Car Heist: Cooldown Ended",
                    "**Cooldown:** Global cooldown has ended and heist is now available again.",
                    Config.Discord.Colors.Info
                )
            end)
        end
    end
    
    logToDiscord(
        "Car Heist: Status Changed",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Status:** " .. status .. "\n**Value:** " .. tostring(value),
        Config.Discord.Colors.Success
    )
end)

RegisterServerEvent('hcyk_heists:car:givereward')
AddEventHandler('hcyk_heists:car:givereward', function(reward)
    local playerId = source
    if not verifyPlayerInRobbery(playerId) then return end
    
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    local minReward = Config.Car.Rewards.Min
    local maxReward = Config.Car.Rewards.Max * 1.1 
    local clampedReward = math.max(minReward, math.min(maxReward, reward))
    
    exports.ox_inventory:AddItem(playerId, 'money', clampedReward)
    
    logToDiscord(
        "Car Heist: Reward Granted",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Reward:** $" .. tostring(clampedReward) .. " money awarded.",
        Config.Discord.Colors.Success
    )
end)

RegisterServerEvent('hcyk_heists:car:notifycops')
AddEventHandler('hcyk_heists:car:notifycops', function(coordsx)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    
    -- Generate random offset coordinates for police notification
    local newCoords = Config.GetRandomOffsetCoords(coordsx, 100, 150)
    
    -- Send dispatch notification
    TriggerClientEvent('cd_dispatch:AddNotification', -1, {
        job_table = Config.Police.Jobs, 
        coords = newCoords,
        title = Config.Car.Dispatch.Title,
        message = Config.Car.Dispatch.Message, 
        flash = 1,
        unique_id = tostring(math.random(0000000,9999999)),
        sound = 1,
        blip = Config.Car.Dispatch.Blip
    })
    
    logToDiscord(
        "Car Heist: Police Notified",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Location:** Offset location near " .. tostring(coordsx),
        Config.Discord.Colors.Info
    )
end)

RegisterServerEvent('hcyk_heists:car:startalertcops')
AddEventHandler('hcyk_heists:car:startalertcops', function()
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    local playerName = xPlayer.getName()
    local thiefServerId = playerId

    -- Notify all police officers about the thief
    for _, targetId in ipairs(ESX.GetPlayers()) do
        local targetPlayer = ESX.GetPlayerFromId(targetId)
        if targetPlayer and targetPlayer.job and Config.HasValue(Config.Police.Jobs, targetPlayer.job.name) then
            debugLog('Sending startalertcops event to Police ID: %d', targetId)
            TriggerClientEvent('hcyk_heists:car:startalertcops', targetId, thiefServerId)
        end
    end

    logToDiscord(
        "Car Heist: Tracking Started",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Police tracking of suspect initiated.",
        Config.Discord.Colors.Success
    )
end)

RegisterServerEvent('hcyk_heists:car:stopalertcops')
AddEventHandler('hcyk_heists:car:stopalertcops', function()
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    local playerName = xPlayer.getName()

    -- Stop all police tracking for this thief
    for _, targetId in ipairs(ESX.GetPlayers()) do
        local targetPlayer = ESX.GetPlayerFromId(targetId)
        if targetPlayer and targetPlayer.job and Config.HasValue(Config.Police.Jobs, targetPlayer.job.name) then
            TriggerClientEvent('hcyk_heists:car:stopalertcops', targetId)
        end
    end

    logToDiscord(
        "Car Heist: Tracking Stopped",
        "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Action:** Police tracking of suspect stopped.",
        Config.Discord.Colors.Warning
    )
end)

-- Server callbacks
ESX.RegisterServerCallback('hcyk_heists:car:pdcount', function(source, cb)
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
    
    if globalCooldown then
        cb(0) -- Cooldown is active, return 0 cops
        
        logToDiscord(
            "Car Heist: PD Count Requested During Cooldown",
            "**Cooldown Active:** Police count request returned 0 due to active cooldown.",
            Config.Discord.Colors.Warning
        )
    else
        cb(policeCount)
        
        logToDiscord(
            "Car Heist: PD Count Requested",
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
        debugLog("Player %s (ID: %d) disconnected during car heist. Reason: %s", playerName, playerId, reason)
        
        -- Notify police that the robbery has ended
        for _, targetId in ipairs(ESX.GetPlayers()) do
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            if targetPlayer and targetPlayer.job and Config.HasValue(Config.Police.Jobs, targetPlayer.job.name) then
                TriggerClientEvent('hcyk_heists:car:stopalertcops', targetId)
            end
        end
        
        -- Clean up
        activeRobberies[playerId] = nil
        
        logToDiscord(
            "Car Heist: Player Disconnected",
            "**Player:** " .. playerName .. " (ID: " .. playerId .. ")\n**Reason:** " .. reason .. "\n**Action:** Heist ended due to disconnection.",
            Config.Discord.Colors.Error
        )
    end
end)