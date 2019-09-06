//
//  JSTool.h
//  HBJsNative
//
//  Created by Leon on 2019/9/6.
//  Copyright © 2019 huanghaipo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>


NS_ASSUME_NONNULL_BEGIN
///创建一个遵循JSExport的协议
@protocol JSToolProtocol <NSObject,JSExport>

// 提供给js调用原生的方法,如果想暴露一些属性也是可以的。
- (void)jsCallNativeMethod;


@end

@interface JSTool : NSObject<JSToolProtocol>

@property (nonatomic, strong) JSContext * jsContext;


@end

NS_ASSUME_NONNULL_END
