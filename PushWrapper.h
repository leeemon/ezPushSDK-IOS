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

#import <Foundation/Foundation.h>
#import "SocketIO.h"
#import "SocketIOPacket.h"

@protocol PushWrapper <NSObject>
@optional
- (void)handleUrlOpen:(NSURL*)url;
@end

@interface PushWrapper : NSObject <SocketIODelegate> {
    SocketIO *socketIO;
}

@property (weak) id<PushWrapper> delegate;

+ (id)sharedManager;

-(void)setTokenAndConnect:(NSData *)token;
-(void)registerUserName:(NSString*) username;
-(void)processRemoteNotification:(NSDictionary*)userInfo;

//WEB SOCKET METHODS
- (void) socketIODidConnect:(SocketIO *)socket;
- (void) socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error;
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didSendMessage:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket onError:(NSError *)error;


@end
