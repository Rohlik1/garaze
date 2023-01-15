local recentVehicles = {}

ESX.RegisterServerCallback('rhlk_garages:getVehicles', function(source, cb, garage)
    local xPlayer = ESX.GetPlayerFromId(source)
    local vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? and type = ?', { xPlayer.identifier, Config.Garages[garage].Type })
    cb(vehicles)
end)

RegisterNetEvent('rhlk_garages:vehicleTakenOut')
AddEventHandler('rhlk_garages:vehicleTakenOut', function(plate)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.update.await('UPDATE owned_vehicles SET stored = 0 WHERE plate = ? and owner = ?', { plate, xPlayer.identifier })
    LogToDiscord(source, _U('webhook_take') .. '\n' .. _U('license_plate', plate))
end)

ESX.RegisterServerCallback('rhlk_garages:saveVehicle', function(source, cb, props)
    local xPlayer = ESX.GetPlayerFromId(source)
    local vehicle = MySQL.query.await('SELECT * FROM owned_vehicles WHERE plate = ? and owner = ?', { props.plate, xPlayer.identifier })
    if #vehicle == 0 then
        cb(false)
        return
    end
    if json.decode(vehicle[1].vehicle).model == props.model then
        cb(true)
        MySQL.update.await('UPDATE owned_vehicles SET vehicle = ?, stored = 1 WHERE plate = ?', { json.encode(props), props.plate })
        LogToDiscord(source, _U('webhook_save') .. '\n' .. _U('license_plate', props.plate))
        recentVehicles[props.plate] = nil
    else
        cb(false)
        print('Cheater is trying to change vehicle hash, identifier: ' .. xPlayer.identifier)
    end
end)

ESX.RegisterServerCallback('rhlk_garages:getImpoundedVehicles', function(source, cb, garage)
    local xPlayer = ESX.GetPlayerFromId(source)
    local vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? and type = ? and stored = 0', { xPlayer.identifier, Config.Garages[garage].Type })
    local impoundedVehicles = {}
    for k,v in ipairs(vehicles) do
        if recentVehicles[v.plate] == nil then
            table.insert(impoundedVehicles, v)
        end
    end
    cb(impoundedVehicles)
end)

ESX.RegisterServerCallback('rhlk_garages:returnVehicle', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getAccount('money').money >= Config.ImpoundPrice then
        xPlayer.removeAccountMoney('money', Config.ImpoundPrice)
        cb(true)
        LogToDiscord(source, _U('webhook_impound') .. '\n' .. _U('license_plate', plate))
        recentVehicles[plate] = true
        Citizen.SetTimeout(60000, function()
            recentVehicles[plate] = nil
        end)
    else
        cb(false)
    end
end)

function LogToDiscord(source, message)
    if Config.Webhook ~= 'WEBHOOK_HERE' then
        local xPlayer = ESX.GetPlayerFromId(source)
        local connect = {
            {
                ["color"] = "16768885",
                ["title"] = GetPlayerName(source).." (".. xPlayer.identifier ..")",
                ["description"] = message,
                ["footer"] = {
                ["text"] = os.date('%H:%M - %d. %m. %Y', os.time()),
                ["icon_url"] = 'https://cdn.discordapp.com/attachments/793081015433560075/1048643072952647700/lunar.png',
                },
            }
        }
        PerformHttpRequest(Config.Webhook, function(err, text, headers) end, 'POST', json.encode({username = "rhlk_garages", embeds = connect}), { ['Content-Type'] = 'application/json' })
    end
end
