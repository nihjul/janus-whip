package janus

func NewJanus(baseURL string) *JanusInfo {
	return &JanusInfo{
		BaseURL: baseURL,
	}
}
