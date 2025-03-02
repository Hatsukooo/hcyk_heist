local SecuritySystem = {}

-- Get the shared utils
local SharedUtils = exports[GetCurrentResourceName()]:GetSharedUtils()

-- Configuration
local securityConfig = {
    -- Anti-exploit settings
    maxDistanceValidation = 100.0,  -- Max distance for position validation
    maxRateLimit = {               -- Rate limiting for key events
        defaultLimit = 3,           -- Default number of calls allowed in the timeout period
        defaultTimeout = 5000,      -- Default timeout in ms
        events = {
            -- Define event-specific limits here
            ["hcyk_heists:trailers:giveLoot"] = { limit = 1, timeout = 10000 },
            ["hcyk_heists:vangelico:giveitem"] = { limit = 5, timeout = 5000 }
        }
    },
    logging = {
        enabled = true,
        discord = true,
        console = true
    },
    -- Action to take when detecting potential cheats
    actions = {
        ban = true,           -- Ban players for severe violations
        kick = true,          -- Kick for moderate violations 
        warn = true           -- Just warn for minor violations
    }
}

-- State
local rateLimits = {}  -- Track rate limiting by player
local suspiciousActivity = {} -- Track suspicious activity by player

-- Helper function to log security events
local function logSecurityEvent(playerId, type, details)
    local playerName = GetPlayerName(playerId) or "Unknown"
    local playerIdentifier = nil
    
    -- Get player identifier if available
    if ESX and ESX.GetPlayerFromId then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            playerIdentifier = xPlayer.getIdentifier()
        end
    end
    
    -- Format message
    local message = string.format("[SECURITY] Player %s (%s) - %s: %s", 
        playerName, playerId, type, details or "No details")
    
    -- Console logging
    if securityConfig.logging.console then
        print(message)
    end
    
    -- Discord logging
    if securityConfig.logging.discord and HeistConfig.Discord and HeistConfig.Discord.Enabled then
        local embed = {
            {
                ["title"] = string.format('**[SECURITY]** %s Alert', type),
                ["description"] = string.format("**Player:** %s (ID: %s)\n**Identifier:** %s\n**Details:** %s",
                    playerName, playerId, playerIdentifier or "Not available", details or "No details"),
                ["type"] = "rich",
                ["color"] = HeistConfig.Discord.Colors.Error,
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }

        PerformHttpRequest(HeistConfig.Discord.Webhook, function(err, text, headers) end, 'POST', 
            json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

-- Apply penalties for violations
local function applyPenalty(playerId, violation, severity)
    local playerName = GetPlayerName(playerId) or "Unknown"
    severity = severity or "moderate" -- mild, moderate, severe
    
    -- Record in suspicious activity
    if not suspiciousActivity[playerId] then
        suspiciousActivity[playerId] = {
            count = 0,
            violations = {}
        }
    end
    
    -- Increment count and log violation
    suspiciousActivity[playerId].count = suspiciousActivity[playerId].count + 1
    table.insert(suspiciousActivity[playerId].violations, {
        time = os.time(),
        violation = violation,
        severity = severity
    })
    
    -- Apply penalty based on severity
    if severity == "severe" and securityConfig.actions.ban then
        -- Ban player
        if exports["rx_utils"] and exports["rx_utils"].fg_BanPlayer then
            exports["rx_utils"]:fg_BanPlayer(playerId, "Anti-cheat: " .. violation, true)
            logSecurityEvent(playerId, "BANNED", violation)
        else
            -- Fallback to kick if ban function is not available
            DropPlayer(playerId, "Security System: You have been removed from the server due to suspicious activity.")
            logSecurityEvent(playerId, "KICKED (No Ban Function)", violation)
        end
    elseif severity == "moderate" and securityConfig.actions.kick then
        -- Kick player
        DropPlayer(playerId, "Security System: Suspicious activity detected. Please contact the server administrator.")
        logSecurityEvent(playerId, "KICKED", violation)
    elseif securityConfig.actions.warn then
        -- Just log a warning
        logSecurityEvent(playerId, "WARNING", violation)
        
        -- Send warning to admins
        local xPlayers = ESX.GetPlayers()
        for i=1, #xPlayers, 1 do
            local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
            if xPlayer and xPlayer.getGroup() == 'admin' then
                TriggerClientEvent('chat:addMessage', xPlayer.source, {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {"SECURITY", string.format("Player %s suspected of %s", playerName, violation)}
                })
            end
        end
    end
end

-- Check rate limiting
local function checkRateLimit(playerId, eventName)
    if not rateLimits[playerId] then
        rateLimits[playerId] = {}
    end
    
    if not rateLimits[playerId][eventName] then
        rateLimits[playerId][eventName] = {
            count = 1,
            lastReset = GetGameTimer()
        }
        return true
    end
    
    -- Get limit configuration
    local limit = securityConfig.maxRateLimit.defaultLimit
    local timeout = securityConfig.maxRateLimit.defaultTimeout
    
    if securityConfig.maxRateLimit.events[eventName] then
        limit = securityConfig.maxRateLimit.events[eventName].limit
        timeout = securityConfig.maxRateLimit.events[eventName].timeout
    end
    
    -- Check if timeout has passed
    local currentTime = GetGameTimer()
    if currentTime - rateLimits[playerId][eventName].lastReset > timeout then
        -- Reset counter
        rateLimits[playerId][eventName] = {
            count = 1,
            lastReset = currentTime
        }
        return true
    end
    
    -- Increment counter
    rateLimits[playerId][eventName].count = rateLimits[playerId][eventName].count + 1
    
    -- Check if limit exceeded
    if rateLimits[playerId][eventName].count > limit then
        -- Log and apply penalty
        applyPenalty(playerId, "Rate limit exceeded for event: " .. eventName, "moderate")
        return false
    end
    
    return true
end

-- Verify player position against expected coordinates
function SecuritySystem.VerifyPosition(playerId, expectedCoords, maxDistance)
    if not playerId then return false end
    
    -- If no expected coords were provided, just return true
    if not expectedCoords then return true end
    
    maxDistance = maxDistance or securityConfig.maxDistanceValidation
    
    local playerPed = GetPlayerPed(playerId)
    if not playerPed then return false end
    
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(expectedCoords.x, expectedCoords.y, expectedCoords.z))
    
    if distance > maxDistance then
        applyPenalty(playerId, string.format("Position validation failed. Distance: %.2f (max: %.2f)", 
            distance, maxDistance), "moderate")
        return false
    end
    
    return true
end

-- Verify player state (for example, if they should be in a certain state to use an event)
function SecuritySystem.VerifyState(playerId, states)
    if not playerId or not states then return true end
    
    -- Convert single state to table if needed
    if type(states) ~= "table" then
        states = {states}
    end
    
    -- States should be a table of key-value pairs or event-state pairs
    -- Example: {isRobbing = true, hasWeapon = true}
    local allValid = true
    local failedChecks = ""
    
    -- Iterate through each state check
    for stateKey, expectedValue in pairs(states) do
        -- Handle special cases for common checks
        if stateKey == "isInVehicle" then
            local isInVehicle = IsPedInAnyVehicle(GetPlayerPed(playerId), false)
            if isInVehicle ~= expectedValue then
                allValid = false
                failedChecks = failedChecks .. "isInVehicle, "
            end
        elseif stateKey == "isAlive" then
            local isAlive = not IsPlayerDead(playerId)
            if isAlive ~= expectedValue then
                allValid = false
                failedChecks = failedChecks .. "isAlive, "
            end
        else
            -- For custom states, we would need a state manager
            -- This is a placeholder - in a real implementation you would check against your state tracking
        end
    end
    
    if not allValid then
        applyPenalty(playerId, "State validation failed. Failed checks: " .. failedChecks, "moderate")
    end
    
    return allValid
end

-- Register a secure event handler with validation
function SecuritySystem.SecureEventHandler(eventName, handlerFn, options)
    options = options or {}
    
    -- Register the event
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function(...)
        local playerId = source
        
        -- Rate limit check
        if not checkRateLimit(playerId, eventName) then
            return
        end
        
        -- Position verification if needed
        if options.verifyPosition then
            if options.expectedPosition then
                if not SecuritySystem.VerifyPosition(playerId, options.expectedPosition, options.maxDistance) then
                    return
                end
            else
                -- If no specific position is expected but verification is enabled,
                -- we can optionally log the current position
                local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
                logSecurityEvent(playerId, "POSITION", string.format("Event: %s, Position: %.2f, %.2f, %.2f", 
                    eventName, playerCoords.x, playerCoords.y, playerCoords.z))
            end
        end
        
        -- State verification if needed
        if options.states and not SecuritySystem.VerifyState(playerId, options.states) then
            return
        end
        
        -- If all checks pass, call the handler
        handlerFn(playerId, ...)
    end)
end

-- Register multiple secure callbacks
function SecuritySystem.RegisterSecureCallbacks(callbacks)
    for name, callback in pairs(callbacks) do
        ESX.RegisterServerCallback(name, function(source, cb, ...)
            local playerId = source
            
            -- Rate limit check
            if not checkRateLimit(playerId, name) then
                cb(false)
                return
            end
            
            -- Additional checks can be added here
            
            -- Call the actual callback with the player ID
            callback(playerId, cb, ...)
        end)
    end
end

-- Initialize the security system
function SecuritySystem.Initialize()
    -- Clear state
    rateLimits = {}
    suspiciousActivity = {}
    
    -- Register cleanup for player disconnection
    AddEventHandler('playerDropped', function(reason)
        local playerId = source
        
        -- Clean up player state
        rateLimits[playerId] = nil
        suspiciousActivity[playerId] = nil
    end)
    
    print("^2Security system initialized^7")
end

-- Call initialization
SecuritySystem.Initialize()

return SecuritySystem