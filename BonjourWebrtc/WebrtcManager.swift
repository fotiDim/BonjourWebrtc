//
//  WebrtcManager.swift
//  ConnectedColors
//
//  Created by Mahabali on 4/8/16.
//  Copyright © 2016 Ralf Ebert. All rights reserved.
//

import Foundation
import AVFoundation
import WebRTC

class WebrtcManager: NSObject {
    
    var kARDMediaStreamId: String {
        UUID().uuidString
    }
    var kARDAudioTrackId: String {
        UUID().uuidString
    }
    var kARDVideoTrackId: String {
        UUID().uuidString
    }
    
    var peerConnection: RTCPeerConnection?
    var peerConnectionFactory: RTCPeerConnectionFactory! = RTCPeerConnectionFactory()
    var videoCapturer: RTCCameraVideoCapturer?
    var localAudioTrack: RTCAudioTrack?
    var localVideoTrack: RTCVideoTrack?
    var remoteSDP: RTCSessionDescription?
    var delegate: WebrtcManagerProtocol?
    var localStream: RTCMediaStream!
    var unusedICECandidates: [RTCIceCandidate] = []
    var initiator: Bool = false
    var isLoopback: Bool = true
    var shouldUseLevelControl: Bool = false
    var isAudioOnly: Bool = false
  
    override init() {
        super.init()
        // Create peer connection.
        let config: RTCConfiguration = RTCConfiguration()
        let iceServer = RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"], username: nil, credential: nil)
        config.iceServers = [iceServer]
        peerConnection = peerConnectionFactory.peerConnection(with: config, constraints: defaultPeerConnectionConstraints(), delegate: self)
    }
    
    func startWebrtcConnection() {
        if initiator {
            // Send offer.
            addLocalMediaStream()
            let wself: WebrtcManager? = self
            peerConnection?.offer(for: defaultOfferConstraints(), completionHandler: { (sdp: RTCSessionDescription?, error: Error?) in
                if let sself = wself {
                    sself.peerConnection(sself.peerConnection, didCreateSessionDescription: sdp, error: error)
                }
            })
        } else {
            // Check if we've received an offer.
            self.waitForAnswer()
        }
    }

    func addLocalMediaStream() {
        let videoSource = peerConnectionFactory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)

        let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front })

        // choose highest res
        let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera!).sorted { (f1, f2) -> Bool in
        let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
        let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
        return width1 < width2
        }).last

        videoCapturer?.startCapture(with: frontCamera!, format: format!, fps: 10)
        localVideoTrack = peerConnectionFactory.videoTrack(with: videoSource, trackId: kARDVideoTrackId)
        
        localAudioTrack = peerConnectionFactory.audioTrack(withTrackId: kARDAudioTrackId)
        
        localStream = peerConnectionFactory?.mediaStream(withStreamId: kARDMediaStreamId)
        localStream!.addVideoTrack(localVideoTrack!)
        localStream!.addAudioTrack(localAudioTrack!)
        
        self.peerConnection!.add(localStream!)
        self.delegate?.didReceiveLocalVideoTrack(localVideoTrack!)
    }
    
    func waitForAnswer() {
        // Do nothing. Maybe initialize something here. Nothing for this example
    }
  
    func createAnswer() {
        DispatchQueue.main.sync {
            self.peerConnection?.setRemoteDescription(self.remoteSDP!, completionHandler: { (error: Error?) in
                if let error = error {
                    print("setRemoteDescription error: \(error)")
                    assert(false)
                } else {
                    self.addLocalMediaStream()
                    self.peerConnection(self.peerConnection, didSetSessionDescriptionWithError: error)
                }
            })
        }
    }
  
    func setAnswerSDP() {
        let wself: WebrtcManager? = self
        DispatchQueue.main.sync {
            if let sself = wself, let sdp = sself.remoteSDP {
                sself.peerConnection?.setRemoteDescription(sdp, completionHandler: { (error: Error?) in
                    if let error = error {
                        print("setRemoteDescription error: \(error)")
                    }
                })
            }
            self.addUnusedIceCandidates()
        }
    }
  
    func setICECandidates(_ iceCandidate: RTCIceCandidate){
        DispatchQueue.main.async {
            print("Got IceCandidate")
            self.peerConnection?.add(iceCandidate)
        }
    }
  
    func addUnusedIceCandidates(){
        for (iceCandidate) in self.unusedICECandidates {
            print("added unused ices")
            self.peerConnection?.add(iceCandidate)
        }
        self.unusedICECandidates = []
    }

    func peerConnection(_ peerConnection: RTCPeerConnection!, didCreateSessionDescription sdp: RTCSessionDescription!, error: Error!) {
        DispatchQueue.main.async {
            if let error = error {
                print("Failed to create session description. Error: \(error)")
                self.disconnect()
                return
            }
            
            let wself: WebrtcManager? = self
            peerConnection.setLocalDescription(sdp, completionHandler: { (error: Error?) in
                if let error = error {
                    print("Failed to setLocalDescription, error: \(error)")
                    assert(false)
                }
                if let sself = wself {
                    sself.peerConnection(sself.peerConnection, didSetSessionDescriptionWithError: error)
                }
            })
        }
    }
  
    func peerConnection(_ peerConnection: RTCPeerConnection!, didSetSessionDescriptionWithError error: Error!) {
        DispatchQueue.main.async {
            if error != nil {
                print("sdp error \(error.localizedDescription) \(String(describing: error))")
                assert(false)
            } else {
                if self.initiator {
                    // Send offer through the signaling channel of our application
                    if let sdp = self.peerConnection?.localDescription {
                        print("Send offer to remote peer")
                        self.delegate?.offerSDPCreated(sdp)
                    }
                } else if let sdp = self.peerConnection!.localDescription {
                    // Send answer through the signaling channel of our application
                    self.delegate?.answerSDPCreated(sdp)
                } else {
                    // If we're answering and we've just set the remote offer we need to create
                    // an answer and set the local description.
                    let constraints = self.defaultAnswerConstraints()
                    let wself: WebrtcManager? = self
                    peerConnection.answer(for: constraints, completionHandler: { (sdp: RTCSessionDescription?, error: Error?) in
                        if let sself = wself {
                            sself.peerConnection?.setLocalDescription(sdp!, completionHandler: { (error: Error?) in
                                sself.peerConnection(self.peerConnection, didSetSessionDescriptionWithError: error)
                            })
                        }
                    })
                }
            }
        }
    }
  
    // Called when the data channel state has changed.
    func channelDidChangeState(_ channel:RTCDataChannel){

    }
  
    func channel(_ channel: RTCDataChannel!, didReceiveMessageWithBuffer buffer: RTCDataBuffer!) {
        self.delegate?.dataReceivedInChannel(buffer.data)
    }
  
    func disconnect() {
        self.peerConnection?.close()
    }
}

extension WebrtcManager: RTCPeerConnectionDelegate {
    
    /** Called when the SignalingState changed. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("PEER CONNECTION:- Signaling State Changed \(stateChanged.rawValue)")
    }
    
    /** Called when media is received on a new stream from remote peer. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Log: PEER CONNECTION:- Stream Added")
        if (stream.videoTracks.count > 0) {
            let videoTrack = stream.videoTracks[0]
            delegate?.didReceiveRemoteVideoTrack(videoTrack)
        }
    }
    
    /** Called when a remote peer closes a stream. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("PEER CONNECTION:- Stream Removed")
    }
    
    /** Called when negotiation is needed, for example ICE has restarted. */
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("PEER CONNECTION:- Renegotiation Needed")
    }
    
    /** Called any time the IceConnectionState changes. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("PEER CONNECTION: - didChange newState IceConnectionState \(newState.rawValue)")
    }
    
    /** Called any time the IceGatheringState changes. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("PEER CONNECTION:- ICE Gathering Changed - \(newState.rawValue)")
    }
    
    /** New ice candidate has been found. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("PEER CONNECTION:- didGenerate IceCandidate")
        self.delegate?.iceCandidatesCreated(candidate)
    }
    
    /** Called when a group of local Ice candidates have been removed. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("peerConnection didRemove candidates")
    }
    
    /** New data channel has been opened. */
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("PEER CONNECTION:- Open Data Channel")
    }
}

// MARK: RTCMediaContraints

extension WebrtcManager {
    
    func defaultMediaStreamConstraints() -> RTCMediaConstraints {
        return RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    }
    
    func defaultMediaAudioConstraints() -> RTCMediaConstraints {
        let valueLevelControl = shouldUseLevelControl ? "true" : "false"
        let mandatoryConstraints = [ kRTCMediaConstraintsLevelControl : valueLevelControl ]
        return RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
    }
    
    func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
        let value = isLoopback ? "false" : "true"
        let optionalConstraints = ["DtlsSrtpKeyAgreement" : value ]
        return RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
    }
    
    func defaultOfferConstraints() -> RTCMediaConstraints {
        let mandatoryConstraints = [ "OfferToReceiveAudio": "true", "OfferToReceiveVideo" : "true"]
        return RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
    }
    
    func defaultAnswerConstraints() -> RTCMediaConstraints {
        return defaultOfferConstraints()
    }
}
