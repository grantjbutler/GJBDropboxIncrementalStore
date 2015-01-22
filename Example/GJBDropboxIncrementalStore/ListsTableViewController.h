//
//  ListsTableViewController.h
//  GJBDropboxIncrementalStore
//
//  Created by Grant Butler on 1/17/15.
//  Copyright (c) 2015 Grant Butler. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface ListsTableViewController : UITableViewController

@property (nonatomic) NSManagedObjectContext *context;

@end
