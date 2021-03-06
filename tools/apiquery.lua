local socket  = require 'socket'
local ltn12   = require 'ltn12'
local https   = require 'ssl.https'
local json    = require 'dkjson'
local tablex  = require 'pl.tablex'
local z       = require 'zlib' -- for gzip


socket.http.TIMEOUT = 3 -- set timeout for http request
local https_request = function (method, urlbase, urlpath, headers, postdata)
  urlpath = urlpath or ""
  local req_headers =
    {
      connection = "keep-alive",
      ["accept-encoding"] = "gzip",
      ["content-length"] = postdata and #postdata,
    }
  if headers then tablex.update (req_headers, headers) end
  local resp = {}
  local r, c, h, s = https.request
    {
      method = method,
      url = urlbase .. urlpath,
      headers = req_headers,
      sink = ltn12.sink.table (resp),
      source = postdata and ltn12.source.string (postdata),
    }
  assert (r and type(c) == 'number', s or c)

  resp = table.concat (resp)
  if h["content-encoding"] == "gzip" then
    resp = z.inflate (resp):read "*a"
  end

  local json_resp, _, errmsg = json.decode (resp)
  local debugmsg = (s or c) .. " -> %s:\n  %s .."
  debugmsg = debugmsg:format (tostring (errmsg), resp:sub (1, 320))

  assert (not errmsg and type(json_resp) == 'table', debugmsg)
  return json_resp, c
end

local apiquery = {}
apiquery.getrequest  = function (urlbase, urlpath, headers)
  return https_request ("GET", urlbase, urlpath, headers)
end

apiquery.postrequest = function (urlbase, urlpath, headers, postdata)
  return https_request ("POST", urlbase, urlpath, headers, postdata)
end

return apiquery
