//
//  PersonTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.10.13.
//  Copyright © 2013 -2019 Christoph Krey. All rights reserved.
//

#import "PersonTVC.h"
#import "Friend+CoreDataClass.h"
#import <Contacts/Contacts.h>
#import <CocoaLumberjack/CocoaLumberjack.h>


@interface PersonTVC ()
@property (strong, nonatomic) NSMutableDictionary *sections;
@end

@implementation PersonTVC
static const DDLogLevel ddLogLevel = DDLogLevelWarning;

- (void)viewWillAppear:(BOOL)animated {
    self.sections = [[NSMutableDictionary alloc] init];

    NSArray *keys = @[[CNContactFormatter
                       descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName],
                      CNContactThumbnailImageDataKey,
                      CNContactImageDataAvailableKey
                      ];
    CNContactFetchRequest *contactFetchRequest = [[CNContactFetchRequest alloc]
                                                  initWithKeysToFetch:keys];
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    [contactStore enumerateContactsWithFetchRequest:contactFetchRequest
                                              error:nil
                                         usingBlock:
     ^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
         NSString *name = [CNContactFormatter
                           stringFromContact:contact
                           style:CNContactFormatterStyleFullName];

         DDLogVerbose(@"contact %@: %@",
                      contact.identifier,
                      name);

         NSString *key = [name substringToIndex:1].uppercaseString;
         if (key) {
             NSMutableArray *array = (self.sections)[key];
             if (!array) {
                 array = [[NSMutableArray alloc] init];
             }
             [array addObject:contact];
             (self.sections)[key] = array;
         }

     }];

    for (NSString *key in self.sections.allKeys) {
        NSArray *persons = [(self.sections)[key] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            CNContact *contact1 = obj1;
            CNContact *contact2 = obj2;
            NSString *name1 = [CNContactFormatter
                              stringFromContact:contact1
                              style:CNContactFormatterStyleFullName];
            NSString *name2 = [CNContactFormatter
                              stringFromContact:contact2
                              style:CNContactFormatterStyleFullName];

            return [name1 localizedCaseInsensitiveCompare:name2];
        }];

        (self.sections)[key] = persons;
    }

    self.tableView.sectionIndexMinimumDisplayRowCount = 8;

    [super viewWillAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (self.sections).count;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [(self.sections).allKeys sortedArrayUsingSelector:@selector(compare:)];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return index;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *keys = [(self.sections).allKeys sortedArrayUsingSelector:@selector(compare:)];
    return keys[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *keys = [(self.sections).allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSArray *persons = (self.sections)[keys[section]];
    return persons.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"person" forIndexPath:indexPath];
    
    NSArray *persons = [self sortedPersonsInSection: indexPath.section];
    CNContact *contact = persons[indexPath.row];
    cell.textLabel.text = [CNContactFormatter
                           stringFromContact:contact
                           style:CNContactFormatterStyleFullName];

    if (contact.imageDataAvailable) {
        cell.imageView.image = [UIImage imageWithData:contact.thumbnailImageData];
    } else {
        cell.imageView.image = [UIImage imageNamed:@"icon40"];
    }
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *indexPath = nil;
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        indexPath = [self.tableView indexPathForCell:sender];
        if (indexPath) {
            if ([segue.identifier isEqualToString:@"setPerson:"]) {
                NSArray *persons = [self sortedPersonsInSection: indexPath.section];
                CNContact *contact = persons[indexPath.row];
                self.contactId = contact.identifier;
            }
        }
    } else {
        self.contactId = nil;
    }
}

- (NSArray *)sortedPersonsInSection:(NSInteger)index {
    NSArray *keys = [(self.sections).allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSArray *persons = (self.sections)[keys[index]];
    return persons;
}

- (IBAction)contactsButton:(UIBarButtonItem *)sender {
}
@end
