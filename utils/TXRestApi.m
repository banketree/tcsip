//
//  TXRestApi.m
//  Texr
//
//  Created by Ilya Petrov on 8/26/12.
//  Copyright (c) 2012 Ilya Petrov. All rights reserved.
//

#import "TXRestApi.h"
#import "JSONKit.h"
#import "Callback.h"
#import "TXSip.h"
#import "ReWrap.h"

#include "http.h"

#define URL(__x) ((NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,\
   (__bridge CFStringRef)__x,\
    NULL,\
    CFSTR("!*'();:@&=+$,/?%#[]"),\
    kCFStringEncodingUTF8)))

static struct httpc app;
static MailBox* root_box;
static ReWrap* wrapper;
static NSDateFormatter *df = NULL;

static void setup_df() {
    df = [[NSDateFormatter alloc] init];
    df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    df.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
}

static void http_ret(struct request *req, int code, void *arg) {

    TXRestApi *r = (__bridge_transfer TXRestApi*)arg;
    struct pl *data = http_data(req);
    NSData *nd = [NSData dataWithBytes:data->p length:data->l];
    [r code: code data:nd];
}

static void http_done(struct request *req, int code, void *arg) {
    char *user=NULL, *pass=NULL;
    int ok = -EINVAL;
    TXRestApi *r = (__bridge TXRestApi*)arg;

    if(code==401) {
	[r getAuth: &user password: &pass];

	if(user && pass)
	    ok = http_auth(req, user, pass);

	if(user)
	    free(user);
	if(pass)
            free(pass);

	if(ok!=0)
	    http_ret(req, code, arg); 
	return;
    }
    http_ret(req, code, arg);
}

static void http_err(int err, void *arg) {
    TXRestApi *r = (__bridge_transfer TXRestApi*)arg;
    [r fail];
}


@implementation TXRestApi
+ (void)r: (NSString*)path cb:(id)cb
{
    TXRestApi *api = [[TXRestApi alloc] init];
    api = [wrapper wrap:api];
    [api rload: path cb: cb];
    [api start];
}

+ (void)r: (NSString*)path cb:(id)cb user:(NSString*)u password:(NSString*)p
{
    TXRestApi *api = [[TXRestApi alloc] init];
    api = [wrapper wrap:api];
    [api rload: path cb: cb];
    [api setAuth: u password:p];
    [api start];
}

+ (id)api
{
    TXRestApi *api = [[TXRestApi alloc] init];
    return [wrapper wrap:api];
}

- (void)rload: (NSString*)path cb:(id)pCb
{
    NSString *url = [NSString stringWithFormat:@"https://www.texr.net/api/%@",path];
    http_init(&app, &request, (char*)_byte(url));
    http_cb(request, (__bridge_retained void*)self, http_done, http_err);
    cb = [MProxy withTargetBox: pCb box:root_box];
    request = mem_ref(request);
}

- (void)post:(NSString*)key val:(NSString*)val
{
    http_post(request,
                  (char*)_byte(URL(key)),
                  (char*)_byte(URL(val)));
}

- (void)post:(NSString*)val
{
    http_post(request, NULL, (char*)_byte(val));
}
- (void)ifs:(NSDate*)date
{
    NSString *header = [df stringFromDate:date];
    http_header(request, "If-Modified-Since", (char*)_byte(header));
}

- (oneway void)start
{
    http_send(request);
}

- (void)code:(int) code data:(NSData*)data
{
    request = NULL;
    // Use responseData
    if(code!=200) {
        [self fail];
        return;
    }

    JSONDecoder* decoder = [JSONDecoder decoder];
    NSDictionary *ret = [decoder objectWithData: data];

    [cb response: ret];
}
- (void)fail
{
   [cb response: nil];
}

- (void) setAuth:(NSString*)pU password:(NSString*)pW
{
    username = pU;
    password = pW;
}

- (void) getAuth:(char**)_user password:(char**)_passw
{
    *_user = byte(username);
    *_passw = byte(password);
}


+ (void) cert:(NSString*)cert
{
    int err;
    if(app.tls)
        mem_deref(app.tls);

    err = tls_alloc(&app.tls, TLS_METHOD_SSLV23, cert ? _byte(cert) : NULL, NULL);

    NSBundle *b = [NSBundle mainBundle];
    NSString *ca_cert;
    ca_cert = [b pathForResource:@"STARTSSL" ofType: @"cert"];
    err = tls_add_ca(app.tls, _byte(ca_cert));
}

+ (void)wrapper: (id)_wrapper
{
    wrapper = _wrapper;
    void *_app = wrapper.app;
    memcpy(&app, _app, sizeof(struct httpc));

    if(!df) setup_df();

}

+ (void)retbox: (MailBox*)_box
{
    root_box = _box;
}

- (void) dealloc
{
    mem_deref(request);
}

@end
