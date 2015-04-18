#ABStaticTableViewController

Dynamically hide rows and sections in static UITableView inside UITableViewController.

#Installation

Just:

```
pod 'ABStaticTableViewController'
```

or include this files into your project:

- ABStaticTableViewController.h
- ABStaticTableViewController.m

#Using

Replace this code of `MyTableViewController.h`:

```
@interface MyTableViewController : UITableViewController
```

With this code:

```
@interface MyTableViewController : ABStaticTableViewController
```

And now you can call this methods to non-animated and animated rows and sections deletions and insertions back:

```
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)insertSections:(NSIndexSet *)sections;
- (void)deleteSections:(NSIndexSet *)sections;

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths
              withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths
              withRowAnimation:(UITableViewRowAnimation)animation;
- (void)insertSections:(NSIndexSet *)sections
      withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteSections:(NSIndexSet *)sections
      withRowAnimation:(UITableViewRowAnimation)animation;
```

#License

ABStaticTableViewController is released under the MIT License.