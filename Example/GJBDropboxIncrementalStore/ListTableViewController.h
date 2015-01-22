//
//  ListTableViewController.h
//  GJBDropboxIncrementalStore
//
//  Created by Grant Butler on 1/17/15.
//  Copyright (c) 2015 Grant Butler. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class List;

@interface ListTableViewController : UITableViewController

@property (nonatomic) List *list;

@end
