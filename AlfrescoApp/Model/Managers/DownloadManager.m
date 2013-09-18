//
//  DownloadManager.m
//  AlfrescoApp
//
//  Created by Tauseef Mughal on 29/07/2013
//  Copyright (c) 2013 Alfresco. All rights reserved.
//

#import "DownloadManager.h"
#import "Utility.h"
#import "UIAlertView+ALF.h"

static NSString *const kDownloadsInfoDirectory = @"downloads/info";
static NSString *const kDownloadsContentDirectory = @"downloads/content";

static NSUInteger const kOverwriteConfirmationOptionYes = 0;
static NSUInteger const kOverwriteConfirmationOptionNo = 1;

static NSUInteger const kStreamCopyBufferSize = 16 * 1024;

@interface DownloadManager ()
@property (nonatomic, strong) id<AlfrescoSession> alfrescoSession;
@property (nonatomic, strong) AlfrescoFileManager *fileManager;
@end

@implementation DownloadManager

#pragma mark - Public Interface

+ (DownloadManager *)sharedManager
{
    static dispatch_once_t predicate = 0;
    __strong static id sharedObject = nil;
    dispatch_once(&predicate, ^{
        sharedObject = [[self alloc] init];
    });
    return sharedObject;
}

- (void)downloadDocument:(AlfrescoDocument *)document contentPath:(NSString *)contentPath session:(id<AlfrescoSession>)alfrescoSession
{
    if (!document)
    {
        AlfrescoLogError(@"Download operation attempted with nil AlfrescoDocument object");
        return;
    }
    
    // Check source content exists
    if (!contentPath || ![self.fileManager fileExistsAtPath:contentPath])
    {
        // No local source, so the content will need to be downloaded from the Repository
        self.alfrescoSession = alfrescoSession;
        [self downloadDocument:document];
    }
    else
    {
        [self saveDocument:document contentPath:contentPath completionBlock:NULL];
    }
}

- (void)saveDocument:(AlfrescoDocument *)document contentPath:(NSString *)contentPath completionBlock:(DownloadManagerFileSavedBlock)completionBlock
{
    // Check source content exists
    if (contentPath == nil || ![self.fileManager fileExistsAtPath:contentPath])
    {
        AlfrescoLogError(@"Save operation attempted with no valid source document");
    }
    else
    {
        if (![self isDownloadedDocument:contentPath])
        {
            // No existing file, so we're ok to copy from contentPath source to downloads folder
            NSString *filePath;
            NSError *error = nil;
            
            filePath = [self copyToDownloadsFolder:document contentPath:contentPath overwriteExisting:YES error:&error];
            if (filePath != nil)
            {
                displayInformationMessage(NSLocalizedString(@"download.success.message", @"Download succeeded"));
            }
            else
            {
                displayErrorMessage([NSString stringWithFormat:NSLocalizedString(@"error.filefolder.content.failedtodownload", @"Failed to download the file"), error.localizedDescription]);
            }
            
            if (completionBlock != NULL)
            {
                completionBlock(filePath);
            }
        }
        else
        {
            [self displayOverwriteConfirmationWithCompletionBlock:^(NSUInteger buttonIndex, BOOL isCancelButton) {
                NSString *blockFilePath;
                NSError *blockError = nil;
                
                if (buttonIndex == kOverwriteConfirmationOptionYes)
                {
                    // User chose to overwrite existing file
                    blockFilePath = [self copyToDownloadsFolder:document contentPath:contentPath overwriteExisting:YES error:&blockError];
                }
                else
                {
                    // Don't allow overwriting existing content
                    blockFilePath = [self copyToDownloadsFolder:document contentPath:contentPath overwriteExisting:NO error:&blockError];
                }
                
                if (blockFilePath != nil)
                {
                    if ([blockFilePath.lastPathComponent isEqualToString:contentPath.lastPathComponent])
                    {
                        // Filename has not changed
                        displayInformationMessage(NSLocalizedString(@"download.success.message", @"Download succeeded"));
                    }
                    else
                    {
                        // Filename has been suffixed
                        displayInformationMessage([NSString stringWithFormat:NSLocalizedString(@"download.success-as.message", @"Download succeeded"), blockFilePath.lastPathComponent]);
                    }
                }
                else
                {
                    displayErrorMessage([NSString stringWithFormat:NSLocalizedString(@"error.filefolder.content.failedtodownload", @"Failed to download the file"), blockError.localizedDescription]);
                }

                if (completionBlock != NULL)
                {
                    completionBlock(blockFilePath);
                }
            }];
        }
    }
}

/**
 * TODO: There must be a way this be consolidated with the saveDocument:contentPath:completionBlock method above...
 */
- (void)moveFileIntoSecureContainer:(NSString *)absolutePath completionBlock:(DownloadManagerFileSavedBlock)completionBlock
{
    // Check source content exists
    if (absolutePath == nil || ![[NSFileManager defaultManager] fileExistsAtPath:absolutePath])
    {
        AlfrescoLogError(@"Move operation attempted with no valid source document");
    }
    else
    {
        if (![self isDownloadedDocument:absolutePath.lastPathComponent])
        {
            // No existing file of the same name, so we're ok to use the original
            NSString *filePath;
            NSError *error = nil;
            
            filePath = [self moveFileToDownloadsFolderFromAbsolutePath:absolutePath overwriteExisting:YES error:&error];
            if (filePath != nil)
            {
                // Always display the filename
                displayInformationMessage([NSString stringWithFormat:NSLocalizedString(@"download.success-as.message", @"Download succeeded"), filePath.lastPathComponent]);
            }
            else
            {
                displayErrorMessage([NSString stringWithFormat:NSLocalizedString(@"error.filefolder.content.failedtodownload", @"Failed to download the file"), error.localizedDescription]);
            }
            
            if (completionBlock != NULL)
            {
                completionBlock(filePath);
            }
        }
        else
        {
            [self displayOverwriteConfirmationWithCompletionBlock:^(NSUInteger buttonIndex, BOOL isCancelButton) {
                NSString *blockFilePath;
                NSError *blockError = nil;
                
                if (buttonIndex == kOverwriteConfirmationOptionYes)
                {
                    // User chose to overwrite existing file
                    blockFilePath = [self moveFileToDownloadsFolderFromAbsolutePath:absolutePath overwriteExisting:YES error:&blockError];
                }
                else
                {
                    // Don't allow overwriting existing content
                    blockFilePath = [self moveFileToDownloadsFolderFromAbsolutePath:absolutePath overwriteExisting:NO error:&blockError];
                }
                
                if (blockFilePath != nil)
                {
                    // Always display the filename
                    displayInformationMessage([NSString stringWithFormat:NSLocalizedString(@"download.success-as.message", @"Download succeeded"), blockFilePath.lastPathComponent]);
                }
                else
                {
                    displayErrorMessage([NSString stringWithFormat:NSLocalizedString(@"error.filefolder.content.failedtodownload", @"Failed to download the file"), blockError.localizedDescription]);
                }
                
                if (completionBlock != NULL)
                {
                    completionBlock(blockFilePath);
                }
            }];
        }
    }
}

- (void)removeFromDownloads:(NSString *)filePath
{
    NSString *fileName = [filePath lastPathComponent];
    NSError *error = nil;
    NSString *downloadPath = [[self downloadedDocumentsContentDirectory] stringByAppendingPathComponent:fileName];
    
    [self.fileManager removeItemAtPath:downloadPath error:&error];
    
    if (!error)
    {
        [self removeDocumentInfo:fileName];
    }
    else
    {
        displayErrorMessage(NSLocalizedString(@"download.delete.failure.message", @"Download delete failure"));
    }
}

- (BOOL)isDownloadedDocument:(NSString *)filePath
{
    NSString *downloadPath = [self.downloadedDocumentsContentDirectory stringByAppendingPathComponent:filePath.lastPathComponent];
    return [self.fileManager fileExistsAtPath:downloadPath];
}

- (AlfrescoDocument *)infoForDocument:(NSString *)documentName
{
    NSString *downloadInfoPath = [[self downloadedDocumentsInfoDirectory] stringByAppendingPathComponent:[documentName lastPathComponent]];
    NSData *unarchivedDoc = [self.fileManager dataWithContentsOfURL:[NSURL fileURLWithPath:downloadInfoPath]];
    AlfrescoDocument *document = nil;
    
    if (unarchivedDoc)
    {
        document = [NSKeyedUnarchiver unarchiveObjectWithData:unarchivedDoc];
    }
    
    return document;
}

- (NSString *)downloadedDocumentsInfoDirectory
{
    NSString *infoDirectory = [self.fileManager.homeDirectory stringByAppendingPathComponent:kDownloadsInfoDirectory];
    BOOL isDirectory;
    BOOL dirExists = [self.fileManager fileExistsAtPath:kDownloadsInfoDirectory isDirectory:&isDirectory];
    NSError *error = nil;
    
    if (!dirExists)
    {
        [self.fileManager createDirectoryAtPath:infoDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    return infoDirectory;
}

- (NSString *)downloadedDocumentsContentDirectory
{
    NSString *contentDirectory = [self.fileManager.homeDirectory stringByAppendingPathComponent:kDownloadsContentDirectory];
    BOOL isDirectory;
    BOOL dirExists = [self.fileManager fileExistsAtPath:contentDirectory isDirectory:&isDirectory];
    NSError *error = nil;
    
    if (!dirExists)
    {
        [self.fileManager createDirectoryAtPath:contentDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    return contentDirectory;
}

- (NSArray *)downloadedDocumentPaths
{
    __block NSMutableArray *documents = [NSMutableArray array];
    NSError *enumeratorError = nil;
    
    [self.fileManager enumerateThroughDirectory:self.downloadedDocumentsContentDirectory includingSubDirectories:NO withBlock:^(NSString *fullFilePath) {
        BOOL isDirectory;
        [self.fileManager fileExistsAtPath:fullFilePath isDirectory:&isDirectory];
        
        if (!isDirectory)
        {
            [documents addObject:fullFilePath];
        }
    } error:&enumeratorError];
    
    NSSortDescriptor *sortOrder = [NSSortDescriptor sortDescriptorWithKey:nil ascending:YES comparator:^NSComparisonResult(id firstDocument, id secondDocument) {
        return [firstDocument caseInsensitiveCompare:secondDocument];
    }];
    
    return [documents sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortOrder]];
}

- (NSString *)updateDownloadedDocument:(AlfrescoDocument *)document withContentsOfFileAtPath:(NSString *)filePath
{
    NSError *updateError = nil;
    NSString *savedFilePath = [self copyToDownloadsFolder:document contentPath:filePath overwriteExisting:YES error:&updateError];
    
    if (updateError)
    {
        AlfrescoLogError(@"Error updating downloads. Error: %@", updateError.localizedDescription);
    }
    
    return savedFilePath;
}

#pragma mark - Private Interface

- (id)init
{
    self = [super init];
    if (self)
    {
        self.fileManager = [AlfrescoFileManager sharedManager];
    }
    return self;
}

// Returns the filePath the content was saved to, or nil if an error occurred
- (NSString *)copyToDownloadsFolder:(AlfrescoDocument *)document contentPath:(NSString *)contentPath overwriteExisting:(BOOL)overwrite error:(NSError **)error
{
    BOOL copySucceeded = NO;
    NSString *destinationFilename = (overwrite ? contentPath.lastPathComponent : [self safeFilenameBySuffixing:contentPath.lastPathComponent error:error]);
    if (destinationFilename != nil)
    {
        if ([self copyDocumentFrom:contentPath destinationFilename:destinationFilename error:error])
        {
            // Note: we're assuming that there will be no problem saving the metadata if the content saves successfully
            [self saveDocumentInfo:document forDocument:destinationFilename error:nil];
            [Notifier postDocumentDownloadedNotificationWithUserInfo:nil];
            copySucceeded = YES;
        }
    }

    return (copySucceeded ? [self.downloadedDocumentsContentDirectory stringByAppendingPathComponent:destinationFilename] : nil);
}

- (void)downloadDocument:(AlfrescoDocument *)document
{
    // TODO: Handle overwrite existing file case
    NSString *downloadDestinationPath = [self.downloadedDocumentsContentDirectory stringByAppendingPathComponent:document.name];
    NSOutputStream *outputStream = [[AlfrescoFileManager sharedManager] outputStreamToFileAtPath:downloadDestinationPath append:NO];
    AlfrescoDocumentFolderService *documentService = [[AlfrescoDocumentFolderService alloc] initWithSession:self.alfrescoSession];
    
    [documentService retrieveContentOfDocument:document outputStream:outputStream completionBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded)
        {
            // Note: we're assuming that there will be no problem saving the metadata if the content saves successfully
            [self saveDocumentInfo:document forDocument:document.name error:nil];
            displayInformationMessage(NSLocalizedString(@"download.success.message", @"download succeeded"));
            [Notifier postDocumentDownloadedNotificationWithUserInfo:nil];
        }
        else
        {
            // Display an error
            displayErrorMessage([NSString stringWithFormat:NSLocalizedString(@"error.filefolder.content.failedtodownload", @"Failed to download the file"), error.localizedDescription]);
        }
    } progressBlock:^(unsigned long long bytesTransferred, unsigned long long bytesTotal) {
        // TODO: Progress indicator update
    }];
}

- (BOOL)copyDocumentFrom:(NSString *)filePath destinationFilename:(NSString *)destinationFilename error:(NSError **)error
{
    NSString *downloadPath = [self.downloadedDocumentsContentDirectory stringByAppendingPathComponent:destinationFilename];

    [self.fileManager copyItemAtPath:filePath toPath:downloadPath error:error];

    return (error == NULL || *error == nil);
}

- (NSString *)moveFileToDownloadsFolderFromAbsolutePath:(NSString *)absolutePath overwriteExisting:(BOOL)overwrite error:(NSError **)error
{
    BOOL moveSucceeded = NO;
    NSString *destinationFilename = (overwrite ? absolutePath.lastPathComponent : [self safeFilenameBySuffixing:absolutePath.lastPathComponent error:error]);
    NSString *destinationFilePath = nil;
    if (destinationFilename != nil)
    {
        NSString *downloadPath = [self.downloadedDocumentsContentDirectory stringByAppendingPathComponent:destinationFilename];
        NSOutputStream *outputStream = [[AlfrescoFileManager sharedManager] outputStreamToFileAtPath:downloadPath append:NO];
        
        if (outputStream)
        {
            [outputStream open];
            if ([outputStream hasSpaceAvailable])
            {
                NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:absolutePath];
                if (inputStream)
                {
                    // Assume success unless an error occurs during copying...
                    moveSucceeded = YES;
                    [inputStream open];
                    
                    while ([inputStream hasBytesAvailable])
                    {
                        uint8_t buffer[kStreamCopyBufferSize];
                        [inputStream read:buffer maxLength:kStreamCopyBufferSize];
                        if ([outputStream write:(const uint8_t*)(&buffer) maxLength:kStreamCopyBufferSize] == -1)
                        {
                            moveSucceeded = NO;
                            break;
                        }
                    }
                    [inputStream close];
                }
            }
            [outputStream close];
        }
      
        if (moveSucceeded)
        {
            // Note: if overwriting then make sure any existing saved documentInfo is removed
            if (overwrite)
            {
                [self saveDocumentInfo:nil forDocument:destinationFilename error:nil];
            }
            destinationFilePath = [self.downloadedDocumentsContentDirectory stringByAppendingPathComponent:destinationFilename];
            [Notifier postDocumentDownloadedNotificationWithUserInfo:@{kAlfrescoDocumentDownloadedIdentifierKey : destinationFilePath}];
        }
    }
    
    return destinationFilePath;
}

- (BOOL)saveDocumentInfo:(AlfrescoDocument *)document forDocument:(NSString *)documentName error:(NSError **)error
{
    NSString *downloadInfoPath = [self.downloadedDocumentsInfoDirectory stringByAppendingPathComponent:documentName.lastPathComponent];
    
    if (document != nil)
    {
        NSData *archivedDoc = [NSKeyedArchiver archivedDataWithRootObject:document];
        [self.fileManager createFileAtPath:downloadInfoPath contents:archivedDoc error:error];
    }
    else
    {
        // Remove any old info file for the documentName - we don't want to return stale info
        [self.fileManager removeItemAtPath:downloadInfoPath error:error];
    }
    
    return (error == NULL || *error == nil);
}

- (BOOL)removeDocumentInfo:(NSString *)documentName
{
    NSString *downloadInfoPath = [self.downloadedDocumentsInfoDirectory stringByAppendingPathComponent:documentName.lastPathComponent];
    NSError *error = nil;

    [self.fileManager removeItemAtPath:downloadInfoPath error:&error];
    
    return error == nil;
}

// Returns just the filenames of downloaded documents
- (NSArray *)downloadedDocumentNames
{
    NSArray *downloadedDocumentPaths = self.downloadedDocumentPaths;
    NSMutableArray *documents = [NSMutableArray arrayWithCapacity:downloadedDocumentPaths.count];
    for (NSString *path in downloadedDocumentPaths)
    {
        [documents addObject:path.lastPathComponent];
    }
    return documents;
}

- (NSString *)safeFilenameBySuffixing:(NSString *)filename error:(NSError **)error
{
    NSString *fileExtension = filename.pathExtension;
    NSString *filenameWithoutExtension = filename.stringByDeletingPathExtension;
    BOOL hasExtension = ![fileExtension isEqualToString:@""];
    NSArray *existingFiles = [self downloadedDocumentNames];
    // We'll bail out after kFileSuffixMaxAttempts attempts
    NSUInteger suffix = 0;
    NSString *safeFilename = filename;
    
    if (hasExtension)
    {
        while ([existingFiles containsObject:safeFilename] && (++suffix < kFileSuffixMaxAttempts))
        {
            safeFilename = [NSString stringWithFormat:@"%@-%u.%@", filenameWithoutExtension, suffix, fileExtension];
        }
    }
    else
    {
        while ([existingFiles containsObject:safeFilename] && (++suffix < kFileSuffixMaxAttempts))
        {
            safeFilename = [NSString stringWithFormat:@"%@-%u", filenameWithoutExtension, suffix];
        }
    }
    
    // Did we hit the max suffix number?
    if (suffix == kFileSuffixMaxAttempts)
    {
        AlfrescoLogError(@"ERROR: Couldn't save downloaded file as kFileSuffixMaxAttempts (%u) reached", kFileSuffixMaxAttempts);
        if (error != NULL)
        {
            *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier]
                                         code:kErrorFileSuffixMaxAttempts
                                     userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"error.description.kErrorFileSuffixMaxAttempts", @"Couldn't generate a unique filename") }];
        }
        return nil;
    }
    
    return safeFilename;
}

- (void)displayOverwriteConfirmationWithCompletionBlock:(UIAlertViewDismissBlock)completionBlock
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"download.overwrite.prompt.title", @"overwite alert title")
                                                    message:NSLocalizedString(@"download.overwrite.prompt.message", @"overwrite alert message")
                                                   delegate:nil
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"Yes", @"Yes"), NSLocalizedString(@"No", @"No"), nil];
    [alert showWithCompletionBlock:completionBlock];
}

@end