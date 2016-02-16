
//
//  FeaturedContentVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 23.01.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
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
    if (url) {
        [self.UIhtml loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    } else {
        if (content) {
            [self.UIhtml loadHTMLString:content baseURL:nil];
        } else {
            [self.UIhtml loadHTMLString:@"no content available" baseURL:nil];
        }
    }
    [self adjust];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
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
    [AlertView alert:@"UIWebView error" message:[NSString stringWithFormat:@"%@\n%@",
                                                 error.localizedDescription,
                                                 webView.request.URL.absoluteString
                                                 ]
     ];
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
