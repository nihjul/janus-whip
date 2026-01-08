Mix.install([
  {:req, "~> 0.5.16"}
])
defmodule JanusGateway do
  def setUrl(url) do
    "http://"<>url<>":8088/janus/"
  end
  def sessionBody do
    %{
      janus: "create",
      transaction: "4Qxd4qkYR6G",
    }
  end
  def handlerBody do
    %{
      janus: "attach",
      plugin: "janus.plugin.videoroom",
      transaction: "4Qxd4qkYR6G",
    }
  end
  def joinBody do
    %{
      janus: "message",
      transaction: "4Qxd4qkYR6G",
      body: %{
        request: "joinandconfigure",
        ptype: "publisher",
        room: 1234,
        display: "obs",
        record: false,
        audiocodec: "opus",
        videocodec: "h264"
      },
      jsep: %{
        type: "offer",
        sdp: "v=0\r\no=rtc 705986798 0 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=group:BUNDLE 0 1\r\na=group:LS 0 1\r\na=msid-semantic:WMS *\r\na=setup:actpass\r\na=ice-ufrag:JLvv\r\na=ice-pwd:AVQo+aTrh2UHIfcZiaNfD9\r\na=ice-options:ice2,trickle\r\na=fingerprint:sha-256 44:42:C8:DB:51:8D:EC:3F:3D:A5:72:A4:35:2D:21:65:FA:10:B4:08:08:F6:99:32:C0:12:74:3B:74:52:AA:E5\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\nc=IN IP4 0.0.0.0\r\na=mid:0\r\na=sendonly\r\na=ssrc:3957928345 cname:sURF2wTOmwqWwFdX\r\na=ssrc:3957928345 msid:ZEkK1QTjccuD7aXX ZEkK1QTjccuD7aXX-audio\r\na=msid:ZEkK1QTjccuD7aXX ZEkK1QTjccuD7aXX-audio\r\na=rtcp-mux\r\na=rtpmap:111 opus/48000/2\r\na=fmtp:111 minptime=10;maxaveragebitrate=96000;stereo=1;sprop-stereo=1;useinbandfec=1\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\nc=IN IP4 0.0.0.0\r\na=mid:1\r\na=sendonly\r\na=ssrc:3957928346 cname:sURF2wTOmwqWwFdX\r\na=ssrc:3957928346 msid:ZEkK1QTjccuD7aXX ZEkK1QTjccuD7aXX-video\r\na=msid:ZEkK1QTjccuD7aXX ZEkK1QTjccuD7aXX-video\r\na=rtcp-mux\r\na=rtpmap:96 H264/90000\r\na=rtcp-fb:96 nack\r\na=rtcp-fb:96 nack pli\r\na=rtcp-fb:96 goog-remb\r\na=fmtp:96 profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=1\r\n"
      }
    }
  end
  def parseResponse(:ok, response) do
    case Map.get(response.body, "janus") do
      "error" -> parseResponse(:error, response)
      "success" -> response.body
      "event" -> response.body
      "ack" -> response.body
      _ -> parseResponse(:error, response)
    end
  end
  def parseResponse(:error, response) do
    IO.puts(response)
    IO.puts("ERROR: " <> response.body["error"]["reason"])
  end
  def session(url) do
    {status, rawResponse} = Req.post(url, json: sessionBody())
    sessionId = parseResponse(status, rawResponse)["data"]["id"]
    Integer.to_string(sessionId)
  end
  def handler(baseUrl, sessionId) do
    url = baseUrl <> sessionId
    {status, rawResponse} = Req.post(url, json: handlerBody())
    handlerId = parseResponse(status, rawResponse)["data"]["id"]
    Integer.to_string(handlerId)
  end
  def joinandconfigure(baseUrl, sessionId, handlerId) do
    url = baseUrl <> sessionId <> "/" <> handlerId
    {status, rawResponse} = Req.post(url, json: joinBody())
    parseResponse(status, rawResponse)
  end
  def sessionInfo(baseUrl, sessionId) do
    url = baseUrl <> sessionId
    {status, rawResponse} = Req.get(url)
    parseResponse(status, rawResponse)
  end
  def janusInfo(url) do
    rawResponse = Req.get(url <> "info")
    case rawResponse do
      {:ok, response} -> IO.puts response.body
      {:error, error} -> IO.puts error
      _ -> IO.puts "Fallthrough"
    end
  end
end

url = JanusGateway.setUrl(System.get_env("JANUS_URL"))
IO.puts(url)
sessionId = JanusGateway.session(url)
handlerId = JanusGateway.handler(url, sessionId)
JanusGateway.joinandconfigure(url, sessionId, handlerId)
sessionInfo = JanusGateway.sessionInfo(url, sessionId)
IO.puts(sessionInfo["jsep"]["sdp"])
