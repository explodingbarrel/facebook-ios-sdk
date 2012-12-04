#import "Facebook.h"
#import "FBSBJSON.h"

extern "C"
{
    void UnitySendMessage(const char* name, const char* fn, const char* data);
}

static NSString* kDialogBaseURL;
static NSString* kSDKVersion;
static NSString* kRedirectURL;

@interface Plugin : NSObject<FBSessionDelegate, FBDialogDelegate>
{
    NSString* _appId;
    FBDialog* _fbDialog;
}

//@property (readwrite, retain) Facebook *facebook;

- (Plugin*) initWithAppId: (NSString*)appId;
- (BOOL)handleOpenURL:(NSURL *)url;
- (void) login:(NSString*)scope allowUI:(bool)allowUI;
- (void) dialog: (NSString*)action params:(NSMutableDictionary*)params;
- (void) setToken:(NSString*)token;

//- (void)fbDidLogin;
//- (void)fbDidNotLogin:(BOOL)cancelled;
//- (void)fbDidLogout;

//- (void)fbDidExtendToken:(NSString*)accessToken expiresAt:(NSDate*)expiresAt;
//- (void)fbSessionInvalidated;
@end

@implementation Plugin

//@synthesize facebook;

- (NSDictionary*)parseURLParams:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        NSString *val =
        [[kv objectAtIndex:1]
         stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [params setObject:val forKey:[kv objectAtIndex:0]];
    }
    return params;
}

- (Plugin*) initWithAppId: (NSString*)appId
{
	self = [super init];
	if (self) 
	{
        _appId = appId;
        [FBSession setDefaultAppID:appId];
        //facebook = [[Facebook alloc] initWithAppId:appId];
		//facebook = [ [Facebook alloc] initWithAppId:appId andDelegate:self ];
		//[facebook retain];
	}
	return self;
}

/*
- (void)fbDidLogin
{
	NSString* accessToken = [ facebook accessToken ];
	NSLog(@"@fbDidLogin: %@", accessToken );
    UnitySendMessage("fb_callbacks", "OnAuthorize", [accessToken UTF8String]);
}

- (void)fbDidNotLogin:(BOOL)cancelled
{
	NSLog(@"fbDidNotLogin %d", cancelled ? 1 : 0);
    UnitySendMessage("fb_callbacks", "OnAuthorizeFailed", cancelled ? "1" : "0");
}

- (void)fbDidLogout
{
	NSLog(@"fbDidLogout");
    UnitySendMessage("fb_callbacks", "OnLogout", "" );
}
*/ 

- (void)dialog:(NSString *)action
     andParams:(NSMutableDictionary *)params
   andDelegate:(id <FBDialogDelegate>)delegate {
    
   [_fbDialog release];
    
   NSString *dialogURL = [kDialogBaseURL stringByAppendingString:action];
   [params setObject:@"touch" forKey:@"display"];
   [params setObject:kSDKVersion forKey:@"sdk"];
   [params setObject:kRedirectURL forKey:@"redirect_uri"];
    
   [params setObject:_appId forKey:@"app_id"];
    
    FBSession* session = [FBSession activeSession];
    
   if (session && session.isOpen)
   {
       [params setValue:[session.accessToken stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:@"access_token"];
   }
    
    _fbDialog = [[FBDialog alloc] initWithURL:dialogURL
                                           params:params
                                  isViewInvisible:NO
                             frictionlessSettings:nil
                                         delegate:delegate];
    
    [_fbDialog show];
}

- (void) dialog: (NSString*)action params:(NSMutableDictionary*)params 
{
	NSLog(@"dialog: %@, %@", action, params);
	[self dialog:action andParams:params andDelegate:self];
}

- (void)dialogCompleteWithUrl:(NSURL *)url {
    NSDictionary *params = [self parseURLParams:[url query]];
    FBSBJSON *jsonWriter = [FBSBJSON new];
    NSString *dialogResult = [jsonWriter stringWithObject:params];
    UnitySendMessage("fb_callbacks", "OnDialog", [dialogResult UTF8String]);
}

- (BOOL)handleOpenURL:(NSURL *)url
{
   FBSession* session = [FBSession activeSession];
   if (session) {
       return [session handleOpenURL:url];
   }
   return NO;
}

- (void) login:(NSString*)scope allowUI:(bool)allowUI
{
    NSArray* permissions = [scope componentsSeparatedByString:@","];
    
    [FBSession openActiveSessionWithReadPermissions:permissions allowLoginUI:allowUI completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
        switch(state)
        {
        case FBSessionStateOpen:
            {
                NSString* accessToken = [FBSession activeSession].accessToken;
                UnitySendMessage("fb_callbacks", "OnAuthorize", [accessToken UTF8String]);
            }
                break;
        case FBSessionStateClosedLoginFailed:
            {
                NSString *errorCode = [[error userInfo] objectForKey:FBErrorLoginFailedOriginalErrorCode];
                NSString *errorReason = [[error userInfo] objectForKey:FBErrorLoginFailedReason];
                BOOL userDidCancel = !errorCode && (!errorReason ||
                                                    [errorReason isEqualToString:FBErrorLoginFailedReasonInlineCancelledValue]);
                UnitySendMessage("fb_callbacks", "OnAuthorizeFailed",userDidCancel ? "1" : "0" );
            }
                break;
            default:
                break;
        }
    }];
}


@end

Plugin* plugin = nil;


extern "C"
{
	//////////////////////////////////////////////////////////////////////////////////
	//
	void _FacebookInit( const char* appId )
	{
		NSLog(@"-> _FacebookInit \n");
		if ( plugin == nil )
		{
			NSString* appIdStr = [NSString stringWithFormat:@"%s",appId];
			plugin = [[Plugin alloc] initWithAppId:appIdStr];
			[plugin retain];
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////
	//
    void _FacebookLogin(const char* scope, bool allowUI )
	{
        NSLog(@"-> _FacebookLogin \n");
		if ( plugin != nil )
		{
			[plugin login:[NSString stringWithUTF8String:scope] allowUI:allowUI ];
		}
	}
    
    //////////////////////////////////////////////////////////////////////////////////
	//
    void _FacebookLogout()
	{
        NSLog(@"-> _FacebookLogout \n");
        FBSession* session = [FBSession activeSession];
        if (session) {
            [session closeAndClearTokenInformation];
        }
	}
	
	//////////////////////////////////////////////////////////////////////////////////
	//
	void _FacebookUI(const char* method, const char* params)
	{
        if ( plugin != nil )
		{
            NSString* action        = [NSString stringWithUTF8String:method];
            NSString* pstr          = [NSString stringWithUTF8String:params];
            FBSBJSON *jsonReader    = [FBSBJSON new];
            NSMutableDictionary* dic= [jsonReader objectWithString:pstr];
            [plugin dialog:action params:dic];
		}
	}
    
    //////////////////////////////////////////////////////////////////////////////////
	//
    bool _FacebookHandleUrl( NSURL* url )
    {
        NSLog(@"-> _FacebookHandleUrl %@ \n", url);
        if ( plugin != nil )
		{
            return [plugin handleOpenURL:url];
		}
        return false;
    }
}



