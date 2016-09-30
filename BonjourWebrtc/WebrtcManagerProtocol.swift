//
//  WebrtcManagerProtocol.swift
//  ConnectedColors
//
//  Created by Mahabali on 4/8/16.
//  Copyright © 2016 Ralf Ebert. All rights reserved.
//

import Foundation
import WebRTC

@objc protocol WebrtcManagerProtocol {
  func offerSDPCreated(_ sdp: RTCSessionDescription)
  func didReceiveLocalVideoTrack(_ localVideoTrack: RTCVideoTrack)
  func didReceiveRemoteVideoTrack(_ remoteVideoTrack: RTCVideoTrack)
  func answerSDPCreated(_ sdp: RTCSessionDescription)
  func iceCandidatesCreated(_ iceCandidate: RTCIceCandidate)
  func dataReceivedInChannel(_ data: Data)
}
