// Copyright 2008 Google Inc.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License.  You may obtain a copy
// of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations under
// the License.

#import "CGImageView.h"

@implementation CGImageView
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (BOOL)isViewCompletelyVisible {
  NSClipView *clip = (NSClipView *)[self superview];
  NSRect documentRect = [clip documentRect];
  NSRect documentVisibleRect = [clip documentVisibleRect];
  
  // If they're the same size, no panning
  return NSEqualSizes(documentRect.size, documentVisibleRect.size);
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
- (void)setImage:(CGImageRef)image {
  if (image != image_) {
    CGImageRelease(image_);
    image_ = CGImageRetain(image);
    [self setZoom:zoom_];
    [self setNeedsDisplay:YES];
  }
}

//------------------------------------------------------------------------------
- (CGImageRef)image {
  return image_;
}

//------------------------------------------------------------------------------
- (void)setZoom:(CGFloat)zoom {
  NSScrollView *scrollView = [self enclosingScrollView];
  NSRect bounds = [scrollView bounds];
  
  if (image_)
    bounds = NSMakeRect(0, 0, CGImageGetWidth(image_), CGImageGetHeight(image_));
  
  bounds.size.width *= zoom / 100.0;
  bounds.size.height *= zoom / 100.0;
  bounds = NSIntegralRect(bounds);
  
  [self setFrame:bounds];
  [self setBounds:bounds];
  
  zoom_ = zoom;
  [[NSUserDefaults standardUserDefaults] setFloat:zoom_ forKey:@"zoom"];
  [scrollView tile];
}

//------------------------------------------------------------------------------
- (CGFloat)zoom {
  return zoom_;
}

//------------------------------------------------------------------------------
- (NSRect)optimalFrame {
  return [self optimalFrameForZoom:zoom_];
}

//------------------------------------------------------------------------------
- (NSRect)optimalFrameForZoom:(CGFloat)zoom {
  NSRect frame = [self frame];
  
  if (image_) {
    NSRect imageRect = NSMakeRect(0, 0, CGImageGetWidth(image_), CGImageGetHeight(image_));
    imageRect.size.width *= zoom / 100.0;
    imageRect.size.height *= zoom / 100.0;
    frame = NSIntegralRect(imageRect);
  }
  
  return frame;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSView ||
//------------------------------------------------------------------------------
- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    zoom_ = [[NSUserDefaults standardUserDefaults] floatForKey:@"zoom"];
    
    if (zoom_ < 10)
      [self setZoom:25];
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  CGImageRelease(image_);
  [super dealloc];
}

//------------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect {
  NSRect bounds = [self bounds];

  if (!image_) {
    [[NSColor grayColor] set];
    NSRectFill(bounds);
    return;
  }
  
  CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
  CGContextDrawImage(context, NSRectToCGRect(bounds), image_);
}

//------------------------------------------------------------------------------
- (void)resetCursorRects {
  NSCursor *hand = isDown_ ? [NSCursor closedHandCursor] : [NSCursor openHandCursor];
  
  if (![self isViewCompletelyVisible])
    [self addCursorRect:[self visibleRect] cursor:hand];
}

//------------------------------------------------------------------------------
- (BOOL)isOpaque {
  return YES;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSResponder ||
//------------------------------------------------------------------------------
- (void)mouseDown:(NSEvent *)event {
  // No panning if we're completely visible
  if ([self isViewCompletelyVisible])
    return;
  
  NSClipView *clip = (NSClipView *)[self superview];
  initialPt_ = [self convertPoint:[event locationInWindow] toView:clip];
  initialOrigin_ = [clip bounds].origin;
  isDown_ = YES;
  [[self window] invalidateCursorRectsForView:self];
}

//------------------------------------------------------------------------------
- (void)mouseDragged:(NSEvent *)event {
  // No panning if we're completely visible
  if ([self isViewCompletelyVisible])
    return;

  NSClipView *clip = (NSClipView *)[self superview];
  NSPoint localPt = [self convertPoint:[event locationInWindow] toView:clip];
  NSPoint delta;
  delta.x = localPt.x - initialPt_.x;
  delta.y = localPt.y - initialPt_.y;

  NSPoint origin = initialOrigin_;
  origin.x -= delta.x;
  origin.y -= delta.y;
 
  [self scrollPoint:origin];
}

//------------------------------------------------------------------------------
- (void)mouseUp:(NSEvent *)event {
  isDown_ = NO;
  [[self window] invalidateCursorRectsForView:self];
}

@end
