//
//  SettingsTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 24.02.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(SettingsTVC)
class SettingsTVC: UITableViewController, UIDocumentInteractionControllerDelegate, UITextFieldDelegate {
    @IBOutlet weak var UImodeSwitch: UISegmentedControl!
    
    @IBOutlet weak var UItrackerid: UITextField!
    @IBOutlet weak var UIclientPKCS: UITextField!
    @IBOutlet weak var UIpassphrase: UITextField!
    @IBOutlet weak var UIDeviceID: UITextField!
    @IBOutlet weak var UIHost: UITextField!
    @IBOutlet weak var UIUserID: UITextField!
    @IBOutlet weak var UIPassword: UITextField!
    @IBOutlet weak var UIPort: UITextField!
    @IBOutlet weak var UIproto: UITextField!
    @IBOutlet weak var UIkeepAlive: UITextField!
    @IBOutlet weak var UIsecret: UITextField!
    @IBOutlet weak var UIurl: UITextField!
    @IBOutlet weak var UIhttpHeaders: UITextField!
    @IBOutlet weak var UIOSMTemplate: UITextField!
    @IBOutlet weak var UIOSMCopyright: UITextField!
    @IBOutlet weak var UIignoreStaleLocations: UITextField!
    @IBOutlet weak var UIignoreInaccurateLocations: UITextField!
    @IBOutlet weak var UIsubTopic: UITextField!
    @IBOutlet weak var UIpubTopicBase: UITextField!
    @IBOutlet weak var UIlocatorDisplacement: UITextField!
    @IBOutlet weak var UIlocatorInterval: UITextField!
    @IBOutlet weak var UIpositions: UITextField!
    @IBOutlet weak var UIdays: UITextField!
    @IBOutlet weak var UImaxHistory: UITextField!
    @IBOutlet weak var UIsubQos: UITextField!
    @IBOutlet weak var UIpubQos: UITextField!
    @IBOutlet weak var UImonitoring: UITextField!
    @IBOutlet weak var UIclientId: UITextField!
    @IBOutlet weak var UIdowngrade: UITextField!
    @IBOutlet weak var UIadapt: UITextField!
    
    @IBOutlet weak var UIallowUntrustedCertificates: UISwitch!
    @IBOutlet weak var UIUsePassword: UISwitch!
    @IBOutlet weak var UITLS: UISwitch!
    @IBOutlet weak var UIWS: UISwitch!
    @IBOutlet weak var UIAuth: UISwitch!
    @IBOutlet weak var UIextendedData: UISwitch!
    @IBOutlet weak var UIranging: UISwitch!
    @IBOutlet weak var UIlocked: UISwitch!
    @IBOutlet weak var UIsub: UISwitch!
    @IBOutlet weak var UIcleanSession: UISwitch!
    @IBOutlet weak var UIpubRetain: UISwitch!
    
    @IBOutlet weak var UIcmd: UISwitch!
    @IBOutlet weak var UIallowRemoteLocation: UISwitch!
    @IBOutlet weak var UIremoteConfiguration: UISwitch!
    @IBOutlet weak var UIuriConfiguration: UISwitch!
    @IBOutlet weak var UIintentAuthKey: UITextField!
    @IBOutlet weak var UIintents: UISwitch!
    
    @IBOutlet weak var UITLSCell: UITableViewCell!
    @IBOutlet weak var UIclientPKCSCell: UITableViewCell!

    @IBOutlet weak var UITLSTrash: UIButton!
    @IBOutlet weak var UIexport: UIButton!
    @IBOutlet weak var UIexportWaypoints: UIButton!
    @IBOutlet weak var UIpublish: UIButton!

    @IBOutlet weak var createCardButton: UIButton!
    @IBOutlet weak var toursButton: UIButton!
    
    @IBOutlet weak var UIeffectivePubTopic: UILabel!
    @IBOutlet weak var UIeffectiveSubTopic: UILabel!
    @IBOutlet weak var UIeffectiveClientId: UILabel!
    @IBOutlet weak var UIeffectiveTid: UILabel!
    @IBOutlet weak var UIeffectiveDeviceId: UILabel!

    var warningShown = false;
    var dic: UIDocumentInteractionController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        UItrackerid?.delegate = self;
        UIclientPKCS?.delegate = self;
        UIpassphrase?.delegate = self;
        UIDeviceID?.delegate = self;
        UIHost?.delegate = self;
        UIUserID?.delegate = self;
        UIPassword?.delegate = self;
        UIPort?.delegate = self;
        UIproto?.delegate = self;
        UIkeepAlive?.delegate = self;
        UIsecret?.delegate = self;
        UIurl?.delegate = self;
        UIhttpHeaders?.delegate = self;
        UIOSMTemplate?.delegate = self;
        UIOSMCopyright?.delegate = self;
        UIignoreStaleLocations?.delegate = self;
        UIignoreInaccurateLocations?.delegate = self;
        UIsubTopic?.delegate = self;
        UIpubTopicBase?.delegate = self;
        UIlocatorDisplacement?.delegate = self;
        UIlocatorInterval?.delegate = self;
        UIpositions?.delegate = self;
        UIdays?.delegate = self;
        UImaxHistory?.delegate = self;
        UIsubQos?.delegate = self;
        UIpubQos?.delegate = self;
        UImonitoring?.delegate = self;
        UIclientId?.delegate = self;
        UIdowngrade?.delegate = self;
        UIadapt?.delegate = self;

        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.addObserver(self, forKeyPath: "configLoad", options: [.initial, .new], context: nil);
        
        let lm = LocationManager.sharedInstance();
        lm.addObserver(self, forKeyPath: "monitoring", options: [.initial, .new], context: nil);
        
        updated();
        warningShown = false;
    }
    override func viewWillDisappear(_ animated: Bool) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.removeObserver(self, forKeyPath: "configLoad");
    
        let lm = LocationManager.sharedInstance();
        lm.removeObserver(self, forKeyPath: "monitoring");
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "reload"), object: nil);
        reconnect();
        super.viewWillDisappear(animated);
    }
    
    override func observeValue(forKeyPath keyPath: String?, of _: Any?, change: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "configLoad" {
            DispatchQueue.main.async {
                self.updated();
            }
        }
        if keyPath == "monitoring" {
            DispatchQueue.main.async {
                self.updated();
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        return true;
    }
    
    func updateValues() -> ()  {
        let moc = CoreData.sharedInstance().mainMOC;
        
        if UIDeviceID != nil {
            Settings.setString(UIDeviceID.text as? NSObject,
                               forKey: "deviceid_preference",
                               inMOC: moc);
        }
        
        if UIclientPKCS != nil {
            Settings.setString(UIclientPKCS.text as? NSObject,
                               forKey: "clientpkcs",
                               inMOC: moc);
        }
        
        if UIpassphrase != nil {
            Settings.setString(UIpassphrase.text as? NSObject,
                               forKey: "passphrase",
                               inMOC: moc);
        }

        if UIallowUntrustedCertificates != nil {
            Settings.setBool(UIallowUntrustedCertificates.isOn,
                             forKey: "allowinvalidcerts",
                             inMOC: moc);
        }

        if UItrackerid != nil {
            Settings.setString(UItrackerid.text as? NSObject,
                               forKey: "trackerid_preference",
                               inMOC: moc);
        }

        if UIHost != nil {
            Settings.setString(UIHost.text as? NSObject,
                               forKey: "host_preference",
                               inMOC: moc);
        }

        if UIclientId != nil {
            Settings.setString(UIclientId.text as? NSObject,
                               forKey: "clientid_preference",
                               inMOC: moc);
        }
        
        if UIpubTopicBase != nil {
            Settings.setString(UIpubTopicBase.text as? NSObject,
                               forKey: "topic_preference",
                               inMOC: moc);
        }

        if UIsubTopic != nil {
            Settings.setString(UIsubTopic.text as? NSObject,
                               forKey: "subscription_preference",
                               inMOC: moc);
        }

        if UIUserID != nil {
            Settings.setString(UIUserID.text as? NSObject,
                               forKey: "user_preference",
                               inMOC: moc);
        }

        if UIPassword != nil {
            Settings.setString(UIPassword.text as? NSObject,
                               forKey: "pass_preference",
                               inMOC: moc);
        }
        
        if UIUsePassword != nil {
            Settings.setBool(UIUsePassword.isOn,
                             forKey: "usepassword_preference",
                             inMOC: moc);
        }

        if UIsecret != nil {
            Settings.setString(UIsecret.text as? NSObject,
                               forKey: "secret_preference",
                               inMOC: moc);
        }

        if UIPort != nil {
            Settings.setString(UIPort.text as? NSObject,
                               forKey: "port_preference",
                               inMOC: moc);
        }

        if UIignoreStaleLocations != nil {
            Settings.setString(UIignoreStaleLocations.text as? NSObject,
                               forKey: "ignorestalelocations_preference",
                               inMOC: moc);
        }

        if UIlocatorDisplacement != nil {
            Settings.setString(UIlocatorDisplacement.text as? NSObject,
                               forKey: "mindist_preference",
                               inMOC: moc);
            LocationManager.sharedInstance().minTime = Settings.double(forKey: "mindist_preference",
                                                                       inMOC: moc);
        }

        if UIlocatorInterval != nil {
            Settings.setString(UIlocatorInterval.text as? NSObject,
                               forKey: "mintime_preference",
                               inMOC: moc);
            LocationManager.sharedInstance().minTime = Settings.double(forKey: "mintime_preference",
                                                                       inMOC: moc);
        }
        
        if UIpositions != nil {
            Settings.setString(UIpositions.text as? NSObject,
                               forKey: "positions_preference",
                               inMOC: moc);
        }

        if UIdays != nil {
            Settings.setString(UIdays.text as? NSObject,
                               forKey: "days_preference",
                               inMOC: moc);
        }

        if UImaxHistory != nil {
            Settings.setString(UImaxHistory.text as? NSObject,
                               forKey: "maxhistory_preference",
                               inMOC: moc);
        }

        if UIsubQos != nil {
            Settings.setString(UIsubQos.text as? NSObject,
                               forKey: "subscriptionqos_preference",
                               inMOC: moc);
        }

        if UIpubQos != nil {
            Settings.setString(UIpubQos.text as? NSObject,
                               forKey: "qos_preference",
                               inMOC: moc);
        }
        
        if UIkeepAlive != nil {
            Settings.setString(UIkeepAlive.text as? NSObject,
                               forKey: "keepalive_preference",
                               inMOC: moc);
        }
        
        if UImonitoring != nil {
            if UImonitoring.text != nil {
                let string = UImonitoring.text! as NSString;
                LocationManager.sharedInstance().monitoring = LocationMonitoring(rawValue: string.integerValue) ?? .manual;
                UserDefaults.standard.set(false, forKey: "downgraded");
                UserDefaults.standard.set(false, forKey: "adapted");
                Settings.setString(UImonitoring.text as? NSObject,
                                   forKey: "monitoring_preference",
                                   inMOC: moc);
            }
        }

        if UIdowngrade != nil {
            Settings.setString(UIdowngrade.text as? NSObject,
                               forKey: "downgrade_preference",
                               inMOC: moc);
        }

        if UIadapt != nil {
            Settings.setString(UIadapt.text as? NSObject,
                               forKey: "adapt_preference",
                               inMOC: moc);
        }

        if UIignoreInaccurateLocations != nil {
            Settings.setString(UIignoreInaccurateLocations.text as? NSObject,
                               forKey: "ignoreinaccuratelocations_preference",
                               inMOC: moc);
        }
        
        if UITLS != nil {
            Settings.setBool(UITLS.isOn,
                             forKey: "tls_preference",
                             inMOC: moc);
        }

        if UIWS != nil {
            Settings.setBool(UIWS.isOn,
                             forKey: "ws_preference",
                             inMOC: moc);
        }

        if UIAuth != nil {
            Settings.setBool(UIAuth.isOn,
                             forKey: "auth_preference",
                             inMOC: moc);
        }

        if UIranging != nil {
            Settings.setBool(UIranging.isOn,
                             forKey: "ranging_preference",
                             inMOC: moc);
        }

        if UIextendedData != nil {
            Settings.setBool(UIextendedData.isOn,
                             forKey: "extendeddata_preference",
                             inMOC: moc);
        }

        if UIlocked != nil {
            Settings.setBool(UIlocked.isOn,
                             forKey: "locked",
                             inMOC: moc);
        }

        if UIsub != nil {
            Settings.setBool(UIsub.isOn,
                             forKey: "sub_preference",
                             inMOC: moc);
        }

        if UIcmd != nil {
            Settings.setBool(UIcmd.isOn,
                             forKey: "cmd_preference",
                             inMOC: moc);
        }

        if UIpubRetain != nil {
            Settings.setBool(UIpubRetain.isOn,
                             forKey: "retain_preference",
                             inMOC: moc);
        }

        if UIcleanSession != nil {
            Settings.setBool(UIcleanSession.isOn,
                             forKey: "clean_preference",
                             inMOC: moc);
        }

        if UIallowRemoteLocation != nil {
            Settings.setBool(UIallowRemoteLocation.isOn,
                             forKey: "allowremotelocation_preference",
                             inMOC: moc);
        }

        if UIremoteConfiguration != nil {
            Settings.setBool(UIremoteConfiguration.isOn,
                             forKey: "allowremoteconfiguration_preference",
                             inMOC: moc);
        }

        if UIuriConfiguration != nil {
            Settings.setBool(UIuriConfiguration.isOn,
                             forKey: "allowConfigurationByURIAndConfigFile",
                             inMOC: moc);
        }

        if UIintents != nil {
            Settings.setBool(UIintents.isOn,
                             forKey: "allowIntentControl",
                             inMOC: moc);
        }

        if UIurl != nil {
            Settings.setString(UIurl.text as? NSObject,
                               forKey: "url_preference",
                               inMOC: moc);
        }

        if UIhttpHeaders != nil {
            Settings.setString(UIhttpHeaders.text as? NSObject,
                               forKey: "httpheaders_preference",
                               inMOC: moc);
        }

        if UIOSMTemplate != nil {
            Settings.setOSMTemplate(UIOSMTemplate.text,
                                    inMOC: moc);
        }

        if UIOSMCopyright != nil {
            Settings.setOSMCopyright(UIOSMCopyright.text,
                                     inMOC: moc);
        }
        
        // important to save UImode last. Otherwise parameters not valid in the old mode may get persisted
        if UImodeSwitch != nil {
            switch UImodeSwitch.selectedSegmentIndex {
            case 1:
                Settings.setMode(.CONNECTION_MODE_HTTP,
                                 inMOC: moc);
            case 0:
                Settings.setMode(.CONNECTION_MODE_MQTT,
                                 inMOC: moc);
            default:
                Settings.setMode(.CONNECTION_MODE_MQTT,
                                 inMOC: moc);
            }
            
        }
        CoreData.sharedInstance().sync(moc);
    }
    
    func updated() -> () {
        let moc = CoreData.sharedInstance().mainMOC;
        let locked = Settings.theLocked(inMOC: moc);
        
        title = NSLocalizedString("Settings",
                                  comment: "Settings screen title") + (locked ? " (" + NSLocalizedString("locked", comment: "indicates a locked configuration") + ")" : "");
        
        if createCardButton != nil {
            createCardButton.isEnabled = !locked;
        }
        
        if toursButton != nil {
            toursButton.isEnabled = !locked;
        }

        if UIDeviceID != nil {
            UIDeviceID.text = Settings.string(forKey: "deviceid_preference", inMOC: moc) as String?;
        }
        
        if UIeffectiveDeviceId != nil {
            UIeffectiveDeviceId.text = Settings.theDeviceId(inMOC: moc);
        }
        
        if UIclientPKCS != nil {
            UIclientPKCS.text = Settings.string(forKey: "clientpkcs", inMOC: moc) as String?;
            UIclientPKCS.isEnabled = !locked;
            UIclientPKCSCell.isUserInteractionEnabled = !locked;
            UIclientPKCSCell.accessoryType = !locked ? .detailDisclosureButton : .none;
        }
        
        if UIpassphrase != nil {
            UIpassphrase.text = Settings.string(forKey: "passphrase", inMOC: moc) as String?;
            if UIclientPKCS != nil {
                UIpassphrase.isEnabled = !locked &&
                UIclientPKCS.text != nil &&
                !UIclientPKCS.text!.isEmpty;
            }
        }
        
        if UIallowUntrustedCertificates != nil {
            UIallowUntrustedCertificates.isOn = Settings.bool(forKey: "allowinvalidcerts", inMOC: moc);
            UIallowUntrustedCertificates.isEnabled = !locked;
        }
        
        if UItrackerid != nil {
            UItrackerid.text = Settings.string(forKey: "trackerid_preference", inMOC: moc) as String?;
            UItrackerid.isEnabled = !locked;
        }

        if UIeffectiveTid != nil {
            UIeffectiveTid.text = Friend.effectiveTid(Settings.string(forKey:"trackerid_preference",
                                                                      inMOC: moc) ?? "",
                                                      device: Settings.theDeviceId(inMOC: moc));
        }

        if UIHost != nil {
            UIHost.text = Settings.string(forKey: "host_preference", inMOC: moc) as String?;
            UIHost.isEnabled = !locked;
        }

        if UIclientId != nil {
            UIclientId.text = Settings.string(forKey: "clientid_preference", inMOC: moc) as String?;
            UIclientId.isEnabled = !locked;
        }

        if UIeffectiveClientId != nil {
            UIeffectiveClientId.text = Settings.theClientId(inMOC: moc);
        }
        
        if UIsubTopic != nil {
            UIsubTopic.text = Settings.string(forKey: "subscription_preference", inMOC: moc) as String?;
            UIsubTopic.isEnabled = !locked;
        }

        if UIeffectiveSubTopic != nil {
            UIeffectiveSubTopic.text = Settings.theSubscriptions(inMOC: moc);
        }
        
        if UIpubTopicBase != nil {
            UIpubTopicBase.text = Settings.string(forKey: "topic_preference", inMOC: moc) as String?;
            UIpubTopicBase.isEnabled = !locked;
        }

        if UIeffectivePubTopic != nil {
            UIeffectivePubTopic.text = Settings.theGeneralTopic(inMOC: moc);
        }
        
        if UIUserID != nil {
            UIUserID.text = Settings.string(forKey: "user_preference", inMOC: moc) as String?;
            UIUserID.isEnabled = !locked;
        }

        if UIAuth != nil {
            UIAuth.isOn = Settings.bool(forKey: "auth_preference", inMOC: moc);
            UIAuth.isEnabled = !locked;
        }

        if UIUsePassword != nil {
            UIUsePassword.isOn = Settings.bool(forKey: "usepassword_preference", inMOC: moc);
            UIUsePassword.isEnabled = !locked;
            if UIAuth != nil {
                UIUsePassword.isEnabled = !locked && UIAuth.isOn;
            }
        }

        if UIPassword != nil {
            UIPassword.text = Settings.string(forKey: "pass_preference", inMOC: moc) as String?;
            UIPassword.isEnabled = !locked;
            if UIAuth != nil && UIUsePassword != nil {
                UIPassword.isEnabled = !locked && UIAuth.isOn && UIUsePassword.isOn;
            }
        }

        if UIsecret != nil {
            UIsecret.text = Settings.string(forKey: "secret_preference", inMOC: moc) as String?;
            UIsecret.isEnabled = !locked;
        }
        
        if UImodeSwitch != nil {
            let mode = Settings.theMode(inMOC: moc);
            switch mode {
            case ConnectionMode.CONNECTION_MODE_HTTP:
                UImodeSwitch.selectedSegmentIndex = 1;
            case ConnectionMode.CONNECTION_MODE_MQTT:
                UImodeSwitch.selectedSegmentIndex = 0;
            default:
                UImodeSwitch.selectedSegmentIndex = 0;
            }
            UImodeSwitch.isEnabled = !locked;
        }

        if UIPort != nil {
            UIPort.text = Settings.string(forKey: "port_preference", inMOC: moc) as String?;
            UIPort.isEnabled = !locked;
        }


        if UIproto != nil {
            UIproto.text = "\(Settings.int(forKey: "mqttProtocolLevel", inMOC: moc))";
            UIproto.isEnabled = !locked;
        }

        if UIignoreStaleLocations != nil {
            UIignoreStaleLocations.text = Settings.string(forKey: "ignorestalelocations_preference", inMOC: moc) as String?;
            UIignoreStaleLocations.isEnabled = !locked;
        }

        if UIkeepAlive != nil {
            UIkeepAlive.text = Settings.string(forKey: "keepalive_preference", inMOC: moc) as String?;
            UIkeepAlive.isEnabled = !locked;
        }

        if UIpubQos != nil {
            UIpubQos.text = "\(Settings.theQos(inMOC: moc).rawValue)";
            UIpubQos.isEnabled = !locked;
        }

        if UIsubQos != nil {
            UIsubQos.text = Settings.string(forKey: "subscriptionqos_preference", inMOC: moc) as String?;
            UIsubQos.isEnabled = !locked;
        }

        if UIpositions != nil {
            UIpositions.text = Settings.string(forKey: "positions_preference", inMOC: moc) as String?;
            UIpositions.isEnabled = !locked;
        }

        if UIdays != nil {
            UIdays.text = Settings.string(forKey: "days_preference", inMOC: moc) as String?;
            UIdays.isEnabled = !locked;
        }

        if UImaxHistory != nil {
            UImaxHistory.text = Settings.string(forKey: "maxhistory_preference", inMOC: moc) as String?;
            UImaxHistory.isEnabled = !locked;
        }

        if UIlocatorInterval != nil {
            UIlocatorInterval.text = Settings.string(forKey: "mintime_preference", inMOC: moc) as String?;
            UIlocatorInterval.isEnabled = !locked;
        }

        if UIlocatorDisplacement != nil {
            UIlocatorDisplacement.text = Settings.string(forKey: "mindist_preference", inMOC: moc) as String?;
            UIlocatorDisplacement.isEnabled = !locked;
        }

        if UImonitoring != nil {
            UImonitoring.text = Settings.string(forKey: "monitoring_preference", inMOC: moc) as String?;
            UImonitoring.isEnabled = !locked;
        }

        if UIdowngrade != nil {
            UIdowngrade.text = Settings.string(forKey: "downgrade_preference", inMOC: moc) as String?;
            UIdowngrade.isEnabled = !locked;
        }

        if UIadapt != nil {
            UIadapt.text = Settings.string(forKey: "adapt_preference", inMOC: moc) as String?;
            UIadapt.isEnabled = !locked;
        }

        if UIignoreInaccurateLocations != nil {
            UIignoreInaccurateLocations.text = Settings.string(forKey: "ignoreinaccuratelocations_preference", inMOC: moc) as String?;
            UIignoreInaccurateLocations.isEnabled = !locked;
        }

        if UITLS != nil {
            UITLS.isOn = Settings.bool(forKey: "tls_preference", inMOC: moc);
            UITLS.isEnabled = !locked;
        }

        if UIWS != nil {
            UIWS.isOn = Settings.bool(forKey: "ws_preference", inMOC: moc);
            UIWS.isEnabled = !locked;
        }

        if UIranging != nil {
            UIranging.isOn = Settings.bool(forKey: "ranging_preference", inMOC: moc);
            UIranging.isEnabled = !locked;
        }

        if UIextendedData != nil {
            UIextendedData.isOn = Settings.bool(forKey: "extendeddata_preference", inMOC: moc);
            UIextendedData.isEnabled = !locked;
        }

        if UIlocked != nil {
            UIlocked.isOn = Settings.theLocked(inMOC: moc);
            UIlocked.isEnabled = !locked;
        }

        if UIsub != nil {
            UIsub.isOn = Settings.bool(forKey: "sub_preference", inMOC: moc);
            UIsub.isEnabled = !locked;
        }

        if UIcmd != nil {
            UIcmd.isOn = Settings.bool(forKey: "cmd_preference", inMOC: moc);
            UIcmd.isEnabled = !locked;
        }

        if UIpubRetain != nil {
            UIpubRetain.isOn = Settings.bool(forKey: "retain_preference", inMOC: moc);
            UIpubRetain.isEnabled = !locked;
        }

        if UIcleanSession != nil {
            UIcleanSession.isOn = Settings.bool(forKey: "clean_preference", inMOC: moc);
            UIcleanSession.isEnabled = !locked;
        }

        if UIallowRemoteLocation != nil {
            UIallowRemoteLocation.isOn = Settings.theAllowRemoteLocation(inMOC: moc);
            UIallowRemoteLocation.isEnabled = !locked;
        }

        if UIremoteConfiguration != nil {
            UIremoteConfiguration.isOn = Settings.theAllowRemoteConfiguration(inMOC: moc);
            UIremoteConfiguration.isEnabled = !locked;
        }

        if UIuriConfiguration != nil {
            UIuriConfiguration.isOn = Settings.theallowConfigurationByURIAndConfigFile(inMOC: moc);
        }

        if UIintents != nil {
            UIintents.isOn = Settings.theAllowIntentControl(inMOC: moc);
        }
        
        if UIintentAuthKey != nil {
            UIintentAuthKey.text = Settings.theIntentAuthKey();
        }

        if UIurl != nil {
            UIurl.text = Settings.string(forKey: "url_preference", inMOC: moc) as String?;
            UIurl.isEnabled = !locked;
        }

        if UIOSMTemplate != nil {
            UIOSMTemplate.text = Settings.theOSMTemplate(moc) as String?;
            UIOSMTemplate.isEnabled = !locked;
        }

        if UIOSMCopyright != nil {
            UIOSMCopyright.text = Settings.theOSMCopyright(inMOC: moc) as String?;
            UIOSMCopyright.isEnabled = !locked;
        }

        if UIhttpHeaders != nil {
            UIhttpHeaders.text = Settings.string(forKey: "httpheaders_preference", inMOC: moc) as String?;
            UIhttpHeaders.isEnabled = !locked;
        }

        if UITLSCell != nil {
            if UITLS != nil {
                UITLSCell.accessoryType = Settings.bool(forKey: "tls_preference", inMOC: moc) ? .detailDisclosureButton : .none;
            }
        }
        
        if UITLSTrash != nil {
            UITLSTrash.isEnabled = !locked;
        }
        
        if tabBarController != nil && tabBarController!.isKind(of: TabBarController.self) {
            let tbc = tabBarController as! TabBarController;
            tbc.adjust();
        }
    }
    
    @IBAction func publishSettingsPressed(_ sender: UIButton) {
        updateValues();
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.dump();
    }
    
    @IBAction func publishWaypointsPressed(_ sender: UIButton) {
        updateValues();
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.waypoints();
    }
    
    @IBAction func exportPressed(_ sender: UIButton) {
        updateValues();
        do {
            let directoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true);
            let fileURL = directoryURL.appendingPathComponent("config.otrc");
            FileManager.default.createFile(atPath: fileURL.path, contents: Settings.toData(inMOC: CoreData.sharedInstance().mainMOC), attributes: nil);
            dic = UIDocumentInteractionController(url:fileURL as URL) ;
            dic?.delegate = self;
            dic?.presentOptionsMenu(from: UIexport.frame, in: UIexport, animated: true);

        } catch {
        }
    }
    
    @IBAction func exportWaypointsPressed(_ sender: UIButton) {
        updateValues();
        do {
            let directoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true);
            let fileURL = directoryURL.appendingPathComponent("config.otrw");
            FileManager.default.createFile(atPath: fileURL.path, contents: Settings.waypointsToData(inMOC: CoreData.sharedInstance().mainMOC), attributes: nil);
            dic = UIDocumentInteractionController(url:fileURL as URL) ;
            dic?.delegate = self;
            dic?.presentOptionsMenu(from: UIexportWaypoints.frame, in: UIexportWaypoints, animated: true);

        } catch {
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "setClientPKCS" {
            if segue.destination is CertificatesTVC {
                let cTVC = segue.destination as? CertificatesTVC;
                cTVC!.selectedFileName = Settings.string(forKey: "clientpkcs", inMOC: CoreData.sharedInstance().mainMOC) ?? "";
            }
        }
        
    }
    @IBAction func setNames(_ segue: UIStoryboardSegue) {
        if segue.source is CertificatesTVC {
            let cTVC = segue.source as? CertificatesTVC;
            let name = cTVC!.selectedFileName;
            Settings.setString(name as NSObject, forKey: "clientpkcs", inMOC: CoreData.sharedInstance().mainMOC);
            updated();
        }
    }
    
    @IBAction func setCard(_ segue: UIStoryboardSegue) {
        if segue.source is CreateCardTVC {
            let cTVC = segue.source as? CreateCardTVC;
            let name = cTVC!.name;
            let cardImage = cTVC!.cardImage;
            
            let moc = CoreData.sharedInstance().mainMOC;
            let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
            
            if name != nil && cardImage != nil {
                if cardImage!.image != nil && name!.text != nil {
                    let png = cardImage!.image!.pngData();
                    if png != nil {
                        let topic = Settings.theGeneralTopic(inMOC: moc) as String?;
                        if topic != nil {
                            let myself = Friend.existsFriend(withTopic: topic!, in: moc);
                            if myself != nil {
                                myself!.cardName = name!.text!;
                                myself!.cardImage = png;
                                let b64String = png!.base64EncodedString();
                                let json = [
                                    "_type": "card",
                                    "face": b64String,
                                    "name": name!.text!
                                ];
                                
                                var jsonData: Data? = nil;
                                do {
                                    jsonData = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys);
                                } catch {
                                }
                                if jsonData != nil  && ad.connection != nil {
                                    ad.connection!.send(jsonData,
                                                        topic: Settings.theGeneralTopic(inMOC: moc) + "/info",
                                                        topicAlias: NSNumber(value: 0),
                                                        qos: Settings.theQos(inMOC: moc),
                                                        retain: true);
                                    
                                    NavigationController.alert(title: NSLocalizedString("Card",
                                                                                        comment: "Header of an alert message regarding a card"),
                                                               message: NSLocalizedString("set and sent to backend",
                                                                                          comment: "content of an alert message regarding card"));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func touchedOutsideText(_ sender: UITapGestureRecognizer) {
        UItrackerid?.resignFirstResponder();
        UIclientPKCS?.resignFirstResponder();
        UIpassphrase?.resignFirstResponder();
        UIDeviceID?.resignFirstResponder();
        UIHost?.resignFirstResponder();
        UIUserID?.resignFirstResponder();
        UIPassword?.resignFirstResponder();
        UIPort?.resignFirstResponder();
        UIproto?.resignFirstResponder();
        UIkeepAlive?.resignFirstResponder();
        UIsecret?.resignFirstResponder();
        UIurl?.resignFirstResponder();
        UIhttpHeaders?.resignFirstResponder();
        UIOSMTemplate?.resignFirstResponder();
        UIOSMCopyright?.resignFirstResponder();
        UIignoreStaleLocations?.resignFirstResponder();
        UIignoreInaccurateLocations?.resignFirstResponder();
        UIsubTopic?.resignFirstResponder();
        UIpubTopicBase?.resignFirstResponder();
        UIlocatorDisplacement?.resignFirstResponder();
        UIlocatorInterval?.resignFirstResponder();
        UIpositions?.resignFirstResponder();
        UIdays?.resignFirstResponder();
        UImaxHistory?.resignFirstResponder();
        UIsubQos?.resignFirstResponder();
        UIpubQos?.resignFirstResponder();
        UImonitoring?.resignFirstResponder();
        UIclientId?.resignFirstResponder();
        UIdowngrade?.resignFirstResponder();
        UIadapt?.resignFirstResponder();
    }
    
    @IBAction func protocolChanged(_ sender: UITextField) {
        if sender.text != nil {
            if sender.text!.count > 0 {
                let proto = sender.text!.codingKey.intValue;
                if proto == nil || (
                    proto! != MQTTProtocolVersion.version31.rawValue &&
                    proto! != MQTTProtocolVersion.version311.rawValue &&
                    proto! != MQTTProtocolVersion.version50.rawValue) {
                    let ac = UIAlertController(title:NSLocalizedString("Protocol invalid",
                                                                       comment:"Alert header regarding protocol input"),
                                               message: NSLocalizedString("Protocol may be 3 for MQTT V3.1 or 4 for MQTT V3.1.1 or 5 for MQTT V5",
                                                                          comment: "Alert content regarding protocol input"),
                                               preferredStyle: .alert);
                    let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                                    comment: "Continue button title"),
                                           style: .destructive) { _ in
                        sender.text = "\(Settings.int(forKey: "mqttProtocolLevel", inMOC: CoreData.sharedInstance().mainMOC))";
                    };
                    ac.addAction(ok);
                    present(ac, animated: true);
                    return;
               }
                Settings.setInt(Int32(proto!), forKey: "mqttProtocolLevel", inMOC: CoreData.sharedInstance().mainMOC);
                updated();
            }
        }
    }
    
    @IBAction func modeSwitchChanged(_ sender: UISegmentedControl){
        changeWarning();
    }
    
    @IBAction func tidChanged(_ sender: UITextField) {
        let invalidTrackerId = NSLocalizedString("TrackerID invalid", comment: "Alert header regarding TrackerID input");
        if sender.text != nil {
            if sender.text!.count > 2 {
                let ac = UIAlertController(title: invalidTrackerId,
                                           message: NSLocalizedString("TrackerID may be empty or up to 2 characters long",
                                                                      comment: "Alert content regarding TrackerID input"),
                                           preferredStyle: .alert);
                let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                                comment: "Continue button title"),
                                       style: .destructive) { _ in
                    sender.text = Settings.string(forKey: "trackerid_preference", inMOC: CoreData.sharedInstance().mainMOC);
                };
                ac.addAction(ok);
                present(ac, animated: true);
                return;
            }
        }
        for c in sender.text! {
            if !c.isLetter && !c.isNumber {
                let ac = UIAlertController(title: invalidTrackerId,
                                           message: NSLocalizedString("TrackerID may contain alphanumeric characters only",
                                                                      comment: "Alert content regarding TrackerID input"),
                                           preferredStyle: .alert);
                let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                                comment: "Continue button title"),
                                       style: .destructive) { _ in
                    sender.text = Settings.string(forKey: "trackerid_preference", inMOC: CoreData.sharedInstance().mainMOC);
                };
                ac.addAction(ok);
                present(ac, animated: true);
                return;
            }
        }
        updateValues();
        updated();
    }
    
    @IBAction func deviceIdChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func hostChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func portChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func wsChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }
    
    @IBAction func tlsChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }
    
    @IBAction func useridChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func authChanged(_ sender: UISwitch) {
        changeWarning();
    }

    @IBAction func passwordChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func usePasswordChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }
    
    @IBAction func secretChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func urlChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func subTopicChanged(_ sender: UITextField) {
        changeWarning();
    }

    @IBAction func clientIdChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func pubTopicChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func willTopicChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func ignoreStaleLocationsChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func ignoreInaccurateLocationsChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func locatorDisplacementChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func locatorIntervalChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func positionsChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func daysChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func maxHistoryChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func subQosChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func keepAliveChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func pubQosChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func monitoringChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func downgradeChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }

    @IBAction func adaptChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func httpHeadersChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func osmTemplateChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func osmCopyrightChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func clientPKCSChanged(_ sender: UITextField) {
        changeWarning();
    }
    
    @IBAction func passphraseChanged(_ sender: UITextField) {
        updateValues();
        updated();
    }
    
    @IBAction func rangingChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }

    @IBAction func extendedDataChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }

    @IBAction func lockedChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }

    @IBAction func subChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }

    @IBAction func pubRetainChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }

    @IBAction func cleanSessionChanged(_ sender: UISwitch) {
        changeWarning();
    }

    // Remote Control Section
    @IBAction func cmdChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }

   @IBAction func allowRemoteLocationChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }
    
    @IBAction func remoteConfigurationChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }
    
    @IBAction func uriConfigurationChanged(_ sender: UISwitch) {
        if sender.isOn {
            configWarning();
        } else {
            updateValues();
            updated();
        }
    }
    
    @IBAction func intentsChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let tableViewCell = tableView.cellForRow(at: indexPath);
        if tableViewCell?.tag == 99 {
            UIPasteboard.general.string = Settings.theIntentAuthKey();
            NavigationController.alert(title: NSLocalizedString("Clipboard",
                                                                comment: "Clipboard"),
                                       message: NSLocalizedString("Intent auth key copied to clipboard",
                                                                  comment: "Intent auth key copied to clipboard"),
                                       dismissAfter: 1.0);
        }
        return nil;
    }
    
    func configWarning() {
        let ac = UIAlertController(title:NSLocalizedString("Allow external configuration?",
                                                           comment:"Alert header for external configuration change warning"),
                                   message: NSLocalizedString("Any owntracks: URL or config file can completely reconfigure this app, including change the backend, credentials, and tracking settings. Only enable this if you trust all sources that can send such URLs to this device.",
                                                              comment: "Alert content for external configuration change warning"),
                                   preferredStyle: .alert);
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel",
                                                            comment:"Cancel button title"),
                                   style: .cancel) { _ in
            self.updated();
        }
        let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                        comment: "Continue button title"),
                               style: .destructive) { _ in
            let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
            ad.terminateSession();
            self.updateValues();
            self.updated();
        }
        ac.addAction(cancel);
        ac.addAction(ok);
        present(ac, animated: true);
    }

    
    @IBAction func allowUntrustedCertificatesChanged(_ sender: UISwitch) {
        updateValues();
        updated();
    }

    @IBAction func trashPressed(_ sender: UIBarButtonItem) {
        if UIclientPKCS != nil {
            UIclientPKCS.text = "";
        }

        if UIpassphrase != nil {
            UIpassphrase.text = "";
        }

        updateValues();
    }

    func changeWarning() {
        if warningShown {
            let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
            ad.terminateSession();
            updateValues();
            updated();
        } else {
            let ac = UIAlertController(title:NSLocalizedString("Connection change",
                                                                comment:"Alert header for connection change warning"),
                                       message: NSLocalizedString("Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before.",
                                                                  comment: "Alert content for connection change warning"),
                                       preferredStyle: .alert);
            let cancel = UIAlertAction(title: NSLocalizedString("Cancel",
                                                                comment:"Cancel button title"),
                                       style: .cancel) { _ in
                self.updated();
                self.warningShown = false;
            }
            let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                            comment: "Continue button title"),
                                   style: .destructive) { _ in
                let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
                ad.terminateSession();
                self.updateValues();
                self.updated();
                self.warningShown = true;
            }
            ac.addAction(cancel);
            ac.addAction(ok);
            present(ac, animated: true);
        }
    }
    
    func reconnect() {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.connectionOff();
        ad.syncProcessing();
        updateValues();
        ad.reconnect();
    }
}
