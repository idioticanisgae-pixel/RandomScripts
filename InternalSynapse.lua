local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local _existing = playerGui:FindFirstChild("Synapse X")
if _existing then _existing:Destroy() end
local T = {
    BG_DEEP      = Color3.fromRGB(22,  22,  26),
    BG_MID       = Color3.fromRGB(30,  30,  35),
    BG_PANEL     = Color3.fromRGB(26,  26,  31),
    BG_EDITOR    = Color3.fromRGB(18,  18,  22),
    BG_BTN       = Color3.fromRGB(38,  38,  45),
    BG_BTN_HOV   = Color3.fromRGB(52,  52,  62),
    STROKE_OUTER = Color3.fromRGB(60,  60,  75),
    STROKE_INNER = Color3.fromRGB(45,  45,  58),
    STROKE_BTN   = Color3.fromRGB(55,  55,  68),
    STROKE_ACCENT= Color3.fromRGB(80,  80, 180),
    TEXT_MAIN    = Color3.fromRGB(220, 220, 230),
    TEXT_DIM     = Color3.fromRGB(130, 130, 150),
    TEXT_TAB     = Color3.fromRGB(200, 200, 215),
    ICON_TINT    = Color3.fromRGB(180, 180, 200),
    CLOSE_HOV    = Color3.fromRGB(180,  50,  50),
}
local TOOLBAR_H  = 34
local TITLEBAR_H = 28
local TABBAR_H   = 22
local FRAME_W    = 706
local FRAME_H    = 289
local GUTTER_W   = 38
local EDITOR_TOP = TITLEBAR_H + TABBAR_H
local EDITOR_H   = FRAME_H - EDITOR_TOP - TOOLBAR_H
local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color           = color or T.STROKE_INNER
    s.Thickness       = thickness or 1
    s.LineJoinMode    = Enum.LineJoinMode.Miter
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = parent
    return s
end
local function flash(btn)
    local orig = btn.BackgroundColor3
    TweenService:Create(btn, TweenInfo.new(0.06), { BackgroundColor3 = T.BG_BTN_HOV }):Play()
    task.delay(0.12, function()
        if btn and btn.Parent then
            TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = orig }):Play()
        end
    end)
end
local function hoverEffect(btn, hoverCol, normalCol)
    normalCol = normalCol or btn.BackgroundColor3
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = hoverCol }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = normalCol }):Play()
    end)
end
local Syntax = {
    Text          = Color3.fromRGB(204,204,204),
    Operator      = Color3.fromRGB(204,204,204),
    Number        = Color3.fromRGB(255,198,  0),
    String        = Color3.fromRGB(173,241,149),
    Comment       = Color3.fromRGB(102,102,102),
    Keyword       = Color3.fromRGB(248,109,124),
    BuiltIn       = Color3.fromRGB(132,214,247),
    LocalMethod   = Color3.fromRGB(253,251,172),
    LocalProperty = Color3.fromRGB( 97,161,241),
    Nil           = Color3.fromRGB(255,198,  0),
    Bool          = Color3.fromRGB(255,198,  0),
    Function      = Color3.fromRGB(248,109,124),
    Local         = Color3.fromRGB(248,109,124),
    Self          = Color3.fromRGB(248,109,124),
    FunctionName  = Color3.fromRGB(253,251,172),
    Bracket       = Color3.fromRGB(204,204,204),
}
local HL_KEYWORDS = {
    ["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
    ["end"]=true,["for"]=true,["function"]=true,["if"]=true,["in"]=true,
    ["local"]=true,["not"]=true,["or"]=true,["repeat"]=true,["return"]=true,
    ["then"]=true,["until"]=true,["while"]=true,
    ["false"]=true,["true"]=true,["nil"]=true,
}
local HL_BUILTINS = {
    ["game"]=true,["Players"]=true,["TweenService"]=true,["ScreenGui"]=true,
    ["Instance"]=true,["UDim2"]=true,["Vector2"]=true,["Vector3"]=true,
    ["Color3"]=true,["Enum"]=true,["loadstring"]=true,["warn"]=true,
    ["pcall"]=true,["print"]=true,["UDim"]=true,["delay"]=true,
    ["require"]=true,["spawn"]=true,["tick"]=true,["getfenv"]=true,
    ["workspace"]=true,["setfenv"]=true,["getgenv"]=true,["script"]=true,
    ["string"]=true,["pairs"]=true,["type"]=true,["math"]=true,
    ["tonumber"]=true,["tostring"]=true,["CFrame"]=true,["BrickColor"]=true,
    ["table"]=true,["Random"]=true,["Ray"]=true,["xpcall"]=true,
    ["coroutine"]=true,["_G"]=true,["_VERSION"]=true,["debug"]=true,
    ["Axes"]=true,["assert"]=true,["error"]=true,["ipairs"]=true,
    ["rawequal"]=true,["rawget"]=true,["rawset"]=true,["select"]=true,
    ["bit32"]=true,["buffer"]=true,["task"]=true,["os"]=true,
}
local HL_METHODS = {
    ["WaitForChild"]=true,["FindFirstChild"]=true,["GetService"]=true,
    ["Destroy"]=true,["Clone"]=true,["IsA"]=true,["ClearAllChildren"]=true,
    ["GetChildren"]=true,["GetDescendants"]=true,["Connect"]=true,
    ["Disconnect"]=true,["Fire"]=true,["Invoke"]=true,["rgb"]=true,
    ["FireServer"]=true,["request"]=true,["call"]=true,
}
local function colorToHex(c)
    return string.format("#%02x%02x%02x",
        math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
end
local function hlTokenize(line)
    local tokens, i = {}, 1
    while i <= #line do
        local c = line:sub(i,i)
        if c == "-" and line:sub(i,i+1) == "--" then
            table.insert(tokens, {line:sub(i), "Comment"}); break
        elseif c == "[" and line:sub(i,i+1):match("%[=*%[") then
            local eqCount, k = 0, i+1
            while line:sub(k,k) == "=" do eqCount += 1; k += 1 end
            if line:sub(k,k) == "[" then
                local close  = "]"..string.rep("=",eqCount).."]"
                local endIdx = line:find(close, k+1, true)
                local j      = endIdx and (endIdx + #close - 1) or #line
                table.insert(tokens, {line:sub(i,j), "String"}); i = j
            else
                table.insert(tokens, {c, "Operator"})
            end
        elseif c == '"' or c == "'" then
            local q, j = c, i+1
            while j <= #line do
                if line:sub(j,j) == q and line:sub(j-1,j-1) ~= "\\" then break end
                j += 1
            end
            table.insert(tokens, {line:sub(i,j), "String"}); i = j
        elseif c:match("%d") then
            local j = i
            while j <= #line and line:sub(j,j):match("[%d%.xXa-fA-F_]") do j += 1 end
            table.insert(tokens, {line:sub(i,j-1), "Number"}); i = j-1
        elseif c:match("[%a_]") then
            local j = i
            while j <= #line and line:sub(j,j):match("[%w_]") do j += 1 end
            table.insert(tokens, {line:sub(i,j-1), "Word"}); i = j-1
        else
            table.insert(tokens, {c, "Operator"})
        end
        i += 1
    end
    return tokens
end
local function hlDetect(tokens, idx)
    local val, typ = tokens[idx][1], tokens[idx][2]
    if typ ~= "Word" then return typ end
    if val == "self"                   then return "Self"          end
    if val == "true" or val == "false" then return "Bool"          end
    if val == "nil"                    then return "Nil"           end
    if HL_KEYWORDS[val]                then return "Keyword"       end
    if HL_BUILTINS[val]                then return "BuiltIn"       end
    if HL_METHODS[val]                 then return "LocalMethod"   end
    local prev = idx > 1 and tokens[idx-1][1] or ""
    if prev == "."                     then return "LocalProperty" end
    if prev == ":"                     then return "LocalMethod"   end
    if prev == "function"              then return "FunctionName"  end
    return "Text"
end
local function hlLine(line)
    local tokens = hlTokenize(line)
    local out    = ""
    for i, tok in ipairs(tokens) do
        local col  = Syntax[hlDetect(tokens, i)] or Syntax.Text
        local safe = tok[1]
            :gsub("&","&amp;")
            :gsub("<","&lt;")
            :gsub(">","&gt;")
        out ..= string.format('<font color="%s">%s</font>', colorToHex(col), safe)
    end
    return out
end
local function applySyntaxHighlight(source, overlayLabel)
    if not overlayLabel then return end
    local lines    = source:split("\n")
    local rendered = {}
    for _, ln in ipairs(lines) do
        rendered[#rendered+1] = hlLine(ln)
    end
    overlayLabel.Text = table.concat(rendered, "\n")
end
local function updateLineNumbers(codeText, lineLabel)
    local count = 1
    for _ in codeText:gmatch("\n") do count += 1 end
    local lines = {}
    for i = 1, count do lines[i] = tostring(i) end
    lineLabel.Text = table.concat(lines, "\n")
end
local function createGui()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name                  = "Synapse X"
    ScreenGui.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
    ScreenGui.ScreenInsets          = Enum.ScreenInsets.CoreUISafeInsets
    ScreenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
    local ToggleBtn = Instance.new("ImageButton")
    ToggleBtn.Parent                 = ScreenGui
    ToggleBtn.Name                   = "ToggleBtn"
    ToggleBtn.Size                   = UDim2.fromOffset(46, 46)
    ToggleBtn.Position               = UDim2.fromScale(0.965, 0.94)
    ToggleBtn.BackgroundColor3       = T.BG_MID
    ToggleBtn.BackgroundTransparency = 0
    ToggleBtn.BorderSizePixel        = 0
    ToggleBtn.Image                  = "rbxassetid://9524079125"
    ToggleBtn.ImageColor3            = T.ICON_TINT
    ToggleBtn.ScaleType              = Enum.ScaleType.Fit
    ToggleBtn.Style                  = Enum.ButtonStyle.Custom
    stroke(ToggleBtn, T.STROKE_OUTER, 1)
    hoverEffect(ToggleBtn, T.BG_BTN_HOV, T.BG_MID)
    local MainFrame = Instance.new("Frame")
    MainFrame.Parent           = ScreenGui
    MainFrame.Name             = "MainFrame"
    MainFrame.Size             = UDim2.fromOffset(FRAME_W, FRAME_H)
    MainFrame.Position         = UDim2.fromScale(0.062, 0.096)
    MainFrame.Visible          = false
    MainFrame.BackgroundColor3 = T.BG_DEEP
    MainFrame.BorderSizePixel  = 0
    MainFrame.ClipsDescendants = true
    stroke(MainFrame, T.STROKE_OUTER, 1)
    local TitleBar = Instance.new("Frame")
    TitleBar.Parent           = MainFrame
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, TITLEBAR_H)
    TitleBar.Position         = UDim2.fromOffset(0, 0)
    TitleBar.BackgroundColor3 = T.BG_MID
    TitleBar.BorderSizePixel  = 2
    TitleBar.ZIndex           = 2
    local TitleIcon = Instance.new("ImageLabel")
    TitleIcon.Parent                 = TitleBar
    TitleIcon.Size                   = UDim2.fromOffset(18, 18)
    TitleIcon.Position               = UDim2.fromOffset(8, 5)
    TitleIcon.BackgroundTransparency = 1
    TitleIcon.Image                  = "rbxassetid://9524079125"
    TitleIcon.ImageColor3            = T.ICON_TINT
    TitleIcon.ScaleType              = Enum.ScaleType.Fit
    TitleIcon.ZIndex                 = 3
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Parent                = TitleBar
    TitleLabel.Size                  = UDim2.new(1, -110, 1, 0)
    TitleLabel.Position              = UDim2.fromOffset(32, 0)
    TitleLabel.BackgroundTransparency= 1
    TitleLabel.Text                  = "Synapse X"
    TitleLabel.Font                  = Enum.Font.GothamBold
    TitleLabel.TextSize              = 15
    TitleLabel.TextColor3            = T.TEXT_MAIN
    TitleLabel.TextXAlignment        = Enum.TextXAlignment.Left
    TitleLabel.ZIndex                = 3
    local AccentLine = Instance.new("Frame")
    AccentLine.Parent           = MainFrame
    AccentLine.Size             = UDim2.new(1, 0, 0, 1)
    AccentLine.Position         = UDim2.fromOffset(0, TITLEBAR_H)
    AccentLine.BackgroundColor3 = T.STROKE_ACCENT
    AccentLine.BorderSizePixel  = 0
    AccentLine.ZIndex           = 2
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent           = TitleBar
    CloseBtn.Name             = "CloseBtn"
    CloseBtn.Size             = UDim2.fromOffset(28, 20)
    CloseBtn.Position         = UDim2.new(1, -30, 0, 4)
    CloseBtn.BackgroundColor3 = T.BG_MID
    CloseBtn.BorderSizePixel  = 0
    CloseBtn.Text             = "X"
    CloseBtn.Font             = Enum.Font.GothamBold
    CloseBtn.TextSize         = 12
    CloseBtn.TextColor3       = T.TEXT_DIM
    CloseBtn.ZIndex           = 4
    hoverEffect(CloseBtn, T.CLOSE_HOV, T.BG_MID)
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.08), { TextColor3 = Color3.fromRGB(255,255,255) }):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.08), { TextColor3 = T.TEXT_DIM }):Play()
    end)
    local MinBtn = Instance.new("TextButton")
    MinBtn.Parent           = TitleBar
    MinBtn.Name             = "MinBtn"
    MinBtn.Size             = UDim2.fromOffset(28, 20)
    MinBtn.Position         = UDim2.new(1, -60, 0, 4)
    MinBtn.BackgroundColor3 = T.BG_MID
    MinBtn.BorderSizePixel  = 0
    MinBtn.Text             = "─"
    MinBtn.Font             = Enum.Font.GothamBold
    MinBtn.TextSize         = 12
    MinBtn.TextColor3       = T.TEXT_DIM
    MinBtn.ZIndex           = 4
    hoverEffect(MinBtn, T.BG_BTN_HOV, T.BG_MID)
    local TabBar = Instance.new("Frame")
    TabBar.Parent           = MainFrame
    TabBar.Name             = "TabBar"
    TabBar.Size             = UDim2.new(1, 0, 0, TABBAR_H)
    TabBar.Position         = UDim2.fromOffset(0, TITLEBAR_H + 1)
    TabBar.BackgroundColor3 = T.BG_PANEL
    TabBar.BorderSizePixel  = 0
    local TabBarLine = Instance.new("Frame")
    TabBarLine.Parent           = TabBar
    TabBarLine.Size             = UDim2.new(1, 0, 0, 1)
    TabBarLine.Position         = UDim2.new(0, 0, 1, -1)
    TabBarLine.BackgroundColor3 = T.STROKE_INNER
    TabBarLine.BorderSizePixel  = 0
    local Tab1 = Instance.new("Frame")
    Tab1.Parent           = TabBar
    Tab1.Name             = "Tab1"
    Tab1.Size             = UDim2.fromOffset(88, TABBAR_H)
    Tab1.Position         = UDim2.fromOffset(0, 0)
    Tab1.BackgroundColor3 = T.BG_DEEP
    Tab1.BorderSizePixel  = 0
    local Tab1Label = Instance.new("TextLabel")
    Tab1Label.Parent                 = Tab1
    Tab1Label.Size                   = UDim2.new(1, -20, 1, 0)
    Tab1Label.Position               = UDim2.fromOffset(6, 0)
    Tab1Label.BackgroundTransparency = 1
    Tab1Label.Text                   = "Script 1"
    Tab1Label.Font                   = Enum.Font.Gotham
    Tab1Label.TextSize               = 11
    Tab1Label.TextColor3             = T.TEXT_TAB
    Tab1Label.TextXAlignment         = Enum.TextXAlignment.Left
    local Tab1Close = Instance.new("TextButton")
    Tab1Close.Parent           = Tab1
    Tab1Close.Name             = "TabClose"
    Tab1Close.Size             = UDim2.fromOffset(16, 16)
    Tab1Close.Position         = UDim2.new(1, -18, 0, 3)
    Tab1Close.BackgroundColor3 = T.BG_DEEP
    Tab1Close.BorderSizePixel  = 0
    Tab1Close.Text             = "x"
    Tab1Close.Font             = Enum.Font.Gotham
    Tab1Close.TextSize         = 9
    Tab1Close.TextColor3       = T.TEXT_DIM
    hoverEffect(Tab1Close, T.CLOSE_HOV, T.BG_DEEP)
    stroke(Tab1, T.STROKE_INNER, 1)
    local NewTabBtn = Instance.new("TextButton")
    NewTabBtn.Parent           = TabBar
    NewTabBtn.Name             = "NewTab"
    NewTabBtn.Size             = UDim2.fromOffset(22, TABBAR_H)
    NewTabBtn.Position         = UDim2.fromOffset(88, 0)
    NewTabBtn.BackgroundColor3 = T.BG_PANEL
    NewTabBtn.BorderSizePixel  = 0
    NewTabBtn.Text             = "+"
    NewTabBtn.Font             = Enum.Font.GothamBold
    NewTabBtn.TextSize         = 14
    NewTabBtn.TextColor3       = T.TEXT_DIM
    hoverEffect(NewTabBtn, T.BG_BTN_HOV, T.BG_PANEL)
    local EDITOR_TOP_PX = TITLEBAR_H + 1 + TABBAR_H
    local Gutter = Instance.new("Frame")
    Gutter.Parent           = MainFrame
    Gutter.Name             = "Gutter"
    Gutter.Size             = UDim2.fromOffset(GUTTER_W, EDITOR_H)
    Gutter.Position         = UDim2.fromOffset(0, EDITOR_TOP_PX)
    Gutter.BackgroundColor3 = T.BG_PANEL
    Gutter.BorderSizePixel  = 0
    Gutter.ClipsDescendants = true
    Gutter.ZIndex           = 2
    local GutterLine = Instance.new("Frame")
    GutterLine.Parent           = Gutter
    GutterLine.Size             = UDim2.new(0, 1, 1, 0)
    GutterLine.Position         = UDim2.new(1, -1, 0, 0)
    GutterLine.BackgroundColor3 = T.STROKE_INNER
    GutterLine.BorderSizePixel  = 0
    GutterLine.ZIndex           = 3
    local LineNumbers = Instance.new("TextLabel")
    LineNumbers.Parent              = Gutter
    LineNumbers.Name                = "LineNumbers"
    LineNumbers.Size                = UDim2.new(1, -4, 10, 0)
    LineNumbers.Position            = UDim2.fromOffset(0, 4)
    LineNumbers.BackgroundTransparency = 1
    LineNumbers.Text                = "1"
    LineNumbers.Font                = Enum.Font.Code
    LineNumbers.TextSize            = 14
    LineNumbers.TextColor3          = T.TEXT_DIM
    LineNumbers.TextXAlignment      = Enum.TextXAlignment.Right
    LineNumbers.TextYAlignment      = Enum.TextYAlignment.Top
    LineNumbers.ZIndex              = 3
    local EditorFrame = Instance.new("ScrollingFrame")
    EditorFrame.Parent                    = MainFrame
    EditorFrame.Name                      = "EditorScroll"
    EditorFrame.Size                      = UDim2.fromOffset(FRAME_W - GUTTER_W, EDITOR_H)
    EditorFrame.Position                  = UDim2.fromOffset(GUTTER_W, EDITOR_TOP_PX)
    EditorFrame.BackgroundColor3          = T.BG_EDITOR
    EditorFrame.BorderSizePixel           = 0
    EditorFrame.ClipsDescendants          = true
    EditorFrame.ScrollBarThickness        = 5
    EditorFrame.ScrollBarImageColor3      = T.STROKE_BTN
    EditorFrame.ScrollBarImageTransparency= 0
    EditorFrame.ScrollingDirection        = Enum.ScrollingDirection.XY
    EditorFrame.ElasticBehavior           = Enum.ElasticBehavior.WhenScrollable
    EditorFrame.CanvasSize                = UDim2.new(2, 0, 4, 0)
    EditorFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
    EditorFrame.BottomImage               = ""
    EditorFrame.MidImage                  = ""
    EditorFrame.TopImage                  = ""
    stroke(EditorFrame, T.STROKE_INNER, 1)
    local HighlightLabel = Instance.new("TextLabel")
    HighlightLabel.Parent                 = EditorFrame
    HighlightLabel.Name                   = "HighlightLabel"
    HighlightLabel.Size                   = UDim2.new(1, -8, 1, 0)
    HighlightLabel.Position               = UDim2.fromOffset(6, 4)
    HighlightLabel.BackgroundTransparency = 1
    HighlightLabel.Text                   = ""
    HighlightLabel.Font                   = Enum.Font.Code
    HighlightLabel.TextSize               = 14
    HighlightLabel.TextColor3             = T.TEXT_MAIN
    HighlightLabel.TextXAlignment         = Enum.TextXAlignment.Left
    HighlightLabel.TextYAlignment         = Enum.TextYAlignment.Top
    HighlightLabel.TextTruncate           = Enum.TextTruncate.None
    HighlightLabel.RichText               = true
    HighlightLabel.ZIndex                 = 1
    local CodeBox = Instance.new("TextBox")
    CodeBox.Parent                 = EditorFrame
    CodeBox.Name                   = "CodeBox"
    CodeBox.Size                   = UDim2.new(1, -8, 1, 0)
    CodeBox.Position               = UDim2.fromOffset(6, 4)
    CodeBox.BackgroundTransparency = 1
    CodeBox.Text                   = ""
    CodeBox.Font                   = Enum.Font.Code
    CodeBox.TextSize               = 14
    CodeBox.TextColor3             = Color3.fromRGB(0, 0, 0)
    CodeBox.TextTransparency       = 1
    CodeBox.TextXAlignment         = Enum.TextXAlignment.Left
    CodeBox.TextYAlignment         = Enum.TextYAlignment.Top
    CodeBox.TextTruncate           = Enum.TextTruncate.None
    CodeBox.TextStrokeTransparency = 1
    CodeBox.PlaceholderText        = "-- paste or type your script here"
    CodeBox.PlaceholderColor3      = T.TEXT_DIM
    CodeBox.ClearTextOnFocus       = false
    CodeBox.MultiLine              = true
    CodeBox.ZIndex                 = 2
    local Toolbar = Instance.new("Frame")
    Toolbar.Parent           = MainFrame
    Toolbar.Name             = "Toolbar"
    Toolbar.Size             = UDim2.new(1, 0, 0, TOOLBAR_H)
    Toolbar.Position         = UDim2.new(0, 0, 1, -TOOLBAR_H)
    Toolbar.BackgroundColor3 = T.BG_MID
    Toolbar.BorderSizePixel  = 0
    local ToolbarLine = Instance.new("Frame")
    ToolbarLine.Parent           = Toolbar
    ToolbarLine.Size             = UDim2.new(1, 0, 0, 1)
    ToolbarLine.Position         = UDim2.fromOffset(0, 0)
    ToolbarLine.BackgroundColor3 = T.STROKE_INNER
    ToolbarLine.BorderSizePixel  = 0
    local btnDefs = {
        { name = "Execute",     label = "Execute",      x = 6 },
        { name = "OpenFile",    label = "Open File",    x = 190 },
        { name = "Clear",       label = "Clear",        x = 98 },
        { name = "SaveFile",    label = "Save File",    x = 374 },
        { name = "Options",     label = "Options",      x = 466 },
        { name = "Hub",         label = "Script Hub",   x = 600 },
    }
    local buttons = {}
    for _, def in ipairs(btnDefs) do
        local btn = Instance.new("TextButton")
        btn.Parent           = Toolbar
        btn.Name             = def.name
        btn.Size             = UDim2.fromOffset(86, 22)
        btn.Position         = UDim2.fromOffset(def.x, 6)
        btn.BackgroundColor3 = T.BG_BTN
        btn.BorderSizePixel  = 0
        btn.Text             = def.label
        btn.Font             = Enum.Font.Gotham
        btn.TextSize         = 11
        btn.TextColor3       = T.TEXT_MAIN
        btn.ZIndex           = 2
        stroke(btn, T.STROKE_BTN, 1)
        hoverEffect(btn, T.BG_BTN_HOV, T.BG_BTN)
        buttons[def.name] = btn
    end
    local execStroke = buttons["Execute"]:FindFirstChildOfClass("UIStroke")
    if execStroke then execStroke.Color = T.STROKE_ACCENT end
    ScreenGui.Parent = playerGui
    return {
        ScreenGui      = ScreenGui,
        ToggleBtn      = ToggleBtn,
        MainFrame      = MainFrame,
        TitleBar       = TitleBar,
        CloseBtn       = CloseBtn,
        MinBtn         = MinBtn,
        CodeBox        = CodeBox,
        HighlightLabel = HighlightLabel,
        EditorScroll   = EditorFrame,
        LineNumbers    = LineNumbers,
        TabClose       = Tab1Close,
        NewTab         = NewTabBtn,
        Execute        = buttons["Execute"],
        Clear          = buttons["Clear"],
        OpenFile       = buttons["OpenFile"],
        SaveFile       = buttons["SaveFile"],
        Options        = buttons["Options"],
        Hub            = buttons["Hub"],
    }
end
local ui = createGui()
updateLineNumbers(ui.CodeBox.Text, ui.LineNumbers)
applySyntaxHighlight(ui.CodeBox.Text, ui.HighlightLabel)
ui.ToggleBtn.MouseButton1Click:Connect(function()
    local f = ui.MainFrame
    if f.Visible then
        TweenService:Create(f, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size     = UDim2.new(0, f.AbsoluteSize.X, 0, 0),
            Position = f.Position + UDim2.fromOffset(0, f.AbsoluteSize.Y / 2)
        }):Play()
        task.delay(0.18, function()
            f.Visible = false
            f.Size     = UDim2.fromOffset(FRAME_W, FRAME_H)
            f.Position = UDim2.fromScale(0.062, 0.096)
        end)
    else
        f.Size    = UDim2.new(0, FRAME_W, 0, 0)
        f.Visible = true
        TweenService:Create(f, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(FRAME_W, FRAME_H)
        }):Play()
    end
end)
ui.CloseBtn.MouseButton1Click:Connect(function()
    local f = ui.MainFrame
    TweenService:Create(f, TweenInfo.new(0.15), {
        Size = UDim2.new(0, f.AbsoluteSize.X, 0, 0)
    }):Play()
    task.delay(0.15, function()
        f.Visible = false
        f.Size = UDim2.fromOffset(FRAME_W, FRAME_H)
    end)
end)
local minimized = false
local FULL_SIZE = UDim2.fromOffset(FRAME_W, FRAME_H)
local MINI_SIZE = UDim2.fromOffset(FRAME_W, TITLEBAR_H)
ui.MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(ui.MainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        Size = minimized and MINI_SIZE or FULL_SIZE
    }):Play()
end)
do
    local dragging = false
    local dragStart, startPos = Vector2.zero, UDim2.new()
    local DRAG_TWEEN = TweenInfo.new(0.04)
    ui.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = ui.MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragStart
        TweenService:Create(ui.MainFrame, DRAG_TWEEN, {
            Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        }):Play()
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
            if not ok then warn("[SynapseUI] Runtime error: " .. tostring(runErr)) end
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
local SCRIPTS_DIR = "scripts"
local function ensureScriptsDir()
    local ok = pcall(function()
        if isfolder and not isfolder(SCRIPTS_DIR) then
            makefolder(SCRIPTS_DIR)
        end
    end)
    return ok
end
local function showSaveDialog(scriptCode)
    local backdrop = Instance.new("Frame")
    backdrop.Name                   = "SaveDialogBackdrop"
    backdrop.Size                   = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.55
    backdrop.BorderSizePixel        = 0
    backdrop.ZIndex                 = 50
    backdrop.Parent                 = ui.ScreenGui
    local dialog = Instance.new("Frame", backdrop)
    dialog.Name             = "SaveDialog"
    dialog.Size             = UDim2.fromOffset(320, 118)
    dialog.Position         = UDim2.new(0.5, -160, 0.5, -59)
    dialog.BackgroundColor3 = T.BG_DEEP
    dialog.BorderSizePixel  = 0
    dialog.ZIndex           = 51
    stroke(dialog, T.STROKE_OUTER, 1)
    local dTitleBar = Instance.new("Frame", dialog)
    dTitleBar.Size             = UDim2.new(1, 0, 0, 26)
    dTitleBar.BackgroundColor3 = T.BG_MID
    dTitleBar.BorderSizePixel  = 0
    dTitleBar.ZIndex           = 52
    local dTitle = Instance.new("TextLabel", dTitleBar)
    dTitle.Size                   = UDim2.new(1, -10, 1, 0)
    dTitle.Position               = UDim2.fromOffset(10, 0)
    dTitle.BackgroundTransparency = 1
    dTitle.Text                   = "Save Script"
    dTitle.Font                   = Enum.Font.GothamBold
    dTitle.TextSize               = 12
    dTitle.TextColor3             = T.TEXT_MAIN
    dTitle.TextXAlignment         = Enum.TextXAlignment.Left
    dTitle.ZIndex                 = 53
    local dAccent = Instance.new("Frame", dialog)
    dAccent.Size             = UDim2.new(1, 0, 0, 1)
    dAccent.Position         = UDim2.fromOffset(0, 26)
    dAccent.BackgroundColor3 = T.STROKE_ACCENT
    dAccent.BorderSizePixel  = 0
    dAccent.ZIndex           = 52
    local dLabel = Instance.new("TextLabel", dialog)
    dLabel.Size                   = UDim2.new(1, -20, 0, 16)
    dLabel.Position               = UDim2.fromOffset(10, 34)
    dLabel.BackgroundTransparency = 1
    dLabel.Text                   = "Script name:"
    dLabel.Font                   = Enum.Font.Gotham
    dLabel.TextSize               = 11
    dLabel.TextColor3             = T.TEXT_DIM
    dLabel.TextXAlignment         = Enum.TextXAlignment.Left
    dLabel.ZIndex                 = 52
    local dInputBg = Instance.new("Frame", dialog)
    dInputBg.Size             = UDim2.new(1, -20, 0, 24)
    dInputBg.Position         = UDim2.fromOffset(10, 52)
    dInputBg.BackgroundColor3 = T.BG_EDITOR
    dInputBg.BorderSizePixel  = 0
    dInputBg.ZIndex           = 52
    stroke(dInputBg, T.STROKE_INNER, 1)
    local dInput = Instance.new("TextBox", dInputBg)
    dInput.Size                   = UDim2.new(1, -12, 1, -4)
    dInput.Position               = UDim2.fromOffset(6, 2)
    dInput.BackgroundTransparency = 1
    dInput.Text                   = "MyScript"
    dInput.Font                   = Enum.Font.Gotham
    dInput.TextSize               = 12
    dInput.TextColor3             = T.TEXT_MAIN
    dInput.TextXAlignment         = Enum.TextXAlignment.Left
    dInput.ClearTextOnFocus       = false
    dInput.PlaceholderText        = "enter script name..."
    dInput.PlaceholderColor3      = T.TEXT_DIM
    dInput.ZIndex                 = 53
    local dSaveBtn = Instance.new("TextButton", dialog)
    dSaveBtn.Name             = "SaveBtn"
    dSaveBtn.Size             = UDim2.fromOffset(82, 22)
    dSaveBtn.Position         = UDim2.new(0.5, -86, 1, -30)
    dSaveBtn.BackgroundColor3 = T.BG_BTN
    dSaveBtn.BorderSizePixel  = 0
    dSaveBtn.Text             = "Save"
    dSaveBtn.Font             = Enum.Font.Gotham
    dSaveBtn.TextSize         = 11
    dSaveBtn.TextColor3       = T.TEXT_MAIN
    dSaveBtn.ZIndex           = 52
    stroke(dSaveBtn, T.STROKE_ACCENT, 1)
    hoverEffect(dSaveBtn, T.BG_BTN_HOV, T.BG_BTN)
    local dCancelBtn = Instance.new("TextButton", dialog)
    dCancelBtn.Name             = "CancelBtn"
    dCancelBtn.Size             = UDim2.fromOffset(82, 22)
    dCancelBtn.Position         = UDim2.new(0.5, 4, 1, -30)
    dCancelBtn.BackgroundColor3 = T.BG_BTN
    dCancelBtn.BorderSizePixel  = 0
    dCancelBtn.Text             = "Cancel"
    dCancelBtn.Font             = Enum.Font.Gotham
    dCancelBtn.TextSize         = 11
    dCancelBtn.TextColor3       = T.TEXT_MAIN
    dCancelBtn.ZIndex           = 52
    stroke(dCancelBtn, T.STROKE_BTN, 1)
    hoverEffect(dCancelBtn, T.BG_BTN_HOV, T.BG_BTN)
    dInput:CaptureFocus()
    dInput.SelectionStart  = 1
    dInput.CursorPosition  = #dInput.Text + 1
    local function doSave()
        local name = dInput.Text:gsub("%.lua$", ""):match("^%s*(.-)%s*$")
        if not name or name == "" then
            warn("[SynapseUI] Please enter a valid script name.")
            return
        end
        if not writefile then
            warn("[SynapseUI] writefile not available.")
            backdrop:Destroy()
            return
        end
        ensureScriptsDir()
        local path = SCRIPTS_DIR .. "/" .. name .. ".lua"
        local ok, err = pcall(writefile, path, scriptCode)
        if ok then
            print("[SynapseUI] Saved → " .. path)
        else
            warn("[SynapseUI] Save failed: " .. tostring(err))
        end
        backdrop:Destroy()
    end
    dSaveBtn.MouseButton1Click:Connect(doSave)
    dCancelBtn.MouseButton1Click:Connect(function() backdrop:Destroy() end)
    dInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then doSave() end
    end)
end
ui.SaveFile.MouseButton1Click:Connect(function()
    flash(ui.SaveFile)
    local code = ui.CodeBox.Text
    if code == "" then
        warn("[SynapseUI] Nothing to save.")
        return
    end
    showSaveDialog(code)
end)
ui.Options.MouseButton1Click:Connect(function()
    flash(ui.Options)
    print("[SynapseUI] Options")
end)
local HttpService = game:GetService("HttpService")
local Hub = {
    _frame       = nil,
    _scroll      = nil,
    _results     = {},
    _page        = 1,
    _perPage     = 20,
    _query       = "",
    _searching   = false,
    _history     = {},
    _sortMode    = "newest",
    _source      = "scriptblox",
    _apis        = {
        scriptblox = "https://scriptblox.com/api/script/search?q=%s&mode=free&max=100",
    },
}
local function hubRequest(url)
    local req = (typeof(request)  == "function" and request)
             or (typeof(syn)      == "table"    and syn.request)
             or (typeof(http)     == "table"    and http.request)
    if not req then return nil, "no http function" end
    local ok, res = pcall(req, { Url = url, Method = "GET" })
    if ok and res.StatusCode == 200 then
        return res.Body
    end
    return nil, "request failed"
end
local function hubClearScroll(scroll)
    for _, v in ipairs(scroll:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
            v:Destroy()
        end
    end
end
local function hubStatusLabel(scroll, msg, col)
    local lbl = Instance.new("TextLabel", scroll)
    lbl.Size                   = UDim2.new(1, -10, 0, 28)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = msg
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextSize               = 12
    lbl.TextColor3             = col or T.TEXT_DIM
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    return lbl
end
local function hubBtn(parent, label, x, w, accentStroke)
    local b = Instance.new("TextButton", parent)
    b.Size             = UDim2.fromOffset(w or 70, 22)
    b.Position         = UDim2.fromOffset(x, 4)
    b.BackgroundColor3 = T.BG_BTN
    b.BorderSizePixel  = 0
    b.Text             = label
    b.Font             = Enum.Font.Gotham
    b.TextSize         = 11
    b.TextColor3       = T.TEXT_MAIN
    b.ZIndex           = 2
    stroke(b, accentStroke and T.STROKE_ACCENT or T.STROKE_BTN, 1)
    hoverEffect(b, T.BG_BTN_HOV, T.BG_BTN)
    return b
end
local function hubCard(scroll, data, index)
    local card = Instance.new("Frame", scroll)
    card.Name             = "Card_" .. index
    card.Size             = UDim2.new(1, -10, 0, 62)
    card.BackgroundColor3 = index % 2 == 0 and T.BG_MID or T.BG_PANEL
    card.BorderSizePixel  = 0
    stroke(card, T.STROKE_INNER, 1)
    local titleLbl = Instance.new("TextLabel", card)
    titleLbl.Size                   = UDim2.new(1, -182, 0, 22)
    titleLbl.Position               = UDim2.fromOffset(8, 4)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = data.title or "Untitled"
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.TextSize               = 12
    titleLbl.TextColor3             = T.TEXT_MAIN
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.TextTruncate           = Enum.TextTruncate.AtEnd
    local gameLbl = Instance.new("TextLabel", card)
    gameLbl.Size                   = UDim2.new(1, -182, 0, 16)
    gameLbl.Position               = UDim2.fromOffset(8, 26)
    gameLbl.BackgroundTransparency = 1
    gameLbl.Text                   = "Game: " .. ((data.game and data.game.name) or "Universal")
    gameLbl.Font                   = Enum.Font.Gotham
    gameLbl.TextSize               = 10
    gameLbl.TextColor3             = T.TEXT_DIM
    gameLbl.TextXAlignment         = Enum.TextXAlignment.Left
    gameLbl.TextTruncate           = Enum.TextTruncate.AtEnd
    local favLbl = Instance.new("TextLabel", card)
    favLbl.Size                   = UDim2.new(1, -182, 0, 14)
    favLbl.Position               = UDim2.fromOffset(8, 44)
    favLbl.BackgroundTransparency = 1
    favLbl.Text                   = "♥ " .. tostring(data.favorites or 0)
    favLbl.Font                   = Enum.Font.Gotham
    favLbl.TextSize               = 10
    favLbl.TextColor3             = T.TEXT_DIM
    favLbl.TextXAlignment         = Enum.TextXAlignment.Left
    local function cardBtn(label, xOff, accentCol)
        local b = Instance.new("TextButton", card)
        b.Size             = UDim2.fromOffset(56, 18)
        b.Position         = UDim2.new(1, xOff, 0, 22)
        b.BackgroundColor3 = T.BG_BTN
        b.BorderSizePixel  = 0
        b.Text             = label
        b.Font             = Enum.Font.Gotham
        b.TextSize         = 10
        b.TextColor3       = T.TEXT_MAIN
        stroke(b, accentCol or T.STROKE_BTN, 1)
        hoverEffect(b, T.BG_BTN_HOV, T.BG_BTN)
        return b
    end
    local execBtn = cardBtn("Execute", -174, T.STROKE_ACCENT)
    local copyBtn = cardBtn("Copy",    -114, T.STROKE_BTN)
    local viewBtn = cardBtn("View",    - 54, T.STROKE_BTN)
    execBtn.MouseButton1Click:Connect(function()
        local fn, err = loadstring(data.script or "")
        if fn then
            task.spawn(fn)
            StarterGui:SetCore("SendNotification", { Title="Script Hub", Text="Executed: "..(data.title or "script"), Duration=2 })
        else
            warn("[Hub] Syntax error: " .. tostring(err))
            StarterGui:SetCore("SendNotification", { Title="Script Hub", Text="Syntax error in script.", Duration=3 })
        end
    end)
    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(data.script or "")
            StarterGui:SetCore("SendNotification", { Title="Script Hub", Text="Copied to clipboard.", Duration=2 })
        end
    end)
    viewBtn.MouseButton1Click:Connect(function()
        ui.CodeBox.Text = data.script or ""
        StarterGui:SetCore("SendNotification", { Title="Script Hub", Text="Loaded into editor.", Duration=2 })
    end)
end
local function hubDisplayPage()
    local scroll = Hub._scroll
    hubClearScroll(scroll)
    local results = Hub._results
    if #results == 0 then
        hubStatusLabel(scroll, "No results found.")
        return
    end
    local startIdx = (Hub._page - 1) * Hub._perPage + 1
    local endIdx   = math.min(Hub._page * Hub._perPage, #results)
    for i = startIdx, endIdx do
        hubCard(scroll, results[i], i)
    end
    local totalPages = math.ceil(#results / Hub._perPage)
    hubStatusLabel(scroll,
        "Page " .. Hub._page .. " / " .. totalPages .. "  —  " .. #results .. " results",
        T.TEXT_DIM)
end
local function hubSearch(query, gameMode)
    if Hub._searching then return end
    if not query or query == "" then
        StarterGui:SetCore("SendNotification", { Title="Script Hub", Text="Enter a search query.", Duration=2 })
        return
    end
    Hub._searching = true
    Hub._query     = query
    Hub._page      = 1
    Hub._results   = {}
    if not table.find(Hub._history, query) then
        table.insert(Hub._history, 1, query)
        if #Hub._history > 15 then table.remove(Hub._history) end
    end
    local scroll = Hub._scroll
    hubClearScroll(scroll)
    local statusLbl = hubStatusLabel(scroll, "Searching '" .. Hub._source .. "'...", T.TEXT_MAIN)
    task.spawn(function()
        local apiUrl  = Hub._apis[Hub._source] or Hub._apis.scriptblox
        local encoded = HttpService:UrlEncode(query)
        local url     = apiUrl:format(encoded)
        local body, err = hubRequest(url)
        if body then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
            if ok and data and data.result and data.result.scripts then
                Hub._results = data.result.scripts
                if Hub._sortMode == "popular" then
                    table.sort(Hub._results, function(a,b) return (a.favorites or 0) > (b.favorites or 0) end)
                else
                    table.sort(Hub._results, function(a,b) return (a.updated_at or "") > (b.updated_at or "") end)
                end
                hubDisplayPage()
                StarterGui:SetCore("SendNotification", {
                    Title = "Script Hub",
                    Text  = "Found " .. #Hub._results .. " results.",
                    Duration = 2,
                })
            else
                if statusLbl and statusLbl.Parent then
                    statusLbl.Text = "No results found."
                end
            end
        else
            if statusLbl and statusLbl.Parent then
                statusLbl.Text = "Request failed: " .. tostring(err)
            end
        end
        Hub._searching = false
    end)
end
local function createHubUI()
    if Hub._frame and Hub._frame.Parent then
        Hub._frame:Destroy()
        Hub._frame = nil
        return
    end
    local StarterGui = game:GetService("StarterGui")
    local HUB_W, HUB_H = 580, 500
    local hubFrame = Instance.new("Frame", ui.ScreenGui)
    hubFrame.Name             = "ScriptHub"
    hubFrame.Size             = UDim2.fromOffset(HUB_W, HUB_H)
    hubFrame.Position         = UDim2.fromScale(0.5, 0.5)
    hubFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    hubFrame.BackgroundColor3 = T.BG_DEEP
    hubFrame.BorderSizePixel  = 0
    hubFrame.ClipsDescendants = true
    hubFrame.ZIndex           = 20
    stroke(hubFrame, T.STROKE_OUTER, 1)
    Hub._frame = hubFrame
    local hubTitleBar = Instance.new("Frame", hubFrame)
    hubTitleBar.Name             = "HubTitleBar"
    hubTitleBar.Size             = UDim2.new(1, 0, 0, 28)
    hubTitleBar.BackgroundColor3 = T.BG_MID
    hubTitleBar.BorderSizePixel  = 0
    hubTitleBar.ZIndex           = 21
    local hubTitleLbl = Instance.new("TextLabel", hubTitleBar)
    hubTitleLbl.Size                   = UDim2.new(1, -40, 1, 0)
    hubTitleLbl.Position               = UDim2.fromOffset(10, 0)
    hubTitleLbl.BackgroundTransparency = 1
    hubTitleLbl.Text                   = "Script Hub"
    hubTitleLbl.Font                   = Enum.Font.GothamBold
    hubTitleLbl.TextSize               = 13
    hubTitleLbl.TextColor3             = T.TEXT_MAIN
    hubTitleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    hubTitleLbl.ZIndex                 = 22
    local hubCloseBtn = Instance.new("TextButton", hubTitleBar)
    hubCloseBtn.Size             = UDim2.fromOffset(28, 20)
    hubCloseBtn.Position         = UDim2.new(1, -30, 0, 4)
    hubCloseBtn.BackgroundColor3 = T.BG_MID
    hubCloseBtn.BorderSizePixel  = 0
    hubCloseBtn.Text             = "X"
    hubCloseBtn.Font             = Enum.Font.GothamBold
    hubCloseBtn.TextSize         = 12
    hubCloseBtn.TextColor3       = T.TEXT_DIM
    hubCloseBtn.ZIndex           = 22
    hoverEffect(hubCloseBtn, T.CLOSE_HOV, T.BG_MID)
    hubCloseBtn.MouseEnter:Connect(function()
        TweenService:Create(hubCloseBtn, TweenInfo.new(0.08), { TextColor3 = Color3.fromRGB(255,255,255) }):Play()
    end)
    hubCloseBtn.MouseLeave:Connect(function()
        TweenService:Create(hubCloseBtn, TweenInfo.new(0.08), { TextColor3 = T.TEXT_DIM }):Play()
    end)
    hubCloseBtn.MouseButton1Click:Connect(function()
        hubFrame:Destroy()
        Hub._frame = nil
    end)
    local hubAccent = Instance.new("Frame", hubFrame)
    hubAccent.Size             = UDim2.new(1, 0, 0, 1)
    hubAccent.Position         = UDim2.fromOffset(0, 28)
    hubAccent.BackgroundColor3 = T.STROKE_ACCENT
    hubAccent.BorderSizePixel  = 0
    hubAccent.ZIndex           = 21
    local searchRow = Instance.new("Frame", hubFrame)
    searchRow.Name             = "SearchRow"
    searchRow.Size             = UDim2.new(1, 0, 0, 30)
    searchRow.Position         = UDim2.fromOffset(0, 29)
    searchRow.BackgroundColor3 = T.BG_PANEL
    searchRow.BorderSizePixel  = 0
    searchRow.ZIndex           = 21
    local searchRowLine = Instance.new("Frame", searchRow)
    searchRowLine.Size             = UDim2.new(1, 0, 0, 1)
    searchRowLine.Position         = UDim2.new(0, 0, 1, -1)
    searchRowLine.BackgroundColor3 = T.STROKE_INNER
    searchRowLine.BorderSizePixel  = 0
    local searchBg = Instance.new("Frame", searchRow)
    searchBg.Size             = UDim2.new(1, -240, 0, 22)
    searchBg.Position         = UDim2.fromOffset(6, 4)
    searchBg.BackgroundColor3 = T.BG_EDITOR
    searchBg.BorderSizePixel  = 0
    stroke(searchBg, T.STROKE_INNER, 1)
    local searchBox = Instance.new("TextBox", searchBg)
    searchBox.Size                   = UDim2.new(1, -10, 1, -4)
    searchBox.Position               = UDim2.fromOffset(5, 2)
    searchBox.BackgroundTransparency = 1
    searchBox.Text                   = ""
    searchBox.Font                   = Enum.Font.Gotham
    searchBox.TextSize               = 12
    searchBox.TextColor3             = T.TEXT_MAIN
    searchBox.PlaceholderText        = "Search scripts..."
    searchBox.PlaceholderColor3      = T.TEXT_DIM
    searchBox.ClearTextOnFocus       = false
    searchBox.ZIndex                 = 22
    local btnX = HUB_W - 234
    local searchExecBtn = hubBtn(searchRow, "Search",  btnX,       66, true)
    local gameBtn       = hubBtn(searchRow, "Game",    btnX + 70,  54, false)
    local refreshBtn    = hubBtn(searchRow, "Refresh", btnX + 128, 60, false)
    local historyBtn    = hubBtn(searchRow, "History", btnX + 192, 60, false)
    local optRow = Instance.new("Frame", hubFrame)
    optRow.Name             = "OptRow"
    optRow.Size             = UDim2.new(1, 0, 0, 26)
    optRow.Position         = UDim2.fromOffset(0, 59)
    optRow.BackgroundColor3 = T.BG_MID
    optRow.BorderSizePixel  = 0
    optRow.ZIndex           = 21
    local optRowLine = Instance.new("Frame", optRow)
    optRowLine.Size             = UDim2.new(1, 0, 0, 1)
    optRowLine.Position         = UDim2.new(0, 0, 1, -1)
    optRowLine.BackgroundColor3 = T.STROKE_INNER
    optRowLine.BorderSizePixel  = 0
    local function optLabel(txt, x)
        local l = Instance.new("TextLabel", optRow)
        l.Size                   = UDim2.fromOffset(44, 26)
        l.Position               = UDim2.fromOffset(x, 0)
        l.BackgroundTransparency = 1
        l.Text                   = txt
        l.Font                   = Enum.Font.Gotham
        l.TextSize               = 10
        l.TextColor3             = T.TEXT_DIM
        l.TextXAlignment         = Enum.TextXAlignment.Left
        l.ZIndex                 = 22
        return l
    end
    optLabel("Sort:", 8)
    local sortBtn = hubBtn(optRow, "Newest", 50, 68, false)
    sortBtn.ZIndex = 22
    local sortModes = { "newest", "popular" }
    local sortIdx   = 1
    sortBtn.MouseButton1Click:Connect(function()
        sortIdx = sortIdx % #sortModes + 1
        Hub._sortMode = sortModes[sortIdx]
        sortBtn.Text  = sortModes[sortIdx]:sub(1,1):upper() .. sortModes[sortIdx]:sub(2)
        if #Hub._results > 0 then
            if Hub._sortMode == "popular" then
                table.sort(Hub._results, function(a,b) return (a.favorites or 0) > (b.favorites or 0) end)
            else
                table.sort(Hub._results, function(a,b) return (a.updated_at or "") > (b.updated_at or "") end)
            end
            hubDisplayPage()
        end
    end)
    optLabel("Per page:", 128)
    local perPageBtn = hubBtn(optRow, "20", 194, 44, false)
    perPageBtn.ZIndex = 22
    local pageOpts = {10, 20, 50}
    local pageOptIdx = 2
    perPageBtn.MouseButton1Click:Connect(function()
        pageOptIdx      = pageOptIdx % #pageOpts + 1
        Hub._perPage    = pageOpts[pageOptIdx]
        perPageBtn.Text = tostring(pageOpts[pageOptIdx])
        if #Hub._results > 0 then hubDisplayPage() end
    end)
    local prevBtn = hubBtn(optRow, "◄ Prev", HUB_W - 148, 66, false)
    prevBtn.ZIndex = 22
    prevBtn.MouseButton1Click:Connect(function()
        if Hub._page > 1 then
            Hub._page -= 1
            hubDisplayPage()
        end
    end)
    local nextBtn = hubBtn(optRow, "Next ►", HUB_W - 78, 66, false)
    nextBtn.ZIndex = 22
    nextBtn.MouseButton1Click:Connect(function()
        local maxPage = math.ceil(#Hub._results / Hub._perPage)
        if Hub._page < maxPage then
            Hub._page += 1
            hubDisplayPage()
        end
    end)
    local RESULTS_TOP = 85
    local scroll = Instance.new("ScrollingFrame", hubFrame)
    scroll.Name                  = "HubScroll"
    scroll.Size                  = UDim2.new(1, -12, 1, -(RESULTS_TOP + 6))
    scroll.Position              = UDim2.fromOffset(6, RESULTS_TOP)
    scroll.BackgroundColor3      = T.BG_EDITOR
    scroll.BorderSizePixel       = 0
    scroll.ScrollBarThickness    = 5
    scroll.ScrollBarImageColor3  = T.STROKE_BTN
    scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    scroll.CanvasSize            = UDim2.new(0,0,0,0)
    scroll.ScrollingDirection    = Enum.ScrollingDirection.Y
    scroll.ZIndex                = 21
    stroke(scroll, T.STROKE_INNER, 1)
    Hub._scroll = scroll
    local layout = Instance.new("UIListLayout", scroll)
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.Padding             = UDim.new(0, 4)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingTop    = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft   = UDim.new(0, 4)
    pad.PaddingRight  = UDim.new(0, 4)
    hubStatusLabel(scroll, "Search for scripts above, or press Game to find scripts for this game.", T.TEXT_DIM)
    do
        local dragging, dragStart, startPos = false, Vector2.zero, UDim2.new()
        hubTitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging  = true
                dragStart = input.Position
                startPos  = hubFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local d = input.Position - dragStart
            hubFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end)
    end
    searchExecBtn.MouseButton1Click:Connect(function()
        hubSearch(searchBox.Text, false)
    end)
    searchBox.FocusLost:Connect(function(enter)
        if enter then hubSearch(searchBox.Text, false) end
    end)
    gameBtn.MouseButton1Click:Connect(function()
        hubSearch("game:" .. game.GameId, true)
    end)
    refreshBtn.MouseButton1Click:Connect(function()
        if Hub._query ~= "" then
            hubSearch(Hub._query, false)
        end
    end)
    historyBtn.MouseButton1Click:Connect(function()
        hubClearScroll(scroll)
        if #Hub._history == 0 then
            hubStatusLabel(scroll, "No search history yet.", T.TEXT_DIM)
            return
        end
        for i, q in ipairs(Hub._history) do
            local hBtn = Instance.new("TextButton", scroll)
            hBtn.Name             = "Hist_" .. i
            hBtn.Size             = UDim2.new(1, -10, 0, 26)
            hBtn.BackgroundColor3 = T.BG_MID
            hBtn.BorderSizePixel  = 0
            hBtn.Text             = "⟳  " .. q
            hBtn.Font             = Enum.Font.Gotham
            hBtn.TextSize         = 11
            hBtn.TextColor3       = T.TEXT_TAB
            hBtn.TextXAlignment   = Enum.TextXAlignment.Left
            stroke(hBtn, T.STROKE_INNER, 1)
            hoverEffect(hBtn, T.BG_BTN_HOV, T.BG_MID)
            hBtn.MouseButton1Click:Connect(function()
                searchBox.Text = q
                hubSearch(q, false)
            end)
        end
    end)
end
ui.Hub.MouseButton1Click:Connect(function()
    flash(ui.Hub)
    createHubUI()
end)
ui.TabClose.MouseButton1Click:Connect(function()
    ui.CodeBox.Text = ""
    print("[SynapseUI] Tab closed")
end)
ui.NewTab.MouseButton1Click:Connect(function()
    ui.CodeBox.Text = ""
    print("[SynapseUI] New tab")
end)
