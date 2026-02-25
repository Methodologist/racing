-- src/shared/KartConfig.lua
local KartConfig = {}

KartConfig.TopSpeed = 80       -- Raised so it feels like a race
KartConfig.Acceleration = 150  -- Needs to be high to overcome the kart's mass!

-- SUSPENSION
KartConfig.SuspensionStiffness = 150 
KartConfig.SuspensionDamping = 15    
KartConfig.SuspensionLength = 1.5    -- Raised to 1.5 to stop the chassis from scraping!

KartConfig.TurnSpeed = 75     -- Lowered from the hardcoded 150. Controls how fast you turn.
KartConfig.TurnDamping = 35   -- Raised from 25. This "smooths out" the steering so it isn't twitchy.

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