//
//  PersonTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.10.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>

@interface PersonTVC : UITableViewController
@property (nonatomic) ABRecordRef person;

@end
