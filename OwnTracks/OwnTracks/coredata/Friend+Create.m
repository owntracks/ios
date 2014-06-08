//
//  Friend+Create.m
//  OwnTracks   
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
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

+ (Friend *)friendWithTopic:(NSString *)topic
     inManagedObjectContext:(NSManagedObjectContext *)context

{
    Friend *friend = [self existsFriendWithTopic:topic inManagedObjectContext:context];
    
    if (!friend) {
        friend = [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:context];
        
        friend.topic = topic;
        
        friend.abRecordId = @(kABRecordInvalidID);
        friend.hasLocations = [[NSSet alloc] init];
    }

    return friend;
}

- (NSString *)name
{
    ABRecordRef record = [self recordOfFriend];
    
    return [Friend nameOfPerson:record];
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
    ABRecordRef record = [self recordOfFriend];
    
    return [Friend imageDataOfPerson:record];
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

@end
