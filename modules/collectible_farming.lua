--[[
BUG EVOLUTION
Collectible Farming Controller

Modes:
- Orb: Highest XP first
- Breakable: Random nearest
- VoidOrb: Random

No manual attack input.

]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local Farming = {}
Farming.__index = Farming

--==================================================
-- CONSTRUCTOR
--==================================================

function Farming.new(options)

local self = setmetatable({}, Farming)

self.Settings = options.Settings
self.Scanner = options.Scanner
self.Movement = options.Movement

self.Running = false
self.Destroyed = false

self.CurrentMode = nil
self.CurrentTarget = nil
self.CurrentStatus = "Idle"

self.ActiveTween = nil

self.TargetTimeout = 15
self.TargetCooldown = 2

self.FailedTargets = {}

self.OnStatusChanged = options.OnStatusChanged

return self

end

--==================================================
-- STATUS
--==================================================

function Farming:SetStatus(status)

if self.CurrentStatus == status then
    return
end

self.CurrentStatus = status

print(
    "[Bug Evolution] Collectible: "
    .. tostring(status)
)

if self.OnStatusChanged then

    pcall(function()
        self.OnStatusChanged(status)
    end)

end

end

function Farming:GetStatus()
return self.CurrentStatus
end

function Farming:GetCurrentTarget()
return self.CurrentTarget
end

--==================================================
-- CHARACTER
--==================================================

function Farming:GetRoot()

local character = LocalPlayer.Character

if not character then
    return nil
end

return character:FindFirstChild("HumanoidRootPart")

end

--==================================================
-- TARGET VALIDATION
--==================================================

function Farming:IsValidTarget(target)

if not target or not target.Instance then
    return false
end

if not target.Instance.Parent then
    return false
end

if not target.Root or not target.Root.Parent then
    return false
end

return true

end

--==================================================
-- COOLDOWN
--==================================================

function Farming:IsOnCooldown(target)

if not target or not target.Instance then
    return true
end

local expiry = self.FailedTargets[target.Instance]

if not expiry then
    return false
end

if os.clock() >= expiry then

    self.FailedTargets[target.Instance] = nil

    return false

end

return true

end

function Farming:AddCooldown(target)

if not target or not target.Instance then
    return
end

self.FailedTargets[target.Instance] =
    os.clock() + self.TargetCooldown

end

--==================================================
-- GET TARGET
--==================================================

function Farming:GetNextTarget()

local mode = self.CurrentMode

if mode == "Orb" then

    local targets = self.Scanner:GetOrbTargets()

    for _, target in ipairs(targets) do

        if not self:IsOnCooldown(target) then
            return target
        end

    end

elseif mode == "Breakable" then

    local attempts = 10

    for _ = 1, attempts do

        local target =
            self.Scanner:GetBreakableTarget()

        if target and not self:IsOnCooldown(target) then
            return target
        end

        if not target then
            break
        end

    end

elseif mode == "VoidOrb" then

    local attempts = 10

    for _ = 1, attempts do

        local target =
            self.Scanner:GetVoidOrbTarget()

        if target and not self:IsOnCooldown(target) then
            return target
        end

        if not target then
            break
        end

    end

end

return nil

end

--==================================================
-- CANCEL MOVEMENT
--==================================================

function Farming:CancelMovement()

if self.ActiveTween then

    pcall(function()
        self.ActiveTween:Cancel()
    end)

    self.ActiveTween = nil

end

if self.Movement then
    self.Movement:Stop()
end

end

--==================================================
-- MOVE TO COLLECTIBLE
--==================================================

function Farming:MoveToTarget(target)

if not self:IsValidTarget(target) then
    return false
end

local root = self:GetRoot()

if not root then
    return false
end

local targetRoot = target.Root

local mode =
    self.Settings.MovementMode or "Tween"

-- Breakables use normal attack distance.
if self.CurrentMode == "Breakable" then

    local success =
        self.Movement:MoveToBreakable(target.Instance)

    if not success then
        return false
    end

    if mode == "Tween" then
        self.Movement:WaitForMovement()
    end

    return self.Running

end

-- Orb and VoidOrb require contact.
-- Their destination is the target position itself.

self:CancelMovement()

local destination =
    targetRoot.CFrame

if mode == "Teleport" then

    return self.Movement:MoveToCFrame(destination, target.Instance)

elseif mode == "Tween" then

    local speed =
        tonumber(self.Settings.TweenSpeed) or 100

    speed = math.max(speed, 1)

    local distance =
        (root.Position - destination.Position).Magnitude

    local duration = math.clamp(
        distance / speed,
        0.05,
        10
    )

    return self.Movement:MoveToCFrame(
        destination,
        target.Instance
    ) and self.Movement:WaitForMovement() and self.Running

end

return false

end

--==================================================
-- WAIT FOR COLLECTION / BREAK
--==================================================

function Farming:WaitForTarget(target)

local startTime = os.clock()

while self.Running do

    if not self:IsValidTarget(target) then
        return true
    end

    if os.clock() - startTime >= self.TargetTimeout then
        return false
    end

    task.wait(0.15)

end

return false

end

--==================================================
-- PROCESS TARGET
--==================================================

function Farming:ProcessTarget(target)

if not self:IsValidTarget(target) then
    return false
end

self.CurrentTarget = target

local name = target.Name or "Unknown"

if self.CurrentMode == "Orb" then

    self:SetStatus(
        "Orb: " .. name .. " | XP: " .. tostring(target.XP)
    )

elseif self.CurrentMode == "Breakable" then

    self:SetStatus(
        "Breakable: " .. name
    )

elseif self.CurrentMode == "VoidOrb" then

    self:SetStatus(
        "VoidOrb: " .. name
    )

end

-- Move to target.
local moved = self:MoveToTarget(target)

if not self.Running then
    return false
end

if not moved then

    self:AddCooldown(target)

    return false

end

if not self:IsValidTarget(target) then
    return true
end

-- Wait for collection or destruction.
if self.CurrentMode == "Orb" then

    self:SetStatus(
        "Collecting Orb | XP: " .. tostring(target.XP)
    )

elseif self.CurrentMode == "Breakable" then

    self:SetStatus(
        "Waiting for Breakable..."
    )

elseif self.CurrentMode == "VoidOrb" then

    self:SetStatus(
        "Collecting VoidOrb..."
    )

end

local completed = self:WaitForTarget(target)

if completed then

    self:SetStatus(
        "Collected: " .. name
    )

else

    self:AddCooldown(target)

    self:SetStatus(
        "Target timeout: " .. name
    )

end

self.CurrentTarget = nil

return completed

end

--==================================================
-- FARM LOOP
--==================================================

function Farming:FarmLoop()

while self.Running do

    local target = self:GetNextTarget()

    if target then

        self:ProcessTarget(target)

    else

        self:SetStatus(
            "Waiting for " .. tostring(self.CurrentMode)
        )

        task.wait(0.75)

    end

    if self.Running then
        task.wait(0.1)
    end

end

self:CancelMovement()

self.CurrentTarget = nil

self:SetStatus("Idle")

end

--==================================================
-- START
--==================================================

function Farming:Start(mode)

if self.Destroyed then
    return false
end

if self.Running then
    self:Stop()
end

if mode ~= "Orb"
    and mode ~= "Breakable"
    and mode ~= "VoidOrb" then

    warn(
        "[Bug Evolution] Invalid collectible mode: "
        .. tostring(mode)
    )

    return false

end

self.CurrentMode = mode
self.Running = true

self.Settings.CollectibleEnabled = true
self.Settings.CollectibleMode = mode

self:SetStatus("Starting " .. mode .. "...")

task.spawn(function()

    local success, err = pcall(function()
        self:FarmLoop()
    end)

    if not success then

        warn(
            "[Bug Evolution] Collectible Error: "
            .. tostring(err)
        )

        self:Stop()

    end

end)

return true

end

--==================================================
-- STOP
--==================================================

function Farming:Stop()

self.Running = false

self.Settings.CollectibleEnabled = false

self:CancelMovement()

self.CurrentTarget = nil

self:SetStatus("Stopped")

end

--==================================================
-- DESTROY
--==================================================

function Farming:Destroy()

self:Stop()

self.Destroyed = true

self.FailedTargets = {}

end

return Farming