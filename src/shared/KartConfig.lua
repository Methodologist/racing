-- src/shared/KartConfig.lua
local KartConfig = {}

-- NEW: Attach these to the table so the client can read them!
KartConfig.HopForce = 1000
KartConfig.DriftBoostPower = 50 -- Added this so you don't get a nil error when drifting!

KartConfig.TopSpeed = 150       -- Raised so it feels like a race
KartConfig.Acceleration = 150  -- Needs to be high to overcome the kart's mass!

-- 🛸 HOVERCRAFT SUSPENSION TUNING
KartConfig.SuspensionStiffness = 85  -- Strong enough to hold the heavy kart off the ground
KartConfig.SuspensionDamping = 35    -- Keeps that thick "pillow" feeling so it doesn't bounce
KartConfig.SuspensionLength = 2.5

KartConfig.TurnSpeed = 100     -- Slightly lower for more precision
KartConfig.TurnDamping = 45   -- Increased from 35 to stop that "dragging" feeling

-- WHEEL FIXES: Swapped Z values so Front is -Z (Standard Roblox Forward)
KartConfig.WheelOffset = {
    FrontLeft = Vector3.new(-1.1, 0, -2.1),
    FrontRight = Vector3.new(1.1, 0, -2.1),
    RearLeft = Vector3.new(-1.1, 0, 2.1),
    RearRight = Vector3.new(1.1, 0, 2.1),
}

KartConfig.Gravity = Vector3.new(0, -workspace.Gravity, 0)
KartConfig.DriftFriction = 2.5 
KartConfig.NormalFriction = 1.2
KartConfig.AirControlTorque = 15 -- Reduced to prevent wild mid-air spinning
KartConfig.TripleBoostWindows = {0.25, 0.25, 0.25}

return KartConfig