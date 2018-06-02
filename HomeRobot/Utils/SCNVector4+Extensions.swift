//
//  SCNVector4+Extensions.swift
//  ARMeasure
//
//  Created by William Perkins on 8/14/17.
//  Copyright © 2017 Laan Labs. All rights reserved.
//

import SceneKit

extension SCNQuaternion {
    /// Create a quaternion representation of a rotation operation around an axis angle.
    // Adapted from http://www.euclideanspace.com/maths/geometry/rotations/conversions/angleToQuaternion/
    init(radians angle: Float, around axis: SCNVector3) {
        let s = sin(angle/2)
        self.x = axis.x * s
        self.y = axis.y * s
        self.z = axis.z * s
        self.w = cos(angle/2)
    }
    
    /// Combine two quaternions together.
    // Adapted from http://www.euclideanspace.com/maths/algebra/realNormedAlgebra/quaternions/code/
    func concatenating(_ other: SCNQuaternion) -> SCNQuaternion {
        return SCNQuaternion(
            x: (x *  other.w) + (y *  other.z) + (z * -other.y) + (w * other.x),
            y: (x * -other.z) + (y *  other.w) + (z *  other.x) + (w * other.y),
            z: (x * -other.y) + (y * -other.x) + (z *  other.w) + (w * other.z),
            w: (x *  other.x) + (y * -other.y) + (z * -other.z) + (w * other.w)
        )
    }
}
