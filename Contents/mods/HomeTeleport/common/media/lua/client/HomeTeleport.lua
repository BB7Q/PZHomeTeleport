-- 添加回家功能（只支持车辆上回家）

HomeTeleport = {}
HomeTeleport.homePosition = {x = 0, y = 0, z = 0}
HomeTeleport.isHomeSet = false
HomeTeleport.wasInVehicle = false
HomeTeleport.wasInVehicleLastPos = nil

-- 加载保存的家的位置
function HomeTeleport.loadHomePosition()
    if isClient() then
        sendClientCommand("HomeTeleport", "requestHomePosition", {})
    else
        if ModData.exists("HomeTeleport") then
            local data = ModData.get("HomeTeleport")
            if data and data.homePosition then
                HomeTeleport.homePosition = data.homePosition
                HomeTeleport.isHomeSet = data.isHomeSet or false
            end
        end
    end
end

-- 保存家的位置
function HomeTeleport.saveHomePosition()
    if isClient() then
        sendClientCommand("HomeTeleport", "saveHomePosition", {
            homePosition = HomeTeleport.homePosition,
            isHomeSet = HomeTeleport.isHomeSet
        })
    else
        if not ModData.exists("HomeTeleport") then
            ModData.add("HomeTeleport", {})
        end
        local data = ModData.get("HomeTeleport")
        data.homePosition = HomeTeleport.homePosition
        data.isHomeSet = HomeTeleport.isHomeSet
        ModData.transmit("HomeTeleport")
    end
end

-- 设置当前位置为家（地面）
function HomeTeleport.setHome()
    local player = getPlayer()
    if not player then return end

    HomeTeleport.homePosition.x = player:getX()
    HomeTeleport.homePosition.y = player:getY()
    HomeTeleport.homePosition.z = player:getZ()
    HomeTeleport.isHomeSet = true

    HomeTeleport.saveHomePosition()

    getPlayer():Say(getText("UI_HomeTeleport_SetSuccess"))
end



-- 处理服务器命令响应
local function onServerCommand(module, command, args)
    if module == "HomeTeleport" then
        if command == "homePositionUpdated" then
            if args.homePosition then
                HomeTeleport.homePosition = args.homePosition
                HomeTeleport.isHomeSet = args.isHomeSet or false
                print("[HomeTeleport] Home position loaded from server")
            end
        elseif command == "homeSaved" then
            if args.success then
                print("[HomeTeleport] Home position saved successfully on server")
            end
        end
    end
end

-- 传送回家
function HomeTeleport.goHome()
    if not HomeTeleport.isHomeSet then
        getPlayer():Say(getText("UI_HomeTeleport_NotSet"))
        return
    end

    local player = getPlayer()
    if not player then return end

    -- 检查是否有僵尸在附近
    local safe = true
    local zombies = getCell():getZombieList()
    for i=0, zombies:size()-1 do
        local zombie = zombies:get(i)
        if zombie and player:DistTo(zombie) < 3 then
            safe = false
            break
        end
    end

    if not safe then
        getPlayer():Say(getText("UI_HomeTeleport_Unsafe"))
        return
    end

    -- 记录当前是否在车内以及车辆信息
    local currentVehicle = player:getVehicle()
    if currentVehicle then
        HomeTeleport.wasInVehicle = true
        
        -- 使用MKI B42的方法记录车辆信息
        local seatIndex = 0
        
        -- 尝试找到玩家所在的座位
        for i = 0, 3 do
            local occupant = currentVehicle:getCharacter(i)
            if occupant and occupant == player then
                seatIndex = i
                break
            end
        end
        
        HomeTeleport.wasInVehicleLastPos = {
            x = player:getX(),
            y = player:getY(),
            z = player:getZ(),
            vehicleId = currentVehicle:getId(),
            seatIndex = seatIndex
        }
        currentVehicle:exit(player)
    else
        HomeTeleport.wasInVehicle = false
    end

    -- 传送到家的地面位置
    player:setX(HomeTeleport.homePosition.x)
    player:setY(HomeTeleport.homePosition.y)
    player:setZ(HomeTeleport.homePosition.z)
    player:setLastX(HomeTeleport.homePosition.x)
    player:setLastY(HomeTeleport.homePosition.y)
    player:setLastZ(HomeTeleport.homePosition.z)

    getPlayer():Say(getText("UI_HomeTeleport_GoHomeSuccess"))
end

-- 返回离开位置
function HomeTeleport.returnToLastPosition()
    if not HomeTeleport.wasInVehicle or not HomeTeleport.wasInVehicleLastPos then
        getPlayer():Say(getText("UI_HomeTeleport_NoLastPos"))
        return
    end

    local player = getPlayer()
    if not player then return end

    local currentVehicle = player:getVehicle()

    -- 如果在车内，先离开
    if currentVehicle then
        currentVehicle:exit(player)
    end

    -- 检查是否有记录的车辆信息
    if HomeTeleport.wasInVehicleLastPos.vehicleId then
        -- 查找原来的车辆
        local returnVehicle = nil
        local vehicles = getCell():getVehicles()
        for i = 0, vehicles:size() - 1 do
            local v = vehicles:get(i)
            if v:getId() == HomeTeleport.wasInVehicleLastPos.vehicleId then
                returnVehicle = v
                break
            end
        end

        if returnVehicle then
            -- 直接传送到车辆所在位置
            player:setX(returnVehicle:getX())
            player:setY(returnVehicle:getY())
            player:setZ(returnVehicle:getZ())
            player:setLastX(returnVehicle:getX())
            player:setLastY(returnVehicle:getY())
            player:setLastZ(returnVehicle:getZ())

            getPlayer():Say(getText("UI_HomeTeleport_ReturnSuccess"))

            -- 使用MKI B42的方法让玩家进入车辆
            local seatIndex = HomeTeleport.wasInVehicleLastPos.seatIndex or 0
            
            -- 首先尝试进入指定的座位
            returnVehicle:enter(seatIndex, player)
            
            -- 设置玩家在车辆中的位置
            returnVehicle:setCharacterPosition(player, seatIndex, "inside")
            
            -- 切换座位（确保玩家在正确的位置）
            returnVehicle:switchSeat(player, seatIndex)
            
            -- 发送座位切换事件
            sendSwitchSeat(returnVehicle, player, 0, seatIndex)
            
            -- 触发座位切换事件
            triggerEvent("OnSwitchVehicleSeat", player)
        else
            -- 车辆没找到，传送到记录的位置
            player:setX(HomeTeleport.wasInVehicleLastPos.x)
            player:setY(HomeTeleport.wasInVehicleLastPos.y)
            player:setZ(HomeTeleport.wasInVehicleLastPos.z)
            player:setLastX(HomeTeleport.wasInVehicleLastPos.x)
            player:setLastY(HomeTeleport.wasInVehicleLastPos.y)
            player:setLastZ(HomeTeleport.wasInVehicleLastPos.z)

            getPlayer():Say(getText("UI_HomeTeleport_ReturnSuccess"))
        end
    else
        -- 没有车辆信息，直接传送到记录的位置
        player:setX(HomeTeleport.wasInVehicleLastPos.x)
        player:setY(HomeTeleport.wasInVehicleLastPos.y)
        player:setZ(HomeTeleport.wasInVehicleLastPos.z)
        player:setLastX(HomeTeleport.wasInVehicleLastPos.x)
        player:setLastY(HomeTeleport.wasInVehicleLastPos.y)
        player:setLastZ(HomeTeleport.wasInVehicleLastPos.z)

        getPlayer():Say(getText("UI_HomeTeleport_ReturnSuccess"))
    end

    HomeTeleport.wasInVehicle = false
    HomeTeleport.wasInVehicleLastPos = nil
end

-- 填充世界对象上下文菜单（右键菜单）
HomeTeleport.doWorldContextMenu = function(playerNum, context, worldobjects)
    local player = getSpecificPlayer(playerNum)
    if not player or not player:isAlive() then return end

    -- 只有在车外才能设置家
    if not player:getVehicle() then
        local setHomeOption = context:addOption(getText("UI_HomeTeleport_SetHome"), nil, HomeTeleport.setHome)
        -- 为设置家选项添加图标
        local setHomeIcon = getTexture("media/ui/home_icon.png")
        if setHomeIcon and setHomeOption then
            setHomeOption.iconTexture = setHomeIcon
            setHomeOption.icon = nil
        end
    end

    -- 添加返回车辆选项（如果之前从车辆回家过）
    if HomeTeleport.wasInVehicle and HomeTeleport.wasInVehicleLastPos then
        local returnVehicleOption = context:addOption(getText("UI_HomeTeleport_ReturnVehicle"), nil, HomeTeleport.returnToLastPosition)
        -- 为返回车辆选项添加图标
        local returnVehicleIcon = getTexture("media/ui/car_icon.png")
        if returnVehicleIcon and returnVehicleOption then
            returnVehicleOption.iconTexture = returnVehicleIcon
            returnVehicleOption.icon = nil
        end
    end

    -- 移除地面上的回家选项，只在车辆上通过轮盘回家
end

-- 不需要车辆右键菜单，回家功能只在车辆轮盘菜单中

-- 重写径向菜单（用于车内操作，只显示回家）
local showRadialMenufix = ISVehicleMenu.showRadialMenu
function ISVehicleMenu.showRadialMenu(playerObj)
    showRadialMenufix(playerObj)
    
    -- 只有在车上且已设置家时才能显示回家选项
    if playerObj:getVehicle() and HomeTeleport.isHomeSet then
        local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
        -- 添加回家选项，使用home图标
        menu:addSlice(getText("UI_HomeTeleport_GoHome"), getTexture("media/ui/home_icon.png"), HomeTeleport.goHome, playerObj)
    end
end

-- 初始化模组
HomeTeleport.init = function()
    HomeTeleport.loadHomePosition()
    -- 注册右键菜单事件
    Events.OnFillWorldObjectContextMenu.Add(HomeTeleport.doWorldContextMenu)
    
    -- 注册服务器命令事件（仅客户端）
    if isClient() then
        Events.OnServerCommand.Add(onServerCommand)
    end
end

Events.OnGameStart.Add(HomeTeleport.init)
Events.OnLoad.Add(HomeTeleport.loadHomePosition)