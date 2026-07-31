//
//  PersonTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 14.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit
import Contacts

@objc(PersonTVC)
class PersonTVC: UITableViewController {
    @objc public var contactId: String? = nil;
    var sections: [String:[CNContact]] = [:];

    override func viewWillAppear(_ animated: Bool) {
        sections = [:];
        
        let keyDescriptors : [any CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                                                      CNContactThumbnailImageDataKey as CNKeyDescriptor,
                                                      CNContactImageDataAvailableKey as CNKeyDescriptor
        ];
        let contactsFetchRequest = CNContactFetchRequest(keysToFetch: keyDescriptors);
        let contactStore = CNContactStore();
            do {
                try contactStore.enumerateContacts(with: contactsFetchRequest) { contact, stop in
                    let name = CNContactFormatter.string(from: contact, style: .fullName);
                    if name != nil {
                        let sectionKey = name?.prefix(1).uppercased();
                        if sectionKey != nil {
                            var persons : [CNContact] = sections[sectionKey!] ?? [];
                            persons.append(contact);
                            sections[sectionKey!] = persons;
                        }
                    }
                }
            } catch {
            }
        
        for sectionKey in sections.keys {
            let persons = sections[sectionKey]?.sorted(by: { (lhs: CNContact, rhs: CNContact) -> Bool in
                let lhsName = CNContactFormatter.string(from: lhs, style: .fullName) ?? "";
                let rhsName = CNContactFormatter.string(from: rhs, style: .fullName) ?? "";
                return lhsName < rhsName;
            });
            sections[sectionKey] = persons;
        }
        
        tableView.sectionIndexMinimumDisplayRowCount = 8;
        
        super.viewWillAppear(animated);
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count;
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sections.keys.sorted();
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index;
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionKeys = sections.keys.sorted();
        return sectionKeys[section];
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionKeys = sections.keys.sorted();
        let sectionKey = sectionKeys[section];
        let persons : [CNContact]  = sections[sectionKey] ?? [];
        return persons.count;
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "person", for: indexPath) as UITableViewCell;
        let sectionKeys = sections.keys.sorted();
        let persons = sections[sectionKeys[indexPath.section]]!;
        let contact = persons[indexPath.row];
        cell.textLabel?.text = CNContactFormatter.string(from: contact, style: .fullName);
        if contact.imageDataAvailable {
            cell.imageView?.image = UIImage(data: contact.thumbnailImageData!);
        } else {
            cell.imageView?.image = UIImage(named: "icon40");
        }
        return cell;
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if sender is UITableViewCell {
            let cell = sender as? UITableViewCell;
            let indexPath = tableView.indexPath(for: cell!)!;
            if segue.identifier == "setPerson:" {
                let sectionKeys = sections.keys.sorted();
                let persons = sections[sectionKeys[indexPath.section]]!;
                let contact = persons[indexPath.row];
                contactId = contact.identifier;
            }
        } else {
            contactId = nil;
        }
    }
}
