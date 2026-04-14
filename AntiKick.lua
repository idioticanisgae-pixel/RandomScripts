local players: Players = game:GetService("Players")
local guiService: GuiService = game:GetService("GuiService")
local teleportService: TeleportService = game:GetService("TeleportService")
local coreGui: CoreGui = game:GetService("CoreGui")
local runService: RunService = game:GetService("RunService")
local logService: LogService = game:GetService("LogService")

local localPlayer: Player = players.LocalPlayer
local placeId: number = game.PlaceId
local jobId: string = game.JobId

local rawMetatable: any = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
local oldNewIndex = rawMetatable.__newindex

setreadonly(rawMetatable, false)

local function bypassInternal(self, ...): any
	local method: string = getnamecallmethod()
	local args: any = { ... }

	if not checkcaller() then
		if (method == "Kick" or method == "kick") and self == localPlayer then
			return task.wait(9e9)
		end

		if method == "BreakJoints" and self == localPlayer.Character then
			return nil
		end

		if method == "SetCore" and args[1] == "PromptSignIn" then
			return nil
		end
	end

	return oldNamecall(self, ...)
end

rawMetatable.__namecall = newcclosure(bypassInternal)

rawMetatable.__index = newcclosure(function(self, key: any): any
	if not checkcaller() then
		if (key == "Kick" or key == "kick") and self == localPlayer then
			return newcclosure(function()
				return task.wait(9e9)
			end)
		end

		if key == "Clonable" and self:IsA("LocalScript") then
			return true
		end
	end

	return oldIndex(self, key)
end)

setreadonly(rawMetatable, true)

local function secureEnvironment(): ()
	for _, value in ipairs(getgc(true)) do
		if typeof(value) == "function" and islclosure(value) and not isexecutorclosure(value) then
			local constants: any = debug.getconstants(value)
			local info = debug.getinfo(value)

			for _, constant in ipairs(constants) do
				if typeof(constant) == "string" then
					local lowerConstant: string = constant:lower()
					if lowerConstant == "kick" or lowerConstant == "ban" or lowerConstant == "crash" then
						hookfunction(value, function(...)
							return nil
						end)
						break
					end
				end
			end
		end
	end
end

local function handleBypassGui(descendant: Instance): ()
	if descendant:IsA("TextLabel") then
		local text: string = descendant.Text:lower()
		if
			string.find(text, "kick")
			or string.find(text, "ban")
			or string.find(text, "disconnected")
			or string.find(text, "error")
		then
			descendant.Text = "Security: Attempted Disconnection Intercepted"
		end
	end
end

local function performRejoin(): ()
	if #players:GetPlayers() <= 1 then
		teleportService:Teleport(placeId, localPlayer)
	else
		teleportService:TeleportToPlaceInstance(placeId, jobId, localPlayer)
	end
end

guiService.ErrorMessageChanged:Connect(function()
	task.wait(0.2)
	performRejoin()
end)

teleportService.TeleportInitFailed:Connect(function()
	task.wait(1)
	performRejoin()
end)

logService.MessageOut:Connect(function(message: string, messageType: MessageType)
	if messageType == Enum.MessageType.MessageError then
		if string.find(message:lower(), "kick") or string.find(message:lower(), "sent disconnect") then
			task.spawn(performRejoin)
		end
	end
end)

pcall(function()
	for _, descendant in ipairs(coreGui:GetDescendants()) do
		handleBypassGui(descendant)
	end

	coreGui.DescendantAdded:Connect(handleBypassGui)
end)

task.spawn(secureEnvironment)
