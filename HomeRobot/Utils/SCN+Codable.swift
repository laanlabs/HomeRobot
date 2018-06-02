//
//  SCNCodables.swift
//  HomeRobot
//
//  Created by cc on 6/2/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import Foundation


extension SCNVector3: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init()
        self.x = try container.decode(Float.self)
        self.y = try container.decode(Float.self)
        self.z = try container.decode(Float.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.x)
        try container.encode(self.y)
        try container.encode(self.z)
    }
}

extension SCNMatrix4: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init()
        self.m11 = try container.decode(Float.self)
        self.m12 = try container.decode(Float.self)
        self.m13 = try container.decode(Float.self)
        self.m14 = try container.decode(Float.self)
        
        self.m21 = try container.decode(Float.self)
        self.m22 = try container.decode(Float.self)
        self.m23 = try container.decode(Float.self)
        self.m24 = try container.decode(Float.self)
        
        self.m31 = try container.decode(Float.self)
        self.m32 = try container.decode(Float.self)
        self.m33 = try container.decode(Float.self)
        self.m34 = try container.decode(Float.self)
        
        self.m41 = try container.decode(Float.self)
        self.m42 = try container.decode(Float.self)
        self.m43 = try container.decode(Float.self)
        self.m44 = try container.decode(Float.self)
        
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.m11)
        try container.encode(self.m12)
        try container.encode(self.m13)
        try container.encode(self.m14)
        try container.encode(self.m21)
        try container.encode(self.m22)
        try container.encode(self.m23)
        try container.encode(self.m24)
        try container.encode(self.m31)
        try container.encode(self.m32)
        try container.encode(self.m33)
        try container.encode(self.m34)
        try container.encode(self.m41)
        try container.encode(self.m42)
        try container.encode(self.m43)
        try container.encode(self.m44)
    }
}
