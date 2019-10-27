//
//  WifiServiceManager.swift
//  ConnectedColors
//
//  Created by Ralf Ebert on 10/02/2017.
//  Copyright © 2017 Example. All rights reserved.
//

import Foundation
import MultipeerConnectivity

protocol WifiServiceManagerDelegate {
    func connectedDevicesChanged(manager: WifiServiceManager, connectedDevices: [String])
    // func colorChanged(manager : WifiServiceManager, colorString: String)
    func gotData(manager: WifiServiceManager, data: Data)
}

class WifiServiceManager: NSObject {
    // Service type must be a unique string, at most 15 characters long
    // and can contain only ASCII lowercase letters, numbers and hyphens.
    private let ServiceType = "example-service"

    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)

    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser

    var delegate: WifiServiceManagerDelegate?

    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()

    override init() {
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: ServiceType)
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: ServiceType)

        super.init()

        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()

        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }

    func send(colorName: String) {
        // NSLog("%@", "sendColor: \(colorName) to \(session.connectedPeers.count) peers")

        if session.connectedPeers.count > 0 {
            do {
                try session.send(colorName.data(using: .utf8)!, toPeers: session.connectedPeers, with: .reliable)
            } catch {
                NSLog("%@", "Error for sending: \(error)")
            }
        }
    }

    func sendData(_ data: Data, largeData: Bool) {
        // NSLog("%@", "sendColor: \(colorName) to \(session.connectedPeers.count) peers")

        if session.connectedPeers.count > 0 {
            do {
                if largeData {
                    try session.send(data, toPeers: session.connectedPeers, with: .reliable)
                } else {
                    try session.send(data, toPeers: session.connectedPeers, with: .unreliable)
                }
            } catch {
                NSLog("%@", "Error for sending: \(error)")
                print("Error for sending: \(error)")
            }
        }
    }

    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
}

extension WifiServiceManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }

    func advertiser(_: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext _: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, session)
    }
}

extension WifiServiceManager: MCNearbyServiceBrowserDelegate {
    func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo _: [String: String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
}

extension WifiServiceManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state)")
        delegate?.connectedDevicesChanged(manager: self, connectedDevices:
            session.connectedPeers.map { $0.displayName })
    }

    func session(_: MCSession, didReceive data: Data, fromPeer _: MCPeerID) {
        // NSLog("%@", "didReceiveData: \(data)")
        // let str = String(data: data, encoding: .utf8)!
        // self.delegate?.colorChanged(manager: self, colorString: str)
        delegate?.gotData(manager: self, data: data)
    }

    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }

    func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }

    func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
}
