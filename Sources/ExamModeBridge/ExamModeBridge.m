// Loads macOS 27's private MenuBarClientCore at run time and drives its exam-mode
// (assessment) allow-list. Nothing links the framework at build time: if a macOS
// update removes or renames it, Stow reports "unavailable" instead of failing to
// launch. API usage learned from dwarvesf/hidden (MIT); this is a fresh
// implementation. Background: docs/macos-27-menu-bar-findings.md.
#import "ExamModeBridge.h"
#import <dlfcn.h>

// Shapes of the private classes, declared so ARC applies normal init and ownership rules.
@protocol SXAssessmentConfiguration <NSObject>
- (instancetype)initWithAllowedSystemItems:(NSArray<NSNumber *> *)systemItems
                  allowedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers;
@end

@protocol SXAssessmentAssertion <NSObject>
- (void)activateWithConfiguration:(id)configuration
                completionHandler:(void (^)(NSError * _Nullable error))completion;
- (void)invalidate;
@end

static NSString *const SXFrameworkPath = @"/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore";
static NSString *const SXConfigurationClassName = @"MBAssessmentModeConfiguration";
static NSString *const SXAssertionClassName = @"MBAssessmentModeAssertion";
static NSString *const SXErrorDomain = @"studio.longbrook.stow.ExamMode";

static NSError *SXError(NSString *reason) {
    return [NSError errorWithDomain:SXErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: reason}];
}

BOOL SXExamModeIsAvailable(void) {
    if (dlopen(SXFrameworkPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL) == NULL) {
        return NO;
    }
    Class configuration = NSClassFromString(SXConfigurationClassName);
    Class assertion = NSClassFromString(SXAssertionClassName);
    return configuration != Nil && assertion != Nil
        && [configuration instancesRespondToSelector:@selector(initWithAllowedSystemItems:allowedBundleIdentifiers:)]
        && [assertion instancesRespondToSelector:@selector(activateWithConfiguration:completionHandler:)]
        && [assertion instancesRespondToSelector:@selector(invalidate)];
}

void SXExamModeActivate(NSArray<NSNumber *> *systemItems,
                        NSArray<NSString *> *bundleIDs,
                        void (^completion)(id _Nullable assertion, NSError * _Nullable error)) {
    void (^finish)(id, NSError *) = ^(id assertion, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(assertion, error); });
    };
    if (!SXExamModeIsAvailable()) {
        finish(nil, SXError(@"Hiding isn't available on this version of macOS."));
        return;
    }
    @try {
        // Both lists must be NSArrays: the framework indexes into them (an NSSet raises -objectAtIndex:).
        id<SXAssessmentConfiguration> configuration =
            [(id<SXAssessmentConfiguration>)[NSClassFromString(SXConfigurationClassName) alloc]
                initWithAllowedSystemItems:[systemItems copy]
                  allowedBundleIdentifiers:[bundleIDs copy]];
        id<SXAssessmentAssertion> assertion = [[NSClassFromString(SXAssertionClassName) alloc] init];
        if (configuration == nil || assertion == nil) {
            finish(nil, SXError(@"Couldn't create the exam-mode configuration."));
            return;
        }
        [assertion activateWithConfiguration:configuration completionHandler:^(NSError *error) {
            finish(error == nil ? assertion : nil, error);
        }];
    } @catch (NSException *exception) {
        finish(nil, SXError([NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]));
    }
}

void SXExamModeInvalidate(id assertion) {
    @try {
        if ([assertion respondsToSelector:@selector(invalidate)]) {
            [(id<SXAssessmentAssertion>)assertion invalidate];
        }
    } @catch (NSException *exception) {
        NSLog(@"Stow: invalidate raised %@: %@", exception.name, exception.reason);
    }
}
