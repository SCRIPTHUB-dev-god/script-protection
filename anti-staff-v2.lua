local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local NetworkClient = game:GetService("NetworkClient")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

local hookfunction = hookfunction or (getfenv and getfenv().hookfunction)
local hookmetamethod = hookmetamethod or (getfenv and getfenv().hookmetamethod)
local getnamecallmethod = getnamecallmethod or (getfenv and getfenv().getnamecallmethod)
local newcclosure = newcclosure or (getfenv and getfenv().newcclosure) or function(f) return f end
local checkcaller = checkcaller or (getfenv and getfenv().checkcaller) or function() return false end
local getrawmetatable = getrawmetatable or (getfenv and getfenv().getrawmetatable)
local setreadonly = setreadonly or (getfenv and getfenv().setreadonly)
local isreadonly = isreadonly or (getfenv and getfenv().isreadonly)
local getgc = getgc or (getfenv and getfenv().getgc) or function() return {} end

local BLOCK = {
    Kick = true, kick = true, Ban = true, ban = true,
    Destroy = true, destroy = true,
    Teleport = true, teleport = true,
    TeleportAsync = true, TeleportToPlaceInstance = true,
    KickPlayer = true, kickPlayer = true,
    Disconnect = true, disconnect = true,
}

local KEYS = {
    "kick", "ban", "detect", "flag", "exploit", "cheat",
    "violation", "terminate", "shutdown", "blacklist",
    "suspend", "anticheat", "anti-cheat",
}

local function has_key(s)
    if type(s) ~= "string" then return false end
    local l = string.lower(s)
    for i = 1, #KEYS do
        if string.find(l, KEYS[i], 1, true) then return true end
    end
    return false
end

local function deep_has(v, d)
    d = d or 0
    if d > 2 then return false end
    if type(v) == "string" then return has_key(v) end
    if type(v) == "table" then
        for k, val in pairs(v) do
            if has_key(k) or deep_has(val, d + 1) then return true end
        end
    end
    return false
end

local OutgoingKey = nil
local LastBan = 0

local function verify_ban_packet(stack)
    local counter, expected = 0, nil
    for i, v in pairs(stack) do
        if v == LP.Name or v == "Ban" or v == "Packet" or v == "Network" then
            counter = counter + 1
        elseif type(v) == "number" then
            if type(expected) == "number" then expected = expected + v else expected = v end
        end
    end
    if counter == expected then return true, counter + 5 end
    return false, 0
end

local orig_nc
local my_nc

my_nc = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if not m then
        if orig_nc then return orig_nc(self, ...) end
        return
    end

    if m == "Ban" then
        local args = {...}
        if debug and debug.validlevel and debug.validlevel(3) and self.Parent == nil then
            local stack = debug.getstack(3)
            local ok, count = verify_ban_packet(stack)
            if ok and #args == count then
                local c, key = 0, nil
                for i, v in pairs(args) do
                    if v == LP.Name or v == "Ban" or v == "Packet" or v == "Network" then
                        c = c + 1
                    elseif type(v) == "userdata" then
                        local s = tostring(v)
                        if string.match(s, "^userdata: 0x%x+$") then key = v end
                    end
                end
                if c == count and key then
                    OutgoingKey = key
                    LastBan = tick()
                    pcall(function() NetworkClient:SetOutgoingKBPSLimit(0, key) end)
                    return
                end
            end
        end
        LastBan = tick()
        return
    end

    if BLOCK[m] and not checkcaller() then
        if self == LP or self == game then return end
        if typeof(self) == "Instance" and self:IsA("Player") then return end
    end

    if m == "FireServer" then
        for _, v in ipairs({...}) do
            if deep_has(v) then return end
        end
    end

    if orig_nc then return orig_nc(self, ...) end
end)

pcall(function()
    local mt = getrawmetatable(game)
    if mt then
        local ro = isreadonly(mt)
        setreadonly(mt, false)
        orig_nc = mt.__namecall
        mt.__namecall = my_nc
        setreadonly(mt, ro)
    end
end)

local hooked = {}
local function hook_plr(p)
    if hooked[p] then return end
    hooked[p] = true
    if p.Kick then
        pcall(function()
            local o = p.Kick
            hookfunction(o, newcclosure(function(self, ...)
                if self == LP and not checkcaller() then return end
                return o(self, ...)
            end))
        end)
    end
    if p.Destroy then
        pcall(function()
            local o = p.Destroy
            hookfunction(o, newcclosure(function(self, ...)
                if self == LP and not checkcaller() then return end
                return o(self, ...)
            end))
        end)
    end
end

for _, p in ipairs(Players:GetPlayers()) do hook_plr(p) end
Players.PlayerAdded:Connect(function(p) task.wait(0.2) hook_plr(p) end)

pcall(function()
    if TeleportService.Teleport then
        local o = TeleportService.Teleport
        hookfunction(o, newcclosure(function(self, ...)
            if not checkcaller() then return end
            return o(self, ...)
        end))
    end
    if TeleportService.TeleportAsync then
        local o = TeleportService.TeleportAsync
        hookfunction(o, newcclosure(function(self, ...)
            if not checkcaller() then return end
            return o(self, ...)
        end))
    end
end)

pcall(function()
    if LP.Idled then
        LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end)

task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local mt = getrawmetatable(game)
            if mt and mt.__namecall ~= my_nc then
                setreadonly(mt, false)
                mt.__namecall = my_nc
                setreadonly(mt, true)
            end
        end)
        if OutgoingKey and tick() - LastBan < 120 then
            pcall(function() NetworkClient:SetOutgoingKBPSLimit(0, OutgoingKey) end)
        end
    end
end)
