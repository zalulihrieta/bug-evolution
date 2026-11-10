--[[
 BUG EVOLUTION v1.3.0
 Main controller: Farm Options, Bug Farm, Breakable, Orb, ESP.
]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    BugFolderName = "Bugs",
    SelectedSpecies = "All Bugs",
    BugSizeFilter = "All Sizes",
    SizePriority = "Largest First",
    ScanInterval = 1,

    MovementMode = "Tween",
    AttackDistance = 2,
    TeleportDelay = 0.2,
    TweenSpeed = 150,

    FarmEnabled = false,
    CollectibleEnabled = false,
    CollectibleMode = "Orb",
    SelectedBreakable = "All",

    ESPEnabled = false,
    ESPFilter = "All Sizes",
    ESPSpecies = "All Bugs",
    ESPMaxDistance = 1000,
}

local BASE_URL = "https://raw.githubusercontent.com/zalulihrieta/bug-evolution/main/"
local function LoadModule(path)
    local ok, result = pcall(function()
        local source = game:HttpGet(BASE_URL .. path .. "?v=1.3.0")
        assert(type(source) == "string" and #source > 0, "Empty source: " .. path)
        local compiled, err = loadstring(source)
        assert(compiled, err or "Compile failed")
        return compiled()
    end)
    if not ok then error("[Bug Evolution] Module error " .. path .. ": " .. tostring(result)) end
    return result
end

local GUI = LoadModule("gui.lua")
local Scanner = LoadModule("modules/scanner.lua")
local Movement = LoadModule("modules/movement.lua")
local Farming = LoadModule("modules/farming.lua")
local CollectibleScanner = LoadModule("modules/collectible_scanner.lua")
local CollectibleFarming = LoadModule("modules/collectible_farming.lua")
local ESP = LoadModule("modules/esp.lua")

local Window = GUI
local FarmOptionsTab = Window:CreateTab("Farm Options", 1)
local BugTab = Window:CreateTab("Bug Farm", 2)
local BreakableTab = Window:CreateTab("Breakable", 3)
local OrbTab = Window:CreateTab("Orb", 4)
local ESPTab = Window:CreateTab("ESP", 5)

local BugScanner = Scanner.new(CONFIG)
local MovementController = Movement.new(CONFIG)
local CollectibleScannerController = CollectibleScanner.new(CONFIG)

local BugStatus, BugTarget = "Stopped", "None"
local CollectibleStatus, CollectibleTarget = "Stopped", "None"
local Destroyed, Syncing = false, false
local BugToggle, BreakableToggle, OrbToggle, ESPToggle
local SpeciesDropdown, ESPspeciesDropdown, BreakableDropdown

local function Notify(message, duration)
    Window:Notify(tostring(message), duration or 3)
end

local function SafeCall(label, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        warn("[Bug Evolution] " .. label .. "\n" .. tostring(err))
        Notify(label .. " failed. Check executor console.", 5)
    end
    return ok
end

local function TargetName(target)
    if not target then return "None" end
    if type(target) == "table" then
        if target.Name then return tostring(target.Name) end
        if target.Instance then return target.Instance.Name end
    end
    if typeof(target) == "Instance" then return target.Name end
    return tostring(target)
end

local function SetToggleVisual(toggle, value)
    if not toggle then return end
    Syncing = true
    pcall(function() toggle.Set(value) end)
    Syncing = false
end

local BugFarm = Farming.new({
    Settings = CONFIG,
    Scanner = BugScanner,
    Movement = MovementController,
    OnStatusChanged = function(status, target)
        BugStatus = tostring(status)
        if target then BugTarget = TargetName(target) end
        if BugStatus == "Stopped" or BugStatus == "Idle" then BugTarget = "None" end
    end,
})

local CollectibleFarm = CollectibleFarming.new({
    Settings = CONFIG,
    Scanner = CollectibleScannerController,
    Movement = MovementController,
    OnStatusChanged = function(status)
        CollectibleStatus = tostring(status)
        if status == "Stopped" or status == "Idle" then CollectibleTarget = "None" end
    end,
})

local ESPController = ESP.new({Settings = CONFIG, Scanner = BugScanner})

local function StopBugFarm()
    CONFIG.FarmEnabled = false
    BugFarm:Stop()
    BugStatus, BugTarget = "Stopped", "None"
end

local function StopCollectibleFarm()
    CONFIG.CollectibleEnabled = false
    CollectibleFarm:Stop()
    CollectibleStatus, CollectibleTarget = "Stopped", "None"
end

local function StartBugFarm()
    StopCollectibleFarm()
    SetToggleVisual(BreakableToggle, false)
    SetToggleVisual(OrbToggle, false)
    CONFIG.FarmEnabled = true
    BugFarm:Start()
    Notify("Bug Farming ON")
end

local function StartCollectibleFarm(mode)
    StopBugFarm()
    SetToggleVisual(BugToggle, false)
    CONFIG.CollectibleMode = mode
    CONFIG.CollectibleEnabled = true
    CollectibleFarm:Start(mode)
    Notify(mode .. " Farming ON")
end

-- FARM OPTIONS: movement controls shared by all farm types.
Window:AddSection(FarmOptionsTab, "Movement")
Window:AddDropdown(FarmOptionsTab, "Movement Method", {"Teleport", "Tween"}, CONFIG.MovementMode, function(v)
    CONFIG.MovementMode = v
end)
Window:AddSlider(FarmOptionsTab, "Teleport Delay", 0, 3, CONFIG.TeleportDelay, function(v)
    CONFIG.TeleportDelay = v
end, 0.05)
Window:AddSlider(FarmOptionsTab, "Tween Speed", 50, 500, CONFIG.TweenSpeed, function(v)
    CONFIG.TweenSpeed = v
end)
Window:AddSlider(FarmOptionsTab, "Attack Distance", 2, 20, CONFIG.AttackDistance, function(v)
    CONFIG.AttackDistance = v
end)
Window:AddLabel(FarmOptionsTab, "Movement settings apply to Bug and Breakable farming.")

-- BUG FARM
Window:AddSection(BugTab, "Bug Farming")
local BugStatusLabel = Window:AddLabel(BugTab, "Status: Stopped")
local BugTargetLabel = Window:AddLabel(BugTab, "Target: None")
BugToggle = Window:AddToggle(BugTab, "Enable Bug Farming", false, function(enabled)
    if Syncing then return end
    SafeCall("Bug Farming", function()
        if enabled then StartBugFarm() else StopBugFarm() end
    end)
end)
Window:AddDropdown(BugTab, "Bug Value / Size", {"All Sizes", "Large", "Small", "Normal (Random)"}, CONFIG.BugSizeFilter, function(v)
    CONFIG.BugSizeFilter = v
end)
Window:AddDropdown(BugTab, "Bug Species", {"All Bugs"}, CONFIG.SelectedSpecies, function(v)
    CONFIG.SelectedSpecies = v
end)
Window:AddDropdown(BugTab, "Target Priority", {"Largest First", "Smallest First", "Nearest First", "Random Size (Nearest)"}, CONFIG.SizePriority, function(v)
    CONFIG.SizePriority = v
end)

-- BREAKABLE FARM
Window:AddSection(BreakableTab, "Breakable Farming")
local BreakableStatusLabel = Window:AddLabel(BreakableTab, "Status: Stopped")
local BreakableTargetLabel = Window:AddLabel(BreakableTab, "Target: None")
BreakableToggle = Window:AddToggle(BreakableTab, "Enable Breakable Farming", false, function(enabled)
    if Syncing then return end
    SafeCall("Breakable Farming", function()
        if enabled then StartCollectibleFarm("Breakable") else StopCollectibleFarm() end
    end)
end)
Window:AddDropdown(BreakableTab, "Breakable Type", {"All"}, CONFIG.SelectedBreakable, function(v)
    CONFIG.SelectedBreakable = v
end)
BreakableDropdown = nil
Window:AddButton(BreakableTab, "Refresh Breakable Types", function()
    local options = CollectibleScannerController:GetBreakableNames()
    if BreakableDropdown then BreakableDropdown.SetOptions(options) end
    Notify(tostring(math.max(#options - 1, 0)) .. " breakable types found")
end)
Window:AddLabel(BreakableTab, "The character moves above the selected breakable. The game's own attack system handles breaking.")

-- replace the initial dropdown handle with a live options-capable control
-- (kept separate so the refresh button can update names discovered in-game)
BreakableDropdown = Window:AddDropdown(BreakableTab, "Select Breakable", {"All"}, CONFIG.SelectedBreakable, function(v)
    CONFIG.SelectedBreakable = v
end)

-- ORB FARM
Window:AddSection(OrbTab, "Orb Farming")
local OrbStatusLabel = Window:AddLabel(OrbTab, "Status: Stopped")
local OrbTargetLabel = Window:AddLabel(OrbTab, "Target: None")
local VoidOrbCountLabel = Window:AddLabel(OrbTab, "VoidOrbs Available: 0")
OrbToggle = Window:AddToggle(OrbTab, "Enable Orb Farming", false, function(enabled)
    if Syncing then return end
    SafeCall("Orb Farming", function()
        if enabled then StartCollectibleFarm(CONFIG.CollectibleMode) else StopCollectibleFarm() end
    end)
end)
Window:AddDropdown(OrbTab, "Orb Type", {"Orb", "VoidOrb"}, CONFIG.CollectibleMode, function(v)
    CONFIG.CollectibleMode = v
    if CONFIG.CollectibleEnabled then
        StartCollectibleFarm(v)
        SetToggleVisual(OrbToggle, true)
    end
end)

-- ESP
Window:AddSection(ESPTab, "Bug ESP")
ESPToggle = Window:AddToggle(ESPTab, "Enable ESP", false, function(enabled)
    if Syncing then return end
    SafeCall("ESP", function()
        CONFIG.ESPEnabled = enabled
        if enabled then ESPController:Enable() else ESPController:Disable() end
    end)
end)
Window:AddDropdown(ESPTab, "Bug Value / Size", {"All Sizes", "Large", "Small", "Normal (Random)"}, CONFIG.ESPFilter, function(v)
    CONFIG.ESPFilter = v
    if CONFIG.ESPEnabled then ESPController:Refresh() end
end)
Window:AddDropdown(ESPTab, "Bug Species", {"All Bugs"}, CONFIG.ESPSpecies, function(v)
    CONFIG.ESPSpecies = v
    if CONFIG.ESPEnabled then ESPController:Refresh() end
end)
Window:AddSlider(ESPTab, "Maximum Distance", 100, 5000, CONFIG.ESPMaxDistance, function(v)
    CONFIG.ESPMaxDistance = v
    if CONFIG.ESPEnabled then ESPController:Refresh() end
end)
Window:AddButton(ESPTab, "Refresh Bug / Species Lists", function()
    SafeCall("Refresh ESP Lists", function()
        BugScanner:Refresh()
        local species = {"All Bugs"}
        for _, name in ipairs(BugScanner:GetSpecies()) do table.insert(species, name) end
        if SpeciesDropdown then SpeciesDropdown.SetOptions(species) end
        if ESPspeciesDropdown then ESPspeciesDropdown.SetOptions(species) end
        Notify("Bug list refreshed")
    end)
end)

-- assign dropdown references after controls exist
-- update species options from a single scanner refresh
local function RefreshLists()
    BugScanner:Refresh()
    local species = {"All Bugs"}
    for _, name in ipairs(BugScanner:GetSpecies()) do table.insert(species, name) end
    if SpeciesDropdown then SpeciesDropdown.SetOptions(species) end
    if ESPspeciesDropdown then ESPspeciesDropdown.SetOptions(species) end
    if BreakableDropdown then BreakableDropdown.SetOptions(CollectibleScannerController:GetBreakableNames()) end
end

-- Recreate species dropdown controls with handles for live updates.
SpeciesDropdown = Window:AddDropdown(BugTab, "Select Bug Species", {"All Bugs"}, CONFIG.SelectedSpecies, function(v)
    CONFIG.SelectedSpecies = v
end)
ESPspeciesDropdown = Window:AddDropdown(ESPTab, "Select ESP Species", {"All Bugs"}, CONFIG.ESPSpecies, function(v)
    CONFIG.ESPSpecies = v
    if CONFIG.ESPEnabled then ESPController:Refresh() end
end)
Window:AddButton(BugTab, "Refresh Bug Species", RefreshLists)

Window:AddButton(FarmOptionsTab, "Stop All Farms", function()
    StopBugFarm()
    StopCollectibleFarm()
    MovementController:Stop()
    SetToggleVisual(BugToggle, false)
    SetToggleVisual(BreakableToggle, false)
    SetToggleVisual(OrbToggle, false)
    Notify("All farming stopped")
end)
Window:AddButton(FarmOptionsTab, "Refresh All Lists", RefreshLists)
Window:AddButton(FarmOptionsTab, "Destroy GUI", function()
    if Destroyed then return end
    Destroyed = true
    StopBugFarm()
    StopCollectibleFarm()
    ESPController:Disable()
    MovementController:Stop()
    Window:Destroy()
end)

task.spawn(function()
    while not Destroyed do
        task.wait(0.5)
        local target = BugFarm:GetCurrentTarget()
        if CONFIG.FarmEnabled and target then BugTarget = TargetName(target) end
        BugStatus = tostring(BugFarm:GetStatus())
        local ct = CollectibleFarm:GetCurrentTarget()
        if CONFIG.CollectibleEnabled and ct then CollectibleTarget = TargetName(ct) end
        CollectibleStatus = tostring(CollectibleFarm:GetStatus())
        BugStatusLabel.Text = "Status: " .. BugStatus
        BugTargetLabel.Text = "Target: " .. BugTarget
        BreakableStatusLabel.Text = "Status: " .. (CONFIG.CollectibleMode == "Breakable" and CollectibleStatus or "Stopped")
        BreakableTargetLabel.Text = "Target: " .. (CONFIG.CollectibleMode == "Breakable" and CollectibleTarget or "None")
        OrbStatusLabel.Text = "Status: " .. ((CONFIG.CollectibleMode == "Orb" or CONFIG.CollectibleMode == "VoidOrb") and CollectibleStatus or "Stopped")
        OrbTargetLabel.Text = "Target: " .. ((CONFIG.CollectibleMode == "Orb" or CONFIG.CollectibleMode == "VoidOrb") and CollectibleTarget or "None")
        local count = 0
        pcall(function() count = CollectibleScannerController:GetVoidOrbCount() end)
        VoidOrbCountLabel.Text = "VoidOrbs Available: " .. tostring(count)
    end
end)

SafeCall("Initial Scan", RefreshLists)
Window:SetTab("Farm Options")
Notify("BUG EVOLUTION v1.3.0 LOADED", 5)
print("[Bug Evolution] v1.3.0 initialized")
