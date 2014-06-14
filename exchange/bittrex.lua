local https  = require 'ssl.https'
local crypto = require 'crypto'
local json   = require 'dkjson'
local tablex = require 'pl.tablex'
local urlencode_parm = require 'tools.util'.urlencode_parm
local map_transpose  = require 'tools.util'.map_transpose
local dump = require 'pl.pretty'.dump

local url = "https://bittrex.com"
local apiv = "/api/v1.1"

local bittrex_query = function (method, urlpath, headers, data)
  local req_headers = { connection = "keep-alive" }
  if headers then tablex.update (req_headers, headers) end
  local resp = {}
  local r, c, h = https.request
    {
      method = method,
      url = url .. apiv .. urlpath,
      headers = req_headers,
      source = data and ltn12.source.string (data),
      sink = ltn12.sink.table (resp),
    }
  assert (r, c)

  resp = table.concat(resp)
  assert (#resp > 0, "empty response!")
  return json.decode (resp)
end

local bittrex_privquery = function (self, cmd, parm)
  parm = parm or {}
  parm.apikey = self.key
  parm.nonce = os.time()
  parm.market = parm.market and parm.market:upper()

  local urlpath = cmd .. "?" .. urlencode_parm (parm)
  local uri = url .. apiv .. urlpath
  local headers = { apisign = crypto.hmac.digest ("sha512", uri, self.secret) }

  return bittrex_query ("GET", urlpath, headers)
end

local bittrex_pubquery = function (self, cmd, parm)
  parm = parm or {}
  parm.market = parm.market and parm.market:upper()

  return bittrex_query ("GET", string.format ("%s?%s", 
                                              cmd, urlencode_parm (parm)))
end

local bittrex_api = {}
function bittrex_api:balance ()
  local balances = bittrex_privquery (self, "/account/getbalances")
  assert (balances.success, balances.message)

  balances = balances.result
  for _, coin in pairs (balances) do
    local avail = tonumber (coin.Available)
    balances[coin.Currency] = avail > 0 and avail or nil
  end
  balances.BTC = balances.BTC or 0
  return balances
end

function bittrex_api:tradehistory (market1, market2)
  return bittrex_privquery (self, "/account/getorderhistory", {market = market1 .. "-" .. market2})
end

function bittrex_api:buy (market1, market2, rate, quantity)
  return bittrex_privquery (self, "/market/buylimit", {market = market1 .. "-" .. market2, rate = rate, quantity = quantity})
end

function bittrex_api:sell (market1, market2, rate, quantity)
  return bittrex_privquery (self, "/market/selllimit", {market = market1 .. "-" .. market2, rate = rate, quantity = quantity})
end

function bittrex_api:cancelorder (market1, market2, ordernumber)
  return pol_privquery (self, "/market/cancel", {market = market1 .. "-" .. market2, uuid = ordernumber})
end

function bittrex_api:markethistory (market1, market2)
  return bittrex_pubquery (self, "/public/getmarkethistory", {market = market1 .. "-" .. market2})
end

function bittrex_api:orderbook (market1, market2)
  local r = bittrex_pubquery (self, "/public/getorderbook",
                              {market = market1 .. "-" .. market2,
                              ["type"] = "both"})
  r = assert (r.success, r.message) and r.result

  r.buy  = map_transpose (r.buy, { Rate = "price", Quantity = "amount" })
  r.sell = map_transpose (r.sell, { Rate = "price", Quantity = "amount" })

  return r
end

function bittrex_api:openorders (market1, market2)
  return bittrex_privquery (self, "/market/getopenorders", {market = market1 .. "-" .. market2})
end

local session_mt = { __index = bittrex_api }
function bittrex_api:__call (t)
  assert (t and t.key and t.secret, "No api key/secret parameter given.")

  return setmetatable({ key = t.key, secret = t.secret }, session_mt)
end

return setmetatable(bittrex_api, bittrex_api)
