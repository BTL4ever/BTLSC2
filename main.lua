local inspect = require("pretty-print")
local discordia = require("discordia")
local dcmd = require("discordia-slash")
local client = discordia.Client():useApplicationCommands()
local json = require("json")
local http = require("coro-http")
local timer = require("timer")
local availableGuilds = {
    ["1350119432894021662"] = true,
    ["1259951808969834557"] = true,
    ["1410967023802126428"] = true,
    ["1433874230935552172"] = true,
    ["1399856511534104637"] = true
}
local timeoutedDataJson = io.open("timeoutedData.json","r")
local timeoutedData = json.decode(timeoutedDataJson:read("*a")) or {}
timeoutedDataJson:close()
local afkDataJson = io.open("afkData.json","r")
local afkData = json.decode(afkDataJson:read("*a")) or {}
afkDataJson:close()
local confirmDataJson = io.open("confirmData.json","r")
local confirmData = json.decode(confirmDataJson:read("*a")) or {}
confirmDataJson:close()
local mainChannelsJson = io.open("mainChannels.json","r")
local mainChannels = json.decode(mainChannelsJson:read("*a")) or {}
mainChannelsJson:close()
local customEmojis = {["BTLST_Success"] = "BTLST_Success:1461391133232992409",["BTLST_Basic_Fail"] = "BTLST_Basic_Fail:1461391454977917051",["BTLST_Fail"] = "BTLST_Fail:1461391513320947984"}
local testMode = true
local operationIsOnProgress = false
local function commandNameCheck(options)
    local commandName = " "..options[1]["name"]
    if options[1] and options[1]["options"] then commandName = commandName..commandNameCheck(options[1]["options"]) end
    return commandName
end
local function timeoutMember(guildId,memberId,duration,reason)
    if duration > 0 then timeoutedData[guildId][memberId] = os.time() + duration else timeoutedData[guildId][memberId] = 0 end
    local url = string.format("https://discord.com/api/v10/guilds/%s/members/%s",guildId,memberId)
    local untilTime = os.date("!%Y-%m-%dT%H:%M:%S.000Z",timeoutedData[guildId][memberId])
    local body = json.encode({communication_disabled_until = untilTime})
    local headers = {{"Authorization","Bot "..os.getenv('DISCORD_TOKEN')},{"Content-Type","application/json"},{"X-Audit-Log-Reason",reason}}
    local res,data = http.request("PATCH",url,headers,body)
    return res.code
end
local function banSystem(isBan,guildId,memberId,deleteDays,reason)
    local url = string.format("https://discord.com/api/v10/guilds/%s/bans/%s",guildId,memberId)
    local headers = {{"Authorization","Bot "..os.getenv('DISCORD_TOKEN')},}
    if reason and #reason > 0 then table.insert(headers,{"X-Audit-Log-Reason",reason}) end
    local res,data = {["code"] = 200},nil
    if isBan then
        local body = json.encode({delete_message_days = tonumber(deleteDays) or 0})
        table.insert(headers,{"Content-Type","application/json"})
        res,data = http.request("PUT",url,headers,body)
    else res,data = http.request("DELETE",url,headers) end
    return res.code
end
client:on("ready",function()
    if operationIsOnProgress then return end
    operationIsOnProgress = true
    print("$#","Logged in as "..client.user.username,"#")
    operationIsOnProgress = false
end)
client:on("slashCommand",function(interaction,command,args)
    if operationIsOnProgress == true then return end
    operationIsOnProgress = true
    if testMode and interaction.user.id ~= "1335946313292058664" then
        interaction:reply{content = "Bot is Currently in Test-Mode; Only `The🐧BTL` (aka baconteams_leader) Can Use Commands",flags = 64}
        operationIsOnProgress = false
        return
    end
    local commandName = interaction.data.name
    local options = interaction.data.options
    if options and options[1] then commandName = commandName..commandNameCheck(options) end
    if not availableGuilds[interaction.guild.id] and interaction.guild.id ~= "1433874230935552172" or interaction.user.id ~= "1335946313292058664" then
        interaction:reply{content = "This Bot is Not Available in This Server",flags = 64}
        operationIsOnProgress = false
        return
    end
    if interaction.user.id == "1335946313292058664" then
        if commandName:match("^test%-mode") then
            if testMode then testMode = false else testMode = true end
            interaction:reply{content = "Test-Mode is Now: "..tostring(testMode),flags = 64}
            operationIsOnProgress = false
            return
        elseif commandName:match("^shutdown") then
            local mainChannel
            for i,v in pairs(availableGuilds) do
                client:getGuild(i):getChannel(mainChannels[i]):send("Shutdown Requested; Shutting Down...🔷")
            end
            interaction:reply{content = "Shutting Down...🔷",flags = 64}
            client:stop()
            return
        elseif commandName:match("^save%-data%-period") then
            interaction:reply{content = "Feature isn't Available🔶",flags = 64}
            operationIsOnProgress = false
            return
        end
    end
    print("$#","----------------------------------------------------","#")
    local user = interaction.user
    local member = interaction.member
    print("$#","Command Name:",commandName,"#")
    print("$#","User:",user.username,user.id,"#")
    local embed = {
        title = "Command Received But it's Not Added Yet",
        description = commandName,
        color = 0x8b0000,
        fields = {},
        timestamp = discordia.Date():toISO('T','Z')
    }
    local buttons1 = {}
    if commandName:match("^moderation") then
        if (not member:hasPermission("administrator")) and user.username ~= "troxyblox" then
            embed["title"] = "You Don't Have Permission to Use This Command❌"
            embed["description"] = "You Need the `Administrator` Permission to Use Moderation Commands"
            embed["color"] = 0xff0000
            interaction:reply{embed = embed,flags = 64}
            operationIsOnProgress = false
            return
        elseif commandName:match("^moderation add%-action") then
            embed["color"] = 0x00ff00
            if commandName:match("^moderation add%-action timeout") then
                local reason = "No Reason Set"
                local targetMember
                local duration
                local resultEmoji = "BTLST_Fail"
                for i,v in pairs(options[1]["options"][1]["options"]) do if v["name"] == "reason" then reason = v["value"] elseif v["name"] == "member" then targetMember = interaction.guild:getMember(v["value"]) elseif v["name"] == "duration" then duration = v["value"] end end
                if not targetMember then
                    embed["color"] = 0x8b0000
                    embed["title"] = "Can't Find Member"
                    embed["fields"] = {
                        {name = "Member ID",value = targetMember.id,inline = true},
                        {name = "Duration",value = duration,inline = true},
                        {name = "Reason",value = reason,inline = true}
                    }
                    local message = interaction:reply{embed = embed}
                    message:addReaction(customEmojis[resultEmoji])
                else
                    if timeoutedData[interaction.guild.id] and timeoutedData[interaction.guild.id][targetMember.id] then embed["title"] = "Member is Already Timeouted; Changed Timeout Instead" else embed["title"] = "Timeouted" end
                    local resCode = timeoutMember(interaction.guild.id,targetMember.id,duration,reason)
                    print("$#",resCode,"#")
                    if resCode == 403 then
                        embed["color"] = 0x8b0000
                        embed["title"] = "Can't Timeout Member"
                        embed["description"]  = "Most Common Reason is Bot's Highest Role is Below the Target Member's Highest Role"
                        embed["fields"] = {
                            {name = "Member",value = targetMember.username,inline = true},
                            {name = "Duration",value = duration,inline = true},
                            {name = "Reason",value = reason,inline = true},
                            {name = "Developer Message",value = "Res Code is "..tostring(resCode),inline = true}
                        }
                    else
                        resultEmoji = "BTLST_Success"
                        embed["fields"] = {
                            {name = "Member",value = targetMember.username,inline = true},
                            {name = "Duration",value = duration,inline = true},
                            {name = "Reason",value = reason,inline = true}
                        }
                        timeoutedData[interaction.guild.id][targetMember.id] = os.time() + duration
                        local timeoutedDataJsonW = io.open("timeoutedData.json","w")
                        timeoutedDataJsonW:write(json.encode(timeoutedData))
                        timeoutedDataJsonW:close()
                    end
                    local message = interaction:reply{embed = embed}
                    if message then message:addReaction(customEmojis[resultEmoji]) end
                    timer.setTimeout(duration*1000,function()
                        if timeoutedData[interaction.guild.id][targetMember.id] then
                            timeoutedData[interaction.guild.id][targetMember.id] = nil
                            local timeoutedDataJsonW = io.open("timeoutedData.json","w")
                            timeoutedDataJsonW:write(json.encode(timeoutedData))
                            timeoutedDataJsonW:close()
                        end
                        return
                    end)
                end
            elseif commandName:match("^moderation add%-action lock") then
                local channel = interaction.guild:getChannel(options[1]["options"][1]["options"][1] and options[1]["options"][1]["options"][1]["value"]) or interaction.channel
                local resultEmoji = "BTLST_Fail"
                if channel ~= interaction.channel and not interaction.guild:getChannel(options[1]["options"][1]["options"][1]["value"]) then
                    embed["color"] = 0x8b0000
                    embed["title"] = "Bot Doesn't Have Permission to View That Channel"
                    embed["fields"] = {{name = "Channel",value = channel.name,inline = true}}
                else
                    if channel:getPermissionOverwriteFor(interaction.guild.defaultRole):getDeniedPermissions():has("sendMessages") then
                        embed["color"] = 0xdeb900
                        embed["title"] = "Channel is Already Locked"
                        resultEmoji = "BTLST_Basic_Fail"
                        embed["fields"] = {{name = "Channel",value = channel.name,inline = true}}
                    else
                        channel:getPermissionOverwriteFor(interaction.guild.defaultRole):denyPermissions("sendMessages")
                        embed["title"] = "Locked Channel"
                        resultEmoji = "BTLST_Success"
                        embed["fields"] = {{name = "Channel",value = channel.name,inline = true}}
                    end
                end
                local message = interaction:reply{embed = embed}
                message:addReaction(customEmojis[resultEmoji])
            elseif commandName:match("^moderation add%-action ban") then
                local reason = "No Reason Set"
                local targetMember
                local resultEmoji = "BTLST_Fail"
                for i,v in pairs(options[1]["options"][1]["options"]) do if v["name"] == "reason" then reason = v["value"] elseif v["name"] == "member" then targetMember = interaction.guild:getMember(v["value"]) end end
                if not targetMember or interaction.guild:getBan(targetMember.id) then
                    embed["color"] = 0xdeb900
                    if interaction.guild:getBan(targetMember.id) then
                        embed["title"] = "Member is Already Banned"
                        resultEmoji = "BTLST_Basic_Fail"
                        embed["fields"] = {
                            {name = "Member",value = interaction.guild:getBan(targetMember.id).username,inline = true},
                            {name = "Reason",value = reason,inline = true}
                        }
                    else
                        embed["title"] = "Can't Find Member"
                        embed["fields"] = {
                            {name = "Member ID",value = options[1]["options"][1]["options"][1]["value"],inline = true},
                            {name = "Reason",value = reason,inline = true}
                        }
                    end
                else
                    local resCode = banSystem(true,interaction.guild.id,targetMember.id,nil,reason)
                    if resCode == 403 then
                        embed["color"] = 0x8b0000
                        embed["title"] = "Can't Ban Member"
                        embed["fields"] = {
                            {name = "Member",value = targetMember.username,inline = true},
                            {name = "Reason",value = reason,inline = true},
                            {name = "Developer Message",value = "Res Code is "..tostring(resCode),inline = true}
                        }
                    else
                        embed["title"] = "Banned Member"
                        resultEmoji = "BTLST_Success"
                        embed["fields"] = {
                            {name = "Member",value = targetMember.username,inline = true},
                            {name = "Reason",value = reason,inline = true}
                        }
                    end
                end
                local message = interaction:reply{embed = embed}
                message:addReaction(customEmojis[resultEmoji])
            else
                interaction:reply{embed = embed}
            end
        elseif commandName:match("^moderation remove%-action") then
            embed["color"] = 0xff0000
            if commandName:match("^moderation remove%-action untimeout") then
                local reason = "No Reason Set"
                local targetMember
                local resultEmoji = "BTLST_Fail"
                for i,v in pairs(options[1]["options"][1]["options"]) do if v["name"] == "reason" then reason = v["value"] elseif v["name"] == "member" then targetMember = interaction.guild:getMember(v["value"]) end end
                if not targetMember then
                    embed["color"] = 0x8b0000
                    embed["title"] = "Can't Find Member"
                    embed["fields"] = {
                        {name = "Member's ID",value = targetMember.id,inline = true},
                        {name = "Reason",value = reason,inline = true}
                    }
                else
                    if not timeoutedData[interaction.guild.id][targetMember.id] or timeoutedData[interaction.guild.id][targetMember.id] <= os.time() then
                        embed["color"] = 0xdeb900
                        embed["title"] = "That Member isn't Timeouted"
                        resultEmoji = "BTLST_Basic_Fail"
                        embed["fields"] = {
                            {name = "Member",value = targetMember.username,inline = true},
                            {name = "Reason",value = reason,inline = true}
                        }
                    else
                        local resCode = timeoutMember(interaction.guild.id,targetMember.id,0,reason)
                        if resCode == 403 then
                            embed["color"] = 0x8b0000
                            embed["title"] = "Can't Remove Timeout"
                            embed["fields"] = {
                                {name = "Member",value = targetMember.username,inline = true},
                                {name = "Reason",value = reason,inline = true},
                                {name = "Developer Message",value = "Res Code is "..tostring(resCode),inline = true}
                            }
                            timeoutedData[interaction.guild.id][targetMember.id] = nil
                        else
                            embed["title"] = "Removed Timeout"
                            resultEmoji = "BTLST_Success"
                            embed["fields"] = {
                                {name = "Member",value = targetMember.username,inline = true},
                                {name = "Reason",value = reason,inline = true}
                            }
                            local timeoutedDataJsonW = io.open("timeoutedData.json","w")
                            timeoutedDataJsonW:write(json.encode(timeoutedData))
                            timeoutedDataJsonW:close()
                        end
                    end
                end
                local message = interaction:reply{embed = embed}
                message:addReaction(customEmojis[resultEmoji])
            elseif commandName:match("^moderation remove%-action unlock") then
                local channel = interaction.guild:getChannel(options[1]["options"][1]["options"][1] and options[1]["options"][1]["options"][1]["value"]) or interaction.channel
                local resultEmoji = "BTLST_Fail"
                if options[1]["options"][1]["options"][1] and not interaction.guild:getChannel(options[1]["options"][1]["options"][1]["value"]) then
                    embed["color"] = 0x8b0000
                    embed["title"] = "That Channel Doesn't Exist in This Server"
                    embed["fields"] = {{name = "Channel's ID",value = options[1]["options"][1]["options"][1]["value"],inline = true}}
                else
                    if channel:getPermissionOverwriteFor(interaction.guild.defaultRole):getAllowedPermissions():has("sendMessages") then
                        embed["color"] = 0xdeb900
                        embed["title"] = "That Channel isn't Locked Already"
                        resultEmoji = "BTLST_Basic_Fail"
                        embed["fields"] = {{name = "Channel",value = channel.name,inline = true}}
                    else
                        channel:getPermissionOverwriteFor(interaction.guild.defaultRole):allowPermissions("sendMessages")
                        embed["title"] = "Unlocked Channel"
                        resultEmoji = "BTLST_Success"
                        embed["fields"] = {{name = "Channel",value = channel.name,inline = true}}
                    end
                end
                local message = interaction:reply{embed = embed}
                message:addReaction(customEmojis[resultEmoji])
            elseif commandName:match("^moderation remove%-action unban") then
                local reason = "No Reason Set"
                local targetMember
                local resultEmoji = "BTLST_Fail"
                for i,v in pairs(options[1]["options"][1]["options"]) do if v["name"] == "reason" then reason = v["value"] elseif v["name"] == "member" then targetMember = v["value"] end end
                if not interaction.guild:getBan(targetMember,true) then
                    embed["color"] = 0xdeb900
                    if interaction.guild:getMember(targetMember) then
                        embed["title"] = "That Member isn't Banned Already"
                        resultEmoji = "BTLST_Basic_Fail"
                        embed["fields"] = {
                            {name = "Member",value = interaction.guild:getMember(targetMember).username,inline = true},
                            {name = "Reason",value = reason,inline = true}
                        }
                    else
                        embed["title"] = "Can't Find Member"
                        embed["fields"] = {
                            {name = "Member",value = targetMember,inline = true},
                            {name = "Reason",value = reason,inline = true}
                        }
                    end
                else
                    banSystem(false,interaction.guild.id,targetMember,nil,reason)
                    embed["title"] = "Unbanned Member"
                    resultEmoji = "BTLST_Success"
                    embed["fields"] = {
                        {name = "Member",value = interaction.guild:getBan(targetMember)[3].username,inline = true},
                        {name = "Reason",value = reason,inline = true}
                    }
                end
                local message = interaction:reply{embed = embed}
                message:addReaction(customEmojis[resultEmoji])
            else
                interaction:reply{embed = embed}
            end
        elseif commandName:match("^moderation set%-action") then
            embed["color"] = 0x0000ff
            interaction:reply{embed = embed,flags = 64}
        elseif commandName:match("^moderation other%-actions") then
            embed["color"] = 0x808080
            message = interaction:reply{embed = embed,flags = 64}
        end
    elseif commandName:match("^other") then
        embed["color"] = 0x808080
        if commandName:match("^other afk") then
            if commandName:match("^other afk set") then
                if not afkData[interaction.user.id] then
                    local reason = "No Reason Set"
                    local autoUnafk = false
                    for i,v in pairs(options[1]["options"][1]["options"]) do if v["name"] == "reason" then reason = v["value"] elseif v["name"] == "auto-unafk" then autoUnafk = v["value"] end end
                    afkData[interaction.user.id] = {["reason"] = reason,["autoUnafk"] = autoUnafk,["flags"] = 0,["mentioned"] = {}}
                    local afkDataJsonW = io.open("afkData.json","w")
                    afkDataJsonW:write(json.encode(afkData))
                    afkDataJsonW:close()
                    embed["color"] = 0x00ff00
                    embed["title"] = "AFK Set"
                    embed["fields"] = {
                        {name = "Reason",value = reason,inline = true},
                        {name = "Auto Remove AFK",value = autoUnafk,inline = true},
                        {name = "Flags",value = 0,inline = true}
                    }
                    local message = interaction:reply{embed = embed}
                    message:addReaction(customEmojis["BTLST_Success"])
                else
                    embed["color"] = 0xdeb900
                    embed["title"] = "You are AFK Already"
                    embed["description"] = "Check More Details with `/other afk check`🔬"
                    embed["fields"] = {
                        {name = "To Remove AFK",value = "~error~",inline = true}
                    }
                    local message
                    if afkData[interaction.user.id]["autoUnafk"] then
                        embed["fields"][1]["value"] = "Type a Message"
                        message = interaction:reply{embed = embed}
                    elseif afkData[interaction.user.id]["autoUnafk"] == false then
                        embed["fields"][1]["value"] = "Either Do '`/other afk remove`' or '`/confirm` in 10 Seconds'"
                        confirmData[interaction.user.id] = {["request"] = "unafk",["until"] = os.time() + 10}
                        local confirmDataJsonW = io.open("confirmData.json","w")
                        confirmDataJsonW:write(json.encode(confirmData))
                        confirmDataJsonW:close()
                        message = interaction:reply{embed = embed}
                        timer.setTimeout(10000,function()
                            if confirmData[interaction.user.id] then
                                confirmData[interaction.user.id] = nil
                                local confirmDataJsonW = io.open("confirmData.json","w")
                                confirmDataJsonW:write(json.encode(confirmData))
                                confirmDataJsonW:close()
                            end
                            return
                        end)
                    end
                    message:addReaction(customEmojis["BTLST_Basic_Fail"])
                end
            elseif commandName:match("^other afk remove") then
                if afkData[interaction.user.id] then
                    embed["title"] = "You are No Longer AFK"
                    embed["description"] = "Removed AFK Status"
                    embed["color"] = 0x00ff00
                    embed["fields"] = {
                        {name = "Reason",value = afkData[interaction.user.id]["reason"],inline = true},
                        {name = "Auto remove AFK",value = tostring(afkData[interaction.user.id]["autoUnafk"]),inline = true},
                        --{name = "Flags (Always 0/Won't Be Changed Probably)",value = tostring(afkData[interaction.user.id]["flags"]),inline = true},
                        {name = "Mention(s) ("..tostring(#afkData[interaction.user.id]["mentioned"])..")",value = "",inline = true}
                    }
                    for i,v in pairs(afkData[interaction.user.id]["mentioned"]) do embed["fields"][3]["value"] = embed["fields"][3]["value"].." ["..v["username"].."/"..tostring(i).."](https://discord.com/channels/"..v["guildId"].."/"..v["channelId"].."/"..v["messageId"]..")" end
                    if embed["fields"][3]["value"] == "" then embed["fields"][3] = nil else embed["fields"][3]["value"] = embed["fields"][3]["value"]:match(" (.)") end
                    local message = interaction:reply{embed = embed}
                    message:addReaction(customEmojis["BTLST_Success"])
                    afkData[interaction.user.id] = nil
                    local afkDataJsonW = io.open("afkData.json","w")
                    afkDataJsonW:write(json.encode(afkData))
                    afkDataJsonW:close()
                else
                    embed["title"] = "You aren't AFK Already"
                    embed["color"] = 0xdeb900
                    local message = interaction:reply{embed = embed}
                    message:addReaction(customEmojis["BTLST_Basic_Fail"])
                end
            elseif commandName:match("^other afk check") then
                local targetUser = (options[1]["options"][1]["options"][1] and interaction.guild:getMember(options[1]["options"][1]["options"][1]["value"])) or interaction.user
                if afkData[interaction.user.id] then
                    embed["title"] = "AFK Details🔬"
                    embed["description"] = "of "..targetUser.username
                    embed["color"] = 0x00ff00
                    embed["fields"] = {
                        {name = "Reason",value = afkData[interaction.user.id]["reason"],inline = true},
                        {name = "Auto Remove AFK",value = tostring(afkData[interaction.user.id]["autoUnafk"]),inline = true},
                        --{name = "Flags",value = tostring(afkData[interaction.user.id]["flags"]),inline = true},
                        {name = "Mention(s) ("..tostring(#afkData[interaction.user.id]["mentioned"])..")",value = "",inline = true}
                    }
                    for i,v in pairs(afkData[interaction.user.id]["mentioned"]) do embed["fields"][3]["value"] = embed["fields"][3]["value"].." ["..v["username"].."/"..tostring(i).."](https://discord.com/channels/"..v["guildId"].."/"..v["channelId"].."/"..v["messageId"]..")" end
                    if embed["fields"][3]["value"] == "" then embed["fields"][3] = nil else embed["fields"][3]["value"] = embed["fields"][3]["value"]:match(" (.)") end
                    interaction:reply{embed = embed}
                else
                    embed["title"] = "Target User isn't AFK Already"
                    embed["color"] = 0xdeb900
                    local message = interaction:reply{embed = embed}
                    message:addReaction(customEmojis["BTLST_Basic_Fail"])
                end
            else
                local message = interaction:reply{embed = embed,flags = 64}
                message:addReaction(customEmojis["BTLST_Basic_Fail"])
            end
        else
            local message = interaction:reply{embed = embed,flags = 64}
            message:addReaction(customEmojis["BTLST_Basic_Fail"])
        end
    elseif commandName:match("^help") then
        embed["color"] = 0x00ff00
        embed["title"] = "Help Menu🔷"
        embed["description"] = "Click `📜About Bot` to See Informations About Bot"
        embed["fields"] = {
            {name = "🔍Moderation",value = "Moderation Actions | `Admin Only`",inline = true},
            {name = "🎨Other",value = "Other Commands",inline = true}
        }
        buttons = {
            {
                type = 2,
                style = 3, -- Success (green)
                label = "🤖About Bot",
                custom_id = "aboutbot"
            },
            {
                type = 2,
                style = 1, -- Primary (blue)
                label = "🔍Moderation",
                custom_id = "moderation"
            },
            {
                type = 2,
                style = 2, -- Secondary (gray)
                label = "🎨Other",
                custom_id = "other"
            }
        }
        local res,data = http.request(
            "POST",
            string.format("https://discord.com/api/v10/interactions/%s/%s/callback",interaction.id,interaction.token),
            {
                {"Authorization","Bot "..os.getenv('DISCORD_TOKEN')},
                {"Content-Type","application/json"}
            },
            json.encode({type = 4,data = {embeds = {embed},components = {{type = 1,components = buttons}},flags = 64}})
        )
        print(res.code,data)
    elseif commandName:match("^confirm") then
        if confirmData[interaction.user.id] then
            if confirmData[interaction.user.id]["request"] == "unafk" then
                embed["title"] = "You are No Longer AFK"
                embed["description"] = "Remove AFK Confirmed"
                embed["color"] = 0x00ff00
                embed["fields"] = {
                    {name = "Reason",value = afkData[interaction.user.id]["reason"],inline = true},
                    {name = "Flags",value = tostring(afkData[interaction.user.id]["flags"]),inline = true},
                    {name = "Mention(s) ("..tostring(#afkData[interaction.user.id]["mentioned"])..")",value = "",inline = true}
                }
                for i,v in pairs(afkData[interaction.user.id]["mentioned"]) do embed["fields"][3]["value"] = embed["fields"][3]["value"].." ["..v["username"].."/"..tostring(i).."](https://discord.com/channels/"..v["guildId"].."/"..v["channelId"].."/"..v["messageId"]..")" end
                if embed["fields"][3]["value"] == "" then embed["fields"][3] = nil else embed["fields"][3]["value"] = embed["fields"][3]["value"]:match(" (.)") end
                local message = interaction:reply{embed = embed}
                message:addReaction(customEmojis["BTLST_Success"])
                afkData[interaction.user.id] = nil
                local afkDataJsonW = io.open("afkData.json","w")
                afkDataJsonW:write(json.encode(afkData))
                afkDataJsonW:close()
            else
                embed["title"] = "Error Occured"
                embed["description"] = "Developer Message is "..confirmData[interaction.user.id]["request"]
                local message = interaction:reply{embed = embed}
                message:addReaction(customEmojis["BTLST_Fail"])
            end
        else
            embed["title"] = "No Confirmation Request📂"
            embed["color"] = 0x808080
            interaction:reply{embed = embed}
        end
    elseif commandName:match("^custom%-embeds") then
        local embedJson = options[1]["options"][1]["value"]
        if not json.decode(embedJson) then
            embed["title"] = "Invalid JSON❌"
            embed["fields"] = {
                {name = "Valid Example",value = json.encode({{title = "Custom Embed",description = "Description"},{title = "Custom Embed 2",description = "Description 2"}})}
            }
            embed["color"] = 0xff0000
            interaction:reply{embed = embed,flags = 64}
        else
            if commandName:match("^custom%-embeds ephemeral") then
                interaction:reply{embeds = json.decode(embedJson),flags = 64}
            elseif commandName:match("^custom%-embeds public") then
                if member:hasPermission("administrator") then
                    local message = interaction:reply{embeds = json.decode(embedJson)}
                    if message then message:addReaction(customEmojis["BTLST_Success"]) end
                else
                    embed["title"] = "You Don't Have Permission to Use This Command❌"
                    embed["description"] = "You Need the `Administrator` Permission to Use This Command"
                    embed["color"] = 0xff0000
                    interaction:reply{embed = embed,flags = 64}
                end
            end
        end
    else
        interaction:reply{embed = embed}
    end
    operationIsOnProgress = false
end)
client:on("messageCreate",function(message)
    if message.author.bot then return end
    if operationIsOnProgress then return end
    operationIsOnProgress = true
    local mentionedIds = {}
    local mentionedAfkIds = {}
    local filledEmbeds = {}
    local authorId = message.author.id
    local channelId = message.channel.id
    local filledEmbedsLastIndex = 0
    local resultEmoji = {
        ["BTLST_Fail"] = false,
        ["BTLST_Basic_Fail"] = false,
        ["BTLST_Success"] = false
    }
    for mentionedId in message.content:gmatch("<@(%d+)>") do
        table.insert(mentionedIds,mentionedId)
        if afkData[mentionedId] then table.insert(mentionedAfkIds,mentionedId) end
    end
    if #mentionedAfkIds ~= 0 then
        table.insert(filledEmbeds,{
            title = "Mentioned AFK User(s)❗",
            description = "("..tostring(#mentionedAfkIds)..")",
            color = 0x8b0000,
            fields = {
                {name = "Mentioned:",value = ""},
                {name = "Reason(s):",value = ""}
            },
            timestamp = discordia.Date():toISO('T','Z')
        })
        filledEmbedsLastIndex = #filledEmbeds
        for i,mentionedId2 in pairs(mentionedAfkIds) do
            filledEmbeds[filledEmbedsLastIndex]["fields"][1]["value"] = filledEmbeds[filledEmbedsLastIndex]["fields"][1]["value"].." | <@"..message.guild:getMember(mentionedId2).userId..">"
            filledEmbeds[filledEmbedsLastIndex]["fields"][2]["value"] = filledEmbeds[filledEmbedsLastIndex]["fields"][2]["value"].." | "..afkData[mentionedId2]["reason"].."/"..tostring(i)
            table.insert(afkData[mentionedId2]["mentioned"],{["guildId"] = message.guild.id,["channelId"] = message.channel.id,["messageId"] = message.id,["username"] = message.author.username})
        end
        filledEmbeds[filledEmbedsLastIndex]["fields"][1]["value"] = filledEmbeds[filledEmbedsLastIndex]["fields"][1]["value"]:match(" | (.)")
        filledEmbeds[filledEmbedsLastIndex]["fields"][2]["value"] = filledEmbeds[filledEmbedsLastIndex]["fields"][2]["value"]:match(" | (.)")
        local afkDataJsonW = io.open("afkData.json","w")
        afkDataJsonW:write(json.encode(afkData))
        afkDataJsonW:close()
    end
    if afkData[authorId] and afkData[authorId]["autoUnafk"] then
        table.insert(filledEmbeds,{
            title = "You are No Longer AFK",
            description = "Auto Remove AFK",
            color = 0x00ff00,
            fields = {
                {name = "Reason",value = afkData[authorId]["reason"],inline = true},
                {name = "Flags",value = tostring(afkData[authorId]["flags"]),inline = true},
                {name = "Mention(s) ("..tostring(#afkData[authorId]["mentioned"])..")",value = "",inline = true}
            }
        })
        resultEmoji["BTLST_Success"] = true
        filledEmbedsLastIndex = #filledEmbeds
        if #afkData[authorId]["mentioned"] > 0 then
            for i,v in pairs(afkData[authorId]["mentioned"]) do filledEmbeds[filledEmbedsLastIndex]["fields"][3]["value"] = filledEmbeds[filledEmbedsLastIndex]["fields"][3]["value"].." ["..v["username"].."/"..tostring(i).."](https://discord.com/channels/"..v["guildId"].."/"..v["channelId"].."/"..v["messageId"]..")" end
        else
            filledEmbeds[filledEmbedsLastIndex]["fields"][3] = nil
        end
        afkData[authorId] = nil
        local afkDataJsonW = io.open("afkData.json","w")
        afkDataJsonW:write(json.encode(afkData))
        afkDataJsonW:close()
    end
    if string.lower(message.content):match("donate me") or string.lower(message.content):match("dono me") then
        table.insert(filledEmbeds,{
            title = "Beg in Streams; Not Here",
            color = 0xdeb900
        })
        resultEmoji["BTLST_Basic_Fail"] = true
    end
    if string.lower(message.content):match("my username") or string.lower(message.content):match("my nick") or string.lower(message.content):match("my name") then
        table.insert(filledEmbeds,{
            title = "The Reason of You Saying Your Username is probably because Begging - You Shouldn't Here",
            color = 0xdeb900
        })
    end
    local willReplyWith = {}
    local willReplyWith_flags = 0 -- 2^0 - embeds, 2^1 - message, 2^2 - data
    if #filledEmbeds ~= 0 then
        willReplyWith["embeds"] = filledEmbeds
        willReplyWith_flags = willReplyWith_flags + 2^0
    end
    if willReplyWith_flags ~= 0 then
        local replyMessage = message:reply(willReplyWith)
        for i,v in pairs(resultEmoji) do if v then replyMessage:addReaction(customEmojis[i]) end end
    end
    operationIsOnProgress = false
end)
client:on("raw",function(payload)
    if operationIsOnProgress then return end
    operationIsOnProgress = true
    payload = json.decode(payload)
    if payload.t ~= "INTERACTION_CREATE" then operationIsOnProgress = false return end
    local d = payload.d
    if d.type ~= 3 then operationIsOnProgress = false return end
    print("----------------------------------------------------")
    local button = {
        custom_id = d.data.custom_id,
        user = d.member and d.member.user or d.user,
        member = d.member,
        token = d.token,
        id = d.id,
        message = d.message
    }
    local buttons
    local embed = {
        title = "Button Received but Error Occured",
        description = button.custom_id,
        color = 0x8b0000,
        fields = {},
        timestamp = discordia.Date():toISO('T','Z')
    }
    local postData = {type = 4,data = {embeds = {embed},flags = 64}}
    if button.custom_id == "aboutbot" then
        embed["title"] = "BTLSC"
        embed["description"] = "BTL's Smart Core"
        embed["color"] = 0x0099ffff
        embed["fields"] = {
            {name = "for",value = "Bacon Powers Group eXperience (Discord Server)",inline = true},
            {name = "by",value = "The🐧BTL (`D`irect `M`essages are Open, if You have Questions)",inline = true},
            {name = "Bot Emojis",value = "Check Answer of 'What Does Emojis that Bot Uses Mean?'",inline = false}
        }
        buttons = {
            {
                type = 2,
                style = 1, -- Primary (blue)
                label = "Bot Emojis",
                custom_id = "aboutbot_botemojis"
            }
        }
        postData.data.components = {{type = 1,components = buttons}}
    elseif button.custom_id == "aboutbot_botemojis" then
        local s,e = pcall(function()
            client:getUser(button.user.id):send({content = 
[[<:BTLST_Success:1461391133232992409> => Success
<:BTLST_Basic_Fail:1461391454977917051> => Warn ~ Basic Fail
<:BTLST_Fail:1461391513320947984> => Fail]]})
        end)
        if s then
            embed["title"] = "Sent Details"
            embed["color"] = 0x00ffff
        else
            embed["title"] = "Error Occured"
            embed["description"] = tostring(e)
        end
    elseif button.custom_id == "moderation" then
        if client.guilds:get(d.guild.id):getMember(button.user.id):hasPermission("administrator") or button["user"].username == "baconteams_leader" then
            embed["title"] = "🔍Moderation"
            embed["description"] = "Moderation Actions | `Admin Only`"
            embed["color"] = 0x0000ff
            embed["fields"] = {
                {name = "⭕Add Action",value = "Add Moderation Actions",inline = true},
                {name = "❌Remove Action",value = "Remove Moderation Actions",inline = true},
                {name = "📌Set Action",value = "Set Moderation Actions",inline = true},
                {name = "🎫Other Actions",value = "Other Moderation Actions",inline = true}
            }
            buttons = {
                {
                    type = 2,
                    style = 3, -- Success (green)
                    label = "⭕Add Action",
                    custom_id = "moderation_addaction"
                },
                {
                    type = 2,
                    style = 4, -- Danger (red)
                    label = "❌Remove Action",
                    custom_id = "moderation_removeaction"
                },
                {
                    type = 2,
                    style = 1, -- Primary (blue)
                    label = "📌Set Action",
                    custom_id = "moderation_setaction"
                },
                {
                    type = 2,
                    style = 2, -- Secondary (grey)
                    label = "🎫Other Actions",
                    custom_id = "moderation_otheractions"
                }
            }
            postData.data.components = {{type = 1,components = buttons}}
        else
            embed["title"] = "🔍Moderation"
            embed["description"] = "You Can't View Moderation Page ~ You Don't Have Administrator Permission"
            embed["color"] = 0xff0000
        end
    elseif button.custom_id == "moderation_addaction" then
        embed["title"] = "⭕Add Action"
        embed["description"] = "Add Moderation Actions"
        embed["color"] = 0x00ff00
        embed["fields"] = {
            {name = "⏰Timeout",value = "Timeout a Member",inline = true},
            {name = "🔒Lock",value = "Lock a Channel",inline = true},
            {name = "🔨Ban",value = "Ban a Member",inline = true},
        }
    elseif button.custom_id == "moderation_removeaction" then
        embed["title"] = "❌Remove Action"
        embed["description"] = "Remove Moderation Actions"
        embed["color"] = 0xff0000
        embed["fields"] = {
            {name = "⏰Untimeout",value = "Untimeout a Member",inline = true},
            {name = "🔒Unlock",value = "Unlock a Channel",inline = true},
            {name = "🔨Unban",value = "Unban a Member",inline = true},
        }
    elseif button.custom_id == "moderation_setaction" then
        embed["title"] = "📌Set Action"
        embed["description"] = "Not Added Yet"
    elseif button.custom_id == "moderation_otheractions" then
        embed["title"] = "🎫Other Actions"
        embed["description"] = "Not Added Yet"
    elseif button.custom_id == "other" then
        embed["title"] = "🎨Other"
        embed["description"] = "Only AFK Commands Available for Now"
        buttons = {
            {
                type = 2,
                style = 3, -- Success (green)
                label = "💤AFK",
                custom_id = "other_afk"
            }
        }
    elseif button.custom_id == "other_afk" then
        embed["title"] = "💤AFK"
        embed["description"] = "While You are AFK, If Someone '@Mention'-s You, that Member Will be Notified With Your AFK Reason"
        embed["fields"] = {
            {name = "📌Set",value = "Set AFK Status",inline = true},
            {name = "❌Remove",value = "Remove AFK Status",inline = true},
            {name = "🔬Check",value = "Check AFK Status of a Member",inline = true}
        }
    end
    if button.custom_id:match("_") then table.insert(buttons or {},{type = 2,style = 4,label = "🔙Go Back",custom_id = button.custom_id:match("(.-)_[^_]+$")}) end
    postData.data.embeds = {embed}
    postData = json.encode(postData)
    http.request(
        "POST",
        string.format("https://discord.com/api/v10/interactions/%s/%s/callback",button.id,button.token),
        {
            {"Authorization","Bot "..os.getenv('DISCORD_TOKEN')},
            {"Content-Type","application/json"}
        },
        postData
    )
    operationIsOnProgress = false
end)
client:run("Bot "..os.getenv('DISCORD_TOKEN'))
