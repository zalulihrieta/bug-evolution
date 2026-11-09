--[[
    BUG EVOLUTION
    Main Controller
    Version: 1.1.0

    Modules:
    - Bug Scanner
    - Bug Farming
    - Collectible Scanner
    - Collectible Farming
    - Movement
    - ESP

    GUI API compatible with gui.lua v1.0
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
    BugFolderName = "Bugs",
    SelectedSpecies = "All Bugs",
    SizePriority = "Largest First",
    ScanInterval = 1,

    -- Movement
    MovementMode = "Tween",
    AttackDistance = 2,
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

    local success, result = pcall(function()

        local source = game:HttpGet(
            BASE_URL .. path
        )

        assert(
            type(source) == "string"
                and #source > 0,
            "Empty module source: " .. path
        )

        local compiled, compileError =
            loadstring(source)

        assert(
            compiled,
            compileError or "Compilation failed"
        )

        return compiled()

    end)

    if not success then

        error(
            "[Bug Evolution] Module Error: "
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

local Scanner =
    LoadModule("modules/scanner.lua")

local Movement =
    LoadModule("modules/movement.lua")

local Farming =
    LoadModule("modules/farming.lua")

local CollectibleScanner =
    LoadModule("modules/collectible_scanner.lua")

local CollectibleFarming =
    LoadModule("modules/collectible_farming.lua")

local ESP =
    LoadModule("modules/esp.lua")

--==================================================
-- GUI INITIALIZATION
--==================================================

-- IMPORTANT:
-- gui.lua returns a GUI table.
-- Do NOT use GUI().

local Window = GUI

--==================================================
-- CREATE TABS
--==================================================

-- CreateTab returns a ScrollingFrame.
-- Every GUI component must receive that page.

local FarmTab =
    Window:CreateTab("Farm", 1)

local CollectiblesTab =
    Window:CreateTab("Collectibles", 2)

local BugsTab =
    Window:CreateTab("Bugs", 3)

local ESPTab =
    Window:CreateTab("ESP", 4)

local SettingsTab =
    Window:CreateTab("Settings", 5)

--==================================================
-- CREATE CONTROLLERS
--==================================================

local BugScanner = Scanner.new(CONFIG)

local MovementController =
    Movement.new(CONFIG)

local CollectibleScannerController =
    CollectibleScanner.new(CONFIG)

--==================================================
-- STATUS
--==================================================

local BugStatus = "Stopped"
local CollectibleStatus = "Stopped"

local BugTargetName = "None"
local CollectibleTargetName = "None"

local BugFarm
local CollectibleFarm
local ESPController

local BugToggle
local CollectibleToggle
local ESPToggle

local SyncingToggles = false
local Destroyed = false

--==================================================
-- HELPER FUNCTIONS
--==================================================

local function Notify(message, duration)

    Window:Notify(
        tostring(message),
        duration or 3
    )

end

local function SafeCall(label, callback)

    local success, result = xpcall(
        callback,
        debug.traceback
    )

    if not success then

        warn(
            "[Bug Evolution] "
            .. label
            .. "\n"
            .. tostring(result)
        )

        Notify(
            label .. " failed. Check executor console.",
            5
        )

    end

    return success, result

end

local function GetTargetName(target)

    if not target then
        return "None"
    end

    if type(target) == "table" then

        if target.Name then
            return tostring(target.Name)
        end

        if target.Instance then
            return target.Instance.Name
        end

    end

    if typeof(target) == "Instance" then
        return target.Name
    end

    return tostring(target)

end

local function UpdateLabel(label, value)

    if label then
        label.Text = tostring(value)
    end

end

local function SetToggleVisual(toggle, value)

    if not toggle then
        return
    end

    SyncingToggles = true

    pcall(function()
        toggle.Set(value)
    end)

    SyncingToggles = false

end

--==================================================
-- CREATE FARMING CONTROLLERS
--==================================================

BugFarm = Farming.new({

    Settings = CONFIG,

    Scanner = BugScanner,

    Movement = MovementController,

    OnStatusChanged = function(status, target)

        BugStatus = tostring(status)

        if target then
            BugTargetName = GetTargetName(target)
        end

        if BugStatus == "Stopped"
            or BugStatus == "Idle" then

            BugTargetName = "None"

        end

    end,

})

CollectibleFarm = CollectibleFarming.new({

    Settings = CONFIG,

    Scanner = CollectibleScannerController,

    Movement = MovementController,

    OnStatusChanged = function(status)

        CollectibleStatus = tostring(status)

        if CollectibleStatus == "Stopped"
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
-- FARM CONTROL
--==================================================

local function StopBugFarm()

    CONFIG.FarmEnabled = false

    BugFarm:Stop()

    BugStatus = "Stopped"
    BugTargetName = "None"

end

local function StopCollectibleFarm()

    CONFIG.CollectibleEnabled = false

    CollectibleFarm:Stop()

    CollectibleStatus = "Stopped"
    CollectibleTargetName = "None"

end

local function StartBugFarm()

    -- Prevent simultaneous farming.

    StopCollectibleFarm()

    SetToggleVisual(
        CollectibleToggle,
        false
    )

    CONFIG.FarmEnabled = true

    BugFarm:Start()

    Notify(
        "Bug Farming Enabled"
    )

end

local function StartCollectibleFarm()

    -- Prevent simultaneous farming.

    StopBugFarm()

    SetToggleVisual(
        BugToggle,
        false
    )

    CONFIG.CollectibleEnabled = true

    CollectibleFarm:Start(
        CONFIG.CollectibleMode
    )

    Notify(
        CONFIG.CollectibleMode
        .. " Farming Enabled"
    )

end

--==================================================
-- FARM TAB
--==================================================

Window:AddSection(
    FarmTab,
    "Bug Farming"
)

local BugStatusLabel = Window:AddLabel(
    FarmTab,
    "Status: Stopped"
)

local BugTargetLabel = Window:AddLabel(
    FarmTab,
    "Target: None"
)

BugToggle = Window:AddToggle(
    FarmTab,
    "Enable Bug Farming",
    false,

    function(enabled)

        if SyncingToggles then
            return
        end

        SafeCall("Bug Farming", function()

            if enabled then
                StartBugFarm()
            else
                StopBugFarm()

                Notify(
                    "Bug Farming Disabled"
                )
            end

        end)

    end
)

Window:AddDropdown(
    FarmTab,
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
    FarmTab,
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
    FarmTab,
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
    CollectiblesTab,
    "Collectible Farming"
)

local CollectibleStatusLabel = Window:AddLabel(
    CollectiblesTab,
    "Status: Stopped"
)

local CollectibleTargetLabel = Window:AddLabel(
    CollectiblesTab,
    "Target: None"
)

Window:AddDropdown(
    CollectiblesTab,
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
            "Selected: " .. value
        )

    end
)

CollectibleToggle = Window:AddToggle(
    CollectiblesTab,
    "Enable Collectible Farming",
    false,

    function(enabled)

        if SyncingToggles then
            return
        end

        SafeCall("Collectible Farming", function()

            if enabled then
                StartCollectibleFarm()
            else
                StopCollectibleFarm()

                Notify(
                    "Collectible Farming Disabled"
                )
            end

        end)

    end
)

--==================================================
-- BUGS TAB
--==================================================

Window:AddSection(
    BugsTab,
    "Species Scanner"
)

local SpeciesLabel = Window:AddLabel(
    BugsTab,
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

        table.insert(
            options,
            name
        )

    end

    if SpeciesDropdown then

        SpeciesDropdown.SetOptions(
            options
        )

    end

    -- Reset invalid selection.

    if not table.find(options, CONFIG.SelectedSpecies) then
        CONFIG.SelectedSpecies = "All Bugs"
    end

    UpdateLabel(
        SpeciesLabel,
        "Detected Species: " .. #species
    )

    Notify(
        #species .. " species detected"
    )

end

SpeciesDropdown = Window:AddDropdown(
    BugsTab,
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
    BugsTab,
    "Refresh Species",
    function()

        SafeCall(
            "Species Scanner",
            RefreshSpecies
        )

    end
)

--==================================================
-- ESP TAB
--==================================================

Window:AddSection(
    ESPTab,
    "Bug ESP"
)

ESPToggle = Window:AddToggle(
    ESPTab,
    "Enable Bug ESP",
    false,

    function(enabled)

        if SyncingToggles then
            return
        end

        SafeCall("Bug ESP", function()

            CONFIG.ESPEnabled = enabled

            if enabled then

                ESPController:Enable()

                Notify("ESP Enabled")

            else

                ESPController:Disable()

                Notify("ESP Disabled")

            end

        end)

    end
)

Window:AddDropdown(
    ESPTab,
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
    ESPTab,
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
    SettingsTab,
    "General Settings"
)

Window:AddLabel(
    SettingsTab,
    "Bug Evolution v1.1.0"
)

Window:AddButton(
    SettingsTab,
    "Refresh All Scanners",

    function()

        SafeCall("Refresh All Scanners", function()

            BugScanner:Refresh()

            CollectibleScannerController:RefreshFolders()

            RefreshSpecies()

            Notify(
                "All scanners refreshed"
            )

        end)

    end
)

Window:AddButton(
    SettingsTab,
    "Stop All Farming",

    function()

        StopBugFarm()
        StopCollectibleFarm()

        MovementController:Stop()

        SetToggleVisual(
            BugToggle,
            false
        )

        SetToggleVisual(
            CollectibleToggle,
            false
        )

        Notify(
            "All farming stopped"
        )

    end
)

Window:AddButton(
    SettingsTab,
    "Disable ESP",

    function()

        CONFIG.ESPEnabled = false

        ESPController:Disable()

        SetToggleVisual(
            ESPToggle,
            false
        )

        Notify(
            "ESP Disabled"
        )

    end
)

Window:AddButton(
    SettingsTab,
    "Destroy GUI",

    function()

        if Destroyed then
            return
        end

        Destroyed = true

        StopBugFarm()
        StopCollectibleFarm()

        ESPController:Disable()

        MovementController:Stop()

        CONFIG.ESPEnabled = false

        Window:Destroy()

    end
)

--==================================================
-- LIVE STATUS
--==================================================

task.spawn(function()

    while not Destroyed do

        task.wait(0.5)

        if CONFIG.FarmEnabled then

            local target =
                BugFarm:GetCurrentTarget()

            if target then

                BugTargetName =
                    GetTargetName(target)

            end

            BugStatus =
                tostring(BugFarm:GetStatus())

        end

        if CONFIG.CollectibleEnabled then

            local target =
                CollectibleFarm:GetCurrentTarget()

            if target then

                CollectibleTargetName =
                    GetTargetName(target)

            end

            CollectibleStatus =
                tostring(CollectibleFarm:GetStatus())

        end

        UpdateLabel(
            BugStatusLabel,
            "Status: " .. BugStatus
        )

        UpdateLabel(
            BugTargetLabel,
            "Target: " .. BugTargetName
        )

        UpdateLabel(
            CollectibleStatusLabel,
            "Status: " .. CollectibleStatus
        )

        UpdateLabel(
            CollectibleTargetLabel,
            "Target: " .. CollectibleTargetName
        )

    end

end)

--==================================================
-- INITIALIZATION
--==================================================

SafeCall(
    "Initial Scanner",
    function()

        BugScanner:Refresh()

        CollectibleScannerController:RefreshFolders()

        RefreshSpecies()

    end
)

Window:SetTab("Farm")

Notify(
    "BUG EVOLUTION v1.1.0 LOADED",
    5
)

print("================================")
print("       BUG EVOLUTION v1.1.0")
print("       GUI INITIALIZED")
print("================================")