//
//  RTCSessionDescription+JSON.swift
//  BonjourWebrtc
//
//  Created by Omair Baskanderi on 2016-09-29.
//  Copyright © 2016 Dhilip Raveendran. All rights reserved.
//

import Foundation
import WebRTC

let kRTCSessionDescriptionTypeKey = "type"
let kRTCSessionDescriptionSdpKey = "sdp"

extension RTCSessionDescription {
    
    static func descriptionFromJSONDictionary(_ dictionary: [String : AnyObject]) -> RTCSessionDescription {
        let type = RTCSessionDescription.type(for: dictionary[kRTCSessionDescriptionTypeKey] as! String)
        let sdp = dictionary[kRTCSessionDescriptionSdpKey] as! String
        return RTCSessionDescription(type: type, sdp: sdp)
    }
    
    func JSONData() -> Data {
        var data = Data()
        do {
            data = try JSONSerialization.data(withJSONObject: jsonDictionary(), options: [])
        } catch {
            print("Failed to serialize JSON Object")
        }
        return data
    }
    
    func jsonDictionary() -> [String : AnyObject]{
        var description = self.sdp
        if let range = description.range(of: "RTCSessionDescription:\n") {
            description.removeSubrange(range)
        }
        if let range = description.range(of: "offer\n") {
            description.removeSubrange(range)
        }
        if let range = description.range(of: "answer\n") {
            description.removeSubrange(range)
        }
        let json: [String : AnyObject] = [
            kRTCSessionDescriptionTypeKey : RTCSessionDescription.string(for: self.type) as AnyObject,
            kRTCSessionDescriptionSdpKey : description as AnyObject
        ]
        return json
    }
    
}
