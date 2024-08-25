
---FLinearColor constructor
---@param Red float?
---@param Green float?
---@param Blue float?
---@param Alpha float?
---@return FLinearColor
function FLinearColor(Red, Green, Blue, Alpha)
    Red = Red or 1.0
    Green = Green or 1.0
    Blue = Blue or 1.0
    Alpha = Alpha or 1.0
    return {
        R = Red,
        G = Green,
        B = Blue,
        A = Alpha
    }
end

---@type { [string]: FLinearColor }
local LinearColors = {}

LinearColors.White = FLinearColor()
LinearColors.Black = FLinearColor(0, 0, 0, 1)
LinearColors.Red = FLinearColor(1, 0, 0, 1)
LinearColors.Green = FLinearColor(0, 1, 0, 1)
LinearColors.Blue = FLinearColor(0, 0, 1, 1)

return LinearColors