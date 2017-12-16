//
//  LYOpenGLView.h
//  LearnVideoToolBox
//
//  Created by apple on 2017/12/16.
//  Copyright © 2017年 apple. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface LYOpenGLView : UIView

-(void)setupGL;
-(void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
