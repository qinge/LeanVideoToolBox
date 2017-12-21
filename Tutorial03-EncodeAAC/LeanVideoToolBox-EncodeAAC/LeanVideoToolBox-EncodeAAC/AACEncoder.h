//
//  AACEncoder.h
//  LeanVideoToolBox-EncodeAAC
//
//  Created by apple on 2017/12/18.
//  Copyright © 2017年 apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


@interface AACEncoder : NSObject

@property (nonatomic, strong) dispatch_queue_t encoderQueue;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;

-(void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(NSData *encodedData, NSError *error)) completionBlock;

@end
