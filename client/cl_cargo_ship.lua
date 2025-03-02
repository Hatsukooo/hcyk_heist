local ESX = exports["es_extended"]:getSharedObject()
local ClientUtils = exports[GetCurrentResourceName()]:GetClientUtils()
local SharedUtils = exports[GetCurrentResourceName()]:GetSharedUtils()

-- State management
local PlayerData = {}
local heistState = {
    active = false,
    id = nil,
    approach = nil,
    ship = nil,
    guards = {},
    loot = {},
    alarmed = false,
    remainingTime = 0,
    carriedLoot = 0,
    blips = {},
    zones = {}
}

-- Debug logging
local function debugLog(message, ...)
    if Config.Debug then
        print(string.format("[DEBUG] [Cargo Ship] %s", string.format(message, ...)))
    end
end

-- Initialize player data
Citizen.CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(100)
    end
    
    PlayerData = ESX.GetPlayerData()
    debugLog("Player data initialized")
    
    -- Create the heist NPC
    CreateHeistNPC()
end)

-- Handle job changes
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

-- Create the heist NPC
function CreateHeistNPC()
    debugLog("Creating heist NPC")
    
    local model = Config.CargoShip.NPCModel
    local pedHash = GetHashKey(model)
    
    RequestModel(pedHash)
    while not HasModelLoaded(pedHash) do
        Citizen.Wait(50)
        debugLog("Waiting for NPC model to load")
    end
    
    local ped = CreatePed(4, pedHash, 
        Config.CargoShip.NPCpoint.x, 
        Config.CargoShip.NPCpoint.y, 
        Config.CargoShip.NPCpoint.z - 1, 
        Config.CargoShip.NPCpoint.w, 
        false, true)
    
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    
    -- Add interaction
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'start_cargo_ship_heist',
            icon = 'fa-solid fa-ship',
            label = 'Discuss Cargo Ship Job',
            distance = 2.0,
            onSelect = function()
                OpenHeistMenu()
            end
        }
    })
    
    debugLog("Heist NPC created")
end

-- Open the heist selection menu
function OpenHeistMenu()
    ESX.TriggerServerCallback('hcyk_heists:cargo_ship:getStatus', function(available, remainingCooldown)
        if not available then
            local remainingMinutes = math.ceil(remainingCooldown / 60)
            SharedUtils.Notify('warning', Config.CargoShip.Title, 
                string.format('This job is not available right now. Try again in %d minutes.', remainingMinutes))
            return
        end
        
        local approachOptions = {}
        
        for _, approach in ipairs(Config.CargoShip.ApproachPoints) do
            table.insert(approachOptions, {
                title = approach.label,
                description = string.format("Difficulty: %s | Guards: %d", approach.difficulty, approach.guardCount),
                onSelect = function()
                    TriggerServerEvent('hcyk_heists:cargo_ship:start', approach.name)
                end
            })
        end
        
        lib.registerContext({
            id = 'cargo_ship_menu',
            title = 'Cargo Ship Infiltration',
            options = approachOptions
        })
        
        lib.showContext('cargo_ship_menu')
    end)
end

-- Setup the heist
RegisterNetEvent('hcyk_heists:cargo_ship:setup')
AddEventHandler('hcyk_heists:cargo_ship:setup', function(heistId, heistData)
    debugLog("Setting up heist: " .. heistId)
    
    heistState.active = true
    heistState.id = heistId
    heistState.approach = heistData.approachType
    heistState.alarmed = false
    heistState.remainingTime = Config.CargoShip.TimeLimit
    heistState.carriedLoot = 0
    heistState.loot = heistData.loot
    
    -- Clear any existing blips
    ClearHeistBlips()
    
    -- Start the heist
    StartHeist()
end)

-- Start the heist
function StartHeist()
    -- Show approach point on map
    local approachPoint = nil
    for _, point in ipairs(Config.CargoShip.ApproachPoints) do
        if point.name == heistState.approach then
            approachPoint = point
            break
        end
    end
    
    if not approachPoint then
        SharedUtils.Notify('error', Config.CargoShip.Title, 'Invalid approach point!')
        return
    end
    
    -- Create approach blip
    local blip = ClientUtils.CreateBlip(approachPoint.coords, 501, 3, 1.0, "Approach Point", true, false)
    table.insert(heistState.blips, blip)
    
    -- Start approach thread
    Citizen.CreateThread(function()
        local arrived = false
        
        while heistState.active and not arrived do
            Citizen.Wait(1000)
            
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - approachPoint.coords)
            
            if distance < 5.0 and not arrived then
                arrived = true
                RemoveBlip(blip)
                
                -- Trigger infiltration start
                StartInfiltration(approachPoint)
            end
        end
    end)
    
    -- Start timer
    StartHeistTimer()
    
    SharedUtils.Notify('info', Config.CargoShip.Title, 
        string.format('Infiltration started. Head to the %s approach point.', approachPoint.label))
end

-- Start the infiltration phase
function StartInfiltration(approachPoint)
    debugLog("Starting infiltration at " .. approachPoint.name)
    
    -- Special handling for water approach
    if approachPoint.name == "water_approach" then
        -- If water approach, offer diving equipment
        SharedUtils.Notify('info', Config.CargoShip.Title, 'Using water approach. Prepare to swim to the ship.')
    end
    
    -- Spawn guards based on approach
    SpawnGuards(approachPoint)
    
    -- Create loot markers and interactions
    SetupLootPoints()
    
    -- Create escape point
    SetupEscapePoint()
}

-- Spawn guards for the heist
function SpawnGuards(approachPoint)
    -- Clear any existing guards
    for _, guard in ipairs(heistState.guards) do
        if DoesEntityExist(guard.ped) then
            DeleteEntity(guard.ped)
        end
    end
    
    heistState.guards = {}
    
    -- Get guard configuration
    local guardCount = approachPoint.guardCount
    local guardModels = Config.CargoShip.Guards.Models
    local guardWeapons = Config.CargoShip.Guards.Weapons
    local patrolRoutes = Config.CargoShip.Guards.PatrolRoutes
    
    -- Spawn guards
    for i = 1, guardCount do
        local modelName = guardModels[math.random(1, #guardModels)]
        local weaponName = guardWeapons[math.random(1, #guardWeapons)]
        local patrolRoute = patrolRoutes[math.random(1, #patrolRoutes)]
        
        -- Request model
        local modelHash = GetHashKey(modelName)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Citizen.Wait(10)
        end
        
        -- Create guard
        local startPoint = patrolRoute[1]
        local guard = CreatePed(4, modelHash, startPoint.x, startPoint.y, startPoint.z, 0.0, true, true)
        
        -- Configure guard
        SetPedRandomComponentVariation(guard, 0)
        SetPedRandomProps(guard)
        SetPedArmour(guard, 100)
        SetPedAccuracy(guard, 50)
        SetPedFleeAttributes(guard, 0, false)
        SetPedCombatAttributes(guard, 46, true)
        SetPedCombatMovement(guard, 2)
        GiveWeaponToPed(guard, GetHashKey(weaponName), 999, false, true)
        
        -- Store guard data
        table.insert(heistState.guards, {
            ped = guard,
            state = "patrolling", -- patrolling, alert, combat
            route = patrolRoute,
            currentPoint = 1,
            lastSeen = nil,
            alertLevel = 0 -- 0-100
        })
        
        -- Start patrol AI
        StartGuardPatrol(#heistState.guards)
    end
    
    debugLog(string.format("Spawned %d guards", guardCount))
end

-- Start guard patrol behavior
function StartGuardPatrol(guardIndex)
    Citizen.CreateThread(function()
        local guard = heistState.guards[guardIndex]
        if not guard or not DoesEntityExist(guard.ped) then return end
        
        while heistState.active and DoesEntityExist(guard.ped) do
            if guard.state == "patrolling" then
                -- Move to next patrol point
                local targetPoint = guard.route[guard.currentPoint]
                TaskGoToCoordAnyMeans(guard.ped, targetPoint.x, targetPoint.y, targetPoint.z, 1.0, 0, 0, 786603, 0)
                
                -- Wait until guard reaches point or gets alerted
                local reachedPoint = false
                while not reachedPoint and guard.state == "patrolling" and heistState.active do
                    Citizen.Wait(500)
                    
                    local guardCoords = GetEntityCoords(guard.ped)
                    local distanceToTarget = #(guardCoords - targetPoint)
                    
                    if distanceToTarget < 0.5 then
                        reachedPoint = true
                        
                        -- Move to next point in route
                        guard.currentPoint = guard.currentPoint % #guard.route + 1
                        
                        -- Guard looks around briefly
                        TaskAchieveHeading(guard.ped, math.random(0, 359), 2000)
                        Citizen.Wait(2000)
                    end
                    
                    -- Check if guard sees player
                    CheckGuardVision(guardIndex)
                end
            elseif guard.state == "alert" then
                -- Guard is suspicious and investigating
                if guard.lastSeen then
                    -- Move to last known position
                    TaskGoToCoordAnyMeans(guard.ped, 
                        guard.lastSeen.x, guard.lastSeen.y, guard.lastSeen.z, 
                        2.0, 0, 0, 786603, 0)
                    
                    -- Wait until guard reaches position
                    local investigating = true
                    local startTime = GetGameTimer()
                    
                    while investigating and guard.state == "alert" and heistState.active do
                        Citizen.Wait(500)
                        
                        local guardCoords = GetEntityCoords(guard.ped)
                        local distanceToTarget = #(guardCoords - guard.lastSeen)
                        
                        -- Check if guard reached position or timeout
                        if distanceToTarget < 1.0 or GetGameTimer() - startTime > 10000 then
                            investigating = false
                            
                            -- Look around
                            for i = 1, 4 do
                                local heading = (i - 1) * 90
                                TaskAchieveHeading(guard.ped, heading, 2000)
                                Citizen.Wait(2000)
                                
                                -- Check if guard sees player during look around
                                CheckGuardVision(guardIndex)
                            end
                            
                            -- Return to patrol if not alerted again
                            if guard.state == "alert" then
                                guard.state = "patrolling"
                                guard.alertLevel = math.max(guard.alertLevel - 20, 0)
                            end
                        end
                        
                        -- Continue checking vision
                        CheckGuardVision(guardIndex)
                    end
                else
                    -- No last seen position, return to patrol
                    guard.state = "patrolling"
                end
            elseif guard.state == "combat" then
                -- Guard is in combat mode
                local playerPed = PlayerPedId()
                TaskCombatPed(guard.ped, playerPed, 0, 16)
                
                -- Check if lost sight of player
                local combatTime = GetGameTimer()
                
                while guard.state == "combat" and heistState.active do
                    Citizen.Wait(1000)
                    
                    local playerCoords = GetEntityCoords(playerPed)
                    local guardCoords = GetEntityCoords(guard.ped)
                    local distance = #(guardCoords - playerCoords)
                    
                    -- If player is too far away or out of sight for too long
                    if distance > 30.0 and GetGameTimer() - combatTime > 15000 then
                        guard.state = "alert"
                        guard.lastSeen = playerCoords
                    else
                        -- Update last seen position
                        guard.lastSeen = playerCoords
                        combatTime = GetGameTimer()
                        
                        -- Trigger alarm if not already triggered
                        if not heistState.alarmed then
                            TriggerServerEvent('hcyk_heists:cargo_ship:triggerAlarm', heistState.id, false)
                        end
                    end
                end
            end
            
            Citizen.Wait(500)
        end
    end)
end

-- Check if guard can see the player
function CheckGuardVision(guardIndex)
    local guard = heistState.guards[guardIndex]
    if not guard or not DoesEntityExist(guard.ped) then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local guardCoords = GetEntityCoords(guard.ped)
    
    -- Calculate distance and angle
    local distance = #(guardCoords - playerCoords)
    local heading = GetEntityHeading(guard.ped)
    local angle = math.abs(GetHeadingFromVector_2d(
        playerCoords.x - guardCoords.x, 
        playerCoords.y - guardCoords.y
    ) - heading)
    if angle > 180 then angle = 360 - angle end
    
    -- Basic vision parameters
    local visionCone = 90 -- degrees
    local visionDistance = 15.0 -- meters
    local visionDistanceAlert = 25.0 -- meters when already alert
    
    -- Check if player is within vision cone and distance
    local canSeePlayer = false
    local maxDistance = guard.state == "alert" and visionDistanceAlert or visionDistance
    
    if distance < maxDistance and angle < visionCone then
        -- Check for line of sight
        canSeePlayer = HasEntityClearLosToEntity(guard.ped, playerPed, 17) -- 17 = skip windows flag
        
        -- Adjust based on crouching/stealth
        if canSeePlayer and GetPedStealthMovement(playerPed) then
            -- Reduce detection chance if player is in stealth mode
            canSeePlayer = distance < (maxDistance * 0.5)
        end
    end
    
    -- Very close proximity detection regardless of cone
    if distance < 2.0 and HasEntityClearLosToEntity(guard.ped, playerPed, 17) then
        canSeePlayer = true
    end
    
    -- Update guard state based on vision
    if canSeePlayer then
        guard.lastSeen = playerCoords
        guard.alertLevel = guard.alertLevel + 25
        
        if guard.alertLevel >= 100 or guard.state == "alert" or distance < 5.0 then
            -- Full alert - combat mode
            guard.state = "combat"
            
            -- Alert nearby guards
            AlertNearbyGuards(guardIndex, playerCoords)
        elseif guard.alertLevel >= 50 then
            -- Suspicious - investigate
            guard.state = "alert"
            
            -- Play alert animation
            PlayPedAmbientSpeechWithVoiceNative(guard.ped, "SPOT_SUSPECT", "S_M_Y_RANGER_01_WHITE_FULL_01", "SPEECH_PARAMS_FORCE_SHOUTED", 0)
        end
    else
        -- Gradually reduce alert level over time
        if guard.state == "alert" and guard.alertLevel > 0 then
            guard.alertLevel = guard.alertLevel - 1
        end
    end
end

-- Alert nearby guards
function AlertNearbyGuards(sourceGuardIndex, playerCoords)
    local sourceGuard = heistState.guards[sourceGuardIndex]
    if not sourceGuard or not DoesEntityExist(sourceGuard.ped) then return end
    
    local sourceCoords = GetEntityCoords(sourceGuard.ped)
    
    for i, guard in ipairs(heistState.guards) do
        if i ~= sourceGuardIndex and DoesEntityExist(guard.ped) then
            local guardCoords = GetEntityCoords(guard.ped)
            local distance = #(guardCoords - sourceCoords)
            
            -- Alert guards within hearing range
            if distance < 20.0 then
                guard.state = "alert"
                guard.lastSeen = playerCoords
                guard.alertLevel = math.min(guard.alertLevel + 50, 100)
                
                -- If very close, go straight to combat
                if distance < 10.0 then
                    guard.state = "combat"
                end
            end
        end
    end
    
    -- Trigger alarm if not already triggered
    if not heistState.alarmed then
        TriggerServerEvent('hcyk_heists:cargo_ship:triggerAlarm', heistState.id, true)
    end
end

-- Setup loot points
function SetupLootPoints()
    -- Clear any existing zones
    for _, zone in ipairs(heistState.zones) do
        exports.ox_target:removeZone(zone)
    end
    
    heistState.zones = {}
    
    -- Create zones for each loot item
    for _, loot in pairs(heistState.loot) do
        if not loot.collected then
            local modelHash = GetHashKey(loot.model)
            RequestModel(modelHash)
            
            -- Create loot object
            local lootObj = CreateObject(modelHash, 
                loot.position.x, loot.position.y, loot.position.z - 1.0, 
                true, false, false)
            
            SetEntityAsMissionEntity(lootObj, true, true)
            PlaceObjectOnGroundProperly(lootObj)
            FreezeEntityPosition(lootObj, true)
            SetModelAsNoLongerNeeded(modelHash)
            
            -- Add interaction zone
            local zoneId = exports.ox_target:addSphereZone({
                coords = loot.position,
                radius = 0.9,
                debug = Config.Debug,
                options = {
                    {
                        name = 'collect_loot_' .. loot.id,
                        icon = 'fa-solid fa-box-open',
                        label = 'Collect ' .. loot.name:gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end),
                        distance = 1.5,
                        onSelect = function()
                            CollectLoot(loot.id, lootObj)
                        end
                    }
                }
            })
            
            table.insert(heistState.zones, zoneId)
            
            -- Add blip for loot
            local blip = ClientUtils.CreateBlip(loot.position, 586, 5, 0.6, "Loot", false, false)
            table.insert(heistState.blips, blip)
        end
    end
end

-- Collect loot
function CollectLoot(lootId, lootObj)
    -- Check weight capacity
    local lootItem = nil
    for _, item in pairs(heistState.loot) do
        if item.id == lootId then
            lootItem = item
            break
        end
    end
    
    if not lootItem then return end
    
    -- Check weight limits
    if heistState.carriedLoot + lootItem.weight > Config.CargoShip.Loot.MaxCapacity then
        SharedUtils.Notify('error', Config.CargoShip.Title, 
            'You cannot carry any more loot! Escape now or drop some items.')
        return
    end
    
    -- Progress bar for collecting
    ClientUtils.ProgressBar('Collecting ' .. lootItem.name, 3000, 'anim@mp_snowball', 'pickup_snowball', 0, {
        car = true,
        move = true,
        combat = true
    })
    
    -- Update loot state
    heistState.carriedLoot = heistState.carriedLoot + lootItem.weight
    
    -- Send collection event to server
    TriggerServerEvent('hcyk_heists:cargo_ship:collectLoot', heistState.id, lootId)
    
    -- Delete loot object
    if DoesEntityExist(lootObj) then
        DeleteEntity(lootObj)
    end
end

-- Setup escape point
function SetupEscapePoint()
    -- Pick appropriate escape point based on approach
    local escapeIndex = 1
    if heistState.approach == "water_approach" then
        escapeIndex = 3 -- Boat escape
    elseif heistState.approach == "main_entrance" then
        escapeIndex = 1 -- Helicopter escape
    else
        escapeIndex = 2 -- Vehicle escape
    end
    
    local escapePoint = Config.CargoShip.EscapePoints[escapeIndex]
    
    -- Create escape blip
    local blip = ClientUtils.CreateBlip(escapePoint, 357, 2, 1.0, "Escape Point", false, false)
    table.insert(heistState.blips, blip)
    
    -- Create escape zone
    local zoneId = exports.ox_target:addSphereZone({
        coords = escapePoint,
        radius = 2.0,
        debug = Config.Debug,
        options = {
            {
                name = 'escape_ship',
                icon = 'fa-solid fa-person-running',
                label = 'Escape with Loot',
                distance = 2.0,
                onSelect = function()
                    CompleteHeist()
                end
            }
        }
    })
    
    table.insert(heistState.zones, zoneId)
}

-- Complete the heist
function CompleteHeist()
    if heistState.carriedLoot <= 0 then
        SharedUtils.Notify('warning', Config.CargoShip.Title, 
            'You don\'t have any loot to escape with!')
        return
    end
    
    -- Progress bar for escaping
    ClientUtils.ProgressBar('Escaping', 5000, 'missfbi5ig_0', 'lyinginpain_loop_steve', 0, {
        car = true,
        move = true,
        combat = true
    })
    
    -- Trigger completion on server
    TriggerServerEvent('hcyk_heists:cargo_ship:complete', heistState.id)
    
    -- Clean up heist
    CleanupHeist()
}

-- Start heist timer
function StartHeistTimer()
    Citizen.CreateThread(function()
        while heistState.active and heistState.remainingTime > 0 do
            Citizen.Wait(1000)
            heistState.remainingTime = heistState.remainingTime - 1
            
            -- Display time remaining
            local minutes = math.floor(heistState.remainingTime / 60)
            local seconds = heistState.remainingTime % 60
            
            DrawTimerHUD(minutes, seconds)
            
            -- Handle time running out
            if heistState.remainingTime <= 0 then
                SharedUtils.Notify('error', Config.CargoShip.Title, 'Time\'s up! Security forces incoming!')
                
                -- Trigger alarm if not already
                if not heistState.alarmed then
                    TriggerServerEvent('hcyk_heists:cargo_ship:triggerAlarm', heistState.id, false)
                end
                
                -- Force all guards to combat mode
                for i, guard in ipairs(heistState.guards) do
                    guard.state = "combat"
                end
            end
        end
    end)
}

-- Draw timer HUD
function DrawTimerHUD(minutes, seconds)
    -- Only every second to save resources
    local timeText = string.format("Time: %02d:%02d", minutes, seconds)
    local lootText = string.format("Loot: %d/%d kg", heistState.carriedLoot, Config.CargoShip.Loot.MaxCapacity)
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    SetTextCentre(false)
    AddTextComponentString(timeText)
    DrawText(0.9, 0.1)
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    SetTextCentre(false)
    AddTextComponentString(lootText)
    DrawText(0.9, 0.14)
}

-- Handle alarm trigger
RegisterNetEvent('hcyk_heists:cargo_ship:alarmTriggered')
AddEventHandler('hcyk_heists:cargo_ship:alarmTriggered', function()
    heistState.alarmed = true
    
    -- Play alarm sound
    local alarmSoundId = GetSoundId()
    PlaySoundFromCoord(alarmSoundId, "Ship_Horn", 
        Config.CargoShip.ShipLocation.x, 
        Config.CargoShip.ShipLocation.y, 
        Config.CargoShip.ShipLocation.z, 
        "DLC_BTL_Yacht_Ambient_Soundset", true, 100, 0)
    
    -- Alert all guards
    for i, guard in ipairs(heistState.guards) do
        if guard.state ~= "combat" then
            guard.state = "alert"
            guard.alertLevel = math.min(guard.alertLevel + 75, 100)
        end
    end
    
    SharedUtils.Notify('error', Config.CargoShip.Title, 'Alarm triggered! Guards are on high alert!')
    
    -- Stop alarm after 10 seconds but guards remain alerted
    Citizen.SetTimeout(10000, function()
        StopSound(alarmSoundId)
        ReleaseSoundId(alarmSoundId)
    end)
}

-- Sync loot state
RegisterNetEvent('hcyk_heists:cargo_ship:syncLoot')
AddEventHandler('hcyk_heists:cargo_ship:syncLoot', function(newLoot)
    heistState.loot = newLoot
    
    -- Refresh loot points to reflect changes
    Citizen.SetTimeout(500, function()
        SetupLootPoints()
    end)
end)

-- Notification handler
RegisterNetEvent('hcyk_heists:cargo_ship:notify')
AddEventHandler('hcyk_heists:cargo_ship:notify', function(type, message)
    SharedUtils.Notify(type, Config.CargoShip.Title, message)
end)

-- Cleanup the heist
function CleanupHeist()
    -- Reset state
    heistState.active = false
    
    -- Remove all blips
    ClearHeistBlips()
    
    -- Remove all zones
    for _, zone in ipairs(heistState.zones) do
        exports.ox_target:removeZone(zone)
    end
    heistState.zones = {}
    
    -- Delete all guards
    for _, guard in ipairs(heistState.guards) do
        if DoesEntityExist(guard.ped) then
            DeleteEntity(guard.ped)
        end
    end
    heistState.guards = {}
}

-- Clear all heist blips
function ClearHeistBlips()
    for _, blip in ipairs(heistState.blips) do
        RemoveBlip(blip)
    end
    heistState.blips = {}
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Cleanup any active heist
    if heistState.active then
        CleanupHeist()
    end
end)