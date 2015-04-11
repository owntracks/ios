//
//  Friend+Create.m
//  OwnTracks   
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "Friend+Create.h"
#import "Location+Create.h"
#import "OwnTracksAppDelegate.h"

@implementation Friend (Create)

+ (ABAddressBookRef)theABRef
{
    static ABAddressBookRef ab = nil;
    
    if (!ab) {
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if (status == kABAuthorizationStatusAuthorized || status == kABAuthorizationStatusNotDetermined) {
            CFErrorRef error;
            ab = ABAddressBookCreateWithOptions(NULL, &error);
        }
    }
    
    return ab;
}

+ (Friend *)existsFriendWithTopic:(NSString *)topic
     inManagedObjectContext:(NSManagedObjectContext *)context

{
    Friend *friend = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES]];
    request.predicate = [NSPredicate predicateWithFormat:@"topic = %@", topic];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || [matches count] > 1) {
        // handle error
    } else {
        if ([matches count]) {
            friend = [matches lastObject];
        }
    }
    
    return friend;
}

+ (NSArray *)allFriendsInManagedObjectContext:(NSManagedObjectContext *)context {    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES]];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    return matches;
}

+ (Friend *)friendWithTopic:(NSString *)topic
                        tid:(NSString *)tid
     inManagedObjectContext:(NSManagedObjectContext *)context

{
    Friend *friend = [self existsFriendWithTopic:topic inManagedObjectContext:context];
    
    if (!friend) {
        friend = [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:context];
        
        friend.topic = topic;
        
        friend.abRecordId = @(kABRecordInvalidID);
        friend.hasLocations = [[NSSet alloc] init];
    }
    
    friend.tid = tid;

    return friend;
}

- (NSString *)name
{
    ABRecordRef record = [self recordOfFriend];
    NSString *abName = [Friend nameOfPerson:record];
    if (abName) {
        return abName;
    } else {
        return self.cardName;
    }
}

+ (NSString *)nameOfPerson:(ABRecordRef)record
{
    NSString *name = nil;
    
    if (record) {
        name =  CFBridgingRelease(ABRecordCopyValue(record, kABPersonNicknameProperty));
        if (!name) {
            name = CFBridgingRelease(ABRecordCopyCompositeName(record));
        }
    }
    return name;
}


- (NSData *)image
{
    NSData *data = nil;
    ABRecordRef record = [self recordOfFriend];
    if (record) {
        data = [Friend imageDataOfPerson:record];
        CFRelease(record);
    }
    if (data) {
        return data;
    } else {
        return self.cardImage;
    }
}

+ (NSData *)imageDataOfPerson:(ABRecordRef)record
{
    NSData *imageData = nil;
    
    if (record) {
        if (ABPersonHasImageData(record)) {
            CFDataRef ir = ABPersonCopyImageDataWithFormat(record, kABPersonImageFormatThumbnail);
            imageData = CFBridgingRelease(ir);
        }
    }
    return imageData;
}

- (ABRecordRef)recordOfFriend
{
    ABRecordRef record = NULL;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if ([delegate.settings boolForKey:@"ab_preference"]) {
        record = recordWithTopic((__bridge CFStringRef)(self.topic));
    } else {
        if ([self.abRecordId intValue] != kABRecordInvalidID) {
            ABAddressBookRef ab = [Friend theABRef];
            if (ab) {
                record = ABAddressBookGetPersonWithRecordID(ab, [self.abRecordId intValue]);
                if (record) {
                    CFRetain(record);
                }
            }
        }
    }
    
    return record;
}

- (void)linkToAB:(ABRecordRef)record
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if ([delegate.settings boolForKey:@"ab_preference"]) {
        ABRecordRef oldrecord = recordWithTopic((__bridge CFStringRef)(self.topic));
        
        if (oldrecord) {
            [self ABsetTopic:nil record:oldrecord];
            CFRelease(oldrecord);
        }
        
        if (record) {
            [self ABsetTopic:self.topic record:record];
        }
        
    } else {
        ABRecordID abRecordID = ABRecordGetRecordID(record);
        self.abRecordId = @(abRecordID);
    }
    
    // make sure all locations are updated so all views get updated
    for (Location *location in self.hasLocations) {
        location.belongsTo = self;
    }
}

#define RELATION_NAME CFSTR("OwnTracks")

ABRecordRef recordWithTopic(CFStringRef topic)
{
    ABRecordRef theRecord = NULL;
    ABAddressBookRef ab = [Friend theABRef];
    if (ab) {
        CFArrayRef records = ABAddressBookCopyArrayOfAllPeople(ab);
        
        if (records) {
            for (CFIndex i = 0; i < CFArrayGetCount(records); i++) {
                ABRecordRef record = CFArrayGetValueAtIndex(records, i);
                
                ABMultiValueRef relations = ABRecordCopyValue(record, kABPersonRelatedNamesProperty);
                if (relations) {
                    CFIndex relationsCount = ABMultiValueGetCount(relations);
                    
                    for (CFIndex k = 0 ; k < relationsCount ; k++) {
                        CFStringRef label = ABMultiValueCopyLabelAtIndex(relations, k);
                        CFStringRef value = ABMultiValueCopyValueAtIndex(relations, k);
                        if(CFStringCompare(label, RELATION_NAME, kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
                            if(CFStringCompare(value, topic, kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
                                theRecord = record;
                                CFRelease(label);
                                CFRelease(value);
                                break;
                            }
                        }
                        CFRelease(label);
                        CFRelease(value);
                    }
                    CFRelease(relations);
                }
                if (theRecord) {
                    CFRetain(theRecord);
                    break;
                }
            }
            CFRelease(records);
        }
    }
    return theRecord;
}

- (void)ABsetTopic:(NSString *)topic record:(ABRecordRef)record
{
    CFErrorRef errorRef;

    ABMutableMultiValueRef relationsRW;
    
    ABMultiValueRef relationsRO = ABRecordCopyValue(record, kABPersonRelatedNamesProperty);
    
    if (relationsRO) {
        relationsRW = ABMultiValueCreateMutableCopy(relationsRO);
        CFRelease(relationsRO);
    } else {
        relationsRW = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    }
    
    CFIndex relationsCount = ABMultiValueGetCount(relationsRW);
    CFIndex i;
    
    for (i = 0 ; i < relationsCount ; i++) {
        CFStringRef label = ABMultiValueCopyLabelAtIndex(relationsRW, i);
        if(CFStringCompare(label, RELATION_NAME, kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
            if (topic) {
                if (!ABMultiValueReplaceValueAtIndex(relationsRW, (__bridge CFTypeRef)(topic), i)) {
                    NSLog(@"Friend error ABMultiValueReplaceValueAtIndex %@ %ld", topic, i);
                }
            } else {
                if (!ABMultiValueRemoveValueAndLabelAtIndex(relationsRW, i))  {
                    NSLog(@"Friend error ABMultiValueRemoveValueAndLabelAtIndex %ld", i);
                }
            }
            CFRelease(label);
            break;
        }
        CFRelease(label);
    }
    if (i == relationsCount) {
        if (topic) {
            if (!ABMultiValueAddValueAndLabel(relationsRW, (__bridge CFStringRef)(self.topic), RELATION_NAME, NULL)) {
                NSLog(@"Friend error ABMultiValueAddValueAndLabel %@ %@", topic, RELATION_NAME);
            }
        }
    }
        
    if (!ABRecordSetValue(record, kABPersonRelatedNamesProperty, relationsRW, &errorRef)) {
        NSLog(@"Friend error ABRecordSetValue %@", errorRef);
    }
    CFRelease(relationsRW);
    
    ABAddressBookRef ab = [Friend theABRef];
    if (ab) {
        if (ABAddressBookHasUnsavedChanges(ab)) {
            if (!ABAddressBookSave(ab, &errorRef)) {
                NSLog(@"Friend error ABAddressBookSave %@", errorRef);
            }
        }
    }
}

- (NSString *)getEffectiveTid {
    NSString *tid;
    if (self.tid != nil && ![self.tid isEqualToString:@""]) {
        tid = self.tid;
    } else {
        NSUInteger length = self.topic.length;
        if (length > 2) {
            tid = [self.topic substringFromIndex:length - 2].uppercaseString;
        } else {
            tid = self.topic.uppercaseString;
        }
    }
    return tid;
}

- (Location *)newestLocation
{
    Location *newestLocation;
    
    for (Location *location in self.hasLocations) {
        if (!newestLocation) {
            newestLocation = location;
        } else {
            if ([newestLocation.timestamp compare:location.timestamp] == NSOrderedAscending) {
                newestLocation = location;
            } 
        }
    }
    return newestLocation;
}




@end
