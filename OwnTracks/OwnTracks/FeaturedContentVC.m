
//
//  FeaturedContentVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 23.01.16.
//  Copyright © 2016-2017 OwnTracks. All rights reserved.
//

#import "FeaturedContentVC.h"
#import "Settings.h"
#import "TabBarController.h"
#import "OwnTracksAppDelegate.h"
#import "AlertView.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface FeaturedContentVC ()
@property (weak, nonatomic) IBOutlet UIWebView *UIhtml;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *UIrefresh;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *UIforward;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *UIbackward;
@end

@implementation FeaturedContentVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewDidLoad {
    [super viewDidLoad];
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"action"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    self.UIhtml.delegate = self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);
    
    if ([keyPath isEqualToString:@"action"]) {
        [self performSelectorOnMainThread:@selector(updated) withObject:nil waitUntilDone:NO];
    }
}

- (void)updated {
    [self.UIhtml stopLoading];
    NSString *content = [Settings stringForKey:SETTINGS_ACTION];
    NSString *url = [Settings stringForKey:SETTINGS_ACTIONURL];
    BOOL external = [Settings boolForKey:SETTINGS_ACTIONEXTERN];
    
    if (url) {
        if (self.tabBarController.selectedViewController != self.navigationController) {
            self.navigationController.tabBarItem.badgeValue = NSLocalizedString(@"!",
                                                                                @"New featured content indicator");
        }
        if (external) {
            [self.UIhtml loadHTMLString:[NSString stringWithFormat:@"%@ %@",
                                         NSLocalizedString(@"opening URL",
                                                           @"temporary display while opening URL"),
                                         url
                                         ]
                                baseURL:nil
             ];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        } else {
            [self.UIhtml loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
        }
    } else {
        if (content) {
            if (self.tabBarController.selectedViewController != self.navigationController) {
                self.navigationController.tabBarItem.badgeValue = NSLocalizedString(@"!",
                                                                                    @"New featured content indicator");
            }
            [self.UIhtml loadHTMLString:content baseURL:nil];
        } else {
            [self.UIhtml loadHTMLString:NSLocalizedString(@"no content available",
                                                          @"dummy for missing content")
                                baseURL:nil];
            self.navigationController.tabBarItem.badgeValue = nil;
        }
    }
    [self adjust];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.tabBarItem.badgeValue = nil;
}

- (IBAction)backwardPressed:(id)sender {
    [self.UIhtml goBack];
}
- (IBAction)forwardPressed:(id)sender {
    [self.UIhtml goForward];
}
- (IBAction)reloadPressed:(id)sender {
    [self.UIhtml reload];
}

- (void)adjust {
    self.UIbackward.enabled = self.UIhtml.canGoBack;
    self.UIforward.enabled = self.UIhtml.canGoForward;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    DDLogVerbose(@"didFailLoadWithError %@", error);
    [self.UIhtml loadHTMLString:[NSString stringWithFormat:@"%@\n%@\n%@",
                                 NSLocalizedString(@"webView didFailLoadWithError",
                                                   @"webView didFailLoadWithError display"),
                                 error.localizedDescription,
                                 webView.request.URL.absoluteString]
                        baseURL:nil];
    [self adjust];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    DDLogVerbose(@"shouldStartLoadWithRequest %@", request);
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    DDLogVerbose(@"webViewDidFinishLoad");
    [self adjust];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    DDLogVerbose(@"webViewDidStartLoad");
}
@end
