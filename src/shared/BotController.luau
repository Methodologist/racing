local BotController = {}
local RunService = game:GetService("RunService")

function BotController.StartBot(botKart, checkpoints)
    local root = botKart.PrimaryPart
    if not root then return end
    
    local currentTargetIdx = 1
    
    -- 1. ANTI-FRICTION PROTOCOL (Updated to prevent Clamping Errors)
    -- 🟢 FIX: Update Section 1 (ANTI-FRICTION PROTOCOL)
    for _, part in ipairs(botKart:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.1, 0.5, 1, 1)
        end
    end

    -- 2. CREATE PHYSICS MOVERS
    local alignPos = Instance.new("AlignPosition")
    alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPos.Attachment0 = root:FindFirstChild("CenterAttachment") or Instance.new("Attachment", root)
    
    -- 🛑 THE GRAVITY LOCK FIX: Force the bot to ONLY push horizontally, never up.
    alignPos.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    alignPos.MaxAxesForce = Vector3.new(80000, 0, 80000) 
    
    alignPos.MaxVelocity = 120
    alignPos.Responsiveness = 8
    alignPos.Parent = root

    local alignOri = Instance.new("AlignOrientation")
    alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOri.Attachment0 = alignPos.Attachment0
    alignOri.MaxTorque = 80000
    alignOri.Responsiveness = 10 -- Lowered to smooth out their steering
    alignOri.Parent = root

    local timeStuck = 0
    local lastPos = root.Position

    -- 3. THE AI BRAIN LOOP
    local connection
    connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not botKart.Parent or not root then
            connection:Disconnect()
            return
        end

        local targetPart = checkpoints[currentTargetIdx]
        if targetPart then
            -- ⬇️ 1. THE ANTI-GRAVITY FIX
            -- By setting the Target's Y to match the Bot's current Y, 
            -- AlignPosition will ONLY pull them horizontally. Gravity handles the rest!
            local targetPos = Vector3.new(targetPart.Position.X, root.Position.Y, targetPart.Position.Z)

            -- 📡 2. DYNAMIC OBSTACLE AVOIDANCE
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {botKart}

            local lookDir = root.CFrame.LookVector
            local rightDir = root.CFrame.RightVector
            
            local whiskers = {
                lookDir * 40,                                  -- Center
                (lookDir * 0.8 + rightDir * 0.6).Unit * 25,    -- Right
                (lookDir * 0.8 - rightDir * 0.6).Unit * 25     -- Left
            }

            for _, direction in ipairs(whiskers) do
                local rayResult = workspace:Raycast(root.Position, direction, rayParams)
                if rayResult and rayResult.Instance.Name == "Smooth Block Model" then
                    if math.abs(rayResult.Normal.Y) < 0.5 then
                        targetPos = targetPos + (rayResult.Normal * 30) -- Steer away
                        break
                    end
                end
            end

            -- Apply the grounded target position
            alignPos.Position = targetPos
            
            local lookAtPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
            alignOri.CFrame = CFrame.lookAt(root.Position, lookAtPos)

            -- 🛸 3. BOT VOID CATCH & PHYSICS RESET
            local isOffTrack = root.Position.Y < -100

            -- 🛑 STUCK DETECTION
            local speed = (root.Position - lastPos).Magnitude / deltaTime
            lastPos = root.Position
            
            if speed < 10 then 
                timeStuck += deltaTime
            else
                timeStuck = 0
            end

            -- RECOVERY PROTOCOL
            if isOffTrack or timeStuck > 2.0 then
                -- CRITICAL: Zero out velocity so they don't bounce upon teleporting
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                
                botKart:PivotTo(targetPart.CFrame * CFrame.new(0, 5, 0))
                timeStuck = 0
            end

            -- 🏁 CHECKPOINT HIT DETECTION (Expanded radius to 35 for fast-moving bots)
            local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetPart.Position.X, 0, targetPart.Position.Z)).Magnitude
            
            if dist < 35 then 
                currentTargetIdx += 1
                if currentTargetIdx > #checkpoints then
                    currentTargetIdx = 1
                end
            end
        end
    end)
    
    return connection
end

return BotController