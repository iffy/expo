/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI23_0_0RCTLinkingManager.h"

#import <ReactABI23_0_0/ABI23_0_0RCTBridge.h>
#import <ReactABI23_0_0/ABI23_0_0RCTEventDispatcher.h>
#import <ReactABI23_0_0/ABI23_0_0RCTUtils.h>

static NSString *const kOpenURLNotification = @"ABI23_0_0RCTOpenURLNotification";

static void postNotificationWithURL(NSURL *URL, id sender)
{
  NSDictionary<NSString *, id> *payload = @{@"url": URL.absoluteString};
  [[NSNotificationCenter defaultCenter] postNotificationName:kOpenURLNotification
                                                      object:sender
                                                    userInfo:payload];
}

@implementation ABI23_0_0RCTLinkingManager

ABI23_0_0RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)startObserving
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleOpenURLNotification:)
                                               name:kOpenURLNotification
                                             object:nil];
}

- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"url"];
}

+ (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)URL
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
  postNotificationWithURL(URL, self);
  return YES;
}

+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
  postNotificationWithURL(URL, self);
  return YES;
}

+ (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
  restorationHandler:(void (^)(NSArray *))restorationHandler
{
  if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
    NSDictionary *payload = @{@"url": userActivity.webpageURL.absoluteString};
    [[NSNotificationCenter defaultCenter] postNotificationName:kOpenURLNotification
                                                        object:self
                                                      userInfo:payload];
  }
  return YES;
}

- (void)handleOpenURLNotification:(NSNotification *)notification
{
  [self sendEventWithName:@"url" body:notification.userInfo];
}

ABI23_0_0RCT_EXPORT_METHOD(openURL:(NSURL *)URL
                  resolve:(ABI23_0_0RCTPromiseResolveBlock)resolve
                  reject:(ABI23_0_0RCTPromiseRejectBlock)reject)
{
  BOOL opened = [ABI23_0_0RCTSharedApplication() openURL:URL];
  if (opened) {
    resolve(nil);
  } else {
    reject(ABI23_0_0RCTErrorUnspecified, [NSString stringWithFormat:@"Unable to open URL: %@", URL], nil);
  }
}

ABI23_0_0RCT_EXPORT_METHOD(canOpenURL:(NSURL *)URL
                  resolve:(ABI23_0_0RCTPromiseResolveBlock)resolve
                  reject:(__unused ABI23_0_0RCTPromiseRejectBlock)reject)
{
  if (ABI23_0_0RCTRunningInAppExtension()) {
    // Technically Today widgets can open urls, but supporting that would require
    // a reference to the NSExtensionContext
    resolve(@NO);
    return;
  }

  // TODO: on iOS9 this will fail if URL isn't included in the plist
  // we should probably check for that and reject in that case instead of
  // simply resolving with NO

  // This can be expensive, so we deliberately don't call on main thread
  BOOL canOpen = [ABI23_0_0RCTSharedApplication() canOpenURL:URL];
  resolve(@(canOpen));
}

ABI23_0_0RCT_EXPORT_METHOD(getInitialURL:(ABI23_0_0RCTPromiseResolveBlock)resolve
                  reject:(__unused ABI23_0_0RCTPromiseRejectBlock)reject)
{
  NSURL *initialURL = nil;
  if (self.bridge.launchOptions[UIApplicationLaunchOptionsURLKey]) {
    initialURL = self.bridge.launchOptions[UIApplicationLaunchOptionsURLKey];
  } else {
    NSDictionary *userActivityDictionary =
      self.bridge.launchOptions[UIApplicationLaunchOptionsUserActivityDictionaryKey];
    if ([userActivityDictionary[UIApplicationLaunchOptionsUserActivityTypeKey] isEqual:NSUserActivityTypeBrowsingWeb]) {
      initialURL = ((NSUserActivity *)userActivityDictionary[@"UIApplicationLaunchOptionsUserActivityKey"]).webpageURL;
    }
  }
  resolve(ABI23_0_0RCTNullIfNil(initialURL.absoluteString));
}

@end
