/**
 * Copyright 2014 Lior Gross
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "PushWrapper.h"

#define socketHost @"fe.techonlinecorp.com"
#define socketPort 443
#define socketSecure YES
#define applicationId @"<YOUR_APPLICATION_ID>"

@implementation PushWrapper {
    NSString *queString;
    NSData *pushToken;
    NSString *contextId;
    NSString *saveUser;
}
@synthesize delegate;

//make it singleton
+ (id)sharedManager {
    static PushWrapper *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
        NSLog(@"init once");
    });
    return sharedMyManager;
}

- (id)init {
    return self;
}

-(void)processRemoteNotification:(NSDictionary *)userInfo {
    //let's handle info!!!
    //Not yet complete, will modify by requirements
    NSLog(@"HANDLING INFO");
    NSString *URL = @"";
    if( [userInfo objectForKey:@"URL"] != NULL)
    {
        URL = [userInfo objectForKey:@"URL"];
        NSLog(@"%@",URL);
        NSURL *candidateURL = [NSURL URLWithString:URL];
        // WARNING > "test" is an URL according to RFCs, being just a path
        // so you still should check scheme and all other NSURL attributes you need
        if (candidateURL && candidateURL.scheme && candidateURL.host) {
            // candidate is a well-formed url with, let's check if delegator responds to URL function
            if ([delegate respondsToSelector:@selector(handleUrlOpen:)]) {
                [delegate handleUrlOpen:candidateURL];
            }
        }
    }
}

-(void)setTokenAndConnect:(NSData *)token {
    NSLog(@"I got token, and connecting!!!!");
    NSData* oldToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceToken"];
    pushToken = token;
    if (oldToken && [oldToken isEqualToData:token]) {
        NSLog(@"I Already have this one!!");
    } else {
        [self connectSocket];
    }
}
-(void) executeQue {
    if (queString) {
        NSArray *queSelectors = [queString componentsSeparatedByString:@":"];
        if ([queSelectors[0] isEqualToString:@"registerUserName"]) {
            [self registerUserName:queSelectors[1]];
        }
        queString = nil;
    }
}
-(void) connectSocket {
    if (pushToken) {
        NSLog(@"I have token, I can start connection");
        socketIO = [[SocketIO alloc] initWithDelegate:self];
        socketIO.useSecure = socketSecure;
        [socketIO connectToHost:socketHost onPort:socketPort];
        
        //need to get context
        [socketIO sendMessage:@"{\"qualifier\":\"pt.openapi.context/createContextRequest\",\"data\":{\"properties\":null}}"];
    } else {
        NSLog(@"I don't have token /:");
    }
}

-(void) registerDeviceForPush {
        [socketIO sendMessage:[NSString stringWithFormat:@"{\"qualifier\":\"pt.openapi.push.devreg/registerDevice/1.0\",\"contextId\":\"%@\",\"data\":{\"_id\":{\"hwid\":\"%@\",\"applicationId\":\"%@\"},\"pushToken\":\"%@\",\"language\":\"en\",\"platform\":1,\"timeZone\":7200}}",contextId, [self stringFromDeviceToken],applicationId,[self stringFromDeviceToken]]];
}

-(void) registerUserName:(NSString*) username {
    NSString *oldUser = [[NSUserDefaults standardUserDefaults] objectForKey:@"username"];
    if (oldUser && [oldUser isEqualToString:username]) {
        NSLog(@"We already have this username: %@",username);
    } else if (contextId) {
        NSLog(@"rEGISTERING uSERNAME");
        //it's new or different from what we have, so let's update ptech
        saveUser = username;
        [socketIO sendMessage:[NSString stringWithFormat:@"{\"qualifier\":\"pt.openapi.push.devreg/updateUserId\",\"contextId\":\"%@\",\"data\":{\"deviceRegistrationId\":{\"hwid\":\"%@\",\"applicationId\":\"%@\"},\"userIdentity\":\"%@-winnercasino\"}}",contextId, [self stringFromDeviceToken], applicationId, username]];
    } else {
        NSLog(@"Missing stuff, put in que");
        queString = [NSString stringWithFormat:@"registerUserName:%@",username];
        [self connectSocket];
    }
}

- (NSString*)stringFromDeviceToken {
    const char* data = [pushToken bytes];
    NSMutableString* token = [NSMutableString string];
    for (int i = 0; i < [pushToken length]; i++) {
        [token appendFormat:@"%02.2hhX", data[i]];
    }
    return token;
}

- (void) socketIODidConnect:(SocketIO *)socket {
    NSLog(@"I am connected!!!!");
}
- (void) socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error {
    NSLog(@"NNNNOOOOTTTTTTTT connected!!!!");
}
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet {
    NSLog(@"didReceiveMessage >>> data: %@", packet.data);
    NSData *packetData = [packet.data dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:packetData options:0 error:nil];
    NSString *qualifier = [json objectForKey:@"qualifier"];
    if ([qualifier isEqualToString:@"pt.openapi.context/createContextResponse"]) {
        id data = [json objectForKey:@"data"];
        if ([data objectForKey:@"contextId"] == [NSNull null]) {
            NSLog(@"NO CONTEXT ID");
        } else {
            contextId = [data objectForKey:@"contextId"];
            //check is no saved token in settings, must send request to server to set token
            NSData *oldToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceToken"];
            if (oldToken) {
                NSLog(@"I already have old token, let's check if something else needed");
                [self executeQue];
            } else {
                NSLog(@"I don't have old token, let's register my device");
                [self registerDeviceForPush];
            }
        }
    } else if ([qualifier isEqualToString:@"pt.openapi.push.devreg/registerDeviceResponse"]) {
        id data = [json objectForKey:@"data"];
        if ([data objectForKey:@"code"] == [NSNull null]) {
            //no code?
        } else if ([[data objectForKey:@"code"] integerValue] == 0) {
            //device successfuly registered, save token for future
            NSLog(@"device successfuly registered, save token for future & check if something else needed");
            [[NSUserDefaults standardUserDefaults] setObject:pushToken forKey:@"deviceToken"];
            //let's check if something else needed
            [self executeQue];
        }
    } else if([qualifier isEqualToString:@"pt.openapi.push.devreg/updateUserIdResponse"]) {
        id data = [json objectForKey:@"data"];
        if ([data objectForKey:@"code"] == [NSNull null]) {
            //no code?
        } else if ([[data objectForKey:@"code"] integerValue] == 0) {
            //user successfuly registered, save user for future
            NSLog(@"user successfuly registered, save user for future & check if something else needed");
            [[NSUserDefaults standardUserDefaults] setObject:saveUser forKey:@"username"];
            NSLog(@"saved user: %@",saveUser);
        }
    }
}
- (void) socketIO:(SocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet {
    NSLog(@"I Rcived json packet");
}
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet {
    NSLog(@"I Rcived event packet");
}
- (void) socketIO:(SocketIO *)socket didSendMessage:(SocketIOPacket *)packet {
    
}
- (void) socketIO:(SocketIO *)socket onError:(NSError *)error{
    NSLog(@"I have error: %@",[error debugDescription]);
}

- (void)handleUrlOpen:(NSURL*)url {
    NSLog(@"I GOT TO WRONG PLACE /:");
}

//suporting methods


@end
