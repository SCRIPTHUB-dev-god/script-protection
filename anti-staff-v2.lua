local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

local hookfunction = hookfunction or (getfenv and getfenv().hookfunction)
local getnamecallmethod = getnamecallmethod or (getfenv and getfenv().getnamecallmethod)
local newcclosure = newcclosure or (getfenv and getfenv().newcclosure) or function(f) return f end
local checkcaller = checkcaller or (getfenv and getfenv().checkcaller)
local getrawmetatable = getrawmetatable or (getfenv and getfenv().getrawmetatable)
local setreadonly = setreadonly or (getfenv and getfenv().setreadonly)
local isreadonly = isreadonly or (getfenv and getfenv().isreadonly)

local HAS_CC = checkcaller ~= nil

local function self_call()
    if not HAS_CC then return false end
    local ok, r = pcall(checkcaller)
    return ok and r
end

local BLOCK_PLAYER = {
    Kick = true, KickPlayer = true, Ban = true,
    Report = true, ReportAbuse = true, ReportPlayer = true,
}

local TELEPORT_METHODS = {
    Teleport = true, TeleportAsync = true, TeleportToPlaceInstance = true,
}

local BLOCK_STRINGS = {
    ["reportabuse"] = true, ["reportplayer"] = true, ["reportuser"] = true,
    ["kickplayer"] = true, ["banplayer"] = true, ["kickban"] = true,
}

local BLOCK_REMOTE_EXACT = {
    ["reportabuse"] = true, ["reportplayer"] = true, ["reportuser"] = true,
    ["kickplayer"] = true, ["banplayer"] = true, ["kickban"] = true,
    ["anticheatreport"] = true, ["anticheatkick"] = true,
}

local function normalize(s)
    if type(s) ~= "string" then return nil end
    if #s < 6 or #s > 64 then return nil end
    return (s:lower():gsub("[^%w]", ""))
end

local function is_bad_str(s)
    local n = normalize(s)
    return n and BLOCK_STRINGS[n] == true
end

local function args_bad(args)
    local function scan(v, depth)
        if depth > 3 then return false end
        if is_bad_str(v) then return true end
        if type(v) == "table" then
            for k, val in pairs(v) do
                if is_bad_str(k) or scan(val, depth + 1) then return true end
            end
        end
        return false
    end
    for i = 1, #args do
        if scan(args[i], 0) then return true end
    end
    return false
end

local function targets_lp(args)
    for i = 1, #args do
        local v = args[i]
        if v == LP or v == LP.UserId then return true end
        if type(v) == "table" then
            for k, val in pairs(v) do
                if val == LP or val == LP.UserId then return true end
            end
        end
    end
    return false
end

local function is_player_self(self)
    if self == LP then return true end
    return typeof(self) == "Instance" and self:IsA("Player")
end

local function is_blocked_remote(inst)
    if typeof(inst) ~= "Instance" then return false end
    if not (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then return false end
    local n = inst.Name:lower():gsub("[^%w]", "")
    return BLOCK_REMOTE_EXACT[n] == true
end

local LPChar = nil
local function refresh_char() LPChar = LP.Character end
LP.CharacterAdded:Connect(refresh_char)
refresh_char()

local function is_lp_char_child(self)
    if not LPChar then return false end
    if self == LPChar then return true end
    if typeof(self) == "Instance" and self.Parent == LPChar then return true end
    return false
end

local orig_nc
local my_nc

my_nc = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if not m then
        return orig_nc and orig_nc(self, ...)
    end

    if BLOCK_PLAYER[m] and is_player_self(self) then
        if HAS_CC and self_call() then
            return orig_nc(self, ...)
        end
        return
    end

    if m == "Destroy" or m == "Remove" then
        if is_lp_char_child(self) then
            if HAS_CC and self_call() then
                return orig_nc(self, ...)
            end
            return
        end
    end

    if TELEPORT_METHODS[m] and targets_lp({...}) then
        if not HAS_CC then
            return orig_nc(self, ...)
        end
        if self_call() then
            return orig_nc(self, ...)
        end
        return
    end

    if m == "FireServer" or m == "InvokeServer" then
        if is_blocked_remote(self) then return end
        if args_bad({...}) then return end
    end

    return orig_nc and orig_nc(self, ...)
end)

pcall(function()
    local mt = getrawmetatable(game)
    if mt then
        local ro = isreadonly and isreadonly(mt)
        if setreadonly then setreadonly(mt, false) end
        orig_nc = mt.__namecall
        mt.__namecall = my_nc
        if setreadonly then setreadonly(mt, ro) end
    end
end)

local function hook_teleport_svc(method)
    if not TeleportService[method] then return end
    pcall(function()
        local o = TeleportService[method]
        hookfunction(o, newcclosure(function(self, ...)
            if targets_lp({...}) then
                if not HAS_CC then return o(self, ...) end
                if self_call() then return o(self, ...) end
                return
            end
            return o(self, ...)
        end))
    end)
end

hook_teleport_svc("Teleport")
hook_teleport_svc("TeleportAsync")
hook_teleport_svc("TeleportToPlaceInstance")

if LP.Idled then
    LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            local rx = math.random(150, 750)
            local ry = math.random(150, 750)
            VirtualUser:ClickButton2(Vector2.new(rx, ry))
        end)
    end)
end

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local mt = getrawmetatable(game)
            if mt and mt.__namecall ~= my_nc then
                local ro = isreadonly and isreadonly(mt)
                if setreadonly then setreadonly(mt, false) end
                mt.__namecall = my_nc
                if setreadonly then setreadonly(mt, ro) end
            end
        end)
    end
end)
