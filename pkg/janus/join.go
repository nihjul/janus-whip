package janus

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
)

func (info *JanusInfo) JoinAndConfigure(roomId int, sdp string) error {
	videoRoomBody := &VideoRoomBody{
		Request:    "joinandconfigure",
		Ptype:      "publisher",
		Room:       roomId,
		Record:     false,
		Audiocodec: "opus",
		Videocodec: "h264",
	}
	jsepBody := &JSEPBody{
		Type: "offer",
		SDP:  sdp,
	}
	rawBody := &JanusBody{
		Janus:       "message",
		Transaction: "4Qxd4qkYR6G",
		Body:        videoRoomBody,
		JSEP:        jsepBody,
	}

	body, err := json.Marshal(rawBody)
	if err != nil {
		return err
	}

	bodyReader := bytes.NewReader(body)

	resp, err := http.Post(info.ApiUrl+info.SessionId+"/"+info.HandlerId, "application/json", bodyReader)
	if err != nil {
		return err
	}

	defer resp.Body.Close()
	_, err = io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	return nil
}
