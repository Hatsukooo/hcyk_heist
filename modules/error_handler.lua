-- modules/error_handler.lua
-- Centralized error handling system

ErrorHandler = {}

-- Debug flag (should align with HeistConfig.Debug)
local debugMode = true

-- Error codes for better tracking
ErrorHandler.Codes = {
    -- Resource related (1-99)
    RESOURCE_NOT_LOADED = 1,
    EXPORT_NOT_FOUND = 2,
    DEPENDENCY_MISSING = 3,
    
    -- Player related (100-199) 
    PLAYER_NOT_FOUND = 101,
    INVALID_PLAYER_STATE = 102,
    
    -- Entity related (200-299)
    ENTITY_CREATION_FAILED = 201,
    ENTITY_NOT_FOUND = 202,
    
    -- Animation related (300-399)
    ANIM_DICT_LOAD_FAILED = 301,
    
    -- Network related (400-499)
    NETWORK_ERROR = 401,
    EVENT_TIMEOUT = 402,
    
    -- Heist specific (500-599)
    HEIST_INVALID_STATE = 501,
    HEIST_COOLDOWN_ACTIVE = 502,
    HEIST_REQUIREMENTS_NOT_MET = 503,
    
    -- Permission related (600-699)
    INSUFFICIENT_PERMISSIONS = 601,
    
    -- Unknown errors (900-999)
    UNKNOWN_ERROR = 999
}

-- Prepare error message and handle it
function ErrorHandler.HandleError(source, code, message, critical, data)
    local errorInfo = {
        source = source or "unknown",
        code = code or ErrorHandler.Codes.UNKNOWN_ERROR,
        message = message or "Unknown error occurred",
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        critical = critical or false,
        data = data or {}
    }
    
    -- Log error
    ErrorHandler.LogError(errorInfo)
    
    -- For critical errors, send notification to players/admins if appropriate
    if critical and IsDuplicityVersion() then -- Server-side
        ErrorHandler.NotifyCriticalError(errorInfo)
    end
    
    return errorInfo
end

-- Log the error
function ErrorHandler.LogError(errorInfo)
    -- Format error for console
    local errorString = string.format(
        "[ERROR] [%s] Code: %d | %s | Critical: %s",
        errorInfo.source,
        errorInfo.code,
        errorInfo.message,
        errorInfo.critical and "YES" or "NO"
    )
    
    -- Print to console
    print("^1" .. errorString .. "^7")
    
    -- Log additional data if in debug mode
    if debugMode and errorInfo.data then
        print("^3[ERROR DATA]^7")
        for k, v in pairs(errorInfo.data) do
            if type(v) ~= "function" then
                print("  " .. k .. ": " .. tostring(v))
            end
        end
    end
    
    -- Log to Discord if server-side
    if IsDuplicityVersion() and HeistConfig and HeistConfig.Discord and HeistConfig.Discord.Enabled then
        local errorData = ""
        if errorInfo.data then
            for k, v in pairs(errorInfo.data) do
                if type(v) ~= "function" then
                    errorData = errorData .. string.format("**%s:** %s\n", k, tostring(v))
                end
            end
        end
        
        local embed = {
            {
                ["title"] = '**[ERROR]** ' .. errorInfo.source,
                ["description"] = string.format("**Code:** %d\n**Message:** %s\n**Critical:** %s\n**Time:** %s\n\n**Additional Data:**\n%s",
                    errorInfo.code,
                    errorInfo.message,
                    errorInfo.critical and "YES" or "NO",
                    errorInfo.timestamp,
                    errorData ~= "" and errorData or "None"
                ),
                ["type"] = "rich",
                ["color"] = HeistConfig.Discord.Colors.Error,
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }

        PerformHttpRequest(HeistConfig.Discord.Webhook, function(err, text, headers) end, 'POST', 
            json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

-- Notify admins about critical errors
function ErrorHandler.NotifyCriticalError(errorInfo)
    if not IsDuplicityVersion() then return end -- Server-side only
    
    -- Notify all admins in game
    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer and xPlayer.getGroup() == 'admin' then
            TriggerClientEvent('chat:addMessage', xPlayer.source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"SYSTEM", string.format("Critical error in %s: %s (Code: %d)", 
                    errorInfo.source, errorInfo.message, errorInfo.code)}
            })
        end
    end
end

-- Safe execution wrapper for functions
function ErrorHandler.SafeExecute(source, func, ...)
    local status, result = pcall(func, ...)
    
    if not status then
        return ErrorHandler.HandleError(
            source, 
            ErrorHandler.Codes.UNKNOWN_ERROR, 
            "Error during execution: " .. tostring(result), 
            false,
            {traceback = debug.traceback()}
        )
    end
    
    return result
end

-- Safe event handler registration
function ErrorHandler.SafeEventHandler(eventName, handler)
    local wrappedHandler = function(...)
        local status, error = pcall(handler, ...)
        
        if not status then
            ErrorHandler.HandleError(
                eventName, 
                ErrorHandler.Codes.UNKNOWN_ERROR, 
                "Error in event handler: " .. tostring(error), 
                true,
                {
                    traceback = debug.traceback(),
                    args = {...}
                }
            )
        end
    end
    
    -- Register the wrapped handler
    AddEventHandler(eventName, wrappedHandler)
    
    return wrappedHandler
end

-- Safe resource dependency check
function ErrorHandler.CheckDependency(resourceName, exportName)
    if not GetResourceState(resourceName) == 'started' then
        ErrorHandler.HandleError(
            "dependency_check", 
            ErrorHandler.Codes.DEPENDENCY_MISSING, 
            "Required resource not started: " .. resourceName, 
            true
        )
        return false
    end
    
    if exportName then
        local success = pcall(function() return exports[resourceName][exportName] end)
        if not success then
            ErrorHandler.HandleError(
                "dependency_check", 
                ErrorHandler.Codes.EXPORT_NOT_FOUND, 
                "Required export not found: " .. resourceName .. "." .. exportName, 
                true
            )
            return false
        end
    end
    
    return true
end

-- Safe animation dictionary loading with timeout
function ErrorHandler.RequestAnimDict(dict, timeout)
    timeout = timeout or 1000
    if not dict or dict == '' then
        return ErrorHandler.HandleError(
            "anim_dict", 
            ErrorHandler.Codes.ANIM_DICT_LOAD_FAILED, 
            "Empty animation dictionary name", 
            false
        )
    end
    
    if HasAnimDictLoaded(dict) then
        return true
    end
    
    RequestAnimDict(dict)
    
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - startTime > timeout then
            return ErrorHandler.HandleError(
                "anim_dict", 
                ErrorHandler.Codes.ANIM_DICT_LOAD_FAILED, 
                "Timed out loading animation dictionary: " .. dict, 
                false
            )
        end
        Citizen.Wait(10)
    end
    
    return true
end

-- Safe model loading with timeout
function ErrorHandler.RequestModel(model, timeout)
    timeout = timeout or 1000
    
    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    
    if not modelHash or modelHash == 0 then
        return ErrorHandler.HandleError(
            "model_load", 
            ErrorHandler.Codes.ENTITY_CREATION_FAILED, 
            "Invalid model hash: " .. tostring(model), 
            false
        )
    end
    
    if HasModelLoaded(modelHash) then
        return true
    end
    
    RequestModel(modelHash)
    
    local startTime = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() - startTime > timeout then
            return ErrorHandler.HandleError(
                "model_load", 
                ErrorHandler.Codes.ENTITY_CREATION_FAILED, 
                "Timed out loading model: " .. tostring(model), 
                false
            )
        end
        Citizen.Wait(10)
    end
    
    return true
end

-- Initialize error handling system
function ErrorHandler.Initialize()
    -- Set debug mode from config if available
    if HeistConfig then
        debugMode = HeistConfig.Debug
    end
    
    -- Register for unhandled errors
    AddEventHandler('onResourceError', function(resourceName, error)
        if GetCurrentResourceName() == resourceName then
            ErrorHandler.HandleError(
                "resource_error", 
                ErrorHandler.Codes.UNKNOWN_ERROR, 
                "Unhandled error: " .. tostring(error), 
                true
            )
        end
    end)
    
    print("^2Error handling system initialized^7")
end

-- Initialize the error handling system
ErrorHandler.Initialize()

return ErrorHandler