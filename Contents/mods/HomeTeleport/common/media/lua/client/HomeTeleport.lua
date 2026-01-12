-- 添加回家功能（只支持车辆上回家）

HomeTeleport = {}
HomeTeleport.homePosition = {x = 0, y = 0, z = 0}
HomeTeleport.isHomeSet = false
HomeTeleport.wasInVehicle = false
HomeTeleport.wasInVehicleLastPos = nil
HomeTeleport.useSandboxHome = false
HomeTeleport.boundVehicles = {}
HomeTeleport.currentBoundVehicleId = nil

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
        local bindLimitOption = sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")

        if enableOption and enableOption:getValue() then
            HomeTeleport.useSandboxHome = true
            HomeTeleport.homePosition.x = xOption and xOption:getValue() or 0
            HomeTeleport.homePosition.y = yOption and yOption:getValue() or 0
            HomeTeleport.homePosition.z = zOption and zOption:getValue() or 0
            HomeTeleport.isHomeSet = true
        end
        
        -- 根据绑定限制配置加载车辆绑定数据
        if bindLimitOption then
            local limited = bindLimitOption:getValue()
            if ModData.exists("HomeTeleport") then
                local data = ModData.get("HomeTeleport")
                if data then
                    if limited then
                        -- 限制模式：加载保存的绑定数据
                        HomeTeleport.boundVehicles = data.boundVehicles or {}
                        HomeTeleport.currentBoundVehicleId = data.currentBoundVehicleId or nil
                    else
                        -- 非限制模式：不使用绑定数据，允许所有车辆
                        HomeTeleport.boundVehicles = {}
                        HomeTeleport.currentBoundVehicleId = nil
                    end
                end
            end
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

    local sandboxOptions = getSandboxOptions()
    local limitOption = sandboxOptions and sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")
    local limited = limitOption and limitOption:getValue()
    
    local data = ModData.get("HomeTeleport")
    data.homePosition = HomeTeleport.homePosition
    data.isHomeSet = HomeTeleport.isHomeSet
    
    -- 只在限制模式下保存车辆绑定数据
    if limited ~= false then
        data.boundVehicles = HomeTeleport.boundVehicles
        data.currentBoundVehicleId = HomeTeleport.currentBoundVehicleId
    else
        data.boundVehicles = {}
        data.currentBoundVehicleId = nil
    end
    
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
-- 显示确认对话框
-- **********************************************************************************
function HomeTeleport.showConfirmationDialog(confirmText, onYes)
    local player = getPlayer()
    if not player then return end

    local modal = ISModalDialog:new(
        (getCore():getScreenWidth() / 2) - 150,
        (getCore():getScreenHeight() / 2) - 75,
        300,
        150,
        confirmText,
        player,
        true,
        function(target, button)
            if button.internal == "YES" and onYes then
                onYes()
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

-- **********************************************************************************
-- 显示设置家确认对话框
-- **********************************************************************************
function HomeTeleport.showSetHomeConfirmation(confirmText, successText)
    HomeTeleport.showConfirmationDialog(
        confirmText or getText("UI_HomeTeleport_ConfirmSetHome"),
        function()
            HomeTeleport.setHomeConfirmed(successText)
        end
    )
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
-- 显示绑定车辆确认对话框
-- **********************************************************************************
function HomeTeleport.showBindVehicleConfirmation(vehicle, playerObj)
    local sandboxOptions = getSandboxOptions()
    local limitOption = sandboxOptions and sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")
    local limited = limitOption and limitOption:getValue()
    
    local confirmText = getText("UI_HomeTeleport_ConfirmBindVehicle")
    
    -- 如果限制模式开启且已绑定其他车辆，显示更换绑定的提示
    if limited ~= false and HomeTeleport.currentBoundVehicleId and HomeTeleport.currentBoundVehicleId ~= vehicle:getId() then
        confirmText = getText("UI_HomeTeleport_ConfirmRebindVehicle")
    end
    
    HomeTeleport.showConfirmationDialog(
        confirmText,
        function()
            local vehicleId = vehicle:getId()
            
            -- 如果更换了绑定车辆，重置返回数据
            if HomeTeleport.currentBoundVehicleId and HomeTeleport.currentBoundVehicleId ~= vehicleId then
                HomeTeleport.wasInVehicle = false
                HomeTeleport.wasInVehicleLastPos = nil
            end
            
            HomeTeleport.currentBoundVehicleId = vehicleId
            HomeTeleport.boundVehicles = {}
            HomeTeleport.boundVehicles[vehicleId] = true
            HomeTeleport.saveHomePosition()
            
            playerObj:Say(getText("UI_HomeTeleport_BindSuccess"))
        end
    )
end

-- **********************************************************************************
-- 绑定车辆（如果限制模式开启，直接更换绑定）
-- **********************************************************************************
function HomeTeleport.bindVehicle(vehicle)
    local player = getPlayer()
    if not player or not vehicle then return false end
    
    local vehicleId = vehicle:getId()
    
    -- 如果更换了绑定车辆，重置返回数据
    if HomeTeleport.currentBoundVehicleId and HomeTeleport.currentBoundVehicleId ~= vehicleId then
        HomeTeleport.wasInVehicle = false
        HomeTeleport.wasInVehicleLastPos = nil
    end
    
    HomeTeleport.currentBoundVehicleId = vehicleId
    HomeTeleport.boundVehicles = {}
    HomeTeleport.boundVehicles[vehicleId] = true
    HomeTeleport.saveHomePosition()
    
    return true
end

-- **********************************************************************************
-- 解绑车辆
-- **********************************************************************************
function HomeTeleport.unbindVehicle(vehicleId)
    if not vehicleId then return end
    
    if HomeTeleport.boundVehicles[vehicleId] then
        HomeTeleport.boundVehicles[vehicleId] = nil
    end
    
    if HomeTeleport.currentBoundVehicleId == vehicleId then
        HomeTeleport.currentBoundVehicleId = nil
    end
    
    if HomeTeleport.wasInVehicleLastPos and HomeTeleport.wasInVehicleLastPos.vehicleId == vehicleId then
        HomeTeleport.wasInVehicle = false
        HomeTeleport.wasInVehicleLastPos = nil
    end
    
    HomeTeleport.saveHomePosition()
end

-- **********************************************************************************
-- 检查车辆是否已绑定
-- **********************************************************************************
function HomeTeleport.isVehicleBound(vehicleId)
    return HomeTeleport.boundVehicles[vehicleId] ~= nil
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
    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    
    if playerObj:getVehicle() then
        local sandboxOptions = getSandboxOptions()
        local limitOption = sandboxOptions and sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")
        local limited = limitOption and limitOption:getValue()
        
        local vehicle = playerObj:getVehicle()
        local vehicleId = vehicle:getId()
        local isBound = HomeTeleport.isVehicleBound(vehicleId)
        
        -- 如果已设置家，根据限制模式显示不同选项
        if HomeTeleport.isHomeSet then
            if limited ~= false then
                -- 限制模式：只在已绑定的车辆上显示回家选项
                if isBound then
                    menu:addSlice(
                        getText("UI_HomeTeleport_GoHome"),
                        getTexture("media/ui/home_icon.png"),
                        HomeTeleport.goHome,
                        playerObj
                    )
                else
                    -- 未绑定的车辆显示绑定选项（带确认对话框）
                    menu:addSlice(
                        getText("UI_HomeTeleport_BindVehicle"),
                        getTexture("media/ui/car_icon.png"),
                        function()
                            HomeTeleport.showBindVehicleConfirmation(vehicle, playerObj)
                        end
                    )
                end
            else
                -- 非限制模式：所有车辆都能回家，不显示绑定菜单
                menu:addSlice(
                    getText("UI_HomeTeleport_GoHome"),
                    getTexture("media/ui/home_icon.png"),
                    HomeTeleport.goHome,
                    playerObj
                )
            end
        end
    end
end

-- **********************************************************************************
-- 初始化
-- **********************************************************************************
Events.OnFillWorldObjectContextMenu.Add(HomeTeleport.doWorldContextMenu)
Events.OnGameStart.Add(HomeTeleport.loadHomePosition)
