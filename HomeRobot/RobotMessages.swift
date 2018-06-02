//
//  RobotMessages.swift
//  HomeRobot
//
//  Created by cc on 6/2/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import Foundation
import SceneKit

enum RobotMessageType : Int, Codable  {
    case updateLocation = 0
    case motorCommand = 1
    case waypointAdd = 2
    case waypointAchieved = 3
}

protocol RobotMessage : Codable {
    
}

// MARK: - Messages

struct UpdateLocationMessage : RobotMessage {
    let location : SCNVector3
    let transform : SCNMatrix4
    let robotConnected : Bool
    let currentMapId : String?
    let hasLocalized : Bool
}

struct DriveMotorMessage : RobotMessage {
    let leftMotorPower : Float
    let rightMotorPower : Float
}

struct WaypointAchievedMessage : RobotMessage {
    let markerId : Int
}

struct WaypointAddMessage : RobotMessage {
    let markerId : Int
    let location : SCNVector3
}

// MARK: - Wrapper to handle different message types
/*
 There seemed to be some weirdness around subclasses and Codable.
 So I went with this approach for now.
 */
class RobotMessageWrapper : Codable {
    
    var message : RobotMessage?
    var messageType : RobotMessageType = .updateLocation
    
    init() {
        
    }
    
    enum CodingKeys: String, CodingKey {
        case messageType = "messageType"
        case message = "message"
    }
    
    required init(from decoder: Decoder) throws {
        
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        messageType = try values.decode(RobotMessageType.self, forKey: .messageType)
        
        if messageType == .updateLocation {
            message = try values.decode(UpdateLocationMessage.self, forKey: .message)
        } else if messageType == .motorCommand {
            message = try values.decode(DriveMotorMessage.self, forKey: .message)
        } else if messageType == .waypointAdd {
            message = try values.decode(WaypointAddMessage.self, forKey: .message)
        } else if messageType == .waypointAchieved {
            message = try values.decode(WaypointAchievedMessage.self, forKey: .message)
        }
        
    }
    
    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        
        if let msg = message as? UpdateLocationMessage {
            self.messageType = .updateLocation
            try container.encode(msg, forKey: .message)
        } else if let msg = message as? DriveMotorMessage {
            self.messageType = .motorCommand
            try container.encode(msg, forKey: .message)
        } else if let msg = message as? WaypointAddMessage {
            self.messageType = .waypointAdd
            try container.encode(msg, forKey: .message)
        } else if let msg = message as? WaypointAchievedMessage {
            self.messageType = .waypointAchieved
            try container.encode(msg, forKey: .message)
        }
        
        try container.encode(messageType, forKey: .messageType)
        
    }
    
}

// MARK: - Send / Rec messages
func ParseRobotMessageData( _ data : Data ) -> RobotMessage? {
    
    let decoder = JSONDecoder()
    guard let messageWrapper = try? decoder.decode(RobotMessageWrapper.self, from: data) else { return nil; }
    return messageWrapper.message
    
}

func EncodeRobotMessage( _ message : RobotMessage ) -> Data? {
    
    let wrapper = RobotMessageWrapper()
    wrapper.message = message
    
    let jsonEncoder = JSONEncoder()
    
    if let encodedData = try? jsonEncoder.encode(wrapper) {
        return encodedData
    }
    
    return nil;
    
}

func TestRobotMessages() {
    
    let msg = UpdateLocationMessage(location: SCNVector3(1,2,3),
                                    transform: SCNMatrix4Identity,
                                    robotConnected: false,
                                    currentMapId: nil,
                                    hasLocalized: false)
    
    let data = EncodeRobotMessage(msg)!
    let msg2 = ParseRobotMessageData(data)! as! UpdateLocationMessage
    
    assert(msg2.location.x == msg.location.x)
    assert(msg2.robotConnected == msg.robotConnected)
    assert(msg2.transform.m11 == msg.transform.m11)
    
    
    let msg3 = WaypointAddMessage(markerId: 1234, location: SCNVector3(2,3,4))
    let data2 = EncodeRobotMessage(msg3)!
    let msg4 = ParseRobotMessageData(data2)! as! WaypointAddMessage
    
    assert(msg3.location.x == msg4.location.x)
    assert(msg3.markerId == msg4.markerId)
    
    
    
}




