//
//  PersonTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.10.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "PersonTVC.h"
#import "Friend+Create.h"

@interface PersonTVC ()
@property (strong, nonatomic) NSMutableDictionary *sections;
@end

@implementation PersonTVC

- (void)viewWillAppear:(BOOL)animated
{
    self.sections = [[NSMutableDictionary alloc] init];
    
    ABAddressBookRef ab = [Friend theABRef];
    if (ab) {
        CFArrayRef records = ABAddressBookCopyArrayOfAllPeople(ab);
        
        if (records) {
            for (int i = 0; i < CFArrayGetCount(records); i++)
            {
                ABRecordRef person = CFArrayGetValueAtIndex(records, i);
                NSString *name = CFBridgingRelease(ABRecordCopyCompositeName(person));
                NSString *key = [[name substringToIndex:1] uppercaseString];
                if (key) {
                    NSMutableArray *array = [self.sections objectForKey:key];
                    if (!array) {
                        array = [[NSMutableArray alloc] init];
                    }
                    [array addObject:@(ABRecordGetRecordID(person))];
                    [self.sections setObject:array forKey:key];
                }
            }
            CFRelease(records);
        }
    
        for (NSString *key in self.sections.allKeys) {
            NSArray *persons = [[self.sections objectForKey:key] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                ABRecordRef ABRecordRef1 = ABAddressBookGetPersonWithRecordID(ab, [obj1 intValue]);
                ABRecordRef ABRecordRef2 = ABAddressBookGetPersonWithRecordID(ab, [obj2 intValue]);
                CFComparisonResult r = ABPersonComparePeopleByName(ABRecordRef1, ABRecordRef2, ABPersonGetSortOrdering());
                return (NSComparisonResult)r;
            }];
            
            [self.sections setObject:persons forKey:key];
        }
    }
    
    self.tableView.sectionIndexMinimumDisplayRowCount = 8;
    [super viewWillAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.sections count];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return [[self.sections allKeys] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return index;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSArray *keys = [[self.sections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    return keys[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *keys = [[self.sections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSArray *persons = [self.sections objectForKey:keys[section]];
    return [persons count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"person" forIndexPath:indexPath];
    
    NSArray *persons = [self sortedPersonsInSection: indexPath.section];
    ABRecordRef person = NULL;
    ABAddressBookRef ab = [Friend theABRef];
    if (ab) {
        person = ABAddressBookGetPersonWithRecordID([Friend theABRef], [persons[indexPath.row] intValue]);
    }
    
    cell.textLabel.text = [Friend nameOfPerson:person] ? [Friend nameOfPerson:person] : NSLocalizedString(@"unknown",
                                                                                                          @"displayed if a name is not known");
    cell.imageView.image = [Friend imageDataOfPerson:person] ?
        [UIImage imageWithData:[Friend imageDataOfPerson:person]] : [UIImage imageNamed:@"icon40"];
    
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = nil;
    
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        indexPath = [self.tableView indexPathForCell:sender];
        if (indexPath) {
            if ([segue.identifier isEqualToString:@"setPerson:"]) {
                NSArray *persons = [self sortedPersonsInSection: indexPath.section];
                ABAddressBookRef ab = [Friend theABRef];
                if (ab) {
                    self.person = ABAddressBookGetPersonWithRecordID(ab, [persons[indexPath.row] intValue]);
                } else {
                    self.person = nil;
                }
            }
        }
    } else {
        self.person = nil;
    }
    
}

- (NSArray *)sortedPersonsInSection:(NSInteger)index
{
    NSArray *keys = [[self.sections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSArray *persons = [self.sections objectForKey:keys[index]];
    return persons;
}



@end
