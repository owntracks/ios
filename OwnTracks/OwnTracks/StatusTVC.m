//
//  StatusTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "StatusTVC.h"
#import <errno.h>
#import <CoreFoundation/CFError.h>
#import <mach/mach_error.h>
#import <Security/SecureTransport.h>
#import "OwnTracksAppDelegate.h"


@interface StatusTVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIurl;
@property (weak, nonatomic) IBOutlet UITextView *UIerrorCode;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveTopic;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveClientId;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveWillTopic;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveDeviceId;

@end

@implementation StatusTVC

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.title = [NSString stringWithFormat:@"App Version %@",
                  [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"]];

    self.UIurl.text = self.connection.url;
    
    self.UIerrorCode.text = self.connection.lastErrorCode ? [NSString stringWithFormat:@"%@ %ld %@",
                                                             self.connection.lastErrorCode.domain,
                                                             (long)self.connection.lastErrorCode.code,
                                                             self.connection.lastErrorCode.localizedDescription ?
                                                             self.connection.lastErrorCode.localizedDescription : @""]
                                                            : @"<no error>";
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    self.UIeffectiveDeviceId.text = [delegate.settings theDeviceId];
    self.UIeffectiveClientId.text = [delegate.settings theClientId];
    self.UIeffectiveTopic.text = [delegate.settings theGeneralTopic];
    self.UIeffectiveWillTopic.text = [delegate.settings theWillTopic];
}

- (IBAction)send:(UIBarButtonItem *)sender
{
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    
    [picker setSubject:[NSString stringWithFormat:@"OwnTracks config %@", self.UIeffectiveClientId.text]];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [picker addAttachmentData:[delegate.settings toData] mimeType:@"application/json"
                     fileName:[NSString stringWithFormat:@"Config-%@.otrc", self.UIeffectiveClientId.text]];
    
    NSString *emailBody = @"see attached file";
    [picker setMessageBody:emailBody isHTML:NO];
    
    [self presentViewController:picker animated:YES completion:^{
        // done
    }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [controller dismissViewControllerAnimated:YES completion:^{
        // done
    }];
}


@end
