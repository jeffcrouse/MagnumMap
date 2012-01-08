//
//  MainViewController.m
//  MagnumMap
//
//  Created by Jeffrey Crouse on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MainViewController.h"

@implementation MainViewController
@synthesize mapView, geocoder, locationManager, statusLabel, statusView, initialLocation;


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


// ----------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    NSLog(@"viewDidLoad");
    
    // Can't figure out how to do this via IB..
    statusView.layer.cornerRadius=10;

    geocoder = [[CLGeocoder alloc] init];
    locationManager = [[CLLocationManager alloc] init];
    
    locationManager.delegate=self;
    locationManager.desiredAccuracy=kCLLocationAccuracyBestForNavigation;
    [locationManager startUpdatingLocation];
    
    NSURL *movieurl = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"intro.mp4" ofType:@""]];
	moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:movieurl];
    
    // Register to receive a notification when the movie has finished playing.
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:moviePlayer];

    [moviePlayer.view setFrame: self.view.frame];
    moviePlayer.controlStyle = MPMovieControlStyleNone;
    moviePlayer.shouldAutoplay = YES;
    [moviePlayer setFullscreen:YES animated:YES];
    
    [self.view addSubview:moviePlayer.view];  
}

// ----------------------------------------------------------
- (void)mapView:(MKMapView *)theMapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    if ( !initialLocation )
    {
        self.initialLocation = userLocation.location;
        
        MKCoordinateRegion region;
        region.center = theMapView.userLocation.coordinate;
        region.span = MKCoordinateSpanMake(0.1, 0.1);
        
        region = [theMapView regionThatFits:region];
        [theMapView setRegion:region animated:YES];
    }
}


// ----------------------------------------------------------
- (void) moviePlayBackDidFinish:(NSNotification*)notification
{
    NSLog(@"Movie done!");
	[[NSNotificationCenter defaultCenter] removeObserver:self
										  name:MPMoviePlayerPlaybackDidFinishNotification
										  object:moviePlayer];
	[moviePlayer.view removeFromSuperview];
    [self locateUserAndFetchStores: nil];
}


// ----------------------------------------------------------
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{

    if([moviePlayer.view isDescendantOfView: self.view])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                              name:MPMoviePlayerPlaybackDidFinishNotification
                                              object:moviePlayer];
        [moviePlayer stop];
        [moviePlayer.view removeFromSuperview];
        [self locateUserAndFetchStores: nil];
    }
}


// ----------------------------------------------------------
- (IBAction)locateUserAndFetchStores: (id)sender
{    
    NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity:10];
    for (id annotation in mapView.annotations)
        if (annotation != mapView.userLocation)
            [toRemove addObject:annotation];
    [mapView removeAnnotations:toRemove];
    
    currentMatch=0;

    [statusView setHidden:NO];
    [statusLabel setText:@"Finding your zipcode..."];
    
    [geocoder reverseGeocodeLocation: locationManager.location completionHandler: 
     ^(NSArray* placemarks, NSError* error) {
         if(error)
         {
             NSLog(@"Error geocoding: %@", [error localizedDescription]);
             UIAlertView *alertView = [[UIAlertView alloc]  initWithTitle:@"Error finding your zipcode" 
                                                            message:[error localizedDescription] 
                                                            delegate:self
                                                            cancelButtonTitle:@"OK" 
                                                            otherButtonTitles:@"Try Again", nil];
             [statusView setHidden:YES];
             alertView.tag=1;
             [alertView show];
         }
         else
         {
             CLPlacemark* user = [placemarks objectAtIndex:0];
             NSLog(@"Found zipcode %@", user.postalCode);
             [statusLabel setText:[NSString stringWithFormat:@"Mapping results for %@", user.postalCode]];

             // 002260064320
             // 002260064910
             NSString* url = [NSString stringWithFormat:@"http://www.itemlocator.net/scripts/cgiip.exe/WService=ils3/webspeed/locatorweb.w?radius=10&count=99&customer=churchweb&zip=%@&item=002260064910", user.postalCode];
             NSString* userAgent = @"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-US) AppleWebKit/534.16 (KHTML, like Gecko) Chrome/10.0.648.114 Safari/534.16";
             
             // send the request
             NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
             [theRequest setHTTPMethod:@"GET"]; 
             [theRequest addValue: @"text/plain; charset=utf-8"     forHTTPHeaderField:@"Content-Type"];
             [theRequest setValue: @"http://www.trojancondoms.com"  forHTTPHeaderField:@"Referer"];
             [theRequest setValue:userAgent                         forHTTPHeaderField:@"User-Agent"];
             
             // get the html
             NSError *err;
             NSData *responseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:nil error:&err];
             if(err)
             {
                 [statusView setHidden:YES];
                 NSLog(@"Error geocoding: %@", [error localizedDescription]);
                 UIAlertView *alertView = [[UIAlertView alloc]  initWithTitle:@"Error contacgting Trojan site" 
                                                                message:[error localizedDescription] 
                                                                delegate:self
                                                                cancelButtonTitle:@"OK" 
                                                                otherButtonTitles:@"Try Again", nil];
                 alertView.tag=1;
                 [alertView show];
             }
             else
             {
                 NSString *html = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                 NSString* pattern = @"addr=([^&]+)&csz=([^&]+)&name=([^\"]+)";
                 NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                        options:NSRegularExpressionCaseInsensitive
                                                                                          error:&error];
                 matches = [regex matchesInString:html options:0 range:NSMakeRange(0, [html length])];
                 if([matches count]==0)
                 {
                     NSLog(@"Regex found no results!");
                 }
                 else
                 {
                     NSLog(@"Found %d matches", [matches count]);
                     [self mapAResultFromHtml: html];
                 }
             }
         }
     }];
}



// ----------------------------------------------------------
- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex 
{
  if(actionSheet.tag==1 && buttonIndex==1)
  {
      NSLog(@"Try Again");
      [self locateUserAndFetchStores: nil];
  }
}


// ----------------------------------------------------------
- (void) mapAResultFromHtml:(NSString*)html;
{
    NSTextCheckingResult *match = [matches objectAtIndex:currentMatch];
    currentMatch++;
    
    NSString* addr	= [html substringWithRange:[match rangeAtIndex:1]];
    NSString* csz	= [html substringWithRange:[match rangeAtIndex:2]];
    NSString* name	= [html substringWithRange:[match rangeAtIndex:3]];
    
    name = [name stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    
    [statusLabel setText:[NSString stringWithFormat:@"Mapping \"%@\"", name]];
    
    NSString* search = [NSString stringWithFormat:@"%@ %@", addr, csz];
    
    [geocoder geocodeAddressString:search completionHandler:^(NSArray* placemarks, NSError* error) {
        if(error)
        {
            [statusView setHidden:YES];
            NSLog(@"Error geocoding: %@", [error localizedDescription]);
            UIAlertView *alertView = [[UIAlertView alloc]   initWithTitle:@"Error finding the store" 
                                                            message:[error localizedDescription] 
                                                            delegate:self
                                                            cancelButtonTitle:@"OK" 
                                                            otherButtonTitles:@"Try Again", nil];
            alertView.tag=1;
            [alertView show];
        }
        else
        {
            NSLog(@"Adding placemark for: %@", name);
            CLPlacemark* store = [placemarks objectAtIndex:0];
            
            MKPointAnnotation *pa = [[MKPointAnnotation alloc] init];
            pa.coordinate = store.location.coordinate;
            pa.title = name;
            pa.subtitle = search;
            [mapView addAnnotation:pa];
        }
        if(currentMatch < [matches count]-1)
        {
            [self mapAResultFromHtml:html];
        }
        else
        {
            [statusView setHidden:YES];
            [self zoomToFitMapAnnotations];
        }
    }];
}


// ----------------------------------------------------------
- (MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
   
    if(annotation == mapView.userLocation)
    {
        MKAnnotationView *annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"userPinID"];
        
        UIImageView* animatedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-18, -18, 35, 35)];
        animatedImageView.animationImages = [NSArray arrayWithObjects:    
                                             [UIImage imageNamed:@"penis0.gif"],
                                             [UIImage imageNamed:@"penis1.gif"],
                                             [UIImage imageNamed:@"penis2.gif"],
                                             [UIImage imageNamed:@"penis3.gif"], nil];
        animatedImageView.animationDuration = 0.5f;
        animatedImageView.animationRepeatCount = 0;
        
        [animatedImageView startAnimating];
        [annotationView addSubview: animatedImageView];

        // You may need to resize the image here.
        //UIImage *flagImage = [UIImage imageNamed:@"penis.gif"];
        //annotationView.image = flagImage;
        annotationView.image=nil;
        return annotationView;
    }
    else 
    {
        static NSString *defaultPinID = @"SFAnnotationIdentifier";
        MKPinAnnotationView *pinView =  (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:defaultPinID];
        if (!pinView)
        {
            MKAnnotationView *annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:defaultPinID];
            UIImage *flagImage = [UIImage imageNamed:@"condom.png"];
            // You may need to resize the image here.
            annotationView.image = flagImage;
            annotationView.canShowCallout = YES;
            
            //instatiate a detail-disclosure button and set it to appear on right side of annotation
            UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            annotationView.rightCalloutAccessoryView = infoButton;
            
            return annotationView;
        }
        else
        {
            pinView.annotation = annotation;
            return pinView;
        }
    }
}


// ----------------------------------------------------------
- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{    
	NSString* urlstr = [NSString stringWithFormat:@"http://maps.google.com/maps?q=%@", 
                        [view.annotation.subtitle stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSLog(@"Opening %@", urlstr);
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlstr]];

}


// ----------------------------------------------------------
-(void)zoomToFitMapAnnotations
{
    if([mapView.annotations count] == 0)
        return;
	
    CLLocationCoordinate2D topLeftCoord;
    topLeftCoord.latitude = -90;
    topLeftCoord.longitude = 180;
	
    CLLocationCoordinate2D bottomRightCoord;
    bottomRightCoord.latitude = 90;
    bottomRightCoord.longitude = -180;
	
    for(MKPointAnnotation* annotation in mapView.annotations)
    {
        topLeftCoord.longitude = fmin(topLeftCoord.longitude, annotation.coordinate.longitude);
        topLeftCoord.latitude = fmax(topLeftCoord.latitude, annotation.coordinate.latitude);
		
        bottomRightCoord.longitude = fmax(bottomRightCoord.longitude, annotation.coordinate.longitude);
        bottomRightCoord.latitude = fmin(bottomRightCoord.latitude, annotation.coordinate.latitude);
    }
	
    MKCoordinateRegion region;
    region.center.latitude = topLeftCoord.latitude - (topLeftCoord.latitude - bottomRightCoord.latitude) * 0.5;
    region.center.longitude = topLeftCoord.longitude + (bottomRightCoord.longitude - topLeftCoord.longitude) * 0.5;
    region.span.latitudeDelta = fabs(topLeftCoord.latitude - bottomRightCoord.latitude) * 1.1; // Add a little extra space on the sides
    region.span.longitudeDelta = fabs(bottomRightCoord.longitude - topLeftCoord.longitude) * 1.1; // Add a little extra space on the sides
	
    region = [mapView regionThatFits:region];
    [mapView setRegion:region animated:YES];
}


// ----------------------------------------------------------
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
     NSLog(@"viewDidUnload");
}

// ----------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"viewWillAppear");
}

// ----------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"viewDidAppear");
}

// ----------------------------------------------------------
- (void)viewWillDisappear:(BOOL)animated
{
    NSLog(@"viewWillDisappear");
	[super viewWillDisappear:animated];
}

// ----------------------------------------------------------
- (void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"viewDidDisappear");
	[super viewDidDisappear:animated];
}

// ----------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Flipside View

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
    }
}

@end
