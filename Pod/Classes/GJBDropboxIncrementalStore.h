//
//  GJBDropxboxIncrementalStore.h
//  Checkmark
//
//  Created by Grant Butler on 7/30/14.
//  Copyright (c) 2014 Grant Butler. All rights reserved.
//

@import CoreData;

extern NSString * const GJBDropboxIncrementalStoreType;

extern NSString * const GJBDropboxIncrementalStoreErrorDomain;

extern NSString * const GJBDropboxIncrementalStoreShouldRefetchObjectsNotification;

typedef NS_ENUM(NSUInteger, GJBDropboxIncrementalStoreErrorCode) {
	GJBDropboxIncrementalStoreErrorCodeUnknown = 0,
	GJBDropboxIncrementalStoreErrorCodeInvalidPredicate = 1,
	GJBDropboxIncrementalStoreErrorCodeInvalidURL,
	GJBDropboxIncrementalStoreErrorCodeDropboxError
};

/**
 * When adding a GJBDropxboxIncrementalStore, the URL should follow this format:
 *
 * `db-datastore://<App Identifier>/`
 */
@interface GJBDropboxIncrementalStore : NSIncrementalStore

@end
