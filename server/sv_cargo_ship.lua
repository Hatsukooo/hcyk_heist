local ESX = exports["es_extended"]:getSharedObject()
local ServerUtils = exports[GetCurrentResourceName()]:GetServerUtils()
local SharedUtils = exports[GetCurrentResourceName()]:GetSharedUtils()

-- State management
local activeHeists = {}
local cooldownManager = ServerUtils.CreateCooldownManager()

-- Debug logging
local function debugLog(message, ...)
    if Config.Debug then
        print(string.format("[DEBUG] [Cargo Ship] %s", string.format(message, ...)))
    end
end

-- Generate loot for the heist
local function generateLoot(heistId)
    local loot = {}
    local lootSpots = Config.CargoShip.Loot.Spots
    local lootItems = Config.CargoShip.Loot.Items
    
    -- Create a random selection of loot at different spots
    for i = 1, #lootSpots do
        if math.random() < 0.7 then -- 70% chance for loot at each spot
            local selectedLoot = lootItems[math.random(1, #lootItems)]
            local value = math.random(selectedLoot.value[1], selectedLoot.value[2])
            
            loot[i] = {
                id = "loot_" .. i,
                name = selectedLoot.name,
                value = value,
                weight = selectedLoot.weight,
                model = selectedLoot.model,
                position = lootSpots[i],
                collected = false
            }
        end
    end
    
    activeHeists[heistId].loot = loot
    return loot
end

-- Initialize a new heist
local function initializeHeist(playerId, approachType)
    if cooldownManager.isActive("cargo_ship") then
        return false, "This heist is currently unavailable."
    end
    
    local heistId = ServerUtils.CreateHeistSession(playerId, "cargo_ship")
    if not heistId then return false, "Failed to create heist session." end
    
    -- Store heist data
    activeHeists[heistId] = {
        id = heistId,
        startTime = os.time(),
        players = {playerId},
        approachType = approachType,
        alarmTriggered = false,
        guardsAlerted = false,
        completed = false,
        loot = {},
        collectedLoot = {}
    }
    
    -- Generate loot
    generateLoot(heistId)
    
    return true, heistId
end

-- Register server events
RegisterServerEvent('hcyk_heists:cargo_ship:start')
AddEventHandler('hcyk_heists:cargo_ship:start', function(approachType)
    local playerId = source
    
    -- Verify player
    local isValid, xPlayer = ServerUtils.VerifyPlayer(
        playerId, nil, Config.CargoShip.NPCpoint, Config.CargoShip.MaxDistance
    )
    
    if not isValid then return end
    
    -- Check police count
    local policeCount = ServerUtils.GetOnlineCops()
    if policeCount < Config.CargoShip.RequiredCops then
        TriggerClientEvent('hcyk_heists:cargo_ship:notify', playerId, 'Error', 'Insufficient police officers on duty!')
        return
    end
    
    -- Check required items based on approach
    local requiredItems = {}
    table.insert(requiredItems, Config.CargoShip.RequiredItems.Lockpick)
    table.insert(requiredItems, Config.CargoShip.RequiredItems.Hacking)
    
    if approachType == "water_approach" then
        table.insert(requiredItems, Config.CargoShip.RequiredItems.WaterGear)
    end
    
    if not ServerUtils.HasRequiredItems(playerId, requiredItems) then
        TriggerClientEvent('hcyk_heists:cargo_ship:notify', playerId, 'Error', 'You are missing required equipment!')
        return
    end
    
    -- Initialize the heist
    local success, result = initializeHeist(playerId, approachType)
    if not success then
        TriggerClientEvent('hcyk_heists:cargo_ship:notify', playerId, 'Error', result)
        return
    end
    
    -- Start the heist
    TriggerClientEvent('hcyk_heists:cargo_ship:setup', playerId, result, activeHeists[result])
    
    -- Log heist start
    SharedUtils.LogToDiscord(
        "Cargo Ship Heist Started",
        string.format("**Player:** %s\n**Approach:** %s\n**Session ID:** %s", 
            GetPlayerName(playerId), approachType, result),
        Config.Discord.Colors.Info,
        nil,
        "**[CARGO SHIP]**"
    )
end)

-- Handle alarm triggers
RegisterServerEvent('hcyk_heists:cargo_ship:triggerAlarm')
AddEventHandler('hcyk_heists:cargo_ship:triggerAlarm', function(heistId, silent)
    local playerId = source
    
    -- Verify heist exists and player is part of it
    if not activeHeists[heistId] or not table.contains(activeHeists[heistId].players, playerId) then
        ServerUtils.LogCheatAttempt(playerId, "Invalid heist manipulation", 
            "Tried to trigger alarm for invalid heist: " .. tostring(heistId))
        return
    end
    
    -- Update heist state
    activeHeists[heistId].alarmTriggered = true
    activeHeists[heistId].guardsAlerted = true
    
    -- Notify all players in the heist
    for _, pid in ipairs(activeHeists[heistId].players) do
        TriggerClientEvent('hcyk_heists:cargo_ship:alarmTriggered', pid)
    end
    
    -- Notify police
    local dispatchConfig = silent 
        and Config.CargoShip.Dispatch.Silent 
        or Config.CargoShip.Dispatch.Loud
    
    ServerUtils.NotifyPolice({
        title = dispatchConfig.Title,
        message = dispatchConfig.Message,
        coords = Config.CargoShip.ShipLocation,
        blip = dispatchConfig.Blip
    })
    
    -- Log the alarm
    SharedUtils.LogToDiscord(
        "Cargo Ship Alarm Triggered",
        string.format("**Player:** %s\n**Heist ID:** %s\n**Alert Type:** %s", 
            GetPlayerName(playerId), heistId, silent and "Silent" or "Loud"),
        Config.Discord.Colors.Warning,
        nil,
        "**[CARGO SHIP]**"
    )
end)

-- Handle loot collection
RegisterServerEvent('hcyk_heists:cargo_ship:collectLoot')
AddEventHandler('hcyk_heists:cargo_ship:collectLoot', function(heistId, lootId)
    local playerId = source
    
    -- Verify heist exists and player is part of it
    if not activeHeists[heistId] or not table.contains(activeHeists[heistId].players, playerId) then
        ServerUtils.LogCheatAttempt(playerId, "Invalid loot collection", 
            "Tried to collect loot for invalid heist: " .. tostring(heistId))
        return
    end
    
    -- Find the loot
    local lootFound = false
    for i, loot in pairs(activeHeists[heistId].loot) do
        if loot.id == lootId and not loot.collected then
            lootFound = true
            loot.collected = true
            
            -- Add to collected loot
            table.insert(activeHeists[heistId].collectedLoot, {
                player = playerId,
                item = loot.name,
                value = loot.value,
                weight = loot.weight
            })
            
            -- Notify player
            TriggerClientEvent('hcyk_heists:cargo_ship:notify', playerId, 'Success', 
                string.format('You collected %s worth $%d!', loot.name, loot.value))
                
            -- Sync with all players
            for _, pid in ipairs(activeHeists[heistId].players) do
                TriggerClientEvent('hcyk_heists:cargo_ship:syncLoot', pid, activeHeists[heistId].loot)
            end
            
            break
        end
    end
    
    if not lootFound then
        TriggerClientEvent('hcyk_heists:cargo_ship:notify', playerId, 'Error', 'This item has already been collected!')
    end
end)

-- Handle heist completion
RegisterServerEvent('hcyk_heists:cargo_ship:complete')
AddEventHandler('hcyk_heists:cargo_ship:complete', function(heistId)
    local playerId = source
    
    -- Verify heist exists and player is part of it
    if not activeHeists[heistId] or not table.contains(activeHeists[heistId].players, playerId) then
        ServerUtils.LogCheatAttempt(playerId, "Invalid heist completion", 
            "Tried to complete invalid heist: " .. tostring(heistId))
        return
    end
    
    -- Calculate rewards for this player
    local playerLoot = {}
    local totalValue = 0
    
    for _, loot in ipairs(activeHeists[heistId].collectedLoot) do
        if loot.player == playerId then
            table.insert(playerLoot, loot)
            totalValue = totalValue + loot.value
        end
    end
    
    -- Apply difficulty multiplier
    local approachDifficulty = "Medium" -- Default
    for _, point in ipairs(Config.CargoShip.ApproachPoints) do
        if point.name == activeHeists[heistId].approachType then
            approachDifficulty = point.difficulty
            break
        end
    end
    
    local multiplier = Config.CargoShip.Difficulty[approachDifficulty].lootMultiplier
    totalValue = math.floor(totalValue * multiplier)
    
    -- Give reward
    if totalValue > 0 then
        ServerUtils.AddMoney(playerId, 'money', totalValue)
        TriggerClientEvent('hcyk_heists:cargo_ship:notify', playerId, 'Success', 
            string.format('Heist completed! You earned $%d', totalValue))
    else
        TriggerClientEvent('hcyk_heists:cargo_ship:notify', playerId, 'Warning', 
            'Heist completed, but you didn\'t collect any loot!')
    end
    
    -- Mark heist as completed for this player
    for i, pid in ipairs(activeHeists[heistId].players) do
        if pid == playerId then
            table.remove(activeHeists[heistId].players, i)
            break
        end
    end
    
    -- If no players left, clean up the heist
    if #activeHeists[heistId].players == 0 then
        activeHeists[heistId].completed = true
        
        -- Set cooldown
        cooldownManager.set("cargo_ship", Config.CargoShip.GlobalCooldown * 60)
        
        -- Log heist completion
        SharedUtils.LogToDiscord(
            "Cargo Ship Heist Completed",
            string.format("**Heist ID:** %s\n**Total Players:** %d\n**Total Loot Value:** $%d", 
                heistId, #activeHeists[heistId].collectedLoot, getTotalLootValue(heistId)),
            Config.Discord.Colors.Success,
            nil,
            "**[CARGO SHIP]**"
        )
    end
end)

-- Helper function to get total loot value
function getTotalLootValue(heistId)
    local total = 0
    for _, loot in ipairs(activeHeists[heistId].collectedLoot) do
        total = total + loot.value
    end
    return total
end

-- Server callbacks
ESX.RegisterServerCallback('hcyk_heists:cargo_ship:getStatus', function(source, cb)
    cb(not cooldownManager.isActive("cargo_ship"), cooldownManager.getRemainingTime("cargo_ship"))
end)

-- Handle player dropping during heist
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    
    -- Check if player is in any active heist
    for heistId, heist in pairs(activeHeists) do
        for i, pid in ipairs(heist.players) do
            if pid == playerId then
                -- Remove player from heist
                table.remove(heist.players, i)
                
                -- Log player drop
                SharedUtils.LogToDiscord(
                    "Player Dropped During Heist",
                    string.format("**Player:** %s\n**Heist ID:** %s\n**Reason:** %s", 
                        GetPlayerName(playerId), heistId, reason),
                    Config.Discord.Colors.Warning,
                    nil,
                    "**[CARGO SHIP]**"
                )
                
                -- If no players left, clean up the heist
                if #heist.players == 0 then
                    heist.completed = true
                end
                
                break
            end
        end
    end
end)

-- Helper function to check if a value exists in a table
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end