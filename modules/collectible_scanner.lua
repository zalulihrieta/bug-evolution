--[[
    BUG EVOLUTION
    Collectible Scanner

    Supported:
    - Orb
    - Breakable
    - VoidOrb

    Orb:
    Highest XP first.

    Breakable:
    Random target from nearest group.

    VoidOrb:
    Random target.
]]

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Scanner = {}
Scanner.__index = Scanner

--==================================================
-- CONFIGURATION
--==================================================

local FOLDERS = {
    Orb = "Orbs",
    Breakable = "Breakables",
    VoidOrb = "VoidOrbs",
}

--==================================================
-- HELPER
--==================================================

local function GetPlayerRoot()

    local character = LocalPlayer.Character

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")

end

local function GetRoot(object)

    if object:IsA("BasePart") then
        return object
    end

    if object:IsA("Model") then

        if object.PrimaryPart then
            return object.PrimaryPart
        end

        local root = object:FindFirstChild(
            "HumanoidRootPart",
            true
        )

        if root and root:IsA("BasePart") then
            return root
        end

        for _, item in ipairs(object:GetDescendants()) do

            if item:IsA("BasePart") then
                return item
            end

        end

    end

    return nil

end

local function GetDistance(object)

    local playerRoot = GetPlayerRoot()
    local objectRoot = GetRoot(object)

    if not playerRoot or not objectRoot then
        return math.huge
    end

    return (
        playerRoot.Position - objectRoot.Position
    ).Magnitude

end

--==================================================
-- CONSTRUCTOR
--==================================================

function Scanner.new(settings)

    local self = setmetatable({}, Scanner)

    self.Settings = settings or {}

    self.Folders = {}
    self.Targets = {}

    self.RandomTarget = {}

    self:RefreshFolders()

    return self

end

--==================================================
-- FIND FOLDERS
--==================================================

function Scanner:RefreshFolders()

    for mode, folderName in pairs(FOLDERS) do

        self.Folders[mode] =
            workspace:FindFirstChild(folderName)

    end

end

function Scanner:GetFolder(mode)

    local folder = self.Folders[mode]

    if folder and folder.Parent then
        return folder
    end

    self:RefreshFolders()

    return self.Folders[mode]

end

--==================================================
-- SCAN
--==================================================

function Scanner:Scan(mode)

    local folder = self:GetFolder(mode)

    if not folder then

        warn(
            "[Bug Evolution] Folder not found: "
            .. tostring(FOLDERS[mode])
        )

        return {}

    end

    local results = {}

    for _, object in ipairs(folder:GetChildren()) do

        local root = GetRoot(object)

        if root then

            local xp = object:GetAttribute("XP")

            if typeof(xp) ~= "number" then
                xp = 0
            end

            table.insert(results, {

                Instance = object,
                Root = root,

                Name = object.Name,

                XP = xp,

                Distance = GetDistance(object),

            })

        end

    end

    self.Targets[mode] = results

    return results

end

--==================================================
-- ORB: HIGHEST XP FIRST
--==================================================

function Scanner:GetOrbTargets()

    local results = self:Scan("Orb")

    table.sort(results, function(a, b)

        if a.XP == b.XP then
            return a.Distance < b.Distance
        end

        return a.XP > b.XP

    end)

    return results

end

--==================================================
-- BREAKABLE: RANDOM NEAREST
--==================================================

function Scanner:GetBreakableTarget()

    local results = self:Scan("Breakable")

    if #results == 0 then
        return nil
    end

    table.sort(results, function(a, b)

        return a.Distance < b.Distance

    end)

    local nearest = results[1]

    local candidates = {}

    -- Random selection within 25 studs
    -- of the nearest breakable.

    for _, target in ipairs(results) do

        if target.Distance <= nearest.Distance + 25 then

            table.insert(candidates, target)

        end

    end

    if #candidates == 0 then
        return nearest
    end

    return candidates[math.random(1, #candidates)]

end

--==================================================
-- VOIDORB: RANDOM
--==================================================

function Scanner:GetVoidOrbTarget()

    local results = self:Scan("VoidOrb")

    if #results == 0 then
        return nil
    end

    return results[math.random(1, #results)]

end

--==================================================
-- GET TARGET
--==================================================

function Scanner:GetTarget(mode)

    if mode == "Orb" then

        local results = self:GetOrbTargets()

        return results[1]

    elseif mode == "Breakable" then

        return self:GetBreakableTarget()

    elseif mode == "VoidOrb" then

        return self:GetVoidOrbTarget()

    end

    return nil

end

--==================================================
-- EXPORT
--==================================================

Scanner.FolderNames = FOLDERS

return Scanner