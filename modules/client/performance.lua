local PerformanceManager = {}

-- Utility reference
local Utils = exports[GetCurrentResourceName()]:GetSharedUtils()

-- Configuration
local config = {
    markerRenderDistance = 50.0,
    entityLODDistance = {
        close = 25.0,
        medium = 50.0,
        far = 100.0
    },
    waitTimeScales = {
        close = 0,     -- 0ms wait (every frame)
        medium = 250,  -- 250ms wait
        far = 500,     -- 500ms wait
        none = 1000    -- 1000ms wait (no entity in range)
    },
    markersBatchLimit = 25,  -- Maximum markers to render in one batch
    entityCacheTime = 2000,  -- Time in ms to cache entity search results
}

-- State
local pendingMarkers = {}
local lastEntitySearch = {
    timestamp = 0,
    results = {},
    cache = {}
}

-- Find nearest entity efficiently with caching
function PerformanceManager.FindNearestEntity(playerCoords, modelHashes, maxDistance)
    -- Check cache for recent results
    local currentTime = GetGameTimer()
    if currentTime - lastEntitySearch.timestamp < config.entityCacheTime then
        if lastEntitySearch.cache.coords and 
           #(playerCoords - lastEntitySearch.cache.coords) < 5.0 and
           lastEntitySearch.cache.maxDistance >= maxDistance then
            return lastEntitySearch.cache.entity, lastEntitySearch.cache.distance
        end
    end
    
    local closestEntity = nil
    local closestDistance = maxDistance or 50.0
    
    -- Use cached results from previous searches if available
    for entity, data in pairs(lastEntitySearch.results) do
        if DoesEntityExist(entity) then
            local entCoords = GetEntityCoords(entity)
            local distance = #(playerCoords - entCoords)
            
            if distance <= closestDistance then
                -- Check model hash match
                local modelHash = GetEntityModel(entity)
                for _, hash in ipairs(modelHashes) do
                    if modelHash == hash then
                        closestEntity = entity
                        closestDistance = distance
                        break
                    end
                end
            end
        else
            -- Clean up invalid entities
            lastEntitySearch.results[entity] = nil
        end
    end
    
    -- If we found an entity in our cache, return it
    if closestEntity then
        -- Update cache
        lastEntitySearch.cache = {
            entity = closestEntity,
            distance = closestDistance,
            coords = playerCoords,
            maxDistance = maxDistance or 50.0
        }
        return closestEntity, closestDistance
    end
    
    -- Otherwise do a search for entities
    local objectPool = GetGamePool('CObject')
    
    for i = 1, #objectPool do
        local entity = objectPool[i]
        local modelHash = GetEntityModel(entity)
        
        -- Check if model matches
        local isValidModel = false
        for _, hash in ipairs(modelHashes) do
            if modelHash == hash then
                isValidModel = true
                break
            end
        end
        
        if isValidModel then
            local entityCoords = GetEntityCoords(entity)
            local distance = #(playerCoords - entityCoords)
            
            -- Add to results cache regardless of distance
            lastEntitySearch.results[entity] = {
                modelHash = modelHash,
                coords = entityCoords
            }
            
            if distance <= closestDistance then
                closestEntity = entity
                closestDistance = distance
            end
        end
    end
    
    -- Update cache timestamp and newest result
    lastEntitySearch.timestamp = currentTime
    lastEntitySearch.cache = {
        entity = closestEntity,
        distance = closestDistance,
        coords = playerCoords,
        maxDistance = maxDistance or 50.0
    }
    
    return closestEntity, closestDistance
end

-- Determine if a marker should be drawn based on player distance
function PerformanceManager.ShouldDrawMarker(playerCoords, markerCoords, maxDist)
    if not markerCoords then return false end
    maxDist = maxDist or config.markerRenderDistance
    
    local distance = #(playerCoords - markerCoords)
    return distance <= maxDist
end

-- Add a marker to the render queue
function PerformanceManager.AddMarkerToRender(type, position, dir, rot, scale, color, bobUpAndDown, faceCamera, rotate)
    table.insert(pendingMarkers, {
        type = type,
        position = position,
        dir = dir,
        rot = rot,
        scale = scale,
        color = color,
        bobUpAndDown = bobUpAndDown,
        faceCamera = faceCamera,
        rotate = rotate
    })
end

-- Batch render markers for performance
Citizen.CreateThread(function()
    while true do
        -- Only process if we have markers to render
        if #pendingMarkers > 0 then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Process up to the batch limit
            local processCount = math.min(#pendingMarkers, config.markersBatchLimit)
            
            for i = 1, processCount do
                local marker = pendingMarkers[i]
                
                -- Check if marker should be rendered
                if PerformanceManager.ShouldDrawMarker(playerCoords, marker.position) then
                    DrawMarker(
                        marker.type,
                        marker.position.x, marker.position.y, marker.position.z,
                        marker.dir.x, marker.dir.y, marker.dir.z,
                        marker.rot.x, marker.rot.y, marker.rot.z,
                        marker.scale.x, marker.scale.y, marker.scale.z,
                        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                        marker.bobUpAndDown, marker.faceCamera, 2, marker.rotate, nil, nil, false
                    )
                end
            end
            
            -- Clear processed markers
            for i = processCount, 1, -1 do
                table.remove(pendingMarkers, i)
            end
            
            -- If we have more markers, continue on next frame
            if #pendingMarkers > 0 then
                Citizen.Wait(0)
            else
                Citizen.Wait(50) -- Small wait when empty
            end
        else
            Citizen.Wait(100) -- Longer wait when no markers
        end
    end
end)

-- Optimize entity LOD based on distance
function PerformanceManager.OptimizeEntityDrawDistance(entity, distance)
    if not DoesEntityExist(entity) then return end
    
    if distance < config.entityLODDistance.close then
        -- Close - high detail
        SetEntityLodDist(entity, 500)
    elseif distance < config.entityLODDistance.medium then
        -- Medium - normal detail
        SetEntityLodDist(entity, 250)
    else
        -- Far - low detail
        SetEntityLodDist(entity, 100)
    end
end

-- Get appropriate wait time based on distance
function PerformanceManager.GetWaitTimeForDistance(distanceSquared)
    if distanceSquared < (config.entityLODDistance.close * config.entityLODDistance.close) then
        return config.waitTimeScales.close
    elseif distanceSquared < (config.entityLODDistance.medium * config.entityLODDistance.medium) then
        return config.waitTimeScales.medium
    elseif distanceSquared < (config.entityLODDistance.far * config.entityLODDistance.far) then
        return config.waitTimeScales.far
    else
        return config.waitTimeScales.none
    end
end

-- Clear entity search cache
function PerformanceManager.ClearEntityCache()
    lastEntitySearch = {
        timestamp = 0,
        results = {},
        cache = {}
    }
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Clear any pending markers
    pendingMarkers = {}
    
    -- Clear cache
    PerformanceManager.ClearEntityCache()
end)

return PerformanceManager