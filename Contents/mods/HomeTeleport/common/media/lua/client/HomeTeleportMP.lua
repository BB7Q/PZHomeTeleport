-- HomeTeleport 多人模式客户端实现
require "HomeTeleport/Shared/HomeTeleport_Shared"

HomeTeleport.MP = HomeTeleport.MP or {}

-- 客户端数据缓存
HomeTeleport.MP.playerData = {
    homePosition = {x = 0, y = 0, z = 0},
    isHomeSet = false,
    wasInVehicle = false,
    wasInVehicleLastPos = nil,
    currentBoundVehicleId = nil
}

HomeTeleport.MP.worldData = {
    SandboxHome = {x = 0, y = 0, z = 0},
    UseSandboxHome = false
}

HomeTeleport.MP.isDataSynced = false

-- 客户端初始化
function HomeTeleport.MP.init()
    -- 注册命令处理
    HomeTeleport.MP.registerCommands()
    
    -- 注册事件监听
    HomeTeleport.MP.registerEvents()
    
    -- 请求数据同步
    HomeTeleport.MP.requestDataSync()
    
    print("[HomeTeleport] Multiplayer client initialized")
end

-- 注册服务器命令处理
function HomeTeleport.MP.registerCommands()
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= HomeTeleport.COMMAND_MODULE then return end
        
        HomeTeleport.MP.handleServerCommand(command, args)
    end)
end

-- 注册事件监听
function HomeTeleport.MP.registerEvents()
    -- 游戏开始事件
    Events.OnGameStart.Add(function()
        HomeTeleport.MP.onGameStart()
    end)
    
    -- 玩家更新事件（用于车辆座位重入）
    Events.OnPlayerUpdate.Add(function(player)
        HomeTeleport.MP.onPlayerUpdate(player)
    end)
end

-- 游戏开始处理
function HomeTeleport.MP.onGameStart()
    -- 延迟请求数据同步，确保服务器已准备好
    local function delayedSync()
        HomeTeleport.MP.requestDataSync()
        Events.OnTick.Remove(delayedSync)
    end
    Events.OnTick.Add(delayedSync)
end

-- 玩家更新处理（用于车辆座位重入）
function HomeTeleport.MP.onPlayerUpdate(player)
    if not player or player ~= getPlayer() then return end
    
    -- 检查是否有待处理的座位重入
    if HomeTeleport.MP.pendingSeatReentry then
        HomeTeleport.MP.trySeatReentry(player)
    end
end

-- 处理服务器命令
function HomeTeleport.MP.handleServerCommand(command, args)
    print("[HomeTeleport] Received server command: " .. command)
    
    if command == HomeTeleport.SERVER_COMMANDS.DATA_SYNC then
        HomeTeleport.MP.handleDataSync(args)
    elseif command == HomeTeleport.SERVER_COMMANDS.DATA_UPDATE then
        HomeTeleport.MP.handleDataUpdate(args)
    elseif command == HomeTeleport.SERVER_COMMANDS.COMMAND_RESULT then
        HomeTeleport.MP.handleCommandResult(args)
    elseif command == HomeTeleport.SERVER_COMMANDS.ERROR_MESSAGE then
        HomeTeleport.MP.handleErrorMessage(args)
    else
        print("[HomeTeleport] Unknown server command: " .. command)
    end
end

-- 处理数据同步
function HomeTeleport.MP.handleDataSync(args)
    if not args then return end
    
    -- 更新玩家数据
    if args.playerData then
        HomeTeleport.MP.playerData = args.playerData
    end
    
    -- 更新世界数据
    if args.worldData then
        HomeTeleport.MP.worldData = args.worldData
    end
    
    HomeTeleport.MP.isDataSynced = true
    print("[HomeTeleport] Data synchronization completed")
end

-- 处理数据更新
function HomeTeleport.MP.handleDataUpdate(args)
    if not args then return end
    
    -- 更新玩家数据
    if args.playerData then
        HomeTeleport.MP.playerData = args.playerData
    end
    
    print("[HomeTeleport] Data update completed")
end

-- 处理命令结果
function HomeTeleport.MP.handleCommandResult(args)
    if not args then return end
    
    local player = getPlayer()
    if not player then return end
    
    -- 显示结果消息
    if args.message and args.message ~= "" then
        player:Say(args.message)
    end
    
    -- 处理成功命令
    if args.success then
        if args.command == HomeTeleport.CLIENT_COMMANDS.GO_HOME then
            -- 回家命令成功后，开始座位重入尝试
            HomeTeleport.MP.startSeatReentry()
        end
    end
    
    print("[HomeTeleport] Command execution result: " .. (args.success and "Success" or "Failed") .. " - " .. (args.message or ""))
end

-- 处理错误消息
function HomeTeleport.MP.handleErrorMessage(args)
    if not args then return end
    
    local player = getPlayer()
    if not player then return end
    
    if args.message then
        player:Say(args.message)
        print("[HomeTeleport] Error message: " .. args.message)
    end
end

-- 请求数据同步
function HomeTeleport.MP.requestDataSync()
    HomeTeleport.sendClientCommand(HomeTeleport.CLIENT_COMMANDS.REQUEST_DATA, {})
    print("[HomeTeleport] Requesting data synchronization")
end

-- 设置家位置（多人模式）
function HomeTeleport.MP.setHome()
    local player = getPlayer()
    if not player then return end
    
    -- 检查是否已同步数据
    if not HomeTeleport.MP.isDataSynced then
        player:Say(getText("UI_HomeTeleport_DataNotSynced"))
        return
    end
    
    -- 检查沙盒配置
    if HomeTeleport.MP.worldData.UseSandboxHome then
        player:Say(getText("UI_HomeTeleport_SandboxLocked"))
        return
    end
    
    local position = {
        x = player:getX(),
        y = player:getY(),
        z = player:getZ()
    }
    
    -- 发送设置家命令
    HomeTeleport.sendClientCommand(HomeTeleport.CLIENT_COMMANDS.SET_HOME, {
        position = position
    })
end

-- 传送回家（多人模式）
function HomeTeleport.MP.goHome()
    local player = getPlayer()
    if not player then return end
    
    -- 检查是否已同步数据
    if not HomeTeleport.MP.isDataSynced then
        player:Say(getText("UI_HomeTeleport_DataNotSynced"))
        return
    end
    
    -- 检查家是否已设置
    if not HomeTeleport.MP.playerData.isHomeSet then
        player:Say(getText("UI_HomeTeleport_NotSet"))
        return
    end
    
    -- 检查是否在车辆中
    if not player:getVehicle() then
        player:Say(getText("UI_HomeTeleport_MustInVehicle"))
        return
    end
    
    -- 发送回家命令
    HomeTeleport.sendClientCommand(HomeTeleport.CLIENT_COMMANDS.GO_HOME, {})
end

-- 绑定车辆（多人模式）
function HomeTeleport.MP.bindVehicle(vehicle)
    local player = getPlayer()
    if not player or not vehicle then return false end
    
    -- 检查是否已同步数据
    if not HomeTeleport.MP.isDataSynced then
        player:Say(getText("UI_HomeTeleport_DataNotSynced"))
        return false
    end
    
    -- 检查沙盒配置
    if HomeTeleport.MP.worldData.UseSandboxHome then
        player:Say(getText("UI_HomeTeleport_SandboxLocked"))
        return false
    end
    
    local vehicleId = HomeTeleport.ensureVehiclePersistentId(vehicle)
    
    -- 发送绑定车辆命令
    HomeTeleport.sendClientCommand(HomeTeleport.CLIENT_COMMANDS.BIND_VEHICLE, {
        vehicleId = vehicleId
    })
    
    return true
end

-- 返回车辆位置（多人模式）
function HomeTeleport.MP.returnToLastPosition()
    local player = getPlayer()
    if not player then return end
    
    -- 检查是否已同步数据
    if not HomeTeleport.MP.isDataSynced then
        player:Say(getText("UI_HomeTeleport_DataNotSynced"))
        return
    end
    
    if not HomeTeleport.MP.playerData.wasInVehicle or not HomeTeleport.MP.playerData.wasInVehicleLastPos then
        player:Say(getText("UI_HomeTeleport_NoLastPos"))
        return
    end
    
    -- 发送返回车辆命令
    HomeTeleport.sendClientCommand(HomeTeleport.CLIENT_COMMANDS.RETURN_VEHICLE, {})
end

-- 开始座位重入尝试
function HomeTeleport.MP.startSeatReentry()
    if not HomeTeleport.MP.playerData.wasInVehicleLastPos then return end
    
    HomeTeleport.MP.pendingSeatReentry = {
        persistentId = HomeTeleport.MP.playerData.wasInVehicleLastPos.persistentId,
        seatIndex = HomeTeleport.MP.playerData.wasInVehicleLastPos.seatIndex or 0,
        attempts = 0,
        maxAttempts = 60  -- 最多尝试60次（约30秒）
    }
    
    print("[HomeTeleport] Starting seat re-entry attempt")
end

-- 尝试座位重入
function HomeTeleport.MP.trySeatReentry(player)
    if not HomeTeleport.MP.pendingSeatReentry then return end
    
    local pending = HomeTeleport.MP.pendingSeatReentry
    pending.attempts = pending.attempts + 1
    
    -- 超过最大尝试次数，放弃重入
    if pending.attempts > pending.maxAttempts then
        print("[HomeTeleport] Seat re-entry timeout, giving up attempt")
        HomeTeleport.MP.pendingSeatReentry = nil
        return
    end
    
    -- 在玩家周围3x3范围内搜索车辆
    for i = -1, 1 do
        for k = -1, 1 do
            local sq = getCell():getGridSquare(player:getX() + i, player:getY() + k, player:getZ())
            if sq then
                local vehicle = sq:getVehicleContainer()
                if vehicle ~= nil then
                    local vmd = vehicle:getModData()
                    if vmd.homeTeleport_persistentId then
                        local storedId = tostring(vmd.homeTeleport_persistentId)
                        local targetId = tostring(pending.persistentId)
                        if storedId == targetId then
                            -- 进入车辆
                            vehicle:enter(pending.seatIndex, player)
                            vehicle:setCharacterPosition(player, pending.seatIndex, "inside")
                            vehicle:switchSeat(player, pending.seatIndex)
                            sendSwitchSeat(vehicle, player, 0, pending.seatIndex)
                            triggerEvent("OnSwitchVehicleSeat", player)
                            
                            -- 清理临时返回数据
                            HomeTeleport.MP.playerData.wasInVehicle = false
                            HomeTeleport.MP.playerData.wasInVehicleLastPos = nil
                            
                            -- 通知服务器更新数据
                            HomeTeleport.sendClientCommand(HomeTeleport.CLIENT_COMMANDS.UNBIND_VEHICLE, {
                                vehicleId = pending.persistentId
                            })
                            
                            print("[HomeTeleport] Successfully returned to seat " .. pending.seatIndex)
                            HomeTeleport.MP.pendingSeatReentry = nil
                            return
                        end
                    end
                end
            end
        end
    end
    
    -- 每5次尝试打印一次进度
    if pending.attempts % 5 == 0 then
        print("[HomeTeleport] Seat re-entry attempt in progress... (" .. pending.attempts .. "/" .. pending.maxAttempts .. ")")
    end
end

-- 获取当前家位置
function HomeTeleport.MP.getHomePosition()
    return HomeTeleport.MP.playerData.homePosition
end

-- 检查家是否已设置
function HomeTeleport.MP.isHomeSet()
    return HomeTeleport.MP.playerData.isHomeSet
end

-- 检查车辆是否已绑定
function HomeTeleport.MP.isVehicleBound(vehicle)
    if not vehicle then return false end
    
    local vehicleId = HomeTeleport.ensureVehiclePersistentId(vehicle)
    return HomeTeleport.MP.playerData.currentBoundVehicleId == vehicleId
end

-- 检查是否使用沙盒配置
function HomeTeleport.MP.useSandboxHome()
    return HomeTeleport.MP.worldData.UseSandboxHome
end

-- **********************************************************************************
-- 世界对象右键菜单（多人模式）
-- **********************************************************************************
function HomeTeleport.MP.doWorldContextMenu(playerNum, context, worldobjects)
    local player = getSpecificPlayer(playerNum)
    if not player or not player:isAlive() then return end

    -- 获取设置家菜单文本
    local menuText = HomeTeleport.MP.isHomeSet() and getText("UI_HomeTeleport_UpdateHome") or getText("UI_HomeTeleport_SetHome")

    -- 添加设置家菜单项
    if not player:getVehicle() and not HomeTeleport.MP.useSandboxHome() then
        local option = context:addOption(menuText, nil, function()
            HomeTeleport.MP.setHome()
        end)

        local icon = getTexture("media/ui/home_icon.png")
        if icon then
            option.iconTexture = icon
            option.icon = nil
        end
    end

    -- 添加返回车辆菜单项
    local showReturnOption = HomeTeleport.MP.playerData.wasInVehicle and HomeTeleport.MP.playerData.wasInVehicleLastPos

    if showReturnOption then
        local option = context:addOption(getText("UI_HomeTeleport_ReturnVehicle"), nil, function()
            HomeTeleport.MP.returnToLastPosition()
        end)
        local icon = getTexture("media/ui/car_icon.png")
        if icon then
            option.iconTexture = icon
            option.icon = nil
        end
    end
end

-- **********************************************************************************
-- 车辆径向菜单（多人模式）
-- **********************************************************************************
function HomeTeleport.MP.setupRadialMenu()
    local originalShowRadialMenu = ISVehicleMenu.showRadialMenu
    
    ISVehicleMenu.showRadialMenu = function(playerObj)
        originalShowRadialMenu(playerObj)
        local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
        
        if playerObj:getVehicle() then
            local sandboxOptions = getSandboxOptions()
            local limitOption = sandboxOptions and sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")
            local limited = limitOption and limitOption:getValue()
            
            local vehicle = playerObj:getVehicle()
            
            -- 检查家是否已设置
            local isHomeSet = HomeTeleport.MP.isHomeSet()
            
            if isHomeSet then
                if limited == true then
                    -- 限制模式：检查车辆是否已绑定
                    local isBound = HomeTeleport.MP.isVehicleBound(vehicle)
                    
                    if isBound then
                        -- 已绑定的车辆：显示回家选项
                        menu:addSlice(
                            getText("UI_HomeTeleport_GoHome"),
                            getTexture("media/ui/home_icon.png"),
                            function()
                                HomeTeleport.MP.goHome()
                            end,
                            playerObj
                        )
                    else
                        -- 未绑定的车辆：显示绑定选项
                        menu:addSlice(
                            getText("UI_HomeTeleport_BindVehicle"),
                            getTexture("media/ui/car_icon.png"),
                            function()
                                HomeTeleport.MP.bindVehicle(vehicle)
                            end,
                            playerObj
                        )
                    end
                else
                    -- 非限制模式：所有车辆都能回家
                    menu:addSlice(
                        getText("UI_HomeTeleport_GoHome"),
                        getTexture("media/ui/home_icon.png"),
                        function()
                            HomeTeleport.MP.goHome()
                        end,
                        playerObj
                    )
                end
            end
        end
    end
end

-- **********************************************************************************
-- 初始化UI菜单（多人模式）
-- **********************************************************************************
function HomeTeleport.MP.initUI()
    -- 注册世界对象右键菜单
    Events.OnFillWorldObjectContextMenu.Add(HomeTeleport.MP.doWorldContextMenu)
    
    -- 设置车辆径向菜单
    HomeTeleport.MP.setupRadialMenu()
    
    print("[HomeTeleport] UI menus initialized for multiplayer")
end

-- **********************************************************************************
-- 客户端初始化
-- **********************************************************************************
Events.OnGameStart.Add(function()
    if isClient() then
        HomeTeleport.MP.init()
        HomeTeleport.MP.initUI()
    end
end)