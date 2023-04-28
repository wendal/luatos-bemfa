--[[
@module bemfa_mqtt
@summary 巴法云 之 MQTT设备云
@version 1.0.0
@author  wendal
]]

local bemfa_mqtt = {}

--[[
初始化MQTT设备云
@api bemfa_mqtt.setup(uid)
@string 巴法云的用户私钥
@return bool 成功返回true, 否则返回nil
]]
function bemfa_mqtt.setup(uid)
    if uid == nil then
        uid = _G.BEMFA_UID -- 取全局变量
    end
    if uid == nil or type(uid) ~= "string" or #uid < 10 then
        log.error("bemfa", "非法的用户密钥,必须是字符串,请到巴法云的控制台获取")
        return
    end
    if bemfa_mqtt.mqttc ~= nil then
        log.warn("bemfa", "只需要初始化一次")
        return
    end
    if mqtt == nil then
        log.error("bemfa", "当前固件未包含mqtt库")
        return
    end
    -- bemfa_mqtt.uid = uid
    bemfa_mqtt.mqttc = mqtt.create(nil, "bemfa.com", 9501)
    bemfa_mqtt.mqttc:auth(uid, "luatos", "123")
    bemfa_mqtt.mqttc:autoreconn(true, 3000)
    sys.taskInit(bemfa_mqtt.task)
    return true
end

function bemfa_mqtt.task()
    bemfa_mqtt.mqttc:on(function (mqtt_client, event, data, payload)
        if "conack" == event then
            bemfa_mqtt.ready = 1
            log.info("bemfa", "已连上服务器")
        elseif "recv" == event then
            log.info("bemfa", "收到下发的数据", data, payload)
        elseif "disconnect" == event then
            bemfa_mqtt.ready = nil
            log.info("bemfa", "服务器已断开或链接失败")
        end
        sys.publish("bemfa_mqtt_evt", event, data, payload)
    end)
    -- 适配的主循环
    bemfa_mqtt.mqttc:connect()
	sys.waitUntil("mqtt_conack")
    while true do
        -- 演示等待其他task发送过来的上报信息
        local ret, event, data, payload = sys.waitUntil("bemfa_mqtt_evt", 300000)
        if ret then
            -- 提供关闭本while循环的途径, 不需要可以注释掉
            if event == "close" then break end
            -- bemfa_mqtt.mqttc:publish(topic, data, qos)
        end
        -- 如果没有其他task上报, 可以写个空等待
        --sys.wait(60000000)
    end
    bemfa_mqtt.mqttc:close()
    bemfa_mqtt.mqttc = nil
end

--[[
上报数据
@api bemfa_mqtt.publish(topic, data, qos, retain)
@string 主题,必须填
@string 待上报的数据,必须填
@int    QOS,默认1,可以不填
@int    是否保存,默认0,可以不填
@return bool 成功返回true, 否则返回nil, 例如未连接上
]]
function bemfa_mqtt.publish(topic, data, qos, retain)
    if data == nil then
        return
    end
    if not bemfa_mqtt.ready then
        log.info("bemfa", "尚未连上服务器")
        return
    end
    if type(data) == "table" then
        data = json.encode(data)
    end
    if qos == nil then
        qos = 1
    end
    bemfa_mqtt.mqttc:publish(topic, data, qos ,retain)
    return true
end

--[[
上报数据, 但限定为set操作
@api bemfa_mqtt.set(topic, data, qos, retain)
@string 主题,必须填,会自动添加/set后缀
@string 待上报的数据,必须填
@int    QOS,默认1,可以不填
@int    是否保存,默认0,可以不填
@return bool 成功返回true, 否则返回nil, 例如未连接上
]]
function bemfa_mqtt.set(topic, data, qos, retain)
    return bemfa_mqtt.publish(topic .. "/set", data, qos, retain)
end


--[[
上报数据, 但限定为up操作
@api bemfa_mqtt.up(topic, data, qos, retain)
@string 主题,必须填,会自动添加/up后缀
@string 待上报的数据,必须填
@int    QOS,默认1,可以不填
@int    是否保存,默认0,可以不填
@return bool 成功返回true, 否则返回nil, 例如未连接上
]]
function bemfa_mqtt.up(topic, data, qos, retain)
    return bemfa_mqtt.publish(topic .. "/up", data, qos, retain)
end

--[[
等待数据下发
@api bemfa_mqtt.wait(timeout)
@int    超时时长,单位毫秒, 默认300000,可以不填
@return bool 是否超时,true为超时,否则为有实际发生,例如数据下发,链接成功等
@return string 事件类型, "conack"连接成功, "recv"数据下发, "disconnect"连接中断, "sent"数据上报成功
]]
function bemfa_mqtt.wait(timeout)
    return sys.waitUntil("bemfa_mqtt_evt", timeout or 300000)
end

-- function bemfa_mqtt.isReady()
--     return bemfa_mqtt.ready
-- end

return bemfa_mqtt
