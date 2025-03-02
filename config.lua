Config = {}

-- Global Settings
Config.Debug = true
Config.Discord = {
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
Config.Police = {
    Jobs = {"police", "sheriff"},
    BlipDuration = 5 -- minutes
}

-- Heist: Vangelico
Config.Vangelico = {
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
    
    -- Vitrines array will be populated in the client script
    Vitrines = {},
    
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
    
    -- Notifications
    Notifications = {
        Success = {
            title = "Vangelico Heist",
            type = "success",
            duration = 10000,
            position = "top"
        },
        Info = {
            title = "Vangelico Heist",
            type = "info",
            duration = 10000,
            position = "top"
        },
        Warning = {
            title = "Vangelico Heist",
            type = "warning", 
            duration = 10000,
            position = "top"
        },
        Error = {
            title = "Vangelico Heist",
            type = "error",
            duration = 10000,
            position = "top"
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

-- Heist: Car Stealing
Config.Car = {
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
    
    -- Delivery locations
    DeliveryLocations = {
        vec3(1686.24, 6435.92, 32.04),
        vec3(1598.48, 6568.4, 13.28),
        vec3(1427.92, 6594.32, 12.2),
        vec3(420.04, 6509.88, 27.4),
        vec3(1.28, 6466.12, 31.08),
        vec3(182.44, 6367.92, 31.08),
        vec3(-944.04, 5429.28, 37.8),
        vec3(-2253.44, 4305.88, 46.6),
        vec3(-2956.4, 59.12, 11.24),
        vec3(-2190.84, -419.04, 12.76),
        vec3(-883.12, -1488.24, 4.68),
        vec3(-948.68, -1090.56, 1.8),
        vec3(-853.84, -1094.28, 1.8),
        vec3(-461.2, -1030.88, 23.2),
        vec3(-15.4, -1031.44, 28.6),
        vec3(15.6, -576.08, 31.28),
        vec3(-667.76, -172.0, 37.32),
        vec3(-355.24, 35.88, 47.56),
        vec3(-160.64, 159.28, 77.16),
        vec3(-71.48, 191.0, 87.16),
        vec3(552.12, -143.84, 58.24),
        vec3(1141.2, -309.44, 68.64),
        vec3(1132.8, -792.56, 57.24),
        vec3(969.28, -1380.52, 20.92),
        vec3(412.52, -2066.24, 21.12),
        vec3(150.44, -2386.2, 5.64),
        vec3(126.88, -2508.56, 5.64),
        vec3(-93.28, -2577.16, 5.64),
        vec3(-256.56, -2680.88, 5.64)
    },
    
    -- Notifications
    Notifications = {
        Success = {
            title = "Car Heist",
            type = "success",
            duration = 10000,
            position = "top"
        },
        Info = {
            title = "Car Heist",
            type = "info",
            duration = 10000,
            position = "top"
        },
        Warning = {
            title = "Car Heist",
            type = "warning", 
            duration = 10000,
            position = "top"
        },
        Error = {
            title = "Car Heist",
            type = "error",
            duration = 10000,
            position = "top"
        }
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

-- Heist: Cargo Ship Infiltration
Config.CargoShip = {
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
    
    -- Loot configuration
    Loot = {
        Items = {
            { 
                name = "electronics", 
                value = {2000, 4000}, 
                weight = 2, 
                model = "prop_box_ammo03a"
            },
            { 
                name = "art_pieces", 
                value = {5000, 8000}, 
                weight = 3, 
                model = "prop_idol_case_01"
            },
            { 
                name = "exotic_materials", 
                value = {10000, 15000}, 
                weight = 5, 
                model = "prop_box_ammo07a"
            }
        },
        Spots = {
            -- Cargo hold loot positions
            vec3(1194.23, -2981.74, 5.90),
            vec3(1191.45, -2975.89, 5.90),
            vec3(1201.36, -2978.63, 5.90),
            vec3(1206.89, -2982.29, 5.90),
            vec3(1197.52, -2969.18, 5.90),
            vec3(1185.67, -2973.41, 5.90)
        },
        MaxCapacity = 20 -- Maximum weight carrier capacity
    },
    
    -- Required items
    RequiredItems = {
        Lockpick = { name = "advanced_lockpick", count = 1 },
        Hacking = { name = "hacking_device", count = 1 },
        WaterGear = { name = "diving_gear", count = 1 } -- For water approach
    },
    
    -- Escape points (different based on approach)
    EscapePoints = {
        vec3(1224.45, -2946.12, 5.90), -- Helicopter extraction
        vec3(1184.32, -3006.78, 5.90), -- Vehicle extraction
        vec3(1231.87, -2998.46, 0.10)  -- Boat extraction
    },
    
    -- Guard patrol routes and patterns
    Guards = {
        Models = {"s_m_m_security_01", "s_m_m_marine_01"},
        Weapons = {"WEAPON_PISTOL", "WEAPON_SMG"},
        PatrolRoutes = {
            -- Each route consists of multiple points
            {
                vec3(1202.34, -2962.54, 5.90),
                vec3(1195.67, -2970.23, 5.90),
                vec3(1188.43, -2978.89, 5.90),
                vec3(1205.78, -2980.55, 5.90)
            },
            {
                vec3(1215.45, -2957.89, 5.90),
                vec3(1222.78, -2967.34, 5.90),
                vec3(1210.56, -2978.90, 5.90)
            }
            -- Additional patrol routes
        }
    },
    
    -- Dispatch configuration
    Dispatch = {
        Silent = {
            Title = "10-37 - Suspicious Activity",
            Message = "Security reports suspicious activity at the docks",
            Blip = {
                Sprite = 455,
                Scale = 1.0,
                Color = 2,
                Text = "<font face = 'Oswald'>10-37",
                Time = 5,
                Radius = 0 -- No radius for stealth approach
            }
        },
        Loud = {
            Title = "10-90 - Armed Robbery",
            Message = "Armed robbery in progress at the cargo docks",
            Blip = {
                Sprite = 455,
                Scale = 1.0,
                Color = 1,
                Text = "<font face = 'Oswald'>10-90",
                Time = 5,
                Radius = 8
            }
        }
    },
    
    -- Difficulty scaling
    Difficulty = {
        Easy = { guardAccuracy = 0.5, hackTime = 20000, lootMultiplier = 0.8 },
        Medium = { guardAccuracy = 0.7, hackTime = 15000, lootMultiplier = 1.0 },
        Hard = { guardAccuracy = 0.9, hackTime = 10000, lootMultiplier = 1.2 }
    }
}

-- Helper function to check if a value exists in a table
function Config.HasValue(tab, val)
    for _, v in ipairs(tab) do
        if v == val then
            return true
        end
    end
    return false
end

-- Function to get a random element from a table
function Config.GetRandomElement(table)
    if #table == 0 then return nil end
    return table[math.random(1, #table)]
end

-- Function to get random coordinates with offset
function Config.GetRandomOffsetCoords(originalCoords, minOffset, maxOffset)
    local angle = math.random() * 2 * math.pi
    local distance = minOffset + math.random() * (maxOffset - minOffset)
    local offsetX = math.cos(angle) * distance
    local offsetY = math.sin(angle) * distance
    return vector3(originalCoords.x + offsetX, originalCoords.y + offsetY, originalCoords.z)
end

return Config