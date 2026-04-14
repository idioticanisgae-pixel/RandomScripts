local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local _existing = playerGui:FindFirstChild("Synapse X")
if _existing then
	_existing:Destroy()
end
local T = {
	BG_DEEP = Color3.fromRGB(14, 14, 18),
	BG_MID = Color3.fromRGB(22, 22, 28),
	BG_PANEL = Color3.fromRGB(18, 18, 24),
	BG_EDITOR = Color3.fromRGB(12, 12, 16),
	BG_BTN = Color3.fromRGB(32, 32, 42),
	BG_BTN_HOV = Color3.fromRGB(46, 46, 60),
	BG_TAB_ACT = Color3.fromRGB(18, 18, 24),
	BG_ANALYZER = Color3.fromRGB(16, 16, 22),
	STROKE_OUTER = Color3.fromRGB(50, 50, 70),
	STROKE_INNER = Color3.fromRGB(38, 38, 55),
	STROKE_BTN = Color3.fromRGB(50, 50, 68),
	STROKE_ACCENT = Color3.fromRGB(90, 90, 210),
	STROKE_WARN = Color3.fromRGB(210, 120, 40),
	STROKE_OK = Color3.fromRGB(50, 190, 90),
	TEXT_MAIN = Color3.fromRGB(220, 220, 235),
	TEXT_DIM = Color3.fromRGB(110, 110, 135),
	TEXT_TAB = Color3.fromRGB(190, 190, 210),
	TEXT_ACCENT = Color3.fromRGB(140, 140, 255),
	TEXT_WARN = Color3.fromRGB(255, 165, 60),
	TEXT_OK = Color3.fromRGB(80, 220, 120),
	TEXT_ERR = Color3.fromRGB(255, 85, 85),
	ICON_TINT = Color3.fromRGB(160, 160, 185),
	CLOSE_HOV = Color3.fromRGB(180, 45, 45),
	ATTACH_ON = Color3.fromRGB(50, 180, 80),
	ACCENT_GLOW = Color3.fromRGB(70, 70, 200),
}
local NETWORK_METHODS = {
	FireServer = true,
	InvokeServer = true,
	FireAllClients = true,
	FireClient = true,
	InvokeClient = true,
}
local SCAN_COOLDOWN = 8
local ModuleAnalyzer = {
	Results = {},
	_lastScan = 0,
	_scanning = false,
	Settings = {
		ScanUpvalues = true,
		Verbose = false,
		MaxResults = 500,
	},
}
local function maLog(level, msg)
	if level == "verbose" and not ModuleAnalyzer.Settings.Verbose then
		return
	end
	print(string.format("[ModuleAnalyzer][%s] %s", level:upper(), msg))
end
local function GetPath(obj)
	if not obj then
		return "Nil/Unknown"
	end
	local ok, path = pcall(function()
		return obj:GetFullName()
	end)
	return ok and path or "Unknown"
end
function ModuleAnalyzer:Clear()
	table.clear(self.Results)
	self._resultCount = 0
end
function ModuleAnalyzer:Analyze(onProgress, onDone)
	if self._scanning then
		maLog("warn", "Scan already in progress.")
		return false
	end
	if tick() - self._lastScan < SCAN_COOLDOWN then
		maLog("warn", string.format("Cooldown active (%.1fs remaining).", SCAN_COOLDOWN - (tick() - self._lastScan)))
		return false
	end
	self._scanning = true
	self:Clear()
	local resultCount = 0
	local gcObjects = getgc(true)
	local total = #gcObjects
	task.spawn(function()
		for idx, v in ipairs(gcObjects) do
			if resultCount >= self.Settings.MaxResults then
				maLog("warn", "MaxResults cap reached, stopping early.")
				break
			end
			if type(v) == "function" and islclosure(v) then
				local envOk, env = pcall(getfenv, v)
				if not envOk then
					goto continue
				end
				local scriptOwner = env.script
				if not scriptOwner then
					goto continue
				end
				local isModuleOk, isModule = pcall(function()
					return scriptOwner:IsA("ModuleScript")
				end)
				if not isModuleOk or not isModule then
					goto continue
				end
				local constantsOk, constants = pcall(getconstants, v)
				if not constantsOk then
					goto continue
				end
				local isNetworkActive = false
				local matchedMethods = {}
				for _, constant in ipairs(constants) do
					if type(constant) == "string" and NETWORK_METHODS[constant] then
						isNetworkActive = true
						matchedMethods[constant] = true
					end
				end
				if isNetworkActive then
					local scriptPath = GetPath(scriptOwner)
					local infoOk, funcInfo = pcall(debug.getinfo, v)
					local funcName = (infoOk and funcInfo and funcInfo.name) or "Anonymous"
					local lineDefined = (infoOk and funcInfo and funcInfo.linedefined) or -1
					local detectedRemotes = {}
					if self.Settings.ScanUpvalues then
						local upOk, upvalues = pcall(getupvalues, v)
						if upOk then
							for _, upvalue in pairs(upvalues) do
								if type(upvalue) == "userdata" then
									local chk, isRemote = pcall(function()
										return upvalue:IsA("RemoteEvent") or upvalue:IsA("RemoteFunction")
									end)
									if chk and isRemote then
										table.insert(detectedRemotes, {
											Instance = upvalue,
											Path = GetPath(upvalue),
											RawName = upvalue.Name,
										})
									end
								end
							end
						end
					end
					local cleanConstants = {}
					for _, c in ipairs(constants) do
						if type(c) == "string" and #c > 1 then
							table.insert(cleanConstants, c)
						end
					end
					if not self.Results[scriptPath] then
						self.Results[scriptPath] = {}
					end
					table.insert(self.Results[scriptPath], {
						FunctionName = funcName,
						Line = lineDefined,
						Constants = cleanConstants,
						Remotes = detectedRemotes,
						MatchedMethods = matchedMethods,
					})
					resultCount += 1
					maLog(
						"verbose",
						string.format(
							"[%s] %s @ line %d | remotes: %d",
							scriptPath,
							funcName,
							lineDefined,
							#detectedRemotes
						)
					)
				end
			end
			::continue::
			if idx % 100 == 0 then
				if onProgress then
					pcall(onProgress, idx, total)
				end
				task.wait()
			end
		end
		self._lastScan = tick()
		self._scanning = false
		self._resultCount = resultCount
		maLog("info", string.format("Scan complete. %d network-active functions found.", resultCount))
		if onDone then
			pcall(onDone, resultCount)
		end
	end)
	return true
end
function ModuleAnalyzer:GetFlatResults()
	local flat = {}
	for path, funcs in pairs(self.Results) do
		for _, data in ipairs(funcs) do
			table.insert(flat, {
				Module = path,
				FuncName = data.FunctionName,
				Line = data.Line,
				Constants = data.Constants,
				Remotes = data.Remotes,
				Methods = data.MatchedMethods,
			})
		end
	end
	table.sort(flat, function(a, b)
		return a.Module < b.Module
	end)
	return flat
end
function ModuleAnalyzer:GetByRemote(remotePath)
	local found = {}
	for path, funcs in pairs(self.Results) do
		for _, data in ipairs(funcs) do
			for _, r in ipairs(data.Remotes) do
				if r.Path:find(remotePath, 1, true) then
					table.insert(found, { Module = path, FuncName = data.FunctionName, Remote = r.Path })
				end
			end
		end
	end
	return found
end
function ModuleAnalyzer:Find(moduleFrag, funcName, callback)
	for path, funcs in pairs(self.Results) do
		if path:find(moduleFrag, 1, true) then
			for _, data in ipairs(funcs) do
				if not funcName or data.FunctionName == funcName then
					if callback then
						callback(path, data)
					end
				end
			end
		end
	end
end
function ModuleAnalyzer:Export()
	local exportable = {}
	for path, funcs in pairs(self.Results) do
		local fList = {}
		for _, d in ipairs(funcs) do
			local remPaths = {}
			for _, r in ipairs(d.Remotes) do
				table.insert(remPaths, r.Path)
			end
			table.insert(fList, {
				name = d.FunctionName,
				line = d.Line,
				remotes = remPaths,
				constants = d.Constants,
			})
		end
		table.insert(exportable, { module = path, functions = fList })
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, exportable)
	return ok and json or nil
end
local function stroke(parent, color, thickness, lineJoin)
	local s = Instance.new("UIStroke")
	s.Color = color or T.STROKE_INNER
	s.Thickness = thickness or 1
	s.LineJoinMode = lineJoin or Enum.LineJoinMode.Miter
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 4)
	c.Parent = parent
	return c
end
local function flash(btn, col)
	local orig = btn.BackgroundColor3
	TweenService:Create(btn, TweenInfo.new(0.06), { BackgroundColor3 = col or T.BG_BTN_HOV }):Play()
	task.delay(0.14, function()
		if btn and btn.Parent then
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = orig }):Play()
		end
	end)
end
local function hoverEffect(btn, hoverCol, normalCol)
	normalCol = normalCol or btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = hoverCol }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = normalCol }):Play()
	end)
end
local function makeLabel(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.Font or Enum.Font.Gotham
	l.TextSize = props.TextSize or 12
	l.TextColor3 = props.TextColor3 or T.TEXT_MAIN
	l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	l.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Size = props.Size or UDim2.new(1, 0, 1, 0)
	l.Position = props.Position or UDim2.new()
	l.Text = props.Text or ""
	l.ZIndex = props.ZIndex or 1
	l.RichText = props.RichText or false
	l.Parent = parent
	return l
end
local Syntax = {
	Text = Color3.fromRGB(204, 204, 204),
	Operator = Color3.fromRGB(204, 204, 204),
	Number = Color3.fromRGB(255, 198, 0),
	String = Color3.fromRGB(173, 241, 149),
	Comment = Color3.fromRGB(100, 100, 120),
	Keyword = Color3.fromRGB(248, 109, 124),
	BuiltIn = Color3.fromRGB(132, 214, 247),
	LocalMethod = Color3.fromRGB(253, 251, 172),
	LocalProperty = Color3.fromRGB(97, 161, 241),
	Nil = Color3.fromRGB(255, 198, 0),
	Bool = Color3.fromRGB(255, 198, 0),
	Function = Color3.fromRGB(248, 109, 124),
	Local = Color3.fromRGB(248, 109, 124),
	Self = Color3.fromRGB(248, 109, 124),
	FunctionName = Color3.fromRGB(253, 251, 172),
	Bracket = Color3.fromRGB(204, 204, 204),
}
local HL_KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["until"] = true,
	["while"] = true,
	["false"] = true,
	["true"] = true,
	["nil"] = true,
}
local HL_BUILTINS = {
	["game"] = true,
	["Players"] = true,
	["TweenService"] = true,
	["ScreenGui"] = true,
	["Instance"] = true,
	["UDim2"] = true,
	["Vector2"] = true,
	["Vector3"] = true,
	["Color3"] = true,
	["Enum"] = true,
	["loadstring"] = true,
	["warn"] = true,
	["pcall"] = true,
	["print"] = true,
	["UDim"] = true,
	["delay"] = true,
	["require"] = true,
	["spawn"] = true,
	["tick"] = true,
	["getfenv"] = true,
	["workspace"] = true,
	["setfenv"] = true,
	["getgenv"] = true,
	["script"] = true,
	["string"] = true,
	["pairs"] = true,
	["type"] = true,
	["math"] = true,
	["tonumber"] = true,
	["tostring"] = true,
	["CFrame"] = true,
	["BrickColor"] = true,
	["table"] = true,
	["Random"] = true,
	["Ray"] = true,
	["xpcall"] = true,
	["coroutine"] = true,
	["_G"] = true,
	["_VERSION"] = true,
	["debug"] = true,
	["Axes"] = true,
	["assert"] = true,
	["error"] = true,
	["ipairs"] = true,
	["rawequal"] = true,
	["rawget"] = true,
	["rawset"] = true,
	["select"] = true,
	["bit32"] = true,
	["buffer"] = true,
	["task"] = true,
	["os"] = true,
	["getgc"] = true,
	["islclosure"] = true,
	["getconstants"] = true,
	["getupvalues"] = true,
	["hookfunction"] = true,
	["getconnections"] = true,
	["decompile"] = true,
	["readfile"] = true,
	["writefile"] = true,
	["isfile"] = true,
}
local HL_METHODS = {
	["WaitForChild"] = true,
	["FindFirstChild"] = true,
	["GetService"] = true,
	["Destroy"] = true,
	["Clone"] = true,
	["IsA"] = true,
	["ClearAllChildren"] = true,
	["GetChildren"] = true,
	["GetDescendants"] = true,
	["Connect"] = true,
	["Disconnect"] = true,
	["Fire"] = true,
	["Invoke"] = true,
	["rgb"] = true,
	["FireServer"] = true,
	["request"] = true,
	["call"] = true,
	["JSONEncode"] = true,
	["JSONDecode"] = true,
	["GetFullName"] = true,
}
local function colorToHex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end
local function hlTokenize(line)
	local tokens, i = {}, 1
	while i <= #line do
		local c = line:sub(i, i)
		if c == "-" and line:sub(i, i + 1) == "--" then
			table.insert(tokens, { line:sub(i), "Comment" })
			break
		elseif c == "[" and line:sub(i, i + 1):match("%[=*%[") then
			local eqCount, k = 0, i + 1
			while line:sub(k, k) == "=" do
				eqCount += 1
				k += 1
			end
			if line:sub(k, k) == "[" then
				local close = "]" .. string.rep("=", eqCount) .. "]"
				local endIdx = line:find(close, k + 1, true)
				local j = endIdx and (endIdx + #close - 1) or #line
				table.insert(tokens, { line:sub(i, j), "String" })
				i = j
			else
				table.insert(tokens, { c, "Operator" })
			end
		elseif c == '"' or c == "'" then
			local q, j = c, i + 1
			while j <= #line do
				if line:sub(j, j) == q and line:sub(j - 1, j - 1) ~= "\\" then
					break
				end
				j += 1
			end
			table.insert(tokens, { line:sub(i, j), "String" })
			i = j
		elseif c:match("%d") then
			local j = i
			while j <= #line and line:sub(j, j):match("[%d%.xXa-fA-F_]") do
				j += 1
			end
			table.insert(tokens, { line:sub(i, j - 1), "Number" })
			i = j - 1
		elseif c:match("[%a_]") then
			local j = i
			while j <= #line and line:sub(j, j):match("[%w_]") do
				j += 1
			end
			table.insert(tokens, { line:sub(i, j - 1), "Word" })
			i = j - 1
		else
			table.insert(tokens, { c, "Operator" })
		end
		i += 1
	end
	return tokens
end
local function hlDetect(tokens, idx)
	local val, typ = tokens[idx][1], tokens[idx][2]
	if typ ~= "Word" then
		return typ
	end
	if val == "self" then
		return "Self"
	end
	if val == "true" or val == "false" then
		return "Bool"
	end
	if val == "nil" then
		return "Nil"
	end
	if HL_KEYWORDS[val] then
		return "Keyword"
	end
	if HL_BUILTINS[val] then
		return "BuiltIn"
	end
	if HL_METHODS[val] then
		return "LocalMethod"
	end
	local prev = idx > 1 and tokens[idx - 1][1] or ""
	if prev == "." then
		return "LocalProperty"
	end
	if prev == ":" then
		return "LocalMethod"
	end
	if prev == "function" then
		return "FunctionName"
	end
	return "Text"
end
local function hlLine(line)
	local tokens = hlTokenize(line)
	local out = ""
	for i, tok in ipairs(tokens) do
		local col = Syntax[hlDetect(tokens, i)] or Syntax.Text
		local safe = tok[1]:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		out ..= string.format('<font color="%s">%s</font>', colorToHex(col), safe)
	end
	return out
end
local function applySyntaxHighlight(source, overlayLabel)
	if not overlayLabel then
		return
	end
	local lines = source:split("\n")
	local rendered = {}
	for _, ln in ipairs(lines) do
		rendered[#rendered + 1] = hlLine(ln)
	end
	overlayLabel.Text = table.concat(rendered, "\n")
end
local function updateLineNumbers(codeText, lineLabel)
	local count = 1
	for _ in codeText:gmatch("\n") do
		count += 1
	end
	local lines = {}
	for i = 1, count do
		lines[i] = tostring(i)
	end
	lineLabel.Text = table.concat(lines, "\n")
end
local function createGui()
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "Synapse X"
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	ScreenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
	local ToggleBtn = Instance.new("ImageButton")
	ToggleBtn.Parent = ScreenGui
	ToggleBtn.Name = "ToggleBtn"
	ToggleBtn.Size = UDim2.fromOffset(46, 46)
	ToggleBtn.Position = UDim2.fromScale(0.965, 0.94)
	ToggleBtn.BackgroundColor3 = T.BG_MID
	ToggleBtn.BorderSizePixel = 0
	ToggleBtn.Image = "rbxassetid://9524079125"
	ToggleBtn.ImageColor3 = T.ICON_TINT
	ToggleBtn.ScaleType = Enum.ScaleType.Fit
	ToggleBtn.Style = Enum.ButtonStyle.Custom
	corner(ToggleBtn, 8)
	stroke(ToggleBtn, T.STROKE_OUTER, 1)
	hoverEffect(ToggleBtn, T.BG_BTN_HOV, T.BG_MID)
	local MainFrame = Instance.new("Frame")
	MainFrame.Parent = ScreenGui
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.fromOffset(760, 420)
	MainFrame.Position = UDim2.fromScale(0.05, 0.07)
	MainFrame.Visible = false
	MainFrame.BackgroundColor3 = T.BG_DEEP
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	corner(MainFrame, 6)
	stroke(MainFrame, T.STROKE_OUTER, 1)
	local TitleBar = Instance.new("Frame")
	TitleBar.Parent = MainFrame
	TitleBar.Name = "TitleBar"
	TitleBar.Size = UDim2.new(1, 0, 0, 30)
	TitleBar.Position = UDim2.fromOffset(0, 0)
	TitleBar.BackgroundColor3 = T.BG_MID
	TitleBar.BorderSizePixel = 0
	TitleBar.ZIndex = 2
	local TitleIcon = Instance.new("ImageLabel")
	TitleIcon.Parent = TitleBar
	TitleIcon.Size = UDim2.fromOffset(16, 16)
	TitleIcon.Position = UDim2.fromOffset(10, 7)
	TitleIcon.BackgroundTransparency = 1
	TitleIcon.Image = "rbxassetid://9524079125"
	TitleIcon.ImageColor3 = T.TEXT_ACCENT
	TitleIcon.ScaleType = Enum.ScaleType.Fit
	TitleIcon.ZIndex = 3
	makeLabel(TitleBar, {
		Text = "Synapse X",
		Size = UDim2.new(1, -130, 1, 0),
		Position = UDim2.fromOffset(32, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.TEXT_MAIN,
		ZIndex = 3,
	})
	local AccentLine = Instance.new("Frame")
	AccentLine.Parent = MainFrame
	AccentLine.Size = UDim2.new(1, 0, 0, 1)
	AccentLine.Position = UDim2.fromOffset(0, 30)
	AccentLine.BackgroundColor3 = T.STROKE_ACCENT
	AccentLine.BorderSizePixel = 0
	AccentLine.ZIndex = 2
	local function makeTitleBtn(name, label, xOff)
		local b = Instance.new("TextButton")
		b.Parent = TitleBar
		b.Name = name
		b.Size = UDim2.fromOffset(28, 20)
		b.Position = UDim2.new(1, xOff, 0, 5)
		b.BackgroundColor3 = T.BG_MID
		b.BorderSizePixel = 0
		b.Text = label
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = T.TEXT_DIM
		b.ZIndex = 4
		return b
	end
	local CloseBtn = makeTitleBtn("CloseBtn", "✕", -32)
	local MinBtn = makeTitleBtn("MinBtn", "─", -64)
	hoverEffect(CloseBtn, T.CLOSE_HOV, T.BG_MID)
	CloseBtn.MouseEnter:Connect(function()
		TweenService:Create(CloseBtn, TweenInfo.new(0.08), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
	end)
	CloseBtn.MouseLeave:Connect(function()
		TweenService:Create(CloseBtn, TweenInfo.new(0.08), { TextColor3 = T.TEXT_DIM }):Play()
	end)
	hoverEffect(MinBtn, T.BG_BTN_HOV, T.BG_MID)
	local TabBar = Instance.new("Frame")
	TabBar.Parent = MainFrame
	TabBar.Name = "TabBar"
	TabBar.Size = UDim2.new(1, 0, 0, 24)
	TabBar.Position = UDim2.fromOffset(0, 31)
	TabBar.BackgroundColor3 = T.BG_PANEL
	TabBar.BorderSizePixel = 0
	local TabBarLine = Instance.new("Frame")
	TabBarLine.Parent = TabBar
	TabBarLine.Size = UDim2.new(1, 0, 0, 1)
	TabBarLine.Position = UDim2.new(0, 0, 1, -1)
	TabBarLine.BackgroundColor3 = T.STROKE_INNER
	TabBarLine.BorderSizePixel = 0
	local Tab1 = Instance.new("Frame")
	Tab1.Parent = TabBar
	Tab1.Name = "Tab1"
	Tab1.Size = UDim2.fromOffset(92, 24)
	Tab1.Position = UDim2.fromOffset(0, 0)
	Tab1.BackgroundColor3 = T.BG_TAB_ACT
	Tab1.BorderSizePixel = 0
	makeLabel(Tab1, {
		Text = "Script 1",
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = T.TEXT_TAB,
	})
	local Tab1Close = Instance.new("TextButton")
	Tab1Close.Parent = Tab1
	Tab1Close.Name = "TabClose"
	Tab1Close.Size = UDim2.fromOffset(16, 16)
	Tab1Close.Position = UDim2.new(1, -18, 0, 4)
	Tab1Close.BackgroundColor3 = T.BG_TAB_ACT
	Tab1Close.BorderSizePixel = 0
	Tab1Close.Text = "✕"
	Tab1Close.Font = Enum.Font.Gotham
	Tab1Close.TextSize = 9
	Tab1Close.TextColor3 = T.TEXT_DIM
	hoverEffect(Tab1Close, T.CLOSE_HOV, T.BG_TAB_ACT)
	stroke(Tab1, T.STROKE_INNER, 1)
	local Tab2 = Instance.new("Frame")
	Tab2.Parent = TabBar
	Tab2.Name = "Tab2"
	Tab2.Size = UDim2.fromOffset(110, 24)
	Tab2.Position = UDim2.fromOffset(92, 0)
	Tab2.BackgroundColor3 = T.BG_PANEL
	Tab2.BorderSizePixel = 0
	local Tab2Label = makeLabel(Tab2, {
		Text = "⬡ Analyzer",
		Size = UDim2.new(1, 0, 1, 0),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = T.TEXT_DIM,
		XAlign = Enum.TextXAlignment.Center,
	})
	hoverEffect(Tab2, T.BG_BTN_HOV, T.BG_PANEL)
	stroke(Tab2, T.STROKE_INNER, 1)
	local NewTabBtn = Instance.new("TextButton")
	NewTabBtn.Parent = TabBar
	NewTabBtn.Name = "NewTab"
	NewTabBtn.Size = UDim2.fromOffset(24, 24)
	NewTabBtn.Position = UDim2.fromOffset(202, 0)
	NewTabBtn.BackgroundColor3 = T.BG_PANEL
	NewTabBtn.BorderSizePixel = 0
	NewTabBtn.Text = "+"
	NewTabBtn.Font = Enum.Font.GothamBold
	NewTabBtn.TextSize = 14
	NewTabBtn.TextColor3 = T.TEXT_DIM
	hoverEffect(NewTabBtn, T.BG_BTN_HOV, T.BG_PANEL)
	local EDITOR_TOP = 55
	local EDITOR_HEIGHT = 276
	local TOOLBAR_H = 36
	local GUTTER_W = 40
	local Gutter = Instance.new("Frame")
	Gutter.Parent = MainFrame
	Gutter.Name = "Gutter"
	Gutter.Size = UDim2.fromOffset(GUTTER_W, EDITOR_HEIGHT)
	Gutter.Position = UDim2.fromOffset(0, EDITOR_TOP)
	Gutter.BackgroundColor3 = T.BG_PANEL
	Gutter.BorderSizePixel = 0
	Gutter.ClipsDescendants = true
	Gutter.ZIndex = 2
	local GutterLine = Instance.new("Frame")
	GutterLine.Parent = Gutter
	GutterLine.Size = UDim2.new(0, 1, 1, 0)
	GutterLine.Position = UDim2.new(1, -1, 0, 0)
	GutterLine.BackgroundColor3 = T.STROKE_INNER
	GutterLine.BorderSizePixel = 0
	GutterLine.ZIndex = 3
	local LineNumbers = Instance.new("TextLabel")
	LineNumbers.Parent = Gutter
	LineNumbers.Name = "LineNumbers"
	LineNumbers.Size = UDim2.new(1, -4, 10, 0)
	LineNumbers.Position = UDim2.fromOffset(0, 5)
	LineNumbers.BackgroundTransparency = 1
	LineNumbers.Text = "1"
	LineNumbers.Font = Enum.Font.Code
	LineNumbers.TextSize = 13
	LineNumbers.TextColor3 = T.TEXT_DIM
	LineNumbers.TextXAlignment = Enum.TextXAlignment.Right
	LineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	LineNumbers.ZIndex = 3
	local EditorFrame = Instance.new("ScrollingFrame")
	EditorFrame.Parent = MainFrame
	EditorFrame.Name = "EditorScroll"
	EditorFrame.Size = UDim2.fromOffset(760 - GUTTER_W, EDITOR_HEIGHT)
	EditorFrame.Position = UDim2.fromOffset(GUTTER_W, EDITOR_TOP)
	EditorFrame.BackgroundColor3 = T.BG_EDITOR
	EditorFrame.BorderSizePixel = 0
	EditorFrame.ClipsDescendants = true
	EditorFrame.ScrollBarThickness = 5
	EditorFrame.ScrollBarImageColor3 = T.STROKE_BTN
	EditorFrame.ScrollingDirection = Enum.ScrollingDirection.XY
	EditorFrame.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	EditorFrame.CanvasSize = UDim2.new(2, 0, 4, 0)
	EditorFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
	EditorFrame.BottomImage = ""
	EditorFrame.MidImage = ""
	EditorFrame.TopImage = ""
	stroke(EditorFrame, T.STROKE_INNER, 1)
	local HighlightLabel = Instance.new("TextLabel")
	HighlightLabel.Parent = EditorFrame
	HighlightLabel.Name = "HighlightLabel"
	HighlightLabel.Size = UDim2.new(1, -8, 1, 0)
	HighlightLabel.Position = UDim2.fromOffset(6, 5)
	HighlightLabel.BackgroundTransparency = 1
	HighlightLabel.Text = ""
	HighlightLabel.Font = Enum.Font.Code
	HighlightLabel.TextSize = 13
	HighlightLabel.TextColor3 = T.TEXT_MAIN
	HighlightLabel.TextXAlignment = Enum.TextXAlignment.Left
	HighlightLabel.TextYAlignment = Enum.TextYAlignment.Top
	HighlightLabel.TextTruncate = Enum.TextTruncate.None
	HighlightLabel.RichText = true
	HighlightLabel.ZIndex = 1
	local CodeBox = Instance.new("TextBox")
	CodeBox.Parent = EditorFrame
	CodeBox.Name = "CodeBox"
	CodeBox.Size = UDim2.new(1, -8, 1, 0)
	CodeBox.Position = UDim2.fromOffset(6, 5)
	CodeBox.BackgroundTransparency = 1
	CodeBox.Text = ""
	CodeBox.Font = Enum.Font.Code
	CodeBox.TextSize = 13
	CodeBox.TextColor3 = Color3.fromRGB(0, 0, 0)
	CodeBox.TextTransparency = 1
	CodeBox.TextXAlignment = Enum.TextXAlignment.Left
	CodeBox.TextYAlignment = Enum.TextYAlignment.Top
	CodeBox.TextTruncate = Enum.TextTruncate.None
	CodeBox.TextStrokeTransparency = 1
	CodeBox.PlaceholderText = "-- paste or type your script here"
	CodeBox.PlaceholderColor3 = T.TEXT_DIM
	CodeBox.ClearTextOnFocus = false
	CodeBox.MultiLine = true
	CodeBox.ZIndex = 2
	local AnalyzerPanel = Instance.new("Frame")
	AnalyzerPanel.Parent = MainFrame
	AnalyzerPanel.Name = "AnalyzerPanel"
	AnalyzerPanel.Size = UDim2.fromOffset(760, EDITOR_HEIGHT + GUTTER_W)
	AnalyzerPanel.Position = UDim2.fromOffset(0, EDITOR_TOP)
	AnalyzerPanel.BackgroundColor3 = T.BG_ANALYZER
	AnalyzerPanel.BorderSizePixel = 0
	AnalyzerPanel.Visible = false
	AnalyzerPanel.ClipsDescendants = true
	local ABar = Instance.new("Frame")
	ABar.Parent = AnalyzerPanel
	ABar.Size = UDim2.new(1, 0, 0, 34)
	ABar.BackgroundColor3 = T.BG_MID
	ABar.BorderSizePixel = 0
	local ABarLine = Instance.new("Frame")
	ABarLine.Parent = ABar
	ABarLine.Size = UDim2.new(1, 0, 0, 1)
	ABarLine.Position = UDim2.new(0, 0, 1, -1)
	ABarLine.BackgroundColor3 = T.STROKE_INNER
	ABarLine.BorderSizePixel = 0
	makeLabel(ABar, {
		Text = "MODULE ANALYZER",
		Size = UDim2.fromOffset(200, 34),
		Position = UDim2.fromOffset(10, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = T.TEXT_ACCENT,
		XAlign = Enum.TextXAlignment.Left,
	})
	local StatusLabel = makeLabel(ABar, {
		Text = "Ready.",
		Size = UDim2.fromOffset(280, 34),
		Position = UDim2.fromOffset(210, 0),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = T.TEXT_DIM,
		XAlign = Enum.TextXAlignment.Left,
	})
	StatusLabel.Name = "StatusLabel"
	local function makeABtn(label, xOff, accentStroke)
		local b = Instance.new("TextButton")
		b.Parent = ABar
		b.Size = UDim2.fromOffset(90, 22)
		b.Position = UDim2.new(1, xOff, 0, 6)
		b.BackgroundColor3 = T.BG_BTN
		b.BorderSizePixel = 0
		b.Text = label
		b.Font = Enum.Font.Gotham
		b.TextSize = 11
		b.TextColor3 = T.TEXT_MAIN
		b.ZIndex = 2
		local s = stroke(b, accentStroke and T.STROKE_ACCENT or T.STROKE_BTN, 1)
		hoverEffect(b, T.BG_BTN_HOV, T.BG_BTN)
		return b, s
	end
	local ScanBtn, _ = makeABtn("⬡ Scan", -282, true)
	local ExportBtn, _ = makeABtn("↓ Export", -188, false)
	local ClearABtn, _ = makeABtn("✕ Clear", -94, false)
	ScanBtn.Name = "ScanBtn"
	ExportBtn.Name = "ExportBtn"
	ClearABtn.Name = "ClearABtn"
	local ResultsScroll = Instance.new("ScrollingFrame")
	ResultsScroll.Parent = AnalyzerPanel
	ResultsScroll.Name = "ResultsScroll"
	ResultsScroll.Size = UDim2.new(1, 0, 1, -34)
	ResultsScroll.Position = UDim2.fromOffset(0, 34)
	ResultsScroll.BackgroundColor3 = T.BG_ANALYZER
	ResultsScroll.BorderSizePixel = 0
	ResultsScroll.ScrollBarThickness = 5
	ResultsScroll.ScrollBarImageColor3 = T.STROKE_BTN
	ResultsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	ResultsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ResultsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	local ResultsList = Instance.new("Frame")
	ResultsList.Parent = ResultsScroll
	ResultsList.Name = "ResultsList"
	ResultsList.Size = UDim2.new(1, 0, 0, 0)
	ResultsList.AutomaticSize = Enum.AutomaticSize.Y
	ResultsList.BackgroundTransparency = 1
	ResultsList.BorderSizePixel = 0
	local ResultsLayout = Instance.new("UIListLayout")
	ResultsLayout.Parent = ResultsList
	ResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ResultsLayout.Padding = UDim.new(0, 1)
	local ResultsPad = Instance.new("UIPadding")
	ResultsPad.Parent = ResultsList
	ResultsPad.PaddingTop = UDim.new(0, 4)
	ResultsPad.PaddingLeft = UDim.new(0, 6)
	ResultsPad.PaddingRight = UDim.new(0, 6)
	ResultsPad.PaddingBottom = UDim.new(0, 4)
	local EmptyLabel = makeLabel(ResultsList, {
		Text = "No results yet. Press  ⬡ Scan  to analyze module scripts.",
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = T.TEXT_DIM,
		XAlign = Enum.TextXAlignment.Center,
	})
	EmptyLabel.Name = "EmptyLabel"
	local Toolbar = Instance.new("Frame")
	Toolbar.Parent = MainFrame
	Toolbar.Name = "Toolbar"
	Toolbar.Size = UDim2.new(1, 0, 0, TOOLBAR_H)
	Toolbar.Position = UDim2.new(0, 0, 1, -TOOLBAR_H)
	Toolbar.BackgroundColor3 = T.BG_MID
	Toolbar.BorderSizePixel = 0
	local ToolbarLine = Instance.new("Frame")
	ToolbarLine.Parent = Toolbar
	ToolbarLine.Size = UDim2.new(1, 0, 0, 1)
	ToolbarLine.Position = UDim2.fromOffset(0, 0)
	ToolbarLine.BackgroundColor3 = T.STROKE_INNER
	ToolbarLine.BorderSizePixel = 0
	local btnDefs = {
		{ name = "Execute", label = "Execute", x = 6 },
		{ name = "Clear", label = "Clear", x = 100 },
		{ name = "OpenFile", label = "Open File", x = 194 },
		{ name = "ExecuteFile", label = "Execute File", x = 288 },
		{ name = "SaveFile", label = "Save File", x = 382 },
		{ name = "Options", label = "Options", x = 476 },
		{ name = "Attach", label = "Attach", x = 570 },
		{ name = "Hub", label = "Script Hub", x = 652 },
	}
	local buttons = {}
	for _, def in ipairs(btnDefs) do
		local btn = Instance.new("TextButton")
		btn.Parent = Toolbar
		btn.Name = def.name
		btn.Size = UDim2.fromOffset(88, 24)
		btn.Position = UDim2.fromOffset(def.x, 6)
		btn.BackgroundColor3 = T.BG_BTN
		btn.BorderSizePixel = 0
		btn.Text = def.label
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 11
		btn.TextColor3 = T.TEXT_MAIN
		btn.ZIndex = 2
		corner(btn, 3)
		stroke(btn, T.STROKE_BTN, 1)
		hoverEffect(btn, T.BG_BTN_HOV, T.BG_BTN)
		buttons[def.name] = btn
	end
	local execStroke = buttons["Execute"]:FindFirstChildOfClass("UIStroke")
	if execStroke then
		execStroke.Color = T.STROKE_ACCENT
	end
	ScreenGui.Parent = playerGui
	return {
		ScreenGui = ScreenGui,
		ToggleBtn = ToggleBtn,
		MainFrame = MainFrame,
		TitleBar = TitleBar,
		CloseBtn = CloseBtn,
		MinBtn = MinBtn,
		CodeBox = CodeBox,
		HighlightLabel = HighlightLabel,
		EditorScroll = EditorFrame,
		LineNumbers = LineNumbers,
		Gutter = Gutter,
		Tab1 = Tab1,
		Tab2 = Tab2,
		Tab1Label = Tab1Label,
		Tab2Label = Tab2Label,
		TabClose = Tab1Close,
		NewTab = NewTabBtn,
		AnalyzerPanel = AnalyzerPanel,
		ResultsList = ResultsList,
		EmptyLabel = EmptyLabel,
		StatusLabel = StatusLabel,
		ScanBtn = ScanBtn,
		ExportBtn = ExportBtn,
		ClearABtn = ClearABtn,
		Execute = buttons["Execute"],
		Clear = buttons["Clear"],
		OpenFile = buttons["OpenFile"],
		ExecuteFile = buttons["ExecuteFile"],
		SaveFile = buttons["SaveFile"],
		Options = buttons["Options"],
		Attach = buttons["Attach"],
		Hub = buttons["Hub"],
	}
end
local function buildResultRows(ui, results)
	for _, child in ipairs(ui.ResultsList:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "EmptyLabel" then
			child:Destroy()
		end
	end
	if #results == 0 then
		ui.EmptyLabel.Visible = true
		ui.EmptyLabel.Text = "Scan complete. No network-active module functions found."
		return
	end
	ui.EmptyLabel.Visible = false
	for i, entry in ipairs(results) do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. i
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundColor3 = i % 2 == 0 and T.BG_MID or T.BG_DEEP
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = ui.ResultsList
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = row
		local modLabel = makeLabel(row, {
			Text = entry.Module,
			Size = UDim2.new(1, -8, 0, 14),
			Position = UDim2.fromOffset(0, 0),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = T.TEXT_DIM,
		})
		modLabel.ZIndex = 2
		local funcText = string.format(
			'<font color="%s">%s</font>  <font color="%s">line %d</font>',
			colorToHex(T.TEXT_MAIN),
			entry.FuncName,
			colorToHex(T.TEXT_DIM),
			entry.Line
		)
		local funcLabel = makeLabel(row, {
			Text = funcText,
			Size = UDim2.new(1, -8, 0, 16),
			Position = UDim2.fromOffset(0, 14),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = T.TEXT_MAIN,
			RichText = true,
		})
		funcLabel.ZIndex = 2
		local methodParts = {}
		for m in pairs(entry.Methods) do
			table.insert(methodParts, string.format('<font color="%s">%s</font>', colorToHex(T.TEXT_WARN), m))
		end
		local methodStr = #methodParts > 0 and "  " .. table.concat(methodParts, "  ") or ""
		local extraY = 30
		if #entry.Remotes > 0 then
			for ri, r in ipairs(entry.Remotes) do
				local rLabel = makeLabel(row, {
					Text = string.format('<font color="%s">↳ remote</font>  %s', colorToHex(T.TEXT_OK), r.Path),
					Size = UDim2.new(1, -8, 0, 14),
					Position = UDim2.fromOffset(12, extraY + (ri - 1) * 15),
					Font = Enum.Font.Code,
					TextSize = 11,
					TextColor3 = T.TEXT_MAIN,
					RichText = true,
				})
				rLabel.ZIndex = 2
			end
			extraY = extraY + #entry.Remotes * 15
		else
			local dynLabel = makeLabel(row, {
				Text = '<font color="'
					.. colorToHex(T.TEXT_DIM)
					.. '">↳ remotes stored dynamically / not cached in upvalues</font>',
				Size = UDim2.new(1, -8, 0, 14),
				Position = UDim2.fromOffset(12, extraY),
				Font = Enum.Font.Code,
				TextSize = 11,
				TextColor3 = T.TEXT_DIM,
				RichText = true,
			})
			dynLabel.ZIndex = 2
			extraY += 15
		end
		local constSnippet = #entry.Constants > 0
				and table.concat(entry.Constants, "  |  ", 1, math.min(6, #entry.Constants))
			or "[none]"
		local constLabel = makeLabel(row, {
			Text = "constants: " .. constSnippet,
			Size = UDim2.new(1, -8, 0, 14),
			Position = UDim2.fromOffset(0, extraY),
			Font = Enum.Font.Code,
			TextSize = 10,
			TextColor3 = T.TEXT_DIM,
		})
		constLabel.ZIndex = 2
		extraY += 18
		row.Size = UDim2.new(1, 0, 0, extraY + 4)
		stroke(row, T.STROKE_INNER, 1)
	end
end
local ui = createGui()
local FULL_H = 420
local MINI_H = 30
local function setTab(editorActive)
	ui.Gutter.Visible = editorActive
	ui.EditorScroll.Visible = editorActive
	ui.AnalyzerPanel.Visible = not editorActive
	ui.Tab1.BackgroundColor3 = editorActive and T.BG_TAB_ACT or T.BG_PANEL
	ui.Tab2.BackgroundColor3 = not editorActive and T.BG_TAB_ACT or T.BG_PANEL
	Tab2Label.TextColor3 = not editorActive and T.TEXT_ACCENT or T.TEXT_DIM
end
ui.Tab1.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		setTab(true)
	end
end)
ui.Tab2.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		setTab(false)
	end
end)
ui.ToggleBtn.MouseButton1Click:Connect(function()
	local f = ui.MainFrame
	if f.Visible then
		TweenService:Create(f, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, f.AbsoluteSize.X, 0, 0),
			Position = f.Position + UDim2.fromOffset(0, f.AbsoluteSize.Y / 2),
		}):Play()
		task.delay(0.18, function()
			f.Visible = false
			f.Size = UDim2.fromOffset(760, FULL_H)
			f.Position = UDim2.fromScale(0.05, 0.07)
		end)
	else
		f.Size = UDim2.new(0, 760, 0, 0)
		f.Visible = true
		TweenService:Create(f, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(760, FULL_H),
		}):Play()
	end
end)
ui.CloseBtn.MouseButton1Click:Connect(function()
	local f = ui.MainFrame
	TweenService:Create(f, TweenInfo.new(0.15), {
		Size = UDim2.new(0, f.AbsoluteSize.X, 0, 0),
	}):Play()
	task.delay(0.15, function()
		f.Visible = false
		f.Size = UDim2.fromOffset(760, FULL_H)
	end)
end)
local minimized = false
ui.MinBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	TweenService:Create(ui.MainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		Size = minimized and UDim2.fromOffset(760, MINI_H) or UDim2.fromOffset(760, FULL_H),
	}):Play()
end)
do
	local dragging = false
	local dragStart, startPos = Vector2.zero, UDim2.new()
	local DRAG_TWEEN = TweenInfo.new(0.04)
	ui.TitleBar.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = ui.MainFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local d = input.Position - dragStart
		TweenService
			:Create(ui.MainFrame, DRAG_TWEEN, {
				Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + d.X,
					startPos.Y.Scale,
					startPos.Y.Offset + d.Y
				),
			})
			:Play()
	end)
end
ui.CodeBox:GetPropertyChangedSignal("Text"):Connect(function()
	local src = ui.CodeBox.Text
	updateLineNumbers(src, ui.LineNumbers)
	applySyntaxHighlight(src, ui.HighlightLabel)
end)
ui.Execute.MouseButton1Click:Connect(function()
	flash(ui.Execute)
	local code = ui.CodeBox.Text
	if code ~= "" then
		local fn, err = loadstring(code)
		if fn then
			local ok, runErr = pcall(fn)
			if not ok then
				warn("[SynapseUI] Runtime error: " .. tostring(runErr))
			end
		else
			warn("[SynapseUI] Compile error: " .. tostring(err))
		end
	end
end)
ui.Clear.MouseButton1Click:Connect(function()
	flash(ui.Clear)
	ui.CodeBox.Text = ""
end)
ui.OpenFile.MouseButton1Click:Connect(function()
	flash(ui.OpenFile)
	if readfile and isfile then
		local name = "autoexec.lua"
		if isfile(name) then
			ui.CodeBox.Text = readfile(name)
		else
			warn("[SynapseUI] File not found: " .. name)
		end
	else
		warn("[SynapseUI] readfile not available")
	end
end)
ui.ExecuteFile.MouseButton1Click:Connect(function()
	flash(ui.ExecuteFile)
	if readfile and isfile then
		local name = "autoexec.lua"
		if isfile(name) then
			local fn, err = loadstring(readfile(name))
			if fn then
				local ok, e = pcall(fn)
				if not ok then
					warn("[SynapseUI] Runtime error: " .. tostring(e))
				end
			else
				warn("[SynapseUI] Compile error: " .. tostring(err))
			end
		end
	else
		warn("[SynapseUI] readfile not available")
	end
end)
ui.SaveFile.MouseButton1Click:Connect(function()
	flash(ui.SaveFile)
	if writefile then
		writefile("saved_script.lua", ui.CodeBox.Text)
		print("[SynapseUI] Saved to saved_script.lua")
	else
		warn("[SynapseUI] writefile not available")
	end
end)
ui.Options.MouseButton1Click:Connect(function()
	flash(ui.Options)
	ModuleAnalyzer.Settings.Verbose = not ModuleAnalyzer.Settings.Verbose
	ui.StatusLabel.Text = "Verbose: " .. tostring(ModuleAnalyzer.Settings.Verbose)
	print("[SynapseUI] Verbose = " .. tostring(ModuleAnalyzer.Settings.Verbose))
end)
ui.Attach.MouseButton1Click:Connect(function()
	flash(ui.Attach)
	local s = ui.Attach:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = T.ATTACH_ON
	end
	print("[SynapseUI] Attach")
end)
ui.Hub.MouseButton1Click:Connect(function()
	flash(ui.Hub)
	print("[SynapseUI] Script Hub")
end)
ui.TabClose.MouseButton1Click:Connect(function()
	ui.CodeBox.Text = ""
	print("[SynapseUI] Tab closed")
end)
ui.NewTab.MouseButton1Click:Connect(function()
	ui.CodeBox.Text = ""
	print("[SynapseUI] New tab")
end)
ui.ScanBtn.MouseButton1Click:Connect(function()
	flash(ui.ScanBtn)
	ui.StatusLabel.Text = "Scanning…"
	ui.StatusLabel.TextColor3 = T.TEXT_WARN
	ui.ScanBtn.Active = false
	local started = ModuleAnalyzer:Analyze(function(processed, total)
		ui.StatusLabel.Text = string.format("Scanning… %d / %d", processed, total)
	end, function(count)
		ui.StatusLabel.Text = string.format("Done — %d functions found.", count)
		ui.StatusLabel.TextColor3 = count > 0 and T.TEXT_OK or T.TEXT_DIM
		ui.ScanBtn.Active = true
		local flat = ModuleAnalyzer:GetFlatResults()
		buildResultRows(ui, flat)
	end)
	if not started then
		ui.StatusLabel.Text = "Cooldown active or scan already running."
		ui.StatusLabel.TextColor3 = T.TEXT_ERR
		ui.ScanBtn.Active = true
	end
end)
ui.ExportBtn.MouseButton1Click:Connect(function()
	flash(ui.ExportBtn)
	local json = ModuleAnalyzer:Export()
	if json and writefile then
		writefile("module_analyzer_export.json", json)
		ui.StatusLabel.Text = "Exported → module_analyzer_export.json"
		ui.StatusLabel.TextColor3 = T.TEXT_OK
	elseif json then
		ui.CodeBox.Text = json
		setTab(true)
		ui.StatusLabel.Text = "writefile unavailable — results pasted into editor."
		ui.StatusLabel.TextColor3 = T.TEXT_WARN
	else
		ui.StatusLabel.Text = "No results to export."
		ui.StatusLabel.TextColor3 = T.TEXT_ERR
	end
end)
ui.ClearABtn.MouseButton1Click:Connect(function()
	flash(ui.ClearABtn)
	ModuleAnalyzer:Clear()
	buildResultRows(ui, {})
	ui.StatusLabel.Text = "Results cleared."
	ui.StatusLabel.TextColor3 = T.TEXT_DIM
end)
getgenv().ModuleAnalyzer = ModuleAnalyzer
getgenv().SynapseUI = ui
