//
//  AppDelegate.h
//  QuickRadar
//
//  Created by Amy Worrall on 15/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define GlobalHotkeyName @"hotkey"

@class QRRadar;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSMenu *menu;

- (IBAction)showPreferencesWindow:(id)sender;
- (IBAction)showDuplicateWindow:(id)sender;

- (IBAction)newBug:(id)sender;
- (IBAction)bugWindowControllerSubmissionComplete:(id)sender;
- (IBAction)activateAndShowAbout:(id)sender;
- (void)newBugWithRadar:(QRRadar*)radar;

- (IBAction)goToAppleRadar:(id)sender;
- (IBAction)goToOpenRadar:(id)sender;

- (void)hitHotKey:(id)sender;

@end
