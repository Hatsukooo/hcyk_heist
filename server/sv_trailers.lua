-- server/sv_trailers.lua
local ESX = exports["es_extended"]:getSharedObject()

-- Import our new modules
local ErrorHandler = _G.ErrorHandler
local SecuritySystem = exports[GetCurrentResourceName()]:GetSecurityModule()
local HeistConfig = _G.HeistConfig

-- State management
local activeRobberies = {}  -- Active robberies by player ID
local globalCooldown = false
local robbedContainers = {} -- Track robbed containers across the server
local robberyCount = 0      -- Count of successful robberies since restart

-- Debug logging
local function debugLog(message, ...)
    if HeistConfig.Debug then
        print("[DEBUG] [Trailers Heist] " .. string.format(message, ...))
    end
end

-- Get loot for container robbery
local function getLoot(playerId)
    ErrorHandler.SafeExecute("trailers_get_loot", function()
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then return end
        
        -- Security check - verify player exists and is not cheating
        if not SecuritySystem.VerifyPosition(playerId) then return end
        
        -- Select random tier from loot table based on chance
        local lootTable = HeistConfig.Trailers.Loot
        local selectedTier = nil
        local rand = math.random(1, 100)
        local currentChance = 0
        
        for _, tier in ipairs(lootTable) do
            currentChance = currentChance + tier.chance
            if rand <= currentChance then
                selectedTier = tier
                break
            end
        end
        
        if not selectedTier then return end
        
        -- Track items given for logging
        local givenItems = {}
        
        -- Select random number of items from tier based on itemCount
        local itemCount = math.random(
            selectedTier.itemCount.min, 
            selectedTier.itemCount.max
        )
        
        -- Shuffle items for random selection
        local shuffledItems = {}
        for _, item in ipairs(selectedTier.items) do
            table.insert(shuffledItems, item)
        end
        
        -- Fisher-Yates shuffle
        for i = #shuffledItems, 2, -1 do
            local j = math.random(i)
            shuffledItems[i], shuffledItems[j] = shuffledItems[j], shuffledItems[i]
        end
        
        -- Give random items based on item count
        for i = 1, math.min(itemCount, #shuffledItems) do
            local item = shuffledItems[i]
            local count = math.random(item.min, item.max)
            
            exports.ox_inventory:AddItem(playerId, item.name, count)
            table.insert(givenItems, { name = item.name, count = count })
        end
        
        -- Always give some money
        local moneyAmount = math.random(500, 2500)
        exports.ox_inventory:AddItem(playerId, 'money', moneyAmount)
        table.insert(givenItems, { name = 'money', count = moneyAmount })
        
        -- Increment robbery count
        robberyCount = robberyCount + 1
        
        -- Send success feedback to client
        TriggerClientEvent('hcyk_heists:trailers:robberyComplete', playerId)
        
        -- Format items for log
        local itemLog = ""
        for _, item in ipairs(givenItems) do
            itemLog = itemLog .. "- " .. item.count .. "x " .. item.name .. "\n"
        end
        
        -- Log to discord
        if HeistConfig.Discord and HeistConfig.Discord.Enabled then
            local embed = {
                {
                    ["title"] = '**[TRAILERS]** Loot Given',
                    ["description"] = string.format("**Player:** %s (ID: %s)\n**Items:**\n%s",
                        GetPlayerName(playerId), playerId, itemLog),
                    ["type"] = "rich",
                    ["color"] = HeistConfig.Discord.Colors.Success,
                    ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }

            PerformHttpRequest(HeistConfig.Discord.Webhook, function(err, text, headers) end, 'POST', 
                json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
        end
    end)
end

-- Register container as robbed
local function registerContainer(playerId, containerNetId)
    ErrorHandler.SafeExecute("trailers_register_container", function()
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then return end
        
        -- Add container to robbed list
        robbedContainers[containerNetId] = true
        
        -- Sync with all clients
        TriggerClientEvent('hcyk_heists:trailers:syncRobbedContainers', -1, robbedContainers)
        
        debugLog("Container %s registered as robbed by player %s", containerNetId, playerId)
    end)
end

-- Secure event registration using our SecuritySystem
SecuritySystem.SecureEventHandler('hcyk_heists:trailers:giveLoot', function(playerId)
    -- Check cooldown and max robberies
    if globalCooldown then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Chyba',
            description = 'Už jsi nedávno vykradl kontejner, počkej chvíli!',
            type = 'error'
        })
        return
    end
    
    if robberyCount >= HeistConfig.Trailers.MaxDaily then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Chyba',
            description = 'Všechny kontejnery ve městě byly již vyloupeny!',
            type = 'error'
        })
        return
    end
    
    getLoot(playerId)
    
    -- Set player cooldown
    activeRobberies[playerId] = os.time()
    
    -- Set global cooldown
    if not globalCooldown then
        globalCooldown = true
        
        -- Reset cooldown after time
        Citizen.SetTimeout(HeistConfig.Trailers.GlobalCooldown * 60 * 1000, function()
            globalCooldown = false
            debugLog("Global cooldown ended")
        end)
    end
}, {
    verifyPosition = true  -- Verify player position
})

SecuritySystem.SecureEventHandler('hcyk_heists:trailers:registerContainer', function(playerId, containerNetId)
    registerContainer(playerId, containerNetId)
}, {
    verifyPosition = true  -- Verify player position
})

SecuritySystem.SecureEventHandler('hcyk_heists:trailers:notifyPolice', function(playerId, coords)
    ErrorHandler.SafeExecute("trailers_notify_police", function()
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then return end
        
        -- Generate random offset coordinates for police notification
        local offsetX = math.random(-100, 100)
        local offsetY = math.random(-100, 100)
        local newCoords = vector3(coords.x + offsetX, coords.y + offsetY, coords.z)
        
        -- Send dispatch notification
        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = HeistConfig.Police.Jobs, 
            coords = newCoords,
            title = HeistConfig.Trailers.Dispatch.Title,
            message = HeistConfig.Trailers.Dispatch.Message, 
            flash = 1,
            unique_id = tostring(math.random(0000000,9999999)),
            sound = 1,
            blip = HeistConfig.Trailers.Dispatch.Blip
        })
        
        debugLog("Police notified of robbery at %s", json.encode(newCoords))
    end)
}, {
    verifyPosition = true  -- Verify player position
})

-- Server callbacks
ESX.RegisterServerCallback('hcyk_heists:trailers:pdcount', function(source, cb)
    ErrorHandler.SafeExecute("trailers_pdcount_callback", function()
        local xPlayers = ESX.GetPlayers()
        local policeCount = 0
        
        for i = 1, #xPlayers, 1 do
            local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
            if xPlayer and xPlayer.job then
                if HeistConfig.HasValue(HeistConfig.Police.Jobs, xPlayer.job.name) then
                    policeCount = policeCount + 1
                end
            end
        end
        
        debugLog("Police count: %d", policeCount)
        cb(policeCount)
    end)
end)

ESX.RegisterServerCallback('hcyk_heists:trailers:hasItem', function(source, cb, itemName)
    ErrorHandler.SafeExecute("trailers_hasitem_callback", function() 
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then 
            cb(false)
            return 
        end
        
        local hasItem = false
        if exports.ox_inventory then
            local count = exports.ox_inventory:Search(source, 'count', itemName)
            hasItem = count and count > 0
        else
            local item = xPlayer.getInventoryItem(itemName)
            hasItem = item and item.count > 0
        end
        
        cb(hasItem)
    end)
end)

-- Handle player disconnection
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    -- Remove player from active robberies list
    activeRobberies[playerId] = nil
end)

-- Reset container state on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    robbedContainers = {}
    robberyCount = 0
    debugLog("Resource started, container state reset")
end)

-- Export security module for other files to use
exports('GetSecurityModule', function()
    return SecuritySystem
end)