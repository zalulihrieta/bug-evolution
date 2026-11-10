--[[
    BUG EVOLUTION UI FRAMEWORK
    Version: 1.0
    Author: Hrieta

    Components:
    CreateTab
    SetTab
    AddSection
    AddLabel
    AddButton
    AddToggle
    AddDropdown
    AddSlider
    Notify
    Destroy
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local GUI = {}

local Parent

pcall(function()
    Parent = gethui()
end)

Parent = Parent or game:GetService("CoreGui")

local Previous = Parent:FindFirstChild("BugEvolution")

if Previous then
    Previous:Destroy()
end

-- THEME

local Theme = {
    Background = Color3.fromRGB(19, 22, 30),
    Secondary = Color3.fromRGB(27, 33, 46),
    Element = Color3.fromRGB(35, 42, 56),
    Accent = Color3.fromRGB(65, 125, 220),
    Text = Color3.fromRGB(240, 244, 255),
    SubText = Color3.fromRGB(155, 170, 195),
    Success = Color3.fromRGB(35, 155, 100),
    Danger = Color3.fromRGB(190, 65, 65)
}

-- SCREEN GUI

local Screen = Instance.new("ScreenGui")
Screen.Name = "BugEvolution"
Screen.ResetOnSpawn = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Screen.Parent = Parent

-- MAIN WINDOW

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(340, 320)
Main.Position = UDim2.new(0.5, -170, 0.5, -160)
Main.BackgroundColor3 = Theme.Background
Main.BackgroundTransparency = 0.14
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Screen

Instance.new("UICorner", Main).CornerRadius =
    UDim.new(0, 10)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Theme.Accent
Stroke.Transparency = 0.65
Stroke.Parent = Main

-- HEADER

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Theme.Secondary
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "BUG EVOLUTION"
Title.TextColor3 = Theme.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(32, 28)
Minimize.Position = UDim2.new(1, -38, 0, 7)
Minimize.BackgroundColor3 = Theme.Element
Minimize.Text = "—"
Minimize.TextColor3 = Theme.Text
Minimize.Font = Enum.Font.GothamBold
Minimize.TextSize = 16
Minimize.Parent = Header

Instance.new("UICorner", Minimize).CornerRadius =
    UDim.new(0, 6)

-- NAVIGATION

local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Position = UDim2.fromOffset(8, 50)
Sidebar.Size = UDim2.new(1, -16, 0, 35)
Sidebar.BackgroundTransparency = 1
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 0
Sidebar.ScrollingDirection = Enum.ScrollingDirection.X
Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.X
Sidebar.Parent = Main

local NavLayout = Instance.new("UIListLayout")
NavLayout.FillDirection = Enum.FillDirection.Horizontal
NavLayout.Padding = UDim.new(0, 5)
NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
NavLayout.Parent = Sidebar

-- CONTENT

local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(8, 92)
Content.Size = UDim2.new(1, -16, 1, -100)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Tabs = {}
local Buttons = {}
local CurrentTab
local OpenPopup
local OutsideInputConnection

local function CloseAllPopups()
    if OpenPopup then
        OpenPopup:Destroy()
        OpenPopup = nil
    end
    if OutsideInputConnection then
        OutsideInputConnection:Disconnect()
        OutsideInputConnection = nil
    end
end

-- UTILITY

local function Create(class, properties, parent)

    local object = Instance.new(class)

    for key, value in pairs(properties or {}) do
        object[key] = value
    end

    object.Parent = parent

    return object

end

local function Corner(object, radius)

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = object

    return c

end

local function RefreshCanvas(page)

    local layout = page:FindFirstChildOfClass("UIListLayout")

    if layout then

        page.CanvasSize = UDim2.fromOffset(
            0,
            layout.AbsoluteContentSize.Y + 15
        )

    end

end

local function CreateRow(page, height)

    local holder = Create("Frame", {
        Size = UDim2.new(1, -4, 0, height),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0
    }, page)

    Corner(holder, 7)

    return holder

end

-- CREATE TAB

function GUI:CreateTab(name, order)

    if Tabs[name] then
        return Tabs[name]
    end

    local button = Create("TextButton", {
        Size = UDim2.fromOffset(100, 32),
        BackgroundColor3 = Theme.Element,
        Text = name,
        TextColor3 = Theme.SubText,
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        LayoutOrder = order or 1
    }, Sidebar)

    Corner(button, 6)

    local page = Create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new()
    }, Content)

    local layout = Create("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, page)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        RefreshCanvas(page)
    end)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.Parent = page

    Tabs[name] = page
    Buttons[name] = button

    button.MouseButton1Click:Connect(function()
        self:SetTab(name)
    end)

    if not CurrentTab then
        self:SetTab(name)
    end

    return page

end

-- SET TAB

function GUI:SetTab(name)

    if not Tabs[name] then
        return
    end

    CurrentTab = name
    CloseAllPopups()

    for tab, page in pairs(Tabs) do

        local active = tab == name

        page.Visible = active

        Buttons[tab].BackgroundColor3 =
            active and Theme.Accent or Theme.Element

        Buttons[tab].TextColor3 =
            active and Theme.Text or Theme.SubText

    end

end

-- SECTION

function GUI:AddSection(page, text)

    return Create("TextLabel", {
        Size = UDim2.new(1, -5, 0, 24),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        TextColor3 = Theme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, page)

end

-- LABEL

function GUI:AddLabel(page, text)

    return Create("TextLabel", {
        Size = UDim2.new(1, -5, 0, 30),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, page)

end

-- BUTTON

function GUI:AddButton(page, text, callback)

    local holder = CreateRow(page, 38)

    local button = Create("TextButton", {
        Position = UDim2.fromOffset(5, 4),
        Size = UDim2.new(1, -10, 1, -8),
        BackgroundColor3 = Theme.Accent,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 11
    }, holder)

    Corner(button)

    button.MouseButton1Click:Connect(function()

        if callback then
            callback()
        end

    end)

    return button

end

-- TOGGLE

function GUI:AddToggle(page, text, default, callback)

    local holder = CreateRow(page, 40)

    Create("TextLabel", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -80, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, holder)

    local value = default == true

    local button = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(48, 24),
        BackgroundColor3 = value and Theme.Success or Theme.Element,
        Text = value and "ON" or "OFF",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 10
    }, holder)

    Corner(button, 12)

    local function Set(v)

        value = v == true

        button.Text = value and "ON" or "OFF"

        button.BackgroundColor3 =
            value and Theme.Success or Theme.Element

        if callback then
            callback(value)
        end

    end

    button.MouseButton1Click:Connect(function()
        Set(not value)
    end)

    return {
        Set = Set,
        Get = function()
            return value
        end
    }

end

-- DROPDOWN

function GUI:AddDropdown(page, text, options, default, callback)

    local holder = CreateRow(page, 58)

    Create("TextLabel", {
        Position = UDim2.fromOffset(10, 2),
        Size = UDim2.new(1, -20, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, holder)

    local selected = default or options[1]

    local button = Create("TextButton", {
        Position = UDim2.fromOffset(8, 24),
        Size = UDim2.new(1, -16, 0, 27),
        BackgroundColor3 = Theme.Element,
        Text = tostring(selected or "Select") .. "  ▼",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 10
    }, holder)

    Corner(button)

    local popup

    local function ClosePopup()
        if popup then
            if OpenPopup == popup then OpenPopup = nil end
            popup:Destroy()
            popup = nil
        end
        if OutsideInputConnection then
            OutsideInputConnection:Disconnect()
            OutsideInputConnection = nil
        end
    end

    local function SetOptions(newOptions)

        options = newOptions or {}

        if not table.find(options, selected) then
            selected = options[1]
        end

        button.Text = tostring(selected or "Select") .. "  ▼"

    end

    button.MouseButton1Click:Connect(function()

        CloseAllPopups()

        if #options == 0 then
            return
        end

        popup = Create("Frame", {
            Size = UDim2.fromOffset(190, math.min(#options * 30, 180)),
            Position = UDim2.fromOffset(
                0,
                0
            ),
            BackgroundColor3 = Theme.Secondary,
            BorderSizePixel = 0,
            ZIndex = 20
        }, Screen)

        local absolute = button.AbsolutePosition

        popup.Position = UDim2.fromOffset(
            math.clamp(absolute.X, 0, Screen.AbsoluteSize.X - 195),
            math.clamp(absolute.Y + 30, 0, Screen.AbsoluteSize.Y - 190)
        )

        Corner(popup)
        OpenPopup = popup
        OutsideInputConnection = UIS.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if not popup or not popup.Parent then return end
            local p = input.Position
            local a, z = popup.AbsolutePosition, popup.AbsoluteSize
            local inside = p.X >= a.X and p.X <= a.X + z.X
                and p.Y >= a.Y and p.Y <= a.Y + z.Y
            if not inside then ClosePopup() end
        end)

        local list = Create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            CanvasSize = UDim2.fromOffset(0, #options * 31),
            ZIndex = 21
        }, popup)

        local layout = Create("UIListLayout", {
            Padding = UDim.new(0, 2)
        }, list)

        for _, option in ipairs(options) do

            local item = Create("TextButton", {
                Size = UDim2.new(1, -6, 0, 29),
                BackgroundColor3 = Theme.Element,
                Text = tostring(option),
                TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                ZIndex = 22
            }, list)

            item.MouseButton1Click:Connect(function()

                selected = option

                button.Text = tostring(selected) .. "  ▼"

                ClosePopup()

                if callback then
                    callback(selected)
                end

            end)

        end

    end)

    return {
        SetOptions = SetOptions,

        Set = function(_, value)

            if table.find(options, value) then

                selected = value

                button.Text = tostring(selected) .. "  ▼"

                if callback then
                    callback(selected)
                end

            end

        end,

        Get = function()
            return selected
        end
    }

end

-- SLIDER

function GUI:AddSlider(page, text, min, max, default, callback, step)

    local holder = CreateRow(page, 58)

    local label = Create("TextLabel", {
        Position = UDim2.fromOffset(10, 2),
        Size = UDim2.new(1, -20, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, holder)

    local bar = Create("Frame", {
        Position = UDim2.fromOffset(10, 35),
        Size = UDim2.new(1, -20, 0, 7),
        BackgroundColor3 = Theme.Element
    }, holder)

    Corner(bar, 5)

    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent
    }, bar)

    Corner(fill, 5)

    local value = default or min
    local dragging = false

    local function Set(v)

        step = tonumber(step) or 1
        step = math.max(step, 0.001)
        value = math.clamp(
            min + math.floor(((tonumber(v) or min) - min) / step + 0.5) * step,
            min,
            max
        )

        local alpha = (value - min) / (max - min)

        fill.Size = UDim2.new(alpha, 0, 1, 0)

        label.Text = text .. " : " .. (step < 1 and string.format("%.2f", value) or tostring(math.floor(value + 0.5)))

        if callback then
            callback(value)
        end

    end

    local function Update(input)

        local alpha = math.clamp(
            (input.Position.X - bar.AbsolutePosition.X)
            / bar.AbsoluteSize.X,
            0,
            1
        )

        Set(min + alpha * (max - min))

    end

    bar.InputBegan:Connect(function(input)

        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            Update(input)

        end

    end)

    UIS.InputChanged:Connect(function(input)

        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then

            Update(input)

        end

    end)

    UIS.InputEnded:Connect(function(input)

        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

            dragging = false

        end

    end)

    Set(value)

    return {
        Set = Set,
        Get = function()
            return value
        end
    }

end

-- NOTIFICATION

function GUI:Notify(message, duration)

    local note = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.fromOffset(230, 40),
        BackgroundColor3 = Theme.Secondary,
        Text = tostring(message),
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        TextWrapped = true,
        ZIndex = 50
    }, Screen)

    Corner(note)

    task.delay(duration or 3, function()

        if note then
            note:Destroy()
        end

    end)

end

-- DRAGGING

local dragging = false
local dragStart
local startPosition

Header.InputBegan:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = Main.Position

    end

end)

UIS.InputChanged:Connect(function(input)

    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then

        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )

    end

end)

UIS.InputEnded:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false

    end

end)

-- MINIMIZE

local minimized = false

Minimize.MouseButton1Click:Connect(function()

    minimized = not minimized

    Sidebar.Visible = not minimized
    Content.Visible = not minimized

    local targetSize = minimized
        and UDim2.fromOffset(210, 42)
        or UDim2.fromOffset(340, 320)

    TweenService:Create(
        Main,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {Size = targetSize}
    ):Play()

    Minimize.Text = minimized and "+" or "—"

end)

-- DESTROY

function GUI:Destroy()

    CloseAllPopups()

    if Screen then
        Screen:Destroy()
    end

end

return GUI