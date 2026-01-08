package janus

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

func (info *JanusInfo) NewHandler() error {
	rawBody := &JanusBody{
		Janus:       "attach",
		Transaction: "4Qxd4qkYR6G",
		Plugin:      "janus.plugin.videoroom",
	}

	body, err := json.Marshal(rawBody)
	if err != nil {
		return err
	}

	bodyReader := bytes.NewReader(body)

	resp, err := http.Post(info.BaseURL+info.SessionId, "application/json", bodyReader)
	if err != nil {
		return err
	}

	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	handlerId := parseDataId{}
	err = json.Unmarshal(respBody, &handlerId)
	if err != nil {
		return err
	}

	info.HandlerId = fmt.Sprint(handlerId.Data.Id)
	return nil
}
