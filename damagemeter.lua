local globalDamageMeter = {}

local function cmdDamageMeterReport(client, args)
  local damageJustDone = tonumber( args )
  -- client:msg("%s%d", "Your damage meter script is working (probably :). You did this much damage (only precise when your target is level 31): ", damageJustDone)

  if globalDamageMeter[client.name] == nil then
    globalDamageMeter[client.name] = 0
  end

  globalDamageMeter[client.name] = globalDamageMeter[client.name] + damageJustDone
end

local function renderDamageMeter()
  local msg = {}
  
  local groupTotalDamage = 0

  for clientName, clientTotalDamage in pairs(globalDamageMeter) do
    groupTotalDamage = groupTotalDamage + clientTotalDamage
  end
  
  for clientName, clientTotalDamage in pairs(globalDamageMeter) do
    local clientPercentDamage = clientTotalDamage * 100.0 / groupTotalDamage
    table.insert(msg, string.format("#ly%12s #lg-     #w%4d%%", clientName, clientPercentDamage))    
  end

  if #msg > 0 then
    table.insert(msg, 1, "#w        Name     % Total Damage\n--------------------------------")
    return table.concat(msg, "\n")
  else
    return "#w        (No Damage Recorded)"
  end
end

local function cmdDamageMeter(client)
  chat.msg("%s shows the damage meter:\n%s", client.name, renderDamageMeter())
end

local function cmdDamageMeterReset(client)
  globalDamageMeter = {}
  chat.msg("%s resets the damage meter.", client.name)
end

chat.command( "dm", "user", function(client)
  cmdDamageMeter(client)
end, "Show damage meter to all users")

chat.command( "dmreset", "user", function(client)
  cmdDamageMeterReset(client)
end, "Reset damage meter")

chat.command( "dmr", "user", {
  [ "^DamageMeterMagic Damage:(%d+) XpPerDamage:31$" ] = cmdDamageMeterReport,    
}, " --> Do not use this command. Damage Meter Script automated use only.", "do not use" )
