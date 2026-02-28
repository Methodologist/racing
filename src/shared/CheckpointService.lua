local CheckpointService = {}
CheckpointService.__index = CheckpointService

function CheckpointService.new(checkpoints, maxLaps)
    local self = setmetatable({}, CheckpointService)
    self.checkpoints = checkpoints
    self.maxLaps = maxLaps
    self.playerData = {} -- Note: This stores data for both Players and Bot Models
    return self
end

-- This handles both human Player objects and Bot Models
function CheckpointService:InitPlayer(racerEntity)
    self.playerData[racerEntity] = {
        nextCheckpoint = 1,
        laps = 0,
        hasStarted = false, 
        finished = false
    }
end

function CheckpointService:ProcessTouch(racerEntity, checkpointPart)
    local data = self.playerData[racerEntity]
    if not data or data.finished then return end

    local checkpointIndex = table.find(self.checkpoints, checkpointPart)
    if not checkpointIndex then return end

    -- Check if they hit the correct next checkpoint in the sequence
    if checkpointIndex == data.nextCheckpoint then
        local result = "Checkpoint"

        -- 1. Check what crossing this specific line means
        if checkpointIndex == 1 then
            if data.hasStarted then
                -- They successfully looped the track!
                data.laps += 1
                
                -- Check for Win Condition
                if data.laps >= self.maxLaps then
                    data.finished = true
                    result = "Finished"
                else
                    result = "Lap"
                end
            else
                -- First time crossing the start line
                data.hasStarted = true
                result = "Checkpoint"
            end
        else
            -- Mid-track checkpoint
            result = "Checkpoint"
        end

        -- 2. Logic: Advance their target to the next physical checkpoint
        if data.nextCheckpoint == #self.checkpoints then
            data.nextCheckpoint = 1 -- Reset target to the Start/Finish line
        else
            data.nextCheckpoint += 1
        end

        return result
    end
    
    return nil
end

return CheckpointService