//
//  ViewController.swift
//  HomeRobot
//
//  Created by William Perkins on 5/30/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        RMCore.setDelegate(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController: RMCoreDelegate {
    func robotDidConnect(_ robot: RMCoreRobot!) {
        print("[ViewController::robotDidConnect]")
    }

    func robotDidDisconnect(_ robot: RMCoreRobot!) {
        print("[ViewController::robotDidDisconnect]")
    }


}
