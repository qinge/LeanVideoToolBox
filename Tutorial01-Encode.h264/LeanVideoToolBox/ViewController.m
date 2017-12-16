//
//  ViewController.m
//  LeanVideoToolBox
//
//  Created by apple on 2017/12/16.
//  Copyright © 2017年 apple. All rights reserved.
//  http://www.jianshu.com/p/37784e363b8a

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>


@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *mCaptureSession; //负责输入和输出设备之间的数据传递
@property (nonatomic, strong) AVCaptureDeviceInput *mCaptureDeviceInput; //负责从AVCaptureDevice获得输入数据

@property (nonatomic, strong) AVCaptureVideoDataOutput *mCaptureDeviceOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *mPreviewLayer;

@end

@implementation ViewController{
    int frameID;
    dispatch_queue_t mCaptureQueue;
    dispatch_queue_t mEncodeQueue;
    VTCompressionSessionRef encodingSession;
    CMFormatDescriptionRef format;
    NSFileHandle *fileHandle;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)playButtonAction:(UIButton *)sender {
    if (!self.mCaptureSession || !self.mCaptureSession.running) {
        [sender setTitle:@"stop" forState:UIControlStateNormal];
        [self startCapture];
    }else{
        [sender setTitle:@"play" forState:UIControlStateNormal];
        [self stopCapture];
    }
}

#pragma mark - 开始录视频
-(void)startCapture{
    self.mCaptureSession = [[AVCaptureSession alloc] init];
    self.mCaptureSession.sessionPreset = AVCaptureSessionPreset640x480;
    
    mCaptureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    mEncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    AVCaptureDevice *inputCamera = nil;
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (device.position == AVCaptureDevicePositionBack) {
            inputCamera = device;
        }
    }
    
    self.mCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
    if ([self.mCaptureSession canAddInput:self.mCaptureDeviceInput]) {
        [self.mCaptureSession addInput:self.mCaptureDeviceInput];
    }
    
    self.mCaptureDeviceOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.mCaptureDeviceOutput setAlwaysDiscardsLateVideoFrames:NO]; // 指定是否丢弃新贞 当正在处理老贞时候
    
    [self.mCaptureDeviceOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [self.mCaptureDeviceOutput setSampleBufferDelegate:self queue:mCaptureQueue];
    if ([self.mCaptureSession canAddOutput:self.mCaptureDeviceOutput]) {
        [self.mCaptureSession addOutput:self.mCaptureDeviceOutput];
    }
    
    // 捕捉连接负责将捕捉会话接收的媒体类型和输出连接起来 比如AVCaptureAudioDataOutput可以接受音频数据，AVCaptureVideoDataOutput可以接受视频数据。会话通过捕捉连接，确定哪些输入视频，那些输入音频。通过对捕捉连接的访问，可以对信号流进行底层控制，比如禁用某些特定的连接
    AVCaptureConnection *connection = [self.mCaptureDeviceOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    self.mPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.mCaptureSession];
    [self.mPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [self.mPreviewLayer setFrame:self.view.bounds];
    [self.view.layer insertSublayer:self.mPreviewLayer atIndex:0];
    
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.h264"];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    
    [self initVideoToolBox];
    
    [self.mCaptureSession startRunning];
    
    
}

#pragma mark - 结束录视频
-(void)stopCapture{
    [self.mCaptureSession stopRunning];
    [self.mPreviewLayer removeFromSuperlayer];
    [self endVideoToolBox];
    [fileHandle closeFile];
    fileHandle = NULL;
}

#pragma mark - initVideoToolBox

-(void)initVideoToolBox{
    dispatch_sync(mEncodeQueue, ^{
        frameID = 0;
        int width = 480, height = 640;
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &encodingSession);
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        if (status != 0) {
            NSLog(@"H264: Unable to create a H264 session");
            return ;
        }
        
        // 设置实时编码输出（避免延迟）
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        // 设置关键帧（GOPsize)间隔
        int frameInterval = 10;
        CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        
        // 设置期望帧率
        int fps = 10;
        CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        
        //设置码率，上限，单位是bps
        int bitRate = width * height * 3 * 4 * 8;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        
        //设置码率，均值，单位是byte
        int bitRateLimit = width * height * 3 * 4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(encodingSession);
        
        
    });
}

#pragma mark - 编码
- (void) encode:(CMSampleBufferRef )sampleBuffer{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime presentationTimeStamp = CMTimeMake(frameID++, 1000);
    VTEncodeInfoFlags flags;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL,
                                                          NULL,
                                                          &flags);
    if (statusCode != noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
        VTCompressionSessionInvalidate(encodingSession);
        CFRelease(encodingSession);
        encodingSession = NULL;
        return;
    }
    NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
}

#pragma mark 编码完成回调
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) {
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    ViewController *encoder = (__bridge ViewController*)outputCallbackRefCon;
    CFDictionaryRef theDic = CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0);
    bool keyFrame = !CFDictionaryContainsKey(theDic, kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (keyFrame) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statueCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                 0,
                                                                                 &sparameterSet,
                                                                                 &sparameterSetSize,
                                                                                 &sparameterSetCount,
                                                                                 0);
        if (statueCode == noErr) {
            // Found sps and now check for pps
            size_t pparameteSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus ppStatusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                     1,
                                                                                     &pparameterSet,
                                                                                     &pparameteSetSize,
                                                                                     &pparameterSetCount,
                                                                                     0);
            if (ppStatusCode == noErr) {
                // Found pps
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameteSetSize];
                if (encoder) {
                    [encoder gotSpsPps:sps pps:pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRef = CMBlockBufferGetDataPointer(dataBuffer,
                                                         0,
                                                         &length,
                                                         &totalLength,
                                                         &dataPointer);
    if (statusCodeRef == noErr) {
        size_t bufferOffset = 0;
        // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        static const int AVCCHeaderLength = 4;
        
        // 循环获取nalu数据
        while (bufferOffset
                < totalLength - AVCCHeaderLength) {
            uint32_t NALUintLength = 0;
            memcpy(&NALUintLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUintLength = CFSwapInt32BigToHost(NALUintLength);
            NSData *data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUintLength];
            [encoder gotEncodedData:data isKeyFrame:keyFrame];
            bufferOffset += AVCCHeaderLength + NALUintLength;
        }
    }
}


- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps {
    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);
    const char bytes[] = "\x00\x00\x00\x01";
     //string literals have implicit trailing '\0'
    size_t length = (sizeof(bytes) - 1);
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:pps];
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame {
    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (fileHandle != NULL) {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = sizeof(bytes) - 1;
        NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
        [fileHandle writeData:byteHeader];
        [fileHandle writeData:data];
    }
}

#pragma mark - endVideoToolBox
-(void)endVideoToolBox{
    VTCompressionSessionCompleteFrames(encodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(encodingSession);
    CFRelease(encodingSession);
    encodingSession = NULL;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    dispatch_sync(mEncodeQueue, ^{
        [self encode:sampleBuffer];
    });
}



@end
