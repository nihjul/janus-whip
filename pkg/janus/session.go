package janus

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

func (info *JanusInfo) NewSession() error {
	rawBody := &JanusBody{
		Janus:       "create",
		Transaction: "4Qxd4qkYR6G",
	}

	body, err := json.Marshal(rawBody)
	if err != nil {
		return err
	}

	bodyReader := bytes.NewReader(body)

	resp, err := http.Post(info.BaseURL, "application/json", bodyReader)
	if err != nil {
		return err
	}

	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	sessionId := parseDataId{}
	err = json.Unmarshal(respBody, &sessionId)
	if err != nil {
		return err
	}

	info.SessionId = fmt.Sprint(sessionId.Data.Id)
	return nil
}

func (info *JanusInfo) SessionInfo() (string, error) {
	resp, err := http.Get(info.BaseURL + info.SessionId)
	if err != nil {
		return "", err
	}

	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	jsepAnswer := parseJSEP{}
	err = json.Unmarshal(respBody, &jsepAnswer)
	if err != nil {
		return "", err
	}

	return jsepAnswer.JSEP.SDP, nil
}
