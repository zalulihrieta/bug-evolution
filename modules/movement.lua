--[[
BUG EVOLUTION
Movement Module v1.2.0
Shared AttackDistance for bug and breakable farming.
Breakables are approached above their top surface.
Teleport delay is cancellable. No attack input or remotes.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Movement = {}
Movement.__index = Movement

function Movement.new(settings)
    local self = setmetatable({}, Movement)
    self.Settings = settings or {}
    self.ActiveTween = nil
    self.CurrentTarget = nil
    self.IsMoving = false
    self.Destroyed = false
    self.MovementId = 0
    return self
end

function Movement:GetCharacter()
    return LocalPlayer.Character
end

function Movement:GetRoot()
    local character = self:GetCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Movement:GetHumanoid()
    local character = self:GetCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

function Movement:GetTargetRoot(target)
    if not target then return nil end
    if target:IsA("BasePart") then return target end
    if target:IsA("Model") then
        if target.PrimaryPart then return target.PrimaryPart end
        local root = target:FindFirstChild("HumanoidRootPart", true)
        if root and root:IsA("BasePart") then return root end
        for _, object in ipairs(target:GetDescendants()) do
            if object:IsA("BasePart") then return object end
        end
    end
    return nil
end

function Movement:Cancel()
    self.MovementId += 1
    if self.ActiveTween then
        pcall(function() self.ActiveTween:Cancel() end)
        self.ActiveTween = nil
    end
    self.IsMoving = false
    self.CurrentTarget = nil
end

function Movement:GetAttackDistance()
    return math.max(tonumber(self.Settings.AttackDistance) or 2, 0)
end

function Movement:GetDestination(targetRoot)
    local characterRoot = self:GetRoot()
    if not characterRoot or not targetRoot then return nil end
    local direction = characterRoot.Position - targetRoot.Position
    if direction.Magnitude < 0.01 then direction = -targetRoot.CFrame.LookVector end
    direction = direction.Unit
    local destination = targetRoot.Position + direction * self:GetAttackDistance()
    return CFrame.lookAt(destination, targetRoot.Position)
end

function Movement:GetBreakableDestination(target)
    if not target then return nil end
    local center, height
    if target:IsA("Model") then
        local boxCFrame, boxSize = target:GetBoundingBox()
        center, height = boxCFrame.Position, boxSize.Y
    elseif target:IsA("BasePart") then
        center, height = target.Position, target.Size.Y
    else
        return nil
    end
    local destination = Vector3.new(center.X, center.Y + height / 2 + self:GetAttackDistance(), center.Z)
    return CFrame.lookAt(destination, center)
end

function Movement:MoveToCFrame(destination, target)
    if self.Destroyed or not destination then return false end
    self:Cancel()
    local movementId = self.MovementId
    local mode = self.Settings.MovementMode or "Tween"

    if mode == "Teleport" then
        local delayTime = math.max(tonumber(self.Settings.TeleportDelay) or 0.2, 0)
        if delayTime > 0 then task.wait(delayTime) end
        if self.Destroyed or self.MovementId ~= movementId then return false end
        local root = self:GetRoot()
        if not root or (target and not target.Parent) then return false end
        root.CFrame = destination
        self.CurrentTarget = target
        return true
    elseif mode == "Tween" then
        local root = self:GetRoot()
        if not root or (target and not target.Parent) then return false end
        local speed = math.max(tonumber(self.Settings.TweenSpeed) or 150, 1)
        local distance = (root.Position - destination.Position).Magnitude
        local duration = math.clamp(distance / speed, 0.05, 10)
        local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = destination})
        self.ActiveTween = tween
        self.CurrentTarget = target
        self.IsMoving = true
        tween:Play()
        tween.Completed:Connect(function()
            if self.ActiveTween == tween then
                self.ActiveTween = nil
                self.IsMoving = false
            end
        end)
        return true
    end

    warn("[Bug Evolution] Unknown movement mode: " .. tostring(mode))
    return false
end

function Movement:Teleport(target)
    local targetRoot = self:GetTargetRoot(target)
    return targetRoot and self:MoveToCFrame(self:GetDestination(targetRoot), target) or false
end

function Movement:Tween(target)
    local targetRoot = self:GetTargetRoot(target)
    return targetRoot and self:MoveToCFrame(self:GetDestination(targetRoot), target) or false
end

function Movement:MoveTo(target)
    if self.Destroyed or not target or not target.Parent then return false end
    local targetRoot = self:GetTargetRoot(target)
    return targetRoot and self:MoveToCFrame(self:GetDestination(targetRoot), target) or false
end

function Movement:MoveToBreakable(target)
    if self.Destroyed or not target or not target.Parent then return false end
    return self:MoveToCFrame(self:GetBreakableDestination(target), target)
end

function Movement:IsInRange(target)
    local root, targetRoot = self:GetRoot(), self:GetTargetRoot(target)
    if not root or not targetRoot then return false end
    return (root.Position - targetRoot.Position).Magnitude <= self:GetAttackDistance() + 1
end

function Movement:WaitForMovement()
    while self.IsMoving do
        if self.Destroyed then return false end
        task.wait(0.05)
    end
    return true
end

function Movement:Stop()
    self:Cancel()
end

function Movement:Destroy()
    self:Cancel()
    self.Destroyed = true
end

return Movement
