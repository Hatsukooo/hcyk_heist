local ESX = exports['es_extended']:getSharedObject()

-- State management
local PlayerData = {}
local heistState = {
    isActive = false,
    cooldown = false,
    vehicleData = nil, -- Will store the current vehicle info
    deliveryCoords = nil,
    deliveryBlip = nil,
    deliveryZone = nil,
    stolenVehicle = nil,
    isInDeliveryZone = false,
    trackingBlip = nil,
    isBeingTracked = false
}

-- Utility functions
local function debugLog(message, ...)
    if Config.Debug then 
        print("[DEBUG] [Car Heist] " .. string.format(message, ...))
    end
end

local function notify(type, message)
    local notifConfig = Config.Car.Notifications[type]
    if not notifConfig then
        notifConfig = Config.Car.Notifications.Info
    end
    
    lib.notify({
        title = notifConfig.title,
        description = message,
        type = notifConfig.type,
        duration = notifConfig.duration,
        position = notifConfig.position
    })
end

-- Initialize player data
Citizen.CreateThread(function()
    debugLog("Initializing car heist script")
    
    while ESX.GetPlayerData().job == nil do
        debugLog("Waiting for player job data")
        Citizen.Wait(100)
    end
    
    PlayerData = ESX.GetPlayerData()
    debugLog("Player data initialized: %s", ESX.DumpTable(PlayerData.job))
    
    CreateHeistNPC()
end)

-- Handle job changes
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    debugLog("Player job updated: %s", ESX.DumpTable(job))
end)

-- Create the heist NPC
function CreateHeistNPC()
    debugLog("Creating heist NPC")
    
    -- Request the model
    local model = Config.Car.NPCModel
    local pedHash = GetHashKey(model)
    
    RequestModel(pedHash)
    while not HasModelLoaded(pedHash) do
        debugLog("Waiting for NPC model to load")
        RequestModel(pedHash)
        Citizen.Wait(100)
    end
    
    -- Create the ped
    local ped = CreatePed(4, pedHash, 
        Config.Car.NPCpoint.x, 
        Config.Car.NPCpoint.y, 
        Config.Car.NPCpoint.z - 1, 
        Config.Car.NPCpoint.w, 
        false, true)
    
    debugLog("NPC created with handle %s", ped)
    
    -- Configure the ped
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, Config.Car.NPCpoint.w)
    SetModelAsNoLongerNeeded(pedHash)
    
    -- Add interaction target
    AddTargetToNPC(ped)
    
    debugLog("NPC setup complete")
end

-- Add ox_target to the NPC
function AddTargetToNPC(ped)
    debugLog("Adding target options to NPC")
    
    local options = {
        {
            id = 'start_car_heist',
            label = 'Zahájit krádež vozidla',
            icon = 'fa-solid fa-car',
            distance = 2.0,
            onSelect = function(data)
                StartCarHeist()
            end
        }
    }
    
    exports.ox_target:addLocalEntity(ped, options)
    debugLog("Target options added to NPC")
end

-- Start the car heist
function StartCarHeist()
    debugLog("Attempting to start car heist")
    
    -- Check police count
    ESX.TriggerServerCallback('hcyk_heists:car:pdcount', function(policeCount)
        if policeCount >= Config.Car.RequiredCops then
            if not heistState.isActive and not heistState.cooldown then
                notify('Info', 'Na tomto místě se nachází auto, které můžeš ukrást. Buď opatrný, mohou tě tam čekat cajti!')
                
                -- Setup the delivery location
                GenerateDeliveryCoords()
                AddDeliveryBlip()
                GenerateVehicle()
                SpawnVehicle()
                
                -- Update server about the heist status
                TriggerServerEvent('hcyk_heists:car:stealing', true)
                heistState.isActive = true
                
                -- Set cooldown and notify police
                TriggerServerEvent('hcyk_heists:car:changeStatus', 'Cooldown', true)
                TriggerServerEvent('hcyk_heists:car:notifycops', heistState.deliveryCoords)
            else
                notify('Warning', 'Ztrať se než tě pobodám!')
            end
        else
            notify('Error', 'Nedostatek policistů ve službě!')
        end
    end)
end

-- Generate random delivery coordinates
function GenerateDeliveryCoords()
    debugLog("Generating delivery coordinates")
    
    heistState.deliveryCoords = Config.GetRandomElement(Config.Car.DeliveryLocations)
    debugLog("Delivery coordinates set: %s", ESX.DumpTable(heistState.deliveryCoords))
end

-- Add blip for the delivery location
function AddDeliveryBlip()
    debugLog("Adding delivery blip")
    
    heistState.deliveryBlip = exports['hcyk_blips']:addBlip('deliveryblip', 'Místo doručení', heistState.deliveryCoords, {
        blip = 645,
        type = 4,
        scale = 0.8,
        color = 0,
    })
    
    SetBlipRoute(heistState.deliveryBlip, true)
    debugLog("Delivery blip added and route set")
end

-- Generate a random vehicle for the heist
function GenerateVehicle()
    debugLog("Generating vehicle type")
    
    local vehicleModel = Config.GetRandomElement(Config.Car.Vehicles)
    heistState.vehicleData = {
        model = vehicleModel,
        hash = GetHashKey(vehicleModel)
    }
    
    debugLog("Vehicle selected: %s (Hash: %s)", vehicleModel, heistState.vehicleData.hash)
end

-- Spawn the target vehicle
function SpawnVehicle()
    debugLog("Spawning target vehicle")
    
    -- Request the vehicle model
    local vehicleHash = heistState.vehicleData.hash
    RequestModel(vehicleHash)
    
    while not HasModelLoaded(vehicleHash) do
        debugLog("Waiting for vehicle model to load")
        Citizen.Wait(50)
    end
    
    -- Create the vehicle
    local vehicle = CreateVehicle(
        vehicleHash, 
        heistState.deliveryCoords.x, 
        heistState.deliveryCoords.y, 
        heistState.deliveryCoords.z, 
        heistState.deliveryCoords.w, 
        true, false)
    
    if not DoesEntityExist(vehicle) then
        debugLog("Failed to spawn vehicle")
        return
    end
    
    -- Configure the vehicle
    SetVehicleNumberPlateText(vehicle, Config.Car.LicensePlate)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDoorsLocked(vehicle, 2) -- Lock the vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Store the vehicle reference
    heistState.stolenVehicle = vehicle
    
    -- Clean up model memory
    SetModelAsNoLongerNeeded(vehicleHash)
    
    -- Add interaction to the vehicle
    AddTargetToVehicle(vehicle)
    debugLog("Vehicle spawned with handle %s", vehicle)
end

-- Add target interaction to the vehicle
function AddTargetToVehicle(vehicle)
    debugLog("Adding target options to vehicle")
    
    local options = {
        {
            id = 'unlock_vehicle',
            label = 'Rozšifrovat zámek',
            icon = 'fas fa-lock',
            distance = 2.0,
            onSelect = function(data)
                UnlockVehicle(vehicle)
            end
        }
    }
    
    exports.ox_target:addLocalEntity(vehicle, options)
    debugLog("Target options added to vehicle")
end

-- Unlock the stolen vehicle
function UnlockVehicle(vehicle)
    debugLog("Attempting to unlock vehicle %s", vehicle)
    
    -- Start the minigame
    exports["memorygame"]:thermiteminigame(10, 3, 3, 10, 
        function() -- Success callback
            SetVehicleDoorsLocked(vehicle, 1) -- Unlock the vehicle
            notify('Success', 'Zámek odemčen!')
            
            -- Remove target from vehicle
            exports.ox_target:removeLocalEntity(vehicle)
            exports['hcyk_blips']:removeBlip('deliveryblip')
            
            -- Generate new delivery coordinates
            GenerateDeliveryCoords()
            AddDeliveryBlip()
            
            -- Create the delivery marker after a short delay
            Citizen.Wait(1000)
            CreateDeliveryZone()
            
            -- Start police tracking
            TriggerServerEvent('hcyk_heists:car:startalertcops')
        end,
        function() -- Failure callback
            notify('Error', 'Nepodařilo se odemknout zámek!')
        end
    )
end

-- Create the delivery zone
function CreateDeliveryZone()
    debugLog("Creating delivery zone")
    
    -- Create a circular zone for vehicle delivery
    TriggerEvent('poly:createCircleZone', 'carthief', heistState.deliveryCoords, 2.0, {
        id = 'cardelivered',
        minZ = heistState.deliveryCoords.z - 1.0,
        maxZ = heistState.deliveryCoords.z + 1.0,
        marker = { model = `edynu_marker2`, drawDist = 50 }
    })
    
    debugLog("Delivery zone created")
end

-- Function for delivering the vehicle
function DeliverVehicle()
    debugLog("Vehicle delivery initiated")
    
    local playerPed = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(playerPed, false)
    local plate = GetVehicleNumberPlateText(currentVehicle)
    
    -- Create a thread to watch for key press
    CreateThread(function()
        lib.showTextUI('[E] Odevzdání vozidla', {
            position = "right-center",
            icon = 'warehouse',
            style = { 
                borderRadius = 10
            }
        })
        
        while heistState.isInDeliveryZone do
            Wait(0)
            if IsControlJustReleased(0, 38) then -- E key
                -- Check if in correct vehicle and not moving too fast
                if plate == Config.Car.LicensePlate and GetEntitySpeed(currentVehicle) < 3.0 then
                    CompleteDelivery(currentVehicle)
                else
                    if plate ~= Config.Car.LicensePlate then
                        notify('Error', 'Musíš sem dojet tím vozidlem, co jsi dostal!')
                    else
                        notify('Error', 'Zastav úplně vozidlo!')
                    end
                end
            end
        end
    end)
end

-- Find the CompleteDelivery function and update the reward calculation:
function CompleteDelivery(vehicle)
    debugLog("Completing vehicle delivery")
    
    -- Clean up the zone and blip
    TriggerEvent('poly:removeZone', 'carthief', 'cardelivered')
    exports['hcyk_blips']:removeBlip('deliveryblip')
    
    -- Notify success
    notify('Success', 'Vozidlo bylo úspěšně odevzdáno!')
    
    -- Stop police tracking
    TriggerServerEvent('hcyk_heists:car:stopalertcops')
    
    -- Calculate reward based on vehicle health (with much higher values)
    local vehicleHealth = GetVehicleHealthPercentage(vehicle)
    local baseReward = math.random(Config.Car.Rewards.Min, Config.Car.Rewards.Max)
    local finalReward = math.ceil(baseReward * vehicleHealth)
    
    TriggerServerEvent('hcyk_heists:car:givereward', finalReward)
    
    -- Delete the vehicle
    SetEntityAsNoLongerNeeded(vehicle)
    DeleteEntity(vehicle)
    
    -- Reset state
    heistState.isActive = false
    TriggerServerEvent('hcyk_heists:car:stealing', false)
    lib.hideTextUI()
    
    debugLog("Vehicle delivered successfully with reward: $" .. finalReward)
end

    function GetVehicleHealthPercentage(vehicle)
    if not DoesEntityExist(vehicle) then return 0 end
    
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    
    return (bodyHealth + engineHealth) / 2000
end

-- Zone event handlers
AddEventHandler('poly:enter', function(name, data, center)
    debugLog("Entered zone: %s", name)
    
    if name == 'carthief' and data.id == 'cardelivered' then
        heistState.isInDeliveryZone = true
        DeliverVehicle()
    end
end)

AddEventHandler('poly:exit', function(name, data)
    debugLog("Exited zone: %s", name)
    
    if name == 'carthief' then
        heistState.isInDeliveryZone = false
        lib.hideTextUI()
    end
end)

-- Check if player is a cop
function IsPlayerCop()
    return PlayerData.job and (PlayerData.job.name == "police" or PlayerData.job.name == "sheriff")
end

-- Register network events
RegisterNetEvent('hcyk_heists:car:changeStatus')
AddEventHandler('hcyk_heists:car:changeStatus', function(status, value)
    debugLog("Status change received: %s = %s", status, tostring(value))
    
    if status == 'Cooldown' then
        heistState.cooldown = value
        debugLog("Cooldown status updated to %s", tostring(heistState.cooldown))
    end
end)

RegisterNetEvent('hcyk_heists:car:startalertcops')
AddEventHandler('hcyk_heists:car:startalertcops', function(thiefServerId)
    debugLog("Received start alert for thief ID: " .. thiefServerId)
    
    if not IsPlayerCop() then
        debugLog("Ignoring alert - player is not police")
        return
    end
    
    if heistState.trackingBlip then
        RemoveBlip(heistState.trackingBlip)
        heistState.trackingBlip = nil
    end
    
    local thiefPlayer = GetPlayerFromServerId(thiefServerId)
    if thiefPlayer == -1 then
        debugLog("Thief player not found, creating generic blip")
        local genericBlip = AddBlipForCoord(-621.0, -230.0, 38.0)
        heistState.trackingBlip = genericBlip
    else
        local thiefPed = GetPlayerPed(thiefPlayer)
        if not DoesEntityExist(thiefPed) then
            debugLog("Thief ped doesn't exist")
            return
        end
        
        local thiefBlip = AddBlipForEntity(thiefPed)
        heistState.trackingBlip = thiefBlip
    end
    
    SetBlipSprite(heistState.trackingBlip, 161)
    SetBlipScale(heistState.trackingBlip, 1.5)
    SetBlipColour(heistState.trackingBlip, 1)
    SetBlipAsShortRange(heistState.trackingBlip, false)
    SetBlipDisplay(heistState.trackingBlip, 2)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("<font face = 'Oswald'>[~r~PD~w~] Lokátor")
    EndTextCommandSetBlipName(heistState.trackingBlip)
    
    SetBlipRotation(heistState.trackingBlip, 0)
    SetBlipRoute(heistState.trackingBlip, true)
    SetBlipRouteColour(heistState.trackingBlip, 1)
    
    debugLog("Tracking blip created and configured")
    
    heistState.isBeingTracked = true
    Citizen.CreateThread(function()
        debugLog("Starting tracking thread")
        
        while heistState.isBeingTracked do
            Citizen.Wait(2000) 
            
            if DoesBlipExist(heistState.trackingBlip) then
                local thiefPlayer = GetPlayerFromServerId(thiefServerId)
                if thiefPlayer ~= -1 then
                    local thiefPed = GetPlayerPed(thiefPlayer)
                    if DoesEntityExist(thiefPed) then
                        if not IsBlipAttachedToEntity(heistState.trackingBlip) then
                            local updatedCoords = GetEntityCoords(thiefPed)
                            SetBlipCoords(heistState.trackingBlip, updatedCoords.x, updatedCoords.y, updatedCoords.z)
                        end
                    end
                end
            else
                -- Blip was deleted somehow, stop tracking
                debugLog("Blip no longer exists, stopping tracking")
                heistState.isBeingTracked = false
            end
        end
        
        debugLog("Tracking thread ended")
    end)
end)

RegisterNetEvent('hcyk_heists:car:stopalertcops')
AddEventHandler('hcyk_heists:car:stopalertcops', function()
    debugLog("Received stop alert")
    
    -- Remove tracking blip
    if heistState.trackingBlip then
        RemoveBlip(heistState.trackingBlip)
        heistState.trackingBlip = nil
        debugLog("Tracking blip removed")
    end
    
    heistState.isBeingTracked = false
    debugLog("Tracking stopped")
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Clean up UI elements
    lib.hideTextUI()
    
    -- Clean up any existing blips
    if heistState.deliveryBlip then
        exports['hcyk_blips']:removeBlip('deliveryblip')
    end
    
    if heistState.trackingBlip then
        RemoveBlip(heistState.trackingBlip)
    end
    
    -- Clean up zones
    if heistState.deliveryZone then
        TriggerEvent('poly:removeZone', 'carthief', 'cardelivered')
    end
    
    debugLog("Resource stopped, cleanup complete")
end)