
local currentDir = debug.getinfo(1, "S").source:match("@(.+\\)LogDebug.lua")
if currentDir then
    package.path = package.path .. ';' .. currentDir .. '?.lua'
    require("BaseUtils")
end

---@param MovementComponent UMovementComponent
---@param Prefix string?
function LogMovementComponent(MovementComponent, Prefix)
    if not MovementComponent or not MovementComponent:IsValid() then return end
    Prefix = Prefix or ""

    local velocity = VectorToTable(MovementComponent.Velocity)
    LogDebug(Prefix .. "Current Speed: ", GetKismetMathLibrary():VSize(velocity))
    LogDebug(Prefix .. "Velocity: " .. VectorToString(velocity))
    LogDebug(Prefix .. "GetMaxSpeed: ", MovementComponent:GetMaxSpeed())
    LogDebug(Prefix .. "GetGravityZ: ", MovementComponent:GetGravityZ())
end

---@param MovementComponent UCharacterMovementComponent
---@param Prefix string?
function LogCharacterMovementComponent(MovementComponent, Prefix)
    if not MovementComponent or not MovementComponent:IsValid() then return end
    Prefix = Prefix or ""

    LogDebug(Prefix .. "GravityScale: ", MovementComponent.GravityScale)
    -- LogDebug(Prefix .. "MaxStepHeight: ", MovementComponent.MaxStepHeight)
    LogDebug(Prefix .. "JumpZVelocity: ", MovementComponent.JumpZVelocity)
    LogDebug(Prefix .. "GravityDirection: " .. VectorToString(MovementComponent.GravityDirection))
    LogDebug(Prefix .. "MovementMode (enum 0-6): ", MovementComponent.MovementMode)
    LogDebug(Prefix .. "MaxWalkSpeed: ", MovementComponent.MaxWalkSpeed)
    LogDebug(Prefix .. "MaxWalkSpeedCrouched: ", MovementComponent.MaxWalkSpeedCrouched)
    LogDebug(Prefix .. "MaxSwimSpeed: ", MovementComponent.MaxSwimSpeed)
    LogDebug(Prefix .. "MaxFlySpeed: ", MovementComponent.MaxFlySpeed)
    LogDebug(Prefix .. "MaxCustomMovementSpeed: ", MovementComponent.MaxCustomMovementSpeed)
    LogDebug(Prefix .. "MaxAcceleration: ", MovementComponent.MaxAcceleration)
    LogMovementComponent(MovementComponent, Prefix)
end