//
//  ViewController.m
//  LearnVideoToolBox
//
//  Created by apple on 2017/12/16.
//  Copyright © 2017年 apple. All rights reserved.
//  http://www.jianshu.com/p/da18b979aeec

#import "ViewController.h"
#import "LYOpenGLView.h"
#import <VideoToolbox/VideoToolbox.h>

const uint8_t lyStartCode[4] = {0,0,0,1};

@interface ViewController ()

@property (nonatomic , strong) LYOpenGLView *mOpenGLView;
@property (nonatomic , strong) UILabel  *mLabel;
@property (nonatomic , strong) UIButton *mButton;
@property (nonatomic , strong) CADisplayLink *mDispalyLink;

@end

@implementation ViewController{
    dispatch_queue_t mDecodeQueue;
    VTDecompressionSessionRef mDecodeSession;
    CMFormatDescriptionRef mFormatDescription;
    uint8_t *mSPS;
    long mSPSSize;
    uint8_t *mPPS;
    long mPPSSize;
    
    // 输入
    NSInputStream *inputStream;
    uint8_t *packetBuffer;
    long packetSize;
    uint8_t *inputBuffer;
    long inputSize;
    long inputMaxSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mOpenGLView = (LYOpenGLView *)self.view;
    [self.mOpenGLView setupGL];
    
    mDecodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    self.mLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 200, 100)];
    self.mLabel.textColor = [UIColor redColor];
    [self.view addSubview:self.mLabel];
    self.mLabel.text = @"测试H264硬解码";
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(200, 20, 100, 100)];
    [button setTitle:@"play" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
    self.mButton = button;
    
    self.mDispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.mDispalyLink.frameInterval = 2; // 默认是30FPS的帧率录制
    [self.mDispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.mDispalyLink setPaused:YES];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onClick:(UIButton *)button {
    button.hidden = YES;
    [self startDecode];
}

-(void)startDecode {
    [self onInputStart];
    [self.mDispalyLink setPaused:NO];
}

- (void)onInputStart {
    inputStream = [[NSInputStream alloc] initWithFileAtPath:[[NSBundle mainBundle] pathForResource:@"abc" ofType:@"h264"]];
    [inputStream open];
    inputSize = 0;
    inputMaxSize = 640 * 480 * 3 * 4;
    inputBuffer = malloc(inputMaxSize);
}

-(void)onInputEnd{
    
}

#pragma mark - updateFrame
-(void)updateFrame{
    if (inputStream) {
        dispatch_sync(mDecodeQueue, ^{
            [self readPacket];
            if (packetBuffer == NULL || packetSize == 0) {
                [self onInputEnd];
                return ;
            }
            uint32_t nalSize = (uint32_t)(packetSize - 4);
            uint32_t *pNalSize = (uint32_t *)packetBuffer;
            *pNalSize = CFSwapInt32HostToBig(nalSize);
            
            // 在buffer的前面填入代表长度的int
            CVPixelBufferRef piexlBuffer = NULL;
            int nalType = packetBuffer[4] & 0x1f;
            switch (nalType) {
                case 0x05:
                    NSLog(@"Nal type is IDR frame");
                    [self initVideoToolBox];
                    piexlBuffer = [self decode];
                    break;
                    
                default:
                    break;
            }
        });
    }
}



-(void)readPacket{
    
}

-(void)initVideoToolBox {
    
}

-(CVPixelBufferRef)decode{
    return nil;
}
@end
