ESX = exports["es_extended"]:getSharedObject()

local FullyLoaded = LocalPlayer.state.isLoggedIn

local missionPed = {
    spawned = false,
    ped = nil,
}

local deliveryPed = {
    spawned = false,
    ped = nil,
}

local deliveryBlip = nil
local pedBlip = nil

local isInDelivery = false
local currentDelivery = nil
local checkVehicleDamage = false
local isHoldingPackage = false

local parkPlaneZone = {
    inZone = false,
    zone = nil,
    noSpamming = false,
}

local packagesLeft = 0

local onCooldown = false


local vehNetId = nil

local function startCooldown()
    onCooldown = true
    SetTimeout(Config.Cooldown * 60000, function()
        onCooldown = false
    end)
end


local function createDeliveryBlip()
    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    deliveryBlip = AddBlipForCoord(currentDelivery.delivery_location.x, currentDelivery.delivery_location.y,
            currentDelivery.delivery_location.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipColour(deliveryBlip, 5)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, 5)
    SetBlipScale(deliveryBlip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Delivery Dropoff')
    EndTextCommandSetBlipName(deliveryBlip)
end

local function createPedBlip()
    if pedBlip ~= nil then
        RemoveBlip(pedBlip)
        pedBlip = nil
    end
    pedBlip = AddBlipForCoord(Config.MissionPed.coords.x, Config.MissionPed.coords.y,
            Config.MissionPed.coords.z)
    SetBlipSprite(pedBlip, 90)
    SetBlipColour(pedBlip, 5)
    SetBlipScale(pedBlip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Air Deliveries')
    EndTextCommandSetBlipName(pedBlip)
end

local function createDropOffPed(coords)
    if deliveryPed.spawned then return end
    local model = joaat(Config.MissionPed.model)

    lib.requestModel(model)

    local coords = coords
    local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1, coords.w, false, false)

    deliveryPed.ped = ped

    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_STAND_IMPATIENT', 0, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local options = {
        {
            name = 'airdelivs:dropOffPackage',
            label = 'Drop off Package',
            icon = 'fa-solid fa-box',
            event = 'qw_airdeliveries:client:dropOffPackage',
            canInteract = function(_, distance)
                return distance < 2.0 and isHoldingPackage
            end
        }
    }

    exports.ox_target:addLocalEntity(deliveryPed.ped, options)

    deliveryPed.spawned = true
end

local function deleteDropOffPed()
    if not deliveryPed.spawned then return end

    exports.ox_target:removeLocalEntity(deliveryPed.ped, { 'airdelivs:dropOffPackage' })

    DeleteEntity(deliveryPed.ped)
    deliveryPed.spawned = false
    deliveryPed.ped = nil
end

local function parkPlane()
    if parkPlaneZone.noSpamming then return end

    checkVehicleDamage = false

    local dropOffCoords = currentDelivery.delivery_location
    createDropOffPed(dropOffCoords)

    lib.notify({
        title = 'Air Deliveries',
        description = 'You have parked the plane. You can now grab the packages and deliver them.',
        type = 'success'
    })

    local veh = NetToVeh(vehNetId)

    Wait(1000)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)

    parkPlaneZone.noSpamming = true

    local distanceFromVehicle = #(GetEntityCoords(cache.ped) - GetEntityCoords(veh))

    exports.ox_target:addEntity(vehNetId, {
        {
            name = 'qw_airdeliveries:takeOutPackage',
            event = 'qw_airdeliveries:client:takeOutPackage',
            icon = 'fa-solid fa-box',
            label = 'Grab Package',
            canInteract = function(_, distance)
                return distance < 2.0 and distanceFromVehicle < 5.0 and parkPlaneZone.inZone and packagesLeft > 0 and
                    not isHoldingPackage
            end
        }
    })
end

RegisterNetEvent('qw_airdeliveries:client:newAirDeliv', function()
    if isInDelivery then return end

    if onCooldown then
        lib.notify({
            title = 'Air Deliveries',
            description = 'You cannot do that right now.',
            type = 'error'
        })
        return
    end

    local delivery = Config.Missions[math.random(1, #Config.Missions)]
    currentDelivery = delivery
    packagesLeft = delivery.num_of_packages
    isInDelivery = true
    checkVehicleDamage = true
    TriggerServerEvent('qw_airdeliveries:server:spawnVehicle', delivery.vehicle, delivery.veh_spawn,
        delivery.vehicle_type)
end)

RegisterNetEvent('qw_airdeliveries:client:takeOutPackage', function()
    if not isInDelivery and not parkPlaneZone.inZone then return end

    if packagesLeft > 0 then
        exports.scully_emotemenu:PlayByCommand('box')
        packagesLeft = packagesLeft - 1
        isHoldingPackage = true

        lib.notify({
            title = 'Air Deliveries',
            description = 'You have taken out a package. Deliver it to the dropoff location. (' ..
            packagesLeft .. ' packages left)',
            type = 'success'
        })
    end
end)

RegisterNetEvent('qw_airdeliveries:client:dropOffPackage', function()
    if lib.progressBar({
            duration = 5000,
            label = 'Delivering Package',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
            },
        }) then
        exports.scully_emotemenu:CancelAnimation()
        isHoldingPackage = false

        lib.notify({
            description = 'Package Dropped Off',
            type = 'success'
        })

        if packagesLeft == 0 then
            lib.notify({
                title = 'Air Deliveries',
                description = 'That was your last package. Take your plane back to the airport.',
                type = 'success'
            })

            TriggerEvent('qw_airdeliveries:client:takePlaneBack')
        end
    end
end)

local function returnPlane()
    if parkPlaneZone.noSpamming then return end

    lib.notify({
        title = 'Air Deliveries',
        description = 'You have parked the plane. Please talk to the worker to get your payment. Thanks Again!',
        type = 'success'
    })

    local veh = NetToVeh(vehNetId)

    Wait(1000)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)

    parkPlaneZone.noSpamming = true

    exports.ox_target:addLocalEntity(missionPed.ped, {
        {
            name = 'qw_airdeliveries:finishMission',
            event = 'qw_airdeliveries:client:finishMission',
            icon = 'fa-solid fa-check',
            label = 'Return Plane and Get Paid',
            canInteract = function(_, distance)
                return distance < 2.0
            end
        }
    })
end

local function createReturnZone()
    if parkPlaneZone.zone ~= nil then
        parkPlaneZone.zone:remove()
        parkPlaneZone.zone = nil
        parkPlaneZone.noSpamming = false
    end

    parkPlaneZone.zone = lib.zones.poly({
            points = currentDelivery.take_plane_back,
            thickness = 2,
            debug = Config.Debug,
            inside = function()
                parkPlaneZone.inZone = true
            end,
            onEnter = function()
                parkPlaneZone.inZone = true
                returnPlane()
            end,
            onExit = function()
                parkPlaneZone.inZone = false
            end,
        })
end

RegisterNetEvent('qw_airdeliveries:client:takePlaneBack', function()
    checkVehicleDamage = true
    local veh = NetToVeh(vehNetId)

    if veh ~= nil then
        FreezeEntityPosition(veh, false)
        SetEntityInvincible(veh, false)
    end

    createReturnZone()
end)

RegisterNetEvent('qw_airdeliveries:client:finishMission', function()
    if not isInDelivery then return end

    exports.ox_target:removeLocalEntity(missionPed.ped, { 'qw_airdeliveries:finishMission' })

    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end

    if parkPlaneZone.zone ~= nil then
        parkPlaneZone.zone:remove()
        parkPlaneZone.zone = nil
        lib.hideTextUI()
    end

    if deliveryPed.spawned then
        deleteDropOffPed()
    end

    isInDelivery = false
    packagesLeft = 0
    vehNetId = nil
    parkPlaneZone.noSpamming = false
    checkVehicleDamage = false

    lib.notify({
        title = 'Air Deliveries',
        description = 'You have finished the delivery. You have been paid $' .. currentDelivery.payout .. '.',
        type = 'success'
    })

    TriggerServerEvent('qw_airdeliveries:server:finishMission', currentDelivery.payout)

    currentDelivery = nil
    startCooldown()
end)

local function createParkZone()
    if parkPlaneZone.zone ~= nil then
        parkPlaneZone.zone = nil
    end

    parkPlaneZone.zone = lib.zones.poly({
            points = currentDelivery.park_plane,
            thickness = 2,
            debug = Config.Debug,
            inside = function()
                parkPlaneZone.inZone = true
                lib.showTextUI('Air Deliveries')
            end,
            onEnter = function()
                parkPlaneZone.inZone = true
                parkPlane()
            end,
            onExit = function()
                parkPlaneZone.inZone = false
                lib.hideTextUI()
            end,
        })
end

RegisterNetEvent('qw_airdeliveries:client:beginDeliveryMission', function()
    if not isInDelivery then return end

    lib.notify({
        title = 'Air Deliveries',
        description = 'You have been given a delivery route. Deliver the packages to the dropoff location.',
        type = 'success'
    })

    createDeliveryBlip()
    createParkZone()
end)

local function spawnDelivPed()
    if missionPed.spawned then return end
    local model = joaat(Config.MissionPed.model)

    lib.requestModel(model)

    local coords = Config.MissionPed.coords
    local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1, coords.w, false, false)

    missionPed.ped = ped

    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_STAND_IMPATIENT', 0, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local options = {
        {
            name = 'airdelivs:getDelivery',
            label = 'Request a Delivery Route',
            icon = 'fa-solid fa-plane',
            event = 'qw_airdeliveries:client:newAirDeliv',
            canInteract = function(_, distance)
                return distance < 2.0 and not isInDelivery
            end
        }
    }

    exports.ox_target:addLocalEntity(missionPed.ped, options)

    missionPed.spawned = true
end

local function deleteDelivPed()
    if not missionPed.spawned then return end

    exports.ox_target:removeLocalEntity(missionPed.ped, { 'airdelivs:getDelivery' })

    DeleteEntity(missionPed.ped)
    missionPed.ped = nil

    missionPed.spawned = false
end

local function failedMission()
    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end

    if deliveryPed.spawned then
        deleteDropOffPed()
    end

    if parkPlaneZone.zone ~= nil then
        parkPlaneZone.zone:remove()
        parkPlaneZone.zone = nil
    end

    isInDelivery = false
    packagesLeft = 0
    vehNetId = nil
    currentDelivery = nil
    parkPlaneZone.noSpamming = false
    parkPlaneZone.inZone = false
    parkPlaneZone.zone = nil
    checkVehicleDamage = false

    Wait(5000)

    TriggerServerEvent('qw_airdeliveries:server:failedMission')
end


AddStateBagChangeHandler('deliveryVehicle', nil, function(bagName, key, value)
    local ent = GetEntityFromStateBagName(bagName)
    if ent == 0 then return end

    if NetworkGetEntityOwner(ent) == cache.playerId then
        while not HasCollisionLoadedAroundEntity(ent) do Wait(100) end

        PlaceObjectOnGroundProperly(ent)

        vehNetId = VehToNet(ent)

        local plate = GetVehicleNumberPlateText(ent)

        TriggerEvent("vehiclekeys:client:SetOwner", plate)
        TriggerEvent('qw_airdeliveries:client:beginDeliveryMission')
    end
end)

CreateThread(function()
    while true do
        if not isInDelivery and not vehNetId and not checkVehicleDamage then
            Wait(10000)
        else
            local veh = NetToVeh(vehNetId)

            if GetVehicleHealthPercentage(veh) < Config.MinHealth then
                failedMission()
                lib.notify({
                    title = 'Air Deliveries',
                    description = 'Your vehicle has been damaged too much. You have failed the mission.',
                    type = 'error'
                })
            end
        end

        Wait(5000)
    end
end)


AddStateBagChangeHandler('isLoggedIn', nil, function(_, _, value)
    FullyLoaded = value
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer, isNew)
    Wait(100)
    spawnDelivPed()
    if Config.MissionPed.createBlip then createPedBlip() end
end)

RegisterNetEvent('esx:playerLogout')
AddEventHandler('esx:playerLogout', function()
	deleteDelivPed()
    deleteDropOffPed()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not FullyLoaded then return end
    Wait(100)
    spawnDelivPed()
    if Config.MissionPed.createBlip then createPedBlip() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deleteDelivPed()
    deleteDropOffPed()
    lib.hideTextUI()
    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    if pedBlip ~= nil then
        RemoveBlip(pedBlip)
        pedBlip = nil
    end
    if parkPlaneZone.zone ~= nil then
        parkPlaneZone.zone:remove()
        parkPlaneZone.zone = nil
    end
end)
