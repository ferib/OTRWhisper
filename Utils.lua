local addon, OTR = ...

OTR.utils = {}

local _print = print
OTR.utils.print = function(...)
    _print("|cffFF7EFF[|cff00FAF6OTR|cffFF7EFFWhisper]:|r", ...)
end

OTR.utils.takeNameFromPlayername = function(playername)
    local t={}
    playername = string.lower(playername)
    for str in string.gmatch(playername, "([^"..'-'.."]+)") do
        table.insert(t, str)
    end
    return string.lower(t[1] or playername)
end