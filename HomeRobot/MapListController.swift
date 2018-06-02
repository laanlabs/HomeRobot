//
//  MapListController.swift
//  HomeRobot
//
//  Created by cc on 5/31/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import UIKit
import Placenote
import PlacenoteSDK


protocol MapListDelegate {
    func newMapTapped()
    func mapLoaded(map: MapListController.Map)
}

class MapController : UINavigationController, UIPopoverPresentationControllerDelegate {
    
    let mapListController = MapListController()
    
    
    var mapDelegate : MapListDelegate? {
        set {
            self.mapListController.mapDelegate = newValue
        }
        get {
            return self.mapListController.mapDelegate
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.preferredContentSize = CGSize(width: 300, height: 300)
        
        
        self.pushViewController(mapListController, animated: false)
        
        self.setToolbarHidden(false, animated: false)
        
    }
    
    // MARK: UIPopoverPresentationControllerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
}

class MapListController: UITableViewController {
    
    class Map {
        var mapId : String = ""
        var metadata : [String: Any] = [:]
        var image : UIImage? = nil
    }
    
    var mapDelegate : MapListDelegate? = nil
    
    var maps : [Map] = []
    let MapCellIdentifier = "MapCellIdentifier"
    let mapThumb = UIImage.init(named: "map-thumb.png")
    
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
    
    var loading = false {
        didSet {
            if loading {
                self.tableView.alpha = 0.2
                self.tableView.isUserInteractionEnabled = false
                self.tableView.superview?.addSubview(spinner)
                spinner.frame = .init(x: 0, y: 0, width: 60, height: 60)
                spinner.center = self.tableView.center
                spinner.startAnimating()
            } else {
                self.tableView.isUserInteractionEnabled = true
                self.tableView.alpha = 1.0
                spinner.stopAnimating()
                spinner.removeFromSuperview()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.preferredContentSize = CGSize(width: 300, height: 300)
        
        tableView.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: MapCellIdentifier)
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let button = UIBarButtonItem(title: "New Map", style: .plain, target: self, action: #selector(addMapTapped))
        let close = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(closeTapped))
        
        self.setToolbarItems( [button, spacer, close] , animated: false )
        
        self.hidesBottomBarWhenPushed = false
        
        self.navigationItem.title = "Maps"
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        //self.navigationItem.leftBarButtonItem = button
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.loadMaps()
        }
        
        
    }
    
    // MARK: - Maps
    private func loadMaps() {
        
        self.loading = true
        LibPlacenote.instance.fetchMapList(listCb: onMapList)
        
    }
    
    private func onMapList(success: Bool, mapList: [String: Any]) -> Void {
        
        self.loading = false
        
        maps.removeAll()
        
        if (!success) {
            print ("failed to fetch map list")
            //statusLabel.text = "Map List not retrieved"
            self.tableView.reloadData()
            return
        }
        
        for place in mapList {
            
            //maps.append((place.key, place.value as? [String: Any]))
            
            let map = Map()
            map.mapId = place.key
            map.image = mapThumb
            
            maps.append( map )
            
            print(" map: ", map.mapId )
            
            
            
            if let meta = place.value as? [String:Any] {
                
                map.metadata = meta
                
                if let imageString = meta["image"] as? String {
                    if let imageData = Data.init(base64Encoded: imageString) {
                        let image = UIImage.init(data: imageData)
                        map.image = image
                    }
                    
                    
                }
                
                for k in meta {
                    print("map key: ", k.key )
                }
                
            }
            
            
        }
        
        self.tableView.reloadData()
        
        
    }
    
    
    @objc func addMapTapped() {
        self.navigationController?.dismiss(animated: true, completion: nil)
        self.mapDelegate?.newMapTapped()
    }
    
    @objc func closeTapped() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func showStatus( _ text : String ) {
        print(text)
        //self.statusLabel.text = text
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.maps.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: MapCellIdentifier, for: indexPath)
        
        let map = self.maps[indexPath.row]
        cell.textLabel?.text = map.mapId
        cell.detailTextLabel?.text = "A map"
        cell.imageView?.image = map.image

        return cell
        
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    //Make rows editable for deletion
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    //Delete Row and its corresponding map
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            
            LibPlacenote.instance.deleteMap(mapId: maps[indexPath.row].mapId, deletedCb: {(deleted: Bool) -> Void in
                if (deleted) {
                    
                    self.showStatus("Deleting: " + self.maps[indexPath.row].mapId)
                    self.maps.remove(at: indexPath.row)
                    //self.tableView.reloadData()
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    
                }
                else {
                    
                    self.showStatus("Can't Delete: " + self.maps[indexPath.row].mapId )
                    
                }
            })
        }
    }
    
    //Map selected
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.loading = true
        
        let map = maps[indexPath.row]
        self.showStatus( " Downloading map: " + map.mapId )
        
        LibPlacenote.instance.loadMap(mapId: map.mapId,
                                      downloadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
                                        
            if (completed) {
                self.loading = false
                LibPlacenote.instance.startSession()
                self.dismiss(animated: true, completion: nil)
                self.mapDelegate?.mapLoaded(map: map)
            }
                                        
        })
        
    }

    

}
