-- HomeTeleport Mod - Server Side Script for B42
-- 处理服务器端的数据同步

-- 防止在客户端加载此文件
if isClient() then return end

HomeTeleportServer = {}
HomeTeleportServer.Commands = {}

-- **************************************************************************************
-- 初始化玩家家的位置数据（服务端）
-- @param playerObj 玩家对象
-- **************************************************************************************
HomeTeleportServer.InitPlayerHome = function(playerObj)
    if not playerObj then return end
    
    local modData = playerObj:getModData()
    
    -- 如果玩家还没有家的位置数据，初始化
    if not modData.HomeTeleport then
        modData.HomeTeleport = {
            homePosition = {x = 0, y = 0, z = 0},
            isHomeSet = false
        }
    end
end

-- **************************************************************************************
-- 处理保存家的位置请求
-- @param playerObj 玩家对象
-- @param args 参数表 {homePosition}
-- **************************************************************************************
HomeTeleportServer.Commands.saveHomePosition = function(playerObj, args)
    if not playerObj or not args or not args.homePosition then
        print("[HomeTeleport] Invalid saveHomePosition request from client")
        return
    end
    
    -- 确保玩家家的位置数据已初始化
    HomeTeleportServer.InitPlayerHome(playerObj)
    
    local modData = playerObj:getModData()
    
    -- 保存家的位置到玩家个人数据
    modData.HomeTeleport.homePosition = args.homePosition
    modData.HomeTeleport.isHomeSet = args.isHomeSet ~= nil and args.isHomeSet or true

    print("[HomeTeleport] Player " .. tostring(playerObj:getUsername()) .. " saved home position: (" ..
          args.homePosition.x .. ", " .. args.homePosition.y .. ", " .. args.homePosition.z .. ")")

    -- 发送成功消息回客户端
    sendServerCommand(playerObj, "HomeTeleport", "homeSaved", {
        success = true
    })
end

-- **************************************************************************************
-- 处理查询家的位置请求
-- @param playerObj 玩家对象
-- **************************************************************************************
HomeTeleportServer.Commands.requestHomePosition = function(playerObj, args)
    if not playerObj then return end
    
    -- 确保玩家家的位置数据已初始化
    HomeTeleportServer.InitPlayerHome(playerObj)
    
    local modData = playerObj:getModData()
    
    -- 发送家的位置数据回客户端
    sendServerCommand(playerObj, "HomeTeleport", "homePositionUpdated", {
        homePosition = modData.HomeTeleport.homePosition,
        isHomeSet = modData.HomeTeleport.isHomeSet
    })
end

-- **************************************************************************************
-- 当玩家连接到服务器时初始化
-- **************************************************************************************
local function onConnected(playerObj)
    if not playerObj then return end
    HomeTeleportServer.InitPlayerHome(playerObj)
end

-- **************************************************************************************
-- 注册服务器命令处理器
-- **************************************************************************************
local function onClientCommand(module, command, playerObj, args)
    if module == "HomeTeleport" and HomeTeleportServer.Commands[command] then
        HomeTeleportServer.Commands[command](playerObj, args)
    end
end

-- **************************************************************************************
-- 注册事件
-- **************************************************************************************
-- B42 兼容性事件注册
if Events then
    -- 客户端命令处理（必须）
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(onClientCommand)
        print("[HomeTeleport] Registered OnClientCommand")
    else
        print("[HomeTeleport] Warning: OnClientCommand event not available")
    end
    
    -- 玩家连接事件（可选）
    if Events.OnConnected then
        Events.OnConnected.Add(onConnected)
        print("[HomeTeleport] Registered OnConnected")
    else
        print("[HomeTeleport] Info: OnConnected event not available, using OnServerStarted only")
    end
end

-- 初始化已在线的玩家（服务器启动时）
local function onServerStarted()
    print("[HomeTeleport] Server started, initializing online players...")
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            HomeTeleportServer.InitPlayerHome(player)
        end
    end
end

-- 服务器启动事件（必须）
if Events and Events.OnServerStarted then
    Events.OnServerStarted.Add(onServerStarted)
    print("[HomeTeleport] Registered OnServerStarted")
else
    print("[HomeTeleport] Error: OnServerStarted event not available - mod may not function properly")
end

print("[HomeTeleport] Server module loaded successfully")