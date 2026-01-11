-- 添加回家功能（只支持车辆上回家）

HomeTeleport = {}
HomeTeleport.homePosition = {x = 0, y = 0, z = 0}
HomeTeleport.isHomeSet = false
HomeTeleport.wasInVehicle = false
HomeTeleport.wasInVehicleLastPos = nil
HomeTeleport.useSandboxHome = false

-- **********************************************************************************
-- 加载保存的家的位置
-- **********************************************************************************
function HomeTeleport.loadHomePosition()
    local player = getPlayer()
    if not player then return end

    -- 从 ModData 加载
    if ModData.exists("HomeTeleport") then
        local data = ModData.get("HomeTeleport")
        if data and data.homePosition then
            HomeTeleport.homePosition = data.homePosition
            HomeTeleport.isHomeSet = data.isHomeSet or false
        end
    end

    -- 检查sandbox配置
    local sandboxOptions = getSandboxOptions()
    if sandboxOptions then
        local enableOption = sandboxOptions:getOptionByName("HomeTeleport.EnableFixedHomePosition")
        local xOption = sandboxOptions:getOptionByName("HomeTeleport.FixedHomePositionX")
        local yOption = sandboxOptions:getOptionByName("HomeTeleport.FixedHomePositionY")
        local zOption = sandboxOptions:getOptionByName("HomeTeleport.FixedHomePositionZ")

        if enableOption and enableOption:getValue() then
            HomeTeleport.useSandboxHome = true
            HomeTeleport.homePosition.x = xOption and xOption:getValue() or 0
            HomeTeleport.homePosition.y = yOption and yOption:getValue() or 0
            HomeTeleport.homePosition.z = zOption and zOption:getValue() or 0
            HomeTeleport.isHomeSet = true
        end
    end
end

-- **********************************************************************************
-- 保存家的位置
-- **********************************************************************************
function HomeTeleport.saveHomePosition()
    if not ModData.exists("HomeTeleport") then
        ModData.add("HomeTeleport", {})
    end

    local data = ModData.get("HomeTeleport")
    data.homePosition = HomeTeleport.homePosition
    data.isHomeSet = HomeTeleport.isHomeSet
    ModData.transmit("HomeTeleport")
end

-- **********************************************************************************
-- 确认设置家
-- **********************************************************************************
function HomeTeleport.setHomeConfirmed(successText)
    local player = getPlayer()
    if not player then return end

    if HomeTeleport.useSandboxHome then
        player:Say(getText("UI_HomeTeleport_SandboxLocked"))
        return
    end

    HomeTeleport.homePosition.x = player:getX()
    HomeTeleport.homePosition.y = player:getY()
    HomeTeleport.homePosition.z = player:getZ()
    HomeTeleport.isHomeSet = true

    HomeTeleport.saveHomePosition()
    player:Say(successText or getText("UI_HomeTeleport_SetSuccess"))
end

-- **********************************************************************************
-- 显示设置家确认对话框
-- **********************************************************************************
function HomeTeleport.showSetHomeConfirmation(confirmText, successText)
    local player = getPlayer()
    if not player then return end

    local modal = ISModalDialog:new(
        (getCore():getScreenWidth() / 2) - 150,
        (getCore():getScreenHeight() / 2) - 75,
        300,
        150,
        confirmText or getText("UI_HomeTeleport_ConfirmSetHome"),
        player,
        true,
        function(target, button)
            if button.internal == "YES" then
                HomeTeleport.setHomeConfirmed(successText)
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

-- **********************************************************************************
-- 设置当前位置为家
-- **********************************************************************************
function HomeTeleport.setHome()
    local confirmText = HomeTeleport.isHomeSet and getText("UI_HomeTeleport_ConfirmUpdateHome") or getText("UI_HomeTeleport_ConfirmSetHome")
    local successText = HomeTeleport.isHomeSet and getText("UI_HomeTeleport_UpdateSuccess") or getText("UI_HomeTeleport_SetSuccess")
    HomeTeleport.showSetHomeConfirmation(confirmText, successText)
end

-- **********************************************************************************
-- 传送回家
-- **********************************************************************************
function HomeTeleport.goHome()
    if not HomeTeleport.isHomeSet then
        getPlayer():Say(getText("UI_HomeTeleport_NotSet"))
        return
    end

    local player = getPlayer()
    if not player then return end

    -- 记录车辆信息
    local currentVehicle = player:getVehicle()
    if currentVehicle then
        HomeTeleport.wasInVehicle = true
        local seatIndex = 0
        for i = 0, 3 do
            if currentVehicle:getCharacter(i) == player then
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

    -- 传送
    player:setX(HomeTeleport.homePosition.x)
    player:setY(HomeTeleport.homePosition.y)
    player:setZ(HomeTeleport.homePosition.z)
    player:setLastX(HomeTeleport.homePosition.x)
    player:setLastY(HomeTeleport.homePosition.y)
    player:setLastZ(HomeTeleport.homePosition.z)

    player:Say(getText("UI_HomeTeleport_GoHomeSuccess"))
end

-- **********************************************************************************
-- 返回离开位置
-- **********************************************************************************
function HomeTeleport.returnToLastPosition()
    if not HomeTeleport.wasInVehicle or not HomeTeleport.wasInVehicleLastPos then
        getPlayer():Say(getText("UI_HomeTeleport_NoLastPos"))
        return
    end

    local player = getPlayer()
    if not player then return end

    if player:getVehicle() then
        player:getVehicle():exit(player)
    end

    local pos = HomeTeleport.wasInVehicleLastPos
    local vehicles = getCell():getVehicles()
    local returnVehicle = nil

    for i = 0, vehicles:size() - 1 do
        local v = vehicles:get(i)
        if v:getId() == pos.vehicleId then
            returnVehicle = v
            break
        end
    end

    if returnVehicle then
        player:setX(returnVehicle:getX())
        player:setY(returnVehicle:getY())
        player:setZ(returnVehicle:getZ())
        player:setLastX(returnVehicle:getX())
        player:setLastY(returnVehicle:getY())
        player:setLastZ(returnVehicle:getZ())

        player:Say(getText("UI_HomeTeleport_ReturnSuccess"))
        returnVehicle:enter(pos.seatIndex or 0, player)
        returnVehicle:setCharacterPosition(player, pos.seatIndex or 0, "inside")
        returnVehicle:switchSeat(player, pos.seatIndex or 0)
        sendSwitchSeat(returnVehicle, player, 0, pos.seatIndex or 0)
        triggerEvent("OnSwitchVehicleSeat", player)
    else
        player:setX(pos.x)
        player:setY(pos.y)
        player:setZ(pos.z)
        player:setLastX(pos.x)
        player:setLastY(pos.y)
        player:setLastZ(pos.z)
        player:Say(getText("UI_HomeTeleport_ReturnSuccess"))
    end

    HomeTeleport.wasInVehicle = false
    HomeTeleport.wasInVehicleLastPos = nil
end

-- **********************************************************************************
-- 世界对象右键菜单
-- **********************************************************************************
HomeTeleport.doWorldContextMenu = function(playerNum, context, worldobjects)
    local player = getSpecificPlayer(playerNum)
    if not player or not player:isAlive() then return end

    if not player:getVehicle() and not HomeTeleport.useSandboxHome then
        local menuText = HomeTeleport.isHomeSet and getText("UI_HomeTeleport_UpdateHome") or getText("UI_HomeTeleport_SetHome")
        local confirmText = HomeTeleport.isHomeSet and getText("UI_HomeTeleport_ConfirmUpdateHome") or getText("UI_HomeTeleport_ConfirmSetHome")
        local successText = HomeTeleport.isHomeSet and getText("UI_HomeTeleport_UpdateSuccess") or getText("UI_HomeTeleport_SetSuccess")

        local option = context:addOption(menuText, nil, function()
            HomeTeleport.showSetHomeConfirmation(confirmText, successText)
        end)

        local icon = getTexture("media/ui/home_icon.png")
        if icon then
            option.iconTexture = icon
            option.icon = nil
        end
    end

    if HomeTeleport.wasInVehicle and HomeTeleport.wasInVehicleLastPos then
        local option = context:addOption(getText("UI_HomeTeleport_ReturnVehicle"), nil, HomeTeleport.returnToLastPosition)
        local icon = getTexture("media/ui/car_icon.png")
        if icon then
            option.iconTexture = icon
            option.icon = nil
        end
    end
end

-- **********************************************************************************
-- 车辆径向菜单
-- **********************************************************************************
local showRadialMenuFix = ISVehicleMenu.showRadialMenu
function ISVehicleMenu.showRadialMenu(playerObj)
    showRadialMenuFix(playerObj)
    if playerObj:getVehicle() and HomeTeleport.isHomeSet then
        getPlayerRadialMenu(playerObj:getPlayerNum()):addSlice(
            getText("UI_HomeTeleport_GoHome"),
            getTexture("media/ui/home_icon.png"),
            HomeTeleport.goHome,
            playerObj
        )
    end
end

-- **********************************************************************************
-- 初始化
-- **********************************************************************************
Events.OnFillWorldObjectContextMenu.Add(HomeTeleport.doWorldContextMenu)
Events.OnGameStart.Add(HomeTeleport.loadHomePosition)
