//
//  NCAccount.m
//  Neocom
//
//  Created by Admin on 04.01.14.
//  Copyright (c) 2014 Artem Shimanski. All rights reserved.
//

#import "NCAccount.h"
#import "NCStorage.h"
#import "NCCache.h"
#import "EVEDBInvType.h"

#define NCAccountSkillPointsUpdateInterval (60.0 * 10.0)

static NCAccount* currentAccount = nil;

@interface NCAccount()
@property (nonatomic, strong) NCCacheRecord* characterInfoCacheRecord;
@property (nonatomic, strong) NCCacheRecord* characterSheetCacheRecord;
@property (nonatomic, strong) NCCacheRecord* corporationSheetCacheRecord;
@property (nonatomic, strong) NCCacheRecord* skillQueueCacheRecord;

@property (nonatomic, strong, readwrite) EVECharacterInfo* characterInfo;
@property (nonatomic, strong, readwrite) EVECharacterSheet* characterSheet;
@property (nonatomic, strong, readwrite) EVECorporationSheet* corporationSheet;
@property (nonatomic, strong, readwrite) EVESkillQueue* skillQueue;

@property (nonatomic, strong) NSDate* lastSkillPointsUpdate;

@end

@implementation NCAccount

@dynamic characterID;
@dynamic order;
@dynamic apiKey;
@dynamic skillPlans;
@dynamic mailBox;
@dynamic uuid;

@synthesize characterInfoCacheRecord = _characterInfoCacheRecord;
@synthesize characterSheetCacheRecord = _characterSheetCacheRecord;
@synthesize corporationSheetCacheRecord = _corporationSheetCacheRecord;
@synthesize skillQueueCacheRecord = _skillQueueCacheRecord;
@synthesize error = _error;
@synthesize characterAttributes = _characterAttributes;
@synthesize lastSkillPointsUpdate = _lastSkillPointsUpdate;
@synthesize activeSkillPlan = _activeSkillPlan;

+ (NSArray*) allAccounts {
	NCStorage* storage = [NCStorage sharedStorage];
	NSManagedObjectContext* context = storage.managedObjectContext;
	
	__block NSArray* accounts = nil;
	[context performBlockAndWait:^{
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"Account" inManagedObjectContext:context];
		[fetchRequest setEntity:entity];
		[fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"order" ascending:YES], [NSSortDescriptor sortDescriptorWithKey:@"characterID" ascending:YES]]];
		
		accounts = [context executeFetchRequest:fetchRequest error:nil];
	}];
	return accounts;
}

+ (instancetype) currentAccount {
	@synchronized(self) {
		return currentAccount;
	}
}

+ (instancetype) accountWithUUID:(NSString*) uuid {
	NCStorage* storage = [NCStorage sharedStorage];
	NSManagedObjectContext* context = storage.managedObjectContext;
	
	__block NSArray* accounts = nil;
	[context performBlockAndWait:^{
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"Account" inManagedObjectContext:context];
		[fetchRequest setEntity:entity];
		fetchRequest.predicate = [NSPredicate predicateWithFormat:@"uuid == %@", uuid];
		accounts = [context executeFetchRequest:fetchRequest error:nil];
	}];
	return accounts.count > 0 ? accounts[0] : nil;
}

+ (void) setCurrentAccount:(NCAccount*) account {
	@synchronized(self) {
		currentAccount = account;
		[[NSNotificationCenter defaultCenter] postNotificationName:NCAccountDidChangeNotification object:account];
		if (account) {
			[[NSUserDefaults standardUserDefaults] setValue:account.uuid forKey:NCSettingsCurrentAccountKey];
		}
		else
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:NCSettingsCurrentAccountKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void) awakeFromInsert {
	self.mailBox = [[NCMailBox alloc] initWithEntity:[NSEntityDescription entityForName:@"MailBox" inManagedObjectContext:self.managedObjectContext]
					  insertIntoManagedObjectContext:self.managedObjectContext];
}

- (void) willSave {
	if ([self isDeleted]) {
		NCCache* cache = [NCCache sharedCache];
		NSManagedObjectContext* context = cache.managedObjectContext;
		[context performBlock:^{
			NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
			NSEntityDescription *entity = [NSEntityDescription entityForName:@"Record" inManagedObjectContext:context];
			[fetchRequest setEntity:entity];
			[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"recordID like %@", [NSString stringWithFormat:@"*%@*", self.uuid]]];

			NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:nil];
			for (NCCacheRecord* record in fetchedObjects)
				[cache.managedObjectContext deleteObject:record];

			[cache saveContext];
		}];
	}
	
	[super willSave];
}

- (BOOL) reloadWithCachePolicy:(NSURLRequestCachePolicy) cachePolicy error:(NSError**) errorPtr progressHandler:(void(^)(CGFloat progress, BOOL* stop)) progressHandler {
	if ([NSThread isMainThread])
		return NO;
	
	__block BOOL shouldStop = NO;
	NSError* characterInfoError = nil;
	EVECharacterInfo* characterInfo = self.accountType == NCAccountTypeCharacter ? [EVECharacterInfo characterInfoWithKeyID:self.apiKey.keyID
																													  vCode:self.apiKey.vCode
																												cachePolicy:NSURLRequestUseProtocolCachePolicy
																												characterID:self.characterID
																													  error:&characterInfoError
																											progressHandler:^(CGFloat progress, BOOL *stop) {
																												if (progressHandler) {
																													progressHandler(progress / 4.0f, stop);
																													if (*stop)
																														shouldStop = YES;
																												}
																											}] : nil;
	
	if (shouldStop)
		return NO;
	
	NSError* characterSheetError = nil;
	EVECharacterSheet* characterSheet = self.accountType == NCAccountTypeCharacter ? [EVECharacterSheet characterSheetWithKeyID:self.apiKey.keyID
																														  vCode:self.apiKey.vCode
																													cachePolicy:cachePolicy
																													characterID:self.characterID
																														  error:&characterSheetError
																												progressHandler:^(CGFloat progress, BOOL *stop) {
																													if (progressHandler) {
																														progressHandler((1.0 + progress) / 4.0f, stop);
																														if (*stop)
																															shouldStop = YES;
																													}
																												}] : nil;
	
	if (shouldStop)
		return NO;
	
	NSError* corporationSheetError = nil;
	EVECorporationSheet* corporationSheet = [EVECorporationSheet corporationSheetWithKeyID:self.apiKey.keyID
																					 vCode:self.apiKey.vCode
																			   cachePolicy:cachePolicy
																			   characterID:self.characterID
																			 corporationID:0
																					 error:&corporationSheetError
																		   progressHandler:^(CGFloat progress, BOOL *stop) {
																			   if (progressHandler) {
																				   progressHandler((1.0 + progress) / 4.0f, stop);
																				   if (*stop)
																					   shouldStop = YES;
																			   }
																		   }];
	
	if (shouldStop)
		return NO;

	NSError* skillQueueError = nil;
	EVESkillQueue* skillQueue = self.accountType == NCAccountTypeCharacter ? [EVESkillQueue skillQueueWithKeyID:self.apiKey.keyID
																										  vCode:self.apiKey.vCode
																									cachePolicy:cachePolicy
																									characterID:self.characterID
																										  error:&skillQueueError
																								progressHandler:^(CGFloat progress, BOOL *stop) {
																									if (progressHandler) {
																										progressHandler((1.0 + progress) / 4.0f, stop);
																										if (*stop)
																											shouldStop = YES;
																									}
																								}] : nil;
	
	if (shouldStop)
		return NO;

	if (characterInfo)
		self.characterInfo = characterInfo;
	else if (!self.characterSheetCacheRecord.data)
		self.characterInfo = (id) characterInfoError;
	
	if (characterSheet)
		self.characterSheet = characterSheet;
	else if (!self.characterSheetCacheRecord.data)
		self.characterSheet = (id) characterSheetError;
	
	if (corporationSheet)
		self.corporationSheet = corporationSheet;
	else if (!self.corporationSheetCacheRecord.data)
		self.corporationSheet = (id) corporationSheetError;
	
	if (skillQueue)
		self.skillQueue = skillQueue;
	else if (!self.skillQueueCacheRecord.data)
		self.skillQueue = (id) skillQueueError;

	NCCache* cache = [NCCache sharedCache];
	[cache.managedObjectContext performBlockAndWait:^{
		[cache saveContext];
	}];
	
	if (errorPtr) {
		if (characterInfoError)
			*errorPtr = characterInfoError;
		else if (characterSheetError)
			*errorPtr = characterSheetError;
		else if (skillQueueError)
			*errorPtr = skillQueueError;
	}
	_characterAttributes = nil;
	self.lastSkillPointsUpdate = nil;
	
	[self.managedObjectContext performBlockAndWait:^{
		for (NCSkillPlan* skillPlan in self.skillPlans)
			[skillPlan reloadIfNeeded];
	}];
	return YES;
}

- (NCAccountType) accountType {
	return self.apiKey.apiKeyInfo.key.type == EVEAPIKeyTypeCorporation ? NCAccountTypeCorporate : NCAccountTypeCharacter;
}

- (EVECharacterInfo*) characterInfo {
	@synchronized(self) {
		if (!self.characterInfoCacheRecord.data.data)
			[self reloadWithCachePolicy:NSURLRequestUseProtocolCachePolicy error:nil progressHandler:nil];
		return [self.characterInfoCacheRecord.data isKindOfClass:[NSError class]] ? nil : self.characterInfoCacheRecord.data.data;
	}
}

- (EVECharacterSheet*) characterSheet {
	@synchronized(self) {
		if (!self.characterSheetCacheRecord.data.data)
			[self reloadWithCachePolicy:NSURLRequestUseProtocolCachePolicy error:nil progressHandler:nil];
		
		EVECharacterSheet* characterSheet = [self.characterSheetCacheRecord.data.data isKindOfClass:[NSError class]] ? nil : self.characterSheetCacheRecord.data.data;

		if (!_characterAttributes && characterSheet)
			_characterAttributes = [[NCCharacterAttributes alloc] initWithCharacterSheet:characterSheet];
		
		//Update skill points
		EVESkillQueue* skillQueue = self.skillQueue;
		if (characterSheet && skillQueue && (!self.lastSkillPointsUpdate || [self.lastSkillPointsUpdate timeIntervalSinceNow] < -NCAccountSkillPointsUpdateInterval)) {
			[characterSheet updateSkillPointsFromSkillQueue:skillQueue];
			
			if (self.characterInfo) {
				NSInteger skillPoints = 0;
				for (EVECharacterSheetSkill* skill in characterSheet.skills)
					skillPoints += skill.skillpoints;
				self.characterInfo.skillPoints = skillPoints;
			}
			
			self.lastSkillPointsUpdate = [NSDate date];
			
			[self.activeSkillPlan updateSkillPoints];
		}
		
		return characterSheet;
	}
}

- (EVECorporationSheet*) corporationSheet {
	@synchronized(self) {
		if (!self.corporationSheetCacheRecord.data.data)
			[self reloadWithCachePolicy:NSURLRequestUseProtocolCachePolicy error:nil progressHandler:nil];
		return [self.corporationSheetCacheRecord.data.data isKindOfClass:[NSError class]] ? nil : self.corporationSheetCacheRecord.data.data;
	}
}

- (EVESkillQueue*) skillQueue {
	@synchronized(self) {
		if (!self.skillQueueCacheRecord.data.data)
			[self reloadWithCachePolicy:NSURLRequestUseProtocolCachePolicy error:nil progressHandler:nil];
		return [self.skillQueueCacheRecord.data.data isKindOfClass:[NSError class]] ? nil : self.skillQueueCacheRecord.data.data;
	}
}

- (NCCharacterAttributes*) characterAttributes {
	@synchronized(self) {
		if (!_characterAttributes && self.characterSheet) {
			_characterAttributes = [[NCCharacterAttributes alloc] initWithCharacterSheet:self.characterSheet];
		}
		return _characterAttributes;
	}
}

- (void) setCharacterInfo:(EVECharacterInfo *)characterInfo {
	@synchronized(self) {
		self.characterInfoCacheRecord.data.data = characterInfo;
		if ([characterInfo isKindOfClass:[NSError class]]) {
			self.characterInfoCacheRecord.date = [NSDate date];
			self.characterInfoCacheRecord.expireDate = nil;
		}
		else {
			self.characterInfoCacheRecord.date = characterInfo.cacheDate;
			self.characterInfoCacheRecord.expireDate = characterInfo.cacheExpireDate;
		}
	}
}

- (void) setCharacterSheet:(EVECharacterSheet *)characterSheet {
	@synchronized(self) {
		self.characterSheetCacheRecord.data.data = characterSheet;
		if ([characterSheet isKindOfClass:[NSError class]]) {
			self.characterSheetCacheRecord.date = [NSDate date];
			self.characterSheetCacheRecord.expireDate = nil;
		}
		else {
			self.characterSheetCacheRecord.date = characterSheet.cacheDate;
			self.characterSheetCacheRecord.expireDate = characterSheet.cacheExpireDate;
		}
	}
}

- (void) setCorporationSheet:(EVECorporationSheet *)corporationSheet {
	@synchronized(self) {
		self.corporationSheetCacheRecord.data.data = corporationSheet;
		if ([corporationSheet isKindOfClass:[NSError class]]) {
			self.corporationSheetCacheRecord.date = [NSDate date];
			self.corporationSheetCacheRecord.expireDate = nil;
		}
		else {
			self.corporationSheetCacheRecord.date = corporationSheet.cacheDate;
			self.corporationSheetCacheRecord.expireDate = corporationSheet.cacheExpireDate;
		}
	}
}

- (void) setSkillQueue:(EVESkillQueue *)skillQueue {
	@synchronized(self) {
		self.skillQueueCacheRecord.data.data = skillQueue;
		if ([skillQueue isKindOfClass:[NSError class]]) {
			self.skillQueueCacheRecord.date = [NSDate date];
			self.skillQueueCacheRecord.expireDate = nil;
		}
		else {
			self.skillQueueCacheRecord.date = skillQueue.cacheDate;
			self.skillQueueCacheRecord.expireDate = skillQueue.cacheExpireDate;
		}
	}
}

- (NCSkillPlan*) activeSkillPlan {
	@synchronized(self) {
		if (!_activeSkillPlan || [_activeSkillPlan isDeleted]) {
			__block NCSkillPlan* skillPlan = nil;

			NCStorage* storage = [NCStorage sharedStorage];
			[storage.managedObjectContext performBlockAndWait:^{
				if (self.skillPlans.count == 0) {
					skillPlan = [[NCSkillPlan alloc] initWithEntity:[NSEntityDescription entityForName:@"SkillPlan" inManagedObjectContext:self.managedObjectContext]
									 insertIntoManagedObjectContext:self.managedObjectContext];
					skillPlan.active = YES;
					skillPlan.account = self;
					skillPlan.name = NSLocalizedString(@"Default Skill Plan", nil);
				}
				else {
					NSSet* skillPlans = [self.skillPlans filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"active == YES"]];
					if (skillPlans.count == 0) {
						skillPlan = [self.skillPlans anyObject];
						skillPlan.active = YES;
					}
					else if (skillPlans.count > 1) {
						NSMutableSet* set = [[NSMutableSet alloc] initWithSet:skillPlans];
						skillPlan = [set anyObject];
						[set removeObject:skillPlan];
						for (NCSkillPlan* item in set)
							item.active = NO;
					}
					else
						skillPlan = [skillPlans anyObject];
				}
				[storage saveContext];
			}];
			_activeSkillPlan = skillPlan;
		}
		return _activeSkillPlan;
	}
}

- (void) setActiveSkillPlan:(NCSkillPlan *)activeSkillPlan {
	@synchronized(self) {
		[self willChangeValueForKey:@"activeSkillPlan"];
		for (NCSkillPlan* skillPlan in self.skillPlans)
			if (![skillPlan isDeleted])
				skillPlan.active = NO;
		activeSkillPlan.active = YES;
		_activeSkillPlan = activeSkillPlan;
		[self didChangeValueForKey:@"activeSkillPlan"];
	}
}

#pragma mark - Private

- (NCCacheRecord*) characterInfoCacheRecord {
	@synchronized(self) {
		if (!_characterInfoCacheRecord) {
			[[[NCCache sharedCache] managedObjectContext] performBlockAndWait:^{
				_characterInfoCacheRecord = [NCCacheRecord cacheRecordWithRecordID:[NSString stringWithFormat:@"%@.characterInfo", self.uuid]];
				[[_characterInfoCacheRecord data] data];
			}];
		}
		return _characterInfoCacheRecord;
	}
}

- (NCCacheRecord*) characterSheetCacheRecord {
	@synchronized(self) {
		if (!_characterSheetCacheRecord) {
			[[[NCCache sharedCache] managedObjectContext] performBlockAndWait:^{
				_characterSheetCacheRecord = [NCCacheRecord cacheRecordWithRecordID:[NSString stringWithFormat:@"%@.characterSheet", self.uuid]];
				[[_characterSheetCacheRecord data] data];
			}];
		}
		return _characterSheetCacheRecord;
	}
}

- (NCCacheRecord*) corporationSheetCacheRecord {
	@synchronized(self) {
		if (!_corporationSheetCacheRecord) {
			[[[NCCache sharedCache] managedObjectContext] performBlockAndWait:^{
				_corporationSheetCacheRecord = [NCCacheRecord cacheRecordWithRecordID:[NSString stringWithFormat:@"%@.corporationSheet", self.uuid]];
				[[_corporationSheetCacheRecord data] data];
			}];
		}
		return _corporationSheetCacheRecord;
	}
}

- (NCCacheRecord*) skillQueueCacheRecord {
	@synchronized(self) {
		if (!_skillQueueCacheRecord) {
			[[[NCCache sharedCache] managedObjectContext] performBlockAndWait:^{
				_skillQueueCacheRecord = [NCCacheRecord cacheRecordWithRecordID:[NSString stringWithFormat:@"%@.skillQueue", self.uuid]];
				[[_skillQueueCacheRecord data] data];
			}];
		}
		return _skillQueueCacheRecord;
	}
}

@end
