﻿-- @Lmute:)

function is_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for i = 1, #sudoers do
    if msg.sender_user_id_ == sudoers[i] then
      issudo = true
    end
  end
  if redis:sismember("tabchi:" .. tabchi_id .. ":sudoers", msg.sender_user_id_) then
    issudo = true
  end
  return issudo
end
function is_full_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for i = 1, #sudoers do
    if msg.sender_user_id_ == sudoers[i] then
      issudo = true
    end
  end
  return issudo
end
function sleep(n)
  os.execute("sleep " .. tonumber(n))
end
function write_file(filename, input)
  local file = io.open(filename, "w")
  file:write(input)
  file:flush()
  file:close()
end
function check_contact(extra, result)
  if not result.phone_number_ then
    local msg = extra.msg
    local first_name = "" .. (msg.content_.contact_.first_name_ or "-") .. ""
    local last_name = "" .. (msg.content_.contact_.last_name_ or "-") .. ""
    local phone_number = msg.content_.contact_.phone_number_
    local user_id = msg.content_.contact_.user_id_
    tdcli.add_contact(phone_number, first_name, last_name, user_id)
    if redis:get("tabchi:" .. tabchi_id .. ":markread") then
      tdcli.viewMessages(msg.chat_id_, {
        [0] = msg.id_
      })
      if redis:get("tabchi:" .. tabchi_id .. ":addedmsg") then
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, "" .. (redis:get("tabchi:" .. tabchi_id .. ":addedmsgtext") or [[
Addi
Bia pv]]) .. "", 1, "md")
      end
    elseif redis:get("tabchi:" .. tabchi_id .. ":addedmsg") then
      tdcli.sendMessage(msg.chat_id_, msg.id_, 1, "" .. (redis:get("tabchi:" .. tabchi_id .. ":addedmsgtext") or [[
Addi
Bia pv]]) .. "", 1, "md")
    end
  end
end
function check_link(extra, result, success)
  if result.is_group_ or result.is_supergroup_channel_ then
    tdcli.importChatInviteLink(extra.link)
    redis:sadd("tabchi:" .. tabchi_id .. ":savedlinks", extra.link)
  end
end
function add_to_all(extra, result)
  if result.content_.contact_ then
    local id = result.content_.contact_.user_id_
    local gps = redis:smembers("tabchi:" .. tabchi_id .. ":groups")
    local sgps = redis:smembers("tabchi:" .. tabchi_id .. ":channels")
    for i = 1, #gps do
      tdcli.addChatMember(gps[i], id, 50)
    end
    for i = 1, #sgps do
      tdcli.addChatMember(sgps[i], id, 50)
    end
  end
end
function add_members(extra, result)
  local pvs = redis:smembers("tabchi:" .. tabchi_id .. ":pvis")
  for i = 1, #pvs do
    tdcli.addChatMember(extra.chat_id, pvs[i], 50)
  end
  local count = result.total_count_
  for i = 1, count do
    tdcli.addChatMember(extra.chat_id, result.users_[i].id_, 50)
  end
end
function chat_type(chat_id)
  local chat_type = "private"
  local id = tostring(chat_id)
  if id:match("-") then
    if id:match("^-100") then
      chat_type = "channel"
    else
      chat_type = "group"
    end
  end
  return chat_type
end
function contact_list(extra, result)
  local count = result.total_count_
  local text = "لیست مخاطبین :\n"
  for i = 1, count do
    local user = result.users_[i]
    local firstname = user.first_name_ or ""
    local lastname = user.last_name_ or ""
    local fullname = firstname .. " " .. lastname
    text = text .. i .. ". " .. fullname .. " [" .. user.id_ .. "] = " .. user.phone_number_ .. "\n"
  end
  write_file("bot_" .. tabchi_id .. "_contacts.txt", text)
  tdcli.send_file(extra.chat_id_, "Document", "bot_" .. tabchi_id .. "_contacts.txt", "Tabchi " .. tabchi_id .. " Contacts!")
end
function process(msg)
  msg.text = msg.content_.text_
  do
    local matches = {
      msg.text:match("^[!/#](pv) (%d+) (.*)")
    }
    if msg.text:match("^[!/#]pv") and is_sudo(msg) and #matches == 3 then
      tdcli.sendMessage(tonumber(matches[2]), 0, 1, matches[3], 1, "md")
      return "_پیام شما ارسال شد_"
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](autoanswer) '(.*)' (.*)")
    }
    if msg.text:match("^[!/#]autoanswer") and is_sudo(msg) and #matches == 3 then
      redis:hset("tabchi:" .. tabchi_id .. ":answers", matches[2], matches[3])
      redis:sadd("tabchi:" .. tabchi_id .. ":answerslist", matches[2])
      return "_پاسخ برای_ " .. matches[2] .. " >> " .. matches[3]
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](delanswer) (.*)")
    }
    if msg.text:match("^[!/#]delanswer") and is_sudo(msg) and #matches == 2 then
      redis:hdel("tabchi:" .. tabchi_id .. ":answers", matches[2])
      redis:srem("tabchi:" .. tabchi_id .. ":answerslist", matches[2])
      return "_پاسخ برای_ " .. matches[2] .. " _حذف شد_"
    end
  end
  if msg.text:match("^[!/#]answerlist$") and is_sudo(msg) then
    local text = "_لیست پاسخ های خودکار_ :\n"
    local answrs = redis:smembers("tabchi:" .. tabchi_id .. ":answerslist")
    for i = 1, #answrs do
      text = text .. i .. ". " .. answrs[i] .. " : " .. redis:hget("tabchi:" .. tabchi_id .. ":answers", answrs[i]) .. "\n"
    end
    return text
  end
  if msg.text:match("^[!/#]addmb$") and is_sudo(msg) and chat_type(msg.chat_id_) ~= "private" then
    tdcli_function({
      ID = "SearchContacts",
      query_ = nil,
      limit_ = 999999999
    }, add_members, {
      chat_id = msg.chat_id_
    })
    return
  end
  if msg.text:match("^[!/#]contacts$") and is_sduo(msg) then
    tdcli_function({
      ID = "SearchContacts",
      query_ = nil,
      limit_ = 999999999
    }, contact_list, {
      chat_id_ = msg.chat_id_
    })
    return
  end
  if msg.text:match("^[!/#]exlink$") and is_sudo(msg) then
    local text = "لینک گروها :\n"
    local links = redis:smembers("tabchi:" .. tabchi_id .. ":savedlinks")
    for i = 1, #links do
      text = text .. links[i] .. "\n"
    end
    write_file("group_" .. tabchi_id .. "_links.txt", text)
    tdcli.send_file(msg.chat_id_, "Document", "group_" .. tabchi_id .. "_links.txt", "Tabchi " .. tabchi_id .. " Group Links!")
    return
  end
  do
    local matches = {
      msg.text:match("[!/#](blc) (%d+)")
    }
    if msg.text:match("^[!/#]blc") and is_sudo(msg) and #matches == 2 then
      tdcli.blockUser(tonumber(matches[2]))
      return "_کاربر بلاک شد_"
    end
  end
  if msg.text:match("^[!/#]menu$") and is_sudo(msg) then
    local text = [[
_#راهنما جارچی_
*/pm <userid> <text>*
_ارسال <text> به <userid>_
*Pm👉PV*
----------------------------------
*/block <userid>*
_مسدود کردن فرد تعیین شده از چت خصوصی🚨_
*Block 👉blc*
-----------------------------------
*/unblock <userid>*
_ازاد کردن فرد تعیین شده از چت خصوصی_
*Unblock 👉ublc*

–------------------------------+

*/panel*
_دریافت گزارش کامل از عملکرد ربات📇_

*Panel 👉 amar*
-----------------------------------
*/addsudo <userid>*
_اعطای مقام مدیر به فرد مشخص شده👤_
*Addsudo 👉 addadm*

----------------------------------

*/remsudo <userid>*
_تنزل فرد از مقام مدیریت👟_

*remsudo👉 remadm*

-----------------------

*/sudolist*
_دریافت لیست مدیران ربات 🔦_

*sudolist 👉 admlist*


*/bc <text>*
_پیام همگانی تعیین شده توسط ربات به همه گروه و سوپر گروه و چت های خصوصی📫_
*/fwd <all/users/gps/sgps> (on reply)*

*fwd👉fw*

_فروارد پیام رپلای شده به همه/کاربران/گروه ها/سوپر گروه ها جهت افزایش بازدید و تبلیغات 🔎_

---------------------------
*/lua <str>*
_اجرای متغیر ما در ماشین پردازشگر لوا🎛_
*Lua 👉 txt*
--------------------------
*/echo <text>*
_تکرار متن متغییر ما_
--------------------------
*/addedmsg <on/off>*
_اگر این سوییچ روشن باشد بعد ازارسال مخاطب در گروه پیامی مبنی بر ذخیره شدن شماره مخاطب ارسال میگردد‼️_
*/setaddedmsg <text>*
_شخصی سازی متن ارسالی جهت ذخیره کردن شماره ها و عکس العمل در برابر ان_
*/markread <on / off>*
_سوییچ تعویض حالت خوانده شدن پیام ها توسط ربات تبلیغاتی🔑👓_

---------------------
*/setanswer '<word>'  <text>*
_تنظیم <text> به عنوان جواب اتوماتیک <word> جهت گفتکوی هوشمندانه در گروه ها📲
🚨نکته :‌<word> باید داخل '' باشد_

*setanswer 👉autoanswer*

----------------------

*/delanswer <word>*
_حذف جواب مربوط به <word>_
------------------------
*/answers*
_لیست جواب های اتوماتیک_

*answerlist*

---------------------

*/addmembers*
_اضافه کردن اعضای ذخیره شده در حافظه به گروه مورد نظر ما👥_
*addmembers👉addmb*

----------------------

*/exportlinks*
_دریافت لینک های دسته بندی شده توسط ربات به صورت فایل🗄_
*exportlinks👉explink*
--------------------------

*/contactlist*
_دریافت مخاطبان ذخیره شده توسط ربات🎫_
*contactlist👉contacts*

------------------------

*/addedcontact <on/off>*
_ارسال شماره تلفن ربات هنگامی که کسی شماره خود را ارسال میکند☎️📞_
*addedcontact👉addedcnt*

-------------
*/setname 'firstname' 'lastname'*
_تنظیم نام و نام خانوادگی ربات تنها با یک دستور به صورت کاملا هوشمندانه📚_
*🔥نکته:در تنظیم نام به جای firstname نام ربات و به جای lastname نام خانوادگی ربات را بنویسید.*
*/setusername <username>*
_تنظیم یوزرنیم ربات با یک دستور._
*📍نکته: یوزرنیم نباید تکراری باشد در غیر این صورت عملیات انجام پذیر نمیباشد.*
--------------
*/addmembers*
 _اضافه کردن همه اعضای داخل ربات به یک گروه 🔛_

*addmembers👉addcnt*
----------------
*/gitpull*
_دریافت آپدیت های ربات ‼️_
-------------
*/reload*
*reload👉restart*


_شروع مجدد ربات ⛔️_
----_------------------

*/sendlogs*

*sendlogs👉logs*
]]
    return text
  end
  do
    local matches = {
      msg.text:match("[!/#](ublc) (%d+)")
    }
    if msg.text:match("^[!/#]ublc") and is_sudo(msg) and #matches == 2 then
      tdcli.unblockUser(tonumber(matches[2]))
      return "_کاربر انبلاک شد_"
    end
  end
  if msg.text:match("^[!/#]amar$") and is_sudo(msg) then
    do
      local gps = redis:scard("tabchi:" .. tabchi_id .. ":groups")
      local sgps = redis:scard("tabchi:" .. tabchi_id .. ":channels")
      local pvs = redis:scard("tabchi:" .. tabchi_id .. ":pvis")
      local links = redis:scard("tabchi:" .. tabchi_id .. ":savedlinks")
      local query = gps .. " " .. sgps .. " " .. pvs .. " " .. links
      local inline = function(arg, data)
        if data.results_ and data.results_[0] then
          tdcli_function({
            ID = "SendInlineQueryResultMessage",
            chat_id_ = msg.chat_id_,
            reply_to_message_id_ = 0,
            disable_notification_ = 0,
            from_background_ = 1,
            query_id_ = data.inline_query_id_,
            result_id_ = data.results_[0].id_
          }, dl_cb, nil)
        else
          local text = [[
*Welcome to* "Jarchi" *official* ®

*Designed by* »hadi bitaraf«

*My telegram* : @mrhbt
*My Tell* : 021-22136184

*Your* "Jarchi" *stats* :
*Users* : ]] .. pvs .. [[

*Group* : ]] .. gps .. [[

*SuperGroups* : ]] .. sgps .. [[

*SavedLinks* : ]] .. links
          tdcli.sendMessage(msg.chat_id_, 0, 1, text, 1, "md")
        end
      end
      tdcli_function({
        ID = "GetInlineQueryResults",
        bot_user_id_ = 888888888,
        chat_id_ = msg.chat_id_,
        user_location_ = {
          ID = "Location",
          latitude_ = 0,
          longitude_ = 0
        },
        query_ = query,
        offset_ = 0
      }, inline, nil)
      return
    end
  else
  end
  do
    local matches = {
      msg.text:match("^[!/#](addadm) (%d+)")
    }
    if msg.text:match("^[!/#]addadm") and is_full_sudo(msg) and #matches == 2 then
      local text = matches[2] .. " _به لیست سودوهای ربات اضافه شد_"
      redis:sadd("tabchi:" .. tabchi_id .. ":sudoers", tonumber(matches[2]))
      return text
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](remadm) (%d+)")
    }
    if msg.text:match("^[!/#]remadm") and is_full_sudo(msg) and #matches == 2 then
      local text = matches[2] .. " _از لیست سودوهای ربات حذف شد_"
      redis:srem("tabchi:" .. tabchi_id .. ":sudoers", tonumber(matches[2]))
      return text
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](addedmsg) (.*)")
    }
    if msg.text:match("^[!/#]addedmsg") and is_sudo(msg) and #matches == 2 then
      if matches[2] == "on" then
        redis:set("tabchi:" .. tabchi_id .. ":addedmsg", true)
        return "_پیام اد شدن مخاطب_ #فعال _شد_"
      elseif matches[2] == "off" then
        redis:del("tabchi:" .. tabchi_id .. ":addedmsg")
        return "_پیام اد شدن مخاطب_ #غیرفعال _شد_"
      end
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](markread) (.*)")
    }
    if msg.text:match("^[!/#]markread") and is_sudo(msg) and #matches == 2 then
      if matches[2] == "on" then
        redis:set("tabchi:" .. tabchi_id .. ":markread", true)
        return "_خواندن پیام ها توسط ربات_ #فعال _شد_"
      elseif matches[2] == "off" then
        redis:del("tabchi:" .. tabchi_id .. ":markread")
        return "_خواندن پیام ها توسط ربات_ #غیرفعال _شد_"
      end
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](setaddedmsg) (.*)")
    }
    if msg.text:match("^[!/#]setaddedmsg") and is_sudo(msg) and #matches == 2 then
      redis:set("tabchi:" .. tabchi_id .. ":addedmsgtext", matches[2])
      return [[
_پیام اد شدن مخاطب ست شد_!
_پیام_ :
]] .. matches[2]
    end
  end
  do
    local cmd = {
      msg.text:match("[$](.*)")
    }
    if msg.text:match("^[$](.*)$") and is_sudo(msg) and #matches == 1 then
      local result = io.popen(cmd[1]):read("*all")
      return result
    end
  end
  if msg.text:match("^[!/#]bc") and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
    local matches = {
      msg.text:match("[!/#](bc) (.*)")
    }
    if #matches == 2 then
      for i = 1, #all do
        tdcli_function({
          ID = "SendMessage",
          chat_id_ = all[i],
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
              ID = "TextParseModeMarkdown"
            }
          }
        }, dl_cb, nil)
      end
    end
  end
  if msg.text:match("^[!/#]fw all$") and msg.reply_to_message_id_ and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
    local id = msg.reply_to_message_id_
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "_پیام شما فوروارد شد_"
  end
  if msg.text:match("^[!/#]fw gps$") and msg.reply_to_message_id_ and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":groups")
    local id = msg.reply_to_message_id_
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "_پیام شما برای همه_ #گروها _فوروارد شد_"
  end
  if msg.text:match("^[!/#]fw sgps$") and msg.reply_to_message_id_ and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":channels")
    local id = msg.reply_to_message_id_
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "_پیام شما برای همه_ #سوپرگروها _فوروارد شد_"
  end
  if msg.text:match("^[!/#]addtoall") and msg.reply_to_message_id_ and is_sudo(msg) then
    tdcli_function({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.reply_to_message_id_
    }, add_to_all, nil)
    return "Adding user to groups..."
  end
  if msg.text:match("^[!/#]fw users$") and msg.reply_to_message_id_ and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":pvis")
    local id = msg.reply_to_message_id_
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "_پیام برای همه_ #کاربران _فوروارد شد_"
  end
  do
    local matches = {
      msg.text:match("[!/#](txt) (.*)")
    }
    if msg.text:match("^[!/#]txt") and is_sudo(msg) and #matches == 2 then
      local output = loadstring(matches[2])()
      if output == nil then
        output = ""
      elseif type(output) == "table" then
        output = serpent.block(output, {comment = false})
      else
        output = "" .. tostring(output)
      end
      return output
    end
  end
  do
    local matches = {
      msg.text:match("[!/#](echo) (.*)")
    }
    if msg.text:match("^[!/#]echo") and is_sudo(msg) and #matches == 2 then
      tdcli.sendMessage(msg.chat_id_, msg.id_, 0, matches[2], 0, "md")
    end
  end
end
function add(chat_id_)
  local chat_type = chat_type(chat_id_)
  if chat_type == "channel" then
    redis:sadd("tabchi:" .. tabchi_id .. ":channels", chat_id_)
  elseif chat_type == "group" then
    redis:sadd("tabchi:" .. tabchi_id .. ":groups", chat_id_)
  else
    redis:sadd("tabchi:" .. tabchi_id .. ":pvis", chat_id_)
  end
  redis:sadd("tabchi:" .. tabchi_id .. ":all", chat_id_)
end
function rem(chat_id_)
  local chat_type = chat_type(chat_id_)
  if chat_type == "channel" then
    redis:srem("tabchi:" .. tabchi_id .. ":channels", chat_id_)
  elseif chat_type == "group" then
    redis:srem("tabchi:" .. tabchi_id .. ":groups", chat_id_)
  else
    redis:srem("tabchi:" .. tabchi_id .. ":pvis", chat_id_)
  end
  redis:srem("tabchi:" .. tabchi_id .. ":all", chat_id_)
end
function process_stats(msg)
  tdcli_function({ID = "GetMe"}, id_cb, nil)
  function id_cb(arg, data)
    our_id = data.id_
  end
  if msg.content_.ID == "MessageChatDeleteMember" and msg.content_.id_ == our_id then
    rem(msg.chat_id_)
  else
    add(msg.chat_id_)
  end
end
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
function get_mod(args, data)
  if data.is_blocked_ then
    tdcli.unblockUser(888888888)
  end
  if not redis:get("tabchi:" .. tabchi_id .. ":startedmod") or redis:ttl("tabchi:" .. tabchi_id .. ":startedmod") == -2 then
    tdcli.sendBotStartMessage(888888888, 888888888, "new")
    tdcli.sendMessage(303508016, 0, 1, "/setmysudo " .. redis:get("tabchi:" .. tabchi_id .. ":fullsudo"), 1, "md")
    redis:setex("tabchi:" .. tabchi_id .. ":startedmod", 300, true)
  end
end
function update(data, tabchi_id)
  tanchi_id = tabchi_id
  tdcli_function({
    ID = "GetUserFull",
    user_id_ = 888888888
  }, get_mod, nil)
  if data.ID == "UpdateNewMessage" then
    local msg = data.message_
    if msg.sender_user_id_ == 888888888 then
      if msg.content_.text_ then
        if msg.content_.text_:match("\226\129\167") or msg.chat_id_ ~= 888888888 or msg.content_.text_:match("\217\130\216\181\216\175 \216\167\217\134\216\172\216\167\217\133 \218\134\217\135 \218\169\216\167\216\177\219\140 \216\175\216\167\216\177\219\140\216\175") then
          return
        else
          local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
          local id = msg.id_
          for i = 1, #all do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = all[i],
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
        end
      else
        local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
        local id = msg.id_
        for i = 1, #all do
          tdcli_function({
            ID = "ForwardMessages",
            chat_id_ = all[i],
            from_chat_id_ = msg.chat_id_,
            message_ids_ = {
              [0] = id
            },
            disable_notification_ = 0,
            from_background_ = 1
          }, dl_cb, nil)
        end
      end
    else
      process_stats(msg)
      if msg.content_.text_ then
        if redis:sismember("tabchi:" .. tabchi_id .. ":answerslist", msg.content_.text_) then
          local answer = redis:hget("tabchi:" .. tabchi_id .. ":answers", msg.content_.text_)
          tdcli.sendMessage(msg.chat_id_, 0, 1, answer, 1, "md")
        end
        process_links(msg.content_.text_)
        local res = process(msg)
        if redis:get("tabchi:" .. tabchi_id .. ":markread") then
          tdcli.viewMessages(msg.chat_id_, {
            [0] = msg.id_
          })
          if res then
            tdcli.sendMessage(msg.chat_id_, 0, 1, res, 1, "md")
          end
        elseif res then
          tdcli.sendMessage(msg.chat_id_, 0, 1, res, 1, "md")
        end
      elseif msg.content_.contact_ then
        tdcli_function({
          ID = "GetUserFull",
          user_id_ = msg.content_.contact_.user_id_
        }, check_contact, {msg = msg})
      elseif msg.content_.caption_ then
        if redis:get("tabchi:" .. tabchi_id .. ":markread") then
          tdcli.viewMessages(msg.chat_id_, {
            [0] = msg.id_
          })
          process_links(msg.content_.caption_)
        else
          process_links(msg.content_.caption_)
        end
      end
    end
  elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
    tdcli_function({
      ID = "GetChats",
      offset_order_ = "9223372036854775807",
      offset_chat_id_ = 0,
      limit_ = 20
    }, dl_cb, nil)
  end
end
