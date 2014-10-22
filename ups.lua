local ev = require( "ev" )
local loop = ev.Loop.default

-- Warning, a value of "null" in json must be checked as follows:
--   if value == json.null # value is null
-- See http://www.kyne.com.au/~mark/software/lua-cjson-manual.html#_null
local json = require("cjson")

local globalEqCache = {}
local globalLastUpdate = nil

-- return a string to send to clients for the passed updates in eqFeedJson, given the current state in passed eqCache
local function updateEqCache( eqCache, eqFeedJson )
  local msg = {}

  local eqFeed = json.decode(eqFeedJson)

  for _, item in ipairs(eqFeed) do
    if eqCache[item["id"]] == nil then
      -- new item, add it to cache
      eqCache[item["id"]] = item
      table.insert(msg, string.format("#ly%12s #lg-   #lcnew #lg- #w%s", item["zone"], item["description"]))
    else
      -- TODO - picked items!!!
      if eqCache[item["id"]]["currentBid"] ~= item["currentBid"] then
        -- upbid on existing item
        table.insert(msg, string.format("#ly%12s #lg- #lc%5s #lg- #w%s", item["zone"], item["currentBid"], item["description"]))
        eqCache[item["id"]] = item
      end
    end
  end
  if next(msg) ~= nil then
    table.insert(msg, 1, "#lw        zone     bid   item\n------------------------------")
    table.insert(msg, 1, "#lwUPS Activity")
    return table.concat( msg, "\n")
  else
    return ""
  end
end

local function renderEqCache( eqCache )
  local msg = {}

  -- TODO - would be nice to have eq sorted by currentBidTime
  -- TODO - most of this output is cut off due to max socket:send length. Output isn't buffered.
  for id, item in pairs(eqCache) do
    if item["currentBid"] == json.null then
      table.insert(msg, string.format("#ly%12s #lg-       #lg- #w%s", item["zone"], item["description"]))
    else
      table.insert(msg, string.format("#ly%12s #lg- #lc%5s #lg- #w%s", item["zone"], item["currentBid"], item["description"]))
    end
  end
  if next(msg) ~= nil then
    table.insert(msg, 1, "#lw        zone     bid   item\n------------------------------")
    table.insert(msg, 1, "#lwUPS Recent Eq")
    return table.concat( msg, "\n")
  else
    return ""
  end
end

-- Synchronously run the passed console cmd and return its stdout
function capture(cmd)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return s
end

local function cmdUps(client, eqCache)
  client:msg( "%s", renderEqCache(eqCache))
end

chat.command( "ups", "user", function(client)
  cmdUps(client, globalEqCache)
end, "Show recent UPS eq")

local function doUpsUpdate()
  local eqFeedJson = capture("curl -m2 " .. chat.config.upsEqFeedUrl .. " 2> /dev/null")
  globalLastUpdate = updateEqCache(globalEqCache, eqFeedJson)
  if globalLastUpdate ~= '' then
    chat.msg( "%s", globalLastUpdate)
  end
end

ev.Timer.new( doUpsUpdate, 1, chat.config.upsPollIntervalSeconds):start( loop )
