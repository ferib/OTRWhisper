local addonPrefix = "OTRWhisper" .. "P0C";

local chatFrames = {} -- temp?

-- #==============#
-- #   Settings   #
-- #==============#
--
-- C_FriendList.GetFriendInfo(name)
local Settings_FriendListOnly = false
local Settings_ForceOTR = false
local debug = IsGMClient()

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
        local playerLink = "[|cff222222" .. GetPlayerLink(sender, sender, 0, "WHISPER", sender) .. "|r]"
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
        local chatTimestampFmt = GetChatTimestampFormat();
        if ( chatTimestampFmt ) then
            outMsg = BetterDate(chatTimestampFmt, msgTime)..outMsg;
        end

        return outMsg;
    end

    local isChatLineCensored = C_ChatInfo.IsChatLineCensored(lineID);

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
        SendOTRWhisperToFrame(chatFrame, message, sender, isSender)
    end
end

-- TODO: 1536 bit prime?
local prime = 2147483647 -- figure out big numbers in Lua?
local generator = 2 -- this is fine?

-- Function to calculate the modular exponentiation
function modularExponentiation(base, exponent, modulus)
   local result = 1
   base = math.fmod(base, modulus)

   while exponent > 0 do
      if math.fmod(exponent, 2) == 1 then
         result = math.fmod((result * base), modulus)
      end
      base = math.fmod((base * base), modulus)
      exponent = math.floor(exponent / 2)
   end

   return result
end

function generateKeys()
   local priv = math.random(2, prime - 1)
   local pub = modularExponentiation(generator, priv, prime)

   -- to calc shared secret:
   -- modularExponentiation(publicB, privateA, prime)

   return pub, priv
end

local keychain = {}

local function AddKeychain(playername, value)
   local name = takeNameFromPlayername(playername)
   keychain[name] = value;
end
local function GetKey(playername)
   local name = takeNameFromPlayername(playername)
   return keychain[name]
end

local pubkey, privkey = generateKeys()

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
    
    -- TODO: hit cache for known keys? handle if target offline/relogged?
    local function sendEncrypted()
        if GetKey(channel) then
            local encryptedMsg = encrypt(msg, GetKey(channel))
            
            if debug then
                print("[WHSP]: sending: " .. encryptedMsg)
            end

            C_ChatInfo.SendAddonMessage(addonPrefix, "OTRW" .. encryptedMsg, "WHISPER", channel)
            spoofOTRWhisper(msg, channel, true)
        else
            print("[!] no key found for " .. channel .. ", falling back on WHISPER")
            _SendChatMessage(msg, chatType, language, channel)
        end
    end

    if GetKey(channel) ~= nil then
        sendEncrypted()
        return
    end

    -- Key not exist, request key and sendEncrypted in 2.5 seconds max?
    if debug then
        print("[WHSP]: Unk receiver, sending PUBK (" .. pubkey .. ") to " .. channel)
    end

    local addonmsg = "PUBK" .. tostring(pubkey);
    C_ChatInfo.SendAddonMessage(addonPrefix, addonmsg , "WHISPER", channel)
    
    C_Timer.After(2.5, sendEncrypted)
end

local function OnCommandReceive(commMessage, distribution, sender)
    -- TODO: ignore self (soon-ish)

    if distribution ~= "WHISPER" then
        return
    end

    local opcode = string.sub(commMessage, 1, 4)

    if opcode == "PUBK" then
        local pubkeySender = string.sub(commMessage, 5)

        if debug then
            print("[PUBK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
        end

        -- TODO proper error handeling?
        local pubkeySender = tonumber(pubkeySender)
        local sharedKeyB = modularExponentiation(pubkeySender, privkey, prime)

        AddKeychain(sender, sharedKeyB)

        if debug then
            print("[PUBK]: Shared Key: " .. tostring(sharedKeyB))
            print("[PUBK]: Sending PUBK (" .. tostring(pubkey) .. ") to " .. sender)
        end

        local pubkeyMsg = "PKOK" .. pubkey
        C_ChatInfo.SendAddonMessage(addonPrefix, pubkeyMsg, distribution, sender)

    elseif opcode == "PKOK" then
        local pubkeySender = string.sub(commMessage, 5)

        if debug then
            print("[PKOK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
        end

        local sharedKeyA = modularExponentiation(tonumber(pubkeySender), privkey, prime)

        if debug then
            print("[PKOK]: Shared key: " .. tostring(sharedKeyA))
        end

        AddKeychain(sender, sharedKeyA)

    elseif opcode == "OTRW" then
        local encryptedMessage = string.sub(commMessage, 5)
        local key = GetKey(sender)
        if key == nil then
            -- bad!
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

local function EventHandler(self, event, prefix, commMessage, distribution, sender)
    if event == "CHAT_MSG_ADDON" and prefix == addonPrefix then
        OnCommandReceive(commMessage, distribution, sender)
    end
end

-- Register the callback handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", EventHandler)
C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

-- 
local panel = CreateFrame("Frame")
panel.name = "OTRWhisper"               -- see panel fields
InterfaceOptions_AddCategory(panel)  -- see InterfaceOptions API

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
