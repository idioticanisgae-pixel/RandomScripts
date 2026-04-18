if not getgenv then
    local _fakeGenv = getfenv(0)
    getfenv().getgenv = function()
        return _fakeGenv
    end
end
local genv = getgenv()
local RunService  = game:GetService("RunService")
local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local TweenSvc    = game:GetService("TweenService")
local CoreGui     = game:GetService("CoreGui")
local Stats       = game:GetService("Stats")
local VIM         = game:GetService("VirtualInputManager")
local TeleportSvc = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
genv.clonefunction = function(func)
    assert(type(func) == "function", "clonefunction expects a function")
    return function(...)
        return func(...)
    end
end
genv.iscclosure = function(func)
    if type(func) ~= "function" then return false end
    local ok, info = pcall(debug.info, func, "s")
    if not ok then return false end
    return info == "[C]"
end
genv.islclosure = function(func)
    if type(func) ~= "function" then return false end
    return not genv.iscclosure(func)
end
if not genv.newcclosure then
    genv.newcclosure = function(f)
        assert(type(f) == "function", "newcclosure expects a function")
        return function(...)
            return f(...)
        end
    end
end
genv.cloneref = function(obj)
    if typeof(obj) ~= "Instance" then return obj end
    local ok, clone = pcall(function() return obj:Clone() end)
    return (ok and clone) or obj
end
genv.gethui = function()
    return CoreGui
end
genv.getscripts = function()
    local scripts = {}
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("ModuleScript") or v:IsA("LocalScript") or v:IsA("Script") then
            table.insert(scripts, v)
        end
    end
    return scripts
end
genv.getnilinstances = function()
    local nilInstances = {}
    if not getreg then return nilInstances end
    for _, v in pairs(getreg()) do
        if typeof(v) == "Instance" and v.Parent == nil then
            table.insert(nilInstances, v)
        end
    end
    return nilInstances
end
genv.getcallingscript = function()
    local src = debug.info(2, "s")
    for _, v in pairs(game:GetDescendants()) do
        if v:GetFullName() == src then return v end
    end
    return nil
end
genv.isreadonly = function(instance, property)
    return not pcall(function()
        instance[property] = instance[property]
    end)
end
if not genv.hookfunction then
    genv.hookfunction = function(func, replacement)
        assert(type(func) == "function", "hookfunction: arg #1 must be a function")
        assert(type(replacement) == "function", "hookfunction: arg #2 must be a function")
        local env = getfenv()
        local oldRef = nil
        for k, v in pairs(env) do
            if v == func then
                oldRef = v
                local ok = pcall(rawset, env, k, replacement)
                if not ok then
                    pcall(function() env[k] = replacement end)
                end
            end
        end
        return oldRef
    end
end
if not genv.hookmetamethod then
    local _setro
    if type(setreadonly) == "function" then
        _setro = setreadonly
    elseif type(make_writeable) == "function" and type(make_readonly) == "function" then
        _setro = function(t, writable)
            if writable == false then make_writeable(t)
            else make_readonly(t) end
        end
    end
    genv.hookmetamethod = function(obj, method, func)
        local mt = getrawmetatable(obj)
        assert(mt, "hookmetamethod: object has no metatable")
        if _setro then pcall(_setro, mt, false) end
        local old = rawget(mt, method)
        rawset(mt, method, func)
        if _setro then pcall(_setro, mt, true) end
        return old
    end
end
local _namecallMethod = ""
if not genv.getnamecallmethod then
    genv.getnamecallmethod = function() return _namecallMethod end
end
if not genv.setnamecallmethod then
    genv.setnamecallmethod = function(m) _namecallMethod = m end
end
genv.protect_gui = function(guiElement)
    if typeof(guiElement) ~= "Instance" then return end
    local old_index = rawget(getrawmetatable(game), "__index")
    genv.hookmetamethod(game, "__index", genv.newcclosure(function(t, k)
        if t == guiElement and k == "Parent" then
            return nil
        end
        return old_index(t, k)
    end))
    guiElement.Parent = genv.gethui()
end
if getgc then
    local _realGetGC = getgc
    genv.getgc = function(includeTables)
        local realGC = _realGetGC(includeTables)
        local filtered = {}
        for _, v in pairs(realGC) do
            local skip = false
            if type(v) == "function" then
                local ok, src = pcall(debug.info, v, "s")
                if ok and (src:match("FUnctions") or src == "=[C]") then
                    skip = true
                end
            end
            if not skip then
                table.insert(filtered, v)
            end
        end
        return filtered
    end
end
local _cryptShadow = {}
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
_cryptShadow.base64encode = function(data)
    assert(type(data) == "string", "base64encode: expected string")
    local result = {}
    local padding = (3 - #data % 3) % 3
    data = data .. string.rep("\0", padding)
    for i = 1, #data, 3 do
        local b1, b2, b3 = data:byte(i, i + 2)
        local n = b1 * 65536 + b2 * 256 + b3
        table.insert(result, B64_CHARS:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1))
        table.insert(result, B64_CHARS:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1))
        table.insert(result, B64_CHARS:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1))
        table.insert(result, B64_CHARS:sub(n % 64 + 1, n % 64 + 1))
    end
    local encoded = table.concat(result)
    if padding > 0 then
        encoded = encoded:sub(1, #encoded - padding) .. string.rep("=", padding)
    end
    return encoded
end
_cryptShadow.base64decode = function(data)
    assert(type(data) == "string", "base64decode: expected string")
    data = data:gsub("[^" .. B64_CHARS .. "=]", "")
    local lookup = {}
    for i = 1, #B64_CHARS do
        lookup[B64_CHARS:sub(i, i)] = i - 1
    end
    local result = {}
    for i = 1, #data, 4 do
        local c1 = lookup[data:sub(i, i)] or 0
        local c2 = lookup[data:sub(i+1, i+1)] or 0
        local c3 = lookup[data:sub(i+2, i+2)] or 0
        local c4 = lookup[data:sub(i+3, i+3)] or 0
        local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
        table.insert(result, string.char(math.floor(n / 65536) % 256))
        if data:sub(i+2, i+2) ~= "=" then
            table.insert(result, string.char(math.floor(n / 256) % 256))
        end
        if data:sub(i+3, i+3) ~= "=" then
            table.insert(result, string.char(n % 256))
        end
    end
    return table.concat(result)
end
_cryptShadow.generatekey = function(optionalSize)
    local size = optionalSize or 32
    assert(type(size) == "number", "generatekey: arg #1 must be a number")
    local raw = {}
    for _ = 1, size do
        table.insert(raw, string.char(math.random(0, 255)))
    end
    return _cryptShadow.base64encode(table.concat(raw))
end
_cryptShadow.generatebytes = function(size)
    assert(type(size) == "number", "generatebytes: arg #1 (number) expected")
    return _cryptShadow.generatekey(size)
end
do
    local native = genv.crypt
    if not native then
        genv.crypt = _cryptShadow
    else
        local proxy = setmetatable({}, { __index = native })
        for k, v in pairs(_cryptShadow) do
            if rawget(native, k) == nil then
                rawset(proxy, k, v)
            end
        end
        genv.crypt = proxy
    end
end
local crypt = genv.crypt
if not genv.debugg then genv.debugg = {} end
local debugShim = genv.debugg
debugShim.getinfo = function(funcOrLevel)
    local ok, currentLine = pcall(debug.info, funcOrLevel, "l")
    local _, source       = pcall(debug.info, funcOrLevel, "s")
    local _, name         = pcall(debug.info, funcOrLevel, "n")
    local _, numparams    = pcall(debug.info, funcOrLevel, "a")
    local _, isvararg     = pcall(debug.info, funcOrLevel, "a")
    name = (type(name) == "string" and #name > 0) and name or nil
    source = type(source) == "string" and source or ""
    return {
        currentline = ok and tonumber(currentLine) or -1,
        source      = source,
        name        = name and tostring(name) or nil,
        numparams   = tonumber(numparams) or 0,
        is_vararg   = isvararg and 1 or 0,
        short_src   = source:sub(1, 60),
    }
end
local _isWindowFocused = true
UIS.WindowFocused:Connect(function()
    _isWindowFocused = true
end)
UIS.WindowFocusReleased:Connect(function()
    _isWindowFocused = false
end)
genv.isrbxactive  = function() return _isWindowFocused end
genv.isgameactive = genv.isrbxactive
genv.identifyexecutor = function()
    if type(identifyexecutor) == "function" then
        return identifyexecutor()
    end
    if type(getexecutorname) == "function" then
        return getexecutorname()
    end
    return "Unknown Executor", "0.0.0"
end
if not genv.VirtualDisk then genv.VirtualDisk = {} end
local VFS = genv.VirtualDisk
genv.writefile = function(path, content)
    assert(type(path) == "string", "writefile: path must be a string")
    VFS[path] = tostring(content)
end
genv.readfile = function(path)
    assert(type(path) == "string", "readfile: path must be a string")
    if VFS[path] == nil then
        error("readfile: no such file '" .. path .. "'", 2)
    end
    return VFS[path]
end
genv.appendfile = function(path, content)
    assert(type(path) == "string", "appendfile: path must be a string")
    VFS[path] = (VFS[path] or "") .. tostring(content)
end
genv.isfile = function(path)
    return VFS[path] ~= nil
end
genv.delfile = function(path)
    VFS[path] = nil
end
genv.listfiles = function(dir)
    local files = {}
    for path in pairs(VFS) do
        if not dir or path:sub(1, #dir) == dir then
            table.insert(files, path)
        end
    end
    return files
end
genv.makefolder = function(path)
    VFS["__folder__" .. path] = true
end
genv.isfolder = function(path)
    return VFS["__folder__" .. path] == true
end
if not genv.Drawing then
    local hui = genv.gethui()
    local DrawingContainer = Instance.new("ScreenGui")
    DrawingContainer.Name = "__DrawingLib__"
    DrawingContainer.ZIndexBehavior = Enum.ZIndexBehavior.Global
    DrawingContainer.ResetOnSpawn = false
    DrawingContainer.Parent = hui
    local function convertAlpha(a)
        return 1 - math.clamp(a, 0, 1)
    end
    local function dragify(frame)
        local dragToggle, dragInput, dragStart, startPos = nil, nil, nil, nil
        frame.InputBegan:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch)
                and UIS:GetFocusedTextBox() == nil
            then
                dragToggle = true
                dragStart  = input.Position
                startPos   = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragToggle = false
                    end
                end)
            end
        end)
        frame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragInput = input
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if input == dragInput and dragToggle then
                local delta = input.Position - dragStart
                TweenSvc:Create(frame, TweenInfo.new(0.1), {
                    Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                }):Play()
            end
        end)
    end
    local DrawingLib = {}
    DrawingLib.__index = DrawingLib
    DrawingLib.new = function(objType)
        local obj = {}
        if objType == "Line" then
            local frame = Instance.new("Frame")
            frame.Name = "Drawing_Line"
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.BorderSizePixel = 0
            frame.Parent = DrawingContainer
            local props = {
                Visible     = false,
                Color       = Color3.new(1, 1, 1),
                Transparency= 1,
                Thickness   = 1,
                From        = Vector2.zero,
                To          = Vector2.zero,
                ZIndex      = 1,
            }
            local conn
            conn = RunService.RenderStepped:Connect(function()
                if not frame.Parent then conn:Disconnect() return end
                frame.Visible             = props.Visible
                frame.BackgroundColor3    = props.Color
                frame.BackgroundTransparency = convertAlpha(props.Transparency)
                frame.ZIndex              = props.ZIndex
                local mag    = (props.To - props.From).Magnitude
                local center = (props.To + props.From) / 2
                local angle  = math.atan2(props.To.Y - props.From.Y, props.To.X - props.From.X)
                frame.Size     = UDim2.new(0, mag, 0, props.Thickness)
                frame.Position = UDim2.new(0, center.X, 0, center.Y)
                frame.Rotation = math.deg(angle)
            end)
            return setmetatable({}, {
                __index    = function(_, k) return props[k] end,
                __newindex = function(_, k, v)
                    if props[k] ~= nil then props[k] = v end
                end,
                __tostring = function() return "Drawing(Line)" end,
            })
        elseif objType == "Text" then
            local label = Instance.new("TextLabel")
            label.Name = "Drawing_Text"
            label.BackgroundTransparency = 1
            label.BorderSizePixel = 0
            label.RichText = false
            label.Parent = DrawingContainer
            local props = {
                Visible     = false,
                Text        = "",
                Color       = Color3.new(1, 1, 1),
                Transparency= 1,
                Size        = 14,
                Position    = Vector2.zero,
                Outline     = false,
                OutlineColor= Color3.new(0, 0, 0),
                Center      = false,
                ZIndex      = 1,
                Font        = Drawing.Fonts and Drawing.Fonts.UI or Enum.Font.SourceSans,
            }
            local conn
            conn = RunService.RenderStepped:Connect(function()
                if not label.Parent then conn:Disconnect() return end
                label.Visible          = props.Visible
                label.Text             = tostring(props.Text)
                label.TextColor3       = props.Color
                label.TextTransparency = convertAlpha(props.Transparency)
                label.TextSize         = props.Size
                label.ZIndex           = props.ZIndex
                label.Font             = props.Font
                label.TextXAlignment   = props.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
                local ts = label.TextBounds
                label.Size     = UDim2.new(0, ts.X + 2, 0, ts.Y + 2)
                label.Position = UDim2.new(0, props.Position.X - (props.Center and ts.X/2 or 0), 0, props.Position.Y)
            end)
            return setmetatable({}, {
                __index    = function(_, k) return props[k] end,
                __newindex = function(_, k, v)
                    if props[k] ~= nil then props[k] = v end
                end,
                __tostring = function() return "Drawing(Text)" end,
            })
        elseif objType == "Circle" then
            local frame = Instance.new("Frame")
            frame.Name = "Drawing_Circle"
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Parent = DrawingContainer
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = frame
            local stroke = Instance.new("UIStroke")
            stroke.Parent = frame
            local props = {
                Visible     = false,
                Color       = Color3.new(1, 1, 1),
                Transparency= 1,
                Thickness   = 1,
                Radius      = 10,
                Filled      = false,
                Position    = Vector2.zero,
                ZIndex      = 1,
            }
            local conn
            conn = RunService.RenderStepped:Connect(function()
                if not frame.Parent then conn:Disconnect() return end
                frame.Visible  = props.Visible
                frame.ZIndex   = props.ZIndex
                frame.Position = UDim2.new(0, props.Position.X, 0, props.Position.Y)
                frame.Size     = UDim2.new(0, props.Radius * 2, 0, props.Radius * 2)
                if props.Filled then
                    frame.BackgroundColor3       = props.Color
                    frame.BackgroundTransparency = convertAlpha(props.Transparency)
                    stroke.Enabled = false
                else
                    frame.BackgroundTransparency = 1
                    stroke.Enabled    = true
                    stroke.Color      = props.Color
                    stroke.Thickness  = props.Thickness
                    stroke.Transparency = convertAlpha(props.Transparency)
                end
            end)
            return setmetatable({}, {
                __index    = function(_, k) return props[k] end,
                __newindex = function(_, k, v)
                    if props[k] ~= nil then props[k] = v end
                end,
                __tostring = function() return "Drawing(Circle)" end,
            })
        elseif objType == "Square" then
            local frame = Instance.new("Frame")
            frame.Name = "Drawing_Square"
            frame.BorderSizePixel = 0
            frame.BackgroundTransparency = 1
            frame.Parent = DrawingContainer
            local stroke = Instance.new("UIStroke")
            stroke.Parent = frame
            local props = {
                Visible     = false,
                Color       = Color3.new(1, 1, 1),
                Transparency= 1,
                Thickness   = 1,
                Size        = Vector2.new(100, 100),
                Position    = Vector2.zero,
                Filled      = false,
                ZIndex      = 1,
            }
            local conn
            conn = RunService.RenderStepped:Connect(function()
                if not frame.Parent then conn:Disconnect() return end
                frame.Visible  = props.Visible
                frame.ZIndex   = props.ZIndex
                frame.Position = UDim2.new(0, props.Position.X, 0, props.Position.Y)
                frame.Size     = UDim2.new(0, props.Size.X, 0, props.Size.Y)
                if props.Filled then
                    frame.BackgroundColor3       = props.Color
                    frame.BackgroundTransparency = convertAlpha(props.Transparency)
                    stroke.Enabled = false
                else
                    frame.BackgroundTransparency = 1
                    stroke.Enabled    = true
                    stroke.Color      = props.Color
                    stroke.Thickness  = props.Thickness
                    stroke.Transparency = convertAlpha(props.Transparency)
                end
            end)
            return setmetatable({}, {
                __index    = function(_, k) return props[k] end,
                __newindex = function(_, k, v)
                    if props[k] ~= nil then props[k] = v end
                end,
                __tostring = function() return "Drawing(Square)" end,
            })
        elseif objType == "Image" then
            local imageLabel = Instance.new("ImageLabel")
            imageLabel.Name = "Drawing_Image"
            imageLabel.BackgroundTransparency = 1
            imageLabel.BorderSizePixel = 0
            imageLabel.Parent = DrawingContainer
            local props = {
                Visible     = false,
                Data        = nil,
                DataURL     = "",
                Size        = Vector2.new(100, 100),
                Position    = Vector2.zero,
                Transparency= 1,
                Color       = Color3.new(1, 1, 1),
                ZIndex      = 1,
            }
            local conn
            conn = RunService.RenderStepped:Connect(function()
                if not imageLabel.Parent then conn:Disconnect() return end
                imageLabel.Visible          = props.Visible
                imageLabel.Image            = props.DataURL
                imageLabel.ImageColor3      = props.Color
                imageLabel.ImageTransparency= convertAlpha(props.Transparency)
                imageLabel.Size             = UDim2.new(0, props.Size.X, 0, props.Size.Y)
                imageLabel.Position         = UDim2.new(0, props.Position.X, 0, props.Position.Y)
                imageLabel.ZIndex           = props.ZIndex
            end)
            return setmetatable({}, {
                __index    = function(_, k) return props[k] end,
                __newindex = function(_, k, v)
                    if props[k] ~= nil then props[k] = v end
                end,
                __tostring = function() return "Drawing(Image)" end,
            })
        elseif objType == "Quad" or objType == "Triangle" then
            local numLines = (objType == "Quad") and 4 or 3
            local lines = {}
            for i = 1, numLines do
                lines[i] = DrawingLib.new("Line")
            end
            local props = {
                Visible   = false,
                Color     = Color3.new(1, 1, 1),
                Thickness = 1,
                ZIndex    = 1,
                PointA    = Vector2.zero,
                PointB    = Vector2.zero,
                PointC    = Vector2.zero,
            }
            if objType == "Quad" then
                props.PointD = Vector2.zero
            end
            local function syncLines()
                local pts = {props.PointA, props.PointB, props.PointC}
                if objType == "Quad" then table.insert(pts, props.PointD) end
                for i, line in ipairs(lines) do
                    line.From        = pts[i]
                    line.To          = pts[(i % numLines) + 1]
                    line.Color       = props.Color
                    line.Thickness   = props.Thickness
                    line.Visible     = props.Visible
                    line.ZIndex      = props.ZIndex
                end
            end
            return setmetatable({}, {
                __index    = function(_, k) return props[k] end,
                __newindex = function(_, k, v)
                    if props[k] ~= nil then
                        props[k] = v
                        syncLines()
                    end
                end,
                __tostring = function() return "Drawing(" .. objType .. ")" end,
            })
        end
        return setmetatable({}, {
            __index    = function() return nil end,
            __newindex = function() end,
            __tostring = function() return "Drawing(Unknown)" end,
        })
    end
    DrawingLib.Fonts = {
        UI      = Enum.Font.SourceSans,
        System  = Enum.Font.Code,
        Plex    = Enum.Font.GothamMedium,
        Monospace = Enum.Font.Code,
    }
    genv.Drawing = DrawingLib
end
local function buildMessageBox(title, text, buttons)
    local hui = genv.gethui()
    local sg = Instance.new("ScreenGui")
    sg.Name = "zuk_messagebox"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.ResetOnSpawn = false
    sg.Parent = hui
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0.5, -130, 0.5, -85)
    frame.Size = UDim2.new(0, 260, 0, 170)
    frame.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    local titleBar = Instance.new("Frame")
    titleBar.BackgroundColor3 = Color3.fromRGB(44, 44, 46)
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.Parent = frame
    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 6)
    tbCorner.Parent = titleBar
    local patch = Instance.new("Frame")
    patch.BackgroundColor3 = Color3.fromRGB(44, 44, 46)
    patch.BorderSizePixel = 0
    patch.Position = UDim2.new(0, 0, 0.5, 0)
    patch.Size = UDim2.new(1, 0, 0.5, 0)
    patch.Parent = titleBar
    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -36, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Text = tostring(title)
    titleLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundTransparency = 1
    closeBtn.Position = UDim2.new(1, -34, 0, 2)
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 12, 0, 44)
    body.Size = UDim2.new(1, -24, 0, 80)
    body.Text = tostring(text)
    body.TextColor3 = Color3.fromRGB(200, 200, 210)
    body.Font = Enum.Font.SourceSans
    body.TextSize = 14
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Parent = frame
    local sep = Instance.new("Frame")
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    sep.BorderSizePixel = 0
    sep.Position = UDim2.new(0, 0, 0, 130)
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.Parent = frame
    local btnCount = #buttons
    local btnW = 70
    local spacing = 10
    local totalW = btnCount * btnW + (btnCount - 1) * spacing
    local startX = (260 - totalW) / 2
    local toreturn = nil
    for i, def in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        btn.BorderSizePixel = 0
        btn.Position = UDim2.new(0, startX + (i - 1) * (btnW + spacing), 0, 136)
        btn.Size = UDim2.new(0, btnW, 0, 26)
        btn.Text = def.text
        btn.TextColor3 = Color3.fromRGB(235, 235, 245)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.Parent = frame
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            toreturn = def.returnVal
            sg:Destroy()
        end)
    end
    closeBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)
    dragify(frame)
    repeat task.wait() until toreturn ~= nil or not sg.Parent
    return toreturn or 0
end
local MSGBOX_LAYOUTS = {
    [0] = { { text = "OK", returnVal = 1 } },
    [1] = { { text = "OK", returnVal = 1 }, { text = "Cancel", returnVal = 2 } },
    [2] = { { text = "Abort", returnVal = 1 }, { text = "Retry", returnVal = 2 }, { text = "Ignore", returnVal = 3 } },
    [3] = { { text = "Yes", returnVal = 1 }, { text = "No", returnVal = 2 }, { text = "Cancel", returnVal = 3 } },
    [4] = { { text = "Yes", returnVal = 1 }, { text = "No", returnVal = 2 } },
    [5] = { { text = "Retry", returnVal = 1 }, { text = "Cancel", returnVal = 2 } },
    [6] = { { text = "Cancel", returnVal = 1 }, { text = "Try Again", returnVal = 2 }, { text = "Continue", returnVal = 3 } },
}
genv.messagebox = function(text, caption, style, callback)
    local layout = MSGBOX_LAYOUTS[style] or MSGBOX_LAYOUTS[0]
    local result = buildMessageBox(caption or "Message", text or "", layout)
    if type(callback) == "function" then
        callback(result)
    end
    return result
end
local rconsoleGui = nil
local rconsoleLines = {}
local rconsoleTextBox = nil
local function ensureRconsole()
    if rconsoleGui and rconsoleGui.Parent then return end
    rconsoleLines = {}
    local hui = genv.gethui()
    rconsoleGui = Instance.new("ScreenGui")
    rconsoleGui.Name = "__rconsole__"
    rconsoleGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    rconsoleGui.ResetOnSpawn = false
    rconsoleGui.Parent = hui
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0.2, 0, 0.2, 0)
    frame.Size = UDim2.new(0, 700, 0, 300)
    frame.Parent = rconsoleGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(1, 0, 0, 32)
    bar.Parent = frame
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 6)
    barCorner.Parent = bar
    local barPatch = Instance.new("Frame")
    barPatch.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    barPatch.BorderSizePixel = 0
    barPatch.Position = UDim2.new(0, 0, 0.5, 0)
    barPatch.Size = UDim2.new(1, 0, 0.5, 0)
    barPatch.Parent = bar
    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 10, 0, 0)
    titleLbl.Size = UDim2.new(1, -50, 1, 0)
    titleLbl.Text = "Console"
    titleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    titleLbl.Font = Enum.Font.Code
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = bar
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundTransparency = 1
    closeBtn.Position = UDim2.new(1, -30, 0, 0)
    closeBtn.Size = UDim2.new(0, 30, 1, 0)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(200, 80, 80)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.MouseButton1Click:Connect(function()
        rconsoleGui:Destroy()
        rconsoleGui = nil
    end)
    closeBtn.Parent = bar
    local minBtn = Instance.new("TextButton")
    minBtn.BackgroundTransparency = 1
    minBtn.Position = UDim2.new(1, -60, 0, 0)
    minBtn.Size = UDim2.new(0, 30, 1, 0)
    minBtn.Text = "–"
    minBtn.TextColor3 = Color3.fromRGB(200, 200, 100)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)
    minBtn.Parent = bar
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.Position = UDim2.new(0, 0, 0, 32)
    scrollFrame.Size = UDim2.new(1, 0, 1, -32)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.Parent = frame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 0)
    layout.Parent = scrollFrame
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
        scrollFrame.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y)
    end)
    rconsoleTextBox = scrollFrame
    dragify(frame)
end
local function rconsoleAppendLine(text, color)
    ensureRconsole()
    if not rconsoleTextBox or not rconsoleTextBox.Parent then return end
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -10, 0, 18)
    lbl.Text = tostring(text)
    lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = rconsoleTextBox
    table.insert(rconsoleLines, lbl)
end
genv.rconsolecreate = function(title)
    ensureRconsole()
    if rconsoleTextBox and rconsoleTextBox.Parent then
        local barTitle = rconsoleTextBox.Parent.Parent:FindFirstChild("Console", true)
        if barTitle then barTitle.Text = title or "Console" end
    end
end
genv.rconsoleprint = function(text, color)
    rconsoleAppendLine(text, color)
end
genv.rconsolename = function(name)
    ensureRconsole()
end
genv.rconsoleclear = function()
    if rconsoleTextBox then
        for _, lbl in pairs(rconsoleLines) do
            lbl:Destroy()
        end
        rconsoleLines = {}
    end
end
genv.rconsoledestroy = function()
    if rconsoleGui then
        rconsoleGui:Destroy()
        rconsoleGui = nil
        rconsoleLines = {}
    end
end
genv.rconsoleinput = function()
    return ""
end
genv.notify = function(title, text, duration)
    local hui = genv.gethui()
    local sg = Instance.new("ScreenGui")
    sg.Name = "__notify__"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
    sg.Parent = hui
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(1, -270, 1, -100)
    frame.Size = UDim2.new(0, 255, 0, 75)
    frame.Parent = sg
    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = frame
    local accent = Instance.new("Frame")
    accent.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
    accent.BorderSizePixel = 0
    accent.Size = UDim2.new(0, 3, 1, 0)
    accent.Parent = frame
    local aCorner = Instance.new("UICorner")
    aCorner.CornerRadius = UDim.new(0, 3)
    aCorner.Parent = accent
    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 12, 0, 6)
    titleLbl.Size = UDim2.new(1, -16, 0, 24)
    titleLbl.Text = tostring(title)
    titleLbl.TextColor3 = Color3.fromRGB(235, 235, 245)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = frame
    local bodyLbl = Instance.new("TextLabel")
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Position = UDim2.new(0, 12, 0, 30)
    bodyLbl.Size = UDim2.new(1, -16, 0, 36)
    bodyLbl.Text = tostring(text)
    bodyLbl.TextColor3 = Color3.fromRGB(175, 175, 185)
    bodyLbl.Font = Enum.Font.SourceSans
    bodyLbl.TextSize = 13
    bodyLbl.TextWrapped = true
    bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
    bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
    bodyLbl.Parent = frame
    frame.Position = UDim2.new(1, 10, 1, -100)
    TweenSvc:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -270, 1, -100)
    }):Play()
    task.delay(duration or 4, function()
        if sg.Parent then
            TweenSvc:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 10, 1, -100)
            }):Play()
            task.wait(0.35)
            sg:Destroy()
        end
    end)
end
genv.mouse1click = function(x, y)
    VIM:SendMouseButtonEvent(x or 0, y or 0, 0, true, game, false)
    task.wait()
    VIM:SendMouseButtonEvent(x or 0, y or 0, 0, false, game, false)
end
genv.mouse2click = function(x, y)
    VIM:SendMouseButtonEvent(x or 0, y or 0, 1, true, game, false)
    task.wait()
    VIM:SendMouseButtonEvent(x or 0, y or 0, 1, false, game, false)
end
genv.mouse1press = function(x, y)
    VIM:SendMouseButtonEvent(x or 0, y or 0, 0, true, game, false)
end
genv.mouse1release = function(x, y)
    VIM:SendMouseButtonEvent(x or 0, y or 0, 0, false, game, false)
end
genv.mouse2press = function(x, y)
    VIM:SendMouseButtonEvent(x or 0, y or 0, 1, true, game, false)
end
genv.mouse2release = function(x, y)
    VIM:SendMouseButtonEvent(x or 0, y or 0, 1, false, game, false)
end
genv.mousescroll = function(x, y, up)
    VIM:SendMouseWheelEvent(x or 0, y or 0, up and true or false, game)
end
genv.keypress = function(keyCode)
    VIM:SendKeyEvent(true, keyCode, false, game)
end
genv.keyrelease = function(keyCode)
    VIM:SendKeyEvent(false, keyCode, false, game)
end
genv.getplayer = function(nameOrObj)
    if nameOrObj == nil then return LocalPlayer end
    if typeof(nameOrObj) == "Instance" then return nameOrObj end
    assert(type(nameOrObj) == "string", "getplayer: expected string or nil")
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Name == nameOrObj or plr.DisplayName == nameOrObj then
            return plr
        end
    end
    return nil
end
genv.getlocalplayer = function()
    return LocalPlayer
end
genv.getplayers = function()
    local t = {}
    for _, plr in pairs(Players:GetPlayers()) do
        t[plr.Name] = plr
    end
    t["LocalPlayer"] = LocalPlayer
    return t
end
local function loadAndPlayAnimation(animationId, player)
    local plr = player or LocalPlayer
    local char = plr.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(animationId)
    local track = humanoid:LoadAnimation(anim)
    track:Play()
    return track
end
genv.playanimation = loadAndPlayAnimation
genv.runanimation  = loadAndPlayAnimation
genv.getfps = function(suffix)
    local ok, raw = pcall(function()
        return Stats.Workspace.Heartbeat:GetValue()
    end)
    if not ok then return suffix and "0 fps" or "0" end
    local fps = tostring(math.round(tonumber(raw) or 0))
    return suffix and (fps .. " fps") or fps
end
genv.getping = function(suffix)
    local ok, raw = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    end)
    if not ok then return suffix and "0 ms" or "0" end
    local pingNum = tonumber(raw:match("^%d+")) or 0
    local ping = tostring(math.round(pingNum))
    return suffix and (ping .. " ms") or ping
end
local function getPlatformString()
    local platform = UIS:GetPlatform()
    local map = {
        [Enum.Platform.Windows] = "Windows",
        [Enum.Platform.OSX]     = "macOS",
        [Enum.Platform.IOS]     = "iOS",
        [Enum.Platform.Android] = "Android",
        [Enum.Platform.UWP]     = "Windows (Microsoft Store)",
        [Enum.Platform.XBoxOne] = "Xbox One",
    }
    return map[platform] or "Unknown"
end
genv.getplatform = getPlatformString
genv.getos       = getPlatformString
genv.getdevice   = getPlatformString
genv.getaffiliateid = function() return "none" end
genv.getfpscap = function()
    if type(getfpscap) == "function" then return getfpscap() end
    return 60
end
genv.setfpscap = function(cap)
    if type(setfpscap) == "function" then
        setfpscap(cap)
    end
end
genv.join = function(placeID, jobID)
    assert(type(placeID) == "number", "join: placeID must be a number")
    if jobID then
        TeleportSvc:TeleportToPlaceInstance(placeID, jobID, LocalPlayer)
    else
        TeleportSvc:Teleport(placeID, LocalPlayer)
    end
end
if firetouchinterest then
    genv.firetouchtransmitter = firetouchinterest
elseif genv.firetouchtransmitter == nil then
    genv.firetouchtransmitter = function() end
end
genv.customprint = function(text, properties, imageId)
    print(text)
    task.wait(0.03)
    local ok, devConsole = pcall(function()
        return CoreGui.DevConsoleMaster.DevConsoleWindow.DevConsoleUI.MainView.ClientLog
    end)
    if not ok or not devConsole then return end
    local children = devConsole:GetChildren()
    local lastMsg = devConsole:FindFirstChild(tostring(#children - 1))
    if lastMsg then
        local msg = lastMsg:FindFirstChild("msg")
        if msg and properties then
            for k, v in pairs(properties) do
                pcall(function() msg[k] = v end)
            end
        end
        if msg and imageId then
            local img = lastMsg:FindFirstChild("image")
            if img then img.Image = imageId end
        end
    end
end
genv.notify("zukv2", "Compatibility layer active.", 3)
