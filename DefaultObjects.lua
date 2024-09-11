

---@type UInputSettings
local InputSettingsCache = nil
---@return UInputSettings
function GetInputSettings()
    if not InputSettingsCache or not InputSettingsCache:IsValid() then
        InputSettingsCache = StaticFindObject("/Script/Engine.Default__InputSettings") ---@type UInputSettings
    end
    return InputSettingsCache
end