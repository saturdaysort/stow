#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// YES when macOS's private MenuBarClientCore loads and exposes the exam-mode classes.
BOOL SXExamModeIsAvailable(void);

/// Restricts the menu bar to the given allow-list. `completion` always runs on the main queue,
/// with a non-nil assertion on success or an error on failure.
void SXExamModeActivate(NSArray<NSNumber *> *systemItems,
                        NSArray<NSString *> *bundleIDs,
                        void (^completion)(id _Nullable assertion, NSError * _Nullable error));

/// Releases an assertion returned by SXExamModeActivate. Safe to call more than once.
void SXExamModeInvalidate(id assertion);

NS_ASSUME_NONNULL_END
