--[[
BUG EVOLUTION
Movement Module

Features:
- Teleport movement
- Tween movement
- Configurable movement speed
- Configurable attack distance
- Face selected bug
- Cancel previous movement
- Character respawn handling

Does NOT implement attack input.

]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local Movement = {}
Movement.__index = Movement

--==================================================
-- CONSTRUCTOR
--==================================================

function Movement.new(settings)

local self = setmetatable({}, Movement)

self.Settings = settings or {}

self.ActiveTween = nil
self.CurrentTarget = nil

self.IsMoving = false
self.Destroyed = false

return self

end

--==================================================
-- CHARACTER
--==================================================

function Movement:GetCharacter()

return LocalPlayer.Character

end

function Movement:GetRoot()

local character = self:GetCharacter()

if not character then
    return nil
end

return character:FindFirstChild("HumanoidRootPart")

end

function Movement:GetHumanoid()

local character = self:GetCharacter()

if not character then
    return nil
end

return character:FindFirstChildOfClass("Humanoid")

end

--==================================================
-- TARGET
--==================================================

function Movement:GetTargetRoot(target)

if not target then
    return nil
end

if target:IsA("BasePart") then
    return target
end

if target:IsA("Model") then

    if target.PrimaryPart then
        return target.PrimaryPart
    end

    local root =
        target:FindFirstChild("HumanoidRootPart", true)

    if root and root:IsA("BasePart") then
        return root
    end

    for _, object in ipairs(target:GetDescendants()) do

        if object:IsA("BasePart") then
            return object
        end

    end

end

return nil

end

--==================================================
-- CANCEL MOVEMENT
--==================================================

function Movement:Cancel()

if self.ActiveTween then

    pcall(function()
        self.ActiveTween:Cancel()
    end)

    self.ActiveTween = nil

end

self.IsMoving = false
self.CurrentTarget = nil

end

--==================================================
-- CALCULATE POSITION
--==================================================

function Movement:GetDestination(targetRoot)

local characterRoot = self:GetRoot()

if not characterRoot or not targetRoot then
    return nil
end

local attackDistance =
    tonumber(self.Settings.AttackDistance) or 8

attackDistance = math.max(attackDistance, 2)

local direction =
    characterRoot.Position - targetRoot.Position

if direction.Magnitude < 0.01 then

    direction = -targetRoot.CFrame.LookVector

end

direction = direction.Unit

local destination =
    targetRoot.Position + direction * attackDistance

return CFrame.lookAt(
    destination,
    targetRoot.Position
)

end

--==================================================
-- TELEPORT
--==================================================

function Movement:Teleport(target)

local root = self:GetRoot()
local targetRoot = self:GetTargetRoot(target)

if not root or not targetRoot then
    return false
end

self:Cancel()

local destination =
    self:GetDestination(targetRoot)

if not destination then
    return false
end

root.CFrame = destination

self.CurrentTarget = target

return true

end

--==================================================
-- TWEEN
--==================================================

function Movement:Tween(target)

local root = self:GetRoot()
local targetRoot = self:GetTargetRoot(target)

if not root or not targetRoot then
    return false
end

self:Cancel()

local destination =
    self:GetDestination(targetRoot)

if not destination then
    return false
end

local speed =
    tonumber(self.Settings.TweenSpeed) or 100

speed = math.max(speed, 1)

local distance =
    (root.Position - destination.Position).Magnitude

local duration = distance / speed

duration = math.clamp(duration, 0.05, 10)

local tweenInfo = TweenInfo.new(
    duration,
    Enum.EasingStyle.Linear,
    Enum.EasingDirection.Out
)

local tween = TweenService:Create(
    root,
    tweenInfo,
    {
        CFrame = destination
    }
)

self.ActiveTween = tween
self.CurrentTarget = target
self.IsMoving = true

tween:Play()

local completed = false

local connection

connection = tween.Completed:Connect(function(state)

    completed = true

    if connection then
        connection:Disconnect()
    end

    if self.ActiveTween == tween then

        self.ActiveTween = nil
        self.IsMoving = false

    end

end)

return true

end

--==================================================
-- MOVE TO TARGET
--==================================================

function Movement:MoveTo(target)

if self.Destroyed then
    return false
end

if not target or not target.Parent then
    return false
end

local mode =
    self.Settings.MovementMode or "Tween"

if mode == "Teleport" then

    return self:Teleport(target)

elseif mode == "Tween" then

    return self:Tween(target)

end

warn(
    "[Bug Evolution] Unknown movement mode: "
    .. tostring(mode)
)

return false

end

--==================================================
-- CHECK DISTANCE
--==================================================

function Movement:IsInRange(target)

local root = self:GetRoot()
local targetRoot = self:GetTargetRoot(target)

if not root or not targetRoot then
    return false
end

local attackDistance =
    tonumber(self.Settings.AttackDistance) or 8

local distance =
    (root.Position - targetRoot.Position).Magnitude

return distance <= attackDistance + 1

end

--==================================================
-- WAIT FOR MOVEMENT
--==================================================

function Movement:WaitForMovement()

while self.IsMoving do

    if self.Destroyed then
        return false
    end

    task.wait(0.05)

end

return true

end

--==================================================
-- STOP
--==================================================

function Movement:Stop()

self:Cancel()

end

--==================================================
-- DESTROY
--==================================================

function Movement:Destroy()

self:Cancel()

self.Destroyed = true

end

return Movement