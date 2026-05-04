package main

import (
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strconv"

	"github.com/nihjul/janus-whip/pkg/janus"
)

func main() {
	janusApiUrl := os.Getenv("JANUS_API_URL")
	janusRtpUrl := os.Getenv("JANUS_RTP_URL")
	if len(janusApiUrl) == 0 {
		slog.Error("no janus url was provided, provided one using JANUS_URL")
		return
	}
	mime := "application/sdp"
	router := http.NewServeMux()
	// TODO: check response for error
	// TODO: make error response conforment to RFC https://www.rfc-editor.org/rfc/rfc9726
	// TODO: Add DELETE request to handle stream disconenct

	// TODO: Rename temp, it looks like it might not be rfc compliant
	router.HandleFunc("POST /{room}/whip/{temp}", func(w http.ResponseWriter, r *http.Request) {
		roomId := r.PathValue("room")
		contentType := r.Header["Content-Type"][0]
		if contentType == mime {
			body, err := io.ReadAll(r.Body)
			if err != nil {
				slog.Error("error parsing body", "ERROR", err.Error())
				w.WriteHeader(http.StatusInternalServerError)
				w.Write([]byte{})
			}
			if len(body) == 0 {
				slog.Error("body of request is empty")
				w.WriteHeader(http.StatusBadRequest)
				w.Write([]byte{})
			}
			slog.Info("request info", "roomId", roomId, "Content-Type", contentType, "Body", string(body))
			janusInfo := janus.NewJanus(janusApiUrl, janusRtpUrl)
			if err := janusInfo.NewSession(); err != nil {
				slog.Error("error creating new session", "ERROR", err.Error())
			}

			if err := janusInfo.NewHandler(); err != nil {
				slog.Error("error creating new handler", "ERROR", err.Error())
			}

			joinRoomId, err := strconv.Atoi(roomId)
			if err != nil {
				slog.Error("error converting room id", "ERROR", err.Error())
				return
			}

			if err := janusInfo.JoinAndConfigure(joinRoomId, string(body)); err != nil {
				slog.Error("error join and configure", "ERROR", err.Error())
			}

			sdpAnswer, err := janusInfo.SessionInfo()
			if err != nil {
				slog.Error("error getting info about session", "ERROR", err.Error())
			}
			slog.Info("JanusInfo", "SessionId", janusInfo.SessionId, "HandleId", janusInfo.HandlerId, "SDP", sdpAnswer)

			w.Header().Add("Location", janusInfo.RTPUrl+janusInfo.SessionId+"/"+janusInfo.HandlerId)
			w.Header().Add("Content-Type", mime)
			w.WriteHeader(http.StatusCreated)
			w.Write([]byte(sdpAnswer))
			return
		}
		w.Header().Add("Content-Type", mime)
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte{})
	})

	server := http.Server{
		Addr:    ":8080",
		Handler: router,
	}

	listener := fmt.Sprintf("http://127.0.0.1%s", server.Addr)

	slog.Info("server is running on", "addr", listener)

	slog.Error("error running http server", "ERROR", server.ListenAndServe())
}
