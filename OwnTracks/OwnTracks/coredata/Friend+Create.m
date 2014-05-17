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
    static BOOL isGranted = YES;
    
    if (!ab) {
        if (isGranted) {
#ifdef DEBUG
            NSLog(@"ABAddressBookCreateWithOptions");
#endif
            CFErrorRef cfError;
            ab = ABAddressBookCreateWithOptions(NULL, &cfError);
            if (ab) {
#ifdef DEBUG
                NSLog(@"ABAddressBookCreateWithOptions successful");
#endif
            } else {
                CFStringRef errorDescription = CFErrorCopyDescription(cfError);
                [Friend error:[NSString stringWithFormat:@"ABAddressBookCreateWithOptions not successfull %@", errorDescription]];
                CFRelease(errorDescription);
                isGranted = NO;
            }
            
#ifdef DEBUG
            NSLog(@"ABAddressBookRequestAccessWithCompletion");
#endif
            
            ABAddressBookRequestAccessWithCompletion(ab, ^(bool granted, CFErrorRef error) {
                if (granted) {
#ifdef DEBUG
                    NSLog(@"ABAddressBookRequestAccessCompletionHandler successful");
#endif
                } else {
                    isGranted = NO;
                }
            });
        } else {
            //Error message should have appeared once
            //[Friend error:[NSString stringWithFormat:@"ABAddressBookRequestAccessWithCompletion not successfull"]];
        }
        
    }
    
    return ab;
}

+ (Friend *)friendWithTopic:(NSString *)topic
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
        
        if (![matches count]) {
            //create new friend
            friend = [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:context];
            
            friend.topic = topic;
            
            friend.device = nil;
            friend.abRecordId = @(kABRecordInvalidID);
            friend.hasLocations = [[NSSet alloc] init];
        } else {
            // friend exists already
            friend = [matches lastObject];
        }
    }
    
    return friend;
}

- (NSString *)name
{
    ABRecordRef record = [self recordOfFriend];
    
    if (record) {
        return [Friend nameOfPerson:record];
    } else {
        return nil;
    }
}

- (NSData *)image
{
    ABRecordRef record = [self recordOfFriend];
    
    if (record) {
        return [Friend imageDataOfPerson:record];
    } else {
       return nil;
    }
}

- (ABRecordRef)recordOfFriend
{
    ABRecordRef record = NULL;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if ([delegate.settings boolForKey:@"ab_preference"]) {
        record = recordWithTopic((__bridge CFStringRef)(self.topic));
        //NSLog(@"Friend ABRecordRef by topic =  %p", record);
    } else {
        if ([self.abRecordId intValue] != kABRecordInvalidID) {
            record = ABAddressBookGetPersonWithRecordID([Friend theABRef],
                                                              [self.abRecordId intValue]);
            //NSLog(@"Friend ABRecordRef by abRecordID =  %p", record);
        }
    }
    
    return record;
}

+ (NSString *)nameOfPerson:(ABRecordRef)record
{
    NSString *name;
    name =  CFBridgingRelease(ABRecordCopyValue(record, kABPersonNicknameProperty));
    if (!name) {
        name = CFBridgingRelease(ABRecordCopyCompositeName(record));
    }
    return name;
}

+ (NSData *)imageDataOfPerson:(ABRecordRef)record
{
    NSData *imageData = nil;
    
    if (ABPersonHasImageData(record)) {
        CFDataRef ir = ABPersonCopyImageDataWithFormat(record, kABPersonImageFormatThumbnail);
        imageData = CFBridgingRelease(ir);
    }
    return imageData;
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
    
    CFArrayRef records = ABAddressBookCopyArrayOfAllPeople([Friend theABRef]);
    
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
                    [Friend error:[NSString stringWithFormat:@"Friend error ABMultiValueReplaceValueAtIndex %@ %ld", topic, i]];
                }
            } else {
                if (!ABMultiValueRemoveValueAndLabelAtIndex(relationsRW, i))  {
                    [Friend error:[NSString stringWithFormat:@"Friend error ABMultiValueRemoveValueAndLabelAtIndex %ld", i]];
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
                [Friend error:[NSString stringWithFormat:@"Friend error ABMultiValueAddValueAndLabel %@ %@", topic, RELATION_NAME]];
            }
        }
    }
        
    if (!ABRecordSetValue(record, kABPersonRelatedNamesProperty, relationsRW, &errorRef)) {
        [Friend error:[NSString stringWithFormat:@"Friend error ABRecordSetValue %@", errorRef]];
    }
    CFRelease(relationsRW);
    
    if (ABAddressBookHasUnsavedChanges([Friend theABRef])) {
        if (!ABAddressBookSave([Friend theABRef], &errorRef)) {
            [Friend error:[NSString stringWithFormat:@"Friend error ABAddressBookSave %@", errorRef]];
        }
    }
}

+ (void)error:(NSString *)message
{
#ifdef DEBUG
    NSLog(@"Friend error %@", message);
#endif
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSBundle mainBundle].infoDictionary[@"CFBundleName"]
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    
    [alertView show];
    
}

@end
