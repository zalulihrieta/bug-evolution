--[[
    BUG EVOLUTION
    Bug Farming Controller
    Version: 1.1.0

    Features:
    - Automatic bug target selection
    - Species filtering
    - Size priority
    - Nearest target handling
    - Random size nearest
    - Movement integration
    - Target timeout
    - Failed target cooldown

    Does NOT implement attack input.
]]

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

    self.CurrentTarget = nil
    self.CurrentStatus = "Stopped"

    self.OnStatusChanged = options.OnStatusChanged

    self.TargetTimeout = 15
    self.TargetCooldown = 3

    self.FailedTargets = {}

    return self

end

--==================================================
-- STATUS
--==================================================

function Farming:SetStatus(status, target)

    self.CurrentStatus = status

    if target then
        self.CurrentTarget = target
    end

    if self.OnStatusChanged then

        pcall(function()
            self.OnStatusChanged(status, target)
        end)

    end

    print(
        "[Bug Evolution] Bug Farm: "
        .. tostring(status)
    )

end

function Farming:GetStatus()

    return self.CurrentStatus

end

function Farming:GetCurrentTarget()

    return self.CurrentTarget

end

--==================================================
-- TARGET VALIDATION
--==================================================

function Farming:IsValidTarget(target)

    if not target then
        return false
    end

    if not target.Instance then
        return false
    end

    if not target.Instance.Parent then
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
-- TARGET SELECTION
--==================================================

function Farming:GetNextTarget()

    local species =
        self.Settings.SelectedSpecies or "All Bugs"

    local priority =
        self.Settings.SizePriority or "Largest First"

    local bugs = self.Scanner:GetSortedBugs(
        species,
        priority
    )

    for _, bug in ipairs(bugs) do

        if self:IsValidTarget(bug)
            and not self:IsOnCooldown(bug) then

            return bug

        end

    end

    return nil

end

--==================================================
-- WAIT FOR TARGET
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

        task.wait(0.25)

    end

    return false

end

--==================================================
-- PROCESS TARGET
--==================================================

function Farming:ProcessTarget(target)

    if not self:IsValidTarget(target) then
        return
    end

    local instance = target.Instance

    self:SetStatus(
        "Moving",
        target
    )

    -- Approach target.

    if not self.Movement:IsInRange(instance) then

        local success = self.Movement:MoveTo(instance)

        if not success then

            self:AddCooldown(target)

            return

        end

        self.Movement:WaitForMovement()

    end

    if not self.Running then
        return
    end

    if not self:IsValidTarget(target) then
        return
    end

    -- Wait for the game's own farming mechanics.

    self:SetStatus(
        "Farming",
        target
    )

    local completed = self:WaitForTarget(target)

    if not completed then

        self:AddCooldown(target)

    end

end

--==================================================
-- MAIN LOOP
--==================================================

function Farming:Run()

    while self.Running do

        local success, err = pcall(function()

            local target = self:GetNextTarget()

            if target then

                self:ProcessTarget(target)

            else

                self.CurrentTarget = nil

                self:SetStatus("Idle")

                task.wait(1)

            end

        end)

        if not success then

            warn(
                "[Bug Evolution] Farming Error: "
                .. tostring(err)
            )

            self:SetStatus("Error")

            task.wait(1)

        end

    end

    self.CurrentTarget = nil

    self:SetStatus("Stopped")

end

--==================================================
-- START
--==================================================

function Farming:Start()

    if self.Running then
        return
    end

    if self.Destroyed then
        return
    end

    self.Running = true

    self:SetStatus("Starting")

    task.spawn(function()
        self:Run()
    end)

end

--==================================================
-- STOP
--==================================================

function Farming:Stop()

    self.Running = false

    self.Movement:Stop()

    self.CurrentTarget = nil

    self:SetStatus("Stopped")

end

--==================================================
-- TOGGLE
--==================================================

function Farming:Toggle(enabled)

    if enabled then
        self:Start()
    else
        self:Stop()
    end

end

--==================================================
-- DESTROY
--==================================================

function Farming:Destroy()

    self:Stop()

    self.Destroyed = true

end

return Farming