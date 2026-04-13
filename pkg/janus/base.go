package janus

func NewJanus(apiUrl string, rtpUrl string) *JanusInfo {
	apiUrl = "http://" + apiUrl + ":8088/janus/"
	rtpUrl = "http://" + rtpUrl + ":8088/janus/"
	return &JanusInfo{
		ApiUrl: apiUrl,
		RTPUrl: rtpUrl,
	}
}
