-- 添加回家功能（只支持车辆上回家）

HomeTeleport = {}
HomeTeleport.homePosition = {x = 0, y = 0, z = 0}
HomeTeleport.isHomeSet = false
HomeTeleport.wasInVehicle = false
HomeTeleport.wasInVehicleLastPos = nil
HomeTeleport.useSandboxHome = false
HomeTeleport.currentBoundVehicleId = nil

-- **********************************************************************************
-- 加载保存的家的位置
-- **********************************************************************************
function HomeTeleport.loadHomePosition()
    local player = getPlayer()
    if not player then return end

    -- 打印初始化调试信息
    print("=== HomeTeleport Initialization Debug Info ===")

    -- 从 ModData 加载
    if ModData.exists("HomeTeleport") then
        local data = ModData.get("HomeTeleport")
        if data then
            -- 加载家的位置数据
            if data.homePosition then
                HomeTeleport.homePosition = data.homePosition
                HomeTeleport.isHomeSet = data.isHomeSet or false
                print("Loaded home position from ModData:")
                print("  Home Position: (" .. data.homePosition.x .. ", " .. data.homePosition.y .. ", " .. data.homePosition.z .. ")")
                print("  Is Home Set: " .. tostring(data.isHomeSet or false))
            else
                print("No home position data found in ModData")
            end
            
            -- 加载车辆绑定数据（无论限制模式如何，都先加载）
            HomeTeleport.currentBoundVehicleId = data.currentBoundVehicleId or nil
            
            -- 加载返回位置数据
            HomeTeleport.wasInVehicle = data.wasInVehicle or false
            HomeTeleport.wasInVehicleLastPos = data.wasInVehicleLastPos or nil
            
            print("Loaded bound vehicle ID: " .. tostring(data.currentBoundVehicleId or nil))
            print("Loaded wasInVehicle: " .. tostring(data.wasInVehicle or false))
            if data.wasInVehicleLastPos then
                print("Loaded wasInVehicleLastPos:")
                print("  Position: (" .. data.wasInVehicleLastPos.x .. ", " .. data.wasInVehicleLastPos.y .. ", " .. data.wasInVehicleLastPos.z .. ")")
                print("  Vehicle ID: " .. tostring(data.wasInVehicleLastPos.vehicleId))
                print("  Seat Index: " .. tostring(data.wasInVehicleLastPos.seatIndex))
            else
                print("No wasInVehicleLastPos data found")
            end
        end
    else
        print("No HomeTeleport ModData found")
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
            print("Sandbox home position enabled:")
            print("  Sandbox Home Position: (" .. HomeTeleport.homePosition.x .. ", " .. HomeTeleport.homePosition.y .. ", " .. HomeTeleport.homePosition.z .. ")")
        else
            print("Sandbox home position disabled")
        end
    else
        print("No sandbox options found")
    end

    -- 打印最终绑定信息
    print("Final initialization results:")
    print("  Current Bound Vehicle ID: " .. tostring(HomeTeleport.currentBoundVehicleId))
    print("  Is Home Set: " .. tostring(HomeTeleport.isHomeSet))
    print("  Use Sandbox Home: " .. tostring(HomeTeleport.useSandboxHome))
    if HomeTeleport.isHomeSet then
        print("  Home Position: (" .. HomeTeleport.homePosition.x .. ", " .. HomeTeleport.homePosition.y .. ", " .. HomeTeleport.homePosition.z .. ")")
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
    
    -- 保存返回位置数据
    data.wasInVehicle = HomeTeleport.wasInVehicle
    data.wasInVehicleLastPos = HomeTeleport.wasInVehicleLastPos
    
    ModData.transmit("HomeTeleport")
end

-- **********************************************************************************
-- 保存车辆绑定数据
-- **********************************************************************************
function HomeTeleport.saveVehicleBindings()
    if not ModData.exists("HomeTeleport") then
        ModData.add("HomeTeleport", {})
    end

    local sandboxOptions = getSandboxOptions()
    local limitOption = sandboxOptions and sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")
    local limited = limitOption and limitOption:getValue()
    
    local data = ModData.get("HomeTeleport")
    
    -- 只在限制模式下保存车辆绑定数据
    if limited then
        data.currentBoundVehicleId = HomeTeleport.currentBoundVehicleId
    else
        -- 非限制模式：不清空现有数据，只是不保存
        -- 保持现有数据不变，但当前会话不使用
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

    -- 打印回家调试信息
    print("=== HomeTeleport Go Home Debug Info ===")
    print("Current Player Position: (" .. player:getX() .. ", " .. player:getY() .. ", " .. player:getZ() .. ")")
    print("Home Position: (" .. HomeTeleport.homePosition.x .. ", " .. HomeTeleport.homePosition.y .. ", " .. HomeTeleport.homePosition.z .. ")")

    -- 记录车辆信息
    local currentVehicle = player:getVehicle()
    if currentVehicle then
        print("Player is in vehicle")
        print("Vehicle ID: " .. currentVehicle:getId())
        print("Vehicle Position: (" .. currentVehicle:getX() .. ", " .. currentVehicle:getY() .. ", " .. currentVehicle:getZ() .. ")")
        
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
        print("Recorded vehicle info:")
        print("  Recorded Position: (" .. player:getX() .. ", " .. player:getY() .. ", " .. player:getZ() .. ")")
        print("  Recorded Vehicle ID: " .. currentVehicle:getId())
        print("  Seat Index: " .. seatIndex)
        
        currentVehicle:exit(player)
    else
        print("Player is not in vehicle")
        HomeTeleport.wasInVehicle = false
    end

    -- 传送
    player:setX(HomeTeleport.homePosition.x)
    player:setY(HomeTeleport.homePosition.y)
    player:setZ(HomeTeleport.homePosition.z)
    player:setLastX(HomeTeleport.homePosition.x)
    player:setLastY(HomeTeleport.homePosition.y)
    player:setLastZ(HomeTeleport.homePosition.z)

    print("Teleported to home position")
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
    if limited == true and HomeTeleport.currentBoundVehicleId and HomeTeleport.currentBoundVehicleId ~= vehicle:getId() then
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
            HomeTeleport.saveVehicleBindings()
            
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
    HomeTeleport.saveVehicleBindings()
    
    return true
end

-- **********************************************************************************
-- 解绑车辆
-- **********************************************************************************
function HomeTeleport.unbindVehicle(vehicleId)
    if not vehicleId then return end
    
    if HomeTeleport.currentBoundVehicleId == vehicleId then
        HomeTeleport.currentBoundVehicleId = nil
    end
    
    if HomeTeleport.wasInVehicleLastPos and HomeTeleport.wasInVehicleLastPos.vehicleId == vehicleId then
        HomeTeleport.wasInVehicle = false
        HomeTeleport.wasInVehicleLastPos = nil
    end
    
    HomeTeleport.saveVehicleBindings()
end

-- **********************************************************************************
-- 检查车辆是否已绑定
-- **********************************************************************************
function HomeTeleport.isVehicleBound(vehicleId)
    return HomeTeleport.currentBoundVehicleId == vehicleId
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
    local sandboxOptions = getSandboxOptions()
    local limitOption = sandboxOptions and sandboxOptions:getOptionByName("HomeTeleport.VehicleBindLimit")
    local limited = limitOption and limitOption:getValue()
    
    -- 打印调试信息
    print("=== HomeTeleport Return Debug Info ===")
    print("Restricted Mode: " .. tostring(limited))
    print("Current Bound Vehicle ID: " .. tostring(HomeTeleport.currentBoundVehicleId))
    print("Recorded Position Info:")
    print("  Coordinates: (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")")
    print("  Vehicle ID: " .. tostring(pos.vehicleId))
    print("  Seat Index: " .. tostring(pos.seatIndex))
    
    if limited == true then
        print("Mode: Restricted Mode")
        -- 限制模式：优先使用当前绑定的车辆
        if HomeTeleport.currentBoundVehicleId then
            local vehicles = getCell():getVehicles()
            local foundVehicle = false
            
            for i = 0, vehicles:size() - 1 do
                local v = vehicles:get(i)
                if v:getId() == HomeTeleport.currentBoundVehicleId then
                    print("Found bound vehicle, teleporting via vehicle")
                    print("Vehicle ID: " .. v:getId())
                    print("Vehicle Position: (" .. v:getX() .. ", " .. v:getY() .. ", " .. v:getZ() .. ")")
                    foundVehicle = true
                    
                    player:setX(v:getX())
                    player:setY(v:getY())
                    player:setZ(v:getZ())
                    player:setLastX(v:getX())
                    player:setLastY(v:getY())
                    player:setLastZ(v:getZ())

                    player:Say(getText("UI_HomeTeleport_ReturnSuccess"))
                    v:enter(pos.seatIndex or 0, player)
                    v:setCharacterPosition(player, pos.seatIndex or 0, "inside")
                    v:switchSeat(player, pos.seatIndex or 0)
                    sendSwitchSeat(v, player, 0, pos.seatIndex or 0)
                    triggerEvent("OnSwitchVehicleSeat", player)
                    
                    HomeTeleport.wasInVehicle = false
                    HomeTeleport.wasInVehicleLastPos = nil
                    return
                end
            end
            
            if not foundVehicle then
                print("Bound vehicle not found, teleporting via position")
            end
        else
            print("No bound vehicle, teleporting via position")
        end
        
        -- 限制模式下没有找到绑定的车辆，直接返回到记录的位置
        player:setX(pos.x)
        player:setY(pos.y)
        player:setZ(pos.z)
        player:setLastX(pos.x)
        player:setLastY(pos.y)
        player:setLastZ(pos.z)
        player:Say(getText("UI_HomeTeleport_ReturnSuccess"))
    else
        print("Mode: Unrestricted Mode")
        -- 非限制模式：尝试使用之前记录的车辆
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
            print("Found recorded vehicle, teleporting via vehicle")
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
            
            HomeTeleport.wasInVehicle = false
            HomeTeleport.wasInVehicleLastPos = nil
            print("Return completed")
            return
        else
            print("Recorded vehicle not found, teleporting via position")
            -- 没有找到记录的车辆，直接返回到记录的位置
            player:setX(pos.x)
            player:setY(pos.y)
            player:setZ(pos.z)
            player:setLastX(pos.x)
            player:setLastY(pos.y)
            player:setLastZ(pos.z)
            player:Say(getText("UI_HomeTeleport_ReturnSuccess"))
        end
    end
    
    HomeTeleport.wasInVehicle = false
    HomeTeleport.wasInVehicleLastPos = nil
    print("Return completed")
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
            if limited == true then
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
