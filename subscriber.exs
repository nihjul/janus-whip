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
  def participantsBody do
    %{
      janus: "message",
      transaction: generateTransaction("", 11),
      body: %{
        request: "listparticipants",
        room: 1234,
      }
    }
  end
  def joinBody(publisher) do
    %{
      janus: "message",
      transaction: generateTransaction("", 11),
      body: %{
        request: "join",
        ptype: "subscriber",
        room: 1234,
        streams: [
          %{
            feed: publisher
          }
        ]
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
  def parseParticipants([head | tails], id) do
    if head["publisher"] do
      parseParticipants(tails, head["id"])
    else
      parseParticipants(tails, id)
    end
  end
  def parseParticipants([], id) do
    id
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
  def listParticipants(baseUrl, sessionId, handlerId) do
    url = baseUrl <> sessionId <> "/" <> handlerId
    {status, rawResponse} = Req.post(url, json: participantsBody())
    parcicipants = parseResponse(status, rawResponse)["plugindata"]["data"]["participants"]
    parseParticipants(parcicipants, 0)
  end
  def joinAndWatch(baseUrl, sessionId, handlerId) do
    url = baseUrl <> sessionId <> "/" <> handlerId
    publisher = listParticipants(baseUrl, sessionId, handlerId)
    {status, rawResponse} = Req.post(url, json: joinBody(publisher))
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
sessionId = JanusGateway.session(url)
handlerId = JanusGateway.handler(url, sessionId)
JanusGateway.joinAndWatch(url, sessionId, handlerId)
sessionInfo = JanusGateway.sessionInfo(url, sessionId)
IO.puts(sessionInfo["jsep"]["sdp"])
