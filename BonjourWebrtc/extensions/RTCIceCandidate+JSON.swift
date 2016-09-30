//
//  RTCIceCandidate+JSON.swift
//  BonjourWebrtc
//
//  Created by Omair Baskanderi on 2016-09-29.
//  Copyright © 2016 Dhilip Raveendran. All rights reserved.
//

import Foundation
import WebRTC

let kRTCIceCandidateTypeKey = "type"
let kRTCIceCandidateTypeValue = "candidate"
let kRTCIceCandidateMidKey = "id"
let kRTCIceCandidateMLineIndexKey = "label"
let kRTCIceCandidateSdpKey = "candidate"
let kRTCICECandidatesTypeKey = "candidates"

extension RTCIceCandidate {
    
    static func candidateFromJSONDictionary(_ dictionary: [String : AnyObject]) -> RTCIceCandidate {
        let mid = dictionary[kRTCIceCandidateMidKey] as! String
        let sdp = dictionary[kRTCIceCandidateSdpKey] as! String
        let num = dictionary[kRTCIceCandidateMLineIndexKey] as! NSNumber
        let mLineIndex = num.int32Value
        return RTCIceCandidate(sdp: sdp, sdpMLineIndex: mLineIndex, sdpMid: mid)
    }

    func JSONData() -> Data {
        var data: Data = Data()
        do {
            data = try JSONSerialization.data(withJSONObject: jsonDictionary(), options: .prettyPrinted)
        } catch {
            print("Failed to serialize json object")
        }
        return data
    }

    func jsonDictionary() -> [String : AnyObject] {
        var json: [String : AnyObject] = [
            kRTCIceCandidateTypeKey : kRTCIceCandidateTypeValue as AnyObject,
            kRTCIceCandidateSdpKey : self.sdp as AnyObject
        ]
        
        let number = NSNumber(value: sdpMLineIndex)
        json[kRTCIceCandidateMLineIndexKey] = number as AnyObject
        
        if let sdpMid = self.sdpMid {
            json[kRTCIceCandidateMidKey] = sdpMid as AnyObject
        }
        return json
    }
}
