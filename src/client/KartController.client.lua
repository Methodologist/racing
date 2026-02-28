-- KartController.client.lua
-- Handles input, raycast suspension, drift, air control (Cross-Platform)

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService") -- NEW: For mobile buttons & gamepad
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RemotesModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local Remotes = require(RemotesModule)
local LocalPlayer = Players.LocalPlayer

-- NEW: Get the Player's Control Module for cross-platform movement
local PlayerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

local raceStarted = false
local KartConfig = require(ReplicatedStorage.Shared:WaitForChild("KartConfig"))

local kart = nil
local root = nil

local driveSeat = nil
local currentSmoothSteer = 0

local function waitForKart()
    local kartName = LocalPlayer.Name .. "_Kart"
    kart = Workspace:WaitForChild(kartName, 60)
    
    if kart then
        -- 🟢 FIX: Fallback to any BasePart if PrimaryPart is delayed by network lag
        root = kart.PrimaryPart or kart:FindFirstChildWhichIsA("BasePart")
        while not root do
            task.wait(0.1)
            root = kart.PrimaryPart or kart:FindFirstChildWhichIsA("BasePart")
        end
        kart.PrimaryPart = root 
        
        driveSeat = kart:FindFirstChildWhichIsA("VehicleSeat", true) or kart:FindFirstChildWhichIsA("Seat", true)


        local glideForce = Instance.new("VectorForce")
        glideForce.Name = "AntiGravityForce"
        
        local attachment = root:FindFirstChild("CenterAttachment") 
        if not attachment then
            attachment = Instance.new("Attachment", root)
            attachment.Name = "CenterAttachment"
        end
        glideForce.Attachment0 = attachment
        glideForce.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * 0.45, 0) 
        glideForce.Enabled = false
        glideForce.Parent = root
    end
end

local function getInput()
    if not raceStarted then 
        -- Spam warning to let you know the script is stuck waiting
        -- print("DEBUG: Waiting for race to start...") 
        return 0, 0 
    end

    local move = 0
    local targetSteer = 0
    
    -- 🟢 FIX: If in a VehicleSeat, read from the seat. Otherwise, use PlayerModule.
    if driveSeat and driveSeat:IsA("VehicleSeat") then
        move = driveSeat.ThrottleFloat
        targetSteer = driveSeat.SteerFloat
    else
        local moveVector = Controls:GetMoveVector()
        move = -moveVector.Z
        targetSteer = moveVector.X 
    end
    
    -- 📱 MOBILE OPTIMIZATION: Smooth the steering
    currentSmoothSteer = currentSmoothSteer + (targetSteer - currentSmoothSteer) * 0.15
    
    -- Deadzone snap
    if math.abs(move) < 0.05 then move = 0 end
    if math.abs(currentSmoothSteer) < 0.01 then currentSmoothSteer = 0 end

    return move, currentSmoothSteer
end

local function applySuspension(deltaTime)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {kart}
    
    -- 🛞 THE GLIDER FIX: How thick the invisible suspension ball is.
    -- Set to 0.6 so it bridges cracks but doesn't accidentally hit guardrails beside you.
    local wheelRadius = 0.6 
    
    for name, offset in pairs(KartConfig.WheelOffset) do
        local wheelPos = root.CFrame:PointToWorldSpace(offset)
        local direction = -root.CFrame.UpVector * KartConfig.SuspensionLength
        
        -- UPGRADE: Using Spherecast instead of Raycast!
        local result = Workspace:Spherecast(wheelPos, wheelRadius, direction, params)

        if result then
            local hitDistance = result.Distance
            local compression = math.max(0, KartConfig.SuspensionLength - hitDistance)
            
            local upVector = root.CFrame.UpVector 
            local wheelVelocity = root:GetVelocityAtPosition(wheelPos)
            local suspensionVelocity = wheelVelocity:Dot(upVector)
            
            -- Calculate the raw spring force
            local force = (compression * KartConfig.SuspensionStiffness) - (suspensionVelocity * KartConfig.SuspensionDamping)
            
            -- 🛡️ THE ANTI-LAUNCH FIX (CORRECTED)
            -- Raised to 600 so it can easily catch the kart when it drops from the sky,
            -- but still prevents the 10,000+ force spikes that cause random orbit launches!
            local maxSafeForce = 600 
            force = math.clamp(force, 0, maxSafeForce)
            
            if force > 0 then
                local impulseVector = upVector * (force * (root.AssemblyMass / 4) * deltaTime)
                root:ApplyImpulseAtPosition(impulseVector, wheelPos)
            end
        end
    end
end

local function applyAutoRighting(deltaTime)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {kart}
    
    -- We shoot a laser straight down from the center to find the "average" angle of the road
    local ray = Workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params)
    local targetUpVector = Vector3.new(0, 1, 0) 
    
    if ray then targetUpVector = ray.Normal end

    local currentUpVector = root.CFrame.UpVector
    local tiltAxis = currentUpVector:Cross(targetUpVector)
    
    -- 🛸 THE HOVER FIX (CORRECTED)
    -- 1200 is the sweet spot. Strong enough to ignore bumps, gentle enough not to explode.
    local rightingTorque = tiltAxis * 1200 * root.AssemblyMass * deltaTime
    
    local currentSpin = root.AssemblyAngularVelocity
    local dampingTorque = Vector3.new(currentSpin.X, 0, currentSpin.Z) * -50 * root.AssemblyMass * deltaTime
    
    root:ApplyAngularImpulse(rightingTorque + dampingTorque)
end

local function applyDrive(move, steer, deltaTime)
    local forward = root.CFrame.LookVector
    local right = root.CFrame.RightVector
    local velocity = root.AssemblyLinearVelocity
    local lateral = velocity:Dot(right)
    local currentSpeed = velocity.Magnitude 
    
    if move ~= 0 then
        local maxSpeed = KartConfig.TopSpeed or 150 
        if currentSpeed < maxSpeed then
            -- 🏎️ UPGRADED HILL CLIMB MATH
            local slopeAssist = 1
            local gravityCounter = 0
            
            if forward.Y > 0 then
                -- Cranked up the base assist so the engine revs harder on inclines
                slopeAssist = 1 + (forward.Y * 3.5) 
                -- Dynamically calculate and cancel out the exact gravity pulling you backwards
                gravityCounter = workspace.Gravity * forward.Y * 1.5 
            end
            
            -- Combine base acceleration, slope assist, and the anti-gravity push
            local finalAccelPower = (KartConfig.Acceleration * slopeAssist) + gravityCounter
            local accel = forward * move * finalAccelPower * deltaTime
            
            root:ApplyImpulse(accel * root.AssemblyMass)
        end
    end

    if not airborne then
        local velocity = root.AssemblyLinearVelocity
        local currentSpeed = velocity.Magnitude
        
        -- 🏎️ DYNAMIC STEERING: Reduce turn power at high speeds
        -- This prevents the "twitchy" feeling when going fast on mobile.
        local speedFactor = math.clamp(1 - (currentSpeed / (KartConfig.TopSpeed * 1.2)), 0.5, 1)
        
        local steerAmount = steer * (driftState and 1.5 or 1) * speedFactor
        local currentSpin = root.AssemblyAngularVelocity.Y
        
        local turnForce = KartConfig.TurnSpeed or 75
        local dampingForce = KartConfig.TurnDamping or 35
        
        local steerTorque = steerAmount * -turnForce
        local spinDamping = currentSpin * dampingForce 
        local finalYTorque = (steerTorque - spinDamping) * root.AssemblyMass * deltaTime
        
        root:ApplyAngularImpulse(Vector3.new(0, finalYTorque, 0))
    end

    local friction = driftState and KartConfig.DriftFriction or KartConfig.NormalFriction
    local gripMultiplier = driftState and 15 or 45
    
    if steer == 0 and not driftState then
        gripMultiplier = 85 
    end
    
    local maxStopImpulse = math.abs(lateral * root.AssemblyMass)
    local desiredImpulse = friction * gripMultiplier * root.AssemblyMass * deltaTime
    local safeImpulse = math.min(desiredImpulse, maxStopImpulse)
    
    local lateralFriction = -right * safeImpulse * math.sign(lateral)
    root:ApplyImpulse(lateralFriction)
    
    if not airborne then
        -- Lowered the downforce multiplier slightly so it doesn't glue you to ramps too hard
        local downforceMag = currentSpeed * 1.8 
        local downforceImpulse = -root.CFrame.UpVector * downforceMag * root.AssemblyMass * deltaTime
        root:ApplyImpulse(downforceImpulse)
    end
end

-- NEW: Cross-Platform Action Handler
local function handleKartActions(actionName, inputState, inputObject)
    if not raceStarted then return Enum.ContextActionResult.Pass end

    if actionName == "KartDrift" then
        if inputState == Enum.UserInputState.Begin then
            if not airborne and root then
                root:ApplyImpulse(Vector3.new(0, KartConfig.HopForce, 0))
                print("Hopped!")
            end
            driftState = true
            driftStart = tick()
            
        elseif inputState == Enum.UserInputState.End then
            if driftState then
                driftState = false
                if tick() - driftStart > 0.5 then
                    driftBoostReady = true
                end
            end
        end
        return Enum.ContextActionResult.Sink
        
    elseif actionName == "KartBoostItem" then
        if inputState == Enum.UserInputState.Begin then
            Remotes.ApplyBoost:FireServer() 
        end
        return Enum.ContextActionResult.Sink
    end
    
    return Enum.ContextActionResult.Pass
end

local function applyDriftBoost()
    if driftBoostReady then
        root:ApplyImpulse(root.CFrame.LookVector * KartConfig.DriftBoostPower * root.AssemblyMass)
        driftBoostReady = false
    end
end

-- FIX: Updated to use 'move' and 'steer' instead of hardcoded WASD
local function applyAirControl(move, steer, deltaTime)
    if airborne then
        -- We route the move (forward/backward) to pitch, and steer to yaw
        local torque = Vector3.new(move, 0, steer) * KartConfig.AirControlTorque
        root:ApplyAngularImpulse(torque * 10 * root.AssemblyMass * deltaTime)
    end
end

local function updateAirborne()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {kart}
    
    local rayLength = KartConfig.SuspensionLength + 3
    local ray = Workspace:Raycast(root.Position, Vector3.new(0, -rayLength, 0), params)
    
    airborne = not ray
    
    local glideForce = root:FindFirstChild("AntiGravityForce")
    if glideForce then
        if airborne then
            glideForce.Enabled = true
        else
            glideForce.Enabled = false
        end
    end
end

local function updateEngineSound()
    -- Look for the sound object inside the kart's root part
    local engineSound = root:FindFirstChild("EngineSound", true)
    
    if engineSound then
        if not engineSound.IsPlaying then
            engineSound:Play()
        end
        -- Dynamically shift the pitch based on the kart's velocity
        local speed = root.AssemblyLinearVelocity.Magnitude
        local pitch = 1 + (speed / 100)
        engineSound.PlaybackSpeed = math.clamp(pitch, 1, 2.5)
    end
end

local function onHeartbeat(deltaTime)
    if not kart or not kart.Parent then return end 
    
    local move, steer = getInput()
    
    -- [Existing updates...]
    updateAirborne()
    applySuspension(deltaTime) 
    applyAutoRighting(deltaTime) 
    applyDrive(move, steer, deltaTime) 
    updateEngineSound()
    
    -- 🎥 AUTO-CENTER CAMERA (Optional but great for Mobile)
    if move ~= 0 or steer ~= 0 then
        local camera = workspace.CurrentCamera
        local targetCFrame = CFrame.new(root.Position) * root.CFrame.Rotation * CFrame.new(0, 5, 15)
        camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(targetCFrame.p, root.Position), 0.1)
    end
end

local function init()
    print("DEBUG: Controller initializing...")

    -- 🟢 FIX: Connect events FIRST so we never miss the signal while waiting for the kart
    Remotes.RaceGo.OnClientEvent:Connect(function()
        raceStarted = true
        print("DEBUG: RaceGo received! raceStarted is now TRUE")
    end)

    Remotes.RaceFinished.OnClientEvent:Connect(function()
        raceStarted = false 
        ContextActionService:UnbindAction("KartDrift")
        ContextActionService:UnbindAction("KartBoostItem")
    end)

    -- NOW wait for the kart
    waitForKart()
    
    if not kart or not root then
        warn("CRITICAL: Kart not found for player! Controls will not load.")
        return 
    end
    
    ContextActionService:BindAction("KartDrift", handleKartActions, true, Enum.KeyCode.Space, Enum.KeyCode.ButtonR1)
    ContextActionService:SetTitle("KartDrift", "Drift")
    ContextActionService:SetPosition("KartDrift", UDim2.new(1, -120, 1, -120)) 
    
    ContextActionService:BindAction("KartBoostItem", handleKartActions, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1)
    ContextActionService:SetTitle("KartBoostItem", "Use Item")
    ContextActionService:SetPosition("KartBoostItem", UDim2.new(1, -120, 1, -220)) 
    
    RunService.Heartbeat:Connect(onHeartbeat)
    print("DEBUG: Heartbeat loop started! Controls are active.")
end

Remotes.RaceFinished.OnClientEvent:Connect(function()
    raceStarted = false 
    -- NEW: Clean up the mobile UI when the race is done
    ContextActionService:UnbindAction("KartDrift")
    ContextActionService:UnbindAction("KartBoostItem")
end)

init()
return {}