-- HomeTeleport 服务器端实现
require "HomeTeleport/Shared/HomeTeleport_Shared"

HomeTeleport.Server = HomeTeleport.Server or {}

-- 服务器端数据初始化
function HomeTeleport.Server.init()
    HomeTeleport.initGlobalData()
    
    -- 注册命令处理
    HomeTeleport.Server.registerCommands()
    
    -- 注册事件监听
    HomeTeleport.Server.registerEvents()
    
    print("[HomeTeleport] Server initialization completed")
end

-- 注册服务器命令处理
function HomeTeleport.Server.registerCommands()
    -- 客户端命令处理
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= HomeTeleport.COMMAND_MODULE then return end
        
        HomeTeleport.Server.handleClientCommand(player, command, args)
    end)
end

-- 注册事件监听
function HomeTeleport.Server.registerEvents()
    -- 玩家连接事件
    Events.OnPlayerConnect.Add(function(player)
        HomeTeleport.Server.onPlayerConnect(player)
    end)
    
    -- 玩家断开事件
    Events.OnPlayerDisconnect.Add(function(player)
        HomeTeleport.Server.onPlayerDisconnect(player)
    end)
    
    -- 游戏保存事件
    Events.OnSave.Add(function()
        HomeTeleport.Server.onGameSave()
    end)
end

-- 玩家连接处理
function HomeTeleport.Server.onPlayerConnect(player)
    if not player then return end
    
    print("[HomeTeleport] Player connected: " .. HomeTeleport.getPlayerKey(player))
    
    -- 初始化玩家数据
    local playerData = HomeTeleport.getPlayerData(player)
    
    -- 发送数据同步
    HomeTeleport.Server.sendPlayerDataSync(player, playerData)
end

-- 玩家断开处理
function HomeTeleport.Server.onPlayerDisconnect(player)
    if not player then return end
    
    print("[HomeTeleport] Player disconnected: " .. HomeTeleport.getPlayerKey(player))
    
    -- 保存玩家数据
    local playerData = HomeTeleport.getPlayerData(player)
    HomeTeleport.savePlayerData(player, playerData)
end

-- 游戏保存处理
function HomeTeleport.Server.onGameSave()
    print("[HomeTeleport] Game saved, synchronizing all player data")
    
    -- 保存所有在线玩家的数据
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local playerData = HomeTeleport.getPlayerData(player)
            HomeTeleport.savePlayerData(player, playerData)
        end
    end
    
    -- 保存世界数据
    local worldData = HomeTeleport.getWorldData()
    HomeTeleport.saveWorldData(worldData)
end

-- 发送玩家数据同步
function HomeTeleport.Server.sendPlayerDataSync(player, playerData)
    if not player or not playerData then return false end
    
    local syncData = {
        playerData = playerData,
        worldData = HomeTeleport.getWorldData()
    }
    
    HomeTeleport.sendServerCommand(player, HomeTeleport.SERVER_COMMANDS.DATA_SYNC, syncData)
    return true
end

-- 发送命令结果
function HomeTeleport.Server.sendCommandResult(player, success, message, command)
    if not player then return false end
    
    local resultData = {
        success = success,
        message = message or "",
        command = command or ""
    }
    
    HomeTeleport.sendServerCommand(player, HomeTeleport.SERVER_COMMANDS.COMMAND_RESULT, resultData)
    return true
end

-- 发送错误消息
function HomeTeleport.Server.sendErrorMessage(player, message)
    if not player then return false end
    
    HomeTeleport.sendServerCommand(player, HomeTeleport.SERVER_COMMANDS.ERROR_MESSAGE, {message = message})
    return true
end

-- 处理客户端命令
function HomeTeleport.Server.handleClientCommand(player, command, args)
    if not player then return end
    
    print("[HomeTeleport] Received client command: " .. command .. " from player: " .. HomeTeleport.getPlayerKey(player))
    
    -- 根据命令类型分发处理
    if command == HomeTeleport.CLIENT_COMMANDS.SET_HOME then
        HomeTeleport.Server.handleSetHome(player, args)
    elseif command == HomeTeleport.CLIENT_COMMANDS.GO_HOME then
        HomeTeleport.Server.handleGoHome(player, args)
    elseif command == HomeTeleport.CLIENT_COMMANDS.BIND_VEHICLE then
        HomeTeleport.Server.handleBindVehicle(player, args)
    elseif command == HomeTeleport.CLIENT_COMMANDS.UNBIND_VEHICLE then
        HomeTeleport.Server.handleUnbindVehicle(player, args)
    elseif command == HomeTeleport.CLIENT_COMMANDS.REQUEST_DATA then
        HomeTeleport.Server.handleRequestData(player, args)
    elseif command == HomeTeleport.CLIENT_COMMANDS.RETURN_VEHICLE then
        HomeTeleport.Server.handleReturnVehicle(player, args)
    else
        print("[HomeTeleport] Unknown command: " .. command)
        HomeTeleport.Server.sendErrorMessage(player, getText("UI_HomeTeleport_UnknownCommand") .. command)
    end
end

-- 处理设置家位置
function HomeTeleport.Server.handleSetHome(player, args)
    if not player then return end
    
    -- 检查沙盒配置
    local worldData = HomeTeleport.getWorldData()
    if worldData.UseSandboxHome then
        HomeTeleport.Server.sendCommandResult(player, false, getText("UI_HomeTeleport_SandboxLocked"), "setHome")
        return
    end
    
    -- 验证位置数据
    if not args or not args.position then
        HomeTeleport.Server.sendErrorMessage(player, getText("UI_HomeTeleport_InvalidPosition"))
        return
    end
    
    -- 基本类型检查
    if type(args.position) ~= "table" or not args.position.x or not args.position.y or not args.position.z then
        HomeTeleport.Server.sendErrorMessage(player, getText("UI_HomeTeleport_InvalidPosition"))
        return
    end
    
    -- 更新玩家数据
    local playerData = HomeTeleport.getPlayerData(player)
    playerData.homePosition = args.position
    playerData.isHomeSet = true
    
    HomeTeleport.savePlayerData(player, playerData)
    
    HomeTeleport.Server.sendCommandResult(player, true, getText("UI_HomeTeleport_SetSuccess"), "setHome")
    print("[HomeTeleport] Player " .. HomeTeleport.getPlayerKey(player) .. " set home position: " .. args.position.x .. "," .. args.position.y .. "," .. args.position.z)
end

-- 处理传送回家
function HomeTeleport.Server.handleGoHome(player, args)
    if not player then return end
    
    local playerData = HomeTeleport.getPlayerData(player)
    
    -- 检查家是否已设置
    if not playerData.isHomeSet then
        HomeTeleport.Server.sendCommandResult(player, false, getText("UI_HomeTeleport_NotSet"), "goHome")
        return
    end
    
    -- 检查玩家是否在车辆中
    local vehicle = player:getVehicle()
    if not vehicle then
        HomeTeleport.Server.sendCommandResult(player, false, getText("UI_HomeTeleport_MustInVehicle"), "goHome")
        return
    end
    
    -- 检查周围是否有僵尸
    local square = player:getCurrentSquare()
    if square then
        local zombies = square:getMovingObjects()
        for i = 0, zombies:size() - 1 do
            local zombie = zombies:get(i)
            if instanceof(zombie, "IsoZombie") then
                HomeTeleport.Server.sendCommandResult(player, false, getText("UI_HomeTeleport_ZombieNearby"), "goHome")
                return
            end
        end
    end
    
    -- 记录车辆信息
    if vehicle then
        local persistentId = HomeTeleport.ensureVehiclePersistentId(vehicle)
        
        playerData.wasInVehicle = true
        local seatIndex = 0
        
        -- 查找玩家座位
        for i = 0, 3 do
            if vehicle:getCharacter(i) == player then
                seatIndex = i
                break
            end
        end
        
        -- 记录位置和车辆信息
        playerData.wasInVehicleLastPos = {
            x = player:getX(),
            y = player:getY(),
            z = player:getZ(),
            persistentId = persistentId,
            seatIndex = seatIndex
        }
    else
        playerData.wasInVehicle = false
        playerData.wasInVehicleLastPos = nil
    end
    
    -- 执行传送
    player:setX(playerData.homePosition.x)
    player:setY(playerData.homePosition.y)
    player:setZ(playerData.homePosition.z)
    player:setLastX(playerData.homePosition.x)
    player:setLastY(playerData.homePosition.y)
    player:setLastZ(playerData.homePosition.z)
    
    -- 保存数据
    HomeTeleport.savePlayerData(player, playerData)
    
    HomeTeleport.Server.sendCommandResult(player, true, getText("UI_HomeTeleport_GoHomeSuccess"), "goHome")
    print("[HomeTeleport] Player " .. HomeTeleport.getPlayerKey(player) .. " teleported home")
end

-- 处理绑定车辆
function HomeTeleport.Server.handleBindVehicle(player, args)
    if not player or not args then return end
    
    local playerData = HomeTeleport.getPlayerData(player)
    
    -- 检查沙盒配置
    local worldData = HomeTeleport.getWorldData()
    if worldData.UseSandboxHome then
        HomeTeleport.Server.sendCommandResult(player, false, getText("UI_HomeTeleport_SandboxLocked"), "bindVehicle")
        return
    end
    
    -- 验证车辆数据
    if not args.vehicleId then
        HomeTeleport.Server.sendErrorMessage(player, getText("UI_HomeTeleport_InvalidVehicle"))
        return
    end
    
    -- 检查绑定限制
    local sandboxOptions = getSandboxOptions()
    local limitOption = sandboxOptions and sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")
    local limited = limitOption and limitOption:getValue()
    
    -- 如果更换了绑定车辆，重置返回数据
    if playerData.currentBoundVehicleId and playerData.currentBoundVehicleId ~= args.vehicleId then
        playerData.wasInVehicle = false
        playerData.wasInVehicleLastPos = nil
    end
    
    playerData.currentBoundVehicleId = args.vehicleId
    HomeTeleport.savePlayerData(player, playerData)
    
    HomeTeleport.Server.sendCommandResult(player, true, getText("UI_HomeTeleport_BindSuccess"), "bindVehicle")
    print("[HomeTeleport] Player " .. HomeTeleport.getPlayerKey(player) .. " bound vehicle: " .. args.vehicleId)
end

-- 处理解绑车辆
function HomeTeleport.Server.handleUnbindVehicle(player, args)
    if not player then return end
    
    local playerData = HomeTeleport.getPlayerData(player)
    
    if not args or not args.vehicleId then
        HomeTeleport.Server.sendErrorMessage(player, getText("UI_HomeTeleport_InvalidVehicle"))
        return
    end
    
    if playerData.currentBoundVehicleId == args.vehicleId then
        playerData.currentBoundVehicleId = nil
    end
    
    -- 清理相关数据
    if playerData.wasInVehicleLastPos and playerData.wasInVehicleLastPos.persistentId == args.vehicleId then
        playerData.wasInVehicle = false
        playerData.wasInVehicleLastPos = nil
    end
    
    HomeTeleport.savePlayerData(player, playerData)
    
    HomeTeleport.Server.sendCommandResult(player, true, getText("UI_HomeTeleport_UnbindSuccess"), "unbindVehicle")
    print("[HomeTeleport] Player " .. HomeTeleport.getPlayerKey(player) .. " unbound vehicle: " .. args.vehicleId)
end

-- 处理数据请求
function HomeTeleport.Server.handleRequestData(player, args)
    if not player then return end
    
    local playerData = HomeTeleport.getPlayerData(player)
    HomeTeleport.Server.sendPlayerDataSync(player, playerData)
end

-- 处理返回车辆
function HomeTeleport.Server.handleReturnVehicle(player, args)
    if not player then return end
    
    local playerData = HomeTeleport.getPlayerData(player)
    
    if not playerData.wasInVehicle or not playerData.wasInVehicleLastPos then
        HomeTeleport.Server.sendCommandResult(player, false, getText("UI_HomeTeleport_NoLastPos"), "returnVehicle")
        return
    end
    
    local pos = playerData.wasInVehicleLastPos
    
    -- 先传送到记录的位置
    player:setX(pos.x)
    player:setY(pos.y)
    player:setZ(pos.z)
    player:setLastX(pos.x)
    player:setLastY(pos.y)
    player:setLastZ(pos.z)
    
    HomeTeleport.Server.sendCommandResult(player, true, getText("UI_HomeTeleport_ReturnSuccess"), "returnVehicle")
    print("[HomeTeleport] Player " .. HomeTeleport.getPlayerKey(player) .. " returned to vehicle position")
end

-- 服务器初始化
Events.OnServerStarted.Add(function()
    HomeTeleport.Server.init()
end)