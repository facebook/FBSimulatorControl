//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Feb 20 2016 22:04:40).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <SimulatorKit/FoundationXPCProtocolProxyable-Protocol.h>
#import <SimulatorKit/NSObject-Protocol.h>

@protocol SimDisplayRenderable <FoundationXPCProtocolProxyable, NSObject>
@property (nonatomic, readonly) long long displaySizeInBytes;
@property (nonatomic, readonly) long long displayPitch;
@property (nonatomic, readonly) struct CGSize optimizedDisplaySize;
@property (nonatomic, readonly) struct CGSize displaySize;
@end
