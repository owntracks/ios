//
//  FontAwesome.m
//  FontAwesomeTools-iOS is Copyright 2013 TapTemplate and released under the MIT license.
//  www.taptemplate.com
//

#import "FontAwesome.h"

@implementation FontAwesome


//================================
// Font and Label Methods
//================================

+ (UIFont*)fontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:@"FontAwesome" size:size];
}

+ (UILabel*)labelWithIcon:(NSString*)fa_icon
                     size:(CGFloat)size
                    color:(UIColor*)color
{
    UILabel *label = [[UILabel alloc] init];
    [FontAwesome label:label setIcon:fa_icon size:size color:color sizeToFit:YES];
    return label;
}

+ (void)label:(UILabel*)label
      setIcon:(NSString*)fa_icon
         size:(CGFloat)size
        color:(UIColor*)color
    sizeToFit:(BOOL)shouldSizeToFit
{
    label.font = [FontAwesome fontWithSize:size];
    label.text = fa_icon;
    label.textColor = color;
    label.backgroundColor = [UIColor clearColor];
    if (shouldSizeToFit) {
        [label sizeToFit];
    }
    // NOTE: FontAwesome icons will be silent through VoiceOver, but the Label is still selectable through VoiceOver. This can cause a usability issue because a visually impaired user might navigate to the label but get no audible feedback that the navigation happened. So hide the label for VoiceOver by default - if your label should be descriptive, un-hide it explicitly after creating it, and then set its accessibiltyLabel.
    label.accessibilityElementsHidden = YES;
}



//================================
// Image Methods
//================================

+ (UIImage*)imageWithIcon:(NSString*)fa_icon
                iconColor:(UIColor*)iconColor
                 iconSize:(CGFloat)iconSize
{
    return [FontAwesome imageWithIcon:fa_icon
                            iconColor:iconColor
                             iconSize:iconSize
                            imageSize:CGSizeMake(iconSize, iconSize)];
}

+ (UIImage*)imageWithIcon:(NSString*)fa_icon
                iconColor:(UIColor*)iconColor
                 iconSize:(CGFloat)iconSize
                imageSize:(CGSize)imageSize;
{
    NSAssert(fa_icon, @"You must specify an icon from font-awesome-codes.h.");
    return [self imageWithText:fa_icon
                          font:[FontAwesome fontWithSize:iconSize]
                     iconColor:iconColor
                     imageSize:imageSize];
}

+ (UIImage*)imageWithText:(NSString*)characterCodeString
                     font:(UIFont*)font
                iconColor:(UIColor*)iconColor
                imageSize:(CGSize)imageSize;
{
    NSAssert(characterCodeString, @"You must specify a character code, such as \\uf190.");

    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6) {
        if (!iconColor) { iconColor = [UIColor blackColor]; }
        
        UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0);
        NSAttributedString* attString = [[NSAttributedString alloc]
                                         initWithString:characterCodeString
                                         attributes:@{NSFontAttributeName: font,
                                                      NSForegroundColorAttributeName : iconColor}];
        // get the target bounding rect in order to center the icon within the UIImage:
        NSStringDrawingContext *ctx = [[NSStringDrawingContext alloc] init];
        CGRect boundingRect = [attString boundingRectWithSize:CGSizeMake(font.pointSize, font.pointSize) options:0 context:ctx];
        // draw the icon string into the image:
        [attString drawInRect:CGRectMake((imageSize.width/2.0f) - boundingRect.size.width/2.0f,
                                         (imageSize.height/2.0f) - boundingRect.size.height/2.0f,
                                         imageSize.width,
                                         imageSize.height)];
        UIImage *iconImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return iconImage;
    } else {
#if DEBUG
        NSLog(@" [ FontAwesomeTools ] Using lower-res iOS 5-compatible image rendering.");
#endif
        UILabel *iconLabel = [FontAwesome labelWithIcon:characterCodeString size:font.pointSize color:iconColor];
        UIImage *iconImage = nil;
        UIGraphicsBeginImageContextWithOptions(imageSize, NO, 1.0);
        {
            CGContextRef imageContext = UIGraphicsGetCurrentContext();
            if (imageContext != NULL) {
                UIGraphicsPushContext(imageContext);
                {
                    CGContextTranslateCTM(imageContext,
                                          (imageSize.width/2.0f) - iconLabel.frame.size.width/2.0f,
                                          (imageSize.height/2.0f) - iconLabel.frame.size.height/2.0f);
                    [[iconLabel layer] renderInContext: imageContext];
                }
                UIGraphicsPopContext();
            }
            iconImage = UIGraphicsGetImageFromCurrentImageContext();
        }
        UIGraphicsEndImageContext();
        return iconImage;
    }
}

// DEPRECATED - Instead use +imageWithIcon:iconColor:iconSize:
+ (UIImage*)imageWithIcon:(NSString*)fa_icon size:(CGFloat)size color:(UIColor*)color
{
    return [FontAwesome imageWithIcon:fa_icon iconColor:color iconSize:size imageSize:CGSizeMake(size, size)];
}


@end
