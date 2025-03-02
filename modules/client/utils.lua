local ClientUtils = {}

local SharedUtils = exports[GetCurrentResourceName()]:GetSharedUtils()

-- Animation handler with prop support
function ClientUtils.PlayAnimationWithProp(dict, anim, propModel, boneIndex, offset, rotation, duration, flags)
    local ped = PlayerPedId()
    local prop = nil
    
    -- Request animation dictionary
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Citizen.Wait(10)
        end
    end
    
    -- Create prop if requested
    if propModel and boneIndex then
        -- Load the prop model
        local propHash = GetHashKey(propModel)
        RequestModel(propHash)
        while not HasModelLoaded(propHash) do
            Citizen.Wait(10)
        end
        
        -- Create and attach prop
        local pedCoords = GetEntityCoords(ped)
        prop = CreateObject(propHash, pedCoords.x, pedCoords.y, pedCoords.z + 0.2, true, true, true)
        
        -- Set offset defaults
        offset = offset or vector3(0.0, 0.0, 0.0)
        rotation = rotation or vector3(0.0, 0.0, 0.0)
        
        -- Attach prop to ped
        AttachEntityToEntity(
            prop, ped, 
            GetPedBoneIndex(ped, boneIndex), 
            offset.x, offset.y, offset.z, 
            rotation.x, rotation.y, rotation.z, 
            true, true, false, true, 1, true
        )
    end
    
    -- Play animation
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, flags or 0, 0, false, false, false)
    
    -- Wait for animation to complete if duration is provided
    if duration then
        Citizen.Wait(duration)
        ClearPedTasks(ped)
        
        -- Clean up prop
        if prop then
            DeleteEntity(prop)
        end
    end
    
    return prop
end

-- Enhanced particle effect creator
function ClientUtils.CreateParticleEffect(assetName, effectName, coords, rot, scale, duration)
    -- Request particle effect
    if not HasNamedPtfxAssetLoaded(assetName) then
        RequestNamedPtfxAsset(assetName)
        while not HasNamedPtfxAssetLoaded(assetName) do
            Citizen.Wait(10)
        end
    end
    
    -- Set default values
    rot = rot or vector3(0.0, 0.0, 0.0)
    scale = scale or 1.0
    
    -- Start particle effect
    SetPtfxAssetNextCall(assetName)
    local effect = StartParticleFxLoopedAtCoord(
        effectName,
        coords.x, coords.y, coords.z,
        rot.x, rot.y, rot.z,
        scale,
        false, false, false, false
    )
    
    -- Stop effect after duration if provided
    if duration and duration > 0 then
        Citizen.SetTimeout(duration, function()
            StopParticleFxLooped(effect, 0)
        end)
    end
    
    return effect
end

-- Create an explosion with optional camera shake
function ClientUtils.CreateExplosionEffect(coords, type, size, audioFlag, cameraShake)
    type = type or 4 -- Default: EXPLOSION_GRENADE
    size = size or 1.0
    audioFlag = audioFlag or true
    cameraShake = cameraShake or 0.0
    
    AddExplosion(
        coords.x, coords.y, coords.z,
        type,
        size,
        audioFlag,
        false,
        cameraShake
    )
end

-- Create synchronized scene with entities
function ClientUtils.CreateSyncScene(coords, rotation, entities, anims)
    local scene = NetworkCreateSynchronisedScene(
        coords.x, coords.y, coords.z,
        rotation.x, rotation.y, rotation.z,
        2, false, false, 1065353216, 0, 1.0
    )
    
    -- Add entities to scene
    if entities and anims then
        for i, entity in ipairs(entities) do
            local entityType = GetEntityType(entity)
            local anim = anims[i]
            
            if entityType == 1 then -- Ped
                NetworkAddPedToSynchronisedScene(
                    entity, scene,
                    anim.dict, anim.name,
                    anim.speed or 1.5,
                    anim.speedMultiplier or -4.0,
                    anim.flag or 1,
                    anim.playbackRate or 16,
                    anim.duration or 1148846080
                )
            else -- Object
                NetworkAddEntityToSynchronisedScene(
                    entity, scene,
                    anim.dict, anim.name,
                    anim.speed or 4.0,
                    anim.speedMultiplier or -8.0,
                    anim.flag or 1
                )
            end
        end
    end
    
    return scene
end

-- Play sound at coordinates
function ClientUtils.PlaySound(soundName, soundSet, coords, range)
    range = range or 10.0
    
    if coords then
        -- Play sound at location
        PlaySoundFromCoord(-1, soundName, coords.x, coords.y, coords.z, soundSet, false, range, false)
    else
        -- Play sound from player
        PlaySound(-1, soundName, soundSet, 0, 0, 1)
    end
end

-- Create a blip with configuration options
function ClientUtils.CreateBlip(coords, sprite, color, scale, text, route, flash)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    -- Configure blip
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale or 1.0)
    SetBlipColour(blip, color or 1)
    SetBlipAsShortRange(blip, true)
    
    -- Set blip text
    if text then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(text)
        EndTextCommandSetBlipName(blip)
    end
    
    -- Set route
    if route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, color or 1)
    end
    
    -- Set flash
    if flash then
        SetBlipFlashes(blip, true)
    end
    
    return blip
end

-- Check if player is in a vehicle
function ClientUtils.IsInVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

-- Get current vehicle if in one
function ClientUtils.GetCurrentVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return nil
    end
    return GetVehiclePedIsIn(ped, false)
end

-- Check if player has a weapon type equipped
function ClientUtils.HasWeaponType(weaponType)
    -- Weapon types: 
    -- 0: Unarmed, 1: Melee, 2: Pistol, 3: SMG, 4: Rifle, 5: Shotgun, 6: Sniper, 7: Heavy, 8: Thrown, 9: Special
    return GetPedWeaponTypeFromSlot(PlayerPedId(), weaponType) ~= 0
end

-- Draw 3D text in the world
function ClientUtils.Draw3DText(coords, text, size, font)
    local camCoords = GetGameplayCamCoord()
    local distance = #(coords - camCoords)
    
    -- Scale size based on distance
    size = size or 0.35
    local scale = (size / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    
    -- Set text properties
    SetTextScale(0.0, scale)
    SetTextFont(font or 0)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    
    -- Render text
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Create a text UI element
function ClientUtils.ShowTextUI(text, options)
    lib.showTextUI(text, options or {
        position = "bottom-center",
    })
end

-- Hide text UI
function ClientUtils.HideTextUI()
    lib.hideTextUI()
end

-- Dispatch notification utility
function ClientUtils.NotifyPolice(title, message, coords, blip)
    TriggerServerEvent('hcyk_heists:notifyPolice', {
        title = title,
        message = message,
        coords = coords,
        blip = blip
    })
end

-- Show help text
function ClientUtils.ShowHelpText(text, duration)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, duration or -1)
end

-- Check if coordinates are visible to player
function ClientUtils.IsCoordVisible(coords)
    local result, onScreen = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    return result and onScreen
end

-- Get heading between two coordinates
function ClientUtils.GetHeadingBetweenCoords(coords1, coords2)
    return GetHeadingFromVector_2d(coords2.x - coords1.x, coords2.y - coords1.y)
end

return ClientUtils