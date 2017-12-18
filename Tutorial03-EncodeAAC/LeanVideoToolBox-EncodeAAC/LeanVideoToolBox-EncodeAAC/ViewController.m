//
//  ViewController.m
//  LeanVideoToolBox-EncodeAAC
//
//  Created by apple on 2017/12/18.
//  Copyright © 2017年 apple. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic , strong) UILabel  *mLabel;
@property (nonatomic, strong) AVCaptureSession *mCaptureSession; //负责输入和输出设备之间的数据传递
@property (nonatomic, strong) AVCaptureDeviceInput *mCaptureVideoDeviceInput; //负责从AVCaptureDevice获得输入数据
@property (nonatomic, strong) AVCaptureDeviceInput *mCaptureAudioDeviceInput; //负责从AVCaptureDevice获得输入数据

@property (nonatomic, strong) AVCaptureVideoDataOutput *mCaptureVideoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *mCaptureAudioOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *mPreviewLayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate



#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate

@end
