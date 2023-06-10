C_Timer.After(0, function()

   local addonPrefix = "OTRWhisper" .. "0";

   C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

   local function SendOTRWhisperToFrame(chatFrame, message, sender, isSender)
      -- NOTE: see ChatFrame_MessageEventHandler
      --chatFrame:GetScript("OnEvent")(chatFrame, event, ...); -- TODO: Fire the event for the frame.

      if ( chatFrame.privateMessageList and not chatFrame.privateMessageList[strlower(sender)] ) then
         return;
      elseif ( chatFrame.excludePrivateMessageList and chatFrame.excludePrivateMessageList[strlower(sender)] ) then
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

         --local playerLink = "[|cffffffff" .. sender .. "|r]";
         local playerLink = GetPlayerLink(sender, sender, 0, "WHISPER", sender)
         local playerLinkDisplayText = coloredName;
         local relevantDefaultLanguage = chatFrame.defaultLanguage;

         local message = msg;
         
         local outMsg = format(_G["CHAT_WHISPER_GET"] .. message, pflag .. playerLink);

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
      print("TEST: " .. msg)

      local accessID = ChatHistory_GetAccessID("WHISPER", sender);

      local arg12 = nil -- ?
      local typeID = ChatHistory_GetAccessID("WHISPER", sender, arg12 or arg13);
      
      -- The message formatter is captured so that the original message can be reformatted when a censored message
      -- is approved to be shown. We only need to pack the event args if the line was censored, as the message transformation
      -- step is the only code that needs these arguments. See ItemRef.lua "censoredmessage".
      local eventArgs = {};
      --if isChatLineCensored then
      --	eventArgs = SafePack(...);
      --end

      -- flashing?

      ChatEdit_SetLastTellTarget(sender, "WHISPER");

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
      if FCFManager_GetNumDedicatedFrames("WHISPER", sender) == 0 then
         -- make new frame if needed?
         local chatFrame = FCF_OpenTemporaryWindow("WHISPER", sender);
         SendOTRWhisperToFrame(chatFrame, message, sender, isSender)
         
         if isSender then
            FCF_SelectDockFrame(chatFrame);
            FCF_FadeInChatFrame(chatFrame);
         end
      else
         -- stop flashing
         FCFManager_StopFlashOnDedicatedWindows("WHISPER", sender);
      
         local chatFrame = nil -- FCFManager_GetChatTarget("WHISPER", sender, UnitName("player"))
         -- NOTE: there is no way to obtain the chat window from the `dedicatedWindows`?
         if chatFrame == nil then
            print("No chat whisper frame found?")
            return
         end
         SendOTRWhisperToFrame(chatFrame, message, sender, isSender)
      end
   end

   -- KEY EXCHANGE TEST
   --[[
      diffie-hellman算法简单代码 (Algorithm simple code)
   ]]
   local low = 10	--约定的随机数集合 (Agreed set of random numbers)
   local high = 20

   -- TODO: 1536 bit prime?
   local prime = 2147483647 -- generatePrimeNumber()
   local generator = 2 -- often used in chat encryption?

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

  --print(diffieHellman)

   -- TODO: Register ChatCommand for pub key
   -- InspectPaperDollFrame -> InspectLevelText

   -- TODO: Register ChatCommand for RSAWhsipers

   -- Request chat? or just ignore and auto give?

   -- Before the user whispers, it should somehow request the
   -- to give their public key, which the receiver can then use
   -- to encrypt their whispers.
   --
   -- AFAIK Wow only has a secure post-hook?

   -- test hook? yes this works!
   -- Now make a cache of users and ask on /w for their key
   -- if no key ignore? otherwise save and use key for encryption
   -- wait a second (or two) before dispatching the failsafe msg?
   local _SendChatMessage = _G.SendChatMessage

   local keychain = {}
   
   local pubkey, privkey = generateKeys()

   local hook = true
   local debug = true

   if hook then
      _G.SendChatMessage = function(msg, chatType, language, channel)
         if chatType ~= "WHISPER" then
            return _SendChatMessage(msg, chatType, language, channel)
         end
         
         -- hit cache for known keys?
         -- ask user for key?
         

         if debug then
            print("[WHSP]: Unk receiver, sending PUBK (" .. pubkey .. ") to " .. channel)
         end

         local addonmsg = "PUBK" .. tostring(pubkey);
         C_ChatInfo.SendAddonMessage(addonPrefix, addonmsg , "WHISPER", channel)

         --else
         C_Timer.After(1, function() 

            -- have it encrypted?
            if keychain[channel] ~= nil then
               -- encrypt?
               local encryptedMsg = "OTRW" .. msg -- TODO: actually encrypt this? xD
               C_ChatInfo.SendAddonMessage(addonPrefix, encryptedMsg, "WHISPER", channel)
               -- TODO: print msg?
               spoofOTRWhisper(msg, channel, true) -- sender is self?
            else
               print("[!] no key found for " .. channel .. ", falling back on WHISPER")
               _SendChatMessage(msg, chatType, language, channel)
            end
         end)
      end
   end

   -- SendAddonMessage
   local function OnCommandReceive(commMessage, distribution, sender)
      -- TODO: ignore self (soon-ish)

      -- only YELL for pub key?

      -- WHISPER request key
      if distribution == "WHISPER" then
         local opcode = string.sub(commMessage, 1, 4)
         --print(opcode)

         -- Requested Pubkey
         if opcode == "PUBK" then
            local pubkeySender = string.sub(commMessage, 5)

            if debug then
               print("[PUBK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
            end

            -- TODO proper error handeling?
            local pubkeySender = tonumber(pubkeySender)
            local sharedKeyB = modularExponentiation(pubkeySender, privkey, prime)

            -- substring on '-'?
            local t={}
            for str in string.gmatch(sender, "([^"..'-'.."]+)") do
               table.insert(t, str)
            end
            local name = t[1] or sender

            -- add to keychain?
            keychain[name] = pubkeySender;

            if debug then
               print("[PUBK]: Shared Key: " .. tostring(sharedKeyB))
               print("[PUBK]: Sending PUBK (" .. tostring(pubkey) .. ") to " .. sender)
            end

            local pubkeyMsg = "PKOK" .. pubkey
            C_ChatInfo.SendAddonMessage(addonPrefix, pubkeyMsg, distribution, sender)
         elseif opcode == "PKOK" then
            local pubkeySender = string.sub(commMessage, 5)
            print("[PKOK]: Received PUBK (" .. pubkeySender .. ") from " .. sender)
            
            -- do some math?
            local sharedKeyA = modularExponentiation(tonumber(pubkeySender), privkey, prime)

            if debug then
               print("[PKOK]: Shared key: " .. tostring(sharedKeyA))
            end

            -- substring on '-'?
            local t={}
            for str in string.gmatch(sender, "([^"..'-'.."]+)") do
               table.insert(t, str)
            end
            local name = t[1] or sender

            -- add to keychain?
            keychain[name] = pubkey;
         elseif opcode == "OTRW" then
            -- Off-The-Record message!
            local t={}
            for str in string.gmatch(sender, "([^"..'-'.."]+)") do
               table.insert(t, str)
            end
            local name = t[1] or sender

            if keychain[name] == nil then
               -- bad!
               print("[OTRW] Failed decrypting message from " .. sender)
            end

            -- decrypt?
            local decryptedMessage = string.sub(commMessage, 5);
            if debug then
               print("[OTRW] " .. sender .. " whispers: " .. decryptedMessage)
            end
            
            spoofOTRWhisper(decryptedMessage, sender, false)

            -- invoke FloatingChatFrameManager_OnEvent
            if FloatingChatFrameManager ~= nil then
               -- CHAT_MSG_WHISPER: 
               -- text, playerName, languageName, channelName, playerName2, 
               -- specialFlags, zoneChannelID, channelIndex, channelBaseName, 
               -- languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, 
               -- hideSenderInLetterbox, supressRaidIcons
               --[[
               FloatingChatFrameManager_OnEvent(
                  FloatingChatFrameManager, 
                  "CHAT_MSG_WHISPER",
                  "AA", 
                  "[OTR] " .. sender, 
                  "Common",
                  "WHISPER",
                  sender,
                  0,
                  0,
                  0,
                  "",
                  0,
                  0,
                  UnitGUID("player"),
                  0,
                  false,
                  false,
                  false,
                  false
               )]]--
               --[[
               FloatingChatFrameManager_OnEvent(
                  FloatingChatFrameManager, 
                  decryptedMessage, 
                  sender, 
                  "Common",
                  "WHISPER",
                  sender,
                  0, -- ??
                  0,
                  "WHISPER", -- ??
                  7, -- aly common?
                  0, -- ??
                  "", -- GUID?
                  0, -- bnet?
                  false,
                  false,
                  false,
                  false
               )]]--
            end

         end

      end
   end



   --[[
   local function COPY_FloatingChatFrameManager_OnEvent(self, event, ...)
      local arg1 = ...;
      if ( event == "CHAT_MSG_OTG_WHISPER" ) then
         local chatTarget = tostring(select(2, ...));
         local chatGroup = "WHISPER"

         if ( FCFManager_GetNumDedicatedFrames(chatGroup, chatTarget) == 0 ) then
            local chatFrame = FCF_OpenTemporaryWindow(chatGroup, chatTarget);
            chatFrame:GetScript("OnEvent")(chatFrame, event, ...);	--Re-fire the event for the frame.

            -- If you started the whisper, immediately select the tab
            if ((event == "CHAT_MSG_WHISPER_INFORM" and GetCVar("whisperMode") == "popout")
               or (event == "CHAT_MSG_BN_WHISPER_INFORM" and GetCVar("whisperMode") == "popout") ) then
               FCF_SelectDockFrame(chatFrame);
               FCF_FadeInChatFrame(chatFrame);
            end
         else
            -- While in "Both" mode, if you reply to a whisper, stop the flash on that dedicated whisper tab
            if ( (chatType == "WHISPER_INFORM" and GetCVar("whisperMode") == "popout_and_inline")
            or (chatType == "BN_WHISPER_INFORM" and GetCVar("whisperMode") == "popout_and_inline")) then
               FCFManager_StopFlashOnDedicatedWindows(chatGroup, chatTarget);
            end
         end
      end
   end
   ]]--

   local function EventHandler(self, event, prefix, commMessage, distribution, sender)
      --print(event, prefix, commMessage, distribution, sender)
      if event == "CHAT_MSG_ADDON" and prefix == addonPrefix then
         OnCommandReceive(commMessage, distribution, sender)
      --elseif event == "CHAT_MSG_OTG_WHISPER" then
      --   COPY_FloatingChatFrameManager_OnEvent()
      end
   end

   -- Register the callback handler
   local frame = CreateFrame("Frame")
   frame:RegisterEvent("CHAT_MSG_ADDON")
   --frame:RegisterEvent("CHAT_MSG_OTG_WHISPER")
   frame:SetScript("OnEvent", EventHandler)
end)
