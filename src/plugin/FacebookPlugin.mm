#import "Facebook.h"

void UnitySendMessage(const char* name, const char* fn, const char* data);

@interface Plugin : NSObject<FBSessionDelegate, FBDialogDelegate>

@property (readwrite, retain) Facebook *facebook;

- (Plugin*) initWithAppId: (NSString*)appId;
- (BOOL)handleOpenURL:(NSURL *)url;
- (void) login;
- (void) dialog: (NSString*)action params:(NSMutableDictionary*)params;
- (void) setToken:(NSString*)token;

- (void)fbDidLogin;
- (void)fbDidNotLogin:(BOOL)cancelled;
- (void)fbDidLogout;

- (void)fbDidExtendToken:(NSString*)accessToken expiresAt:(NSDate*)expiresAt;
- (void)fbSessionInvalidated;
@end

@implementation Plugin

@synthesize facebook;

- (Plugin*) initWithAppId: (NSString*)appId 
{
	self = [super init];
	if (self) 
	{
		facebook = [ [Facebook alloc] initWithAppId:appId andDelegate:self ]; 
		[facebook retain];
	}
	return self;
}

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

- (void) dialog: (NSString*)action params:(NSMutableDictionary*)params 
{
	NSLog(@"dialog: %@", action);
	[facebook dialog:action andParams:params andDelegate:nil];
}

- (BOOL)handleOpenURL:(NSURL *)url
{
	if ( facebook )
	{
		NSLog(@"handleOpenURL %@", url );
		return [facebook handleOpenURL:url];
	}
	return NO;
}

- (void) setToken:(NSString*)token
{
	facebook.accessToken = token;
}

- (void) login:(NSString*)scope
{
	if ( facebook )
	{
        NSArray* permissions = [scope componentsSeparatedByString:@","];
		[facebook authorize:permissions];
	}
}

- (void)fbDidExtendToken:(NSString*)accessToken expiresAt:(NSDate*)expiresAt
{
    [self setToken:accessToken];
}

- (void)fbSessionInvalidated
{
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
    void _FacebookSetAccessToken()
	{
        NSLog(@"-> _FacebookSetToken \n");
		if ( plugin != nil )
		{
			NSString* token = [ [NSUserDefaults standardUserDefaults] stringForKey:@"access_token" ];
			[plugin setToken:token ];
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////
	//
    void _FacebookLogin(const char* scope)
	{
        NSLog(@"-> _FacebookLogin \n");
		if ( plugin != nil )
		{
			[plugin login:[NSString stringWithUTF8String:scope] ];
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////
	//
	void _FacebookUI(const char* request, const char* data)
	{
        
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



