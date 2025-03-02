HeistConfig = {}

-- Global Settings
HeistConfig.Debug = true
HeistConfig.Discord = {
    Enabled = true,
    Webhook = "https://discord.com/api/webhooks/1334560648931053648/YkAw3rEUzW8nApLnb3fKQiR926BbsXPuunadGTLokYp_jC0uESdpAKcB-jPb-lEbAaVb",
    Colors = {
        Success = 3066993,  -- Green
        Info = 3447003,     -- Blue
        Warning = 15105570, -- Yellow
        Error = 15158332    -- Red
    }
}

-- Police Settings
HeistConfig.Police = {
    Jobs = {"police", "sheriff"},
    BlipDuration = 5, -- minutes
    MinimumCops = 0   -- Global default, can be overridden per heist
}

-- Global Notification Settings
HeistConfig.Notifications = {
    Success = {
        type = "success",
        duration = 5000,
        position = "top"
    },
    Info = {
        type = "info",
        duration = 5000,
        position = "top"
    },
    Warning = {
        type = "warning", 
        duration = 5000,
        position = "top"
    },
    Error = {
        type = "error",
        duration = 5000,
        position = "top"
    }
}

-- Centralized Loot System
HeistConfig.LootTables = {
    -- Common items (can be used across multiple heists)
    Common = {
        { name = 'water', min = 1, max = 3, chance = 40, value = 10 },
        { name = 'bread', min = 1, max = 3, chance = 40, value = 10 },
        { name = 'phone', min = 1, max = 1, chance = 20, value = 100 }
    },
    -- Tools and utility items
    Tools = {
        { name = 'lockpick', min = 1, max = 2, chance = 30, value = 150 },
        { name = 'screwdriver', min = 1, max = 1, chance = 25, value = 75 },
        { name = 'hammer', min = 1, max = 1, chance = 25, value = 50 },
        { name = 'drill', min = 1, max = 1, chance = 20, value = 300 },
        { name = 'crowbar', min = 1, max = 1, chance = 20, value = 200 }
    },
    -- Valuable items
    Valuables = {
        { name = 'jewels', min = 1, max = 3, chance = 60, value = 1000 },
        { name = 'goldbar', min = 1, max = 1, chance = 30, value = 5000 },
        { name = 'rolex', min = 1, max = 2, chance = 40, value = 2000 },
        { name = 'diamond', min = 1, max = 1, chance = 20, value = 3000 }
    },
    -- Weapons and ammo
    Weapons = {
        { name = 'pistol_ammo', min = 5, max = 15, chance = 30, value = 100 },
        { name = 'pistol', min = 1, max = 1, chance = 10, value = 10000 }
    },
    -- Heist specific items
    HeistItems = {
        { name = 'thermite', min = 1, max = 1, chance = 30, value = 1500 },
        { name = 'hackerdevice', min = 1, max = 1, chance = 20, value = 2000 },
        { name = 'c4', min = 1, max = 1, chance = 10, value = 3000 }
    }
}

-- Create heist-specific loot tables by combining items
HeistConfig.CreateLootTable = function(categories, rarityTiers)
    local lootTable = {}
    
    -- Example rarityTiers:
    -- {
    --   {chance = 50, categories = {"Common"}, itemCount = {min = 1, max = 3}},
    --   {chance = 30, categories = {"Common", "Tools"}, itemCount = {min = 1, max = 2}},
    --   {chance = 15, categories = {"Tools", "Valuables"}, itemCount = {min = 1, max = 2}},
    --   {chance = 5, categories = {"Valuables", "Weapons"}, itemCount = {min = 1, max = 1}}
    -- }
    
    for _, tier in ipairs(rarityTiers) do
        local tierItems = {}
        
        -- Collect all items from specified categories for this tier
        for _, category in ipairs(tier.categories) do
            if HeistConfig.LootTables[category] then
                for _, item in ipairs(HeistConfig.LootTables[category]) do
                    table.insert(tierItems, item)
                end
            end
        end
        
        -- Add the tier with its items to the loot table
        table.insert(lootTable, {
            items = tierItems,
            chance = tier.chance,
            itemCount = tier.itemCount
        })
    end
    
    return lootTable
end

-- Individual Heist Configurations
HeistConfig.Vangelico = {
    Title = "Vangelico Heist",
    AirVent = vec3(-636.5263, -213.0241, 53.6815),
    GasTime = 4, -- Gas duration in minutes
    RobberyTime = 300, -- Time limit for robbery in seconds
    GlobalCooldown = 900, -- Cooldown period in seconds (15 minutes)
    RequiredCops = 0, -- Minimum number of cops required
    MaxDistance = 20, -- Maximum distance from vent to start heist
    Rewards = {
        JewelsMin = 1,
        JewelsMax = 8
    },
    
    -- Required items
    RequiredItems = {
        Drill = {
            name = "drill",
            count = 1
        },
        Thermite = {
            name = "thermite",
            count = 1
        }
    },
    
    -- Dispatch configuration
    Dispatch = {
        Title = "10-68 - Klenotnictví Vangelico",
        Message = "Místní hlásí ozbrojenou loupež v klenotnictví",
        Coords = vec3(-628.1216, -235.1860, 38.0570),
        Blip = {
            Sprite = 674,
            Scale = 1.0,
            Color = 3,
            Text = "<font face = 'Oswald'>10-68 - Klenotnictví",
            Time = 5,
            Radius = 4
        }
    }
}

HeistConfig.Car = {
    Title = "Car Heist",
    GlobalCooldown = 15, -- Cooldown in minutes
    RequiredCops = 0,
    MaxDistance = 20, -- Maximum distance from NPC to start heist
    Spawnpoint = vec4(667.0213, 237.1434, 94.1216, 238.8701),
    NPCModel = 'mp_m_waremech_01',
    NPCpoint = vec4(668.0691, 605.2586, 129.0510, 78.2066),
    
    -- Vehicle list
    Vehicles = {
        "italigto", "zentorno", "t20", "tempesta", "osiris", "reaper", 
        "fmj", "turismor", "infernus", "vacca", "cheetah", "entityxf", 
        "adder", "nero", "nero2", "penetrator", "bullet", "voltic", 
        "comet2", "comet3", "comet4", "comet5", "comet6", "comet7"
    },
    
    -- License plate for stolen cars
    LicensePlate = "H315TUWU",
    
    -- Rewards
    Rewards = {
        Min = 20000, -- Higher minimum reward
        Max = 50000, -- Higher maximum reward
        Multiplier = "vehicle_health" -- Will be multiplied by vehicle health percentage
    },
    
    -- Delivery locations - shortened for readability
    DeliveryLocations = {
        vec3(1686.24, 6435.92, 32.04),
        vec3(1598.48, 6568.4, 13.28),
        vec3(1427.92, 6594.32, 12.2)
        -- Add all your existing locations
    },
    
    -- Dispatch configuration
    Dispatch = {
        Title = "10-14 - Podezřelé vozidlo",
        Message = "Podezřelé vozidlo v okolí, dejte na něj pozor!",
        Blip = {
            sprite = 161,
            scale = 1.0,
            color = 3,
            text = "<font face = 'Oswald'>10-14 - Podezřelé vozidlo",
            time = 5,
            radius = 8
        }
    }
}

HeistConfig.CargoShip = {
    Title = "Cargo Ship Heist",
    RequiredCops = 2,
    GlobalCooldown = 45, -- Cooldown in minutes
    MaxDistance = 20, -- Maximum distance for interactions
    
    -- Heist starter NPC
    NPCModel = 'g_m_y_dockwork_01',
    NPCpoint = vec4(851.376, -3140.012, 5.900, 90.84), -- Docks area
    
    -- Ship coordinates and details
    ShipLocation = vec3(1204.89, -2989.43, 5.90), -- Ship dock position
    ShipModel = "apa_mp_apa_yacht", -- Can be replaced with a cargo ship model
    
    -- Different approach points
    ApproachPoints = {
        { 
            name = "main_entrance", 
            coords = vec3(1209.35, -2955.70, 5.90),
            label = "Main Entrance",
            difficulty = "Hard",
            guardCount = 4
        },
        { 
            name = "cargo_area", 
            coords = vec3(1178.91, -2972.22, 5.90),
            label = "Cargo Area",
            difficulty = "Medium",
            guardCount = 3
        },
        { 
            name = "water_approach", 
            coords = vec3(1222.77, -2988.92, 0.10),
            label = "Water Approach",
            difficulty = "Easy",
            guardCount = 1
        }
    },
    
    -- Time limit for heist completion
    TimeLimit = 15 * 60, -- 15 minutes
    
    -- Loot configuration - using the centralized loot system
    Loot = {
        Items = HeistConfig.CreateLootTable(
            {"Valuables", "HeistItems"}, 
            {
                {chance = 50, categories = {"Common"}, itemCount = {min = 1, max = 3}},
                {chance = 30, categories = {"Tools"}, itemCount = {min = 1, max = 2}},
                {chance = 15, categories = {"Valuables"}, itemCount = {min = 1, max = 2}},
                {chance = 5, categories = {"HeistItems"}, itemCount = {min = 1, max = 1}}
            }
        ),
        MaxCapacity = 20 -- Maximum weight carrier capacity
    }
    
    -- Other configuration options...
}

HeistConfig.Trailers = {
    Title = "Container Heist",
    RequiredCops = 0,
    GlobalCooldown = 10, -- Cooldown in minutes
    MaxDistance = 15, -- Maximum detection distance
    
    -- Container models that can be robbed
    ContainerModels = {
        'prop_container_01a',
        'prop_container_01b',
        'prop_truktrailer_01a',
        'prop_container_side',
        'prop_container_ld_pu',
        'prop_container_03mb'
    },
    
    -- Robbery Settings
    MaxDaily = 5,            -- Maximum robberies per restart
    MinigameTime = 15,       -- Seconds to complete the minigame
    MinigameDifficulty = 3,  -- Difficulty level (1-5)
    RequiredTool = 'crowbar', -- Tool required to open containers
    
    -- Loot configuration - using the centralized loot system
    Loot = HeistConfig.CreateLootTable(
        {"Common", "Tools", "Valuables", "Weapons"}, 
        {
            {chance = 50, categories = {"Common"}, itemCount = {min = 1, max = 3}},
            {chance = 30, categories = {"Common", "Tools"}, itemCount = {min = 1, max = 2}},
            {chance = 15, categories = {"Tools", "Valuables"}, itemCount = {min = 1, max = 2}},
            {chance = 5, categories = {"Valuables", "Weapons"}, itemCount = {min = 1, max = 1}}
        }
    ),
    
    -- Dispatch configuration
    Dispatch = {
        Title = "10-31 - Podezřelá aktivita",
        Message = "Hlášena podezřelá aktivita v okolí nákladních kontejnerů",
        Blip = {
            sprite = 67,
            scale = 1.0,
            color = 2,
            text = "<font face = 'Oswald'>10-31 - Podezřelá aktivita",
            time = 5,
            radius = 5
        }
    }
}

-- Helper functions
HeistConfig.HasValue = function(tab, val)
    for _, v in ipairs(tab) do
        if v == val then
            return true
        end
    end
    return false
end

HeistConfig.GetRandomElement = function(table)
    if #table == 0 then return nil end
    return table[math.random(1, #table)]
end

HeistConfig.GetRandomOffsetCoords = function(originalCoords, minOffset, maxOffset)
    local angle = math.random() * 2 * math.pi
    local distance = minOffset + math.random() * (maxOffset - minOffset)
    local offsetX = math.cos(angle) * distance
    local offsetY = math.sin(angle) * distance
    return vector3(originalCoords.x + offsetX, originalCoords.y + offsetY, originalCoords.z)
end

return HeistConfig