//
//  MapListController.swift
//  HomeRobot
//
//  Created by cc on 5/31/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

import ARKit
import UIKit
protocol MapListDelegate {
    func newMapTapped()
    func mapLoaded(map: Map)
}

class MapController: UINavigationController, UIPopoverPresentationControllerDelegate {
    let mapListController = MapListController()

    var mapDelegate: MapListDelegate? {
        set {
            self.mapListController.mapDelegate = newValue
        }
        get {
            return self.mapListController.mapDelegate
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = CGSize(width: 300, height: 300)

        pushViewController(mapListController, animated: false)

        setToolbarHidden(false, animated: false)
    }

    // MARK: UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for _: UIPresentationController, traitCollection _: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

class MapListController: UITableViewController {
    var mapDelegate: MapListDelegate?

    var maps: [Map] = []
    let MapCellIdentifier = "MapCellIdentifier"
    let mapThumb = UIImage(named: "map-thumb.png")

    let spinner = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.gray)

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

        // self.preferredContentSize = CGSize(width: 300, height: 300)

        tableView.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: MapCellIdentifier)
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let button = UIBarButtonItem(title: "New Map", style: .plain, target: self, action: #selector(addMapTapped))
        let close = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(closeTapped))

        setToolbarItems([button, spacer, close], animated: false)

        hidesBottomBarWhenPushed = false

        navigationItem.title = "Maps"

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        navigationItem.rightBarButtonItem = editButtonItem
        // self.navigationItem.leftBarButtonItem = button

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.loadMaps()
        }
    }

    // MARK: - Maps Loading

    func mapLoadURL(_ key: String) -> URL {
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent(key)
        } catch {
            fatalError("Can't get file save URL: \(error.localizedDescription)")
        }
    }

    private func loadMaps() {
        loading = true

        maps.removeAll()

        guard let maps = UserDefaults.standard.array(forKey: "map")
            as? [String] else { return }

        print(maps)

        self.maps = maps.map({ (url) -> Map in

            let _map = Map()

            /// - Tag: ReadWorldMap
            let worldMap: ARWorldMap = {
                guard let data = try? Data(contentsOf: mapLoadURL(url))
                else { fatalError("Map data should already be verified to exist before Load button is enabled.") }
                return decotMap(data)
            }()

            // Display the snapshot image stored in the world map to aid user in relocalizing.
            if let snapshotData = worldMap.snapshotAnchor?.imageData,
                let snapshot = UIImage(data: snapshotData) {
                _map.image = snapshot
            } else {
                print("No snapshot image in world map")
            }

            worldMap.anchors.removeAll(where: { $0 is SnapshotAnchor })

            _map.worldMap = worldMap

            _map.mapId = url

            return _map
        })
        loading = false
        tableView.reloadData()
    }

    @objc func addMapTapped() {
        navigationController?.dismiss(animated: true, completion: nil)
        mapDelegate?.newMapTapped()
    }

    @objc func closeTapped() {
        navigationController?.dismiss(animated: true, completion: nil)
    }

    func showStatus(_ text: String) {
        print(text)
        // self.statusLabel.text = text
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return maps.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MapCellIdentifier, for: indexPath)

        let map = maps[indexPath.row]
        cell.textLabel?.text = map.mapId
        cell.detailTextLabel?.text = "A map"
        cell.imageView?.image = map.image

        return cell
    }

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        return 70
    }

    // Make rows editable for deletion
    override func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        return true
    }

    // Delete Row and its corresponding map
    override func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

            guard let url = directory?.appendingPathComponent(self.maps[indexPath.row].mapId) else { return }

            try? FileManager.default.removeItem(at: url)
            showStatus("Deleting: " + maps[indexPath.row].mapId)
            let list = maps.map({ $0.mapId }).filter({ $0 != maps[indexPath.row].mapId })

            maps.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            UserDefaults.standard.set(list, forKey: "map")
        }
    }

    // Map selected
    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        loading = true

        let map = maps[indexPath.row]
        showStatus("loading map: " + map.mapId)

        loading = false

        dismiss(animated: true, completion: nil)
        mapDelegate?.mapLoaded(map: map)
    }
}
