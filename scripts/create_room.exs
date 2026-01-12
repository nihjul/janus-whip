Mix.install([
  {:req, "~> 0.5.16"}
])
defmodule JanusGateway do
  def setUrl(url) do
    "http://"<>url<>":8088/janus/"
  end
  def generateTransaction(transaction, n) when n > 0 do
    charList = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ123456789"
    listLenght = String.length(charList)
    randomInt = :rand.uniform(listLenght-1)
    char = String.at(charList, randomInt)
    transaction = transaction <> char
    generateTransaction(transaction, n - 1)
  end
  def generateTransaction(transaction, 0) do
    transaction
  end
  def sessionBody do
    %{
      janus: "create",
      transaction: generateTransaction("", 11),
    }
  end
  def handlerBody do
    %{
      janus: "attach",
      plugin: "janus.plugin.videoroom",
      transaction: generateTransaction("", 11),
    }
  end
  def createRoomBody do
    %{
      janus: "message",
      transaction: generateTransaction("", 11),
      body: %{
        request: "create",
        room: 1212,
        permanent: false,
        secret: "tv2",
        is_private: true,
        publishers: 1,
        audiocodec: "opus",
        videocodec: "h264",
        bitrate: 0
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
  def createRoom(baseUrl, sessionId, handlerId) do
    url = baseUrl <> sessionId <> "/" <> handlerId
    {status, rawResponse} = Req.post(url, json: createRoomBody())
    parseResponse(status, rawResponse)
  end
end

url = JanusGateway.setUrl(System.get_env("JANUS_URL"))
sessionId = JanusGateway.session(url)
handlerId = JanusGateway.handler(url, sessionId)
response = JanusGateway.createRoom(url, sessionId, handlerId)
IO.puts(response["plugindata"]["data"]["room"])
