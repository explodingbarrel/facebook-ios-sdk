#import "Facebook.h"
#import "FBSBJSON.h"

extern "C"
{
    void UnitySendMessage(const char* name, const char* fn, const char* data);
}

@interface Plugin : NSObject<FBSessionDelegate, FBDialogDelegate>

@property (readwrite, retain) Facebook *facebook;

- (Plugin*) initWithAppId: (NSString*)appId;
- (BOOL)handleOpenURL:(NSURL *)url;
- (void) login:(NSString*)scope;
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
	NSLog(@"dialog: %@, %@", action, params);
	[facebook dialog:action andParams:params andDelegate:self];
}

- (void)dialogCompleteWithUrl:(NSURL *)url {
    NSDictionary *params = [self parseURLParams:[url query]];
    FBSBJSON *jsonWriter = [FBSBJSON new];
    NSString *dialogResult = [jsonWriter stringWithObject:params];
    UnitySendMessage("fb_callbacks", "OnDialog", [dialogResult UTF8String]);
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
    facebook.expirationDate = [NSDate dateWithTimeIntervalSinceNow:3600];
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
    void _FacebookSetAccessToken( const char* token )
	{
        NSLog(@"-> _FacebookSetToken \n");
		if ( plugin != nil )
		{
			[plugin setToken:[NSString stringWithUTF8String:token] ];
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



