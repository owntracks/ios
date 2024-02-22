//
//  ABStaticTableViewController.h
//  iCitizen
//
//  Created by Антон Буков on 05.04.14.
//  Copyright (c) 2014 Codeless Solutions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ABStaticTableViewController : UITableViewController

@property (strong, nonatomic) NSMutableDictionary *rowsVisibility;
@property (strong, nonatomic) NSMutableDictionary *sectionsVisibility;

- (BOOL)isRowVisible:(NSIndexPath *)indexPath;
- (BOOL)isSectionVisible:(NSInteger)section;

- (NSIndexPath *)convertRow:(NSIndexPath *)indexPath;
- (NSInteger)convertSection:(NSInteger)section;
- (NSIndexPath *)recoverRow:(NSIndexPath *)indexPath;
- (NSInteger)recoverSection:(NSInteger)section;

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)insertSections:(NSIndexSet *)sections;
- (void)deleteSections:(NSIndexSet *)sections;

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;

@end
