-- client/cl_trailers.lua
local ESX = exports['es_extended']:getSharedObject()

-- Import our new modules
local ErrorHandler = _G.ErrorHandler
local PerformanceManager = _G.PerformanceManager
local FeedbackSystem = _G.FeedbackSystem
local HeistConfig = _G.HeistConfig

-- State management
local PlayerData = {}
local heistState = {
    isActive = false,
    cooldown = false,
    isBusy = false,
    robbedContainers = {},
    lastRobbery = 0
}

-- Debug logging
local function debugLog(message, ...)
    if HeistConfig.Debug then
        ErrorHandler.HandleError("trailers_debug", ErrorHandler.Codes.UNKNOWN_ERROR, 
            string.format(message, ...), false)
    end
end

-- Initialize player data
Citizen.CreateThread(function()
    ErrorHandler.SafeExecute("trailers_init", function()
        while ESX.GetPlayerData().job == nil do
            Citizen.Wait(100)
        end
        
        PlayerData = ESX.GetPlayerData()
        debugLog("Player data initialized")
    end)
end)

-- Handle job changes
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ErrorHandler.SafeExecute("trailers_job_change", function()
        PlayerData.job = job
        debugLog("Player job updated: " .. job.name)
    end)
end)

-- Current highlighted container
local CurrentHighlightedContainer = nil

-- Stop highlighting
local function StopContainerHighlight()
    CurrentHighlightedContainer = nil
end

-- Check if container was already robbed
local function IsContainerRobbed(container)
    if not container then return true end
    
    local containerNetId = NetworkGetNetworkIdFromEntity(container)
    return heistState.robbedContainers[containerNetId] ~= nil
end

-- Enhanced Container Detection using PerformanceManager
local function FindNearestRobbableContainer()
    ErrorHandler.SafeExecute("trailers_find_container", function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Convert container models to hashes
        local modelHashes = {}
        for _, model in ipairs(HeistConfig.Trailers.ContainerModels) do
            table.insert(modelHashes, GetHashKey(model))
        end
        
        -- Use performance optimized entity detection
        local entity, distance = PerformanceManager.FindNearestEntity(
            playerCoords, 
            modelHashes, 
            HeistConfig.Trailers.MaxDistance
        )
        
        return entity, distance
    end)
end

-- Continuous Highlighting Loop with performance optimization
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local container, distance = FindNearestRobbableContainer()
        
        if container and distance <= HeistConfig.Trailers.MaxDistance and not IsContainerRobbed(container) then
            -- Store current highlighted container
            CurrentHighlightedContainer = container
            
            -- Only draw marker when player is close enough
            if PerformanceManager.ShouldDrawMarker(playerCoords) then
                local containerCoords = GetEntityCoords(container)
                
                -- Use optimized marker rendering
                PerformanceManager.AddMarkerToRender(
                    1,  -- Marker type (cylinder)
                    vector3(containerCoords.x, containerCoords.y, containerCoords.z - 1.0),
                    vector3(0.0, 0.0, 0.0),  -- Direction
                    vector3(0.0, 0.0, 0.0),  -- Rotation
                    vector3(2.5, 2.5, 1.0),  -- Scale
                    {r = 255, g = 165, b = 0, a = 100},  -- Color (Orange with transparency)
                    false,  -- Bob up and down
                    false,  -- Face camera
                    false   -- Draw on entities
                )
            end
            
            -- Optimize entity LOD based on distance
            PerformanceManager.OptimizeEntityDrawDistance(container, distance)
            
            -- Use dynamic wait times based on distance for performance
            local waitTime = PerformanceManager.GetWaitTimeForDistance(distance * distance)
            Citizen.Wait(waitTime)
        else
            -- No container nearby
            StopContainerHighlight()
            
            -- Wait longer when no container is nearby
            Citizen.Wait(500)
        end
    end
end)

-- Ox Target Setup for Robbable Containers
Citizen.CreateThread(function()
    ErrorHandler.SafeExecute("trailers_setup_target", function()
        -- Wait for ox_target to load
        if not ErrorHandler.CheckDependency("ox_target") then
            return
        end
        
        -- Add target option for containers
        exports.ox_target:addModel(HeistConfig.Trailers.ContainerModels, {
            {
                label = 'Prohledat kontejner',
                icon = 'fa-solid fa-search',
                onSelect = function(data)
                    StartContainerRobbery(data.entity)
                end,
                canInteract = function(entity)
                    -- Only allow interaction if container hasn't been robbed already
                    return not IsContainerRobbed(entity) and not heistState.isBusy and not heistState.cooldown
                end,
                distance = 2.5
            }
        })
        
        debugLog("Target options added to containers")
    end)
end)

-- Start container robbery
function StartContainerRobbery(container)
    ErrorHandler.SafeExecute("trailers_start_robbery", function()
        -- Check if player is busy
        if heistState.isBusy then
            FeedbackSystem.ShowFailure('Už něco děláš!')
            return
        end
        
        -- Check cooldown
        if heistState.cooldown then
            FeedbackSystem.ShowFailure('Nedávno jsi něco vykradl, počkej chvíli!')
            return
        end
        
        -- Check if container was already robbed
        if IsContainerRobbed(container) then
            FeedbackSystem.ShowFailure('Tento kontejner byl již vyloupen!')
            return
        }
        
        -- Check for required tool
        ESX.TriggerServerCallback('hcyk_heists:trailers:hasItem', function(hasItem)
            if not hasItem then
                FeedbackSystem.ShowFailure('Nemáš páčidlo na otevření kontejneru!')
                return
            end
            
            -- Check police count
            ESX.TriggerServerCallback('hcyk_heists:trailers:pdcount', function(policeCount)
                if policeCount >= HeistConfig.Trailers.RequiredCops then
                    -- Start the robbery
                    heistState.isBusy = true
                    
                    -- Get container position for effects
                    local containerCoords = GetEntityCoords(container)
                    
                    -- Play unlock animation with feedback
                    FeedbackSystem.PlaySound("Lock")
                    
                    -- Start progress bar with animation
                    lib.progressBar({
                        duration = 5000,
                        label = 'Odemykáš kontejner',
                        useWhileDead = false,
                        canCancel = false,
                        disable = {
                            car = true,
                            move = true,
                            combat = true
                        },
                        anim = {
                            dict = 'anim@heists@box_carry@',
                            clip = 'idle'
                        }
                    })
                    
                    -- Start the minigame
                    exports["memorygame"]:thermiteminigame(
                        HeistConfig.Trailers.MinigameTime, 
                        HeistConfig.Trailers.MinigameDifficulty, 
                        3, 10, 
                        function() -- Success callback
                            -- Mark container as robbed locally
                            local containerNetId = NetworkGetNetworkIdFromEntity(container)
                            heistState.robbedContainers[containerNetId] = true
                            
                            -- Register with server
                            TriggerServerEvent('hcyk_heists:trailers:registerContainer', containerNetId)
                            
                            -- Start robbing container
                            CompleteContainerRobbery(container)
                            
                            -- Play success sound and effect
                            FeedbackSystem.PlayParticleEffect("Success", containerCoords)
                            FeedbackSystem.ShowUnlock('Kontejner otevřen!', containerCoords)
                            
                            -- Notify police after successful minigame
                            TriggerServerEvent('hcyk_heists:trailers:notifyPolice', containerCoords)
                        end,
                        function() -- Failure callback
                            heistState.isBusy = false
                            
                            -- Show failure feedback
                            FeedbackSystem.ShowFailure('Nepodařilo se otevřít kontejner!', containerCoords)
                        end
                    )
                else
                    FeedbackSystem.ShowFailure('Nedostatek policistů ve městě!')
                end
            end)
        end, HeistConfig.Trailers.RequiredTool)
    end)
end

-- Complete container robbery after successful minigame
function CompleteContainerRobbery(container)
    ErrorHandler.SafeExecute("trailers_complete_robbery", function()
        -- Set busy state
        heistState.isBusy = true
        
        -- Get container position for effects
        local containerCoords = GetEntityCoords(container)
        
        -- Start search animation
        lib.progressBar({
            duration = 8000,
            label = 'Prohledáváš kontejner',
            useWhileDead = false,
            canCancel = false,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'anim@heists@ornate_bank@grab_cash',
                clip = 'grab'
            }
        })
        
        -- Request loot from server
        TriggerServerEvent('hcyk_heists:trailers:giveLoot')
        
        -- Set cooldown
        heistState.cooldown = true
        heistState.isBusy = false
        
        -- Reset cooldown after delay
        Citizen.SetTimeout(300000, function() -- 5 minute personal cooldown
            heistState.cooldown = false
            debugLog("Cooldown ended, can rob again")
        end)
    end)
end

-- Register event for successful robbery completion
RegisterNetEvent('hcyk_heists:trailers:robberyComplete')
AddEventHandler('hcyk_heists:trailers:robberyComplete', function()
    ErrorHandler.SafeExecute("trailers_robbery_complete", function()
        -- Show success feedback with loot animation
        FeedbackSystem.ShowLoot('Nalezl jsi nějaké předměty!')
    end)
end)

-- Register event for client-server sync of robbed containers
RegisterNetEvent('hcyk_heists:trailers:syncRobbedContainers')
AddEventHandler('hcyk_heists:trailers:syncRobbedContainers', function(containers)
    ErrorHandler.SafeExecute("trailers_sync_containers", function()
        heistState.robbedContainers = containers
        debugLog("Robbed containers synchronized")
    end)
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    ErrorHandler.SafeExecute("trailers_cleanup", function()
        -- Clean up ox_target options
        if exports.ox_target then
            exports.ox_target:removeModel(HeistConfig.Trailers.ContainerModels)
        end
        
        debugLog("Resource stopped, target options removed")
    end)
end)