//
//  Task.h
//  GJBDropboxIncrementalStore
//
//  Created by Grant Butler on 1/17/15.
//  Copyright (c) 2015 Grant Butler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class List;

@interface Task : NSManagedObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) BOOL completed;
@property (nonatomic, retain) List *list;

@end
