--[[
    BUG EVOLUTION
    Bug Scanner Module

    Responsibilities:
    - Detect bugs inside the configured folder
    - Identify bug species from model names
    - Identify bug size from model names
    - Get bug distance from player
    - Sort bugs by selected priority
    - Provide data for Farming and ESP
]]

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Scanner = {}
Scanner.__index = Scanner

--==================================================
-- SIZE CONFIGURATION
--==================================================

local SIZE_RANK = {
    Tiny = 1,
    Small = 2,
    Normal = 3,
    Large = 4,
    Huge = 5,
    Giant = 6,
    Massive = 7,
}

local SIZE_NAMES = {
    "Tiny",
    "Small",
    "Normal",
    "Large",
    "Huge",
    "Giant",
    "Massive",
}

local DEFAULT_SIZE = "Normal"

--==================================================
-- HELPER FUNCTIONS
--==================================================

local function GetPlayerRoot()
    local character = LocalPlayer.Character

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function GetModelRoot(model)
    if not model then
        return nil
    end

    if model:IsA("BasePart") then
        return model
    end

    if model:IsA("Model") then

        if model.PrimaryPart then
            return model.PrimaryPart
        end

        local humanoidRoot =
            model:FindFirstChild("HumanoidRootPart", true)

        if humanoidRoot and humanoidRoot:IsA("BasePart") then
            return humanoidRoot
        end

        local rootPart =
            model:FindFirstChild("RootPart", true)

        if rootPart and rootPart:IsA("BasePart") then
            return rootPart
        end

        for _, descendant in ipairs(model:GetDescendants()) do

            if descendant:IsA("BasePart") then
                return descendant
            end

        end
    end

    return nil
end

--==================================================
-- NAME PARSER
--==================================================

local function ParseBugName(modelName)

    local words = {}

    for word in string.gmatch(modelName, "%S+") do
        table.insert(words, word)
    end

    local detectedSize = DEFAULT_SIZE
    local speciesWords = {}

    local foundSize = false

    for _, word in ipairs(words) do

        local normalized =
            string.lower(word)

        local matchedSize = nil

        for sizeName, _ in pairs(SIZE_RANK) do

            if normalized == string.lower(sizeName) then
                matchedSize = sizeName
                break
            end

        end

        if matchedSize and not foundSize then

            detectedSize = matchedSize
            foundSize = true

        else

            table.insert(speciesWords, word)

        end

    end

    local species = table.concat(speciesWords, " ")

    if species == "" then
        species = modelName
    end

    return {
        Name = modelName,
        Species = species,
        Size = detectedSize,
        SizeRank = SIZE_RANK[detectedSize] or 3,
    }

end

--==================================================
-- DISTANCE
--==================================================

local function GetDistance(model)

    local playerRoot = GetPlayerRoot()
    local bugRoot = GetModelRoot(model)

    if not playerRoot or not bugRoot then
        return math.huge
    end

    return (playerRoot.Position - bugRoot.Position).Magnitude

end

--==================================================
-- CONSTRUCTOR
--==================================================

function Scanner.new(settings)

    local self = setmetatable({}, Scanner)

    self.Settings = settings or {}

    self.BugFolder = nil
    self.Bugs = {}
    self.Species = {}

    self.LastScan = 0

    self.RandomTarget = nil
    self.RandomTargetTime = 0

    self.RandomRefreshInterval = 2
    self.RandomDistanceBand = 25

    self:FindFolder()

    return self

end

--==================================================
-- FIND BUG FOLDER
--==================================================

function Scanner:FindFolder()

    local folderName =
        self.Settings.BugFolderName or "Bugs"

    local configuredFolder =
        self.Settings.BugFolder

    if typeof(configuredFolder) == "Instance"
        and configuredFolder.Parent then

        self.BugFolder = configuredFolder
        return self.BugFolder

    end

    self.BugFolder =
        workspace:FindFirstChild(folderName)

    return self.BugFolder

end

--==================================================
-- GET BUG FOLDER
--==================================================

function Scanner:GetFolder()

    if self.BugFolder and self.BugFolder.Parent then
        return self.BugFolder
    end

    return self:FindFolder()

end

--==================================================
-- CHECK VALID BUG
--==================================================

function Scanner:IsValidBug(model)

    if not model then
        return false
    end

    if not (model:IsA("Model") or model:IsA("BasePart")) then
        return false
    end

    if not GetModelRoot(model) then
        return false
    end

    if not model:IsDescendantOf(self:GetFolder()) then
        return false
    end

    return true

end

--==================================================
-- SCAN BUGS
--==================================================

function Scanner:Refresh()

    local folder = self:GetFolder()

    if not folder then

        self.Bugs = {}
        self.Species = {}

        warn(
            "[Bug Evolution] Bug folder not found: "
            .. tostring(self.Settings.BugFolderName)
        )

        return false

    end

    local detectedBugs = {}
    local detectedSpecies = {}

    for _, model in ipairs(folder:GetChildren()) do

        if self:IsValidBug(model) then

            local info = ParseBugName(model.Name)

            local bugData = {
                Instance = model,

                Name = info.Name,
                Species = info.Species,

                Size = info.Size,
                SizeRank = info.SizeRank,

                Root = GetModelRoot(model),
                Distance = GetDistance(model),
            }

            table.insert(detectedBugs, bugData)

            detectedSpecies[info.Species] = true

        end

    end

    local speciesList = {}

    for speciesName in pairs(detectedSpecies) do
        table.insert(speciesList, speciesName)
    end

    table.sort(speciesList)

    self.Bugs = detectedBugs
    self.Species = speciesList

    self.LastScan = os.clock()

    return true

end

--==================================================
-- GET SPECIES
--==================================================

function Scanner:GetSpecies()

    if os.clock() - self.LastScan >= 1 then
        self:Refresh()
    end

    return self.Species

end

--==================================================
-- GET ALL BUGS
--==================================================

function Scanner:GetBugs()

    if os.clock() - self.LastScan >= 1 then
        self:Refresh()
    end

    local result = {}

    for _, bug in ipairs(self.Bugs) do

        if bug.Instance and bug.Instance.Parent then
            table.insert(result, bug)
        end

    end

    return result

end

--==================================================
-- GET BUGS BY SPECIES
--==================================================

function Scanner:GetBugsBySpecies(species)

    local result = {}

    for _, bug in ipairs(self:GetBugs()) do

        if species == "All Bugs"
            or bug.Species == species then

            table.insert(result, bug)

        end

    end

    return result

end

--==================================================
-- UPDATE DISTANCES
--==================================================

function Scanner:UpdateDistances(bugs)

    for _, bug in ipairs(bugs) do

        if bug.Instance and bug.Instance.Parent then

            bug.Root = GetModelRoot(bug.Instance)
            bug.Distance = GetDistance(bug.Instance)

        else

            bug.Distance = math.huge

        end

    end

    return bugs

end

--==================================================
-- SORTING
--==================================================

function Scanner:SortBugs(bugs, priority)

    priority = priority
        or self.Settings.SizePriority
        or "Largest First"

    self:UpdateDistances(bugs)

    if priority == "Largest First" then

        table.sort(bugs, function(a, b)

            if a.SizeRank == b.SizeRank then
                return a.Distance < b.Distance
            end

            return a.SizeRank > b.SizeRank

        end)

    elseif priority == "Smallest First" then

        table.sort(bugs, function(a, b)

            if a.SizeRank == b.SizeRank then
                return a.Distance < b.Distance
            end

            return a.SizeRank < b.SizeRank

        end)

    elseif priority == "Nearest First" then

        table.sort(bugs, function(a, b)

            return a.Distance < b.Distance

        end)

    elseif priority == "Random Size (Nearest)" then

        table.sort(bugs, function(a, b)

            return a.Distance < b.Distance

        end)

        local nearest = bugs[1]

        if not nearest then
            return bugs
        end

        local candidates = {}

        for _, bug in ipairs(bugs) do

            if bug.Distance <=
                nearest.Distance + self.RandomDistanceBand then

                table.insert(candidates, bug)

            end

        end

        if #candidates > 0 then

            if not self.RandomTarget
                or not self.RandomTarget.Instance
                or not self.RandomTarget.Instance.Parent
                or os.clock() - self.RandomTargetTime
                    >= self.RandomRefreshInterval then

                self.RandomTarget =
                    candidates[math.random(1, #candidates)]

                self.RandomTargetTime = os.clock()

            end

            local selected = self.RandomTarget

            table.sort(bugs, function(a, b)

                if a.Instance == selected.Instance then
                    return true
                end

                if b.Instance == selected.Instance then
                    return false
                end

                return a.Distance < b.Distance

            end)

        end

    end

    return bugs

end

--==================================================
-- GET SORTED BUGS
--==================================================

function Scanner:GetSortedBugs(species, priority)

    local bugs = self:GetBugsBySpecies(
        species or self.Settings.SelectedSpecies or "All Bugs"
    )

    return self:SortBugs(
        bugs,
        priority
    )

end

--==================================================
-- GET SIZE INFORMATION
--==================================================

function Scanner:GetSizeInfo(model)

    if not model then
        return nil
    end

    return ParseBugName(model.Name)

end

--==================================================
-- GET BUG ROOT
--==================================================

function Scanner:GetRoot(model)

    return GetModelRoot(model)

end

--==================================================
-- GET DISTANCE TO BUG
--==================================================

function Scanner:GetDistance(model)

    return GetDistance(model)

end

--==================================================
-- ESP SIZE FILTER
--==================================================

function Scanner:MatchesSizeFilter(model, filter)

    local info = self:GetSizeInfo(model)

    if not info then
        return false
    end

    filter = filter or "Normal"

    -- Normal means ALL sizes.
    if filter == "Normal" then
        return true
    end

    if filter == "Massive" then
        return info.SizeRank == SIZE_RANK.Massive
    end

    local minimumRank = SIZE_RANK[filter]

    if not minimumRank then
        return true
    end

    return info.SizeRank >= minimumRank

end

--==================================================
-- EXPORT SIZE RANK
--==================================================

Scanner.SizeRank = SIZE_RANK
Scanner.SizeNames = SIZE_NAMES

return Scanner