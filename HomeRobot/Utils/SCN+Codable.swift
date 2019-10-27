//
//  SCNCodables.swift
//  HomeRobot
//
//  Created by cc on 6/2/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import Foundation
import SceneKit
import simd

extension SCNVector3: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init()
        x = try container.decode(Float.self)
        y = try container.decode(Float.self)
        z = try container.decode(Float.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
        try container.encode(z)
    }
}

extension SCNMatrix4: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init()
        m11 = try container.decode(Float.self)
        m12 = try container.decode(Float.self)
        m13 = try container.decode(Float.self)
        m14 = try container.decode(Float.self)

        m21 = try container.decode(Float.self)
        m22 = try container.decode(Float.self)
        m23 = try container.decode(Float.self)
        m24 = try container.decode(Float.self)

        m31 = try container.decode(Float.self)
        m32 = try container.decode(Float.self)
        m33 = try container.decode(Float.self)
        m34 = try container.decode(Float.self)

        m41 = try container.decode(Float.self)
        m42 = try container.decode(Float.self)
        m43 = try container.decode(Float.self)
        m44 = try container.decode(Float.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(m11)
        try container.encode(m12)
        try container.encode(m13)
        try container.encode(m14)
        try container.encode(m21)
        try container.encode(m22)
        try container.encode(m23)
        try container.encode(m24)
        try container.encode(m31)
        try container.encode(m32)
        try container.encode(m33)
        try container.encode(m34)
        try container.encode(m41)
        try container.encode(m42)
        try container.encode(m43)
        try container.encode(m44)
    }
}
