local ServerUtils = {}

-- Import shared utilities
local SharedUtils = exports[GetCurrentResourceName()]:GetSharedUtils()

-- Enhanced security verification
function ServerUtils.VerifyPlayer(playerId, states, position, maxDistance)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false, "Invalid player" end
    
    -- If states table is provided, check if player is in an allowed state
    if states then
        local found = false
        for _, state in pairs(states) do
            if state == true then
                found = true
                break
            end
        end
        
        if not found then
            -- Log unauthorized access attempt
            ServerUtils.LogCheatAttempt(playerId, "Unauthorized event access", "Tried to use an event without being in the correct state")
            return false, "Unauthorized access"
        end
    end
    
    -- If position and maxDistance are provided, verify player's location
    if position and maxDistance then
        local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
        local distance = #(playerCoords - vector3(position.x, position.y, position.z))
        
        if distance > maxDistance then
            -- Log suspicious activity
            ServerUtils.LogCheatAttempt(playerId, "Invalid position", 
                string.format("Distance: %.2f (max allowed: %.2f)", distance, maxDistance))
            return false, "Invalid position"
        end
    end
    
    return true, xPlayer
end

-- Log suspicious activity with anti-cheat action
function ServerUtils.LogCheatAttempt(playerId, reason, details)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or "Unknown"
    local playerIdentifier = xPlayer and xPlayer.getIdentifier() or "Unknown"
    
    -- Log to console
    print(string.format("[ANTICHEAT] Player %s (%s) - %s: %s", 
        playerName, playerId, reason, details or "No details"))
    
    -- Log to Discord
    if Config.Discord and Config.Discord.Enabled then
        local embed = {
            {
                ["title"] = '**[ANTICHEAT]** Suspicious Activity Detected',
                ["description"] = string.format("**Player:** %s (ID: %s)\n**Identifier:** %s\n**Reason:** %s\n**Details:** %s",
                    playerName, playerId, playerIdentifier, reason, details or "No details"),
                ["type"] = "rich",
                ["color"] = Config.Discord.Colors.Error,
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                ["footer"] = {
                    ["text"] = "Heist Anticheat System",
                },
            }
        }

        PerformHttpRequest(Config.Discord.Webhook, function(err, text, headers) end, 'POST', 
            json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
    
    -- Ban player if enabled in config
    if Config.Anticheat and Config.Anticheat.AutoBan then
        exports["rx_utils"]:fg_BanPlayer(playerId, reason, true)
    end
end

-- Get count of online players with specific job
function ServerUtils.GetOnlineCops()
    local xPlayers = ESX.GetPlayers()
    local count = 0
    
    for i = 1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer and xPlayer.job then
            if Config.HasValue(Config.Police.Jobs, xPlayer.job.name) then
                count = count + 1
            end
        end
    end
    
    return count
end

-- Safely give item to player with verification
function ServerUtils.GiveItem(playerId, itemName, count, verify)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    -- Verify the reward is within allowed limits
    if verify then
        local itemConfig = verify.items and verify.items[itemName]
        if itemConfig then
            local maxCount = itemConfig.max or 10 -- Default max
            if count > maxCount then
                ServerUtils.LogCheatAttempt(playerId, "Invalid item count", 
                    string.format("Tried to get %d of %s (max: %d)", count, itemName, maxCount))
                count = maxCount
            end
        end
    end
    
    -- Give item using ox_inventory (with fallback to ESX inventory)
    local success = false
    if exports.ox_inventory then
        success = exports.ox_inventory:AddItem(playerId, itemName, count)
    else
        xPlayer.addInventoryItem(itemName, count)
        success = true
    end
    
    -- Log the reward
    if success and Config.Discord and Config.Discord.Enabled then
        local playerName = xPlayer.getName()
        SharedUtils.LogToDiscord(
            "Item Given",
            string.format("**Player:** %s (ID: %s)\n**Item:** %s\n**Count:** %d", 
                playerName, playerId, itemName, count),
            Config.Discord.Colors.Success
        )
    end
    
    return success
end

-- Safely remove item from player with verification
function ServerUtils.RemoveItem(playerId, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    -- Remove item using ox_inventory (with fallback to ESX inventory)
    local success = false
    if exports.ox_inventory then
        success = exports.ox_inventory:RemoveItem(playerId, itemName, count)
    else
        if xPlayer.getInventoryItem(itemName).count >= count then
            xPlayer.removeInventoryItem(itemName, count)
            success = true
        end
    end
    
    -- Log the removal
    if success and Config.Discord and Config.Discord.Enabled then
        local playerName = xPlayer.getName()
        SharedUtils.LogToDiscord(
            "Item Removed",
            string.format("**Player:** %s (ID: %s)\n**Item:** %s\n**Count:** %d", 
                playerName, playerId, itemName, count),
            Config.Discord.Colors.Info
        )
    end
    
    return success
end

-- Send notification to all police officers
function ServerUtils.NotifyPolice(data)
    local xPlayers = ESX.GetPlayers()
    
    for i = 1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer and Config.HasValue(Config.Police.Jobs, xPlayer.job.name) then
            TriggerClientEvent('hcyk_heists:receivePoliceNotification', xPlayer.source, data)
        end
    end
    
    -- Also send to dispatch system if enabled
    if Config.UseDispatchSystem then
        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = Config.Police.Jobs, 
            coords = data.coords,
            title = data.title,
            message = data.message, 
            flash = 1,
            unique_id = tostring(math.random(0000000,9999999)),
            sound = 1,
            blip = data.blip
        })
    end
    
    -- Log the notification
    if Config.Discord and Config.Discord.Enabled then
        SharedUtils.LogToDiscord(
            "Police Notified",
            string.format("**Alert:** %s\n**Message:** %s\n**Location:** %s", 
                data.title, data.message, SharedUtils.FormatCoords(data.coords)),
            Config.Discord.Colors.Info
        )
    end
end

-- Create a timer with callback on completion
function ServerUtils.CreateTimer(duration, onTick, onComplete, tickInterval)
    tickInterval = tickInterval or 1000 -- Default: 1 second
    local remainingTime = duration
    
    Citizen.CreateThread(function()
        while remainingTime > 0 do
            Citizen.Wait(tickInterval)
            remainingTime = remainingTime - (tickInterval / 1000)
            
            if onTick then
                onTick(remainingTime)
            end
        end
        
        if onComplete then
            onComplete()
        end
    end)
    
    return {
        getRemainingTime = function() return remainingTime end,
        isActive = function() return remainingTime > 0 end
    }
end

-- Get closest player to coordinates
function ServerUtils.GetClosestPlayer(coords, maxDistance)
    maxDistance = maxDistance or 5.0
    local closestPlayer = nil
    local closestDistance = maxDistance
    
    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        local playerPed = GetPlayerPed(xPlayer.source)
        local playerCoords = GetEntityCoords(playerPed)
        
        local distance = #(coords - playerCoords)
        if distance < closestDistance then
            closestPlayer = xPlayer.source
            closestDistance = distance
        end
    end
    
    return closestPlayer, closestDistance
end

-- Check if enough time has passed since an event
function ServerUtils.CheckCooldown(cooldowns, identifier, cooldownTime)
    local currentTime = os.time()
    
    if not cooldowns[identifier] then
        cooldowns[identifier] = currentTime
        return true
    end
    
    local timePassed = currentTime - cooldowns[identifier]
    if timePassed < cooldownTime then
        return false, cooldownTime - timePassed
    end
    
    -- Reset cooldown
    cooldowns[identifier] = currentTime
    return true
end

-- Validate reward based on config limits
function ServerUtils.ValidateReward(reward, minReward, maxReward, multiplier)
    -- Apply multiplier if provided
    if multiplier then
        reward = reward * multiplier
    end
    
    -- Clamp reward within limits
    return math.max(minReward, math.min(maxReward, reward))
end

-- Register a callback that runs only once per player session
function ServerUtils.RegisterOneTimeCallback(name, playerId, cb)
    local cbName = name .. "_" .. playerId
    local executed = false
    
    ESX.RegisterServerCallback(cbName, function(source, callback, ...)
        if executed then
            ServerUtils.LogCheatAttempt(source, "Callback exploitation", 
                "Tried to execute one-time callback multiple times: " .. name)
            callback(false)
            return
        end
        
        executed = true
        cb(source, callback, ...)
    end)
    
    return cbName
end

-- Create a unique session ID for a heist instance
function ServerUtils.CreateHeistSession(playerId, heistType)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return nil end
    
    local sessionId = SharedUtils.GenerateUniqueID(heistType .. "_")
    
    -- Log session creation
    if Config.Discord and Config.Discord.Enabled then
        local playerName = xPlayer.getName()
        SharedUtils.LogToDiscord(
            "Heist Session Created",
            string.format("**Player:** %s (ID: %s)\n**Heist Type:** %s\n**Session ID:** %s", 
                playerName, playerId, heistType, sessionId),
            Config.Discord.Colors.Info
        )
    end
    
    return sessionId
end

-- Get all online players with a specific job
function ServerUtils.GetPlayersWithJob(jobName)
    local players = {}
    local xPlayers = ESX.GetPlayers()
    
    for i=1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer and xPlayer.job and xPlayer.job.name == jobName then
            table.insert(players, xPlayer)
        end
    end
    
    return players
end

-- Broadcast a message to all players with specific job
function ServerUtils.BroadcastToJob(jobName, eventName, ...)
    local players = ServerUtils.GetPlayersWithJob(jobName)
    
    for _, player in ipairs(players) do
        TriggerClientEvent(eventName, player.source, ...)
    end
end

-- Register a secure event that verifies player state
function ServerUtils.RegisterSecureEvent(eventName, stateCheck, handler)
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function(...)
        local playerId = source
        
        -- Check if the player is in a valid state
        if stateCheck and not stateCheck(playerId) then
            ServerUtils.LogCheatAttempt(playerId, "Unauthorized event trigger", 
                "Player triggered " .. eventName .. " in invalid state")
            return
        end
        
        -- Call the handler if validation passes
        handler(playerId, ...)
    end)
end

-- Check if a player has required items
function ServerUtils.HasRequiredItems(playerId, itemList)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    for _, itemData in ipairs(itemList) do
        local itemName = itemData.name
        local itemCount = itemData.count or 1
        
        if exports.ox_inventory then
            local count = exports.ox_inventory:Search(playerId, 'count', itemName)
            if not count or count < itemCount then
                return false
            end
        else
            local item = xPlayer.getInventoryItem(itemName)
            if not item or item.count < itemCount then
                return false
            end
        end
    end
    
    return true
end

-- Add money to player with logging
function ServerUtils.AddMoney(playerId, type, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    -- Validate the amount
    if amount <= 0 then return false end
    
    -- Add money based on type
    if type == 'money' then
        xPlayer.addMoney(amount)
    elseif type == 'black_money' then
        xPlayer.addAccountMoney('black_money', amount)
    elseif type == 'bank' then
        xPlayer.addAccountMoney('bank', amount)
    else
        return false
    end
    
    -- Log the transaction
    local playerName = xPlayer.getName()
    SharedUtils.LogToDiscord(
        "Money Transaction",
        string.format("**Player:** %s (ID: %s)\n**Type:** %s\n**Amount:** $%d", 
            playerName, playerId, type, amount),
        Config.Discord.Colors.Success
    )
    
    return true
end

-- Get server-side cooldown manager
function ServerUtils.CreateCooldownManager()
    local cooldowns = {}
    
    return {
        -- Set cooldown
        set = function(identifier, duration)
            cooldowns[identifier] = {
                active = true,
                expires = os.time() + duration
            }
            
            -- Create auto-clearing timer
            Citizen.SetTimeout(duration * 1000, function()
                if cooldowns[identifier] then
                    cooldowns[identifier].active = false
                end
            end)
        end,
        
        -- Check if cooldown is active
        isActive = function(identifier)
            return cooldowns[identifier] and cooldowns[identifier].active or false
        end,
        
        -- Get remaining time in seconds
        getRemainingTime = function(identifier)
            if not cooldowns[identifier] or not cooldowns[identifier].active then
                return 0
            end
            
            local remaining = cooldowns[identifier].expires - os.time()
            return remaining > 0 and remaining or 0
        end,
        
        -- Clear cooldown
        clear = function(identifier)
            if cooldowns[identifier] then
                cooldowns[identifier].active = false
            end
        end,
        
        -- Clear all cooldowns
        clearAll = function()
            for id, _ in pairs(cooldowns) do
                cooldowns[id].active = false
            end
        end
    }
end

return ServerUtils