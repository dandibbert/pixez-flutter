#import "SelectedTextAccessibility.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *pixezSelectedText = @"";
static IMP pixezOrigIsAccessibilityElement = NULL;
static IMP pixezOrigAccessibilityLabel = NULL;
static IMP pixezOrigAccessibilityValue = NULL;

void PixezSetSelectedText(NSString *text) {
  pixezSelectedText = text.length ? [text copy] : @"";
}

static BOOL PixezIsFlutterView(id object) {
  Class viewClass = NSClassFromString(@"FlutterView");
  return viewClass != Nil && [object isKindOfClass:viewClass];
}

static NSString *PixezSelectedTextMethod(id self, SEL cmd) {
  (void)self;
  (void)cmd;
  return pixezSelectedText.length ? pixezSelectedText : nil;
}

static NSRange PixezSelectedTextRangeMethod(id self, SEL cmd) {
  (void)self;
  (void)cmd;
  if (pixezSelectedText.length == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  return NSMakeRange(0, pixezSelectedText.length);
}

static void PixezCopy(id self, SEL cmd, id sender) {
  (void)self;
  (void)cmd;
  (void)sender;
  if (pixezSelectedText.length == 0) {
    return;
  }
  [UIPasteboard generalPasteboard].string = pixezSelectedText;
}

static BOOL PixezIsAccessibilityElement(id self, SEL cmd) {
  BOOL original = NO;
  if (pixezOrigIsAccessibilityElement != NULL) {
    original = ((BOOL(*)(id, SEL))pixezOrigIsAccessibilityElement)(self, cmd);
  }
  if (pixezSelectedText.length == 0 || !PixezIsFlutterView(self)) {
    return original;
  }
  return YES;
}

static NSString *PixezAccessibilityLabel(id self, SEL cmd) {
  if (pixezSelectedText.length > 0 && PixezIsFlutterView(self)) {
    return pixezSelectedText;
  }
  if (pixezOrigAccessibilityLabel == NULL) {
    return nil;
  }
  return ((NSString * (*)(id, SEL))pixezOrigAccessibilityLabel)(self, cmd);
}

static NSString *PixezAccessibilityValue(id self, SEL cmd) {
  if (pixezSelectedText.length > 0 && PixezIsFlutterView(self)) {
    return pixezSelectedText;
  }
  if (pixezOrigAccessibilityValue == NULL) {
    return nil;
  }
  return ((NSString * (*)(id, SEL))pixezOrigAccessibilityValue)(self, cmd);
}

static void PixezInstall(Class cls, SEL sel, IMP imp, const char *types, IMP *original) {
  if (cls == Nil) {
    return;
  }
  Method method = class_getInstanceMethod(cls, sel);
  if (method == NULL) {
    class_addMethod(cls, sel, imp, types);
    return;
  }
  Class owner = class_getSuperclass(cls);
  Method superMethod = owner == Nil ? NULL : class_getInstanceMethod(owner, sel);
  if (superMethod != NULL && method_getImplementation(method) == method_getImplementation(superMethod)) {
    if (original != NULL) {
      *original = method_getImplementation(method);
    }
    class_addMethod(cls, sel, imp, types);
    return;
  }
  IMP previous = method_setImplementation(method, imp);
  if (original != NULL && *original == NULL) {
    *original = previous;
  }
}

static void PixezAddSelectedText(Class cls) {
  if (cls == Nil) {
    return;
  }
  class_addMethod(cls, @selector(accessibilitySelectedText), (IMP)PixezSelectedTextMethod, "@@:");
  class_addMethod(cls, NSSelectorFromString(@"_accessibilitySelectedText"),
                  (IMP)PixezSelectedTextMethod, "@@:");
  class_addMethod(cls, @selector(accessibilitySelectedTextRange), (IMP)PixezSelectedTextRangeMethod,
                  "{_NSRange=QQ}@:");
  class_addMethod(cls, NSSelectorFromString(@"_accessibilitySelectedTextRange"),
                  (IMP)PixezSelectedTextRangeMethod, "{_NSRange=QQ}@:");
  class_addMethod(cls, @selector(copy:), (IMP)PixezCopy, "v@:@");
}

void PixezInstallSelectedTextAccessibility(void) {
  static BOOL installed = NO;
  if (installed) {
    return;
  }
  installed = YES;

  Class viewClass = NSClassFromString(@"FlutterView");
  PixezInstall(viewClass, @selector(isAccessibilityElement), (IMP)PixezIsAccessibilityElement, "B@:",
               &pixezOrigIsAccessibilityElement);
  PixezInstall(viewClass, @selector(accessibilityLabel), (IMP)PixezAccessibilityLabel, "@@:",
               &pixezOrigAccessibilityLabel);
  PixezInstall(viewClass, @selector(accessibilityValue), (IMP)PixezAccessibilityValue, "@@:",
               &pixezOrigAccessibilityValue);
  PixezAddSelectedText(viewClass);
  PixezAddSelectedText(NSClassFromString(@"SemanticsObject"));
  PixezAddSelectedText(NSClassFromString(@"FlutterViewController"));
}
