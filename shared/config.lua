Config = {}

-- DEBUG --
Config.Debug = false

Config.MissionPed = {
-- Mission Ped to Start a Mission
    model = "s_m_m_pilot_02",
    coords = vector4( -1525.75, -3214.18, 14.65, 296.61),
    createBlip = true,
}

Config.MinHealth = 50 -- Min Health before mission is cancelled
Config.Cooldown = 60 -- In Minutes

Config.Missions = {
    [1] = {
        ["vehicle"] = "dodo", -- Model
        ["vehicle_type"] = "plane", -- Vehicle Type
        ["veh_spawn"] = vector4( -1509.58, -3190.38, 14.75, 330.92), -- Where to spawn Aircraft
        ["delivery_location"] = vector4(1741.75, 3313.79, 41.22, 110.55), -- Delivery Location
        ["num_of_packages"] = 10, -- Number of Packages to Deliver
        ["payout"] = math.random(300, 1200), -- Random Payout for Mission
        ["park_plane"] = { -- Park Plane for Package Dropoff
            vector3(1740.47, 3304.67, 41.22),
            vector3(1726.52, 3300.73, 41.22),
            vector3(1721.7, 3317.86, 41.22),
            vector3(1738.44, 3322.08, 41.22)
        },
        ["take_plane_back"] = { -- Take Plane Back to Spawn Location for End of Mission
            vector3( -1528.54, -3188.61, 13.94),
            vector3( -1501.07, -3205.11, 13.94),
            vector3( -1490.74, -3189.97, 13.94),
            vector3( -1514.28, -3174.9, 13.94)
        }
    }
}
