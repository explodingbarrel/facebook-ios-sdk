#import "Facebook.h"
#import "../JSON/JSON.h"

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
	[[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:@"access_token" ];	
	[[NSUserDefaults standardUserDefaults] setBool:true forKey:@"facebook_screen_done"];
}

- (void)fbDidNotLogin:(BOOL)cancelled
{
	NSLog(@"fbDidNotLogin %d", cancelled ? 1 : 0);
	[[NSUserDefaults standardUserDefaults] setBool:true forKey:@"facebook_screen_done"];	
}

- (void)fbDidLogout
{
	NSLog(@"fbDidLogout");
//	[[NSUserDefaults standardUserDefaults] setBool:true forKey:@"facebook_screen_done"];	
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

- (void) login
{
	if ( facebook )
	{
		NSArray* permissions = [NSArray arrayWithObjects:@"publish_actions",nil];
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
    void _FacebookLogin()
	{
        NSLog(@"-> _FacebookLogin \n");
		if ( plugin != nil )
		{
			[plugin login ];
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////
	//
	void _FacebookUI(const char* request, const char* data)
	{
        NSLog(@"-> _FacebookUI \n");
		
		//NSString* requestStr = [NSString stringWithUTF8String:request];
		NSString* dataStr = [NSString stringWithUTF8String:data];
		
		SBJSON *jsonParser = [[SBJSON new] autorelease];
		NSDictionary* result = (NSDictionary*)[jsonParser objectWithString:dataStr];
		NSMutableDictionary* params = [NSMutableDictionary dictionaryWithCapacity:25];
		
		// convert to json strings
		for (NSString* key in result.keyEnumerator) {
			//NSLog(@"key=> %@", key);
			id value = [result objectForKey:key];
			if ( ![value isKindOfClass:[NSString class]] )
			{
				// convert to json
				NSString* str = [jsonParser stringWithObject:value];
				[params setObject:str forKey:key];
				NSLog(@"%@ -> %@", key, str);
			}
			else {
				[params setObject:value forKey:key];
				NSLog(@"%@ -> %@", key, value);
			}
            
			
		}
		
		// set access token
		NSString* token = [ [NSUserDefaults standardUserDefaults] stringForKey:@"access_token" ];
		[params setObject:token forKey:@"access_token"];
        
		NSString* action = [params objectForKey:@"method"];
		NSLog(@"running dialog %@", action);
		[plugin dialog:action params:params];
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



