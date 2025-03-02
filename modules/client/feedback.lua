local FeedbackSystem = {}

-- Utility reference
local Utils = exports[GetCurrentResourceName()]:GetSharedUtils()
local ClientUtils = exports[GetCurrentResourceName()]:GetClientUtils()

-- Configuration for feedback effects
local feedbackConfig = {
    sounds = {
        Unlock = {name = "Door_Unlock", set = "DTAK_Hacking_Gameplay_Sounds"},
        Lock = {name = "Door_Lock", set = "DTAK_Hacking_Gameplay_Sounds"},
        Success = {name = "Hack_Success", set = "dlc_xm_silo_laser_hack_sounds"},
        Failure = {name = "Hack_Fail", set = "dlc_xm_silo_laser_hack_sounds"},
        Loot = {name = "Crate_Collect", set = "GTAO_Magnate_Boss_Modes_Soundset"}
    },
    particles = {
        Success = {
            asset = "scr_xs_celebration",
            effect = "scr_xs_confetti_burst",
            scale = 1.0,
            duration = 2000
        },
        Failure = {
            asset = "core",
            effect = "exp_grd_grenade_smoke",
            scale = 0.5,
            duration = 1000
        },
        Unlock = {
            asset = "scr_ornate_heist",
            effect = "scr_heist_ornate_thermal_burn",
            scale = 0.5,
            duration = 1500
        }
    },
    notifications = {
        success = {
            title = "Success",
            type = "success",
            duration = 5000,
            position = "top-right"
        },
        warning = {
            title = "Warning",
            type = "warning",
            duration = 5000,
            position = "top-right"
        },
        error = {
            title = "Error",
            type = "error",
            duration = 5000,
            position = "top-right"
        },
        info = {
            title = "Info",
            type = "info",
            duration = 5000,
            position = "top-right"
        }
    }
}

-- Show success notification with unlock animation
function FeedbackSystem.ShowUnlock(message, coords)
    -- Play sound
    FeedbackSystem.PlaySound("Unlock")
    
    -- Show notification
    lib.notify({
        title = feedbackConfig.notifications.success.title,
        description = message,
        type = feedbackConfig.notifications.success.type,
        duration = feedbackConfig.notifications.success.duration,
        position = feedbackConfig.notifications.success.position
    })
    
    -- Play particle effect if coords provided
    if coords then
        FeedbackSystem.PlayParticleEffect("Unlock", coords)
    end
end

-- Show failure notification
function FeedbackSystem.ShowFailure(message, coords)
    -- Play sound
    FeedbackSystem.PlaySound("Failure")
    
    -- Show notification
    lib.notify({
        title = feedbackConfig.notifications.error.title,
        description = message,
        type = feedbackConfig.notifications.error.type,
        duration = feedbackConfig.notifications.error.duration,
        position = feedbackConfig.notifications.error.position
    })
    
    -- Play particle effect if coords provided
    if coords then
        FeedbackSystem.PlayParticleEffect("Failure", coords)
    end
end

-- Show loot collection notification with animation
function FeedbackSystem.ShowLoot(message, coords)
    -- Play sound
    FeedbackSystem.PlaySound("Loot")
    
    -- Show notification
    lib.notify({
        title = feedbackConfig.notifications.success.title,
        description = message,
        type = feedbackConfig.notifications.success.type,
        duration = feedbackConfig.notifications.success.duration,
        position = feedbackConfig.notifications.success.position
    })
    
    -- Show sparkle animation on screen
    if not coords then
        -- Default to center-right of screen for UI feedback
        TriggerEvent('pNotify:SendNotification', {
            text = '<img src="img/success.gif" style="max-width: 50px; max-height: 50px;">',
            type = 'success',
            timeout = 3000,
            layout = 'centerRight',
            queue = 'right'
        })
    else
        -- Play particle effect at coords
        FeedbackSystem.PlayParticleEffect("Success", coords)
    end
end

-- Play sound by name
function FeedbackSystem.PlaySound(soundName)
    if not feedbackConfig.sounds[soundName] then return end
    
    local sound = feedbackConfig.sounds[soundName]
    PlaySoundFrontend(-1, sound.name, sound.set, false)
end

-- Play sound at specific coordinates
function FeedbackSystem.PlaySoundAtCoords(soundName, coords, range)
    if not feedbackConfig.sounds[soundName] or not coords then return end
    
    local sound = feedbackConfig.sounds[soundName]
    PlaySoundFromCoord(-1, sound.name, coords.x, coords.y, coords.z, sound.set, false, range or 10.0, false)
end

-- Play particle effect
function FeedbackSystem.PlayParticleEffect(effectName, coords, rotation)
    if not feedbackConfig.particles[effectName] or not coords then return end
    
    local effect = feedbackConfig.particles[effectName]
    rotation = rotation or vector3(0.0, 0.0, 0.0)
    
    -- Request the particle effect
    if not HasNamedPtfxAssetLoaded(effect.asset) then
        RequestNamedPtfxAsset(effect.asset)
        while not HasNamedPtfxAssetLoaded(effect.asset) do
            Citizen.Wait(10)
        end
    end
    
    -- Start particle effect
    SetPtfxAssetNextCall(effect.asset)
    local ptfx = StartParticleFxLoopedAtCoord(
        effect.effect,
        coords.x, coords.y, coords.z,
        rotation.x, rotation.y, rotation.z,
        effect.scale or 1.0,
        false, false, false, false
    )
    
    -- Stop after duration
    if effect.duration then
        Citizen.SetTimeout(effect.duration, function()
            StopParticleFxLooped(ptfx, 0)
        end)
    end
    
    return ptfx
end

-- Show 3D text in world
function FeedbackSystem.Show3DText(text, coords, duration, scale)
    if not coords then return end
    
    scale = scale or 0.35
    duration = duration or 5000
    
    Citizen.CreateThread(function()
        local endTime = GetGameTimer() + duration
        
        while GetGameTimer() < endTime do
            ClientUtils.Draw3DText(coords, text, scale)
            Citizen.Wait(0)
        end
    end)
end

-- Show countdown timer
function FeedbackSystem.ShowCountdown(duration, message, coords)
    if duration <= 0 then return end
    
    Citizen.CreateThread(function()
        local endTime = GetGameTimer() + (duration * 1000)
        
        while GetGameTimer() < endTime do
            local remaining = math.ceil((endTime - GetGameTimer()) / 1000)
            local text = message .. ": " .. remaining
            
            if coords then
                ClientUtils.Draw3DText(coords, text, 0.4)
            else
                -- Draw on screen
                SetTextScale(0.5, 0.5)
                SetTextFont(4)
                SetTextColour(255, 255, 255, 255)
                SetTextOutline()
                SetTextEntry("STRING")
                AddTextComponentString(text)
                DrawText(0.5, 0.85)
            end
            
            if remaining <= 5 and remaining > 0 then
                -- Play warning beep for last 5 seconds
                PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", false)
                
                if remaining == 1 then
                    -- Vibrate controller for last second
                    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.2)
                end
            end
            
            Citizen.Wait(0)
        end
        
        -- Final sound
        PlaySoundFrontend(-1, "Hack_Failed", "DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS", false)
    end)
end

-- Flash entity briefly
function FeedbackSystem.FlashEntity(entity, duration)
    if not DoesEntityExist(entity) then return end
    
    duration = duration or 3000
    
    NetworkRegisterEntityAsNetworked(entity)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(entity), false)
    SetEntityAlpha(entity, 0, false)
    
    local startTime = GetGameTimer()
    local endTime = startTime + duration
    
    Citizen.CreateThread(function()
        while GetGameTimer() < endTime do
            -- Calculate alpha based on time
            local timeLeft = endTime - GetGameTimer()
            local normalizedTime = 1.0 - (timeLeft / duration)
            local alpha = math.floor(255 * (0.5 + 0.5 * math.cos(normalizedTime * 10)))
            
            SetEntityAlpha(entity, alpha, false)
            Citizen.Wait(25)
        end
        
        -- Reset entity
        ResetEntityAlpha(entity)
    end)
end

-- Show camera shake effect
function FeedbackSystem.ShakeCamera(shakeType, intensity, duration)
    shakeType = shakeType or "SMALL_EXPLOSION_SHAKE"
    intensity = intensity or 0.5
    duration = duration or 1000
    
    ShakeGameplayCam(shakeType, intensity)
    
    Citizen.SetTimeout(duration, function()
        StopGameplayCamShaking(true)
    end)
end

-- Add a brief screen effect
function FeedbackSystem.ScreenEffect(effectName, duration)
    effectName = effectName or "DrugsTrevorClownsFight"
    duration = duration or 5000
    
    StartScreenEffect(effectName, 0, false)
    
    Citizen.SetTimeout(duration, function()
        StopScreenEffect(effectName)
    end)
end

return FeedbackSystem