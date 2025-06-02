-- TODO: fix proper addon instead of _G
-- TODO: fix settings and save keys maybe?
-- TODO: extend key bit's bit over frames?
-- TODO: pre generate a key so we can cache and reply instant?

local addon, OTR = ...
OTR.addonPrefix = addon .. "P0C";
OTR.protocolVersion = 2
local api = OTR.api
local md5 = OTR.md5
local BigNum = OTR.BigNum
local chatFrames = {} -- temp?

-- #==============#
-- #   Settings   #
-- #==============#

--Settings_FriendListOnly = false
--Settings_ForceOTR = false
OTR.debug = IsGMClient()
local debug = OTR.debug

-- random helper func, with local overwrite :3
local takeNameFromPlayername = OTR.utils.takeNameFromPlayername;
local print = OTR.utils.print


OTR.SendOTRWhisperToFrame = function(chatFrame, message, sender, isSender)
   -- NOTE: see ChatFrame_MessageEventHandler
   --chatFrame:GetScript("OnEvent")(chatFrame, event, ...); -- TODO: Fire the event for the frame.

   if ( chatFrame.privateMessageList and not chatFrame.privateMessageList[takeNameFromPlayername(sender)] ) then
      return;
   elseif ( chatFrame.excludePrivateMessageList and chatFrame.excludePrivateMessageList[takeNameFromPlayername(sender)] ) then
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
        local pflag = "<|cff00FAF6OTR|r>" --GetPFlag(arg6, arg7, arg8); -- NONE?

        local showLink = 1;
        msg = gsub(msg, "%%", "%%%%");

        -- Search for icon links and replace them with texture links.
        --msg = C_ChatInfo.ReplaceIconAndGroupExpressions(msg, false, not ChatFrame_CanChatGroupPerformExpressionExpansion("WHISPER"));

        --Remove groups of many spaces
        msg = RemoveExtraSpaces(msg);

        -- NOTE: No GUID so no colors?
        --local _, class = GetPlayerInfoByGUID(guid)
        --local color = RAID_CLASS_COLORS[class]
        --local playerLink = "[|c" .. color.colorStr .. GetPlayerLink(sender, sender, 0, "WHISPER", sender) .. "|r]"
        local playerLink = "[" .. GetPlayerLink(sender, sender, 0, "WHISPER", sender) .. "|r]"
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

OTR.spoofOTRWhisper = function(message, sender, isSender)

    -- NOTE: see FloatingChatFrameManager_OnEvent
    if FCFManager_GetNumDedicatedFrames("WHISPER", takeNameFromPlayername(sender)) == 0 then
        -- make new frame if needed?
        local chatFrame = FCF_OpenTemporaryWindow("WHISPER", takeNameFromPlayername(sender));
        chatFrames[takeNameFromPlayername(sender)] = chatFrame -- NOTE tmp way to keep track of the frame?
        
        -- add a welcome msg?
        OTR.SendOTRWhisperToFrame(chatFrame, "|cff00FAF6This chat is using end-to-end encryption!", sender, false)
        OTR.SendOTRWhisperToFrame(chatFrame, message, sender, isSender)

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
            print("Error, No chat whisper frame found!!")
            return
        end

        FCF_FadeInChatFrame(chatFrame); -- ??
        FCF_FlashTab(chatFrame)
        
        OTR.SendOTRWhisperToFrame(chatFrame, message, sender, isSender)
    end
end

print("OTR Whispers only works with other v" .. tostring(OTR.protocolVersion) .. " users! (receiver must also install AddOn)")

local _SendChatMessage = _G.SendChatMessage
_G.SendChatMessage = function(msg, chatType, language, channel)
    -- NOTE channel can be nil ??
    -- skip if not Whisper. allow non-friend if already has key
    if chatType ~= "WHISPER" 
    or ( Settings_FriendListOnly and (C_FriendList.GetFriendInfo(channel) == nil 
        and not OTR.keys.get(channel)))
    then
        if debug then
            print("Skip", chatType, "for", channel)
        end
        return _SendChatMessage(msg, chatType, language, channel)
    end 

    if OTR.keys.isPlayerBlacklisted(channel) then
        if debug then
            print("Skip blacklist on ", channel)
        end
        return _SendChatMessage(msg, chatType, language, channel)
    end

    local function sendEncryptedMessage()
        if OTR.keys.get(channel) then
            local encryptedMsg = api.v2.encrypt(msg, OTR.keys.get(channel))
            
            if debug then
                print("[WHSP]: sending: " .. encryptedMsg)
            end

            C_ChatInfo.SendAddonMessage(OTR.addonPrefix, "OTRW" .. encryptedMsg, "WHISPER", channel)
            OTR.spoofOTRWhisper(msg, channel, true)
        else
            print("Error, no key found for " .. tostring(channel) .. " - E2EE DISABLED")
            _SendChatMessage(msg, chatType, language, channel)
        end
    end
    -- TODO: hit cache for known keys? handle if target offline/relogged?
    local function pre_sendEncryptedMessage()
        -- check timeout
        --print("pre_send playerVersions['" .. name .. "'] =", playerVersions[name])
        if not OTR.keys.isPlayerKnown(channel) then
            if debug then
                print("Error, no ACK from " .. tostring(channel) .. " - E2EE DISABLED")
            end
            -- blacklist so we dont have to wait 1 sec again
            OTR.keys.blacklistPlayer(channel)
            _SendChatMessage(msg, chatType, language, channel)
            return
        end

        if not OTR.keys.isPlayerVersionMatch(channel, OTR.protocolVersion) then
            print("Error, version missmatch for " .. tostring(channel) .. " - E2EE DISABLED,", OTR.keys.getPlayerVersion(channel), " != ", OTR.protocolVersion)
            _SendChatMessage(msg, chatType, language, channel)
            return
        end

        -- player IS found? good, continue!
        -- TODO: actually do a callback if receiv pubkey?
        
        -- NOTE: This is sooooo shitty but whatever xD
        local count = 0
        local function _wait()
            count = count +1
            if debug then
                print("Waiting", count, channel)
            end
            if count > 50 then return end -- 5 sec max?
            if OTR.keys.get(channel) ~= nil then
                sendEncryptedMessage()
                return
            end
            C_Timer.After(0.1, _wait)
        end  
        _wait()
    end

    if api.pubkey == nil then
        api.generateKeys();
    end 
    
    -- Key not exist, request key and sendEncrypted in 2.5 seconds max?
    if debug then
        print("[WHSP]: Unk receiver, sending PUBK (" .. tostring(api.pubkey) .. ") to " .. tostring(channel))
    end

    local addonmsg = "PUBK" .. tostring(api.pubkey);
    C_ChatInfo.SendAddonMessage(OTR.addonPrefix, addonmsg , "WHISPER", channel)
    
    -- give 950 ms to accept a ACK?
    C_Timer.After(0.9, pre_sendEncryptedMessage)
end

-- #============#
-- #     UI     #
-- #============#

local panel = CreateFrame("Frame")
panel.name = "OTRWhisper"               -- see panel fields
if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)  -- see InterfaceOptions API
end

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
-- self, event, msg, author, _, _, _, _, _, _, _, _, lineID, guid)
local function EventHandler(self, event, prefix, commMessage, distribution, sender, _, _, _, _, _, _, lineID, guid)
    if event == "CHAT_MSG_ADDON" and prefix == OTR.addonPrefix then
        api.v2.OnCommandReceive(commMessage, distribution, sender, guid)
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
    print("[OTRWhisper]: blocked a message from " .. player)
    _SendChatMessage(informMsg, "WHISPER", "", player)

    if debug then
        return false
    end

    return true
end)

-- Register the callback handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("CHAT_MSG_WHISPER");
frame:SetScript("OnEvent", EventHandler)
C_ChatInfo.RegisterAddonMessagePrefix(OTR.addonPrefix)

_G.OTR = OTR