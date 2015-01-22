//
//  GJBDropxboxIncrementalStore.m
//  Checkmark
//
//  Created by Grant Butler on 7/30/14.
//  Copyright (c) 2014 Grant Butler. All rights reserved.
//

#import "GJBDropboxIncrementalStore.h"

#import <Dropbox/Dropbox.h>

NSString * const GJBDropboxIncrementalStoreType = @"GJBDropxboxIncrementalStore";

NSString * const GJBDropboxIncrementalStoreErrorDomain = @"com.grantjbutler.GJBDropboxIncrementalStore.ErrorDomain";

static NSString * const GJBDropboxIncrementalStoreMetadataTableName = @"_GJBDropxboxIncrementalStoreMetadata";

static NSString * const GJBDropboxIncrementalStoreMetadataNameKey = @"GJBDropxboxIncrementalStoreMetadataName";
static NSString * const GJBDropboxIncrementalStoreMetadataValueKey = @"GJBDropxboxIncrementalStoreMetadataKey";

static NSString * const GJBDropboxIncrementalStoreVersionKey = @"GJBDropboxIncrementalStoreVersion";

NSString * const GJBDropboxIncrementalStoreShouldRefetchObjectsNotification = @"GJBDropboxIncrementalStoreShouldRefetchObjectsNotification";

@interface GJBDropboxIncrementalStore ()

@property (nonatomic) DBDatastoreManager *datastoreManager;
@property (nonatomic) DBDatastore *datastore;

@property (nonatomic) NSMutableDictionary *entityCache;

@end

@implementation GJBDropboxIncrementalStore

+ (void)load {
	[NSPersistentStoreCoordinator registerStoreClass:[self class] forStoreType:GJBDropboxIncrementalStoreType];
}

#pragma mark - Predicate support

+ (BOOL)validateComparisonPredicate:(NSComparisonPredicate *)predicate error:(NSError **)error {
	if (predicate.predicateOperatorType != NSEqualToPredicateOperatorType) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:GJBDropboxIncrementalStoreErrorDomain
										 code:GJBDropboxIncrementalStoreErrorCodeInvalidPredicate
									 userInfo:@{
												NSLocalizedDescriptionKey: NSLocalizedString(@"Only 'NSEqualToPredicateOperatorType' is supported.", nil)
												}];
		}
		
		return NO;
	}
	
	NSExpression *leftExpression = predicate.leftExpression;
	NSExpression *rightExpression = predicate.rightExpression;
	
	if (leftExpression.expressionType != NSKeyPathExpressionType) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:GJBDropboxIncrementalStoreErrorDomain
										 code:GJBDropboxIncrementalStoreErrorCodeInvalidPredicate
									 userInfo:@{
												NSLocalizedDescriptionKey: NSLocalizedString(@"Only 'NSKeyPathExpressionType' is supported for leftExpression.", nil)
												}];
		}
		
		return NO;
	}
	
	if (rightExpression.expressionType != NSConstantValueExpressionType) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:GJBDropboxIncrementalStoreErrorDomain
										 code:GJBDropboxIncrementalStoreErrorCodeInvalidPredicate
									 userInfo:@{
												NSLocalizedDescriptionKey: NSLocalizedString(@"Only 'NSConstantValueExpressionType' is supported for rightExpression.", nil)
												}];
		}
		
		return NO;
	}
	
	return YES;
}

+ (BOOL)validateCompoundPredicate:(NSCompoundPredicate *)predicate error:(NSError **)error {
	if (predicate.compoundPredicateType != NSAndPredicateType) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:GJBDropboxIncrementalStoreErrorDomain
										 code:GJBDropboxIncrementalStoreErrorCodeInvalidPredicate
									 userInfo:@{
												NSLocalizedDescriptionKey: NSLocalizedString(@"Only 'NSAndPredicateType' is supported.", nil)
												}];
		}
		
		return NO;
	}
	
	__block BOOL hasValidSubpredicates = YES;
	[predicate.subpredicates enumerateObjectsUsingBlock:^(NSPredicate *predicate, NSUInteger idx, BOOL *stop) {
		if (![self validatePredicate:predicate error:error]) {
			hasValidSubpredicates = NO;
			
			*stop = YES;
		}
	}];
	
	return hasValidSubpredicates;
}

+ (BOOL)validatePredicate:(NSPredicate *)predicate error:(NSError **)error {
	if (!predicate) {
		return YES;
	}
	
	if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
		return [self validateComparisonPredicate:(NSComparisonPredicate *)predicate error:error];
	}
	else if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
		return [self validateCompoundPredicate:(NSCompoundPredicate *)predicate error:error];
	}
	
	if (error != NULL) {
		*error = [NSError errorWithDomain:GJBDropboxIncrementalStoreErrorDomain
									 code:GJBDropboxIncrementalStoreErrorCodeInvalidPredicate
								 userInfo:@{
											NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Predicate class '%@' is not supported.", nil), NSStringFromClass([predicate class])]
											}];
	}
	
	return NO;
}

- (NSDictionary *)filtersFromComparisonPredicate:(NSComparisonPredicate *)predicate {
	if (predicate.predicateOperatorType != NSEqualToPredicateOperatorType) {
		return nil;
	}
	
	NSExpression *leftExpression = predicate.leftExpression;
	NSExpression *rightExpression = predicate.rightExpression;
	
	if (leftExpression.expressionType != NSKeyPathExpressionType) {
		return nil;
	}
	
	if (rightExpression.expressionType != NSConstantValueExpressionType) {
		return nil;
	}
	
	id value = rightExpression.constantValue;
	if ([value isKindOfClass:[NSManagedObject class]]) {
		NSManagedObject *managedObject = (NSManagedObject *)value;
		value = [self referenceObjectForObjectID:managedObject.objectID];
	}
	
	return @{
			 leftExpression.keyPath: value ?: [NSNull null]
			 };
}

- (NSDictionary *)filtersFromCompoundPredicate:(NSCompoundPredicate *)predicate {
	if (predicate.compoundPredicateType != NSAndPredicateType) {
		return nil;
	}
	
	NSMutableDictionary *filters = [NSMutableDictionary dictionary];
	
	__block BOOL hasValidSubpredicates = YES;
	[predicate.subpredicates enumerateObjectsUsingBlock:^(NSPredicate *predicate, NSUInteger idx, BOOL *stop) {
		NSDictionary *subfilter = [self filtersFromPredicate:predicate];
		if (!subfilter) {
			hasValidSubpredicates = NO;
			
			*stop = YES;
			
			return;
		}
		
		[filters addEntriesFromDictionary:subfilter];
	}];
	
	if (!hasValidSubpredicates) {
		return nil;
	}
	
	return filters;
}

- (NSDictionary *)filtersFromPredicate:(NSPredicate *)predicate {
	if (!predicate) {
		return @{};
	}
	
	if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
		return [self filtersFromComparisonPredicate:(NSComparisonPredicate *)predicate];
	}
	else if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
		return [self filtersFromCompoundPredicate:(NSCompoundPredicate *)predicate];
	}
	
	return nil;
}

#pragma mark - Helpers

+ (NSString *)tableNameFromEntity:(NSEntityDescription *)entity {
	return entity.name;
}

#pragma mark - Setup

- (void)setupAccountManagerObserver {
	DBAccountManager *accountManager = [DBAccountManager sharedManager];
	[accountManager addObserver:self block:^(DBAccount *account) {
		[self migrateToAccount:account];
	}];
}

- (void)openDatastoreAtURL:(NSURL *)URL {
	DBAccount *linkedAccount = [DBAccountManager sharedManager].linkedAccount;
	if (linkedAccount) {
		self.datastoreManager = [DBDatastoreManager managerForAccount:linkedAccount];
	}
	else {
		self.datastoreManager = [DBDatastoreManager localManagerForAccountManager:[DBAccountManager sharedManager]];
	}
	
	NSString *host = [[URL host] lowercaseString];
	self.datastore = [self.datastoreManager openOrCreateDatastore:host error:nil];
	
	__weak typeof(self) weakSelf = self;
	[self.datastore addObserver:self block:^{
		__strong typeof(weakSelf) strongSelf = weakSelf;
		DBDatastoreStatus *status = strongSelf.datastore.status;
		
		if (status.needsReset) {
			[strongSelf resetStore];
		}
		else if (status.incoming || status.outgoing) {
			[strongSelf syncDatastore];
		}
	}];
}

- (void)closeDatastore {
	[self.datastore removeObserver:self];
	[self.datastore close];
	self.datastore = nil;
}

#pragma mark - Helpers

- (NSEntityDescription *)entityForTableName:(NSString *)tableName {
	return self.persistentStoreCoordinator.managedObjectModel.entitiesByName[tableName];
}

- (BOOL)validateURL {
	if (![self.URL.scheme isEqualToString:@"db-datastore"]) {
		return NO;
	}
	
	return YES;
}

- (void)migrateToAccount:(DBAccount *)account {
	if (self.datastore) {
		[self closeDatastore];
	}
	
	if (account && self.datastoreManager.isLocal) {
		[self.datastoreManager migrateToAccount:account error:nil];
	}
	
	[self openDatastoreAtURL:self.URL];
}

- (void)resetStore {
	if (self.datastore) {
		NSString *datastoreID = self.datastore.datastoreId;
		[self closeDatastore];
		
		[self.datastoreManager uncacheDatastore:datastoreID error:nil];
	}
	
	[self openDatastoreAtURL:self.URL];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:GJBDropboxIncrementalStoreShouldRefetchObjectsNotification object:nil];
}

- (void)syncDatastore {
	NSDictionary *changes = [self.datastore sync:nil];
	
	[changes enumerateKeysAndObjectsUsingBlock:^(NSString *tableId, NSArray *objects, BOOL *stop) {
		
	}];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:GJBDropboxIncrementalStoreShouldRefetchObjectsNotification object:nil];
}

- (NSError *)errorForDropboxError:(DBError *)dbError {
	return [NSError errorWithDomain:GJBDropboxIncrementalStoreErrorDomain
							   code:GJBDropboxIncrementalStoreErrorCodeDropboxError
						   userInfo:@{
									  NSUnderlyingErrorKey: dbError
									  }];
}

#pragma mark - Relationships

- (void)saveToManyRelationship:(NSRelationshipDescription *)relationship ofObject:(NSManagedObject *)object withPropertyName:(NSString *)name toRecord:(DBRecord *)record {
	DBList *objectList = [record getOrCreateList:name];
	
	while ([objectList count]) {
		[objectList removeLastObject];
	}
	
	id objects = [object valueForKey:name];
	for (NSManagedObject *managedObject in objects) {
		NSString *recordID = [self referenceObjectForObjectID:managedObject.objectID];
		
		[objectList addObject:recordID];
	}
}

- (void)saveToOneRelationship:(NSRelationshipDescription *)relationship ofObject:(NSManagedObject *)object withPropertyName:(NSString *)name toRecord:(DBRecord *)record {
	NSManagedObject *managedObject = [object valueForKey:name];
	NSString *recordID = [self referenceObjectForObjectID:managedObject.objectID];
	
	record[name] = recordID;
}

- (NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
	NSPredicate *predicate = fetchRequest.predicate;
	
	if (![[self class] validatePredicate:predicate error:error]) {
		return nil;
	}
	
	NSString *tableName = [[self class] tableNameFromEntity:fetchRequest.entity];
	DBTable *table = [self.datastore getTable:tableName];
	
	NSDictionary *filters = [self filtersFromPredicate:fetchRequest.predicate];
	
	DBError *dbError;
	NSArray *records = [table query:filters error:&dbError];
	
	if (!records) {
		if (error != NULL) {
			*error = [self errorForDropboxError:dbError];
		}
		
		return nil;
	}
	
	NSMutableArray *fetchedObjects = [NSMutableArray array];
	
	[records enumerateObjectsUsingBlock:^(DBRecord *record, NSUInteger idx, BOOL *stop) {
		NSManagedObjectID *objectID = [self newObjectIDForEntity:fetchRequest.entity referenceObject:record.recordId];
		NSManagedObject *object = [context objectWithID:objectID];
		[fetchedObjects addObject:object];
	}];
	
	[fetchedObjects sortedArrayUsingDescriptors:fetchRequest.sortDescriptors];
	
	return fetchedObjects;
}

- (NSArray *)executeSaveRequest:(NSSaveChangesRequest *)saveRequest withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
	NSSet *insertedObjects = [saveRequest insertedObjects];
	NSSet *updatedObjects = [saveRequest updatedObjects];
	NSSet *deletedObjects = [saveRequest deletedObjects];
	NSSet *optLockObjecs = [saveRequest lockedObjects];
	
	void(^incrementRecordVersion)(DBRecord *) = ^(DBRecord *record) {
		NSInteger version = [record[GJBDropboxIncrementalStoreVersionKey] integerValue];
		version += 1;
		record[GJBDropboxIncrementalStoreVersionKey] = @(version);
	};
	
	void(^updateObjectsBlock)(NSManagedObject *, BOOL *) = ^(NSManagedObject *object, BOOL *stop) {
		NSString *tableName = [[self class] tableNameFromEntity:object.entity];
		DBTable *table = [self.datastore getTable:tableName];
		NSString *recordId = [self referenceObjectForObjectID:object.objectID];
		
		DBError *dbError;
		BOOL inserted;
		DBRecord *record = [table getOrInsertRecord:recordId fields:@{ } inserted:&inserted error:&dbError];
		
		if (!record) {
			if (error != NULL) {
				*error = [self errorForDropboxError:dbError];
				
				*stop = YES;
				
				return;
			}
		}
		
		[object.entity.propertiesByName enumerateKeysAndObjectsUsingBlock:^(NSString *name, id property, BOOL *stop) {
			if ([property isKindOfClass:[NSAttributeDescription class]]) {
				id value = [object valueForKey:name];
				if (value) {
					record[name] = value;
				}
			}
			else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
				NSRelationshipDescription *relationship = (NSRelationshipDescription *)property;
				
				if (relationship.isToMany) {
					[self saveToManyRelationship:relationship ofObject:object withPropertyName:name toRecord:record];
				}
				else {
					[self saveToOneRelationship:relationship ofObject:object withPropertyName:name toRecord:record];
				}
			}
		}];
		
		incrementRecordVersion(record);
	};
	
	[insertedObjects enumerateObjectsUsingBlock:updateObjectsBlock];
	[updatedObjects enumerateObjectsUsingBlock:updateObjectsBlock];
	
	[deletedObjects enumerateObjectsUsingBlock:^(NSManagedObject *object, BOOL *stop) {
		NSString *tableName = [[self class] tableNameFromEntity:object.entity];
		DBTable *table = [self.datastore getTable:tableName];
		NSString *recordId = [self referenceObjectForObjectID:object.objectID];
		
		DBError *dbError;
		DBRecord *record = [table getRecord:recordId error:&dbError];
		
		if (!record) {
			if (error != NULL) {
				*error = [self errorForDropboxError:dbError];
				
				*stop = YES;
				
				return;
			}
		}
		
		[record deleteRecord];
	}];
	
	[optLockObjecs enumerateObjectsUsingBlock:^(NSManagedObject *object, BOOL *stop) {
		NSString *tableName = [[self class] tableNameFromEntity:object.entity];
		DBTable *table = [self.datastore getTable:tableName];
		NSString *recordId = [self referenceObjectForObjectID:object.objectID];
		
		DBError *dbError;
		DBRecord *record = [table getRecord:recordId error:&dbError];
		
		if (!record) {
			if (error != NULL) {
				*error = [self errorForDropboxError:dbError];
				
				*stop = YES;
				
				return;
			}
		}
		
		incrementRecordVersion(record);
	}];
	
	return @[];
}

#pragma mark - NSPersistentStore

- (NSString *)type {
	return GJBDropboxIncrementalStoreType;
}

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
	if (![self validateURL]) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:GJBDropboxIncrementalStoreErrorDomain
										 code:GJBDropboxIncrementalStoreErrorCodeInvalidURL
									 userInfo:@{
												NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"The URL '%@' is invalid.", nil), self.URL]
												}];
		}
		
		return NO;
	}
	
	[self setupAccountManagerObserver];
	[self openDatastoreAtURL:self.URL];
	
	DBTable *metadataTable = [self.datastore getTable:GJBDropboxIncrementalStoreMetadataTableName];
	NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
	
	DBError *dbError;
	NSArray *records = [metadataTable query:nil error:&dbError];
	
	if (!records) {
		if (error != NULL) {
			*error = [self errorForDropboxError:dbError];
		}
		
		return NO;
	}
	
	if ([records count]) {
		[records enumerateObjectsUsingBlock:^(DBRecord *record, NSUInteger idx, BOOL *stop) {
			NSString *key = record[GJBDropboxIncrementalStoreMetadataNameKey];
			id value = record[GJBDropboxIncrementalStoreMetadataValueKey];
			
			if ([key isEqualToString:NSStoreModelVersionHashesKey]) {
				value = [NSKeyedUnarchiver unarchiveObjectWithData:value];
			}
			
			metadata[key] = value;
		}];
	}
	else {
		metadata[NSStoreUUIDKey] = [[NSUUID UUID] UUIDString];
		metadata[NSStoreTypeKey] = self.type;
		
		NSDictionary *versionHashes = self.persistentStoreCoordinator.managedObjectModel.entityVersionHashesByName;
		NSData *versionHashesData = [NSKeyedArchiver archivedDataWithRootObject:versionHashes];
		
		metadata[NSStoreModelVersionHashesKey] = versionHashesData;
		
		// TODO: Migrate this to a -saveMetadata method.
		[metadata enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
			[metadataTable insert:@{
									GJBDropboxIncrementalStoreMetadataNameKey: key,
									GJBDropboxIncrementalStoreMetadataValueKey: obj
									}];
		}];
	}
	
	[self setMetadata:metadata];
	
	return YES;
}

#pragma mark - NSIncrementalStore

- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
	if (request.requestType == NSFetchRequestType) {
		NSFetchRequest *fetchRequest = (NSFetchRequest *)request;
		
		return [self executeFetchRequest:fetchRequest withContext:context error:error];
	}
	else if (request.requestType == NSSaveRequestType) {
		NSSaveChangesRequest *saveRequest = (NSSaveChangesRequest *)request;
		
		return [self executeSaveRequest:saveRequest withContext:context error:error];
	}
	
	return nil;
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
	NSString *recordId = [self referenceObjectForObjectID:objectID];
	
	NSString *tableName = [[self class] tableNameFromEntity:objectID.entity];
	DBTable *table = [self.datastore getTable:tableName];
	
	DBError *dbError;
	DBRecord *record = [table getRecord:recordId error:&dbError];
	
	if (!record) {
		if (error != NULL) {
			*error = [self errorForDropboxError:dbError];
		}
		
		return nil;
	}
	
	NSMutableDictionary *fields = [record.fields mutableCopy];
	uint64_t version = [record[GJBDropboxIncrementalStoreVersionKey] integerValue];
	
	NSEntityDescription *entityDescription = objectID.entity;
	[entityDescription.relationshipsByName enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSRelationshipDescription *relationship, BOOL *stop) {
		if (relationship.isToMany) {
			return;
		}
		
		NSString *aRecordID = fields[name];
		fields[name] = [self newObjectIDForEntity:relationship.destinationEntity referenceObject:aRecordID];
	}];
	
	return [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:fields version:version];
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError *__autoreleasing *)error {
	NSMutableArray *objectIDs = [NSMutableArray array];
	
	[array enumerateObjectsUsingBlock:^(NSManagedObject *managedObject, NSUInteger idx, BOOL *stop) {
		NSString *tableName = [[self class] tableNameFromEntity:managedObject.entity];
		DBTable *table = [self.datastore getTable:tableName];
		
		DBRecord *record = [table insert:@{ }];
		NSManagedObjectID *objectID = [self newObjectIDForEntity:managedObject.entity referenceObject:record.recordId];
		
		[objectIDs addObject:objectID];
	}];
	
	return objectIDs;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
	NSString *relationshipName = relationship.name;
	
	NSString *tableName = [[self class] tableNameFromEntity:objectID.entity];
	DBTable *table = [self.datastore getTable:tableName];
	
	NSString *recordId = [self referenceObjectForObjectID:objectID];
	
	DBError *dbError;
	DBRecord *record = [table getRecord:recordId error:&dbError];
	
	if (!record) {
		if (error != NULL) {
			*error = [self errorForDropboxError:dbError];
		}
		
		return nil;
	}
	
	if (relationship.isToMany) {
		DBList *list = [record getOrCreateList:relationshipName];
		
		NSMutableArray *objectIDs = [NSMutableArray array];
		[list.values enumerateObjectsUsingBlock:^(NSString *aRecordID, NSUInteger idx, BOOL *stop) {
			NSManagedObjectID *objectID = [self newObjectIDForEntity:relationship.destinationEntity referenceObject:aRecordID];
			[objectIDs addObject:objectID];
		}];
		
		return objectIDs;
	}
	else {
		NSString *aRecordID = record[relationshipName];
		
		if (aRecordID) {
			return [self newObjectIDForEntity:relationship.destinationEntity referenceObject:aRecordID];
		}
		else {
			return [NSNull null];
		}
	}
}

@end
