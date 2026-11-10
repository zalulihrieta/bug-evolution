--[[
    BUG EVOLUTION
    Bug ESP Module

    Features:
    - Bug Highlight
    - Bug Name
    - Bug Size
    - Distance Display
    - Size Filtering
    - Maximum ESP Distance
    - Automatic Refresh
    - Automatic Cleanup
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local ESP = {}
ESP.__index = ESP

--==================================================
-- CONFIGURATION
--==================================================

local UPDATE_INTERVAL = 0.25

local DEFAULT_SETTINGS = {
    ESPEnabled = false,
    ESPFilter = "Normal",
    ESPMaxDistance = 1000,
}

--==================================================
-- COLORS
--==================================================

local COLORS = {
    Normal = Color3.fromRGB(100, 200, 255),
    Tiny = Color3.fromRGB(150, 150, 255),
    Small = Color3.fromRGB(100, 255, 150),
    Large = Color3.fromRGB(255, 220, 100),
    Huge = Color3.fromRGB(255, 150, 50),
    Giant = Color3.fromRGB(255, 100, 100),
    Massive = Color3.fromRGB(255, 50, 200),
}

--==================================================
-- CONSTRUCTOR
--==================================================

function ESP.new(options)

    local self = setmetatable({}, ESP)

    self.Settings = options.Settings or {}
    self.Scanner = options.Scanner

    self.Enabled = false
    self.Destroyed = false

    self.Objects = {}

    self.Connection = nil
    self.LastUpdate = 0

    self.Folder = Instance.new("Folder")
    self.Folder.Name = "BugEvolutionESP"

    local success, result = pcall(function()
        return gethui()
    end)

    if success and result then
        self.Folder.Parent = result
    else
        self.Folder.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    return self

end

--==================================================
-- GET COLOR
--==================================================

function ESP:GetColor(size)

    return COLORS[size] or COLORS.Normal

end

--==================================================
-- GET ESP ROOT
--==================================================

function ESP:GetRoot(model)

    if not model then
        return nil
    end

    return self.Scanner:GetRoot(model)

end

--==================================================
-- CREATE HIGHLIGHT
--==================================================

function ESP:CreateHighlight(model, color)

    local highlight = Instance.new("Highlight")

    highlight.Name = "BugHighlight"

    highlight.Adornee = model

    highlight.FillColor = color
    highlight.OutlineColor = color

    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0

    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    highlight.Parent = self.Folder

    return highlight

end

--==================================================
-- CREATE BILLBOARD
--==================================================

function ESP:CreateBillboard(root)

    local billboard = Instance.new("BillboardGui")

    billboard.Name = "BugInformation"

    billboard.Adornee = root

    billboard.Size = UDim2.fromOffset(160, 48)

    billboard.StudsOffset = Vector3.new(0, 3, 0)

    billboard.AlwaysOnTop = true

    billboard.MaxDistance = 0

    billboard.Parent = self.Folder

    -- Main container

    local container = Instance.new("Frame")

    container.Name = "Container"

    container.Size = UDim2.fromScale(1, 1)

    container.BackgroundColor3 =
        Color3.fromRGB(20, 20, 25)

    container.BackgroundTransparency = 0.2

    container.BorderSizePixel = 0

    container.Parent = billboard

    local corner = Instance.new("UICorner")

    corner.CornerRadius = UDim.new(0, 6)

    corner.Parent = container

    -- Bug name

    local nameLabel = Instance.new("TextLabel")

    nameLabel.Name = "BugName"

    nameLabel.Size = UDim2.new(1, -8, 0, 22)

    nameLabel.Position = UDim2.fromOffset(4, 2)

    nameLabel.BackgroundTransparency = 1

    nameLabel.Font = Enum.Font.GothamBold

    nameLabel.TextSize = 12

    nameLabel.TextColor3 = Color3.new(1, 1, 1)

    nameLabel.Text = "Unknown Bug"

    nameLabel.TextXAlignment = Enum.TextXAlignment.Center

    nameLabel.Parent = container

    -- Distance

    local distanceLabel = Instance.new("TextLabel")

    distanceLabel.Name = "Distance"

    distanceLabel.Size = UDim2.new(1, -8, 0, 17)

    distanceLabel.Position = UDim2.fromOffset(4, 25)

    distanceLabel.BackgroundTransparency = 1

    distanceLabel.Font = Enum.Font.Gotham

    distanceLabel.TextSize = 10

    distanceLabel.TextColor3 =
        Color3.fromRGB(200, 200, 200)

    distanceLabel.Text = "0 studs"

    distanceLabel.Parent = container

    return billboard

end

--==================================================
-- CREATE ESP OBJECT
--==================================================

function ESP:Create(model, bugInfo)

    if self.Objects[model] then
        return self.Objects[model]
    end

    local root = self:GetRoot(model)

    if not root then
        return nil
    end

    local color = self:GetColor(bugInfo.Size)

    local highlight = self:CreateHighlight(
        model,
        color
    )

    local billboard = self:CreateBillboard(root)

    local object = {
        Model = model,
        Root = root,

        Highlight = highlight,
        Billboard = billboard,

    }

    self.Objects[model] = object

    return object

end

--==================================================
-- UPDATE ESP TEXT
--==================================================

function ESP:UpdateObject(object, bugInfo)

    if not object then
        return
    end

    local model = object.Model

    if not model or not model.Parent then
        return
    end

    local root = self:GetRoot(model)

    if not root then
        return
    end

    object.Root = root

    object.Billboard.Adornee = root

    local container =
        object.Billboard:FindFirstChild("Container")

    if not container then
        return
    end

    local nameLabel =
        container:FindFirstChild("BugName")

    local distanceLabel =
        container:FindFirstChild("Distance")

    local color = self:GetColor(bugInfo.Size)

    if nameLabel then

        nameLabel.Text =
            bugInfo.Name .. " [" .. bugInfo.Size .. "]"

        nameLabel.TextColor3 = color

    end

    if distanceLabel then

        distanceLabel.Text = string.format(
            "%.0f studs",
            bugInfo.Distance
        )

    end

    object.Highlight.FillColor = color
    object.Highlight.OutlineColor = color

end

--==================================================
-- REMOVE ESP
--==================================================

function ESP:Remove(model)

    local object = self.Objects[model]

    if not object then
        return
    end

    if object.Highlight then
        object.Highlight:Destroy()
    end

    if object.Billboard then
        object.Billboard:Destroy()
    end

    self.Objects[model] = nil

end

--==================================================
-- CLEAR ALL
--==================================================

function ESP:Clear()

    for model in pairs(self.Objects) do
        self:Remove(model)
    end

end

--==================================================
-- REFRESH
--==================================================

function ESP:Refresh()

    if not self.Enabled then
        return
    end

    local bugs = self.Scanner:GetBugs()

    local activeModels = {}

    local maxDistance =
        tonumber(self.Settings.ESPMaxDistance)
        or DEFAULT_SETTINGS.ESPMaxDistance

    local filter =
        self.Settings.ESPFilter or "All Sizes"
    local speciesFilter = self.Settings.ESPSpecies or "All Bugs"

    for _, bug in ipairs(bugs) do

        local model = bug.Instance

        if model and model.Parent then

            local distance =
                self.Scanner:GetDistance(model)

            local matchesFilter =
                self.Scanner:MatchesSizeFilter(model, filter)
            local matchesSpecies =
                speciesFilter == "All Bugs" or bug.Species == speciesFilter

            if matchesFilter and matchesSpecies and distance <= maxDistance then

                activeModels[model] = true

                local object = self.Objects[model]

                if not object then

                    object = self:Create(
                        model,
                        bug
                    )

                end

                if object then

                    bug.Distance = distance

                    self:UpdateObject(
                        object,
                        bug
                    )

                end

            end

        end

    end

    -- Remove stale ESP objects.

    for model in pairs(self.Objects) do

        if not activeModels[model] then

            self:Remove(model)

        end

    end

end

--==================================================
-- UPDATE LOOP
--==================================================

function ESP:StartLoop()

    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function()

        if not self.Enabled then
            return
        end

        if os.clock() - self.LastUpdate < UPDATE_INTERVAL then
            return
        end

        self.LastUpdate = os.clock()

        local success, err = pcall(function()

            self:Refresh()

        end)

        if not success then

            warn(
                "[Bug Evolution] ESP Error: "
                .. tostring(err)
            )

        end

    end)

end

--==================================================
-- ENABLE
--==================================================

function ESP:Enable()

    if self.Destroyed then
        return false
    end

    if self.Enabled then
        return false
    end

    self.Enabled = true

    self.Settings.ESPEnabled = true

    self:StartLoop()

    self:Refresh()

    print("[Bug Evolution] ESP Enabled")

    return true

end

--==================================================
-- DISABLE
--==================================================

function ESP:Disable()

    self.Enabled = false

    self.Settings.ESPEnabled = false

    self:Clear()

    print("[Bug Evolution] ESP Disabled")

end

--==================================================
-- TOGGLE
--==================================================

function ESP:Toggle()

    if self.Enabled then

        self:Disable()

        return false

    else

        self:Enable()

        return true

    end

end

--==================================================
-- DESTROY
--==================================================

function ESP:Destroy()

    self:Disable()

    if self.Connection then

        self.Connection:Disconnect()

        self.Connection = nil

    end

    if self.Folder then
        self.Folder:Destroy()
    end

    self.Destroyed = true

end

return ESP