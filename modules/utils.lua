--[[
    Shared Utility Functions for Heist Scripts
    Provides common functionality used across multiple scripts
]]

local Utils = {}

-- Debug logging with formatting
function Utils.DebugLog(component, message, ...)
    if Config and Config.Debug then
        print(string.format("[DEBUG] [%s] %s", component, string.format(message, ...)))
    end
end

-- Discord logging system
function Utils.LogToDiscord(title, description, color, fields, prefix)
    if not Config.Discord or not Config.Discord.Enabled then return end
    
    prefix = prefix or ""
    
    local embed = {
        {
            ["title"] = prefix .. ' ' .. title,
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

-- Notification system for client-side
function Utils.Notify(type, title, message, duration, position)
    duration = duration or 5000
    position = position or "top"
    
    lib.notify({
        title = title,
        description = message,
        type = type,
        duration = duration,
        position = position
    })
end

-- Check if a player has a specific job
function Utils.HasJob(player, jobName)
    if not player or not player.job then return false end
    return player.job.name == jobName
end

-- Check if a player is a police officer
function Utils.IsPoliceOfficer(player)
    if not player or not player.job then return false end
    return Config.HasValue(Config.Police.Jobs, player.job.name)
end

-- Check if player has an item (client-side)
function Utils.HasItem(itemName, count)
    count = count or 1
    local itemCount = exports.ox_inventory:Search('count', itemName)
    return itemCount and itemCount >= count
end

-- Format coordinates for logging
function Utils.FormatCoords(coords)
    if not coords then return "nil" end
    return string.format("x: %.2f, y: %.2f, z: %.2f", coords.x, coords.y, coords.z)
end

-- Play animation with proper error handling
function Utils.PlayAnimation(ped, dict, anim, duration, flags)
    ped = ped or PlayerPedId()
    flags = flags or 0
    
    -- Request animation dictionary
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        
        -- Wait up to 1 second for dictionary to load
        local timeout = 1000
        local timer = 0
        local waitTime = 10
        
        while not HasAnimDictLoaded(dict) and timer < timeout do
            Citizen.Wait(waitTime)
            timer = timer + waitTime
        end
        
        if timer >= timeout then
            Utils.DebugLog("Animation", "Failed to load animation dictionary: %s", dict)
            return false
        end
    end
    
    -- Play the animation
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, flags, 0, false, false, false)
    
    -- Optionally wait for animation to complete
    if duration then
        Citizen.Wait(duration)
        ClearPedTasks(ped)
    end
    
    return true
end

-- Create a progress bar with animation
function Utils.ProgressBar(label, duration, dict, anim, flags, disableOptions)
    disableOptions = disableOptions or {
        car = true,
        move = true,
        combat = true
    }
    
    -- Setup animation if provided
    local animOptions = nil
    if dict and anim then
        animOptions = {
            dict = dict,
            clip = anim
        }
    end
    
    -- Execute the progress bar
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = false,
        disable = disableOptions,
        anim = animOptions
    })
end

-- Calculate distance between two coordinates
function Utils.Distance(coords1, coords2)
    if not coords1 or not coords2 then return 999999.0 end
    
    return #(vector3(coords1.x, coords1.y, coords1.z) - vector3(coords2.x, coords2.y, coords2.z))
end

-- Get a random element from a table
function Utils.GetRandomElement(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

-- Check if a value exists in a table
function Utils.TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Create a random offset coordinate
function Utils.GetRandomOffsetCoords(originalCoords, minOffset, maxOffset)
    local angle = math.random() * 2 * math.pi
    local distance = minOffset + math.random() * (maxOffset - minOffset)
    local offsetX = math.cos(angle) * distance
    local offsetY = math.sin(angle) * distance
    
    return vector3(
        originalCoords.x + offsetX, 
        originalCoords.y + offsetY, 
        originalCoords.z
    )
end

-- Generate a random unique ID
function Utils.GenerateUniqueID(prefix)
    prefix = prefix or ""
    local timestamp = os.time()
    local random = math.random(1000, 9999)
    
    return string.format("%s%d%d", prefix, timestamp, random)
end

-- Convert seconds to formatted time string (MM:SS)
function Utils.FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    
    return string.format("%02d:%02d", minutes, remainingSeconds)
end

-- Get vehicle health as percentage
function Utils.GetVehicleHealthPercentage(vehicle)
    if not DoesEntityExist(vehicle) then return 0.0 end
    
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    
    -- Calculate average health
    local healthPercentage = (bodyHealth + engineHealth) / 2000.0
    
    -- Ensure it's between 0 and 1
    return math.min(1.0, math.max(0.0, healthPercentage))
end

return Utils