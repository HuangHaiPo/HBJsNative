# HBJsNative
JS和原生通信

## 一、采用拦截URL请求的方式
### 1. 事先和前端定好要拦截的URL，实现UIWebView的代理方法`shouldStartLoadWithRequest`，在方法中对实现定义好的URL进行拦截，拦截到后处理原生逻辑，及回调。

```
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    if ([request.URL.absoluteString hasSuffix:@"js_native://alert"]) {
        //这个是弹框
        [self alertWidthValue:request.URL.absoluteString];
        //这个是回调
        [webView stringByEvaluatingJavaScriptFromString:@"jsCallBackNativeMethod('我是回调')"];
    }
    return YES;
}


H5代码
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
            <title>js和原生的交互</title>
    </head>
    <body>
        
        <h1>js和原生的交互 调用原生弹框</h1>
        <button onclick="jsCallNativeMethod()" style="border: 1px solid black">通过拦截URL弹原生弹框</button>
        
        </body>
</html>
<script>
    function jsCallNativeMethod() {
        //可以传参数拼在后面就行
        location.href = "js_native://alert";
    }
    //原生回调js方法
     function jsCallBackNativeMethod(arguments) {
        alert('原生调用js方法 传来的参数 = ' + arguments);
    }
  </script>

原生回调js
[self.webView stringByEvaluatingJavaScriptFromString:@"jsCallBackNativeMethod('我是回调')"];
```

## 二、通过JavaScriptCore

```
步骤：
1. 和前端约定好要传的参数和方法名、回调方法等。
2. 实现webViewDidFinishLoad代理方法，获取js，在里写实现要调用的原生方法，接收传来的参数。
3. 利用evaluateScript执行回调html的方法
```

实现方法一：直接获取js中定义好的方法
```
- (void)webViewDidFinishLoad:(UIWebView *)webView{
    JSContext *jsContext = [webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    __weak typeof(self) weakSelf = self;
    //nativeAlert js定义的方法
    jsContext[@"nativeAlert"] = ^(){
    //传来的参数
        NSArray *arguments = [JSContext currentArguments];
        NSLog(@"%@",arguments);
        NSString *value = [NSString stringWithFormat:@"%@",[arguments objectAtIndex:0]];
        [self alertWidthValue:value];
        [weakSelf handleOtherOperating];
    };
}

- (void)handleOtherOperating {
    // 其他处理
    NSLog(@"原生处理方法 thread = %@", [NSThread currentThread]);
    // 原生回调js方法
    JSContext * context = [_webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    [context evaluateScript:@"nativeCallbackJscMothod('我是原生传过去的参数')"];
    
}

h5代码
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
            <title>js和原生的交互</title>
    </head>
    <body>
        
        <h1>js和原生的交互 调用原生弹框</h1>
    
        
        <button onclick="jscCallNativeMethod()" style="border: 1px solid black">通过JavaScriptCore实现JS原生交互</button>
        


    </body>
</html>
<script>


    function jscCallNativeMethod() {
        nativeAlert('我是传来的参数1', '我是传来的参数2');
    }
    // 原生的回调方法 可以接收原生传来的参数
    function nativeCallbackJscMothod(arguments) {
        alert('原生调用js方法 传来的参数 = ' + arguments);
    }
</script>

```

实现方法二：利用JSExport协议来处理
```
步骤：
1. 在html页面中定义需要调用原生的方法、原生回调JS的方法
2. 创建一个工具类实现一个遵守JSExport的协议，提供js需要调用的方法
3. 在webViewDidFinishLoad中利用JSContext将这个类暴露给html
```

```
//创建一个工具类实现一个遵守JSExport的协议，提供js需要调用的方法
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



@implementation JSTool

- (void)jsCallNativeMethod {
    NSLog(@"js 调用 原生方法");
    // 如果还想要调用js的方法就需要拿到webView的JSContext
    [self.jsContext evaluateScript:@"nativeCallbackJscMothod('原生传递的参数')"];
}


@end



<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
            <title>js和原生的交互</title>
    </head>
    <body>
        
        <h1>js和原生的交互 调用原生弹框</h1>
        <button onclick="jseCallNativeMethod()" style="border: 1px solid black">通过JSExport协议实现JS原生交互</button>

    </body>
</html>
<script>
        function jseCallNativeMethod() {
        jsTool.jsCallNativeMethod();//要和工具类定义的方法一样
    }
    // 原生的回调方法 可以接收原生传来的参数
    function nativeCallbackJscMothod(arguments) {
        alert('原生调用js方法 传来的参数 = ' + arguments);
    }
</script>


- (void)webViewDidFinishLoad:(UIWebView *)webView{
    JSContext *jsContext = [webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];    
    JSTool *jsTool = [[JSTool alloc]init];
    jsTool.jsContext = jsContext;
//    方式一
//    jsContext[@"jsTool"] = jsTool;
//    方式二
    [jsContext setObject:jsTool forKeyedSubscript:@"jsTool"];
}

```


## 三、通过WKWebView

```
* WKWebViewConfiguration用来初始化WKWebView的配置。
* WKPreferences配置webView能否使用JS或者其他插件等
* WKUserContentController用来配置JS交互的代码
* UIDelegate用来控制WKWebView中一些弹窗的显示(alert、confirm、prompt)。
* WKNavigationDelegate用来监听网页的加载情况，包括是否允许加载，加载失败、成功加载等一些列代理方法。
```

```

// 拦截URL
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURL * url = navigationAction.request.URL;
    NSString * scheme = url.scheme;
    NSString * query = url.query;
    NSString * host = url.host;
    if ([[url absoluteString] hasSuffix:@"js_native://alert"]) {
        [self handleJSMessage];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)handleJSMessage {
    // 回调JS方法
    [_wkWebView evaluateJavaScript:@"nativeCallbackJscMothod('123')" completionHandler:^(id _Nullable x, NSError * _Nullable error) {
        NSLog(@"x = %@, error = %@", x, error.localizedDescription);
    }];
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
//        配置webView能否使用JS或者其他插件等
        WKPreferences * preferences = [WKPreferences new];
        preferences.javaScriptCanOpenWindowsAutomatically = YES;
        preferences.minimumFontSize = 50.0;
        configuration.preferences = preferences;
        
        _wkWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_webView.frame), [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/2) configuration:configuration];
        _wkWebView.navigationDelegate = self;
        _wkWebView.UIDelegate = self;
        [self.view addSubview:_wkWebView];
        
    }
    return _wkWebView;
}


<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
            <title>js和原生的交互</title>
    </head>
    <body>
        
        <h1>js和原生的交互 调用原生弹框</h1>
        <button onclick="jsCallNativeMethod()" style="border: 1px solid black">通过拦截URL弹原生弹框</button>
    </body>
</html>
<script>
    function jsCallNativeMethod() {
        //可以传参数拼在后面就行
        location.href = "js_native://alert";
    }
    // 原生的回调方法 可以接收原生传来的参数
    function nativeCallbackJscMothod(arguments) {
        alert('原生调用js方法 传来的参数 = ' + arguments);
    }
</script>



```
## 四、通过WKScriptMessageHandler

```
WKWebView不支持JavaScriptCore。此时我们可以使用WKWebView的WKScriptMessageHandler。

1. 在原生代码中利用userContentController添加JS端需要调用的原生方法
2. 实现WKScriptMessageHandler协议中唯一一个方法`didReceiveScriptMessage`
3. 在该方法中根据message.name获取调用的方法名做相应的处理，通过message.body获取JS端传递的参数
4.在JS端通过`window.webkit.messageHandlers.methodName(事先定好的名称).postMessage(['name','参数','age', 18])`给WK发送消息`didReceiveScriptMessage`这个方法会接收到，可以通过`message.body`获取传来的值。
```


#### 1. 通过`initWithFrame:configuration`初始化方法，给`configuration`传入`WKWebViewConfiguration`对象，在`WKWebViewConfiguration`配置和`JS`交互的方法。
```
- (WKWebView *)wkWebView{
    if (!_wkWebView) {
        //初始化WKWebView的配置
        WKWebViewConfiguration * configuration = [[WKWebViewConfiguration alloc] init];
//        配置JS交互的代码
        configuration.userContentController = [WKUserContentController new];
//      MessageHandler添加对象 记得实现协议<WKScriptMessageHandler>  name JS发送postMessage的对象
        [configuration.userContentController addScriptMessageHandler:self name:@"jsCallNativeMethod"];
        _wkWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_webView.frame), [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/2) configuration:configuration];
        _wkWebView.navigationDelegate = self;
        _wkWebView.UIDelegate = self;
        [self.view addSubview:_wkWebView];
        
    }
    return _wkWebView;
}
```

#### 2. 实现<WKScriptMessageHandler>协议，并且实现`didReceiveScriptMessage`代理方法，当js调用`jsCallNativeMethod`方式时，会回调这个代理方法。

```
#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"jsCallNativeMethod"]) {
    //这个是传过来的参数
        NSLog(@"%@",message.body);
 // 回调JS方法
    [_wkWebView evaluateJavaScript:@"nativeCallbackJscMothod('123')" completionHandler:^(id _Nullable x, NSError * _Nullable error) {
//        NSLog(@"x = %@, error = %@", x, error.localizedDescription);
    }];
        }
}
```
#### 3. js调用

```
// window.webkit.messageHandlers.<name>.postMessage(<messageBody>)
// 这个name就是设置MessageHandler的第二个参数
function jsCallNativeMethod() {
        window.webkit.messageHandlers.jsCallNativeMethod.postMessage('我的参数');
    }
```
#### 4. 移除
```
   - (void)dealloc {
   // 为了避免循环引用，导致控制器无法被释放，需要移除
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"jsCallNativeMethod"];
}
```
## 五、通过第三方库`WebViewJavascriptBridge`

[WebViewJavascriptBridge 地址](https://github.com/marcuswestin/WebViewJavascriptBridge)

