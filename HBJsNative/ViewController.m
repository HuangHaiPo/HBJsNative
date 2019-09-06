//
//  ViewController.m
//  HBJsNative
//
//  Created by Leon on 2019/9/6.
//  Copyright © 2019 huanghaipo. All rights reserved.
//

#import "ViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSTool.h"
#import <WebKit/WebKit.h>


@interface ViewController ()<UIWebViewDelegate,WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler>


@property (nonatomic ,strong) UIWebView *webView;
@property (nonatomic ,strong) WKWebView *wkWebView;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //获取本地html文件路径
    NSString *webPath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"html"];
    //通过路径创建web URL
    NSURL *webURL = [NSURL URLWithString:webPath];
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:webURL]];
    
    NSURL * urlstring = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"html"];

    [self.wkWebView loadRequest:[[NSURLRequest alloc]initWithURL:urlstring]];

}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    if ([request.URL.absoluteString hasSuffix:@"js_native://alert"]) {
        [self alertWidthValue:request.URL.absoluteString];
        [webView stringByEvaluatingJavaScriptFromString:@"jsCallBackNativeMethod('我是回调')"];
    }
    return YES;
}
- (void)webViewDidFinishLoad:(UIWebView *)webView{
    JSContext *jsContext = [webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    __weak typeof(self) weakSelf = self;
    //nativeAlert js定义的方法
    jsContext[@"nativeAlert"] = ^(){
        NSArray *arguments = [JSContext currentArguments];
        NSLog(@"%@",arguments);
        NSString *value = [NSString stringWithFormat:@"%@",[arguments objectAtIndex:0]];
        [self alertWidthValue:value];
        [weakSelf handleOtherOperating];
    };
    
    JSTool *jsTool = [[JSTool alloc]init];
    jsTool.jsContext = jsContext;
//    方式一
//    jsContext[@"jsTool"] = jsTool;
//    方式二
    [jsContext setObject:jsTool forKeyedSubscript:@"jsTool"];
}
- (void)handleOtherOperating {
    // 其他处理
    NSLog(@"原生处理方法 thread = %@", [NSThread currentThread]);
    // 原生回调js方法
    JSContext * context = [_webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    [context evaluateScript:@"nativeCallbackJscMothod('我是原生传过去的参数')"];
    
}
- (void)alertWidthValue:(NSString *)value{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"web与原生交互" message:value preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *conform = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }];
    [alert addAction:conform];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}
- (UIWebView *)webView{
    if (!_webView) {
        _webView = [[UIWebView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/2)];
        _webView.delegate = self;
        [self.view addSubview:_webView];
    }
    return _webView;
}

// 核心代码
//- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
//
//    NSURL * url = navigationAction.request.URL;
//    NSString * scheme = url.scheme;
//    NSString * query = url.query;
//    NSString * host = url.host;
//    if ([[url absoluteString] hasSuffix:@"js_native://alert"]) {
//        [self handleJSMessage];
//        decisionHandler(WKNavigationActionPolicyCancel);
//        return;
//    }
//    decisionHandler(WKNavigationActionPolicyAllow);
//}

- (void)handleJSMessage {
    // 回调JS方法
    [_wkWebView evaluateJavaScript:@"nativeCallbackJscMothod('123')" completionHandler:^(id _Nullable x, NSError * _Nullable error) {
//        NSLog(@"x = %@, error = %@", x, error.localizedDescription);
    }];
}
#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"jsCallNativeMethod"]) {
        NSLog(@"%@",message.body);
        [self handleJSMessage];
    }
}
#pragma mark - WKUIDelegate
// 处理JS中回调方法的alert方法 JS端调用alert()方法会触发下面这个方法，并且通过message获取到alert的信息
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"温馨提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    completionHandler();
}

- (WKWebView *)wkWebView{
    if (!_wkWebView) {
        //初始化WKWebView的配置
        WKWebViewConfiguration * configuration = [[WKWebViewConfiguration alloc] init];
//        配置JS交互的代码
        configuration.userContentController = [WKUserContentController new];
//      MessageHandler添加对象 记得实现协议<WKScriptMessageHandler>  name JS发送postMessage的对象
        [configuration.userContentController addScriptMessageHandler:self name:@"jsCallNativeMethod"];
//        配置webView能否使用JS或者其他插件等
        WKPreferences * preferences = [WKPreferences new];
        preferences.javaScriptCanOpenWindowsAutomatically = YES;
        preferences.minimumFontSize = 50.0;
        configuration.preferences = preferences;
        
        _wkWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_webView.frame), [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/2) configuration:configuration];
        _wkWebView.navigationDelegate = self;
        _wkWebView.UIDelegate = self;// 设置交互代理
        [self.view addSubview:_wkWebView];
        
    }
    return _wkWebView;
}

- (void)dealloc {
    // 为了避免循环引用，导致控制器无法被释放，需要移除
    [self.wkWebView.configuration.userContentController removeScriptMessageHandlerForName:@"jsCallNativeMethod"];
}
@end
