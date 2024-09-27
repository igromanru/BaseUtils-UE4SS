
---@type { [string]: FLinearColor }
local LinearColors = {}

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

LinearColors.White = FLinearColor()
LinearColors.Black = FLinearColor(0, 0, 0, 1)
LinearColors.Red = FLinearColor(1, 0, 0, 1)
LinearColors.Green = FLinearColor(0, 1, 0, 1)
LinearColors.Blue = FLinearColor(0, 0, 1, 1)

---Returns FLinearColor as string format "%f, %f, %f, %f" (R, G, B, A)
---@param LinearColor FLinearColor
---@return string
function LinearColorToString(LinearColor)
    return string.format("%f, %f, %f, %f", LinearColor.R, LinearColor.G, LinearColor.B, LinearColor.A)
end

---Compress FLinearColor to a 64-bit integer, packed as binary string
---@param color FLinearColor
---@return string compressed # Compressed FLinearColor, packed as binary string
function CompressLinearColor(color)
    -- Converts float [0, 1] to integer [0, 65535]
    local function floatToInt16(f)
        return math.floor(f * 65535 + 0.5)
    end

    local r16 = floatToInt16(color.R)
    local g16 = floatToInt16(color.G)
    local b16 = floatToInt16(color.B)
    local a16 = floatToInt16(color.A)

    return string.pack(">HHHH", r16, g16, b16, a16)
end

---Decompress 64-bit integer to FLinearColor
---@param compressed string Compressed FLinearColor, packed as binary string
---@return FLinearColor
function DecompressLinearColor(compressed)
    local r16, g16, b16, a16 = string.unpack(">HHHH", compressed)

    local function int16ToFloat(i)
        return i / 65535
    end

    return {
        R = int16ToFloat(r16),
        G = int16ToFloat(g16),
        B = int16ToFloat(b16),
        A = int16ToFloat(a16)
    }
end

return LinearColors