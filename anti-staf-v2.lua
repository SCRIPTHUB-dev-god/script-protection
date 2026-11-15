local CONFIG = {
    ANTI_AFK_INTERVAL = 60,
    CLEANUP_INTERVAL = 300,
    USE_RANDOM_INPUT = true,
    RANDOM_INPUT_INTERVAL = 45,
    INTEGRITY_CHECK_INTERVAL = 0.5,
    IDLE_RESET_INTERVAL = 30,
}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer

local hookfunction = hookfunction or (getfenv and getfenv().hookfunction) or function(o, n) return o end
local hookmetamethod = hookmetamethod or (getfenv and getfenv().hookmetamethod) or function() end
local getnamecallmethod = getnamecallmethod or (getfenv and getfenv().getnamecallmethod) or function() return "" end
local newcclosure = newcclosure or (getfenv and getfenv().newcclosure) or function(f) return f end
local checkcaller = checkcaller or (getfenv and getfenv().checkcaller) or function() return false end
local getrawmetatable = getrawmetatable or (getfenv and getfenv().getrawmetatable) or getmetatable
local setreadonly = setreadonly or (getfenv and getfenv().setreadonly) or function() end
local isreadonly = isreadonly or (getfenv and getfenv().isreadonly) or function() return true end
local getgc = getgc or (getfenv and getfenv().getgc) or function() return {} end
local identifyexecutor = identifyexecutor or (getfenv and getfenv().identifyexecutor) or function() return "Unknown" end

local BlockedKeywords = {
    "kick", "ban", "crash", "detect", "flag", "exploit", "cheat",
    "violation", "terminate", "shutdown", "blacklist", "suspend",
    "anticheat", "anti-cheat", "guard",
}

local BlockedMethods = {
    Kick = true, kick = true, Ban = true, ban = true,
    Destroy = true, destroy = true,
    Remove = true, remove = true,
    Teleport = true, teleport = true,
    TeleportAsync = true, TeleportToPlaceInstance = true,
    KickPlayer = true, kickPlayer = true,
    Disconnect = true, disconnect = true,
}

local HookedPlayers = {}
local AntiCheatRemotes = {}
local ShutdownFlag = false
local RuntimeStart = tick()

local function containsBlocked(str)
    if type(str) ~= "string" then return false end
    local lower = string.lower(str)
    for _, kw in ipairs(BlockedKeywords) do
        if string.find(lower, kw, 1, true) then return true end
    end
    return false
end

local function deepContains(v, depth)
    depth = depth or 0
    if depth > 3 then return false end
    if type(v) == "string" then return containsBlocked(v) end
    if type(v) == "table" then
        for k, val in pairs(v) do
            if containsBlocked(k) then return true end
            if deepContains(val, depth + 1) then return true end
        end
    end
    return false
end

local function uuidPattern(name)
    if type(name) ~= "string" then return false end
    if #name == 36 and string.match(name, "^%x+%-%x+%-%x+%-%x+%-%x+$") then return true end
    if #name >= 16 and #name <= 48 then
        local hex = 0
        for i = 1, #name do
            local c = string.sub(name, i, i)
            if string.match(c, "%x") or c == "-" or c == "_" then hex = hex + 1 end
        end
        if hex / #name > 0.85 then return true end
    end
    return false
end

local function markRemote(r)
    if r and typeof(r) == "Instance" then AntiCheatRemotes[r] = true end
end

local function isACRemote(r)
    if AntiCheatRemotes[r] then return true end
    if typeof(r) == "Instance" and uuidPattern(r.Name) then
        AntiCheatRemotes[r] = true
        return true
    end
    return false
end

local NamecallOrig
local NamecallHook

NamecallHook = newcclosure(function(self, ...)
    if ShutdownFlag then return end
    local method = getnamecallmethod()
    if not method then
        if NamecallOrig then return NamecallOrig(self, ...) end
        return
    end

    if BlockedMethods[method] and not checkcaller() then
        if self == LP then return end
        if typeof(self) == "Instance" and self:IsA("Player") then return end
        if self == game then return end
    end

    if method == "FireServer" and isACRemote(self) then
        for _, v in ipairs({...}) do
            if deepContains(v) then return end
        end
    end

    if (method == "Teleport" or method == "TeleportAsync" or method == "TeleportToPlaceInstance") and not checkcaller() then
        return
    end

    if NamecallOrig then
        return NamecallOrig(self, ...)
    end
end)

pcall(function()
    local mt = getrawmetatable(game)
    if mt then
        local ro = isreadonly(mt)
        setreadonly(mt, false)
        NamecallOrig = mt.__namecall
        mt.__namecall = NamecallHook
        setreadonly(mt, ro)
    end
end)

local function hookPlayer(plr)
    if HookedPlayers[plr] then return end
    HookedPlayers[plr] = true
    if plr.Kick then
        pcall(function()
            local old = plr.Kick
            hookfunction(old, newcclosure(function(self, ...)
                if self == LP and not checkcaller() then return end
                return old(self, ...)
            end))
        end)
    end
    if plr.Destroy then
        pcall(function()
            local old = plr.Destroy
            hookfunction(old, newcclosure(function(self, ...)
                if self == LP and not checkcaller() then return end
                return old(self, ...)
            end))
        end)
    end
end

for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end
Players.PlayerAdded:Connect(function(plr) task.wait(0.1) hookPlayer(plr) end)

pcall(function()
    if TeleportService.Teleport then
        local old = TeleportService.Teleport
        hookfunction(old, newcclosure(function(self, ...)
            if not checkcaller() then return end
            return old(self, ...)
        end))
    end
    if TeleportService.TeleportAsync then
        local old = TeleportService.TeleportAsync
        hookfunction(old, newcclosure(function(self, ...)
            if not checkcaller() then return end
            return old(self, ...)
        end))
    end
end)

pcall(function()
    if LP and LP.Idled then
        LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end)

if CONFIG.USE_RANDOM_INPUT then
    task.spawn(function()
        while not ShutdownFlag do
            task.wait(CONFIG.RANDOM_INPUT_INTERVAL + math.random(-5, 5))
            pcall(function()
                VirtualUser:CaptureController()
                local cam = workspace.CurrentCamera
                if cam then
                    local vp = cam.ViewportSize
                    local _ = math.random(0, math.floor(vp.X)), math.random(0, math.floor(vp.Y))
                end
            end)
        end
    end)
end

pcall(function()
    LogService:SetLogLevel(Enum.LogLevel.Error)
end)

task.spawn(function()
    while not ShutdownFlag do
        task.wait(CONFIG.CLEANUP_INTERVAL)
        pcall(function() collectgarbage("collect") end)
    end
end)

task.spawn(function()
    while not ShutdownFlag do
        task.wait(CONFIG.INTEGRITY_CHECK_INTERVAL)
        pcall(function()
            local mt = getrawmetatable(game)
            if mt and mt.__namecall ~= NamecallHook then
                setreadonly(mt, false)
                mt.__namecall = NamecallHook
                setreadonly(mt, true)
            end
        end)
        pcall(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if not HookedPlayers[plr] then hookPlayer(plr) end
            end
        end)
        pcall(function()
            if LP and LP.Parent then
                local kickObj = LP:FindFirstChild("Kick")
                if kickObj then kickObj:Destroy() end
                local banObj = LP:FindFirstChild("Ban")
                if banObj then banObj:Destroy() end
            end
        end)
    end
end)

task.spawn(function()
    while not ShutdownFlag do
        task.wait(15)
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
                    if uuidPattern(obj.Name) then
                        AntiCheatRemotes[obj] = true
                    end
                end
            end
        end)
    end
end)

pcall(function()
    local gc = getgc(true)
    for _, v in pairs(gc) do
        if type(v) == "table" then
            local s = rawget(v, "Send")
            local g = rawget(v, "Get")
            local e = rawget(v, "Encrypt")
            if type(s) == "function" and g and e then
                pcall(function()
                    hookfunction(s, newcclosure(function(cmd, ...)
                        if type(cmd) == "string" and containsBlocked(cmd) then return end
                        return s(cmd, ...)
                    end))
                end)
            end
            local k = rawget(v, "Kill")
            local d = rawget(v, "Disconnect")
            if type(k) == "function" and d then
                pcall(function()
                    hookfunction(k, newcclosure(function() end))
                    hookfunction(d, newcclosure(function() end))
                end)
            end
        end
    end
end)

task.spawn(function()
    while not ShutdownFlag do
        task.wait(CONFIG.IDLE_RESET_INTERVAL)
        pcall(function()
            local char = LP and LP.Character
            if char then
                for _, obj in ipairs(char:GetChildren()) do
                    if (obj:IsA("LocalScript") or obj:IsA("Script")) and containsBlocked(obj.Name) then
                        obj:Destroy()
                    end
                end
            end
        end)
    end
end)

print("[SEC] Anti-Kick v2 loaded | " .. identifyexecutor() .. " | " .. tostring(math.floor(tick() - RuntimeStart)) .. "s")
