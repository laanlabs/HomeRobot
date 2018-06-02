//
//  ARCloud.swift
//  HomeRobot
//
//  Created by cc on 5/31/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import Foundation


/*protocol ARCloudManager {
    func startWithSceneView()
    func showMapPicker()
}*/

/*
 What does this manage?
 
 - Load an existing map
 - Create a new map
 -
 
 */

protocol ARCloudDelegate {
    
    func mapLoaded()
    
    // Init, Done, Uploading, Saved
    func mapCreationStatusChanged()
    
    
}

class ARCloudManager {
    
    
    
    func startWithSceneView() {
        
    }
    
    // Present as pop-over?
    func showMapPicker() {
        
    }
    
    
    // MARK: - Position conversion ARKit -> Map
    
    
    func convertToMap( position : SCNVector3 ) -> SCNVector3? {
        return nil
    }
    
    func convertFromMap( position : SCNVector3 ) -> SCNVector3? {
        return nil
    }
    
}
