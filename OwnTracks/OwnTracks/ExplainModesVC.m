//
//  ExplainModesVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.12.17.
//  Copyright © 2017-2018 OwnTracks. All rights reserved.
//

#import "ExplainModesVC.h"

@interface ExplainModesVC ()
    @property (weak, nonatomic) IBOutlet UITextView *UItextview;

@end

@implementation ExplainModesVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.UItextview.text = NSLocalizedStringWithDefaultValue(@"Modes_Text",
                                                             nil,
                                                             [NSBundle mainBundle],
                                                             @"MQTT Mode\n\n"
                                                             "Setup your own OwnTracks server for full privacy protection. More Info on https://owntracks.org/booklet\n\n"
                                                             "HTTP Mode\n\n"
                                                             "Similar to MQTT mode, except data transmission uses HTTP, not MQTT\n\n"
                                                             "Please note:\n"
                                                             "When switching between  modes, all OwnTracks data will be deleted for privacy reasons.",
                                                             @"Text explaining modes");

    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
