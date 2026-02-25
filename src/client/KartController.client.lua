-- KartController.client.lua
-- Handles input, raycast suspension, drift, air control

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local KartConfig = require(ReplicatedStorage.Shared:WaitForChild("KartConfig"))

local kart = nil
local root = nil

local function waitForKart()
    local kartName = LocalPlayer.Name .. "_Kart"
    kart = Workspace:WaitForChild(kartName, 60)
    
    if kart then
        while not kart.PrimaryPart do
            task.wait(0.1)
        end
        root = kart.PrimaryPart
        print("Kart successfully linked to client!")
    end
end

local driftState = false
local driftDirection = 0
local airborne = false
local driftStart = 0
local driftBoostReady = false

local function getInput()
    local move = 0
    local steer = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = -1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then steer = -1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then steer = 1 end
    return move, steer
end

local function applySuspension(deltaTime)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {kart}
    
    for name, offset in pairs(KartConfig.WheelOffset) do
        local wheelPos = root.CFrame:PointToWorldSpace(offset)
        local direction = -root.CFrame.UpVector * KartConfig.SuspensionLength
        local result = Workspace:Raycast(wheelPos, direction, params)

        if result then
            local hitDistance = (wheelPos - result.Position).Magnitude
            local compression = math.max(0, KartConfig.SuspensionLength - hitDistance)
            
            local upVector = Vector3.new(0, 1, 0) 
            local wheelVelocity = root:GetVelocityAtPosition(wheelPos)
            local suspensionVelocity = wheelVelocity:Dot(upVector)
            
            local force = (compression * KartConfig.SuspensionStiffness) - (suspensionVelocity * KartConfig.SuspensionDamping)
            
            if force > 0 then
                local impulseVector = upVector * (force * (root.AssemblyMass / 4) * deltaTime)
                root:ApplyImpulseAtPosition(impulseVector, wheelPos)
            end
        end
    end
end

-- FIX: deltaTime added to prevent infinite helicopter spinning!
local function applyAutoRighting(deltaTime)
    local upVector = root.CFrame.UpVector
    local worldUp = Vector3.new(0, 1, 0)
    
    if airborne or upVector:Dot(worldUp) < 0.7 then
        local tiltAxis = upVector:Cross(worldUp)
        local rightingTorque = tiltAxis * 300 * root.AssemblyMass * deltaTime
        local currentSpin = root.AssemblyAngularVelocity
        local dampingTorque = Vector3.new(currentSpin.X, 0, currentSpin.Z) * -20 * root.AssemblyMass * deltaTime
        
        root:ApplyAngularImpulse(rightingTorque + dampingTorque)
    end
end

local function applyDrive(move, steer, deltaTime)
    local forward = root.CFrame.LookVector
    local right = root.CFrame.RightVector
    local velocity = root.AssemblyLinearVelocity
    local lateral = velocity:Dot(right)
    
    local currentSpeed = velocity.Magnitude 

    if move ~= 0 then
        local maxSpeed = KartConfig.TopSpeed or 80 
        
        if currentSpeed < maxSpeed then
            -- NEW: Uphill Forgiveness!
            local slopeAssist = 1
            if forward.Y > 0 then
                -- If pointing uphill, add up to 60% more engine power to fight gravity
                slopeAssist = 1 + (forward.Y * 1.6) 
            end
            
            -- Apply the slopeAssist to the final acceleration
            local accel = forward * move * KartConfig.Acceleration * slopeAssist * deltaTime
            root:ApplyImpulse(accel * root.AssemblyMass)
        end
    end

    -- STEERING & SPIN PREVENTION
    if not airborne then
        local steerAmount = steer * (driftState and 1.5 or 1)
        local currentSpin = root.AssemblyAngularVelocity.Y
        
        -- Pull from your config, or use safe fallbacks
        local turnForce = KartConfig.TurnSpeed or 75
        local dampingForce = KartConfig.TurnDamping or 35
        
        -- Calculate the smoothed-out turning force
        local steerTorque = steerAmount * -turnForce
        local spinDamping = currentSpin * dampingForce 
        
        local finalYTorque = (steerTorque - spinDamping) * root.AssemblyMass * deltaTime
        root:ApplyAngularImpulse(Vector3.new(0, finalYTorque, 0))
    end

    -- TIRE GRIP
    local friction = driftState and KartConfig.DriftFriction or KartConfig.NormalFriction
    local lateralFriction = -right * lateral * (friction * 15)
    root:ApplyImpulse(lateralFriction * root.AssemblyMass * deltaTime)
end

local function handleDriftInput()
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.W then
            local Remotes = require(ReplicatedStorage.Shared.Remotes)
            Remotes.ApplyBoost:FireServer() 
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space and driftState then
            driftState = false
            if tick() - driftStart > 0.5 then
                driftBoostReady = true
            end
        end
    end)
end

local function applyDriftBoost()
    if driftBoostReady then
        root:ApplyImpulse(root.CFrame.LookVector * KartConfig.DriftBoostPower * root.AssemblyMass)
        driftBoostReady = false
    end
end

local function applyAirControl(deltaTime)
    if airborne then
        local pitch = 0
        local yaw = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then pitch = 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then pitch = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then yaw = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then yaw = 1 end
        local torque = Vector3.new(pitch, 0, yaw) * KartConfig.AirControlTorque
        
        root:ApplyAngularImpulse(torque * 10 * root.AssemblyMass * deltaTime)
    end
end

local function updateAirborne()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {kart}
    local ray = Workspace:Raycast(root.Position, Vector3.new(0, -1, 0) * (KartConfig.SuspensionLength + 1), params)
    airborne = not ray
end

local function updateEngineSound()
    local engineSound = root:FindFirstChild("EngineSound", true)
    
    if engineSound then
        if not engineSound.IsPlaying then
            engineSound:Play()
            print("Engine sound successfully triggered by client!")
        end
        
        local speed = root.AssemblyLinearVelocity.Magnitude
        local pitch = 1 + (speed / 100)
        engineSound.PlaybackSpeed = math.clamp(pitch, 1, 2.5)
    else
        -- NEW: If it's silent because the object is missing, the Output will tell you!
        warn("DEBUG: Could not find 'EngineSound' inside the kart chassis!")
    end
end

local function onHeartbeat(deltaTime)
    -- NEW: Shut down the controller loop if the kart gets destroyed at the end of the race!
    if not kart or not kart.Parent then return end 
    
    local move, steer = getInput()
    
    updateAirborne()
    applySuspension(deltaTime) 
    applyAutoRighting(deltaTime) 
    applyDrive(move, steer, deltaTime) 
    applyAirControl(deltaTime)
    applyDriftBoost()
    
    updateEngineSound()
end

local function init()
    waitForKart()
    if not kart or not root then
        warn("Kart not found for player!")
        return
    end
    handleDriftInput()
    RunService.Heartbeat:Connect(onHeartbeat)
end

init()

return {}