local players: Players = game:GetService("Players")
local coreGui: CoreGui = game:GetService("CoreGui")

local localPlayer: Player = players.LocalPlayer
local mt: any = getrawmetatable(game)
local oldNamecall = mt.__namecall

setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method: string = getnamecallmethod()

    if not checkcaller() and method == "Kick" and self == localPlayer then
        return
    end

    return oldNamecall(self, ...)
end)

setreadonly(mt, true)

for _, v in ipairs(getgc(true)) do
    if typeof(v) == "function" and islclosure(v) then
        local info = debug.getinfo(v)
        if info.name then
            local functionName: string = info.name:lower()
            if functionName == "log" or functionName == "crash" or functionName == "kick" then
                hookfunction(v, function(...)
                    return
                end)
            end
        end
    end
end

local function handleKickGui(gui: Instance): ()
    if gui:IsA("TextLabel") and string.find(gui.Text:lower(), "you have been") then
        gui.Text = "[Bypass] Message Blocked"
    end
end

pcall(function()
    for _, descendant in ipairs(coreGui:GetDescendants()) do
        handleKickGui(descendant)
    end

    coreGui.DescendantAdded:Connect(handleKickGui)
end)
