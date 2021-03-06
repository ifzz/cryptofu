require 'pl.app'.require_here ".."
local utest  = require 'tools.unittest'
local stack  = require 'tools.simplestack'
local tablex = require 'pl.tablex'
local dump   = require 'pl.pretty'.dump

local keys = require 'tests.api_testkeys'.btce
local publicapi = require 'exchange.btce'

utest.group "btce_publicapi"
{
  test_publicapinames = function()
    assert (publicapi.orderbook)
    assert (publicapi.markethistory)
    
    -- unauthenticated access should only contain public functions
    assert (not publicapi.buy)
    assert (not publicapi.sell)
    assert (not publicapi.cancelorder)
    assert (not publicapi.moveorder)
    assert (not publicapi.openorders)
    assert (not publicapi.tradehistory)
    assert (not publicapi.balance)
  end,

  test_bogusmarket = function ()
    local r, errmsg = publicapi:markethistory ("BTC", "___")

    assert (not r and errmsg == "Invalid pair name: btc____", errmsg)
  end,

  test_markethistory = function ()
    local r = assert (publicapi:markethistory ("BTC", "LTC"))

    assert (r and r[1])
    assert (r[1].timestamp)
    assert (r[1].price > 0)
    assert (r[1].amount > 0)
  end,

  test_orderbook = function ()
    local r = publicapi:orderbook ("BTC", "LTC")

    assert (r.bids and r.asks)
    assert (r.asks.amount and r.bids.amount)
    assert (r.asks.price and r.bids.price)
    assert (r.bids.price[1] < r.asks.price[1])
    assert (type(r.asks.amount[1]) == 'number')
    assert (type(r.asks.price[1])  == 'number')
    assert (type(r.bids.amount[1]) == 'number')
    assert (type(r.bids.price[1])  == 'number')
  end,

  test_mixcasequery = function ()
    local r = publicapi:orderbook ("DsH", "btC")

    assert (r.bids and r.asks)
    assert (r.asks.amount and r.bids.amount)
    assert (r.asks.price and r.bids.price)
    assert (type(r.asks.amount[1]) == 'number')
    assert (type(r.asks.price[1])  == 'number')
    assert (type(r.bids.amount[1]) == 'number')
    assert (type(r.bids.price[1])  == 'number')
  end
}

local make_retry = require 'tools.retry'
local tradeapi = assert (publicapi.tradingapi (keys.key, keys.secret))

local test_orders = stack ()
utest.group "btce_tradingapi"
{
  test_tradingapinames = function()
    -- authenticated access should contain only trade functions
    assert (tradeapi.buy)
    assert (tradeapi.sell)
    assert (tradeapi.cancelorder)
    assert (tradeapi.openorders)
    assert (tradeapi.tradehistory)
    assert (tradeapi.balance)
  end,

  test_balance = function ()
    local r = assert (tradeapi:balance ())

    local k, v = next (r)
    assert (type(k) == 'string')
    assert (type(v) == 'number')
    assert (r.btc)
    assert (r.usd)
  end,

  test_tradehistory = function ()
    local r, errmsg = tradeapi:tradehistory ("BTC", "LTC")

    assert (r or errmsg == "no trades", errmsg)
    if not r then return end
    assert (type(r) == 'table', errmsg)
    assert (#r > 0)
  end,

  test_buy = function ()
    local r, errmsg = tradeapi:buy ("BTC", "USD", 0.15, 10)

    assert (errmsg == "It is not enough USD for purchase" or (r and r.order_id), errmsg)
    if r then
      test_orders:push (assert (r.orderNumber))
    end
  end,

  test_sell = function ()
    local r, errmsg = tradeapi:sell ("USD", "BTC", 4000, 0.01)

    assert (errmsg == "It is not enough BTC in the account for sale." or (r and r.order_id), errmsg)
    if r then 
      test_orders:push (assert (r.orderNumber))
    end
  end,
}

utest.group "btce_orderlist"
{
  test_openorders = function ()
    local r, errmsg = tradeapi:openorders ("USD", "BTC")

    assert (r or errmsg == "no orders", errmsg)
    if not r then return end
    assert (type(r) == 'table')
    assert (r[1] == nil or r[1].orderNumber)
  end,
}

utest.group "btce_cancels"
{
  test_cancelinvalidorder = function ()
    local r, errmsg = tradeapi:cancelorder ("BAD_ORDERNUMBER")
    assert (errmsg == "invalid parameter: order_id", errmsg)
  end,

  test_cancelorder = function ()
    if test_orders:empty () then return end

    assert (not test_orders:empty (), "No test orders to cancel.")
    while not test_orders:empty () do
      r = assert (tradeapi:cancelorder (test_orders:top ()))
      assert (r.success == 1)
      test_orders:pop ()
    end
  end,
}

utest.run "btce_publicapi"
utest.run ("btce_tradingapi", 500) -- ms
utest.run "btce_orderlist"
utest.run "btce_cancels"
