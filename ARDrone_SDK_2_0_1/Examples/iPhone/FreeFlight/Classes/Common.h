//
//  Common.h
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/22/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//
#define GOOGLE_USERNAME_KEY    @"GOOGLE_USERNAME"
#define GOOGLE_PASSWORD_KEY    @"GOOGLE_PASSWORD"

#define AA_USERNAME_KEY    @"ARDRONE_ACADEMY_USERNAME"
#define AA_PASSWORD_KEY    @"ARDRONE_ACADEMY_PASSWORD"

#define CAPTURE_MODE    @"CAPTURE_MODE"
#define SYNC_TYPE       @"SYNC_TYPE"

#define USER_LAT_KEY    @"USER_LAT"
#define USER_LNG_KEY    @"USER_LNG"
#define PARROT_LAT      48.879026
#define PARROT_LNG      2.367479

#define LOADING_TIMEOUT 2.0f
#define REQUEST_TIMEOUT 10

#define LOCALIZED_STRING(key) [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:@"Localizable"]

#define HELVETICA       @"HelveticaNeue-CondensedBold"
#define WHITE(a)        [UIColor colorWithWhite:1.f alpha:(a)]
#define BLACK(a)        [UIColor colorWithWhite:0.f alpha:(a)]
#define ORANGE(a)       [UIColor colorWithRed:255.f/255.f green:120.f/255.f blue:0.f/255.f alpha:(a)]

#define PNG_EXTENSION   @"png"

// Enum for application preferences
typedef enum { _NORMAL, _BURST } CaptureMode;