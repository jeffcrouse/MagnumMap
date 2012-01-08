//
//  MainViewController.h
//  MagnumMap
//
//  Created by Jeffrey Crouse on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "FlipsideViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <MapKit/MapKit.h>
#import <MapKit/MKReverseGeocoder.h>
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/CALayer.h>

@interface MainViewController : UIViewController <FlipsideViewControllerDelegate,CLLocationManagerDelegate,MKMapViewDelegate,UIAlertViewDelegate>
{
    MPMoviePlayerController *moviePlayer;
    NSArray* matches;
    int currentMatch;
}

- (IBAction)locateUserAndFetchStores: (id)sender;
- (void)mapAResultFromHtml:(NSString*)html;
- (void)zoomToFitMapAnnotations;

@property (nonatomic, retain) CLLocation* initialLocation;
@property (nonatomic, retain) IBOutlet MKMapView *mapView;
@property (nonatomic, retain) IBOutlet CLLocationManager *locationManager;
@property (nonatomic, retain) IBOutlet CLGeocoder *geocoder;
@property (nonatomic, retain) IBOutlet UILabel *statusLabel;
@property (nonatomic, retain) IBOutlet UIView *statusView;
@end

