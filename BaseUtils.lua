
local UEHelpers = require("UEHelpers")
-- UEHelpers function shortcuts
GetKismetSystemLibrary = UEHelpers.GetKismetSystemLibrary
GetKismetMathLibrary = UEHelpers.GetKismetMathLibrary

ModName = "BaseUtils"
ModVersion = "1.0.0"
DebugMode = false

function GetModInfoPrefix()
    return string.format("[%s v%s]", ModName, ModVersion)
end

function LogInfo(Message)
    print(string.format("%s %s\n", GetModInfoPrefix(), Message))
end

function LogDebug(Message)
    if DebugMode then
        LogInfo(Message)
    end
end

function LogError(Message)
    error(string.format("%s %s\n", GetModInfoPrefix(), Message))
end

---comment Converts UE units (centimeter) to meters
---@param Units any
---@return any
function UnitsToM(Units)
    return Units / 100
end

---comment Converts meters to UE units (centimeter)
---@param Meters any
---@return any
function MToUnits(Meters)
    return Meters * 100
end

local function GetActorFromHitResult(HitResult)
    if not HitResult then return nil end

    local actor = nil
    if UnrealVersion:IsBelow(5, 0) then
        actor = HitResult.Actor:Get()
    else
        actor = HitResult.HitObjectHandle.Actor:Get()
    end

    if actor and actor:IsValid() then
        return actor
    end

    return nil
end

---comment
---@param TraceChannel ECollisionChannel? (Default: 1) It's actually ETraceTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@param LengthInM float? (Default: 20) Trace line length in meter 
---@return AActor|nil #Actor from hit result
function ForwardLineTraceByChannel(TraceChannel, LengthInM)
    TraceChannel = TraceChannel or 1 -- WorldDynamic
    LengthInM = LengthInM or 20.0

    local playerController = UEHelpers.GetPlayerController()
    if playerController and playerController.PlayerCameraManager then
        local cameraManager = playerController.PlayerCameraManager
        local lookDirection = cameraManager:GetActorForwardVector()
        local lookDirOffset = GetKismetMathLibrary():Multiply_VectorFloat(lookDirection, MToUnits(LengthInM))
        local startLocation = cameraManager:GetCameraLocation()
        local endLocation = GetKismetMathLibrary():Add_VectorVector(startLocation, lookDirOffset)
        local traceColor = { R = 0, G = 0, B = 0, A = 0 }
        local worldContext = playerController.Pawn or playerController
        local actorsToIgnore = {}
        local outHitResult = {}
        if GetKismetSystemLibrary():LineTraceSingle(worldContext, startLocation, endLocation, TraceChannel, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return nil
end