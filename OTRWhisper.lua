C_Timer.After(0, function()
   -- test
   -- TODO: Rename to OTRWhisper?
   local addonPrefix = "WhisperRSA" .. "0";

   C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)


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
         C_ChatInfo.SendAddonMessage("WhisperRSA0", addonmsg , "WHISPER", channel)

         --else
         C_Timer.After(1, function() 

            -- have it encrypted?
            if keychain[channel] ~= nil then
               -- encrypt?
               msg = "ENCRYPTED: " .. msg
            end
            _SendChatMessage(msg, chatType, language, channel)
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
         elseif opcode == "MSGR" then

         end

      end
   end

   local function EventHandler(self, event, prefix, commMessage, distribution, sender)
      --print(event, prefix, commMessage, distribution, sender)
      if event == "CHAT_MSG_ADDON" and prefix == addonPrefix then
         OnCommandReceive(commMessage, distribution, sender)
      end
   end

   -- Register the callback handler
   local frame = CreateFrame("Frame")
   frame:RegisterEvent("CHAT_MSG_ADDON")
   frame:SetScript("OnEvent", EventHandler)
end)
