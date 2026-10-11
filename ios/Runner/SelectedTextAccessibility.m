#import "SelectedTextAccessibility.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *pixezSelectedText = @"";

void PixezSetSelectedText(NSString *text) {
  pixezSelectedText = text.length ? [text copy] : @"";
}

static NSString *PixezSelectedTextMethod(id self, SEL cmd) {
  (void)self;
  (void)cmd;
  return pixezSelectedText.length ? pixezSelectedText : nil;
}

static NSRange PixezSelectedTextRangeMethod(id self, SEL cmd) {
  (void)cmd;
  if (pixezSelectedText.length == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  NSString *haystack = nil;
  if ([self respondsToSelector:@selector(accessibilityLabel)]) {
    haystack = [self accessibilityLabel];
  }
  if (haystack.length == 0 && [self respondsToSelector:@selector(accessibilityValue)]) {
    haystack = [self accessibilityValue];
  }
  if (haystack.length == 0) {
    Class viewClass = NSClassFromString(@"FlutterView");
    if (viewClass != Nil && [self isKindOfClass:viewClass]) {
      return NSMakeRange(0, pixezSelectedText.length);
    }
    return NSMakeRange(NSNotFound, 0);
  }
  NSRange found = [haystack rangeOfString:pixezSelectedText];
  if (found.location == NSNotFound) {
    return NSMakeRange(NSNotFound, 0);
  }
  return found;
}

static void PixezAddSelectedTextMethods(Class cls) {
  if (cls == Nil) {
    return;
  }
  class_addMethod(cls, NSSelectorFromString(@"_accessibilitySelectedText"),
                  (IMP)PixezSelectedTextMethod, "@@:");
  class_addMethod(cls, NSSelectorFromString(@"_accessibilitySelectedTextRange"),
                  (IMP)PixezSelectedTextRangeMethod, "{_NSRange=QQ}@:");
}

void PixezInstallSelectedTextAccessibility(void) {
  PixezAddSelectedTextMethods(NSClassFromString(@"SemanticsObject"));
  PixezAddSelectedTextMethods(NSClassFromString(@"FlutterView"));
}
