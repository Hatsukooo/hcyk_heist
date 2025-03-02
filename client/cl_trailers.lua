-- Alternative Container Highlighting Script
-- Designed to work across different FiveM environments

local Config = {
    -- Containers that can be robbed
    RobbableContainers = {
        'prop_container_01a',
        'prop_container_01b',
        'prop_truktrailer_01a',
        'prop_container_side'
    },
    
    -- Highlighting Configuration
    Highlighting = {
        MaxDistance = 10.0,     -- Max distance to detect containers
        HighlightRadius = 2.5   -- Radius for interaction
    }
}

-- Debugging function
local function DebugPrint(message)
    print("^3[CONTAINER_HIGHLIGHT]^7 " .. message)
end

-- Visual Highlighting using Markers
local CurrentHighlightedContainer = nil

-- Stop highlighting
local function StopContainerHighlight()
    CurrentHighlightedContainer = nil
end

-- Enhanced Container Detection
local function FindNearestRobbableContainer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestContainer = nil
    local closestDistance = Config.Highlighting.MaxDistance

    -- Check each possible container model
    for _, model in ipairs(Config.RobbableContainers) do
        local container = GetClosestObjectOfType(
            playerCoords, 
            Config.Highlighting.MaxDistance, 
            GetHashKey(model), 
            false, 
            false, 
            false
        )
        
        if container ~= 0 then
            local distance = #(GetEntityCoords(container) - playerCoords)
            if distance < closestDistance then
                closestContainer = container
                closestDistance = distance
            end
        end
    end
    
    return closestContainer, closestDistance
end

-- Continuous Highlighting Loop
Citizen.CreateThread(function()
    while true do
        local container, distance = FindNearestRobbableContainer()
        
        -- Handle visual indication
        if container and distance <= Config.Highlighting.MaxDistance then
            -- Store current highlighted container
            CurrentHighlightedContainer = container
            
            -- Draw marker around container
            local containerCoords = GetEntityCoords(container)
            DrawMarker(
                1,  -- Marker type (cylinder)
                containerCoords.x, containerCoords.y, containerCoords.z - 1.0,  -- Position (slightly lowered)
                0.0, 0.0, 0.0,  -- Direction
                0.0, 0.0, 0.0,  -- Rotation
                2.5, 2.5, 1.0,  -- Scale
                255, 165, 0, 100,  -- Color (Orange with transparency)
                false,  -- Bob up and down
                false,  -- Face camera
                2,      -- Temporary draw mode
                false,  -- Rotate
                nil,    -- Texture name
                nil,    -- Texture dictionary
                false   -- Should draw on entities
            )
        else
            -- No container nearby
            StopContainerHighlight()
        end
        
        -- Performance optimization
        Citizen.Wait(0)
    end
end)

-- Ox Target Setup for Robbable Containers
Citizen.CreateThread(function()
    -- Wait for ox_target to load
    while not exports.ox_target do
        Citizen.Wait(100)
    end
    
    -- Add target option for containers
    exports.ox_target:addModel(Config.RobbableContainers, {
        {
            label = 'Prohledat kontejner',
            icon = 'fa-solid fa-search',
            onSelect = function(data)
                -- Open container and potentially spawn loot
                TriggerEvent('container:rob', data.entity)
            end,
            distance = 2.5
        }
    })
end)

-- Event for container robbery
RegisterNetEvent('container:rob', function(container)
    -- Validate container
    local playerPed = PlayerPedId()
    
    -- Check if container is valid
    local isValid = false
    for _, model in ipairs(Config.RobbableContainers) do
        if GetEntityModel(container) == GetHashKey(model) then
            isValid = true
            break
        end
    end
    
    if not isValid then
        exports.ox_lib:notify({
            title = 'Chyba',
            description = 'Tento kontejner nelze prohledat.',
            type = 'error'
        })
        return
    end
    
    -- Freeze player during search
    FreezeEntityPosition(playerPed, true)
    
    -- Search animation
    RequestAnimDict('anim@heists@box_carry@')
    while not HasAnimDictLoaded('anim@heists@box_carry@') do
        Citizen.Wait(10)
    end
    
    -- Play search animation
    TaskPlayAnim(
        playerPed, 
        'anim@heists@box_carry@', 
        'idle', 
        8.0, -8.0, 
        3000, 
        1, 0, 
        false, false, false
    )
    
    -- Wait and unfreeze
    Citizen.Wait(3000)
    FreezeEntityPosition(playerPed, false)
    
    -- Notify of search completion
    exports.ox_lib:notify({
        title = 'Kontejner prohledán',
        description = 'Nalezeno několik předmětů.',
        type = 'success'
    })
end)

-- Debug command
RegisterCommand('highlightcontainers', function()
    DebugPrint("Container highlighting active. Scanning for nearby containers...")
    local container, distance = FindNearestRobbableContainer()
    if container then
        DebugPrint(string.format("Nearest container found at distance: %.2f", distance))
    else
        DebugPrint("No containers found nearby.")
    end
end)