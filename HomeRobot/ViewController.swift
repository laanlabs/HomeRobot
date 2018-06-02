//
//  ViewController.swift
//  HomeRobot
//
//  Created by William Perkins on 5/30/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import UIKit
import PlacenoteSDK
import ARKit
import CoreLocation

extension UIColor {
    static var appleBlueColor = UIColor.init(red: 0, green: 120.0 / 255.0 , blue: 200.0 / 255.0, alpha: 1.0)
}

extension Date {
    var secondsAgo : TimeInterval {
        return -self.timeIntervalSinceNow
    }
    var millisecondsAgo : TimeInterval {
        return -self.timeIntervalSinceNow * 1000.0
    }
}


class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate,
                        PNDelegate, CLLocationManagerDelegate, MapListDelegate,
                        TouchDriveDelegate {
    
    
    enum RobotConnectionState {
        case disconnected
        case wifi
        case plug
    }
    
    var botConnectionState : RobotConnectionState = .disconnected {
        didSet {
            if oldValue == botConnectionState { return; }
            
            if botConnectionState == .disconnected {
                botModeButton.isUserInteractionEnabled = false
                botModeButton.setBackgroundImage(UIImage.init(named: "bot.png"), for: .normal)
            } else if botConnectionState == .wifi {
                print(" >>> Connected WiFi")
                botModeButton.isUserInteractionEnabled = true
                botModeButton.setBackgroundImage(UIImage.init(named: "bot-wifi.png"), for: .normal)
                
            } else if botConnectionState == .plug {
                botModeButton.isUserInteractionEnabled = true
                botModeButton.setBackgroundImage(UIImage.init(named: "bot-plug.png"), for: .normal)
            }
        }
    }
    
    enum BotInteractionState {
        case none
        case addShapes
        case addWaypoints
        case drivingControls
    }
    
    var interactionState : BotInteractionState = .none {
        didSet {
            
            if interactionState == .drivingControls {
                self.showDrivingView()
            }
            else if oldValue == .drivingControls {
                self.hideDrivingView()
            } else if interactionState == .addWaypoints {
                self.showStatus("Tap to add points")
            }
        }
    }
    
    enum MappingState {
        case none
        case localizing
        case creatingMap
    }
    
    var mappingState : MappingState = .none {
        didSet {
            // reset this if we leave .localizing
            hasFoundMapOnce = false
        }
    }
    
    // TODO: map id to sync with remote partner?
    //  not sure how placenote works exactly -- like status can still !running/lost but the sync seems fine
    var hasFoundMapOnce = false
    
    
    var trackingStarted = false
    
    
    @IBOutlet var showMapListButton : UIButton! = nil 
    @IBOutlet var doneMappingButton : UIButton! = nil
    @IBOutlet var botModeButton : UIButton! = nil
    @IBOutlet var statusLabel : UILabel! = nil
    @IBOutlet var robotStatusLabel : UILabel! = nil
    
    var sceneView : ARSCNView! = nil
    var scene : SCNScene! = nil
    
    private var planesVizAnchors = [ARAnchor]();
    private var planesVizNodes = [UUID: SCNNode]();
    var planeDetection = true
    
    var shapeManager : ShapeManager! = nil
    
    var locationManager : CLLocationManager! = nil
    private var lastLocation: CLLocation? = nil
    
    private var camManager: CameraManager? = nil
    
    
    private var currentMapId : String! = nil
    private var lastScreenshot : UIImage! = nil
    
    
    // Wifi stuff
    @IBOutlet var connectionsLabel : UILabel! = nil
    private var wifiDevice : WifiServiceManager! = nil
    
    
    // Robot
    var robot : RMCoreRobotRomo3! = nil
    
    
    var driveView : TouchDriveView! = nil
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        TestRobotMessages()
        
        sceneView = ARSCNView(frame: self.view.frame)
        
        sceneView.session.delegate = self
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.isPlaying = true
        
        scene = SCNScene()
        sceneView.scene = scene
        
        if let camera: SCNNode = sceneView.pointOfView {
            camManager = CameraManager(scene: scene, cam: camera)
        }
        
        //sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        shapeManager = ShapeManager(scene: scene, view: sceneView)
        
        
        self.view.insertSubview(sceneView, at: 0)

        UIApplication.shared.isIdleTimerDisabled = true
        
        RMCore.setDelegate(self)
        
        
        self.showStatus("Hi")
        
        //IMPORTANT: need to run this line to subscribe to pose and status events
        //Declare yourself to be one of the delegates of PNDelegate to receive pose and status updates
        LibPlacenote.instance.multiDelegate += self;

        
        // Location
        locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self;
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            locationManager.startUpdatingLocation()
        }
        
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.isEnabled = true
        sceneView.addGestureRecognizer(tapRecognizer)

        
        wifiDevice = WifiServiceManager()
        wifiDevice.delegate = self
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: {
            self.startPeerTimer()
        })
        
        
        
    }

    //Initialize view and scene
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !isSessionRunning {
            configureSession()
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        //scnView.session.pause()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sceneView.frame = view.bounds
        
        if let dv = self.driveView {
            let size = dv.powerView.bounds.size.width
            let h = self.view.bounds.size.height
            let w = self.view.bounds.size.width
            dv.powerView.center = CGPoint.init(x: size * 0.5, y: h - size * 0.55)
            dv.steeringView.center = CGPoint.init(x: w - size * 0.5, y: h - size * 0.55)
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK: ARKit
    
    var isSessionRunning = false
    
    func configureSession() {
        
        isSessionRunning = true
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = ARWorldTrackingConfiguration.WorldAlignment.gravity //TODO: Maybe not heading?
        
        if (planeDetection) {
            if #available(iOS 11.3, *) {
                //configuration.planeDetection = [.horizontal, .vertical]
                configuration.planeDetection = [.horizontal,]
            } else {
                configuration.planeDetection = [.horizontal]
            }
        }
        else {
            for (_, node) in planesVizNodes {
                node.removeFromParentNode()
            }
            for (anchor) in planesVizAnchors { //remove anchors because in iOS versions <11.3, the anchors are not automatically removed when plane detection is turned off.
                sceneView.session.remove(anchor: anchor)
            }
            planesVizNodes.removeAll()
            configuration.planeDetection = []
        }
        
        // Run the view's session
        sceneView.session.run(configuration)
        
    }
    
    
    // MARK: - MapListDelegate
    func newMapTapped() {
        
        LibPlacenote.instance.stopSession()
        LibPlacenote.instance.startSession()
        
        self.doneMappingButton.isHidden = false
        self.mappingState = .creatingMap
        
        //creating new map, remove old shapes.
        shapeManager.clearShapes()
        
        // Take a photo when new map is created for the thumbnail
        self.lastScreenshot = self.sceneView.snapshot()
        
    }
    
    func mapLoaded(map: MapListController.Map) {
        
        self.showStatus("Map Loaded. Look Around" )
        self.mappingState = .localizing
        self.currentMapId = map.mapId
        
        if (self.shapeManager.loadShapeArray(shapeArray: map.metadata["shapeArray"] as? [[String: [String: String]]])) {
            self.showStatus("Map Loaded. Look Around!" )
        }
        
    }
    
    
    // MARK: - UI Actions
    @IBAction func botModeButtonTapped() {
        
        
        if self.botConnectionState != .wifi {
            let msg = "No Bot connected. Make sure bots are on the same WiFi"
            self.showAlert(msg)
            return;
        }
        

        let alert = UIAlertController(title: "", message: "Select Bot Mode", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title:"Drive Controls", style: .default, handler: { action in
            self.interactionState = .drivingControls
        }))
        
        alert.addAction(UIAlertAction(title:"Waypoint Mode", style: .default, handler: { action in
            self.interactionState = .addWaypoints
        }))
        
        
        if (self.interactionState == .addWaypoints) && (self.pendingCommands.count > 0) {
            
            alert.addAction(UIAlertAction(title:"Send Waypoints", style: .default, handler: { action in
                self.sendAllPendingMarkers(nil)
            }))
            
        }
        
        
        
        alert.addAction(UIAlertAction(title:"Cancel", style: .cancel, handler: nil ))
        
        if let popoverPresentationController = alert.popoverPresentationController,
            let view = self.botModeButton {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = view.bounds
        }
        
        self.present(alert, animated: true, completion: nil)
        
        
    }
    
    @objc func handleTap(sender: UITapGestureRecognizer) {
        
        if self.mappingState == .creatingMap {
            let tapLocation = sender.location(in: sceneView)
            
            let hitTestResults = sceneView.hitTest(tapLocation, types: .featurePoint)
            
            if let result = hitTestResults.first {
                let pose = LibPlacenote.instance.processPose(pose: result.worldTransform)
                shapeManager.spawnRandomShape(position: pose.position())
                self.lastScreenshot = self.sceneView.snapshot()
            }
            
        } else if self.interactionState == .addWaypoints {
            
            if !self.areClientsSynced {
                let msg = "You must first sync positions. Create a map, and load the map on both robot and controller devices."
                self.showAlert(msg)
                return;
            }
            
            // && self.robot.isRemotelyConnected or something
            //if lastPanMove.millisecondsAgo < 100.0 { return; }
            //lastPanMove = Date()
            
            let tapLocation = sender.location(in: sceneView)
            
            let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlane)
            
            var bestPos : SCNVector3! = nil
            
            for result in hitTestResults {
                
                let pos = LibPlacenote.instance.processPose(pose: result.worldTransform).position()
                if bestPos == nil || pos.y < bestPos.y {
                    bestPos = pos
                }
            }
            
            // Move off the floor a little
            if var pos = bestPos {
                pos.y += 0.06
                self.addDriveToMarker(pos)
            }
            
        }
        
    }
    
    @IBAction func showMapsTapped() {
        self.showMapList()
    }
    
    func showMapList() {
        
        let vc = MapController()
        vc.mapDelegate = self
        
        vc.modalPresentationStyle = UIModalPresentationStyle.popover

        let popOverController = vc.popoverPresentationController
        popOverController!.delegate = vc

        popOverController!.sourceView = self.view
        let frame = self.showMapListButton.frame
        
        popOverController!.sourceRect = CGRect.init(x:frame.origin.x,
                                                    y:frame.origin.y-20,
                                                    width:frame.size.width,
                                                    height:frame.size.height)
        
        popOverController?.permittedArrowDirections = .any

        self.present(vc, animated: true, completion: nil)
        
        
    }
    
    func showAlert( _ msg : String, title : String = "Alert!") {
        
        let alertController = UIAlertController(title: title,
                                                message: msg,
                                                preferredStyle: UIAlertControllerStyle.alert)
        
        let okAction = UIAlertAction(title: "Confirm", style: UIAlertActionStyle.default) {
            (result : UIAlertAction) -> Void in
        }
        
        alertController.addAction(okAction)
        
        self.present(alertController, animated: true, completion: nil)
        
    }
    
    @IBAction func doneMappingTapped() {
        
        self.doneMappingButton.isHidden = true
        
        LibPlacenote.instance.saveMap(
            savedCb: {(_mapId: String?) -> Void in
                if let mapId = _mapId {
                    
                    self.showStatus("Saved map: " + mapId )
                    self.currentMapId = mapId
                    LibPlacenote.instance.stopSession()
                    
                    var metadata: [String: Any] = [:]
                    
                    if (self.lastLocation != nil) {
                        metadata["location"] = ["latitude": self.lastLocation!.coordinate.latitude,
                                                "longitude": self.lastLocation!.coordinate.longitude,
                                                "altitude": self.lastLocation!.altitude]
                    }
                    
                    if let image = self.lastScreenshot {
                        let str = self.base64encode(image)
                        metadata["image"] = str
                    }
                    
                    metadata["shapeArray"] = self.shapeManager.getShapeArray()
                    
                    let jsonData = try? JSONSerialization.data(withJSONObject: metadata)
                    let jsonString = String.init(data: jsonData!, encoding: String.Encoding.utf8)
                    
                    if (!LibPlacenote.instance.setMapMetadata(mapId: mapId, metadataJson: jsonString!)) {
                        print ("Failed to set map metadata")
                    }
                    
                    //self.planeDetSelection.isOn = false
                    self.planeDetection = false
                    
                    self.configureSession()
                    
                } else {
                    self.showStatus("Failed to Save map")
                }
        },
            uploadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
                if (completed) {
                    self.showStatus("Upload complete: " + self.currentMapId )
                } else if (faulted) {
                    self.showStatus("Upload FAIL")
                } else {
                    //print ("Progress: " + percentage.description)
                    //self.fileTransferLabel.text = "Map Upload: " + String(format: "%.3f", percentage) + "/1.0"
                    self.showStatus( String(format: "Uploading: %4.0f%%", percentage * 100.0 ))
                }
        }
        )
        
    }
    
    
    func showStatus( _ text : String ) {
        DispatchQueue.main.async {
            self.statusLabel.text = text
        }
    }
    
    // MARK: - PNDelegate
    func onPose(_ outputPose: matrix_float4x4, _ arkitPose: matrix_float4x4) {
        
    }
    
    func onStatusChange(_ prevStatus: LibPlacenote.MappingStatus, _ currStatus: LibPlacenote.MappingStatus) {
        
        if prevStatus != LibPlacenote.MappingStatus.running && currStatus == LibPlacenote.MappingStatus.running {
            
            //just localized redraw the shapes
            shapeManager.drawView(parent: scene.rootNode)
            
            if self.mappingState == .creatingMap {
                self.showStatus("Tap anywhere to add Shapes")
            }
            else if self.mappingState == .localizing {
                hasFoundMapOnce = true
                self.showStatus("Map Found!")
            }
            
            //As you are localized, the camera has been moved to match that of Placenote's Map. Transform the planes
            //currently being drawn from the arkit frame of reference to the Placenote map's frame of reference.
            for (_, node) in planesVizNodes {
                node.transform = LibPlacenote.instance.processPose(pose: node.transform);
            }
            
        }
        
        if prevStatus == LibPlacenote.MappingStatus.running && currStatus != LibPlacenote.MappingStatus.running {
            //just lost localization
            if self.mappingState == .creatingMap {
                self.showStatus("Map Lost")
            }
        }
        
    }
    
    
    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        //if planesVizNodes.count > 0 { return nil; }
        let node = SCNNode()
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        //if planesVizNodes.count > 0 { return; }
        
        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.magenta
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        node.transform = LibPlacenote.instance.processPose(pose: node.transform); //transform through
        planesVizNodes[anchor.identifier] = node; //keep track of plane nodes so you can move them once you localize to a new map.
        
        /*
         `SCNPlane` is vertically oriented in its local coordinate space, so
         rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
         */
        planeNode.eulerAngles.x = -.pi / 2
        
        // Make the plane visualization semitransparent to clearly show real-world placement.
        //planeNode.opacity = 0.012
        planeNode.opacity = 0.12
        
        /*
         Add the plane visualization to the ARKit-managed node so that it tracks
         changes in the plane anchor as plane estimation continues.
         */
        node.addChildNode(planeNode)
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        // Plane estimation may shift the center of a plane relative to its anchor's transform.
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         Plane estimation may extend the size of the plane, or combine previously detected
         planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
         corresponding node for one plane, then calls this method to update the size of
         the remaining plane.
         */
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
        
        node.transform = LibPlacenote.instance.processPose(pose: node.transform)
    }
    
    // MARK: - ARSessionDelegate
    
    //Provides a newly captured camera image and accompanying AR information to the delegate.
    func session(_ session: ARSession, didUpdate: ARFrame) {
        
        let image: CVPixelBuffer = didUpdate.capturedImage
        let pose: matrix_float4x4 = didUpdate.camera.transform
        
        if (!LibPlacenote.instance.initialized()) {
            //print("SDK is not initialized")
            return
        }
        
        if (self.mappingState == .creatingMap || self.mappingState == .localizing) {
            LibPlacenote.instance.setFrame(image: image, pose: pose)
        }
    }
    
    
    //Informs the delegate of changes to the quality of ARKit's device position tracking.
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        var status = "Loading.."
        switch camera.trackingState {
        case ARCamera.TrackingState.notAvailable:
            status = "Not available"
        case ARCamera.TrackingState.limited(.excessiveMotion):
            status = "Excessive Motion."
        case ARCamera.TrackingState.limited(.insufficientFeatures):
            status = "Insufficient features"
        case ARCamera.TrackingState.limited(.initializing):
            status = "Initializing"
        case ARCamera.TrackingState.limited(.relocalizing):
            status = "Relocalizing"
        case ARCamera.TrackingState.normal:
            if (!trackingStarted) {
                trackingStarted = true
                //newMapButton.isEnabled = true
            }
            status = "Ready"
        }
        self.showStatus(status)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for (anchor) in anchors {
            planesVizAnchors.append(anchor)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
    
    func base64encode( _ image : UIImage ) -> String {
        
        let img = image.cropToSquare()!.resizeImage(48, opaque: true)
        
        return UIImageJPEGRepresentation(img, 0.2)!.base64EncodedString()
        
        
    }
    
    
    // MARK: - Wifi
    
    // Pyramid that will display over the robot or phone
    var peerNode : SCNNode! = nil
    
    func sendMessage( _ message : RobotMessage ) {
        
        //guard let jsonData = try? JSONSerialization.data(withJSONObject: message.toJson()) else { return; }
        
        guard let jsonData = EncodeRobotMessage( message ) else { return; }
        
        if self.wifiDevice.session.connectedPeers.count > 0 {
            self.wifiDevice.sendData(jsonData)
        }
        
    }
    
    
    func processIncomingData(_ data : Data ) {
        
        guard let message = ParseRobotMessageData( data ) else { return; }
        
        if let driveMessage = message as? DriveMotorMessage {
            self.robot.drive(withLeftMotorPower: driveMessage.leftMotorPower, rightMotorPower: driveMessage.rightMotorPower)
        } else if let locationMessage = message as? UpdateLocationMessage {
            self.updatePeerNode( locationMessage )
        } else if let addWaypoint = message as? WaypointAddMessage {
            self.addDrivingPoint(RobotMarker(flagNode: nil, flagId: addWaypoint.markerId, position: addWaypoint.location))
        } else if let clearWaypoint = message as? WaypointAchievedMessage {
            self.showCompletedMarker(clearWaypoint)
        }
        
    }
    
    
    // Periodically send our location to other connected devices
    func startPeerTimer() {
        
        let _ = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { (_) in
            
            //if !self.hasFoundMapOnce { return; }
            
            guard let cam = self.sceneView.pointOfView else { return }
            
            let message = UpdateLocationMessage(location: cam.worldPosition,
                                                transform: cam.worldTransform,
                                                robotConnected: (self.robot != nil),
                                                currentMapId: self.currentMapId,
                                                hasLocalized: self.hasFoundMapOnce)
            
            
            self.sendMessage( message )
            
        }
        
        
    }
    
    
    func sendCompletedMarker( _ marker : RobotMarker ) {
        
        let message = WaypointAchievedMessage(markerId: marker.flagId)
        self.sendMessage(message)
        
    }
    
    var lastStatusMessage : UpdateLocationMessage? = nil
    var lastStatusDate : Date? = nil
    var areClientsSynced : Bool {
        get {
            guard let d = self.lastStatusDate, let msg = self.lastStatusMessage else { return false; }
            return (d.secondsAgo < 2.0 && msg.hasLocalized && self.hasFoundMapOnce && self.currentMapId == msg.currentMapId)
        }
    }
    
    // Update the node position and add dot trail as the robot moves
    func updatePeerNode( _ result : UpdateLocationMessage ) {
        
        lastStatusDate = Date()
        lastStatusMessage = result
        
        //let allGood = (result.currentMapId == self.currentMapId) && (self.hasFoundMapOnce) && result.hasLocalized
        
        // Only update position if both devices are localized on the same map
        if self.areClientsSynced {
            if peerNode == nil {
                let ball = SCNPyramid(width: 0.06, height: 0.1, length: 0.06)
                ball.firstMaterial?.diffuse.contents = UIColor.magenta
                peerNode = SCNNode(geometry: ball)
                peerNode.eulerAngles.x = Float.pi
                self.scene.rootNode.addChildNode(peerNode)
            }
            
            let posPN = SCNVector3( result.location.x,
                                    result.location.y,
                                    result.location.z )
            
            peerNode.transform = result.transform
            addTrackingBall(posPN)
        }
        
        DispatchQueue.main.async {
            
            if result.robotConnected {
                self.botConnectionState = .wifi
                self.robotStatusLabel.text = "Robot Wifi"
            } else {
                if self.robot == nil {
                    self.botConnectionState = .disconnected
                    self.robotStatusLabel.text = "Robot Off"
                }
            }
        }
        
        
        
    }
    
    private var lastPos : SCNVector3 = SCNVector3Zero
    private var balls : [ SCNNode ] = [ ]
    private var ballIdx : Int = 0
    
    // Add dot trail with max dots
    func addTrackingBall( _ pos : SCNVector3 ) {
        
        if ( pos - lastPos ).length() < 0.012 { return; }
        lastPos = pos
        
        let ball = SCNSphere(radius: 0.007)
        ball.firstMaterial?.diffuse.contents = (ballIdx % 2 == 0) ? UIColor.white : UIColor.red
        ball.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: ball)
        n.position = pos
        
        ballIdx += 1
        
        self.scene.rootNode.addChildNode(n)
        balls.append(n)
        
        let maxSize : Int = 150
        
        if balls.count > maxSize {
            
            let idx = balls.count - maxSize
            
            let b2 = balls[..<idx]
            
            for b in b2 {
                b.removeFromParentNode()
            }
            
            balls = Array(balls[idx...])
            
        }
        
    }
    
    
    // MARK: - Path
    var points : [RobotMarker] = []
    
    var isDriving : Bool = false
    
    var drivingDestination : SCNVector3 = SCNVector3Zero
    var driveQueue = DispatchQueue(label: "com.laan.driveQueue")
    
    func addDrivingPoint( _ marker : RobotMarker ) {
        self.showStatus("Waypoint: " + String(marker.flagId) )
        driveQueue.async {
            self.points.append(marker)
            
            if self.isDriving == false {
                self.driveCurrentPath()
            }
            
        }
        
    }
    
    // MARK: -
    var leftPowerTween : Float = 0
    var rightPowerTween : Float = 0
    
    // Attempt badly to drive robot to each point in the 'points' list
    func driveCurrentPath() {
        
        if isDriving { return }
        
        if !self.robot.isConnected { return }
        
        guard let cam = self.sceneView.pointOfView else { return; }
        
        self.isDriving = true
        
        DispatchQueue.global().async {
            
            var currentPoint : RobotMarker! = nil
            
            while true {
                
                // get point if exists
                currentPoint = nil
                
                self.driveQueue.sync {
                    if self.points.count > 0 {
                        currentPoint = self.points.remove(at: 0)
                    }
                }
                
                // out of points
                if currentPoint == nil {
                    break
                }
                
                // TODO: Better path planning
                // RM_DRIVE_RADIUS_TURN_IN_PLACE = 0
                //let r1 = RM_DRIVE_RADIUS_TURN_IN_PLACE
                //self.robot.drive(withRadius: 0, speed: 1)
                
                // Run drive + adjust loop
                while true {
                    
                    let camPos = cam.worldPosition
                    let destPos = currentPoint.position.withY(y: cam.worldPosition.y )
                    let destDir = destPos - camPos
                    // phone faces opposite direction from bot forward
                    // so phone camera forward is -Z .. bot forward is Z
                    let botDir = (cam.worldTransform.zAxis).withY(y: 0)
                    let angleDiff = botDir.angle(between: destDir) * 180.0 / Float.pi
                    
                    let minDistToWayPoint : Float = 0.15
                    
                    // Is the point too close to robot to bother?
                    let dist = (camPos - destPos).length()
                    if dist < minDistToWayPoint {
                        self.sendCompletedMarker( currentPoint )
                        break
                    }
                    
                    let turnRight = botDir.cross(vector: destDir).y < 0
                    
                    var leftPower : Float = 0
                    var rightPower : Float = 0
                    
                    let speed : Float = 0.6 + 0.2 * min(dist, 2.0)
                    let maxAngle : Float = 50.0
                    
                    if angleDiff > maxAngle {
                        
                        let turnPower : Float = 0.62
                        
                        // just do turn around
                        leftPower = turnRight ? turnPower : -turnPower
                        rightPower = turnRight ? -turnPower : turnPower
                        
                    } else {
                        
                        let frac : Float = 0.1
                        // at center:  1 --> 0
                        let turnFactor = (1.0 - pow(angleDiff / maxAngle, 0.4) )
                        let turnPower = frac + (speed - frac) * turnFactor
                        
                        if turnRight {
                            
                            leftPower = speed
                            rightPower = turnPower
                            
                        } else {
                            
                            rightPower = speed
                            leftPower = turnPower
                            
                        }
                        
                    }
                    
                    self.leftPowerTween = self.leftPowerTween - (self.leftPowerTween - leftPower) * 0.2
                    self.rightPowerTween = self.rightPowerTween - (self.rightPowerTween - rightPower) * 0.2
                    
                    self.robot.drive(withLeftMotorPower: self.leftPowerTween, rightMotorPower: self.rightPowerTween)
                    
                    Thread.sleep(forTimeInterval: (1.0/15.0))
                    
                }
                
            }
            
            self.status("Finished Path")
            self.robot.stopDriving()
            self.isDriving = false
            
        }
        
    }
    
    func status( _ s : String ) {
        DispatchQueue.main.async {
            self.statusLabel.text = s
        }
    }
    
    
    // MARK: -
    struct RobotMarker {
        var flagNode : SCNNode!
        var flagId : Int
        var position : SCNVector3
    }
    
    var pendingCommands : [RobotMarker] = []
    var visibleFlags : [RobotMarker] = []
    
    func showCompletedMarker( _ message : WaypointAchievedMessage ) {
        
        for marker in visibleFlags {
            
            if marker.flagId == message.markerId {
                
                // Turn pin green
                if let cyl = marker.flagNode.childNode(withName: "sphere", recursively: true) {
                    cyl.geometry?.firstMaterial?.diffuse.contents = UIColor.green
                }
                
                return;
                
            }
        }
        
    }
    
    
    var prevPos : SCNVector3! = nil
    
    // Adds a 3d pin and draws a line if there was a previous pin
    func addDriveToMarker( _ p : SCNVector3 ) {
        
        let pin = self.newPinMarker()!
        pin.worldPosition = p
        pin.scale = .one * 3.25
        self.scene.rootNode.addChildNode(pin)
        
        if let prev = prevPos {
            
            let line = SKLine(radius: 0.005, color: UIColor.white.withAlphaComponent(0.9), start: prev, end: p)
            line.capsule.firstMaterial?.lightingModel = .constant
            
            let surf = """
            
            #pragma transparent
            #pragma body
            float ss = sin( 15.0 * u_time + _surface.diffuseTexcoord.y * 35.0 );
            float yy = 0.1 + 0.45 + 0.45 * ss;
            _surface.diffuse.a = yy;
            
            if ( ss > 0.9 ) {
                _surface.diffuse.rgb = vec3(0.25,0.85,1.0);
            } else if ( ss < 0.0 ) {
                _surface.diffuse.rgb = vec3(0.0,0.3,0.9);
            } else {
                _surface.diffuse.rgb = vec3(0.0,0.6,1.0);
            }
            """
            
            line.capsule.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.surface : surf ]
            
            
            self.scene.rootNode.addChildNode(line)
            
        }
        
        prevPos = p
        
        let flagId = Int(arc4random() % 100000)
        let marker = RobotMarker(flagNode: pin, flagId: flagId, position: p)
        
        self.visibleFlags.append(marker)
        self.pendingCommands.append(marker)
        
    }
    
    @objc func sendAllPendingMarkers( _ sender : Any? ) {
        
        if let b = sender as? UIButton {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                b.backgroundColor = UIColor.white
                b.setTitleColor(UIColor.appleBlueColor, for: .normal)
                
            }) { (succ) in
                
                UIView.animate(withDuration: 0.2) {
                    
                    b.setTitleColor(UIColor.white, for: .normal)
                    b.backgroundColor = UIColor.appleBlueColor
                }
                
            }
            
        }
        
        DispatchQueue.global().async {
            
            self.showStatus("Sending " + String(self.pendingCommands.count) + " cmds" )
            
            for marker in self.pendingCommands {
                self.sendMarkerCommand(marker)
                Thread.sleep(forTimeInterval: 0.15)
            }
            
        }
        
    }
    
    func sendDriveToPos( _ p : SCNVector3 ) {
        assert(false)
    }
    
    func sendMarkerCommand( _ marker : RobotMarker ) {
        self.sendMessage( WaypointAddMessage(markerId: marker.flagId, location: marker.position) )
    }
    
    
    
    var pinNode : SCNNode? = nil
    
    func newPinMarker( color: UIColor = UIColor.magenta,
                       addLights: Bool = true,
                       constantLighting : Bool = false) -> SCNNode? {
        
        guard let pinRoot = SCNScene(named: "pin.scn")?.rootNode else { return nil }
        
        guard let pin = pinRoot.childNode(withName: "pin", recursively: true) else { return nil }
        
        if let cyl = pin.childNode(withName: "cylinder", recursively: true) {
            cyl.renderingOrder = 5601
            if constantLighting {
                cyl.geometry?.firstMaterial?.lightingModel = .constant
            }
        }
        
        if let cyl = pin.childNode(withName: "cone", recursively: true) {
            cyl.renderingOrder = 5600
            if constantLighting {
                cyl.geometry?.firstMaterial?.lightingModel = .constant
            }
        }
        
        if let cyl = pin.childNode(withName: "sphere", recursively: true) {
            cyl.geometry?.firstMaterial?.diffuse.contents = color
            cyl.renderingOrder = 5602
            if constantLighting {
                cyl.geometry?.firstMaterial?.lightingModel = .constant
            }
        }
        
        return pin
        
    }
    
    
    // MARK: - Driving View
    
    func showDrivingView() {
        
        if self.driveView == nil {
            driveView = TouchDriveView(size: 150)
            driveView.delegate = self
        }
        
        self.view.addSubview(driveView.powerView)
        self.view.addSubview(driveView.steeringView)
        
    }
    
    func hideDrivingView() {
        self.driveView?.powerView.removeFromSuperview()
        self.driveView?.steeringView.removeFromSuperview()
    }
    
    private var lastDriveMessage = Date()
    
    func valueChanged( steering : Float , power : Float ) {
        
        if self.botConnectionState == .wifi  {
           // && lastDriveMessage.millisecondsAgo > 100.0
        //lastDriveMessage = Date()
        
        var leftPower : Float = 0.0 // steering * power
        var rightPower : Float = 0.0 // steering * power * -1.0
        
        if steering >= 0 {
            
            leftPower = 1.0
            rightPower = 1.0 - 2.0 * steering
            
        } else {
            rightPower = 1.0
            leftPower = 1.0 + 2.0 * steering
        }
        
        rightPower *= power
        leftPower *= power
        
        self.sendMessage(DriveMotorMessage(leftMotorPower: leftPower, rightMotorPower: rightPower))
        }
        
    }
    
    

}



// MARK: - WifiServiceManagerDelegate
extension ViewController : WifiServiceManagerDelegate {
    
    func connectedDevicesChanged(manager: WifiServiceManager, connectedDevices: [String]) {
        OperationQueue.main.addOperation {
            var s = ""
            for d in connectedDevices {
                s += d
                s += ", "
            }
            self.connectionsLabel.text = "Wifi: " + s
            
            if connectedDevices.count == 0 && self.robot == nil {
                self.botConnectionState = .disconnected
            }
            
        }
    }
    
    func gotData(manager: WifiServiceManager, data: Data) {
        self.processIncomingData(data)
    }
    
}



extension ViewController: RMCoreDelegate {
    
    func robotDidConnect(_ robot: RMCoreRobot!) {
        self.robot = robot as! RMCoreRobotRomo3
        self.robotStatusLabel.text = "Robot Connected!"
        self.botConnectionState = .plug
    }

    func robotDidDisconnect(_ robot: RMCoreRobot!) {
        self.robot = nil
        self.robotStatusLabel.text = "Robot Disconnected"
        self.botConnectionState = .disconnected
    }


}
