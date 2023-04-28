--[[
@module bemfa_http
@summary 巴法云 之 HTTP API
@version 1.0.0
@author  wendal
]]

local bemfa_http = {}

--[[
初始化HTTP API
@api bemfa_http.setup(uid)
@string 巴法云的用户私钥
@return bool 成功返回true, 否则返回nil
]]
function bemfa_http.setup(uid)
    if uid == nil or type(uid) ~= "string" or #uid < 10 then
        log.error("bemfa", "非法的用户密码,必须是字符串,请到巴法云的用户界面获取")
        return
    end
    bemfa_http._uid = uid
    return true
end

function bemfa_http.uid()
    if bemfa_http._uid then
        return bemfa_http._uid
    end
    if _G.BEMFA_UID then
        return _G.BEMFA_UID
    end
    log.error("bemfa", "未设置用户私钥")
    error("未设置用户私钥")
end

local function bemfa_send(uri, is_json, rbody)
    if coroutine.running() == nil then
        log.info("bemfa", "当前调用不在task内,自动启动新task")
        sys.taskInit(bemfa_send, uri, is_json, rbody)
        return
    end
    local rheaders = {}
    if is_json then
        if type(rbody) == "table" then
            rbody = json.encode(json)
        end
        if rbody then
            rheaders["Content-Type"] = "application/json; charset=utf-8"
        end
    else
        
        if type(rbody) == "table" then
            rbody = ""
            for k, v in pairs(rbody) do
                rbody = rbody .. tostring(k) .. "=" .. string.urlEncode(tostring(v)) .. "&"
            end
        end
        if rbody then
            rheaders["Content-Type"] = "application/x-www-form-urlencoded"
        end
    end
    local code, headers, body = http.request(body == nil and "GET" or "POST", "http://apis.bemfa.com".. uri, rheaders, rbody).wait()
    if code and code == 200 then
        local resp = json.decode(body)
        if resp and resp.code and resp.code == 0 then
            return true
        end
    end
end

--[[
推送消息(5.1)
@api bemfa_http.postmsg(topic, tp, msg, wxmsg)
@string 主题名
@string 主题类型，当type=1时是MQTT协议，3是TCP协议,可选, 默认"1"
@string 消息体，要推送的消息，自定义即可，比如on，或off等等
@string 发送到微信的消息，自定义即可。如果携带此字段，会将消息发送到微信. 可选
@return bool 成功返回true, 其余返回nil
@usage
-- 官方文档 https://cloud.bemfa.com/docs/#/?id=_51-%e6%8e%a8%e9%80%81%e6%b6%88%e6%81%af
]]
function bemfa_http.postmsg(topic, tp, msg, wxmsg)
    local body = {topic=topic, [type]=(tp or "1"), msg=msg, wxmsg=wxmsg}
    body["uid"] = bemfa_http.uid()
    return bemfa_send("/va/postJsonMsg", true, body)
end

--[[
获取时间(5.15)
@api bemfa_http.timenow(type)
@string 不填默认为1，1是只获取时间，等于2获取日期和时间
@return string 当前日期和时间, 或者仅时间
@usage
-- 官方文档 https://cloud.bemfa.com/docs/#/?id=_515-%e8%8e%b7%e5%8f%96%e6%97%b6%e9%97%b4
]]
function bemfa_http.timenow(tp)
    return bemfa_send("/api/time/now/?type=" .. tostring(tp or "1"))
end

-- 微信推送消息（新）

--[[
微信推送文本消息(6.1)
@api bemfa_http.sendwechat(msg, time)
@string 要推送的消息，自定义即可
@string 1表示携带时间；为空或等于其他，不携带时间
@return bool 成功返回true, 否则返回nil
@usage
-- 官方文档 https://cloud.bemfa.com/docs/#/?id=_61-%e6%96%87%e6%9c%ac%e6%b6%88%e6%81%af
]]
function bemfa_http.sendwechat(msg, time)
    local params = "msg=" .. tostring(msg):urlEncode()
    params = params .. "&uid=" .. bemfa_http.uid()
    if time then
        params = params .. "&time=" .. tostring(time)
    end
    return bemfa_send("/v1/sendwechat?" .. params)
end

--[[
微信推送卡片消息(6.2)
@api bemfa_http.sendwechatcard(title, msg)
@string 消息标题，自定义即可
@string 要推送的消息，自定义即可
@return bool 成功返回true, 否则返回nil
@usage
-- 官方文档 https://cloud.bemfa.com/docs/#/?id=_62-%e5%8d%a1%e7%89%87%e6%b6%88%e6%81%af
]]
function bemfa_http.sendwechatcard(title, msg)
    local params = "msg=" .. tostring(msg):urlEncode()
    params = params .. "&uid=" .. bemfa_http.uid()
    params = params .. "&title=" .. tostring(title):urlEncode()
    return bemfa_send("/v1/sendwechatcard?" .. params)
end

--[[
微信推送Markdown消息(6.3)
@api bemfa_http.sendwechatmk(title, mode)
@string 消息标题，自定义即可
@string 默认为1，等于1时是普通markdown消息，等于2时是原生markdown消息
@return bool 成功返回true, 否则返回nil
@usage
-- 官方文档 https://cloud.bemfa.com/docs/#/?id=_63-markdown
]]
function bemfa_http.sendwechatcard(title, mode)
    local params = "title=" .. tostring(title):urlEncode()
    params = params .. "&uid=" .. bemfa_http.uid()
    params = params .. "&mode=" .. tostring(mode):urlEncode()
    return bemfa_send("/v1/sendwechatcard?" .. params)
end

--[[
微信推送图文消息(6.4)
@api bemfa_http.sendwechatpic(title, url, picurl, description)
@string 图文的标题，不超过128个字节，超过会自动截断
@string 点开时跳转的链接
@string 图文消息显示的封面图片链接
@string 图文消息描述，不超过512个字节，超过会自动截断, 可选
@return bool 成功返回true, 否则返回nil
@usage
-- 官方文档 https://cloud.bemfa.com/docs/#/?id=_64-%e5%9b%be%e6%96%87%e6%b6%88%e6%81%af
]]
function bemfa_http.sendwechatpic(title, url, picurl, description)
    local params = "title=" .. tostring(title):urlEncode()
    params = params .. "&uid=" .. bemfa_http.uid()
    params = params .. "&url=" .. tostring(url):urlEncode()
    params = params .. "&picurl=" .. tostring(picurl):urlEncode()
    if description then
        params = params .. "&description=" .. tostring(description):urlEncode()
    end
    return bemfa_send("/v1/sendwechatpic?" .. params)
end

-- 微信推送消息（旧）

--[[
设备预警提醒通知,旧微信消息推送
@api bemfa_http.weget(device, type, msg, msg2, url)
@string 设备名字，自定义即可
@string 1设备预警, 2设备提醒
@string 要推送的消息，自定义即可
@string 图文消息显示的封面图片链接
@string 要推送的附加消息，自定义即可
@string 点击模板跳转后跳转的链接,仅设备预警时可以传
@return bool 成功返回true, 否则返回nil
@usage
-- 官方文档 https://cloud.bemfa.com/docs/#/?id=_61-%e6%8e%a5%e5%8f%a3%e5%8d%8f%e8%ae%ae
]]
function bemfa_http.weget(device, tp, msg, msg2, url)
    local body = {
        device = device,
        type = tp or "1",
        msg = msg,
        msg2 = msg2,
        url = url,
        uid = bemfa_http.uid()
    }
    return bemfa_send("/api/wechat/v1/", false, body)
end

return bemfa_http
