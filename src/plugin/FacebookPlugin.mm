#import "Facebook.h"
#import "FBSBJSON.h"

extern "C"
{
    void UnitySendMessage(const char* name, const char* fn, const char* data);
}

static NSString* kDialogBaseURL = @"https://m.facebook.com/dialog/";
static NSString* kSDKVersion = @"2";
static NSString* kRedirectURL=  @"fbconnect://success";

@interface Plugin : NSObject<FBDialogDelegate>
{
    NSString* _appId;
    FBDialog* _fbDialog;
}

//@property (readwrite, retain) Facebook *facebook;

- (Plugin*) initWithAppId: (NSString*)appId;
- (BOOL)handleOpenURL:(NSURL *)url;
- (void) login:(NSString*)scope allowUI:(bool)allowUI;
- (void) dialog: (NSString*)action params:(NSMutableDictionary*)params;
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
	}
	return self;
}

- (void)dialog:(NSString *)action
     andParams:(NSMutableDictionary *)params
   andDelegate:(id <FBDialogDelegate>)delegate {
    
   [_fbDialog release];
    
   NSString *dialogURL = [kDialogBaseURL stringByAppendingString:action];
   [params setObject:@"touch" forKey:@"display"];
   [params setObject:kSDKVersion forKey:@"sdk"];
   [params setObject:kRedirectURL forKey:@"redirect_uri"];
    
   [params setObject:_appId forKey:@"app_id"];
    
    FBSession* session = [FBSession activeSessionIfOpen];
    
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
   FBSession* session = [FBSession activeSessionIfOpen];
   if (session != nil) {
       return [session handleOpenURL:url];
   }
   return NO;
}

- (void) login:(NSString*)scope allowUI:(bool)allowUI
{
    NSArray* permissions = [scope componentsSeparatedByString:@","];
    
    [FBSession openActiveSessionWithReadPermissions:permissions allowLoginUI:allowUI completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
        
        NSLog(@"-> _FacebookLogin: State=%d \n", state);
        
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
        NSLog(@"-> _FacebookLogin %d \n", allowUI ? 1 : 0);
		if ( plugin != nil )
		{
			[plugin login:[NSString stringWithUTF8String:scope] allowUI:allowUI ];
		}
	}
    
    //////////////////////////////////////////////////////////////////////////////////
	//
    void _FacebookLogout()
	{
        NSLog(@"-> _FacebookLogout 1 \n");
        FBSession* session = [FBSession activeSessionIfOpen];
        if (session != nil) {
            NSLog(@"-> _FacebookLogout2 \n");
            [session closeAndClearTokenInformation];
        }
        NSLog(@"-> _FacebookLogged Out \n");
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



