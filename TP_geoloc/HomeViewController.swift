//
//  HomeViewController.swift
//  TP_geoloc
//
//  Created by Julien Guillan on 18/11/2020.
//

import UIKit
import MapKit

class HomeViewController: UIViewController {
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var mapView: MKMapView!
    
    var annotations: [MKPointAnnotation] = []
    var defaultAnnotations: [MKPointAnnotation] = []
    var stores: [Store] = []
    var locationManager: CLLocationManager?
    var products: [GraphicCard]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        self.searchBar.delegate = self
        self.mapView.delegate = self
        self.mapView.addSubview(searchBar)
        self.products = []
        
        self.searchBar.placeholder = "Search store"
        
        if CLLocationManager.locationServicesEnabled(){
            let locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            self.locationManager = locationManager
        }
        
        let sws = StoreWebService()
        sws.getStores { (stores) in
            for store in stores {
                self.stores.append(store)
                self.setAnnotations(store: store, def: true)
            }
            self.mapView.addAnnotations(self.annotations)
            self.mapView.showAnnotations(self.mapView.annotations, animated: true)
            self.locationManager?.stopUpdatingLocation()
        }
    }
    
    func setAnnotations(store: Store, def: Bool = false) {
        let annot = MKPointAnnotation()
        annot.title = store.name
        annot.coordinate = CLLocationCoordinate2D(latitude: store.coordinates.coordinate.latitude, longitude: store.coordinates.coordinate.longitude)
        self.annotations.append(annot)
        if def{
            self.defaultAnnotations.append(annot)
        }
    }
    
    func clearMapView() {
        for annotation in self.annotations {
            self.mapView.removeAnnotation(annotation)
        }
        self.annotations.removeAll()
        self.stores.removeAll()
    }
    
    func restoreMap(){
        self.mapView.addAnnotations(self.defaultAnnotations)
        self.mapView.showAnnotations(self.mapView.annotations, animated: true)
    }
    
    func detailsView(annotation: MKAnnotation) -> UIView? {
        guard let title = annotation.title else {
            return nil
        }
        
        let detailsView = UIView()
        let widthConstraint = NSLayoutConstraint(item: detailsView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.75, constant: self.view.bounds.width)
        detailsView.addConstraint(widthConstraint)
        
        let heightConstraint = NSLayoutConstraint(item: detailsView, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200)
        detailsView.addConstraint(heightConstraint)
        
        
        let productTableView = self.initTableView()
        self.loadProducts(storeName: title!, tableView: productTableView)
        
        detailsView.addSubview(productTableView)
        productTableView.translatesAutoresizingMaskIntoConstraints = false
        productTableView.topAnchor.constraint(equalTo: detailsView.topAnchor).isActive = true
        productTableView.leftAnchor.constraint(equalTo: detailsView.leftAnchor).isActive = true
        productTableView.rightAnchor.constraint(equalTo: detailsView.rightAnchor).isActive = true
        productTableView.bottomAnchor.constraint(equalTo: detailsView.bottomAnchor).isActive = true
    
        return detailsView
    }
    
    func loadProducts(storeName: String, tableView: UITableView?) {
        var currentStore: Store!
        for store in self.stores {
            if store.name == storeName {
                currentStore = store
            }
        }
        guard currentStore != nil else {
            return
        }
        self.products = currentStore.products
        if tableView != nil{
            tableView!.reloadData()
        }
    }
    
    func initTableView() -> UITableView{
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "ProductTableViewCell", bundle: nil), forCellReuseIdentifier: "productCell")
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 44.0;
        return tableView
    }
}

extension HomeViewController: MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {
    
    //MAP VIEW
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "store_annotation")
        if annotationView == nil {
            let newAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "store_annotation")
            let detailsView = self.detailsView(annotation: annotation)
            newAnnotationView.detailCalloutAccessoryView = detailsView
            newAnnotationView.canShowCallout = true
            annotationView = newAnnotationView
        } else {
            annotationView!.annotation = annotation
        }
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let title = view.annotation?.title else {
            return
        }
        self.loadProducts(storeName: title!, tableView: nil)
    }
    
    //TABLE VIEW
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.products.count
    }
    
    func setImage(url: String, cell: UITableViewCell) {
        var image: UIImage!
        let iws = ImageWebService()
        iws.getImage(url: url) { (bytes) in
            image = UIImage(data: bytes)
            cell.imageView?.image = image;
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath) as! ProductTableViewCell
        cell.nameLabel.text = self.products[indexPath.row].name
        self.setImage(url: self.products[indexPath.row].image, cell: cell)
        
        return cell
    }
    
    //SEARCHBAR
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchVal = searchBar.text else {
            return
        }
        DispatchQueue.main.async {
            self.clearMapView()
        }
        let sws = StoreWebService()
        sws.searchStore(searchValue: searchVal, completion: { (stores) in
            for store in stores {
                self.stores.append(store)
                self.setAnnotations(store: store)
            }
            if(self.stores.isEmpty){
                self.restoreMap()
            }
            self.mapView.addAnnotations(self.annotations)
            self.mapView.showAnnotations(self.mapView.annotations, animated: true)
        })
        self.view.endEditing(true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        print("text changed")
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        //self.restoreMap()
    }
}
