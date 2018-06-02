//
//  RobotCommands.swift
//
//  Created by cc on 5/30/18.


import Foundation
import SceneKit

// TODO: Error handling, switch to Codable -- something more lightweight than json
// for Codable: maybe {"messageType" : Int, "message" : {}}
// will remove a lot of boilerplate code below


class RobotMessage {
    
    static let kMessageType = "messageType"
    
    let messageType : RobotMessageType
    
    init(messageType : RobotMessageType) {
        self.messageType = messageType
    }
    
    func toJson() -> [String : Any] {
        assert(false)
    }
    
//    func toData() -> Data? {
//        let jsonData = try? JSONSerialization.data(withJSONObject: self.toJson())
//        return jsonData
//    }
    
}

enum RobotMessageType : Int  {
    case updateLocation = 0
    case motorCommand = 1
    case waypointAdd = 2
    case waypointAchieved = 3
}

func ParseRobotMessageData( _ data : Data ) -> RobotMessage? {
    
    guard let jsonDict = try? JSONSerialization.jsonObject(with: data, options: [] ) as! [String: Any] else { return nil; }
    
    let messageType = RobotMessageType(rawValue: jsonDict[RobotMessage.kMessageType] as! Int)!
    
    switch messageType {
    case .updateLocation:
        return UpdateLocationMessage.fromJson(jsonDict: jsonDict)
    case .motorCommand:
        return DriveMotorMessage.fromJson(jsonDict: jsonDict)
    case .waypointAchieved:
        return WaypointAchievedMessage.fromJson(jsonDict: jsonDict)
    case .waypointAdd:
        return WaypointAddMessage.fromJson(jsonDict: jsonDict)
    default:
        return nil
    }
    
    
    
}



class UpdateLocationMessage : RobotMessage {
    
    let location : SCNVector3
    let transform : SCNMatrix4
    let robotConnected : Bool
    
    init(location: SCNVector3, transform: SCNMatrix4, robotConnected : Bool) {
        self.location = location
        self.transform = transform
        self.robotConnected = robotConnected
        super.init(messageType: .updateLocation)
    }
    
    static func fromJson(jsonDict : [String : Any]) -> UpdateLocationMessage? {
        
        let location = SCNVector3( (jsonDict["x"] as! NSNumber).floatValue,
                                   (jsonDict["y"] as! NSNumber).floatValue,
                                   (jsonDict["z"] as! NSNumber).floatValue)
        let connected = jsonDict["connected"] as! Bool
        let transform = SCNMatrix4Identity
        
        return UpdateLocationMessage(location: location, transform: transform, robotConnected: connected)
        
    }
    
    override func toJson() -> [String : Any] {
        return [
            RobotMessage.kMessageType : self.messageType.rawValue,
            "connected" : self.robotConnected,
            "x" : Float(self.location.x),
            "y" : Float(self.location.y),
            "z" : Float(self.location.z)]
    }
    
}

class DriveMotorMessage : RobotMessage {
    
    let leftMotorPower : Float
    let rightMotorPower : Float
    
    init(leftMotorPower : Float, rightMotorPower : Float) {
        self.leftMotorPower = leftMotorPower
        self.rightMotorPower = rightMotorPower
        super.init(messageType: .motorCommand)
    }

    static func fromJson(jsonDict : [String : Any]) -> DriveMotorMessage? {
        
        let leftPower = (jsonDict["leftPower"] as! NSNumber).floatValue
        let rightPower = (jsonDict["rightPower"] as! NSNumber).floatValue
        return DriveMotorMessage(leftMotorPower: leftPower, rightMotorPower: rightPower)
    }
    
    override func toJson() -> [String : Any] {
        return [
            RobotMessage.kMessageType : self.messageType.rawValue,
            "leftPower" : self.leftMotorPower,
            "rightPower" : self.rightMotorPower
            ]
    }
    
}

class WaypointAchievedMessage : RobotMessage {
    let markerId : Int

    init(markerId : Int) {
        self.markerId = markerId
        super.init(messageType: .waypointAchieved)
    }
    
    static func fromJson(jsonDict : [String : Any]) -> WaypointAchievedMessage? {
        return WaypointAchievedMessage(markerId: jsonDict["markerId"] as! Int)
    }
    
    override func toJson() -> [String : Any] {
        return [
            RobotMessage.kMessageType : self.messageType.rawValue,
            "markerId" : self.markerId]
    }
    
}

class WaypointAddMessage : RobotMessage {
    
    let markerId : Int
    let location : SCNVector3
    
    init(markerId : Int, location: SCNVector3) {
        self.markerId = markerId
        self.location = location
        super.init(messageType: .waypointAdd)
    }

    static func fromJson(jsonDict : [String : Any]) -> WaypointAddMessage? {
        
        let location = SCNVector3( (jsonDict["x"] as! NSNumber).floatValue,
                                   (jsonDict["y"] as! NSNumber).floatValue,
                                   (jsonDict["z"] as! NSNumber).floatValue )
        
        return WaypointAddMessage(markerId: jsonDict["markerId"] as! Int, location: location)
    }
    
    override func toJson() -> [String : Any] {
        return [
            RobotMessage.kMessageType : self.messageType.rawValue,
            "markerId" : self.markerId,
            "x" : self.location.x,
            "y" : self.location.y,
            "z" : self.location.z]
    }
    
}









