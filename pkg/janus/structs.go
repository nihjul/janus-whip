package janus

type VideoRoomBody struct {
	Request    string `json:"request"`
	Ptype      string `json:"ptype"`
	Room       int    `json:"room"`
	Record     bool   `json:"record"`
	Audiocodec string `json:"audiocodec"`
	Videocodec string `json:"videocodec"`
}

type JSEPBody struct {
	Type string `json:"type"`
	SDP  string `json:"sdp"`
}

type JanusBody struct {
	Janus       string         `json:"janus"`
	Transaction string         `json:"transaction"`
	Plugin      string         `json:"plugin"`
	Body        *VideoRoomBody `json:"body"`
	JSEP        *JSEPBody      `json:"jsep"`
}

type dataId struct {
	Id int `json:"id"`
}

type parseDataId struct {
	Data *dataId `json:"data"`
}

type answerJSEP struct {
	SDP string `json:"sdp"`
}

type parseJSEP struct {
	JSEP *answerJSEP `json:"jsep"`
}

type JanusInfo struct {
	BaseURL   string
	SessionId string
	HandlerId string
}
