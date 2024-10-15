

local InputSettingsCache = CreateInvalidObject()
---@return UInputSettings
function GetDefaultInputSettings()
    if not InputSettingsCache:IsValid() then
        InputSettingsCache = StaticFindObject("/Script/Engine.Default__InputSettings") ---@cast InputSettingsCache UInputSettings
    end
    return InputSettingsCache
end