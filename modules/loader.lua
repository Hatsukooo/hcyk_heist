local resourceName = GetCurrentResourceName()

-- Load shared utilities
local SharedUtils = nil

-- Get the shared utils
local function LoadSharedUtils()
    if not SharedUtils then
        SharedUtils = LoadResourceFile(resourceName, "modules/utils.lua")
        if SharedUtils then
            SharedUtils = load(SharedUtils)()
        else
            print("^1ERROR: Failed to load shared utilities^7")
            SharedUtils = {}
        end
    end
    return SharedUtils
end

-- Register exports to access utilities from other files
if IsDuplicityVersion() then
    -- Server-side exports
    exports('GetSharedUtils', LoadSharedUtils)
else
    -- Client-side exports
    exports('GetSharedUtils', LoadSharedUtils)
end