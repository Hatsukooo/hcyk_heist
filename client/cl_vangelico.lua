local ESX = exports["es_extended"]:getSharedObject()

-- State management
local PlayerData = {}
local heistState = {
    openedVent = false,
    openedSachta = false,
    canRob = true,
    isRobbing = false,
    isBusy = false,
    globalCooldown = false,
    robbedVitrines = 0,
    totalVitrines = 20,
    remainingTime = Config.Vangelico.RobberyTime,
    vitrineZones = {},
    timerActive = false
}

-- Utility functions
local function debugLog(message, ...)
    if Config.Debug then 
        print("[DEBUG Vangelico] " .. string.format(message, ...))
    end
end

local function hasItem(itemName)
    local count = exports.ox_inventory:Search('count', itemName)
    return count and count > 0
end

local function notify(type, message)
    local notifConfig = Config.Vangelico.Notifications[type]
    if not notifConfig then
        notifConfig = Config.Vangelico.Notifications.Info
    end
    
    lib.notify({
        title = notifConfig.title,
        description = message,
        type = notifConfig.type,
        duration = notifConfig.duration,
        position = notifConfig.position
    })
end

local function playAnimation(dict, anim, duration, flags)
    flags = flags or 0
    
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Citizen.Wait(10)
        end
    end
    
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration or -1, flags, 0, false, false, false)
    
    if duration then
        Citizen.Wait(duration)
        ClearPedTasks(PlayerPedId())
    end
end

-- Initialize the player data
Citizen.CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(10)
    end
    
    PlayerData = ESX.GetPlayerData()
    debugLog("Player data initialized: %s", json.encode(PlayerData.job))
    setupVentTargets()
end)

-- Handle job changes
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    debugLog("Player job updated: %s", json.encode(job))
end)

-- Setup air vent target zone
function setupVentTargets()
    exports.ox_target:addBoxZone({
        name = "vangelico_vent",
        coords = Config.Vangelico.AirVent,
        size = vec3(4.0, 4.0, 4.0),
        rotation = 30.0,
        debug = Config.Debug,
        options = {
            {   
                name = 'open_vent',
                icon = 'fa-solid fa-lock-open',
                label = "Otevřít šachtu",
                distance = 2.0,
                canInteract = function(entity, distance, coords, name, bone)
                    return not heistState.isBusy and not heistState.openedVent
                end,
                onSelect = openVent
            },
            {
                name = 'place_charge',
                icon = 'fa-solid fa-smog',
                label = "Umístit nálož",
                canInteract = function(entity, distance, coords, name, bone)
                    return not heistState.isBusy and not heistState.openedSachta and heistState.openedVent
                end,
                onSelect = placeCharge
            },
        }
    })
    
    debugLog("Vent target zones created")
end

-- Function to open the air vent
function openVent()
    ESX.TriggerServerCallback('hcyk_heists:vangelico:pdcount', function(policeCount)
        if policeCount >= Config.Vangelico.RequiredCops then
            if not heistState.globalCooldown then
                if hasItem(Config.Vangelico.RequiredItems.Drill.name) then
                    FreezeEntityPosition(PlayerPedId(), true)
                    TriggerServerEvent('hcyk_heists:vangelico:removeitem', 
                        Config.Vangelico.RequiredItems.Drill.name, 
                        Config.Vangelico.RequiredItems.Drill.count)
                    
                    -- Synchronize state with server
                    TriggerServerEvent("hcyk_heists:vangelico:syncVent", true)
                    
                    heistState.isBusy = true
                    
                    lib.progressBar({
                        duration = 5000,
                        label = 'Otevíráš šachtu',
                        useWhileDead = false,
                        canCancel = false,
                        disable = {
                            car = true,
                        },
                        anim = {
                            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                            clip = 'machinic_loop_mechandplayer'
                        },
                    })
                    
                    heistState.isBusy = false
                    heistState.openedVent = true
                    
                    notify('Info', 'Šachta otevřena, teď ještě přidej nálož!')
                    FreezeEntityPosition(PlayerPedId(), false)
                else
                    notify('Error', 'Nemáš potřebnou pomůcku blbečku :|')
                end
            else
                notify('Warning', 'Počkej 20 minut, někdo tu již před tebou byl!')
            end
        else
            notify('Error', 'Nedostatek policistů ve městě!')
        end
    end)
end

-- Function to place thermite charge
function placeCharge()
    if hasItem(Config.Vangelico.RequiredItems.Thermite.name) then
        TriggerServerEvent('hcyk_heists:vangelico:removeitem', 
            Config.Vangelico.RequiredItems.Thermite.name, 
            Config.Vangelico.RequiredItems.Thermite.count)
        
        -- Synchronize state with server
        TriggerServerEvent("hcyk_heists:vangelico:syncSachta", true)
        
        heistState.isBusy = true
        heistState.openedSachta = true
        heistState.canRob = false
        
        -- Trigger bomb effect
        TriggerEvent('hcyk_heists:vangelico:bomba')
    else
        notify('Error', 'Nemáš potřebnou pomůcku blbečku :|')
    end
end

-- Setup vitrine targets for robbery
function setupVitrineTargets()
    debugLog("Setting up vitrine targets")
    
    -- Define all the vitrines
    local vitrines = {
        {x = -627.23, y = -234.98, z = 38.52, h = 50.97,  ax = -626.61, ay = -235.62, id = 1, broken = false},
        {x = -627.67, y = -234.35, z = 38.52, h = 232.01, ax = -628.19, ay = -233.54, id = 2, broken = false},
        {x = -626.53, y = -233.52, z = 38.52, h = 232.01, ax = -627.11, ay = -232.84, id = 3, broken = false},
        {x = -626.09, y = -234.15, z = 38.52, h = 45.05, ax = -625.50, ay = -234.92, id = 4, broken = false}, 
        {x = -625.27, y = -238.31, z = 38.52, h = 232.01, ax = -625.81, ay = -237.49, id = 5, broken = false},
        {x = -626.26, y = -239.03, z = 38.52, h = 232.01, ax = -626.82, ay = -238.41, id = 6, broken = false},
        {x = -623.98, y = -230.73, z = 38.52, h = 309.21, ax = -624.84, ay = -231.33, id = 7, broken = false},
        {x = -622.50, y = -232.60, z = 38.52, h = 309.21, ax = -623.55, ay = -233.28, id = 8, broken = false},
        {x = -619.87, y = -234.82, z = 38.52, h = 232.01, ax = -620.37, ay = -234.0, id = 9, broken = false}, 
        {x = -618.79, y = -234.05, z = 38.52, h = 232.01, ax = -619.40, ay = -233.13, id = 10, broken = false},
        {x = -617.11, y = -230.20, z = 38.52, h = 299.83, ax = -617.99, ay = -230.73, id = 11, broken = false},
        {x = -617.87, y = -229.15, z = 38.52, h = 299.83, ax = -618.85, ay = -229.86, id = 12, broken = false},
        {x = -619.16, y = -227.18, z = 38.52, h = 299.83, ax = -620.07, ay = -227.90, id = 13, broken = false},
        {x = -619.99, y = -226.15, z = 38.52, h = 299.83, ax = -620.84, ay = -226.85, id = 14, broken = false},
        {x = -625.25, y = -227.24, z = 38.52, h = 48.83, ax = -624.74, ay = -228.36, id = 15, broken = false},
        {x = -624.27, y = -226.64, z = 38.52, h = 48.83, ax = -623.71, ay = -227.53, id = 16, broken = false},
        {x = -623.58, y = -228.57, z = 38.52, h = 232.01, ax = -624.35, ay = -227.72, id = 17, broken = false},
        {x = -621.48, y = -228.84, z = 38.52, h = 128.82, ax = -620.57, ay = -228.39, id = 18, broken = false},
        {x = -620.17, y = -230.90, z = 38.52, h = 128.82, ax = -619.41, ay = -230.07, id = 19, broken = false},
        {x = -620.60, y = -232.90, z = 38.52, h = 35.14, ax = -619.87, ay = -233.88, id = 20, broken = false}
    }
    
    for _, vitrine in ipairs(vitrines) do
        Citizen.Wait(50) -- Stagger creation to prevent hitches
        
        local zoneId = exports.ox_target:addSphereZone({
            coords = vector3(vitrine.x, vitrine.y, vitrine.z - 0.5),
            radius = 0.4,
            debug = Config.Debug,
            options = {
                {
                    name = "rob_vitrine_" .. vitrine.id,
                    label = "Vykrást vitrínu",
                    icon = 'fa-solid fa-gun',
                    distance = 1,
                    canInteract = function(entity, distance, coords, name, bone)
                        return not vitrine.broken and heistState.isRobbing
                    end,
                    onSelect = function()
                        robVitrine(vitrine)
                    end,
                }
            }
        })
        
        heistState.vitrineZones[vitrine.id] = {
            id = zoneId,
            data = vitrine
        }
        
        debugLog("Created zone ID %s for vitrine %d", zoneId, vitrine.id)
    end
    
    heistState.totalVitrines = #vitrines
    debugLog("Total vitrines: %d", heistState.totalVitrines)
end

-- Function to rob a vitrine
function robVitrine(vitrine)
    if not IsPedArmed(PlayerPedId(), 6) then
        notify('Warning', 'Nejsi ozbrojen!🔫')
        return
    end
    
    -- Disable targeting temporarily
    exports.ox_target:disableTargeting(true)
    
    -- Mark vitrine as broken
    local id = vitrine.id
    heistState.vitrineZones[id].data.broken = true
    
    -- Play sound and particle effects
    PlaySoundFromCoord(-1, "Glass_Smash", vitrine.x, vitrine.y, vitrine.z, "", 0, 0, 0)
    
    if not HasNamedPtfxAssetLoaded("scr_jewelheist") then
        RequestNamedPtfxAsset("scr_jewelheist")
    end
    while not HasNamedPtfxAssetLoaded("scr_jewelheist") do
        Citizen.Wait(10)
    end
    
    SetPtfxAssetNextCall("scr_jewelheist")
    StartParticleFxLoopedAtCoord("scr_jewel_cab_smash", vitrine.x, vitrine.y, vitrine.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
    
    -- Position player for animation
    local calcZ = vitrine.z - 1.46
    SetEntityCoords(PlayerPedId(), vitrine.ax, vitrine.ay, calcZ)
    SetEntityHeading(PlayerPedId(), vitrine.h)
    
    -- Play smash animation
    playAnimation("missheist_jewel", "smash_case", 6000, 2)
    
    -- Give reward and update counts
    TriggerServerEvent('hcyk_heists:vangelico:giveitem')
    heistState.robbedVitrines = heistState.robbedVitrines + 1
    
    -- Show progress notification
    notify('Info', string.format('Momentálně jsi vyloupil %d/%d vitrín, pokračuj!💎', 
        heistState.robbedVitrines, heistState.totalVitrines))
    
    -- Remove the target zone
    local zoneId = heistState.vitrineZones[id].id
    if zoneId then
        exports.ox_target:removeZone(zoneId)
        debugLog("Removed zone ID %s for vitrine %d", zoneId, id)
    else
        debugLog("Failed to remove zone: ID not found for vitrine %d", id)
    end
    
    -- Re-enable targeting
    exports.ox_target:disableTargeting(false)
    
    -- Check if all vitrines are robbed
    checkRobberyCompletion()
end

-- Function to check if robbery is complete
function checkRobberyCompletion()
    if heistState.robbedVitrines >= heistState.totalVitrines then
        finishRobbery(true) -- Success
    end
end

-- Function to finish the robbery
function finishRobbery(success)
    heistState.canRob = true
    heistState.openedSachta = false
    heistState.openedVent = false
    heistState.isRobbing = false
    heistState.timerActive = false
    
    -- Set global cooldown
    heistState.globalCooldown = true
    TriggerServerEvent('hcyk_heists:vangelico:globaltimer', true)
    
    -- Reset server-side states
    TriggerServerEvent("hcyk_heists:vangelico:syncSachta", false)
    TriggerServerEvent("hcyk_heists:vangelico:syncVent", false)
    
    -- Clean up any remaining target zones
    for id, zoneData in pairs(heistState.vitrineZones) do
        if zoneData.id then
            exports.ox_target:removeZone(zoneData.id)
        end
    end
    heistState.vitrineZones = {}
    
    -- Hide UI and show completion message
    lib.hideTextUI()
    
    if success then
        notify('Success', 'Vyloupil jsi všechny vitríny a teď utíkej!💥😎')
    else
        notify('Error', 'AJAJAJ, nestihl jsi to, tak snad příště!💥😎')
    end
end

-- Bomb effect event
RegisterNetEvent('hcyk_heists:vangelico:bomba')
AddEventHandler('hcyk_heists:vangelico:bomba', function()
    heistState.isBusy = false
    exports.ox_target:disableTargeting(true)
    
    ESX.Streaming.RequestAnimDict('anim@heists@ornate_bank@thermal_charge', function(dict)
        if HasAnimDictLoaded('anim@heists@ornate_bank@thermal_charge') then
            -- Position player
            SetEntityCoords(PlayerPedId(), vec3(-635.89,-213.86,52.55))
            SetEntityHeading(PlayerPedId(), 32.45)
            
            -- Calculate forward position
            local fwd, _, _, pos = GetEntityMatrix(PlayerPedId())
            local np = (fwd * 0.8) + pos            
            SetEntityCoords(PlayerPedId(), np.xy, np.z - 1)
            
            -- Get player rotation and position
            local rot = GetEntityRotation(PlayerPedId())
            local pos = GetEntityCoords(PlayerPedId())
            
            -- Prepare player appearance
            SetPedComponentVariation(PlayerPedId(), 5, -1, 0, 0)
            
            -- Create bag prop
            local bag = CreateObject(GetHashKey("hei_p_m_bag_var22_arm_s"), pos.x, pos.y, pos.z, true, true, false)
            
            -- Setup synchronized scene
            local scene = NetworkCreateSynchronisedScene(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 2, 0, 0, 1065353216, 0, 1.3)
            SetEntityCollision(bag, false, true)
            
            -- Add entities to scene
            NetworkAddPedToSynchronisedScene(PlayerPedId(), scene, "anim@heists@ornate_bank@thermal_charge", "thermal_charge", 1.5, -4.0, 1, 16, 1148846080, 0)
            NetworkAddEntityToSynchronisedScene(bag, scene, "anim@heists@ornate_bank@thermal_charge", "bag_thermal_charge", 4.0, -8.0, 1)
            
            -- Start scene
            NetworkStartSynchronisedScene(scene)
            Citizen.Wait(1500)
            
            -- Create thermite prop
            pos = GetEntityCoords(PlayerPedId())
            local thermite = CreateObject(GetHashKey("hei_prop_heist_thermite"), pos.x, pos.y, pos.z + 0.2, true, true, true)
            
            -- Attach thermite to player
            SetEntityCollision(thermite, false, true)
            AttachEntityToEntity(thermite, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 28422), 0, 0, 0, 0, 0, 180.0, true, true, false, true, 1, true)
            
            -- Wait for animation
            Citizen.Wait(4000)
            exports.ox_target:disableTargeting(false)
            
            -- Clean up objects
            ESX.Game.DeleteObject(bag)
            SetPedComponentVariation(PlayerPedId(), 5, 45, 0, 0)
            
            -- Detach and position thermite
            DetachEntity(thermite, true, true)
            FreezeEntityPosition(thermite, true)
            SetEntityCollision(thermite, false, true)
            
            -- Trigger explosion effect
            local thermiteCoords = GetEntityCoords(thermite)
            TriggerServerEvent('hcyk_heists:vangelico:effect', thermite, true)
            
            -- Start robbery timer and vitrine setup
            startRobberyTimer()
            Citizen.Wait(4000)
            
            -- Stop scene and clean up
            NetworkStopSynchronisedScene(scene)
            DeleteObject(thermite)
            
            -- Notify and set up targets
            notify('Info', 'Začal jsi Vangelico Heist, okamžitě jdi do klenotnictví ho vyloupit!💥😎')
            
            heistState.isRobbing = true
            setupVitrineTargets()
        end
    end)
end)

-- Function to start the robbery timer
function startRobberyTimer()
    if heistState.timerActive then return end
    
    heistState.timerActive = true
    heistState.remainingTime = Config.Vangelico.RobberyTime
    
    Citizen.CreateThread(function()
        while heistState.timerActive and heistState.remainingTime > 0 do
            Citizen.Wait(1000)
            heistState.remainingTime = heistState.remainingTime - 1
            
            -- Update UI
            if not heistState.canRob then
                lib.showTextUI('Do vykradení ti zbývá ' .. heistState.remainingTime .. ' sekund!💎', {
                    position = 'bottom-center'
                })
            end
            
            -- Check if time ran out
            if heistState.remainingTime <= 0 then
                finishRobbery(false) -- Failed due to timeout
            end
        end
    end)
end

-- Event handlers for synchronization
RegisterNetEvent('hcyk_heists:vangelico:bombaFx')
AddEventHandler('hcyk_heists:vangelico:bombaFx', function(entity)
    ESX.Streaming.RequestNamedPtfxAsset('scr_ornate_heist', function()
        if HasNamedPtfxAssetLoaded('scr_ornate_heist') then
            SetPtfxAssetNextCall("scr_ornate_heist")
            local explosiveEffect = StartParticleFxLoopedOnEntity("scr_heist_ornate_thermal_burn", entity, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0, 0, 0)
            Citizen.Wait(4000)
            StopParticleFxLooped(explosiveEffect, 0)
        end
    end)
end)

RegisterNetEvent('hcyk_heists:vangelico:smoke')
AddEventHandler('hcyk_heists:vangelico:smoke', function()
    -- Only process the effect if player is near the jewelry store
    if #(GetEntityCoords(PlayerPedId()) - vector3(-632.39, -238.26, 38.07)) < 300 then
        local counter = 0
        local particleEffects = {}
        
        RequestNamedPtfxAsset('core')
        while not HasNamedPtfxAssetLoaded('core') do
            Citizen.Wait(10)
        end
        
        while true do 
            counter = counter + 1            
            
            if counter <= Config.Vangelico.GasTime * 4 then
                -- Create first smoke effect
                UseParticleFxAssetNextCall('core')
                local particle1 = StartParticleFxLoopedAtCoord("exp_grd_grenade_smoke", -621.85, -230.71, 37.05, 0.0, 0.0, 0.0, 2.0, false, false, false, 0)
                table.insert(particleEffects, 1, particle1)
                Citizen.Wait(1000)
                
                -- Create second smoke effect
                UseParticleFxAssetNextCall('core')
                local particle2 = StartParticleFxLoopedAtCoord("exp_grd_grenade_smoke", -624.45, -227.78, 37.05, 0.0, 0.0, 0.0, 2.0, false, false, false, 0)
                table.insert(particleEffects, 1, particle2)
                Citizen.Wait(1000)
                
                -- Wait before next iteration
                Citizen.Wait(4000)
            else
                -- Clean up all particle effects
                for _, particle in pairs(particleEffects) do
                    StopParticleFxLooped(particle, true)
                end
                
                break
            end
        end
    end
end)

RegisterNetEvent('hcyk_heists:vangelico:globaltimer')
AddEventHandler('hcyk_heists:vangelico:globaltimer', function(newGlobalTimer)
    debugLog("Global timer update received: %s", tostring(newGlobalTimer))
    heistState.globalCooldown = newGlobalTimer
end)

RegisterNetEvent('hcyk_heists:vangelico:SyncSachtaWithServer')
AddEventHandler('hcyk_heists:vangelico:SyncSachtaWithServer', function(sachtaStatus)
    debugLog("Sachta status update received: %s", tostring(sachtaStatus))
    heistState.openedSachta = sachtaStatus
end)

RegisterNetEvent('hcyk_heists:vangelico:SyncOpenedVentWithServer')
AddEventHandler('hcyk_heists:vangelico:SyncOpenedVentWithServer', function(ventStatus)
    debugLog("Vent status update received: %s", tostring(ventStatus))
    heistState.openedVent = ventStatus
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    lib.hideTextUI()
    exports.ox_target:disableTargeting(false)
    
    -- Clean up any remaining zones
    for id, zoneData in pairs(heistState.vitrineZones) do
        if zoneData.id then
            exports.ox_target:removeZone(zoneData.id)
        end
    end
end)