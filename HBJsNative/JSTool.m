//
//  JSTool.m
//  HBJsNative
//
//  Created by Leon on 2019/9/6.
//  Copyright © 2019 huanghaipo. All rights reserved.
//

#import "JSTool.h"


@implementation JSTool

- (void)jsCallNativeMethod {
    NSLog(@"js 调用 原生方法");
    // 如果还想要调用js的方法就需要拿到webView的JSContext
    [self.jsContext evaluateScript:@"nativeCallbackJscMothod('原生传递的参数')"];
}


@end
