local players: Players = game:GetService("Players")
local guiService: GuiService = game:GetService("GuiService")
local teleportService: TeleportService = game:GetService("TeleportService")
local coreGui: CoreGui = game:GetService("CoreGui")
local runService: RunService = game:GetService("RunService")

local localPlayer: Player = players.LocalPlayer
local placeId: number = game.PlaceId
local jobId: string = game.JobId

local mt: any = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
local oldNewIndex = mt.__newindex

setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method: string = getnamecallmethod()
    local args: any = {...}

    if not checkcaller() then
        if (method == "Kick" or method == "kick") and self == localPlayer then
            return nil
        end
        
        if method == "BreakJoints" and self == localPlayer.Character then
            return nil
        end
    end

    return oldNamecall(self, ...)
end)

mt.__index = newcclosure(function(self, key: string)
    if not checkcaller() then
        if (key == "Kick" or key == "kick") and self == localPlayer then
            return newcclosure(function() end)
        end
    end

    return oldIndex(self, key)
end)

setreadonly(mt, true)

local function hookGameFunctions(): ()
    for _, value in ipairs(getgc(true)) do
        if typeof(value) == "function" and islclosure(value) and not isexecutorclosure(value) then
            local info = debug.getinfo(value)
            if info.name then
                local name: string = info.name:lower()
                if name == "kick" or name == "crash" or name == "log" or name == "ban" then
                    hookfunction(value, function(...)
                        return nil
                    end)
                end
            end
        end
    end
end

local function handleBypassGui(descendant: Instance): ()
    if descendant:IsA("TextLabel") then
        local text: string = descendant.Text:lower()
        if string.find(text, "kick") or string.find(text, "ban") or string.find(text, "disconnected") then
            descendant.Text = "[Security] Intercepted Execution"
        end
    end
end

local function initiateAutoRejoin(): ()
    if #players:GetPlayers() <= 1 then
        teleportService:Teleport(placeId, localPlayer)
    else
        teleportService:TeleportToPlaceInstance(placeId, jobId, localPlayer)
    end
end

guiService.ErrorMessageChanged:Connect(function()
    task.wait(0.5)
    initiateAutoRejoin()
end)

pcall(function()
    for _, descendant in ipairs(coreGui:GetDescendants()) do
        handleBypassGui(descendant)
    end

    coreGui.DescendantAdded:Connect(handleBypassGui)
end)

task.spawn(hookGameFunctions)
