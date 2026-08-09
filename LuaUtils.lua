
---@param str? string
---@return boolean
function IsStringEmpty(str)
    return str == nil or str == ""
end

---@param str? string
---@return boolean
function IsStringNotEmpty(str)
    return str ~= nil and str ~= ""
end

---@param id? integer
---@return boolean
function IsValidId(id)
    return id ~= nil and id >= 0
end