local addon, OTR = ...

local api = {}
OTR.api = api
local BigNum = OTR.BigNum
api.v2 = {}

-- Vires in numeris, 1024 bit (TODO: https://datatracker.ietf.org/doc/html/rfc3526#section-3)
api.v2.prime = BigNum.new("1522605027922533360535618378132637429718068114961380688657908494580122963258952897654000350692006139") --138906510677011891929592526950652639230206605539989724821445378383957431108810776885337490647001125862737696358886844639523156958002155026797141586656698076850836605519143529711779461131498229669823806930874057768070744659329846993687078442187495466253952387056074335580898174981611057828352967545621549843561")
api.v2.generator = BigNum.new("2")

api.pubkey = nil

--local pubkey, privkey; -- = api.v2.generateKeys()
local privkey = nil

local debug = OTR.debug

-- poor man's symetric encryption
-- TODO: look into https://github.com/Egor-Skriptunoff/pure_lua_SHA
local function encryptCBC(data, key)
    local encrypted = ""
    local keyLength = 16 --#key
    local dataIndex = 1
    
    local iv = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 
                0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}

    for i = 1, #data do
        local byte = string.byte(data, i)

        local ivByte = iv[dataIndex]
        byte = bit.bxor(byte, ivByte)
        iv[dataIndex] = byte
        local keyByte = string.byte(key, dataIndex)
        local encryptedByte = bit.bxor(byte, keyByte)
        encrypted = encrypted .. string.char(encryptedByte)

        dataIndex = dataIndex + 1
        if dataIndex > keyLength then
            dataIndex = 1
        end
    end

    return encrypted
end
local function decryptCBC(data, key)
    local decrypted = ""
    local keyLength = 16
    local dataIndex = 1

    local iv = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 
                0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}

    for i = 1, #data do
        local encryptedByte = string.byte(data, i)
        local keyByte = string.byte(key, dataIndex)
        local byte = bit.bxor(encryptedByte, keyByte)
        local ivByte = iv[dataIndex]
        local originalByte = bit.bxor(byte, ivByte)
        decrypted = decrypted .. string.char(originalByte)
        iv[dataIndex] = byte

        dataIndex = dataIndex + 1
        if dataIndex > keyLength then
            dataIndex = 1
        end
    end

    return decrypted
end
local function bignum_mod(a, b)
    local q = BigNum.new()  -- quotient (discarded)
    local r = BigNum.new()  -- remainder (this is what we want)
    BigNum.div(a, b, q, r)
    return r
end
local function modexp(base, exponent, modulus)
    local one = BigNum.new("1")
    local zero = BigNum.new("0")
    local two = BigNum.new("2")
    local result = one

    base = bignum_mod(base, modulus)

    local count = 0
    while not BigNum.le(exponent, zero) do --BigNum.gt(exponent, zero) do -- exponent > 0
        count = count + 1
        if BigNum.eq(bignum_mod(exponent, two), one) then --if exponent % 2 == 1 then
            result = bignum_mod(result * base, modulus)
        end
        base = bignum_mod(base * base, modulus)
        newexp = BigNum.new()
        BigNum.div(exponent, two, newexp, BigNum.new()) -- newexp = exponent // 2
        exponent = newexp
    end

    return result
end
-- TODO: figure out proper RNG, or ATLEAST use
-- something that is not predictable?
local function unsecureRandomBigNum(bits)
    local digits = math.ceil(bits / 3.32)  -- log2(10) ≈ 3.32
    local s = {}
    table.insert(s, math.random(1, 9))
    for _ = 2, digits do
       table.insert(s, math.random(0, 9))
    end

    return BigNum.new(table.concat(s))
end

-- #=================#
-- #      api V2     #
-- #=================#

api.v2.encrypt = function(string, key)
   local derivedKey = OTR.md5.sumhexa(tostring(key))
   return encryptCBC(string, derivedKey)
end

api.v2.decrypt = function(string, key)
    local derivedKey = OTR.md5.sumhexa(tostring(key))
   return decryptCBC(string, derivedKey)
end

-- Key generation (like Diffie-Hellman)
api.v2.generateKeys = function()
   local priv = unsecureRandomBigNum(100) --unsecureRandomBigNum(1536) -- TODO: secure rng!!!
   local pub = modexp(api.v2.generator, priv, api.v2.prime)
   return pub, priv
end

api.v2.OnCommandReceive = function(commMessage, distribution, sender, guid)
    -- TODO: ignore self (soon-ish)

    if distribution ~= "WHISPER" then
        return
    end

    local opcode = string.sub(commMessage, 1, 4)

    if opcode == "PBSY" then
        -- what??

    elseif opcode == "PACK" then
        -- good, target is computing? if version not missmatch?
        if debug then
            print("recv PACK from", sender)
        end
        local _, res = pcall(tonumber, string.sub(commMessage, 5))
        if res == nil then res = -1 end

        if debug then
            print("recv PACK from", sender, "with version", res)
        end
        
        OTR.keys.setPlayerVersion(sender, res)

        --print("SET playerVersions['" .. name .. "'] =", res)
    elseif opcode == "PUBK" then
        -- send PUBK ACK to let know we computing!
        local pubkeyAckMsg = string.format("PACK%04d", OTR.protocolVersion) 
        C_ChatInfo.SendAddonMessage(OTR.addonPrefix, pubkeyAckMsg, distribution, sender) 

        if debug then
            print("Replied with PACK to", sender)
        end
        
        -- eh, next frame cuz why not?
        local pubkeySender = string.sub(commMessage, 5)
        if pubkeySender == nil or pubkeySender == "" then
            if debug then
                print("Error, pubkeySend invalid. Old version?")
                return
            else
                print("nil on pubkeySender")
                return
            end
        end

        if debug then
            print("[PUBK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
        end

        -- check our own key here?
        if api.pubkey == nil then
            local a, b = api.generateKeys()
            api.pubkey = a
            privkey = b --api.v2.generateKeys()
        end

        -- TODO proper error handeling?
        local pubkeySender = BigNum.new(pubkeySender)
        local sharedKeyB = modexp(pubkeySender, privkey, api.v2.prime)

        OTR.keys.add(sender, sharedKeyB)
        
        if debug then
            print("[PUBK]: Shared Key: " .. tostring(sharedKeyB))
            print("[PUBK]: Sending PUBK (" .. tostring(api.pubkey) .. ") to " .. sender)
        end

        local pubkeyMsg = "PKOK" .. tostring(api.pubkey)
        C_ChatInfo.SendAddonMessage(OTR.addonPrefix, pubkeyMsg, distribution, sender)
    elseif opcode == "PKOK" then
        local pubkeySender = string.sub(commMessage, 5)

        if debug then
            print("[PKOK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
        end

        local sharedKeyA = modexp(BigNum.new(pubkeySender), privkey, api.v2.prime)

        if debug then
            print("[PKOK]: Shared key: " .. tostring(sharedKeyA))
        end

        OTR.keys.add(sender, sharedKeyA)

    elseif opcode == "OTRW" then
        local encryptedMessage = string.sub(commMessage, 5)
        local key = OTR.keys.get(sender)
        if key == nil then
            -- bad! exchange again? or this is failure?
            print("[OTRW] Failed decrypting message from " .. sender)
        end

        -- decrypt?
        local decryptedMessage = api.v2.decrypt(encryptedMessage, key)
        if debug then
            print("[OTRW] " .. sender .. " encrypted: " .. string.sub(commMessage, 5))
            print("[OTRW] " .. sender .. " whispers: " .. decryptedMessage)
        end

        OTR.spoofOTRWhisper(decryptedMessage, sender, false)
    end

end

api.generateKeys = function()
    api.pubkey, privkey = api.v2.generateKeys()
end