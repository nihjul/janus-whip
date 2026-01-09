/**
 * Janus Gateway Subscriber - Browser JavaScript Implementation
 */

// TODO: Add better and extensive error handling
// TODO: Add retry
// LEARN: Read and understand WebRTC better
class JanusGateway {
  constructor(url) {
    this.baseUrl = null;
    if (url) {
      this.setUrl(url);
    }
  }

  setUrl(url) {
    this.baseUrl = `http://${url}:8088/janus/`;
    return this.baseUrl;
  }

  generateTransaction(length = 11) {
    const charList = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ123456789";
    let transaction = "";
    for (let i = 0; i < length; i++) {
      const randomIndex = Math.floor(Math.random() * charList.length);
      transaction += charList[randomIndex];
    }
    return transaction;
  }

  sessionBody() {
    return {
      janus: "create",
      transaction: this.generateTransaction(),
    };
  }

  handlerBody() {
    return {
      janus: "attach",
      plugin: "janus.plugin.videoroom",
      transaction: this.generateTransaction(),
    };
  }

  participantsBody() {
    return {
      janus: "message",
      transaction: this.generateTransaction(),
      body: {
        request: "listparticipants",
        room: 1234,
      },
    };
  }

  joinBody(publisher) {
    return {
      janus: "message",
      transaction: this.generateTransaction(),
      body: {
        request: "join",
        ptype: "subscriber",
        room: 1234,
        streams: [
          {
            feed: publisher,
          },
        ],
      },
    };
  }

  startBody(jsep) {
    return {
      janus: "message",
      transaction: this.generateTransaction(),
      body: {
        request: "start",
      },
      jsep: jsep,
    };
  }

  trickleBody(candidate) {
    return {
      janus: "trickle",
      transaction: this.generateTransaction(),
      candidate: candidate,
    };
  }

  parseResponse(response) {
    switch (response.janus) {
      case "success":
      case "event":
      case "ack":
        return response;
      case "error":
        console.error("ERROR:", response.error?.reason || "Unknown error");
        throw new Error(response.error?.reason || "Unknown error");
      default:
        console.error("Unexpected response:", response);
        throw new Error("Unexpected response type: " + response.janus);
    }
  }

  parseParticipants(participants) {
    let publisherId = 0;
    for (const participant of participants) {
      if (participant.publisher) {
        publisherId = participant.id;
      }
    }
    return publisherId;
  }

  async session() {
    const response = await fetch(this.baseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(this.sessionBody()),
    });
    const data = await response.json();
    const parsed = this.parseResponse(data);
    return String(parsed.data.id);
  }

  async handler(sessionId) {
    const url = this.baseUrl + sessionId;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(this.handlerBody()),
    });
    const data = await response.json();
    const parsed = this.parseResponse(data);
    return String(parsed.data.id);
  }

  async listParticipants(sessionId, handlerId) {
    const url = `${this.baseUrl}${sessionId}/${handlerId}`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(this.participantsBody()),
    });
    const data = await response.json();
    const parsed = this.parseResponse(data);
    const participants = parsed.plugindata?.data?.participants || [];
    return this.parseParticipants(participants);
  }

  async joinAndWatch(sessionId, handlerId) {
    const url = `${this.baseUrl}${sessionId}/${handlerId}`;
    const publisher = await this.listParticipants(sessionId, handlerId);
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(this.joinBody(publisher)),
    });
    const data = await response.json();
    return this.parseResponse(data);
  }

  async sendTrickleCandidate(sessionId, handlerId, candidate) {
    const url = `${this.baseUrl}${sessionId}/${handlerId}`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(this.trickleBody(candidate)),
    });
    const data = await response.json();
    return this.parseResponse(data);
  }

  async sendStart(sessionId, handlerId, jsep) {
    const url = `${this.baseUrl}${sessionId}/${handlerId}`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(this.startBody(jsep)),
    });
    const data = await response.json();
    return this.parseResponse(data);
  }

  async pollEvents(sessionId) {
    const url = `${this.baseUrl}${sessionId}?maxev=1`;
    const response = await fetch(url, {
      method: "GET",
      headers: { "Content-Type": "application/json" },
    });
    const data = await response.json();
    return data;
  }

  /**
   * Poll for events until we receive the SDP offer from Janus
   * @param {string} sessionId - Janus session ID
   * @param {number} timeout - Max time to wait in ms (default: 10000)
   * @returns {Promise<object>} - The event containing jsep offer
   */
  async waitForOffer(sessionId, timeout = 10000) {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeout) {
      const event = await this.pollEvents(sessionId);
      
      // Log for debugging
      console.log("Polled event:", event);
      
      // Check if this event contains a jsep offer
      if (event.jsep && event.jsep.type === "offer") {
        return event;
      }
      
      // Handle keepalive or empty events - continue polling
      if (event.janus === "keepalive") {
        continue;
      }
      
      // Small delay before next poll to avoid hammering the server
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    throw new Error("Timeout waiting for SDP offer from Janus");
  }

  async sessionInfo(sessionId) {
    const url = this.baseUrl + sessionId;
    const response = await fetch(url, {
      method: "GET",
      headers: { "Content-Type": "application/json" },
    });
    const data = await response.json();
    return this.parseResponse(data);
  }

  async janusInfo() {
    try {
      const response = await fetch(this.baseUrl + "info");
      const data = await response.json();
      console.log(data);
      return data;
    } catch (error) {
      console.error(error);
      throw error;
    }
  }

  /**
   * Set up WebRTC peer connection with Janus
   * @param {string} sessionId - Janus session ID
   * @param {string} handlerId - Janus plugin handler ID
   * @param {object} offer - SDP offer from Janus (jsep object)
   * @param {object} options - Options including config and callbacks
   * @param {object} options.config - RTCPeerConnection config
   * @param {function} options.ontrack - Callback for track events
   * @returns {Promise<RTCPeerConnection>}
   */
  async setupPeerConnection(sessionId, handlerId, offer, options = {}) {
    const { config = {}, ontrack = null } = options;
    
    const defaultConfig = {
      iceServers: [
        { urls: "stun:stun.l.google.com:19302" },
      ],
    };

    const rtcConfig = { ...defaultConfig, ...config };
    const peerConnection = new RTCPeerConnection(rtcConfig);

    // Handle ICE candidates - send to Janus via trickle
    peerConnection.onicecandidate = async (event) => {
      if (event.candidate) {
        // Skip mDNS candidates - Janus in Docker/container can't resolve them
        if (event.candidate.candidate.includes(".local")) {
          console.log("Skipping mDNS candidate:", event.candidate.candidate);
          return;
        }
        console.log("Sending ICE candidate to Janus:", event.candidate);
        await this.sendTrickleCandidate(sessionId, handlerId, event.candidate);
      } else {
        // ICE gathering complete - send null candidate to signal completion
        console.log("ICE gathering complete");
        await this.sendTrickleCandidate(sessionId, handlerId, { completed: true });
      }
    };

    // Log ICE connection state changes
    peerConnection.oniceconnectionstatechange = () => {
      console.log("ICE connection state:", peerConnection.iceConnectionState);
    };

    // Log connection state changes
    peerConnection.onconnectionstatechange = () => {
      console.log("Connection state:", peerConnection.connectionState);
    };

    // Set up ontrack handler BEFORE setting remote description
    // This ensures we catch tracks as soon as they arrive
    if (ontrack) {
      peerConnection.ontrack = ontrack;
    }

    // Set remote description with Janus's offer
    console.log("Setting remote description (offer):", offer);
    await peerConnection.setRemoteDescription(new RTCSessionDescription(offer));

    // Create answer
    console.log("Creating answer...");
    const answer = await peerConnection.createAnswer();

    // Set local description
    console.log("Setting local description (answer):", answer);
    await peerConnection.setLocalDescription(answer);

    // Send answer to Janus
    console.log("Sending answer to Janus...");
    await this.sendStart(sessionId, handlerId, {
      type: "answer",
      sdp: answer.sdp,
    });

    return peerConnection;
  }

  /**
   * Main subscribe flow with WebRTC setup
   * @param {object} options - Options including config and callbacks
   * @param {object} options.config - RTCPeerConnection config
   * @param {function} options.ontrack - Callback for track events
   * @returns {Promise<{sessionId: string, handlerId: string, peerConnection: RTCPeerConnection, offer: object}>}
   */
  async subscribe(options = {}) {
    const sessionId = await this.session();
    const handlerId = await this.handler(sessionId);
    
    // joinAndWatch returns "ack", offer comes via event polling
    await this.joinAndWatch(sessionId, handlerId);
    console.log("Join acknowledged, waiting for SDP offer...");
    
    // Poll for the SDP offer event
    const offerEvent = await this.waitForOffer(sessionId);
    const offer = offerEvent.jsep;
    
    if (!offer) {
      throw new Error("No SDP offer received from Janus");
    }
    
    console.log("Received SDP offer from Janus");
    
    // Set up WebRTC peer connection
    const peerConnection = await this.setupPeerConnection(
      sessionId,
      handlerId,
      offer,
      options
    );
    
    return {
      sessionId,
      handlerId,
      peerConnection,
      offer,
    };
  }
}

export { JanusGateway };
