
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

---Returns FVector as string format "X: %f, Y: %f, Z: %f"
---@param Vector FVector
---@return string
function VectorToString(Vector)
    return string.format("X: %f, Y: %f, Z: %f", Vector.X, Vector.Y, Vector.Z)
end

---Converts FVector to a lua table
---@param Vector FVector
---@return table
function VectorToUserdata(Vector)
    return {
        X = Vector.X,
        Y = Vector.Y,
        Z = Vector.Z
    }
end

---Checks if FVector is equal to 0, 0, 0
---@param Vector FVector
---@return boolean
function IsEmptyVector(Vector)
    return Vector.X == 0 and Vector.Y == 0 and Vector.Z == 0
end

---Returns FVector2D as string format "X: %f, Y: %f"
---@param Vector2D FVector2D
---@return string
function Vector2DToString(Vector2D)
    return string.format("X: %f, Y: %f", Vector2D.X, Vector2D.Y)
end

---Converts FVector2D to a lua table
---@param Vector2D FVector2D
---@return table
function Vector2DToUserdata(Vector2D)
    return {
        X = Vector2D.X,
        Y = Vector2D.Y
    }
end

---Checks if FVector is equal to 0, 0
---@param Vector2D FVector2D
---@return boolean
function IsEmptyVector2D(Vector2D)
    return not Vector2D or (Vector2D.X == 0 and Vector2D.Y == 0)
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
    if MyPlayerControllerCache and MyPlayerControllerCache:IsValid() then
        return MyPlayerControllerCache
    end
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

---Finds specific UActorComponent in BlueprintCreatedComponents array
---@param Actor AActor
---@param Class UClass
---@return UActorComponent?
function GetBlueprintCreatedComponentByClass(Actor, Class)
    if Actor and Class and Actor:IsValid() and Class:IsValid() then
        for i = 1, #Actor.BlueprintCreatedComponents, 1 do
            local component = Actor.BlueprintCreatedComponents[i]
            if component:IsValid() and component:IsA(Class) then
                return component
            end
        end
    end

    return nil
end

---Returns hit actor from FHitResult, it handles the struct differance between UE4 and UE5
---@param HitResult FHitResult
---@return AActor|nil
function GetActorFromHitResult(HitResult)
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
