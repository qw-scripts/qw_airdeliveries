local QBCore = exports['qb-core']:GetCoreObject()
local deliveryVehicles = {}

RegisterNetEvent('qw_airdeliveries:server:failedMission', function() 

    local src = source

    for k, v in pairs(deliveryVehicles) do
        if v.owner == src then
            local veh = NetworkGetEntityFromNetworkId(v.netId)
            if DoesEntityExist(veh) then
                DeleteEntity(veh)
            end
            deliveryVehicles[k] = nil
        end
    end
end)

RegisterNetEvent('qw_airdeliveries:server:finishMission', function(payout)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    for k, v in pairs(deliveryVehicles) do
        if v.owner == src then
            local veh = NetworkGetEntityFromNetworkId(v.netId)
            if DoesEntityExist(veh) then
                DeleteEntity(veh)
            end
            deliveryVehicles[k] = nil
        end
    end

    Player.Functions.AddMoney('bank', payout, "air-delivery")
end)

RegisterNetEvent('qw_airdeliveries:server:spawnVehicle', function(model, coords, vehicleType)

    local model = model
    local vehicleType = vehicleType
    local coords = coords
    local hash = joaat(model)
    local src = source

    local veh = CreateVehicleServerSetter(hash, vehicleType, coords.x, coords.y, coords.z, coords.w)

    local Checks = 0

    while not DoesEntityExist(veh) do
        if Checks == 10 then break end
        Wait(25)
        Checks += 1
    end

    if DoesEntityExist(veh) then
        local netId = NetworkGetNetworkIdFromEntity(veh)

            Entity(veh).state.deliveryVehicle = true

            deliveryVehicles[#deliveryVehicles+1] = {
                netId = netId,
                owner = src,
            }
    end

end)