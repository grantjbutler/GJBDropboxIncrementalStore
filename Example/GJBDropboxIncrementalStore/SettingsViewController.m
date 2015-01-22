//
//  SettingsViewController.m
//  GJBDropboxIncrementalStore
//
//  Created by Grant Butler on 1/18/15.
//  Copyright (c) 2015 Grant Butler. All rights reserved.
//

#import "SettingsViewController.h"

#import <Dropbox/Dropbox.h>

@interface SettingsViewController ()

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *logInOutButton;

@end

@implementation SettingsViewController

- (void)viewWillAppear:(BOOL)animated {
	DBAccount *linkedAccount = [DBAccountManager sharedManager].linkedAccount;
	if (linkedAccount) {
		DBAccountInfo *accountInfo = linkedAccount.info;
		self.statusLabel.text = [NSString stringWithFormat:@"You are logged in as %@", accountInfo.displayName];
		[self.logInOutButton setTitle:@"Log Out" forState:UIControlStateNormal];
	}
	else {
		self.statusLabel.text = @"You are not logged in to Dropbox.";
		[self.logInOutButton setTitle:@"Log In" forState:UIControlStateNormal];
	}
}

- (IBAction)tappedButton:(id)sender {
	if ([DBAccountManager sharedManager].linkedAccount) {
		[[DBAccountManager sharedManager].linkedAccount unlink];
	}
	else {
		[[DBAccountManager sharedManager] linkFromController:self];
	}
}

@end
