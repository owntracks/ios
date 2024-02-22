//
//  ABStaticTableViewController.m
//  iCitizen
//
//  Created by Anton Bukov on 05.04.14.
//  Copyright (c) 2014 Codeless Solutions. All rights reserved.
//

#import "ABStaticTableViewController.h"

@interface ABStaticTableViewController ()

@end

@implementation ABStaticTableViewController

- (NSMutableDictionary *)rowsVisibility
{
    if (_rowsVisibility == nil)
        _rowsVisibility = [NSMutableDictionary dictionary];
    return _rowsVisibility;
}

- (NSMutableDictionary *)sectionsVisibility
{
    if (_sectionsVisibility == nil)
        _sectionsVisibility = [NSMutableDictionary dictionary];
    return _sectionsVisibility;
}

- (BOOL)isRowVisible:(NSIndexPath *)indexPath
{
    BOOL(^block)() = self.rowsVisibility[indexPath];
    return (!block) || block();
}

- (BOOL)isSectionVisible:(NSInteger)section
{
    BOOL(^block)() = self.sectionsVisibility[@(section)];
    return (!block) || block();
}

- (NSIndexPath *)convertRow:(NSIndexPath *)indexPath
{
    NSInteger section = [self convertSection:indexPath.section];
    NSInteger rowDelta = 0;
    for (NSIndexPath *ip in [self.rowsVisibility.allKeys sortedArrayUsingSelector:@selector(compare:)])
    {
        if (ip.section == section
            && ip.row <= indexPath.row + rowDelta)
        {
            BOOL (^block)() = self.rowsVisibility[ip];
            rowDelta += block() ? 0 : 1;
        }
    }
    return [NSIndexPath indexPathForRow:indexPath.row + rowDelta inSection:section];
}

- (NSInteger)convertSection:(NSInteger)section
{
    NSInteger secDelta = 0;
    for (NSNumber *sec in [self.sectionsVisibility.allKeys sortedArrayUsingSelector:@selector(compare:)])
    {
        if (sec.integerValue <= section + secDelta)
        {
            BOOL (^block)() = self.sectionsVisibility[sec];
            secDelta += block() ? 0 : 1;
        }
    }
    return section + secDelta;
}

- (NSIndexPath *)recoverRow:(NSIndexPath *)indexPath
{
    NSInteger section = [self recoverSection:indexPath.section];
    int rowDelta = 0;
    for (NSIndexPath * ip in [self.rowsVisibility.allKeys sortedArrayUsingSelector:@selector(compare:)])
    {
        if (ip.section == indexPath.section
            && ip.row < indexPath.row)
        {
            BOOL (^block)() = self.rowsVisibility[ip];
            rowDelta += block() ? 0 : 1;
        }
    }
    return [NSIndexPath indexPathForRow:indexPath.row - rowDelta inSection:section];
}

- (NSInteger)recoverSection:(NSInteger)section
{
    NSInteger secDelta = 0;
    for (NSNumber *sec in [self.sectionsVisibility.allKeys sortedArrayUsingSelector:@selector(compare:)])
    {
        if (sec.integerValue < section)
        {
            BOOL (^block)() = self.sectionsVisibility[sec];
            secDelta += block() ? 0 : 1;
        }
    }
    return section - secDelta;
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths
{
    for (NSIndexPath *ip in indexPaths)
        [self.rowsVisibility removeObjectForKey:ip];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths
{
    for (NSIndexPath *ip in indexPaths)
        self.rowsVisibility[ip] = ^{ return NO; };
}

- (void)insertSections:(NSIndexSet *)sections
{
    [sections enumerateIndexesUsingBlock:^(NSUInteger sec, BOOL *stop) {
        [self.sectionsVisibility removeObjectForKey:@(sec)];
    }];
}

- (void)deleteSections:(NSIndexSet *)sections
{
    [sections enumerateIndexesUsingBlock:^(NSUInteger sec, BOOL *stop) {
        self.sectionsVisibility[@(sec)] = ^{ return NO; };
    }];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self insertRowsAtIndexPaths:indexPaths];
    [self.tableView beginUpdates];
    NSMutableArray *ips = [NSMutableArray array];
    for (NSIndexPath *ip in indexPaths)
        [ips addObject:[self recoverRow:ip]];
    [self.tableView insertRowsAtIndexPaths:ips withRowAnimation:animation];
    [self.tableView endUpdates];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self.tableView beginUpdates];
    NSMutableArray *ips = [NSMutableArray array];
    for (NSIndexPath *ip in indexPaths)
        [ips addObject:[self recoverRow:ip]];
    [self.tableView deleteRowsAtIndexPaths:ips withRowAnimation:animation];
    [self deleteRowsAtIndexPaths:indexPaths];
    [self.tableView endUpdates];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    [self.tableView beginUpdates];
    NSMutableIndexSet *secs = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger sec, BOOL *stop) {
        [secs addIndex:[self recoverSection:sec]];
    }];
    [self.tableView insertSections:secs withRowAnimation:animation];
    [self insertSections:sections];
    [self.tableView endUpdates];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    [self.tableView beginUpdates];
    NSMutableIndexSet *secs = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger sec, BOOL *stop) {
        [secs addIndex:[self recoverSection:sec]];
    }];
    [self.tableView deleteSections:secs withRowAnimation:animation];
    [self deleteSections:sections];
    [self.tableView endUpdates];
}

#pragma mark - Table View Controller

- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [super tableView:tableView indentationLevelForRowAtIndexPath:[self convertRow:indexPath]];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [super tableView:tableView titleForHeaderInSection:[self convertSection:section]];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return [super tableView:tableView titleForFooterInSection:[self convertSection:section]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [super tableView:tableView heightForHeaderInSection:[self convertSection:section]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [super tableView:tableView heightForRowAtIndexPath:[self convertRow:indexPath]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [super tableView:tableView heightForFooterInSection:[self convertSection:section]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger count = 0;
    for (NSNumber *sec in self.sectionsVisibility) {
        BOOL (^block)() = self.sectionsVisibility[sec];
        count += block() ? 0 : 1;
    }
    return [super numberOfSectionsInTableView:tableView] - count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger realSection = [self convertSection:section];
    NSInteger count = 0;
    for (NSIndexPath *ip in self.rowsVisibility) {
        if (ip.section == realSection) {
            BOOL (^block)() = self.rowsVisibility[ip];
            count += block() ? 0 : 1;
        }
    }
    return [super tableView:tableView numberOfRowsInSection:realSection] - count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [super tableView:tableView cellForRowAtIndexPath:[self convertRow:indexPath]];
}

@end
