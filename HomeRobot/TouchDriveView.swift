//
//  TouchDriveView.swift
//  HomeRobot
//
//  Created by cc on 6/2/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

protocol TouchDriveDelegate {
    func valueChanged(steering: Float, power: Float)
}

class RadialSliderView: UIView {
    // from -1.0 : 1.0
    var value: Float = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.clear(rect)

        let path = UIBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        path.lineWidth = 1.0

        UIColor.black.withAlphaComponent(0.25).setFill()
        UIColor.white.setStroke()

        path.stroke()
        path.fill()

        let w = bounds.size.width

        let path3 = UIBezierPath(rect: CGRect(x: 0, y: bounds.size.height * 0.5 - 5,
                                              width: bounds.size.width, height: 10))
        UIColor.white.withAlphaComponent(0.3).setFill()
        path3.fill()

        // Thumb
        let pos_x: CGFloat = w * (CGFloat(value) + 1.0) * 0.5
        let thumbSize: CGFloat = 35.0

        let thumbRect = CGRect(origin: CGPoint(x: pos_x - thumbSize * 0.5, y: bounds.size.height * 0.5 - thumbSize * 0.5),
                               size: CGSize(width: thumbSize, height: thumbSize))

        let path2 = UIBezierPath(ovalIn: thumbRect)
        path2.lineWidth = 2.0

        UIColor.white.setFill()
        UIColor.black.setStroke()

        path2.stroke()
        path2.fill()
    }
}

class TouchDriveView {
    var delegate: TouchDriveDelegate?

    var steeringView = RadialSliderView()
    var powerView = RadialSliderView()

    init(size: CGFloat) {
        powerView.frame = CGRect(x: 0, y: 0, width: size, height: size)

        powerView.backgroundColor = UIColor.clear
        powerView.transform = CGAffineTransform(rotationAngle: -CGFloat.pi * 0.5)

        steeringView.frame = CGRect(x: 0, y: 0, width: size, height: size)

        steeringView.backgroundColor = UIColor.clear

        powerView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
        steeringView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))

//        self.addSubview(powerView)
//        self.addSubview(steeringView)
    }

    @objc func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let sliderView = pan.view as? RadialSliderView else { return }

        if pan.state == .cancelled || pan.state == .ended || pan.state == .failed {
            sliderView.value = 0.0
        } else {
            let pos = pan.location(in: sliderView)
            let value = (pos.x / sliderView.bounds.size.width) * 2.0 - 1.0
            sliderView.value = Float(value)
        }

        delegate?.valueChanged(steering: steeringView.value, power: powerView.value)
    }
}
