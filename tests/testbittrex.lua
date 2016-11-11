require 'pl.app'.require_here ".."
local utest = require 'tools.unittest'
local pltest = require 'pl.test'
local dump = require 'pl.pretty'.dump

local keys = require 'tests.api_testkeys'.bittrex
local session = require 'exchange.bittrex' { key = keys.key, secret = keys.secret }
assert (session)

local make_retry = require 'tools.retry'
local session = make_retry (session, 3, "closed", "timeout")

utest.group "bittrex_pubapi"
{
  test_bogusmarket = function ()
    local r, errmsg = session:markethistory ("BTC", "MRO")

    assert (not r and errmsg == "INVALID_MARKET", errmsg)
  end,

  test_markethistory = function ()
    local r = session:markethistory ("BTC", "LTC")

    assert (r)
  end,

  test_orderbook = function ()
    local r = session:orderbook ("BTC", "LTC")

    assert (r.bids and r.asks)
    assert (r.bids.price and r.asks.price)
    assert (r.bids.amount and r.asks.amount)
    assert (type(r.asks.amount[1]) == "number")
    assert (type(r.asks.price[1])  == "number")
    assert (type(r.bids.amount[1]) == "number")
    assert (type(r.bids.price[1])  == "number")
  end,

  test_mixcasequery = function ()
    local r = session:orderbook ("BtC", "xmR")

    assert (r.bids and r.asks)
    assert (r.bids.price and r.asks.price)
    assert (r.bids.amount and r.asks.amount)
  end
}

local test_orders = {}
utest.group "bittrex_privapi"
{
  test_balance = function ()
    local r = session:balance ()

    dump (r)
    assert (r.BTC)
  end,

  test_tradehistory = function ()
    local r = session:tradehistory ("BTC", "WC")

    dump (r)
  end,

  test_buy = function ()
    local r, errmsg = session:buy ("BTC", "LTC", 0.00015, 1)

    assert (not r and errmsg == "INSUFFICIENT_FUNDS", errmsg)
  end,

  test_sell = function ()
    local r, errmsg = assert (session:sell("BTC", "VTC", 0.15, 0.01))

    dump (r)
    table.insert (test_orders, assert (r.orderNumber))
  end,

  test_cancelorder = function ()
    for _, order in ipairs (test_orders) do
      assert (session:cancelorder ("BTC", "VTC", order))
    end
  end,

  test_openorders = function ()
    local r = session:openorders ("BTC", "VTC")

    dump (r)
  end,
}

utest.run "bittrex_pubapi"
utest.run ("bittrex_privapi", 400) -- ms
