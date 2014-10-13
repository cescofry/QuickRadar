//
//  RadarSubmission.m
//  QuickRadar
//
//  Created by Amy Worrall on 15/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "QRSubmissionController.h"
#import "QRSubmissionService.h"
#import "QRRadarSubmissionService.h"

@interface QRSubmissionController ()

@property (nonatomic, strong) NSMutableSet *completed;
@property (nonatomic, strong) NSMutableSet *inProgress;
@property (nonatomic, strong) NSMutableSet *waiting;

@property (nonatomic, copy) void (^progressBlock)() ;
@property (nonatomic, copy) void (^completionBlock)(BOOL, NSError *) ;
@property (assign) BOOL hasFiredCompletionBlock;

@end

@implementation QRSubmissionController


@synthesize radar = _radar;
@synthesize completed = _completed, inProgress = _inProgress, waiting = _waiting;
@synthesize progressBlock = _progressBlock, completionBlock = _completionBlock;
@synthesize hasFiredCompletionBlock = _hasFiredCompletionBlock;


- (void)startWithProgressBlock:(void (^)())progressBlock completionBlock:(void (^)(BOOL, NSError *))completionBlock
{
	if (!self.radar)
	{
		completionBlock(NO, [NSError errorWithDomain:@"No radar object" code:0 userInfo:nil]);
		return;
	}
	
	self.progressBlock = progressBlock;
	self.completionBlock = completionBlock;

	self.completed = [NSMutableSet set];
	self.inProgress = [NSMutableSet set];
	self.waiting = [NSMutableSet set];
	
	if (self.submitDraft) {
		// Special case drafts to just submit radar
		QRRadarSubmissionService *service = [[QRRadarSubmissionService alloc] init];
		service.radar = self.radar;
		service.submissionWindow = self.submissionWindow;
		service.submitDraft = YES;
		[self.waiting addObject:service];
	} else {
		NSDictionary *services = [QRSubmissionService services];
		
		for (NSString *serviceID in services)
		{
			Class serviceClass = services[serviceID];
			
			if (![serviceClass isAvailable])
			{
				NSLog(@"%@ not available", serviceID);
				continue;
			}
			
			if ([serviceClass requireCheckBox])
			{
				if ([(self.requestedOptionalServices)[serviceID] boolValue] == NO)
				{
					NSLog(@"%@ not requested", serviceID);
					continue;
				}
			}
			
			QRSubmissionService *service = [[serviceClass alloc] init];
			service.radar = self.radar;
			service.submissionWindow = self.submissionWindow;
			
			[self.waiting addObject:service];
		}
	}

	[self startNextAvailableServices];
}

- (void)startNextAvailableServices;
{
	for (QRSubmissionService *service in [self.waiting copy])
	{
		NSSet *hardDeps = [[service class] hardDependencies];
        BOOL hasFailedHardDeps = [self hasFailedHardDependencies:hardDeps fromCompletedServices:[self.completed copy]];
		
        NSSet *softDeps = [[service class] softDependencies];
        BOOL hasFailedSoftDeps = [self hasFailedSoftDependencies:softDeps fromWaitingServices:[self.waiting setByAddingObjectsFromSet:self.inProgress]];
		
		if (hasFailedHardDeps || hasFailedSoftDeps)
		{
			continue;
		}
		
        // Hopefully fix the OpenRadar multiple submissions bug
        @synchronized(self)
        {
            if (![self.waiting containsObject:service])
            {
                continue;
            }
            [self processService:service];
        }
        
	}
	
	if (self.inProgress.count == 0 && self.waiting.count == 0 && !self.hasFiredCompletionBlock)
	{
		self.hasFiredCompletionBlock = YES;
		self.completionBlock(YES, nil);
	}
}


- (void)processService:(QRSubmissionService *)service
{
    [self.inProgress addObject:service];
    [self.waiting removeObject:service];
    
    [service submitAsyncWithProgressBlock:^{
        self.progressBlock();
    } completionBlock:^(BOOL success, NSError *error) {
        [self.inProgress removeObject:service];
        [self.completed addObject:service];
        
        if (!success)
        {
            NSLog(@"Failure by %@", [[service class] identifier]);
            self.hasFiredCompletionBlock = YES;
            self.completionBlock(NO, error);
        }
        else
        {
            [self startNextAvailableServices];
        }
        
    }];
}


/* Check hard deps */
// For a hard dep, if the service in question is NOT completed, it fails.

- (BOOL)hasFailedHardDependencies:(NSSet *)hardDependencies fromCompletedServices:(NSSet *)completedServices
{
    BOOL hasFailedDeps = NO;

    for (NSString *serviceID in hardDependencies)
    {
        BOOL metThisDep = NO;
        for (QRSubmissionService *testService in completedServices)
        {
            if ([[[testService class] identifier] isEqualToString:serviceID])
            {
                metThisDep = YES;
            }
        }
        if (!metThisDep)
        {
            hasFailedDeps = YES;
        }
    }
    
    return hasFailedDeps;
}


// TODO: decide what you're doing about serviceStatus -- either use it here, or remove it everywhere.

/* Check soft deps */
// For a soft dep, if the service in question is present and not finished, it fails.

- (BOOL)hasFailedSoftDependencies:(NSSet *)softDependencies fromWaitingServices:(NSSet *)waitingServices
{

    BOOL hasFailedDeps = NO;
    for (NSString *serviceID in softDependencies)
    {
        for (QRSubmissionService *testService in waitingServices)
        {
            if ([[[testService class] identifier] isEqualToString:serviceID])
            {
                hasFailedDeps = YES;
            }
        }
    }
    
    return hasFailedDeps;
}


- (CGFloat)progress
{
	CGFloat number = self.waiting.count + self.inProgress.count + self.completed.count;
    CGFloat accumulator = [[self.inProgress valueForKeyPath:@"@sum.progress"] floatValue] + self.completed.count;
		
	return accumulator/number;
}

- (NSString *)statusText
{
    NSMutableString *overallStatus = nil;
    
	for (QRSubmissionService *service in self.inProgress)
	{
        NSString *serviceStatus = service.statusText;
        if (serviceStatus == nil)
            continue;
        if (overallStatus == nil)
            overallStatus = [serviceStatus mutableCopy];
        else
            [overallStatus appendFormat:@"; %@", serviceStatus];
	}
    
    return overallStatus;
}

@end
