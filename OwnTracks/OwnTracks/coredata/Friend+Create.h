//
//  Friend+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Friend.h"
#import <AddressBook/AddressBook.h>

@interface Friend (Create)
+ (ABAddressBookRef)theABRef;

+ (Friend *)friendWithTopic:(NSString *)topic
     inManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSString *)nameOfPerson:(ABRecordRef)record;
+ (NSData *)imageDataOfPerson:(ABRecordRef)record;


- (void)linkToAB:(ABRecordRef)record;
- (NSString *)name;
- (NSData *)image;

@end
