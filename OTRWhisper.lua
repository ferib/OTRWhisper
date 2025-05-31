local addon = OTRWhisper

local addonPrefix = "OTRWhisper" .. "P0C";

local protocolVersion = 2
local bignum = _G.BigNumber
local chatFrames = {} -- temp?

-- #==============#
-- #   Settings   #
-- #==============#

--Settings_FriendListOnly = false
--Settings_ForceOTR = false
local debug = false --IsGMClient()

local _print = print
local function print(...)
    _print("|cffFF7EFF[|cff00FAF6OTR|cffFF7EFFWhisper]:|r", ...)
end

-- poor symetric encryption
local function encryptDecrypt(data, key)
    local encrypted = ""
    local keyLength = #key
    local dataIndex = 1

    for i = 1, #data do
        local byte = string.byte(data, i)
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

-- wrapper, soonTM
local function encrypt(string, key)
   return encryptDecrypt(string, tostring(key))
end

local function decrypt(string, key)
   return encryptDecrypt(string, tostring(key))
end

local function takeNameFromPlayername(playername)
    local t={}
    for str in string.gmatch(playername, "([^"..'-'.."]+)") do
        table.insert(t, str)
    end
    return t[1] or playername
end

local function SendOTRWhisperToFrame(chatFrame, message, sender, isSender)
   -- NOTE: see ChatFrame_MessageEventHandler
   --chatFrame:GetScript("OnEvent")(chatFrame, event, ...); -- TODO: Fire the event for the frame.

   if ( chatFrame.privateMessageList and not chatFrame.privateMessageList[strlower(takeNameFromPlayername(sender))] ) then
      return;
   elseif ( chatFrame.excludePrivateMessageList and chatFrame.excludePrivateMessageList[strlower(takeNameFromPlayername(sender))] ) then
      return;
   end

    local arg1 = message
    local arg2, arg11, arg13 = arg2, 0, 0
    local msgTime = time();
    local playerName, lineID, bnetIDAccount = arg2, arg11, arg13;

    local function MessageFormatter(msg)
        local fontHeight = select(2, FCF_GetChatWindowInfo(chatFrame:GetID()));
        if ( fontHeight == 0 ) then
            fontHeight = 14;
        end

        -- Add AFK/DND flags
        local pflag = "<OTR>" --GetPFlag(arg6, arg7, arg8); -- NONE?

        local showLink = 1;
        msg = gsub(msg, "%%", "%%%%");

        -- Search for icon links and replace them with texture links.
        --msg = C_ChatInfo.ReplaceIconAndGroupExpressions(msg, false, not ChatFrame_CanChatGroupPerformExpressionExpansion("WHISPER"));

        --Remove groups of many spaces
        msg = RemoveExtraSpaces(msg);

        -- NOTE: No GUID so no colors?
        --local playerLink = "[|cffffffff" .. sender .. "|r]";
        local playerLink = "[|cff00FF98" .. GetPlayerLink(sender, sender, 0, "WHISPER", sender) .. "|r]"
        local playerLinkDisplayText = coloredName;
        local relevantDefaultLanguage = chatFrame.defaultLanguage;

        local message = msg;

        local outMsg;
        if isSender then
            outMsg = format(_G["CHAT_WHISPER_INFORM_GET"] .. message, pflag .. playerLink);
        else
            outMsg = format(_G["CHAT_WHISPER_GET"] .. message, pflag .. playerLink);
        end

        --Add Timestamps
        local chatTimestampFmt = nil
        if GetChatTimestampFormat then
            chatTimestampFmt = GetChatTimestampFormat(); -- Retail Only?
        end
        if ( chatTimestampFmt ) then
            outMsg = BetterDate(chatTimestampFmt, msgTime)..outMsg;
        end

        return outMsg;
    end

    -- NOTE: Classic no has :( ?
    --local isChatLineCensored = C_ChatInfo.IsChatLineCensored(lineID);

    --local msg = isChatLineCensored and arg1 or MessageFormatter(arg1);
    local msg = MessageFormatter(arg1)
    --print("TEST: " .. msg)

    local accessID = ChatHistory_GetAccessID("WHISPER", takeNameFromPlayername(sender));

    local arg12 = nil -- ?
    local typeID = ChatHistory_GetAccessID("WHISPER", takeNameFromPlayername(sender), arg12 or arg13);

    -- The message formatter is captured so that the original message can be reformatted when a censored message
    -- is approved to be shown. We only need to pack the event args if the line was censored, as the message transformation
    -- step is the only code that needs these arguments. See ItemRef.lua "censoredmessage".
    local eventArgs = {};
    --if isChatLineCensored then
    --	eventArgs = SafePack(...);
    --end

    -- flashing?

    ChatEdit_SetLastTellTarget(takeNameFromPlayername(sender), "WHISPER");

    if ( not chatFrame.tellTimer or (GetTime() > chatFrame.tellTimer) ) then
        PlaySound(SOUNDKIT.TELL_MESSAGE);
    end
    chatFrame.tellTimer = GetTime() + CHAT_TELL_ALERT_TIME;
    --FCF_FlashTab(self);
    FlashClientIcon();

    local info = ChatTypeInfo["WHISPER"];
    -- this is NIL?
    --FlashTabIfNotShown(chatFrame, info, "WHISPER", "WHISPER", sender);
    chatFrame:AddMessage(msg, info.r, info.g, info.b, info.id, accessID, typeID, "CHAT_MSG_WHISPER", eventArgs, MessageFormatter);
end

local function spoofOTRWhisper(message, sender, isSender)

    -- NOTE: see FloatingChatFrameManager_OnEvent
    if FCFManager_GetNumDedicatedFrames("WHISPER", takeNameFromPlayername(sender)) == 0 then
        -- make new frame if needed?
        local chatFrame = FCF_OpenTemporaryWindow("WHISPER", takeNameFromPlayername(sender));
        chatFrames[takeNameFromPlayername(sender)] = chatFrame -- NOTE tmp way to keep track of the frame?
        SendOTRWhisperToFrame(chatFrame, message, sender, isSender)

        if isSender then
            FCF_SelectDockFrame(chatFrame);
            FCF_FadeInChatFrame(chatFrame);
        else
            FCF_FadeInChatFrame(chatFrame); -- ??
            FCF_FlashTab(chatFrame) -- shit is the wrong kind?
        end
    else
        -- stop flashing
        FCFManager_StopFlashOnDedicatedWindows("WHISPER", takeNameFromPlayername(sender));

        -- TODO: figure this one out!
        local chatFrame = chatFrames[takeNameFromPlayername(sender)] -- FCFManager_GetChatTarget("WHISPER", sender, UnitName("player"))
        -- NOTE: there is no way to obtain the chat window from the `dedicatedWindows`?
        if chatFrame == nil then
            print("[!] No chat whisper frame found!!")
            return
        end

        FCF_FadeInChatFrame(chatFrame); -- ??
        FCF_FlashTab(chatFrame)
        
        SendOTRWhisperToFrame(chatFrame, message, sender, isSender)
    end
end

function bignum_mod(a, b)
    local q = BigNum.new()  -- quotient (discarded)
    local r = BigNum.new()  -- remainder (this is what we want)
    BigNum.div(a, b, q, r)
    return r
end

-- Vires in numeris, 1024 bit (TODO: https://datatracker.ietf.org/doc/html/rfc3526#section-3)
local prime = BigNum.new("1522605027922533360535618378132637429718068114961380688657908494580122963258952897654000350692006139") --138906510677011891929592526950652639230206605539989724821445378383957431108810776885337490647001125862737696358886844639523156958002155026797141586656698076850836605519143529711779461131498229669823806930874057768070744659329846993687078442187495466253952387056074335580898174981611057828352967545621549843561")
local generator = BigNum.new("2")

function modexp(base, exponent, modulus)
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
function unsecureRandomBigNum(bits)
    local digits = math.ceil(bits / 3.32)  -- log2(10) ≈ 3.32
    local s = {}
    table.insert(s, math.random(1, 9))
    for _ = 2, digits do
       table.insert(s, math.random(0, 9))
    end

    return BigNum.new(table.concat(s))
end


-- Key generation (like Diffie-Hellman)
function generateKeys()
   local priv = unsecureRandomBigNum(100) --unsecureRandomBigNum(1536) -- TODO: secure rng!!!
   local pub = modexp(generator, priv, prime)
   return pub, priv
end

--local pub, priv = generateKeys()
--print("Public key:  ", pub)
--print("Private key: ", priv)


local keychain = {}
local playerVersions = {}

local function AddKeychain(playername, value)
   local name = takeNameFromPlayername(playername)
   keychain[name] = value;
end
local function GetKey(playername)
   local name = takeNameFromPlayername(playername)
   return keychain[name]
end

local pubkey, privkey = generateKeys()
print("New keypair generated! (v" .. tostring(protocolVersion) .. ")")

local _SendChatMessage = _G.SendChatMessage
_G.SendChatMessage = function(msg, chatType, language, channel)
    -- skip if not Whisper. allow non-friend if already has key
    if chatType ~= "WHISPER" 
    or ( Settings_FriendListOnly and (C_FriendList.GetFriendInfo(channel) == nil 
        and not GetKey(channel)))
    then
        if debug then
            print("Skip " .. chatType .. " for " .. channel)
        end
        return _SendChatMessage(msg, chatType, language, channel)
    end 



    local function sendEncryptedMessage()
        if GetKey(channel) then
            local encryptedMsg = encrypt(msg, GetKey(channel))
            
            if debug then
                print("[WHSP]: sending: " .. encryptedMsg)
            end

            C_ChatInfo.SendAddonMessage(addonPrefix, "OTRW" .. encryptedMsg, "WHISPER", channel)
            spoofOTRWhisper(msg, channel, true)
        else
            print("Error, no key found for " .. tostring(channel) .. " - E2EE DISABLED")
            _SendChatMessage(msg, chatType, language, channel)
        end
    end
    -- TODO: hit cache for known keys? handle if target offline/relogged?
    local function pre_sendEncryptedMessage()
        -- check timeout
        local name = takeNameFromPlayername(channel)
        if playerVersions[name] == nil then
            print("Error, no ACK from " .. tostring(channel) .. " - E2EE DISABLED")
            _SendChatMessage(msg, chatType, language, channel)
            return
        end

        if playerVersions[name] ~= protocolVersion then
            print("Error, version missmatch for " .. tostring(channel) .. " - E2EE DISABLED,", playerVersions[name], " != ", protocolVersion)
            _SendChatMessage(msg, chatType, language, channel)
            return
        end

        -- player IS found? good, continue!
        -- TODO: actually do a callback if receiv pubkey?
        
        -- NOTE: This is sooooo shitty but whatever xD
        local count = 0
        local name = takeNameFromPlayername(channel)
        local function _wait()
            count = count +1
            if debug then
                print("Waiting", count, name)
            end
            if count > 50 then return end -- 5 sec max?
            if GetKey(name) ~= nil then
                sendEncryptedMessage()
                return
            end
            C_Timer.After(0.1, _wait)
        end  
        _wait()
    end

    -- Key not exist, request key and sendEncrypted in 2.5 seconds max?
    if debug then
        print("[WHSP]: Unk receiver, sending PUBK (" .. tostring(pubkey) .. ") to " .. tostring(channel))
    end

    local addonmsg = "PUBK" .. tostring(pubkey);
    C_ChatInfo.SendAddonMessage(addonPrefix, addonmsg , "WHISPER", channel)
    
    -- give 500 ms to accept a ACK?
    C_Timer.After(0.5, pre_sendEncryptedMessage)
end

local function OnCommandReceive(commMessage, distribution, sender)
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
        local name = takeNameFromPlayername(sender)
        playerVersions[name] = tonumber(res)
    elseif opcode == "PUBK" then
        -- send PUBK ACK to let know we computing!
        local pubkeyAckMsg = string.format("PACK%04d", protocolVersion) 
        C_ChatInfo.SendAddonMessage(addonPrefix, pubkeyAckMsg, distribution, sender) 
        if debug then
            print("Replied with PACK to", sender)
        end
        
        C_Timer.After(3, function()
            local pubkeySender = string.sub(commMessage, 5)

            if debug then
                print("[PUBK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
            end

            -- TODO proper error handeling?
            local pubkeySender = BigNum.new(pubkeySender)
            --local sharedKeyB = modularExponentiation(pubkeySender, privkey, prime)
            local sharedKeyB = modexp(pubkeySender, privkey, prime)

            AddKeychain(sender, sharedKeyB)

            if debug then
                print("[PUBK]: Shared Key: " .. tostring(sharedKeyB))
                print("[PUBK]: Sending PUBK (" .. tostring(pubkey) .. ") to " .. sender)
            end

            local pubkeyMsg = "PKOK" .. tostring(pubkey)
            C_ChatInfo.SendAddonMessage(addonPrefix, pubkeyMsg, distribution, sender)
        end)
    elseif opcode == "PKOK" then
        local pubkeySender = string.sub(commMessage, 5)

        if debug then
            print("[PKOK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
        end

        local sharedKeyA = modexp(BigNum.new(pubkeySender), privkey, prime)

        if debug then
            print("[PKOK]: Shared key: " .. tostring(sharedKeyA))
        end

        AddKeychain(sender, sharedKeyA)

    elseif opcode == "OTRW" then
        local encryptedMessage = string.sub(commMessage, 5)
        local key = GetKey(sender)
        if key == nil then
            -- bad! exchange again? or this is failure?
            print("[OTRW] Failed decrypting message from " .. sender)
        end

        -- decrypt?
        local decryptedMessage = decrypt(encryptedMessage, key)
        if debug then
            print("[OTRW] " .. sender .. " encrypted: " .. string.sub(commMessage, 5))
            print("[OTRW] " .. sender .. " whispers: " .. decryptedMessage)
        end

        spoofOTRWhisper(decryptedMessage, sender, false)
    end

end

-- #============#
-- #     UI     #
-- #============#

local panel = CreateFrame("Frame")
panel.name = "OTRWhisper"               -- see panel fields
--InterfaceOptions_AddCategory(panel)  -- see InterfaceOptions API

-- add widgets to the panel as desired
local title = panel:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
title:SetPoint("TOP")
title:SetText("Off-The-Record Whisper")

-- TODO: cache these things somewhere?
local checkboxFriendlist = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
checkboxFriendlist:SetPoint("TOPLEFT", 20, -20)
checkboxFriendlist.Text:SetText("Friendlist OTR only")
checkboxFriendlist:SetScript("OnClick", function()
    Settings_FriendListOnly = checkboxFriendlist:GetChecked()
end)

local checkboxForceOTR = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
checkboxForceOTR:SetPoint("TOPLEFT", 20, -60)
checkboxForceOTR.Text:SetText("Block ALL Non-OTR Whispers")
checkboxForceOTR:SetScript("OnClick", function()
    Settings_ForceOTR = checkboxForceOTR:GetChecked()
end)


-- #============#
-- #   Events   #
-- #============#

-- TODO: use varargs !!
local function EventHandler(self, event, prefix, commMessage, distribution, sender)
    if event == "CHAT_MSG_ADDON" and prefix == addonPrefix then
        OnCommandReceive(commMessage, distribution, sender)
        return true -- always accept?
    elseif event == "ADDON_LOADED" and prefix == "OTRWhisper" then
        if debug then
            print("ForceOTR:", Settings_ForceOTR, ", FriendListOnly:", Settings_FriendListOnly)
        end
        if Settings_ForceOTR == nil then Settings_ForceOTR = false end
        checkboxForceOTR:SetChecked(Settings_ForceOTR)

        if Settings_FriendListOnly == nil then Settings_FriendListOnly = false end
        checkboxFriendlist:SetChecked(Settings_FriendListOnly)
        return true
    end
end


-- filter /w if ForceOTR
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", function(self, event, msg, player)
    if not Settings_ForceOTR then
        return
    end

    -- TODO: figure out how to not print multiple times?

    -- TODO: Fancy print?
    local pname = UnitName("player")
    local informMsg = "[OTRWhisper]: Player " .. pname .. " only accepts Off-The-Records Whispers from the OTRWhisper AddOn"
    print("[OTRWhisper]: blocked 1 message from " .. player)
    _SendChatMessage(informMsg, "WHISPER", "", player)
    return true
end)

-- Register the callback handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("CHAT_MSG_WHISPER");
frame:SetScript("OnEvent", EventHandler)
C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
