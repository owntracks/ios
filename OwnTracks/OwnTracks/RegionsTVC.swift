//
//  RegionsTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 26.02.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

@objc(RegionsTVC)

class RegionsTVC: OwnTracksEditFetchTVC {
    private var frc : NSFetchedResultsController<Region>?;
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { _ in
            self.reset();
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        reset();
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var indexPath : IndexPath? = nil;
        
        if sender is UITableViewCell {
            indexPath = tableView.indexPath(for: sender as! UITableViewCell);
            if indexPath != nil {
                if segue.identifier == "setRegion:" {
                    let region = frc?.object(at: indexPath!);
                    if segue.destination is RegionTVC {
                        let regionTVC = segue.destination as! RegionTVC;
                        regionTVC.region = region;
                        regionTVC.editAllowed = NSNumber(booleanLiteral: true);
                    }
                }
            }
        }
        
        if segue.identifier == "newRegion:" {
            let moc = CoreData.sharedInstance().mainMOC;
            let topic = Settings.theGeneralTopic(inMOC: moc);
            let myself = Friend.existsFriend(withTopic: topic, in: moc);
            if myself != nil {
                let location = LocationManager.sharedInstance().location;
                let rid = Region.newRid();
                let newRegion = OwnTracking.sharedInstance().addRegion(for: rid,
                                                                       friend: myself!,
                                                                       name: "Here-\(rid)",
                                                                       tst: NSDate.now,
                                                                       uuid: nil,
                                                                       major: 0,
                                                                       minor: 0,
                                                                       radius: 0,
                                                                       lat: location.coordinate.latitude,
                                                                       lon: location.coordinate.longitude);
                tableView.reloadData();
                if segue.destination is RegionTVC {
                    let regionTVC = segue.destination as! RegionTVC;
                    regionTVC.region = newRegion;
                    regionTVC.editAllowed = NSNumber(booleanLiteral: true);
                }
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if frc != nil && frc!.sections != nil {
            if frc!.sections!.count == 0 {
                empty();
                return 0;
            } else {
                var numberOfObjects: Int = 0;
                
                for section in frc!.sections!.indices {
                    let sectionInfo = frc!.sections![section];
                    numberOfObjects += sectionInfo.numberOfObjects;
                }
                if numberOfObjects > 0 {
                    nonempty();
                } else {
                    empty();
                }
                return frc!.sections!.count;
            }
        } else {
            empty();
            return 0;
        }
    }
        
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if frc != nil && frc!.sections != nil {
            let sectionInfo = frc!.sections![section];
            return sectionInfo.numberOfObjects;
        }
        return 0;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "region", for: indexPath);
        let region = frc?.object(at: indexPath);
        if region != nil {
            cell.textLabel?.text = region!.name;
            cell.detailTextLabel?.text = region!.subtitle;
            
            let clRegion = region!.cLregion;
            if clRegion != nil {
                if LocationManager.sharedInstance().monitoredRegion(clRegion!.identifier) {
                    if clRegion!.isKind(of: CLCircularRegion.self) {
                        if LocationManager.sharedInstance().insideCircularRegion(clRegion!.identifier) {
                            cell.imageView?.image = UIImage(named: "RegionHot");
                        } else {
                            cell.imageView?.image = UIImage(named: "RegionCold");
                        }
                    } else if clRegion!.isKind(of: CLBeaconRegion.self) {
                        if LocationManager.sharedInstance().insideBeaconRegion(clRegion!.identifier) {
                            cell.imageView?.image = UIImage(named: "iBeaconHot");
                        } else {
                            cell.imageView?.image = UIImage(named: "iBeaconCold");
                        }
                    } else {
                        cell.imageView?.image = UIImage(systemName: "exclamationmark.triangle");
                    }
                } else {
                    cell.imageView?.image = UIImage(systemName: "exclamationmark.triangle")
                }
            } else {
                cell.imageView?.image = UIImage(systemName: "exclamationmark.triangle");
            }

        } else {
            cell.textLabel?.text = "no region";
        }
        return cell;
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true;
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = frc?.managedObjectContext;
            if context != nil {
                let region = frc?.object(at: indexPath);
                if region != nil {
                    OwnTracking.sharedInstance().remove(region!, context: context);
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let region = frc?.object(at: indexPath);
        let tbc = tabBarController;
        let vcs = tbc?.viewControllers;
        let nc = vcs?[0];
        if nc != nil && nc is NavigationController {
            let navigationController = nc as! NavigationController;
            let vc = navigationController.topViewController;
            if vc != nil && vc is ViewController {
                let viewController = vc as! ViewController;
                viewController.setCenter(annotation: region!);
            }
            tabBarController?.selectedIndex = 0;
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false;
    }

    private func reset() {
        let moc = CoreData.sharedInstance().mainMOC;
        let topic = Settings.theGeneralTopic(inMOC: moc);
        let myself = Friend.existsFriend(withTopic: topic, in: moc);
        if myself != nil {
            let fr = NSFetchRequest<Region>();
            let e = NSEntityDescription.entity(forEntityName: "Region", in: moc);
            fr.entity = e;
            fr.predicate = NSPredicate(format: "belongsTo = %@", myself!);
            fr.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)];
            self.frc = NSFetchedResultsController(fetchRequest: fr,
                                                  managedObjectContext: moc,
                                                  sectionNameKeyPath: nil,
                                                  cacheName: nil);
            self.frc?.delegate = self;
            do {
                try self.frc?.performFetch();
            } catch {
                print("fetch failed");
            }
        } else {
            print("myself == nil");
        }
        if tableView != nil {
            tableView.reloadData();
        }
    }
}
