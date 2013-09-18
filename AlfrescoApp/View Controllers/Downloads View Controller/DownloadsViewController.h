//
//  DownloadsViewController.h
//  AlfrescoApp
//
//  Created by Tauseef Mughal on 29/07/2013
//  Copyright (c) 2013 Alfresco. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ParentListViewController.h"
#import "MultiSelectActionsToolbar.h"

@protocol DownloadsPickerDelegate <NSObject>
@optional
- (void)downloadPicker:(id)picker didPickDocument:(NSString *)documentPath;
- (void)downloadPickerDidCancel;
@end

@interface DownloadsViewController : ParentListViewController <MultiSelectActionsDelegate, UIActionSheetDelegate>

@property (nonatomic) BOOL isDownloadPickerEnabled;
@property (nonatomic, weak) id <DownloadsPickerDelegate> downloadPickerDelegate;

@end