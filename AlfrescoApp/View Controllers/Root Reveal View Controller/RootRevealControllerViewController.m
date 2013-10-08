//
//  RootRevealControllerViewController.m
//  AlfrescoApp
//
//  Created by Tauseef Mughal on 30/09/2013.
//  Copyright (c) 2013 Alfresco. All rights reserved.
//

#import "RootRevealControllerViewController.h"

static CGFloat kDeviceSpecificRevealWidth;
static const CGFloat kPadRevealWidth = 50.0f;
static const CGFloat kPhoneRevealWidth = 0.0f;
static const CGFloat kMasterViewWidth = 300.0f;
static const CGFloat kAnimationSpeed = 0.2f;

@interface RootRevealControllerViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong, readwrite) UIViewController *masterViewController;
@property (nonatomic, strong, readwrite) UIViewController *detailViewController;
@property (nonatomic, strong) UIView *masterViewContainer;
@property (nonatomic, strong) UIView *detailViewContainer;
@property (nonatomic, assign) BOOL isExpanded;

@property (nonatomic, assign) CGRect dragStartRect;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, assign) BOOL shouldExpandOrCollapse;

@end

@implementation RootRevealControllerViewController

- (instancetype)initWithMasterViewController:(UIViewController *)masterViewController detailViewController:(UIViewController *)detailViewController
{
    self = [super init];
    if (self)
    {
        self.masterViewController = masterViewController;
        self.detailViewController = detailViewController;
        kDeviceSpecificRevealWidth = (IS_IPAD) ? kPadRevealWidth : kPhoneRevealWidth;
    }
    return self;
}

- (void)loadView
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    UIView *view = [[UIView alloc] initWithFrame:screenBounds];
    
    UIView *masterViewContainer = [[UIView alloc] initWithFrame:CGRectMake(screenBounds.origin.x,
                                                                           screenBounds.origin.y,
                                                                           kMasterViewWidth,
                                                                           screenBounds.size.height)];
    masterViewContainer.autoresizesSubviews = YES;
    masterViewContainer.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [view addSubview:masterViewContainer];
    self.masterViewContainer = masterViewContainer;
    
    UIView *detailViewContainer = [[UIView alloc] initWithFrame:screenBounds];
    detailViewContainer.autoresizesSubviews = YES;
    detailViewContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    detailViewContainer.backgroundColor = [UIColor underPageBackgroundColor];
    [view addSubview:detailViewContainer];
    self.detailViewContainer = detailViewContainer;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapGesture.numberOfTapsRequired = 1;
    tapGesture.numberOfTouchesRequired = 1;
    tapGesture.delegate = self;
    self.tapGesture = tapGesture;
    [self.detailViewContainer addGestureRecognizer:tapGesture];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panGesture.delegate = self;
    self.panGesture = panGesture;
    [self.detailViewContainer addGestureRecognizer:panGesture];
    
    [view bringSubviewToFront:detailViewContainer];
    view.backgroundColor = [UIColor underPageBackgroundColor];
    
    view.autoresizesSubviews = YES;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.masterViewController)
    {
        self.masterViewController.view.frame = self.masterViewContainer.frame;
        [self addChildViewController:self.masterViewController];
        [self.masterViewContainer addSubview:self.masterViewController.view];
        [self.masterViewController didMoveToParentViewController:self];
    }
    
    if (self.detailViewController)
    {
        self.detailViewController.view.frame = self.detailViewContainer.frame;
        [self addChildViewController:self.detailViewController];
        [self.detailViewContainer addSubview:self.detailViewController.view];
        [self.detailViewController didMoveToParentViewController:self];
    }
    
    [self positionViews];
}

#pragma mark - Public Functions

- (void)expandViewController
{
    if (!self.isExpanded)
    {
        [UIView animateWithDuration:kAnimationSpeed delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            CGRect detailFrame = self.detailViewContainer.frame;
            detailFrame.origin.x = kMasterViewWidth;
            self.detailViewContainer.frame = detailFrame;
        } completion:^(BOOL finished) {
            self.isExpanded = YES;
        }];
    }
}

- (void)collapseViewController
{
    if (self.isExpanded)
    {
        [UIView animateWithDuration:kAnimationSpeed delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            CGRect detailFrame = self.detailViewContainer.frame;
            if (IS_IPAD)
            {
                detailFrame.origin.x = kDeviceSpecificRevealWidth;
            }
            else
            {
                detailFrame.origin.x = 0;
            }
            self.detailViewContainer.frame = detailFrame;
        } completion:^(BOOL finished) {
            self.isExpanded = NO;
        }];
    }
}

#pragma mark - Private Functions

- (void)positionViews
{
    if (IS_IPAD)
    {
        CGRect detailFrame = self.detailViewContainer.frame;
        detailFrame.origin.x = kDeviceSpecificRevealWidth;
        detailFrame.size.width += kMasterViewWidth - kDeviceSpecificRevealWidth;
        self.detailViewContainer.frame = detailFrame;
    }
    else
    {
        CGRect detailFrame = self.detailViewContainer.frame;
        detailFrame.origin.x = 0;
        self.detailViewContainer.frame = detailFrame;
    }
    self.isExpanded = NO;
}

- (void)handlePan:(UIPanGestureRecognizer *)panGesture
{
    if (panGesture.state == UIGestureRecognizerStateBegan)
    {
        self.dragStartRect = self.detailViewContainer.frame;
    }
    else if (panGesture.state == UIGestureRecognizerStateChanged)
    {
        CGPoint translation = [panGesture translationInView:self.view];
        
        if (translation.x > 0)
        {
            if (translation.x > kDeviceSpecificRevealWidth)
            {
                self.detailViewContainer.frame = CGRectMake(self.dragStartRect.origin.x + translation.x,
                                                            self.dragStartRect.origin.y,
                                                            self.detailViewContainer.frame.size.width,
                                                            self.detailViewContainer.frame.size.height);
                self.shouldExpandOrCollapse = translation.x > (kMasterViewWidth / 3);
            }
        }
        else
        {
            if (translation.x < kDeviceSpecificRevealWidth)
            {
                self.detailViewContainer.frame = CGRectMake(self.dragStartRect.origin.x + translation.x,
                                                            self.dragStartRect.origin.y,
                                                            self.detailViewContainer.frame.size.width,
                                                            self.detailViewContainer.frame.size.height);
                self.shouldExpandOrCollapse = (translation.x * -1) > (kMasterViewWidth / 3);
            }
        }
    }
    else if (panGesture.state == UIGestureRecognizerStateEnded)
    {
        if (self.shouldExpandOrCollapse)
        {
            if (!self.isExpanded)
            {
                [self expandViewController];
            }
            else if (self.isExpanded)
            {
                [self collapseViewController];
            }
        }
        else
        {
            [UIView animateWithDuration:kAnimationSpeed delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.detailViewContainer.frame = self.dragStartRect;
            } completion:^(BOOL finished) {}];
        }
    }
}

- (void)handleTap:(UITapGestureRecognizer *)tapGesture
{
    [self collapseViewController];
}

#pragma mark - UIPanGestureRecognizerDelegate Functions

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    BOOL shouldBegin = NO;
    if (gestureRecognizer == self.tapGesture)
    {
        if (self.isExpanded)
        {
            shouldBegin = YES;
        }
    }
    else if (gestureRecognizer == self.panGesture)
    {
        UIPanGestureRecognizer *localPanGesture = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint translation = [localPanGesture translationInView:[self.detailViewContainer superview]];
        if ((translation.x > 0 && !self.isExpanded) || (translation.x < 0 && self.isExpanded))
        {
            shouldBegin = YES;
        }
    }
    return shouldBegin;
}

@end