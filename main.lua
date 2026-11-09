--[[
    BUG EVOLUTION
    Main Controller
    Author: Perdana

    Repository:
    https://github.com/zalulihrieta/bug-evolution
]]

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- CONFIGURATION
--==================================================

local BASE_URL =
    "https://raw.githubusercontent.com/zalulihrieta/bug-evolution/main/"

local CONFIG = {
    -- Ganti jika folder bug di game ternyata berbeda.
    BugFolderName = "Bugs",

    -- Farming
    FarmEnabled = false,
    SelectedSpecies = "All Bugs",
    SizePriority = "Largest First",
    MovementMode = "Tween",

    -- Movement
    AttackDistance = 8,
    TweenSpeed = 100,

    -- ESP
    ESPEnabled = false,
    ESPFilter = "Normal",
    ESPMaxDistance = 1000,

    -- Scanner
    ScanInterval = 1,
}

--==================================================
-- MODULE LOADER
--==================================================

local function LoadModule(path)
    local url = BASE_URL .. path

    local success, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        error("[Bug Evolution] Failed to download: " .. path)
    end

    local compileSuccess, moduleFunction = pcall(function()
        return loadstring(source)
    end)

    if not compileSuccess or not moduleFunction then
        error("[Bug Evolution] Failed to compile: " .. path)
    end

    local executeSuccess, module = pcall(moduleFunction)

    if not executeSuccess then
        error("[Bug Evolution] Failed to load module: " .. path)
    end

    return module
end

--==================================================
-- LOAD MODULES
--==================================================

local GUI = LoadModule("gui.lua")

local Scanner = LoadModule("modules/scanner.lua")
local Movement = LoadModule("modules/movement.lua")
local Farming = LoadModule("modules/farming.lua")
local ESP = LoadModule("modules/esp.lua")

--==================================================
-- INITIALIZE MODULES
--==================================================

local ScannerController = Scanner.new(CONFIG)

local MovementController = Movement.new(CONFIG)

local FarmingController = Farming.new({
    Settings = CONFIG,
    Scanner = ScannerController,
    Movement = MovementController,
})

local ESPController = ESP.new({
    Settings = CONFIG,
    Scanner = ScannerController,
})

--==================================================
-- CREATE GUI
--==================================================

local Window = GUI()

Window:Notify(
    "Bug Evolution",
    "Script successfully loaded!",
    3
)

--==================================================
-- TABS
--==================================================

local FarmTab = Window:CreateTab("Farm")
local BugTab = Window:CreateTab("Bugs")
local ESPTab = Window:CreateTab("ESP")
local SettingsTab = Window:CreateTab("Settings")

--==================================================
-- FARM TAB
--==================================================

Window:AddSection(FarmTab, "Farming Control")

Window:AddLabel(
    FarmTab,
    "Automatic Bug Farming"
)

Window:AddToggle(
    FarmTab,
    "Enable Farming",
    false,
    function(state)

        CONFIG.FarmEnabled = state

        if state then
            FarmingController:Start()

            Window:Notify(
                "Farming",
                "Farming enabled!",
                3
            )
        else
            FarmingController:Stop()

            Window:Notify(
                "Farming",
                "Farming stopped!",
                3
            )
        end
    end
)

Window:AddDropdown(
    FarmTab,
    "Movement Mode",
    {
        "Teleport",
        "Tween",
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
    25,
    CONFIG.AttackDistance,
    function(value)

        CONFIG.AttackDistance = value

    end
)

--==================================================
-- BUG TAB
--==================================================

Window:AddSection(BugTab, "Bug Selection")

Window:AddLabel(
    BugTab,
    "Select which bug species to farm."
)

local SpeciesDropdown = Window:AddDropdown(
    BugTab,
    "Bug Species",
    {
        "All Bugs",
    },
    CONFIG.SelectedSpecies,
    function(value)

        CONFIG.SelectedSpecies = value

    end
)

Window:AddButton(
    BugTab,
    "Refresh Bug List",
    function()

        local species = ScannerController:GetSpecies()

        if species then

            local options = {
                "All Bugs",
            }

            for _, name in ipairs(species) do
                table.insert(options, name)
            end

            SpeciesDropdown:SetOptions(options)

            Window:Notify(
                "Bug Scanner",
                "Bug list updated!",
                3
            )

        else

            Window:Notify(
                "Bug Scanner",
                "No bug species found.",
                3
            )

        end
    end
)

--==================================================
-- ESP TAB
--==================================================

Window:AddSection(ESPTab, "ESP Configuration")

Window:AddToggle(
    ESPTab,
    "Enable Bug ESP",
    false,
    function(state)

        CONFIG.ESPEnabled = state

        if state then
            ESPController:Enable()
        else
            ESPController:Disable()
        end

    end
)

Window:AddDropdown(
    ESPTab,
    "ESP Size Filter",
    {
        "Normal",
        "Small+",
        "Large+",
        "Huge+",
        "Giant+",
        "Massive",
    },
    CONFIG.ESPFilter,
    function(value)

        CONFIG.ESPFilter = value

        ESPController:Refresh()

    end
)

Window:AddSlider(
    ESPTab,
    "ESP Max Distance",
    50,
    3000,
    CONFIG.ESPMaxDistance,
    function(value)

        CONFIG.ESPMaxDistance = value

        ESPController:Refresh()

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
    "Bug Evolution"
)

Window:AddLabel(
    SettingsTab,
    "Version: 1.0.0"
)

Window:AddButton(
    SettingsTab,
    "Refresh All Modules",
    function()

        ScannerController:Refresh()

        ESPController:Refresh()

        Window:Notify(
            "Bug Evolution",
            "Modules refreshed!",
            3
        )

    end
)

Window:AddButton(
    SettingsTab,
    "Stop All",
    function()

        CONFIG.FarmEnabled = false
        CONFIG.ESPEnabled = false

        FarmingController:Stop()
        ESPController:Disable()

        Window:Notify(
            "Bug Evolution",
            "All features stopped.",
            3
        )

    end
)

Window:AddButton(
    SettingsTab,
    "Destroy GUI",
    function()

        FarmingController:Stop()
        ESPController:Disable()

        Window:Destroy()

    end
)

--==================================================
-- AUTOMATIC SPECIES REFRESH
--==================================================

task.spawn(function()

    while task.wait(10) do

        local success, species = pcall(function()
            return ScannerController:GetSpecies()
        end)

        if success and species then

            local options = {
                "All Bugs",
            }

            for _, name in ipairs(species) do
                table.insert(options, name)
            end

            SpeciesDropdown:SetOptions(options)

        end

    end

end)

--==================================================
-- INITIAL SCAN
--==================================================

task.spawn(function()

    task.wait(2)

    ScannerController:Refresh()

    Window:Notify(
        "Bug Evolution",
        "Bug scanner initialized.",
        3
    )

end)

--==================================================
-- CLEANUP
--==================================================

Players.PlayerRemoving:Connect(function(player)

    if player == LocalPlayer then

        FarmingController:Stop()
        ESPController:Disable()

    end

end)

-- Collectible Farming
CollectibleEnabled = false,
CollectibleMode = "Orb",
print("[Bug Evolution] Main controller loaded.")