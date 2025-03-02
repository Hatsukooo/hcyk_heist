local ModuleSystem = {}

local initialized = false

local moduleList = {
    { 
        name = "HeistConfig", 
        path = "modules/config.lua", 
        global = true 
    },
    { 
        name = "ErrorHandler", 
        path = "modules/error_handler.lua", 
        global = true 
    },
    {
        name = "Utils",
        path = "modules/utils.lua",
        global = false,
        isShared = true
    },
    {
        name = "ClientUtils",
        path = "modules/client/utils.lua",
        global = false,
        isClient = true
    },
    {
        name = "ServerUtils",
        path = "modules/server/utils.lua",
        global = false,
        isServer = true
    },
    {
        name = "PerformanceManager",
        path = "modules/client/performance.lua",
        global = true,
        isClient = true
    },
    {
        name = "FeedbackSystem",
        path = "modules/client/feedback.lua",
        global = true,
        isClient = true
    },
    {
        name = "SecuritySystem",
        path = "modules/server/security.lua",
        global = false,
        isServer = true
    }
}

local modules = {}

function ModuleSystem.Initialize()
    if initialized then return true end
    
    print("^3[MODULE SYSTEM] Initializing modules...^7")
    
    local success = true
    
    -- First load the Utils module since other modules depend on it
    for _, moduleInfo in ipairs(moduleList) do
        if moduleInfo.name == "Utils" or moduleInfo.name == "HeistConfig" or moduleInfo.name == "ErrorHandler" then
            if (moduleInfo.isServer and not IsDuplicityVersion()) or 
               (moduleInfo.isClient and IsDuplicityVersion()) then
                goto continue
            end
            
            local status, result = pcall(function()
                local moduleContent = LoadResourceFile(GetCurrentResourceName(), moduleInfo.path)
                if not moduleContent then
                    print(string.format("^1[MODULE SYSTEM] Failed to load module %s: File not found at %s^7", 
                        moduleInfo.name, moduleInfo.path))
                    return false
                end
                
                local moduleFunc, err = load(moduleContent)
                if not moduleFunc then
                    print(string.format("^1[MODULE SYSTEM] Failed to parse module %s: %s^7", 
                        moduleInfo.name, err))
                    return false
                end
                
                local moduleObj = moduleFunc()
                if not moduleObj then
                    print(string.format("^1[MODULE SYSTEM] Module %s did not return anything^7", 
                        moduleInfo.name))
                    return false
                end
                
                modules[moduleInfo.name] = moduleObj
                
                if moduleInfo.global then
                    _G[moduleInfo.name] = moduleObj
                end
                
                print(string.format("^2[MODULE SYSTEM] Loaded module: %s^7", moduleInfo.name))
                return true
            end)
            
            if not status or not result then
                success = false
                print(string.format("^1[MODULE SYSTEM] Error loading module %s: %s^7", 
                    moduleInfo.name, tostring(result)))
            end
            
            ::continue::
        end
    end
    
    -- Then load the remaining modules
    for _, moduleInfo in ipairs(moduleList) do
        if moduleInfo.name ~= "Utils" and moduleInfo.name ~= "HeistConfig" and moduleInfo.name ~= "ErrorHandler" then
            if (moduleInfo.isServer and not IsDuplicityVersion()) or 
               (moduleInfo.isClient and IsDuplicityVersion()) then
                goto continue
            end
            
            local status, result = pcall(function()
                local moduleContent = LoadResourceFile(GetCurrentResourceName(), moduleInfo.path)
                if not moduleContent then
                    print(string.format("^1[MODULE SYSTEM] Failed to load module %s: File not found at %s^7", 
                        moduleInfo.name, moduleInfo.path))
                    return false
                end
                
                local moduleFunc, err = load(moduleContent)
                if not moduleFunc then
                    print(string.format("^1[MODULE SYSTEM] Failed to parse module %s: %s^7", 
                        moduleInfo.name, err))
                    return false
                end
                
                local moduleObj = moduleFunc()
                if not moduleObj then
                    print(string.format("^1[MODULE SYSTEM] Module %s did not return anything^7", 
                        moduleInfo.name))
                    return false
                end
                
                modules[moduleInfo.name] = moduleObj
                
                if moduleInfo.global then
                    _G[moduleInfo.name] = moduleObj
                end
                
                print(string.format("^2[MODULE SYSTEM] Loaded module: %s^7", moduleInfo.name))
                return true
            end)
            
            if not status or not result then
                success = false
                print(string.format("^1[MODULE SYSTEM] Error loading module %s: %s^7", 
                    moduleInfo.name, tostring(result)))
            end
            
            ::continue::
        end
    end
    
    initialized = success
    print(string.format("^3[MODULE SYSTEM] Initialization %s^7", 
        success and "^2completed successfully" or "^1failed"))
    
    return success
end

function ModuleSystem.GetModule(name)
    if not initialized then
        ModuleSystem.Initialize()
    end
    
    return modules[name]
end

-- Export the Utils module first as it's a dependency
exports('GetSharedUtils', function()
    if not initialized then
        ModuleSystem.Initialize()
    end
    return modules["Utils"]
end)

-- Setup remaining exports after Utils is available
for _, moduleInfo in ipairs(moduleList) do
    if (moduleInfo.isServer and not IsDuplicityVersion()) or 
       (moduleInfo.isClient and IsDuplicityVersion()) then
        goto continue
    end
    
    -- Skip Utils as it's already exported
    if moduleInfo.name == "Utils" then
        goto continue
    end
    
    local exportName = "Get" .. moduleInfo.name
    exports(exportName, function()
        if not initialized then
            ModuleSystem.Initialize()
        end
        return modules[moduleInfo.name]
    end)
    
    ::continue::
end

Citizen.CreateThread(function()
    ModuleSystem.Initialize()
end)

return ModuleSystem