-- HomeTeleport 多人模式共享定义
HomeTeleport = HomeTeleport or {}

-- 通信模块名称
HomeTeleport.COMMAND_MODULE = "HomeTeleport"

-- 客户端到服务器命令
HomeTeleport.CLIENT_COMMANDS = {
    SET_HOME = "setHome",          -- 设置家位置
    GO_HOME = "goHome",            -- 传送回家
    BIND_VEHICLE = "bindVehicle",   -- 绑定车辆
    UNBIND_VEHICLE = "unbindVehicle", -- 解绑车辆
    REQUEST_DATA = "requestData",   -- 请求数据同步
    RETURN_VEHICLE = "returnVehicle" -- 返回车辆
}

-- 服务器到客户端命令
HomeTeleport.SERVER_COMMANDS = {
    DATA_SYNC = "dataSync",         -- 数据同步
    DATA_UPDATE = "dataUpdate",     -- 数据更新
    COMMAND_RESULT = "commandResult", -- 命令执行结果
    ERROR_MESSAGE = "errorMessage"  -- 错误消息
}

-- 玩家标识符生成函数
function HomeTeleport.getPlayerKey(player)
    if not player then return "unknown" end
    
    local username = player:getUsername() or "unknown"
    local charName = "unknown"
    
    -- 尝试获取角色名
    local descriptor = player:getDescriptor()
    if descriptor then
        charName = descriptor:getForename() or "unknown"
    end
    
    return username .. "_" .. charName
end

-- 检查是否多人模式
function HomeTeleport.isMultiplayer()
    return isServer() or isClient()
end

-- 检查是否服务器端
function HomeTeleport.isServer()
    return isServer()
end

-- 检查是否客户端
function HomeTeleport.isClient()
    return isClient()
end

-- 获取当前玩家（客户端）
function HomeTeleport.getCurrentPlayer()
    if isClient() then
        return getPlayer()
    end
    return nil
end

-- 发送客户端命令的包装函数
function HomeTeleport.sendClientCommand(command, args)
    if not isClient() then return false end
    
    local player = getPlayer()
    if not player then return false end
    
    sendClientCommand(player, HomeTeleport.COMMAND_MODULE, command, args or {})
    return true
end

-- 发送服务器命令的包装函数
function HomeTeleport.sendServerCommand(player, command, args)
    if not isServer() then return false end
    
    sendServerCommand(player, HomeTeleport.COMMAND_MODULE, command, args or {})
    return true
end

-- 车辆持久化ID生成和验证
function HomeTeleport.ensureVehiclePersistentId(vehicle)
    if not vehicle then return nil end
    
    local vmd = vehicle:getModData()
    if not vmd.homeTeleport_persistentId then
        vmd.homeTeleport_persistentId = ZombRand(1, 99999999)
    end
    
    return tostring(vmd.homeTeleport_persistentId)
end

-- 数据版本兼容性检查
function HomeTeleport.checkDataVersion(data)
    if not data then return false end
    if not data.Version then return false end
    
    -- 未来可以在这里添加版本升级逻辑
    return data.Version == "1.0"
end

-- 初始化全局数据
function HomeTeleport.initGlobalData()
    if not ModData.exists("HomeTeleport") then
        ModData.add("HomeTeleport", {
            Version = "1.0",
            WorldData = {
                SandboxHome = {x=0, y=0, z=0},
                UseSandboxHome = false
            },
            Players = {}
        })
    end
end

-- 获取玩家数据
function HomeTeleport.getPlayerData(player)
    if not player then return nil end
    
    HomeTeleport.initGlobalData()
    local globalData = ModData.get("HomeTeleport")
    
    local playerKey = HomeTeleport.getPlayerKey(player)
    if not globalData.Players[playerKey] then
        globalData.Players[playerKey] = {
            homePosition = {x=0, y=0, z=0},
            isHomeSet = false,
            currentBoundVehicleId = nil,
            wasInVehicle = false,
            wasInVehicleLastPos = nil
        }
    end
    
    return globalData.Players[playerKey]
end

-- 保存玩家数据
function HomeTeleport.savePlayerData(player, playerData)
    if not player or not playerData then return false end
    
    HomeTeleport.initGlobalData()
    local globalData = ModData.get("HomeTeleport")
    
    local playerKey = HomeTeleport.getPlayerKey(player)
    globalData.Players[playerKey] = playerData
    
    ModData.transmit("HomeTeleport")
    return true
end

-- 获取世界数据
function HomeTeleport.getWorldData()
    HomeTeleport.initGlobalData()
    local globalData = ModData.get("HomeTeleport")
    return globalData.WorldData
end

-- 保存世界数据
function HomeTeleport.saveWorldData(worldData)
    if not worldData then return false end
    
    HomeTeleport.initGlobalData()
    local globalData = ModData.get("HomeTeleport")
    globalData.WorldData = worldData
    
    ModData.transmit("HomeTeleport")
    return true
end