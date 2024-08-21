
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
    print(string.format("[Error] %s %s\n", GetModInfoPrefix(), Message))
end

function LogDebugError(Message)
    if DebugMode then
        LogError(Message)
    end
end


---comment Converts UE units (centimeter) to meters
---@param Units number
---@return number
function UnitsToM(Units)
    return Units / 100
end

---comment Converts meters to UE units (centimeter)
---@param Meters number
---@return number
function MToUnits(Meters)
    return Meters * 100
end

local MyPlayerControllerCache = nil
---Returns main APlayerController
---@return APlayerController?
function GetMyPlayerController()
    if MyPlayerControllerCache and MyPlayerControllerCache:IsValid() then return MyPlayerControllerCache end
    MyPlayerControllerCache = nil

    local playerControllers = FindAllOf("PlayerController")
    if playerControllers and type(playerControllers) == 'table' then 
        for _, controller in pairs(playerControllers) do
            if controller.Pawn:IsValid() and controller.Pawn:IsPlayerControlled() then
                MyPlayerControllerCache = controller
                break
            end
        end
    end
    
    return MyPlayerControllerCache
end

---Returns currently controlled pawn (usually the player chracter)
---@return APawn?
function GetMyPlayer()
    local playerController = GetMyPlayerController()
    local player = nil

    if playerController then
        player = playerController.Pawn
    end
    if player and player:IsValid() then
        return player
    end

    return nil
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

---Fires a line trace in front of the camera that collides with objects based on collision channel
---@param TraceChannel ECollisionChannel|number|nil (Default: 1) It's actually ETraceTypeQuery enum but ECollisionChannel members are named according to their type (0 = WorldStatic, 1 = WorldDynamic, 2 = Pawn, 3 = Visibility)
---@param LengthInM number|nil (Default: 20) Trace line length in meter 
---@return AActor|nil #Actor from hit result
function ForwardLineTraceByChannel(TraceChannel, LengthInM)
    TraceChannel = TraceChannel or 1 -- WorldDynamic
    LengthInM = LengthInM or 20.0

    local playerController = GetMyPlayerController()
    if playerController and playerController.PlayerCameraManager:IsValid() then
        local cameraManager = playerController.PlayerCameraManager
        local lookDirection = cameraManager:GetActorForwardVector()
        local lookDirOffset = GetKismetMathLibrary():Multiply_VectorFloat(lookDirection, MToUnits(LengthInM))
        local startLocation = cameraManager:GetCameraLocation()
        local endLocation = GetKismetMathLibrary():Add_VectorVector(startLocation, lookDirOffset)
        local traceColor = { R = 0, G = 0, B = 0, A = 0 }
        local worldContext = playerController
        if playerController.Pawn:IsValid() then
            -- Set Pawn as WorldContext to ignore own player with bIgnoreSelf parameter
            worldContext = playerController.Pawn
        end
        local actorsToIgnore = {}
        local outHitResult = {}
        if GetKismetSystemLibrary():LineTraceSingle(worldContext, startLocation, endLocation, TraceChannel, false, actorsToIgnore, 0, outHitResult, true, traceColor, traceColor, 0.0) then
            return GetActorFromHitResult(outHitResult)
        end
    end
    return nil
end
