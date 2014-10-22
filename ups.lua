local ev = require( "ev" )
local loop = ev.Loop.default

-- Warning, a value of "null" in json must be checked as follows:
--   if value == json.null # value is null
-- See http://www.kyne.com.au/~mark/software/lua-cjson-manual.html#_null
local json = require("cjson")

local globalEqCache = {}
local globalLastUpdateRender = ""
local globalEqCacheRender = ""

local function updateEqCache( eqCache, eqFeedJson )
  local msg = {}

  local eqFeed = json.decode(eqFeedJson)

  -- each item that appears in both this eqFeed and eqCache is tagged with nonce.
  -- After processing the eqFeed, we scan eqCache and remove items without this nonce.
  -- This allows us to remove cached items which were previously in an eqFeed but are no longer in this eqFeed.
  -- We assume these removed items have been picked.
  local nonce = math.random()

  for _, item in ipairs(eqFeed) do
    if eqCache[item["id"]] == nil then
      -- new item, add it to cache
      eqCache[item["id"]] = item
      table.insert(msg, string.format("#ly%12s #lg-   #lcnew #lg- #w%s", item["zone"], item["description"]))
    else
      if eqCache[item["id"]]["currentBid"] ~= item["currentBid"] then
        table.insert(msg, string.format("#ly%12s #lg- #lc%5s #lg- #w%s", item["zone"], item["currentBid"], item["description"]))
        eqCache[item["id"]] = item
      end
    end
    eqCache[item["id"]]["nonce"] = nonce
  end

  -- scan eqCache and discover items without this nonce
  toRemove = {}
  for itemId, _ in pairs(eqCache) do
    if eqCache[itemId]["nonce"] ~= nonce then
      table.insert(msg, string.format("#ly%12s #lg-  #lcpicked #lg- #w%s", eqCache[itemId]["zone"], eqCache[itemId]["description"]))
      table.insert(toRemove, itemId)
    end
  end

  -- actually remove items discovered in previous step
  for _, itemId in ipairs(toRemove) do
    eqCache[itemId] = nil
  end

  if #msg > 0 then
    table.insert(msg, 1, "#w        zone     bid   item\n------------------------------")
    table.insert(msg, 1, "#lwUPS Activity")
    return table.concat(msg, "\n")
  else
    return ""
  end
end

local function renderEqCache( eqCache )
  local msg = {}

  for id, item in pairs(eqCache) do
    if item["currentBid"] == json.null then
      table.insert(msg, string.format("#ly%12s #lg-       #lg- #w%s", item["zone"], item["description"]))
    else
      table.insert(msg, string.format("#ly%12s #lg- #lc%5s #lg- #w%s", item["zone"], item["currentBid"], item["description"]))
    end
  end
  if #msg > 0 then
    table.insert(msg, 1, "#w        zone     bid   item\n------------------------------")
    table.insert(msg, 1, "#lwUPS Recent Eq")
    return table.concat(msg, "\n")
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

local function cmdUps(client)
  client:msg("%s", globalLastUpdateRender)
end

chat.command( "ups", "user", function(client)
  cmdUps(client)
end, "Show last UPS update")

local function doUpsUpdate()
  local eqFeedJson = capture("curl -m2 " .. chat.config.upsEqFeedUrl .. " 2> /dev/null")
  local updateRender = updateEqCache(globalEqCache, eqFeedJson)
  if updateRender ~= '' then
    globalLastUpdateRender = updateRender
    chat.msg( "%s", globalLastUpdateRender)
  end
  globalEqCacheRender = renderEqCache(globalEqCache)
end

ev.Timer.new( doUpsUpdate, 1, chat.config.upsPollIntervalSeconds):start( loop )
