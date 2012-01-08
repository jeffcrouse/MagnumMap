//
//  AppDelegate.h
//  MagnumMap
//
//  Created by Jeffrey Crouse on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>


@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    SystemSoundID audioEffect;
    int applicationDidBecomeActives;
}
@property (strong, nonatomic) UIWindow *window;

@end
