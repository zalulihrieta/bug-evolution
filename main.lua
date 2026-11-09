--[[
    BUG EVOLUTION
    Main Controller
    Version: 1.0.0

    Client-side executor script.
    Requires loadstring and game:HttpGet support.
]]

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- CONFIGURATION
--==================================================

local CONFIG = {
    -- Bug Scanner
    BugFolderName = "Bugs", -- Provisional: belum dikonfirmasi
    SelectedSpecies = "All Bugs",
    SizePriority = "Largest First",
    ScanInterval = 1,

    -- Movement
    MovementMode = "Tween",
    AttackDistance = 8,
    TweenSpeed = 100,

    -- Bug Farming
    FarmEnabled = false,

    -- Collectible Farming
    CollectibleEnabled = false,
    CollectibleMode = "Orb",

    -- ESP
    ESPEnabled = false,
    ESPFilter = "Normal",
    ESPMaxDistance = 1000,
}

--==================================================
-- MODULE LOADER
--==================================================

local BASE_URL =
    "https://raw.githubusercontent.com/zalulihrieta/bug-evolution/main/"

local function LoadModule(path)
    local url = BASE_URL .. path

    local success, result = pcall(function()
        local source = game:HttpGet(url)

        local moduleFunction, compileError = loadstring(source)

        if not moduleFunction then
            error(compileError)
        end

        return moduleFunction()
    end)

    if not success then
        error(
            "[Bug Evolution] Failed to load "
            .. path
            .. "\n"
            .. tostring(result)
        )
    end

    return result
end

--==================================================
-- LOAD MODULES
--==================================================

local GUI = LoadModule("gui.lua")

local Scanner = LoadModule("modules/scanner.lua")
local Movement = LoadModule("modules/movement.lua")
local Farming = LoadModule("modules/farming.lua")

local CollectibleScanner =
    LoadModule("modules/collectible_scanner.lua")

local CollectibleFarming =
    LoadModule("modules/collectible_farming.lua")

local ESP = LoadModule("modules/esp.lua")

--==================================================
-- CREATE CONTROLLERS
--==================================================

local Window = GUI()

local BugScanner = Scanner.new(CONFIG)

local MovementController = Movement.new(CONFIG)

local CollectibleScannerController =
    CollectibleScanner.new(CONFIG)

--==================================================
-- STATUS VARIABLES
--==================================================

local BugStatus = "Stopped"
local CollectibleStatus = "Stopped"

local BugTargetName = "None"
local CollectibleTargetName = "None"

local BugFarm
local CollectibleFarm
local ESPController

--==================================================
-- HELPERS
--==================================================

local function GetTargetName(target)
    if not target then
        return "None"
    end

    local instance = target.Instance or target

    if typeof(instance) == "Instance" then
        return instance.Name
    end

    return tostring(instance)
end

local function SetLabelText(label, text)
    if not label then
        return
    end

    pcall(function()
        if typeof(label) == "Instance" then
            label.Text = text
        elseif type(label) == "table" then
            if label.Label then
                label.Label.Text = text
            elseif label.TextLabel then
                label.TextLabel.Text = text
            elseif label.Instance then
                label.Instance.Text = text
            end
        end
    end)
end

local function Notify(title, message, duration)
    Window:Notify(
        title,
        message,
        duration or 3
    )
end

--==================================================
-- FARMING CALLBACKS
--==================================================

BugFarm = Farming.new({
    Settings = CONFIG,

    Scanner = BugScanner,

    Movement = MovementController,

    OnStatusChanged = function(status, target)
        BugStatus = tostring(status)

        if target then
            BugTargetName = GetTargetName(target)
        elseif BugStatus == "Stopped"
            or BugStatus == "Idle" then

            BugTargetName = "None"
        end
    end,
})

CollectibleFarm = CollectibleFarming.new({
    Settings = CONFIG,

    Scanner = CollectibleScannerController,

    Movement = MovementController,

    OnStatusChanged = function(status, target)
        CollectibleStatus = tostring(status)

        if target then
            CollectibleTargetName = GetTargetName(target)
        elseif CollectibleStatus == "Stopped"
            or CollectibleStatus == "Idle" then

            CollectibleTargetName = "None"
        end
    end,
})

ESPController = ESP.new({
    Settings = CONFIG,

    Scanner = BugScanner,
})

--==================================================
-- GUI TABS
--==================================================

Window:CreateTab("Farm")
Window:CreateTab("Collectibles")
Window:CreateTab("Bugs")
Window:CreateTab("ESP")
Window:CreateTab("Settings")

--==================================================
-- FARM TAB
--==================================================

Window:AddSection("Farm", "Bug Farming")

local BugStatusLabel = Window:AddLabel(
    "Farm",
    "Status: Stopped"
)

local BugTargetLabel = Window:AddLabel(
    "Farm",
    "Target: None"
)

Window:AddToggle(
    "Farm",
    "Enable Bug Farming",
    false,

    function(enabled)
        if enabled then
            -- Stop collectible farming first
            CollectibleFarm:Stop()

            CONFIG.CollectibleEnabled = false
            CONFIG.FarmEnabled = true

            BugFarm:Start()

            Notify(
                "Bug Evolution",
                "Bug Farming Enabled"
            )
        else
            CONFIG.FarmEnabled = false

            BugFarm:Stop()

            Notify(
                "Bug Evolution",
                "Bug Farming Disabled"
            )
        end
    end
)

Window:AddDropdown(
    "Farm",
    "Movement Mode",
    {
        "Tween",
        "Teleport",
    },
    CONFIG.MovementMode,

    function(value)
        CONFIG.MovementMode = value
    end
)

Window:AddDropdown(
    "Farm",
    "Bug Priority",
    {
        "Largest First",
        "Smallest First",
        "Nearest First",
        "Random Size (Nearest)",
    },
    CONFIG.SizePriority,

    function(value)
        CONFIG.SizePriority = value
    end
)

Window:AddSlider(
    "Farm",
    "Attack Distance",
    3,
    20,
    CONFIG.AttackDistance,

    function(value)
        CONFIG.AttackDistance = value
    end
)

--==================================================
-- COLLECTIBLES TAB
--==================================================

Window:AddSection(
    "Collectibles",
    "Collectible Farming"
)

local CollectibleStatusLabel = Window:AddLabel(
    "Collectibles",
    "Status: Stopped"
)

local CollectibleTargetLabel = Window:AddLabel(
    "Collectibles",
    "Target: None"
)

Window:AddDropdown(
    "Collectibles",
    "Farming Mode",
    {
        "Orb",
        "Breakable",
        "VoidOrb",
    },
    CONFIG.CollectibleMode,

    function(value)
        CONFIG.CollectibleMode = value

        Notify(
            "Collectible Mode",
            "Selected: " .. value
        )
    end
)

Window:AddToggle(
    "Collectibles",
    "Enable Collectible Farming",
    false,

    function(enabled)
        if enabled then
            -- Stop bug farming first
            BugFarm:Stop()

            CONFIG.FarmEnabled = false
            CONFIG.CollectibleEnabled = true

            CollectibleFarm:Start(
                CONFIG.CollectibleMode
            )

            Notify(
                "Bug Evolution",
                CONFIG.CollectibleMode
                .. " Farming Enabled"
            )
        else
            CONFIG.CollectibleEnabled = false

            CollectibleFarm:Stop()

            Notify(
                "Bug Evolution",
                "Collectible Farming Disabled"
            )
        end
    end
)

--==================================================
-- BUGS TAB
--==================================================

Window:AddSection(
    "Bugs",
    "Species Scanner"
)

local SpeciesLabel = Window:AddLabel(
    "Bugs",
    "Detected Species: Loading..."
)

local SpeciesDropdown

local function RefreshSpecies()
    BugScanner:Refresh()

    local species = BugScanner:GetSpecies()

    local options = {
        "All Bugs",
    }

    for _, name in ipairs(species) do
        table.insert(options, name)
    end

    if SpeciesDropdown then
        -- The GUI module's SetOptions uses dot syntax.
        pcall(function()
            SpeciesDropdown.SetOptions(options)
        end)
    end

    SetLabelText(
        SpeciesLabel,
        "Detected Species: " .. tostring(#species)
    )

    Notify(
        "Bug Scanner",
        tostring(#species) .. " species detected"
    )
end

SpeciesDropdown = Window:AddDropdown(
    "Bugs",
    "Select Species",
    {
        "All Bugs",
    },
    CONFIG.SelectedSpecies,

    function(value)
        CONFIG.SelectedSpecies = value
    end
)

Window:AddButton(
    "Bugs",
    "Refresh Species",
    RefreshSpecies
)

--==================================================
-- ESP TAB
--==================================================

Window:AddSection(
    "ESP",
    "Bug ESP"
)

Window:AddToggle(
    "ESP",
    "Enable Bug ESP",
    false,

    function(enabled)
        CONFIG.ESPEnabled = enabled

        if enabled then
            ESPController:Enable()

            Notify(
                "Bug ESP",
                "ESP Enabled"
            )
        else
            ESPController:Disable()

            Notify(
                "Bug ESP",
                "ESP Disabled"
            )
        end
    end
)

Window:AddDropdown(
    "ESP",
    "Size Filter",
    {
        "Normal",
        "Huge+",
        "Tiny",
        "Small",
        "Large",
        "Giant",
        "Massive",
    },
    CONFIG.ESPFilter,

    function(value)
        CONFIG.ESPFilter = value

        if CONFIG.ESPEnabled then
            ESPController:Refresh()
        end
    end
)

Window:AddSlider(
    "ESP",
    "Maximum Distance",
    100,
    5000,
    CONFIG.ESPMaxDistance,

    function(value)
        CONFIG.ESPMaxDistance = value
    end
)

--==================================================
-- SETTINGS TAB
--==================================================

Window:AddSection(
    "Settings",
    "General Settings"
)

Window:AddLabel(
    "Settings",
    "Bug Evolution v1.0.0"
)

Window:AddButton(
    "Settings",
    "Refresh All Scanners",

    function()
        BugScanner:Refresh()

        CollectibleScannerController:RefreshFolders()

        RefreshSpecies()

        Notify(
            "Bug Evolution",
            "All scanners refreshed"
        )
    end
)

Window:AddButton(
    "Settings",
    "Stop All Farming",

    function()
        BugFarm:Stop()
        CollectibleFarm:Stop()

        MovementController:Stop()

        CONFIG.FarmEnabled = false
        CONFIG.CollectibleEnabled = false

        Notify(
            "Bug Evolution",
            "All farming stopped"
        )
    end
)

Window:AddButton(
    "Settings",
    "Destroy GUI",

    function()
        BugFarm:Stop()
        CollectibleFarm:Stop()

        ESPController:Disable()

        MovementController:Stop()

        CONFIG.FarmEnabled = false
        CONFIG.CollectibleEnabled = false
        CONFIG.ESPEnabled = false

        Window:Destroy()
    end
)

--==================================================
-- LIVE STATUS UPDATE
--==================================================

task.spawn(function()
    while task.wait(0.5) do
        if not Window then
            break
        end

        if CONFIG.FarmEnabled then
            local target = BugFarm:GetCurrentTarget()

            if target then
                BugTargetName = GetTargetName(target)
            end

            BugStatus = tostring(
                BugFarm:GetStatus()
            )
        end

        if CONFIG.CollectibleEnabled then
            local target =
                CollectibleFarm:GetCurrentTarget()

            if target then
                CollectibleTargetName =
                    GetTargetName(target)
            end

            CollectibleStatus = tostring(
                CollectibleFarm:GetStatus()
            )
        end

        SetLabelText(
            BugStatusLabel,
            "Status: " .. BugStatus
        )

        SetLabelText(
            BugTargetLabel,
            "Target: " .. BugTargetName
        )

        SetLabelText(
            CollectibleStatusLabel,
            "Status: " .. CollectibleStatus
        )

        SetLabelText(
            CollectibleTargetLabel,
            "Target: " .. CollectibleTargetName
        )
    end
end)

--==================================================
-- INITIALIZATION
--==================================================

BugScanner:Refresh()

CollectibleScannerController:RefreshFolders()

RefreshSpecies()

Window:SetTab("Farm")

Notify(
    "Bug Evolution",
    "Successfully Loaded!",
    5
)

print("================================")
print("       BUG EVOLUTION v1.0.0")
print("       Successfully Loaded")
print("================================")