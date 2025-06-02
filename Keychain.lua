local addon, OTR = ...

OTR.keys = {}
OTR.keys.keychain = {} -- TODO: add sess ID and regen after someone /reload'd
OTR.keys.playerVersions = {}
OTR.keys.playerBlacklist = {}

OTR.keys.add = function(playername, value)
    playername = OTR.utils.takeNameFromPlayername(playername)
    OTR.keys.keychain[playername] = value;
end

OTR.keys.get = function(playername)
   playername = OTR.utils.takeNameFromPlayername(playername)
   return OTR.keys.keychain[playername]
end

OTR.keys.isPlayerBlacklisted = function(playername)
    playername = OTR.utils.takeNameFromPlayername(playername)
    return OTR.keys.playerBlacklist[playername] ~= nil
end

OTR.keys.blacklistPlayer = function(playername)
    playername = OTR.utils.takeNameFromPlayername(playername)
    OTR.keys.playerBlacklist[playername] = true 
end

OTR.keys.setPlayerVersion = function(playername, version)
    playername = OTR.utils.takeNameFromPlayername(playername)
    OTR.keys.playerVersions[playername] = version
end

OTR.keys.isPlayerVersionMatch = function(playername, version)
    playername = OTR.utils.takeNameFromPlayername(playername)
    local version = OTR.keys.playerVersions[playername]
    return version ~= nil and version == OTR.protocolVersion
end

OTR.keys.isPlayerKnown = function(playername)
    playername = OTR.utils.takeNameFromPlayername(playername)
    local version = OTR.keys.playerVersions[playername]
    return version ~= nil
end

OTR.keys.getPlayerVersion = function(playername)
    playername = OTR.utils.takeNameFromPlayername(playername)
    return OTR.keys.playerVersions[playername]
end
