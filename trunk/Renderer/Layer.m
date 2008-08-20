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

#import <QuartzCore/QuartzCore.h>

#import "Color.h"
#import "Exporter.h"
#import "Filter.h"
#import "Gradient.h"
#import "Image.h"
#import "Layer.h"
#import "PatternObject.h"
#import "PointObject.h"
#import "Randomizer.h"
#import "RectObject.h"
#import "Text.h"

@interface Layer(PrivateMethods)
- (void)releaseBackingStore;
- (BOOL)resizeBackingStore;
- (void)drawColoredRect:(NSArray *)arguments;
@end

@implementation Layer
+ (NSString *)className {
  return @"Layer";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"frame", @"bounds",
          @"fillStyle", @"strokeStyle", 
          @"globalCompositeOperation", @"blendMode",
          @"lineWidth", @"lineCap", @"lineJoin", 
          @"miterLimit",
          nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:
          // Canvas methods
          @"arc", @"arcTo",
          @"beginPath", @"bezierCurveTo",
          @"clearRect", @"clip", @"closePath",
          @"drawImage",
          @"fill", @"fillRect",
          @"lineTo", 
          @"moveTo",
          @"quadraticCurveTo",
          @"rect", @"restore", @"rotate",
          @"save", @"scale", @"stroke", @"strokeRect",
          @"translate",
          
          // Extended
          @"applyFilter", 
          @"circle", @"coloredRect", @"colorAtPoint",
          @"drawText",
          @"ellipse", 
          @"fillStroke", @"fillLayer",
          @"reflect", @"roundedRect", 
          @"shadow", 
          @"toString", 
          @"wavyLineTo", 
          nil];
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    RectObject *rectObj = [[RectObject alloc] initWithArguments:arguments];
    frame_ = NSIntegralRect([rectObj rect]);
    [rectObj release];

    if (![self resizeBackingStore] || NSIsEmptyRect(frame_)) {
      MethodLog("Unable to resize or use frame %@", NSStringFromRect(frame_));
      [self release];
      self = nil;
    }    
  }
  
  return self;
}

//------------------------------------------------------------------------------
+ (CGBlendMode)blendModeFromString:(NSString *)blendModeStr {
  static NSDictionary *sBlendMode = nil;
  
  @synchronized (sBlendMode) {
    if (!sBlendMode) {
      sBlendMode = [[NSDictionary dictionaryWithObjectsAndKeys:
                     [NSNumber numberWithInt:kCGBlendModeNormal], @"normal",
                     [NSNumber numberWithInt:kCGBlendModeMultiply], @"multiply",
                     [NSNumber numberWithInt:kCGBlendModeOverlay], @"overlay",
                     [NSNumber numberWithInt:kCGBlendModeDarken], @"darken",
                     [NSNumber numberWithInt:kCGBlendModeLighten], @"lighten",
                     [NSNumber numberWithInt:kCGBlendModeColorDodge], @"color-dodge",
                     [NSNumber numberWithInt:kCGBlendModeColorBurn], @"color-burn",
                     [NSNumber numberWithInt:kCGBlendModeSoftLight], @"soft-light",
                     [NSNumber numberWithInt:kCGBlendModeHardLight], @"hard-light",
                     [NSNumber numberWithInt:kCGBlendModeDifference], @"difference",
                     [NSNumber numberWithInt:kCGBlendModeExclusion], @"exclusion",
                     [NSNumber numberWithInt:kCGBlendModeHue], @"hue",
                     [NSNumber numberWithInt:kCGBlendModeSaturation], @"saturation",
                     [NSNumber numberWithInt:kCGBlendModeColor], @"color",
                     [NSNumber numberWithInt:kCGBlendModeLuminosity], @"luminosity",

                     [NSNumber numberWithInt:kCGBlendModeClear], @"clear",
                     [NSNumber numberWithInt:kCGBlendModeCopy], @"copy",
                     [NSNumber numberWithInt:kCGBlendModeSourceIn], @"source-in",
                     [NSNumber numberWithInt:kCGBlendModeSourceOut], @"source-out",
                     [NSNumber numberWithInt:kCGBlendModeSourceAtop], @"source-atop",
                     [NSNumber numberWithInt:kCGBlendModeDestinationOver], @"destination-over",
                     [NSNumber numberWithInt:kCGBlendModeDestinationIn], @"destination-in",
                     [NSNumber numberWithInt:kCGBlendModeDestinationOut], @"destination-out",
                     [NSNumber numberWithInt:kCGBlendModeDestinationAtop], @"destination-atop",
                     [NSNumber numberWithInt:kCGBlendModeXOR], @"xor",
                     [NSNumber numberWithInt:kCGBlendModePlusDarker], @"darker",
                     [NSNumber numberWithInt:kCGBlendModePlusLighter], @"lighter",
                     
                     nil] retain];                     
    }
  }
  
  return [[sBlendMode objectForKey:[blendModeStr lowercaseString]] intValue];
}

//------------------------------------------------------------------------------
+ (NSString *)blendModeToString:(CGBlendMode)blendMode {
  NSString *str = nil;
  
  switch (blendMode) {
    case kCGBlendModeNormal: str = @"normal";  break;
    case kCGBlendModeMultiply: str = @"multiply";  break;
    case kCGBlendModeScreen: str = @"screen";  break;
    case kCGBlendModeOverlay: str = @"overlay";  break;
    case kCGBlendModeDarken: str = @"darken";  break;
    case kCGBlendModeLighten: str = @"lighten";  break;
    case kCGBlendModeColorDodge: str = @"color-dodge";  break;
    case kCGBlendModeColorBurn: str = @"color-burn";  break;
    case kCGBlendModeSoftLight: str = @"soft-light";  break;
    case kCGBlendModeHardLight: str = @"hard-light";  break;
    case kCGBlendModeDifference: str = @"difference";  break;
    case kCGBlendModeExclusion: str = @"exclusion";  break;
    case kCGBlendModeHue: str = @"hue";  break;
    case kCGBlendModeSaturation: str = @"saturation";  break;
    case kCGBlendModeColor: str = @"color";  break;
    case kCGBlendModeLuminosity: str = @"luminosity";  break;
   
    case kCGBlendModeClear: str = @"clear";  break;
    case kCGBlendModeCopy: str = @"copy";  break;
    case kCGBlendModeSourceIn: str = @"source-in";  break;
    case kCGBlendModeSourceOut: str = @"source-out";  break;
    case kCGBlendModeSourceAtop: str = @"source-atop";  break;
    case kCGBlendModeDestinationOver: str = @"destination-over";  break;
    case kCGBlendModeDestinationIn: str = @"destination-in";  break;
    case kCGBlendModeDestinationOut: str = @"destination-out";  break;
    case kCGBlendModeDestinationAtop: str = @"destination-atop";  break;
    case kCGBlendModeXOR: str = @"xor";  break;
    case kCGBlendModePlusDarker: str = @"darker";  break;
    case kCGBlendModePlusLighter: str = @"lighter";  break;

    default:
      str = @"unknown-blend-mode";
  }
  
  return str;
}

- (id)initWithFrame:(NSRect)frame {
  if ((self = [super init])) {
    frame_ = NSIntegralRect(frame);
    
    if (![self resizeBackingStore] || NSIsEmptyRect(frame_)) {
      MethodLog("Unable to resize or use frame %@", NSStringFromRect(frame_));
      [self release];
      self = nil;
    }
  }
  
  return self;
}

- (void)releaseBackingStore {
  CGContextRelease(backingStore_);
  backingStore_ = NULL;
  CGImageRelease(image_);
  image_ = NULL;  
  [fillGradient_ release];
  fillGradient_ = nil;
}

- (void)dealloc {
  [self releaseBackingStore];
  [super dealloc];
}

- (CGRect)cgRectFrame {
  return NSRectToCGRect(frame_);
}

- (RectObject *)frame {
  return [[(RectObject *)[RectObject alloc] initWithRect:frame_] autorelease];
}

- (RectObject *)bounds {
  return [[(RectObject *)[RectObject alloc] initWithRect:NSMakeRect(0, 0, NSWidth(frame_), NSHeight(frame_))] autorelease];
}

- (void)setFrame:(NSArray *)arguments {
  RectObject *frame = [[RectObject alloc] initWithArguments:arguments];
  frame_ = [frame rect];
  [frame release];
  [self releaseBackingStore];
  [self resizeBackingStore];
}

- (CGImageRef)cgImage {
  if (!image_)
    image_ = CGBitmapContextCreateImage(backingStore_);
  
  return image_;
}

- (CGContextRef)backingStore {
  return backingStore_;
}

- (BOOL)resizeBackingStore {
  CGContextRelease(backingStore_);
  CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGBitmapInfo info = kCGImageAlphaPremultipliedFirst;
  backingStore_ = CGBitmapContextCreate(NULL, NSWidth(frame_), NSHeight(frame_), 8, 0, cs, info);
  CGColorSpaceRelease(cs);
  
  return backingStore_ ? YES : NO;
}

- (void)setFillStyle:(id)obj {
  [fillGradient_ release];
  fillGradient_ = nil;

  // Color, Pattern, or Gradient
  Color *color = [RuntimeObject coerceObject:obj toClass:[Color class]];
  if (color) {
    CGFloat c[4];
    [color getComponents:c];
    CGContextSetRGBFillColor(backingStore_, c[0], c[1], c[2], c[3]);
    return;
  }
  
  PatternObject *pattern = [RuntimeObject coerceObject:obj toClass:[PatternObject class]];
  if (pattern) {
    CGFloat c[4] = { 1, 1, 1, 1 };
    // The fill for the pattern should be transparent
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(backingStore_, patternSpace);
    CGContextSetFillPattern(backingStore_, [pattern cgPattern], c);
    CGColorSpaceRelease(patternSpace);
  }
  
  Gradient *gradient = [RuntimeObject coerceObject:obj toClass:[Gradient class]];
  if (gradient) {
    // TODO: This should probably copy so that subsequent changes to the gradient
    // object will not be changed in the layer.
    fillGradient_ = [gradient retain];
  }
}

- (void)setStrokeStyle:(id)obj {
  // Color or Pattern
  Color *color = [RuntimeObject coerceObject:obj toClass:[Color class]];
  
  CGFloat c[4];  
  [color getComponents:c];
  CGContextSetRGBStrokeColor(backingStore_, c[0], c[1], c[2], c[3]);  
}

- (void)setLineWidth:(float)width {
  CGContextSetLineWidth(backingStore_, width);
}

- (void)setLineCap:(NSString *)str {
  str = [str lowercaseString];
  CGLineCap cap = kCGLineCapButt;
  
  if ([str isEqualToString:@"round"])
    cap = kCGLineCapRound;
  else if ([str isEqualToString:@"square"])
    cap = kCGLineCapSquare;

  CGContextSetLineCap(backingStore_, cap);
}

- (void)setLineJoin:(NSString *)str {
  str = [str lowercaseString];
  CGLineJoin join = kCGLineJoinMiter;
  
  if ([str isEqualToString:@"round"])
    join = kCGLineJoinRound;
  else if ([str isEqualToString:@"bevel"])
    join = kCGLineJoinBevel;

  CGContextSetLineJoin(backingStore_, join);
}

- (void)setMiterLimit:(CGFloat)limit {
  CGContextSetMiterLimit(backingStore_, limit);
}

- (void)setBlendMode:(NSString *)str {
  CGBlendMode mode = [Layer blendModeFromString:str];
  CGContextSetBlendMode(backingStore_, mode);
}
  
- (void)setGlobalCompositeOperation:(NSString *)str {
  [self setBlendMode:str];
}

- (CGFloat)lineWidth {
  // TODO: There should be a way to return the current line width
  return 1;
}

- (void)save {
  CGContextSaveGState(backingStore_);
}

- (void)restore {
  CGContextRestoreGState(backingStore_);
}

// Commands
- (void)beginPath {
  CGContextBeginPath(backingStore_);
}

- (void)clip {
  CGContextClip(backingStore_);
}

- (void)closePath {
  CGContextClosePath(backingStore_);
}

- (void)lineTo:(NSArray *)arguments {
  PointObject *ptObject = [[PointObject alloc] initWithArguments:arguments];
  NSPoint point = [ptObject point];
  [ptObject release];
  CGContextAddLineToPoint(backingStore_, point.x, point.y);
}

- (void)moveTo:(NSArray *)arguments {
  PointObject *ptObject = [[PointObject alloc] initWithArguments:arguments];
  NSPoint point = [ptObject point];
  [ptObject release];
  CGContextMoveToPoint(backingStore_, point.x, point.y);
}

- (void)bezierCurveTo:(NSArray *)arguments {
  // args: control pt1, controlPt2, end pt
  if ([arguments count] == 3) {
    PointObject *control1 = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PointObject class]];
    PointObject *control2 = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[PointObject class]];
    PointObject *end = [RuntimeObject coerceObject:[arguments objectAtIndex:2] toClass:[PointObject class]];
    
    CGContextAddCurveToPoint(backingStore_, [control1 x], [control1 y], [control2 x], [control2 y], [end x], [end y]);
  }
}

- (void)quadraticCurveTo:(NSArray *)arguments {
  // args: control pt, end pt
  if ([arguments count] == 2) {
    PointObject *control = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PointObject class]];
    PointObject *end = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[PointObject class]];
    
    CGContextAddQuadCurveToPoint(backingStore_, [control x], [control y], [end x], [end y]);
  }  
}

// Positive displacement will be in the clockwise direction, negative counter-clockwise.
// reference is a point on the line made by start and end
- (CGPoint)unitPerpendicularToStart:(CGPoint)start end:(CGPoint)end 
                          reference:(CGPoint)reference {
  CGPoint perp;
  
  // The displacement needs to be negated depending on the quadrant where the
  // offset will be present
  CGFloat scaledDisplacement = 1;
  
  if (start.x == end.x) {
    // Vertical line
    if (start.y > end.y)
      scaledDisplacement *= -1;
    
    perp.x = scaledDisplacement;
    perp.y = 0;
  } else if (start.y == end.y) {
    // Horizontal Line
    if (end.x > start.x)
      scaledDisplacement *= -1;
    
    perp.x = 0;
    perp.y = scaledDisplacement;
  } else {
    // Sloped line
    CGFloat xLen = end.x - start.x;
    CGFloat yLen = end.y - start.y;
    CGFloat slope = yLen / xLen;
    CGFloat perpSlope = -(1.0 / slope);
    CGFloat perpIntercept = (reference.y - perpSlope * reference.x);
    
    // If the slope is small, create the x and calculate the y as it's
    // more accurate to not divide by a small number.
    if (fabs(perpSlope) < 1) {
      // More Horizontal
      if (start.y > end.y)
        scaledDisplacement *= -1;
      
      perp.x = reference.x + scaledDisplacement;
      perp.y = perpSlope * perp.x + perpIntercept;
    } else {
      // More vertical
      scaledDisplacement *= -1;
      
      if (end.x < start.x)
        scaledDisplacement *= -1;
      
      perp.y = reference.y + scaledDisplacement;
      perp.x = (perp.y - perpIntercept) / perpSlope;
    }
    
    // Normalize to the correct length
    xLen = perp.x - reference.x;
    yLen = perp.y - reference.y;
    CGFloat len = sqrt(xLen * xLen + yLen * yLen);
    perp.x = (xLen / len) * fabs(scaledDisplacement);
    perp.y = (yLen / len) * fabs(scaledDisplacement);
  }
  
  return perp;
}

- (CGPoint)referencePointOnStart:(CGPoint)start end:(CGPoint)end step:(CGFloat)step {
  CGFloat xLen = end.x - start.x;
  CGFloat yLen = end.y - start.y;
  return CGPointMake(start.x + xLen * step, start.y + yLen * step);
}

- (CGPoint)segmentPointAtStep:(CGFloat)step {
  CGFloat size = 1.0 / (CGFloat)segmentCount_;
  int idx = (int)floor(step / size);
  CGFloat stepForIdx = (step - (CGFloat)idx * size) / size;
  
  return [self referencePointOnStart:segments_[idx] end:segments_[idx + 1] step:stepForIdx];
}

// From cocoadev:
// http://www.cocoadev.com/index.pl?DrawingArbitaryCurvesFromPoints
//
- (void)addWavyBezier:(CGContextRef)context smoothness:(int)smoothness {
  if (smoothness < 1)
    smoothness = 1;
  
	int curveCount = segmentCount_ / smoothness/* the number of times to partition the function */;
	float start = 0/* starting point of the interval */;
  float end = 1/* end point of the interval */;
  
  if (curveCount < 1)
    curveCount = 1;
	
	float t;
	CGPoint q0, q1, q2, q3, p1, p2;
	float size = (end - start) / curveCount;
  
	for(int i = 0; i < curveCount; i++) {
		t = start + i * size;
    
		q0 = [self segmentPointAtStep:t];
    q1 = [self segmentPointAtStep:t + size / 3.0];
    q2 = [self segmentPointAtStep:t + 2.0 * size / 3.0];
    q3 = [self segmentPointAtStep:t + size];
		
		p1.x = (-5 * q0.x + 18 * q1.x - 9 * q2.x + 2 * q3.x) / 6;
		p1.y = (-5 * q0.y + 18 * q1.y - 9 * q2.y + 2 * q3.y) / 6;
		p2.x = (2 * q0.x - 9 * q1.x + 18 * q2.x - 5 * q3.x) / 6;
		p2.y = (2 * q0.y - 9 * q1.y + 18 * q2.y - 5 * q3.y) / 6;
		
    CGContextAddCurveToPoint(context, p1.x, p1.y, p2.x, p2.y, q3.x, q3.y);
	}
}

- (void)wavyLineTo:(NSArray *)arguments {
  // args: end point, segments to "wave", smoothness, displacement randomizer 
  if ([arguments count] == 4) {
    PointObject *end = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PointObject class]];
    CGFloat steps = floor([RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]]);
    CGFloat smoothness = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];
    Randomizer *displacementRnd = [RuntimeObject coerceObject:[arguments objectAtIndex:3] toClass:[Randomizer class]];
    
    CGPoint startPt = CGContextGetPathCurrentPoint(backingStore_);
    CGPoint endPt = NSPointToCGPoint([end point]);
    
    // Create our segments
    segmentCount_ = (int)steps;
    segments_ = (CGPoint *)malloc(sizeof(CGPoint) * (segmentCount_ + 1));
    
    segments_[0] = startPt;
    segments_[segmentCount_] = endPt;

    CGFloat stepInc = 1.0 / segmentCount_;
    CGFloat step = stepInc;
    CGFloat displacement;
    
    // Initialize the reference point on the original line and the
    // displaced point perpendicular to the reference point and offset by some
    // fraction of displacement_
    for (int i = 1; i < segmentCount_; ++i, step += stepInc) {
      displacement = [displacementRnd floatValue];
      CGPoint reference = [self referencePointOnStart:startPt end:endPt step:step];
      CGPoint perp = [self unitPerpendicularToStart:startPt end:endPt reference:reference];
      segments_[i] = CGPointMake(reference.x + perp.x * displacement,
                                 reference.y + perp.y * displacement);
    }
    
    [self addWavyBezier:backingStore_ smoothness:(int)(smoothness * steps)];
    
    
    // Cleanup
    free(segments_);
    segments_ = nil;
    segmentCount_ = 0;
    
  } else {
    MethodLog("Expecting: end point, steps, randomizer, smoothness");
  }
}

- (void)arc:(NSArray *)arguments {
  // args: center, radius, startAngle, endAngle, clockwise
  if ([arguments count] == 5) {
    PointObject *center = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PointObject class]];
    CGFloat radius = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    CGFloat start = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];
    CGFloat end = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:3]];
    CGFloat clockwise = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:4]];
    
    CGContextAddArc(backingStore_, [center x], [center y], radius, start, end, clockwise);
  }
}

- (void)arcTo:(NSArray *)arguments {
  // args: p1, p2, radius
  if ([arguments count] >= 3) {
    PointObject *p1 = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PointObject class]];
    PointObject *p2 = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[PointObject class]];
    CGFloat radius = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];
    CGContextAddArcToPoint(backingStore_, [p1 x], [p1 y], [p2 x], [p2 y], radius);
  }
}

- (void)clearRect:(NSArray *)arguments {
  RectObject *rectObject = [[RectObject alloc] initWithArguments:arguments];
  CGContextClearRect(backingStore_, NSRectToCGRect([rectObject rect]));
  [rectObject release];
}

- (void)rect:(NSArray *)arguments {
  RectObject *rectObject = [[RectObject alloc] initWithArguments:arguments];
  CGContextAddRect(backingStore_, NSRectToCGRect([rectObject rect]));
  [rectObject release];
}

- (void)roundedRect:(NSArray *)arguments {
  int count = [arguments count];
  NSRange range = NSMakeRange(0, count ? count - 1 : 0);
  NSArray *rectArgs = [arguments subarrayWithRange:range];
  RectObject *rectObject = [[RectObject alloc] initWithArguments:rectArgs];
  NSRect rect = [rectObject rect];
  float radius = 1;
  int radiusIdx = (count == 2) ? 1 : (count >= 4) ? 4 : -1;
  float minDim = MIN(NSWidth(rect), NSHeight(rect));
  
  if (radiusIdx > 0)
    radius = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:radiusIdx]];

  // Ensure that the radius is "reasonable"
  if (radius > minDim / 2.0)
    radius = minDim / 2.0;
  
  // Counter clockwise from bottom right radius
  float quarterRadians = M_PI / 2.0;
  CGContextMoveToPoint(backingStore_, NSMaxX(rect) - radius, NSMinY(rect));
  CGContextAddArc(backingStore_, NSMaxX(rect) - radius, NSMinY(rect) + radius, radius, -quarterRadians, 0, 0);
  CGContextAddLineToPoint(backingStore_, NSMaxX(rect), NSMaxY(rect) - radius);
  CGContextAddArc(backingStore_, NSMaxX(rect) - radius, NSMaxY(rect) - radius, radius, 0, quarterRadians, 0);
  CGContextAddLineToPoint(backingStore_, NSMinX(rect) + radius, NSMaxY(rect));
  CGContextAddArc(backingStore_, NSMinX(rect) + radius, NSMaxY(rect) - radius, radius, quarterRadians, quarterRadians * 2, 0);
  CGContextAddLineToPoint(backingStore_, NSMinX(rect), NSMinY(rect) + radius);
  CGContextAddArc(backingStore_, NSMinX(rect) + radius, NSMinY(rect) + radius, radius, quarterRadians * 2, -quarterRadians, 0);
  CGContextAddLineToPoint(backingStore_, NSMaxX(rect) - radius, NSMinY(rect));
  
  [rectObject release];
}

- (void)ellipse:(NSArray *)arguments {
  RectObject *rectObject = [[RectObject alloc] initWithArguments:arguments];
  CGContextAddEllipseInRect(backingStore_, NSRectToCGRect([rectObject rect]));
  [rectObject release];
}

- (void)circle:(NSArray *)arguments {
  // args: point, radius
  PointObject *pt = nil;
  CGFloat radius = 0;
  
  if ([arguments count] == 2) {
    pt = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PointObject class]];
    radius = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
  } else if ([arguments count] == 3) {
    CGFloat x = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
    CGFloat y = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    pt = [[[PointObject alloc] initWithPoint:NSMakePoint(x, y)] autorelease];
    radius = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];
  }
  
  if (pt)
    CGContextAddArc(backingStore_, [pt x], [pt y], radius, 0, M_PI * 2, 1);
}

- (void)coloredRect:(NSArray *)arguments {
  // args: rect, bl, tl, tr, br colors
  if ([arguments count] == 5) {
    RectObject *rect = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[RectObject class]];
    Color *bl = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[Color class]];
    Color *tl = [RuntimeObject coerceObject:[arguments objectAtIndex:2] toClass:[Color class]];
    Color *tr = [RuntimeObject coerceObject:[arguments objectAtIndex:3] toClass:[Color class]];
    Color *br = [RuntimeObject coerceObject:[arguments objectAtIndex:4] toClass:[Color class]];
    NSString *program =
    @"kernel vec4 coloredRect(__color topLeft, __color topRight, __color bottomLeft, __color bottomRight, vec2 size)"
    "{ vec2 t = destCoord() / size;"
    "vec4 leftCol = topLeft * t.y + bottomLeft * (1.0 - t.y);"
    "vec4 rightCol = topRight * t.y + bottomRight * (1.0 - t.y);"
    "return clamp(rightCol * t.x + leftCol * (1.0 - t.x), 0.0, 1.0); }";
    NSArray *kernels = [CIKernel kernelsWithString:program];
    CIKernel *coloredKernel = [kernels objectAtIndex:0];
    CIFilter *crop = [CIFilter filterWithName:@"CICrop" keysAndValues:
                      @"inputRectangle", [CIVector vectorWithX:0 Y:0 Z:[rect width] W:[rect height]], nil];
    CIColor *topLeft = [[[CIColor alloc] initWithColor:[tl color]] autorelease];
    CIColor *topRight = [[[CIColor alloc] initWithColor:[tr color]] autorelease]; 
    CIColor *bottomLeft = [[[CIColor alloc] initWithColor:[bl color]] autorelease]; 
    CIColor *bottomRight = [[[CIColor alloc] initWithColor:[br color]] autorelease]; 
    CIVector *size = [CIVector vectorWithX:[rect width] Y:[rect height]];
    CIImage *result = [crop apply:coloredKernel, topLeft, topRight, bottomLeft, bottomRight, size, nil];
    
    // Add some noise into the image to reduce banding
#if 0
    CIFilter *f = [CIFilter filterWithName:@"CIRandomGenerator"];
    CIFilter *blend = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [blend setValue:[f valueForKey:@"outputImage"] forKey:@"inputBackgroundImage"];
    [blend setValue:result forKey:@"inputImage"];
    [crop setValue:[blend valueForKey:@"outputImage"] forKey:@"inputImage"];
    result = [crop valueForKey:@"outputImage"];
#endif
    
    CIContext *context = [CIContext contextWithCGContext:backingStore_ options:nil];
    [context drawImage:result atPoint:CGPointMake([rect x], [rect y]) fromRect:CGRectMake(0, 0, [rect width], [rect height])];
  }
}

- (void)stroke {
  CGContextDrawPath(backingStore_, kCGPathStroke);
}

- (void)fill {
  if (fillGradient_) {
    CGPoint start = NSPointToCGPoint([[fillGradient_ start] point]);
    CGPoint end = NSPointToCGPoint([[fillGradient_ end] point]);
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation |
      kCGGradientDrawsAfterEndLocation;
    
    // Save the clip
    CGContextSaveGState(backingStore_);
    CGContextClip(backingStore_);
    
    if (![fillGradient_ isRadial]) {
      CGContextDrawLinearGradient(backingStore_, [fillGradient_ cgGradient], 
                                  start, end, options);
    } else {
      CGPoint radius = NSPointToCGPoint([[fillGradient_ radius] point]);
      CGContextDrawRadialGradient(backingStore_, [fillGradient_ cgGradient], 
                                  start, radius.x, end, radius.y, options);
    }
    CGContextRestoreGState(backingStore_);
  } else {
    CGContextDrawPath(backingStore_, kCGPathFill);
  }
}

- (void)fillRect:(NSArray *)arguments {
  if ([arguments count]) {
    RectObject *rect = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[RectObject class]];
    CGContextFillRect(backingStore_, NSRectToCGRect([rect rect]));
  }
}

- (void)strokeRect:(NSArray *)arguments {
  if ([arguments count]) {
    RectObject *rect = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[RectObject class]];
    CGContextStrokeRect(backingStore_, NSRectToCGRect([rect rect]));
  }
}

- (void)fillStroke {
  // TODO: Use a separate CGPath so that we can properly draw gradients and
  // patterns in the path as well as stroke it.
  CGContextDrawPath(backingStore_, kCGPathFillStroke);
}

- (void)shadow:(NSArray *)arguments {
  // arguments: offset, size, color
  int count = [arguments count];
  CGSize size = CGSizeZero;
  CGFloat blur = 0;
  CGColorRef colorRef = NULL;
  
  if (count == 3) {
    PointObject *pt = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PointObject class]];
    blur = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    Color *color = [RuntimeObject coerceObject:[arguments objectAtIndex:2] toClass:[Color class]];
    size.width = [pt x];
    size.height = [pt y];
    colorRef = [color createCGColor];
  }
  
  CGContextSetShadowWithColor(backingStore_, size, blur, colorRef);
  CGColorRelease(colorRef);
}

- (void)drawImage:(NSArray *)arguments {
  // args:  image, Point (dest)
  //        image, Rect (dest)
  //        image, Rect (src), Rect (dest)
  int count = [arguments count];
  
  if (count < 2)
    return;

  Image *image = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Image class]];
  if (!image)
    return;

  CGRect dest = CGRectMake(0, 0, [image width], [image height]);
  CGImageRef imageRef = [image cgImage];
  CGImageRef srcImageRef = NULL;
  
  PointObject *destPt = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[PointObject class]];
  if (destPt) {
    dest.origin = NSPointToCGPoint([destPt point]);
  } else {
    RectObject *destRect = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[RectObject class]]; 
    dest = NSRectToCGRect([destRect rect]);
  }

  if (count >= 3) {
    // Use the previously read dest
    RectObject *destRect = [RuntimeObject coerceObject:[arguments objectAtIndex:2] toClass:[RectObject class]];
    srcImageRef = CGImageCreateWithImageInRect(imageRef, dest);
    imageRef = srcImageRef;
    dest = NSRectToCGRect([destRect rect]);
  }
    
  CGContextSaveGState(backingStore_);
  CGContextSetBlendMode(backingStore_, [image cgBlendMode]);
  CGContextSetAlpha(backingStore_, [image alpha]);
  CGContextDrawImage(backingStore_, dest, imageRef);
  CGContextRestoreGState(backingStore_);
  
  if (srcImageRef)
    CGImageRelease(srcImageRef);
}

- (void)drawText:(NSArray *)arguments {
  // arguments: Text, Rect | Point
  if ([arguments count] == 2) {
    Text *text = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Text class]];
    NSRect srcRect = NSZeroRect;
    RectObject *srcRectObj = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[RectObject class]];
    if (srcRectObj) {
      srcRect = [srcRectObj rect];
    } else {
      PointObject *destPt = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[PointObject class]];
      
      if (!destPt)
        return;
      
      srcRect.origin = [destPt point];
    }
    
    CGContextSaveGState(backingStore_);
    NSGraphicsContext *original = [NSGraphicsContext currentContext];
    NSGraphicsContext *backing = [NSGraphicsContext graphicsContextWithGraphicsPort:backingStore_ flipped:NO];
    [NSGraphicsContext setCurrentContext:backing];
    NSAttributedString *str = [[NSAttributedString alloc] initWithString:[text string] attributes:[text attributes]];
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingDisableScreenFontSubstitution;

    if (NSWidth(srcRect) == 0)
      srcRect.size = [str size];
    
    [str drawWithRect:srcRect options:options];
    [str release];

    [NSGraphicsContext setCurrentContext:original];
    CGContextRestoreGState(backingStore_);
  }
}

- (void)rotate:(NSArray *)arguments {
  if ([arguments count]) {
    CGFloat angle = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
    CGContextRotateCTM(backingStore_, angle);
  }
}

- (void)scale:(NSArray *)arguments {
  PointObject *pt = [[PointObject alloc] initWithArguments:arguments];
  CGContextScaleCTM(backingStore_, [pt x], [pt y]);
  [pt release];
}

- (void)translate:(NSArray *)arguments {
  PointObject *pt = [[PointObject alloc] initWithArguments:arguments];
  CGContextTranslateCTM(backingStore_, [pt x], [pt y]);
  [pt release];
}

- (void)applyFilter:(NSArray *)arguments {
  if ([arguments count] == 1) {
    Filter *filter = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Filter class]];
    CIFilter *ciFilter = [filter ciFilter];
    
    if (!ciFilter)
      return;
    
    // Find the first filter
    Filter *firstFilter = filter;
    CGRect bounds = CGRectMake(0, 0, NSWidth(frame_), NSHeight(frame_));
    CIVector *cropBounds = [CIVector vectorWithX:CGRectGetMinX(bounds)
                                               Y:CGRectGetMinY(bounds)
                                               Z:CGRectGetMaxX(bounds)
                                               W:CGRectGetMaxY(bounds)];
    // Keep track of any filters that need chaining
    NSMutableArray *filtersToChain = [NSMutableArray array];
    
    do {
      Filter *inputFilter = [firstFilter inputFilter];

      if (!inputFilter)
        break;
      
      // There's an input filter - save this one for chaining
      [filtersToChain insertObject:firstFilter atIndex:0];
      
      firstFilter = [firstFilter inputFilter];
    } while (1);
    
    // Create an image of our background
    CGImageRef current = CGBitmapContextCreateImage(backingStore_);
    CIImage *input = [CIImage imageWithCGImage:current];

    // If this is a generator, it may not respond to this message
    @try {
      [[firstFilter ciFilter] setValue:input forKey:@"inputImage"];
    }
    
    @catch (NSException *e) {
      // We don't care if there was an exception in setting the input image
      // because we'll assume that it was a generator
    }
    
    // Chain the other filters, if any
    NSEnumerator *e = [filtersToChain objectEnumerator];
    Filter *previousFilter = firstFilter;
    while ((filter = [e nextObject])) {
      @try {
        CIImage *input = [[previousFilter ciFilter] valueForKey:@"outputImage"];
        [[filter ciFilter] setValue:input forKey:@"inputImage"];
      }
      
      @catch (NSException *e) {
        NSLog(@"Filter Chaining: %@", e);
        // Something
      }
      
      previousFilter = filter;
    }

    // Always crop the output
    CIFilter *crop = [CIFilter filterWithName:@"CICrop"];
    [crop setValue:cropBounds forKey:@"inputRectangle"];
    [crop setValue:[ciFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
    CIImage *output = [crop valueForKey:@"outputImage"];
    CGImageRelease(current);
    
    CIContext *context = [CIContext contextWithCGContext:backingStore_ options:nil];
    [context drawImage:output atPoint:CGPointZero fromRect:bounds];
  }
}

- (void)fillLayer:(NSArray *)arguments {
  if ([arguments count] == 1) {
    // args: color, pattern, gradient
    Gradient *gradient = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Gradient class]];
    CGRect bounds = [self cgRectFrame];
    bounds.origin.x = bounds.origin.y = 0;

    CGContextSaveGState(backingStore_);

    // Centered gradient
    if (gradient) {
      CGPoint start = NSPointToCGPoint([[gradient start] point]);
      CGPoint end = NSPointToCGPoint([[gradient end] point]);
      CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
      CGGradientRef gradientRef = [gradient cgGradient];
      
      if ([gradient isRadial]) {
        CGPoint radius = NSPointToCGPoint([[gradient radius] point]);

        if (start.x == end.x && start.y == end.y)
          start = end = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));

        CGContextDrawRadialGradient(backingStore_, gradientRef, start, radius.x, end, radius.y, options);
      } else {
        if (start.x == end.x && start.y == end.y) {
          start = CGPointMake(CGRectGetMinX(bounds), CGRectGetMidY(bounds)); 
          end = CGPointMake(CGRectGetMaxX(bounds), CGRectGetMidY(bounds));
        }

        CGContextDrawLinearGradient(backingStore_, gradientRef, start, end, options);
      }
    }
    
    // Pattern
    PatternObject *pattern = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[PatternObject class]];
    if (pattern) {
      CGFloat c[4] = { 1, 1, 1, 1 };
      // The fill for the pattern should be transparent
      CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
      CGContextSetFillColorSpace(backingStore_, patternSpace);
      CGContextSetFillPattern(backingStore_, [pattern cgPattern], c);
      CGColorSpaceRelease(patternSpace);
      CGContextFillRect(backingStore_, bounds);
    }

    // Solid color
    Color *color = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Color class]];
    if (color) {
      CGFloat c[4];
      [color getComponents:c];
      CGContextSetRGBFillColor(backingStore_, c[0], c[1], c[2], c[3]);
      CGContextFillRect(backingStore_, bounds);
    }
    CGContextRestoreGState(backingStore_);
  } else if ([arguments count] == 4) {
    // args: 4 colors
    NSMutableArray *newArguments = [NSMutableArray arrayWithArray:arguments];
    [newArguments insertObject:[self bounds] atIndex:0];
    [self drawColoredRect:newArguments];
  }
}

- (void)reflect:(NSArray *)arguments {
  if ([arguments count] >= 1) {
    NSString *mode = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
    CGFloat alpha = 1.0;
    CGImageRef baseImage = CGBitmapContextCreateImage(backingStore_);
    CGImageRef srcImage;
    CGRect bounds = [self cgRectFrame];
    bounds.origin.x = bounds.origin.y = 0;
    CGRect srcRect;

    CGContextSaveGState(backingStore_);
    
    if ([arguments count] == 2)
       alpha = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    
    if ([mode isEqualToString:@"top"]) {
      srcRect = bounds;
      srcRect.size.height /= 2.0;
      
      // Sub-image coords start with (0, 0) in upper left...
      srcImage = CGImageCreateWithImageInRect(baseImage, srcRect);
      
      // Flip bottom over top
      CGContextTranslateCTM(backingStore_, 0, CGRectGetHeight(srcRect));
      CGContextScaleCTM(backingStore_, 1, -1);
      CGContextSetAlpha(backingStore_, alpha);
      CGContextClearRect(backingStore_, srcRect);
      CGContextDrawImage(backingStore_, srcRect, srcImage);
    } else if ([mode isEqualToString:@"left"]) {
      srcRect = bounds;
      srcRect.size.width /= 2.0;
      
      // Sub-image coords start with (0, 0) in upper left...
      srcImage = CGImageCreateWithImageInRect(baseImage, srcRect);
      
      // Flip left over right
      CGContextTranslateCTM(backingStore_, 2 * CGRectGetWidth(srcRect), 0);
      CGContextScaleCTM(backingStore_, -1, 1);
      CGContextSetAlpha(backingStore_, alpha);
      CGContextClearRect(backingStore_, srcRect);
      CGContextDrawImage(backingStore_, srcRect, srcImage);
    } else if ([mode isEqualToString:@"quarter"]) {
      srcRect = bounds;
      srcRect.size.width /= 2.0;
      srcRect.size.height /= 2.0;

      // Sub-image coords start with (0, 0) in upper left...
      srcImage = CGImageCreateWithImageInRect(baseImage, srcRect);
      
      // Flip left over right
      CGContextSaveGState(backingStore_);
      CGContextTranslateCTM(backingStore_, 2 * CGRectGetWidth(srcRect), CGRectGetHeight(srcRect));
      CGContextScaleCTM(backingStore_, -1, 1);
      CGContextClearRect(backingStore_, srcRect);
      CGContextSetAlpha(backingStore_, alpha);
      CGContextDrawImage(backingStore_, srcRect, srcImage);
      CGContextRestoreGState(backingStore_);
      
      // Flip down and right
      CGContextSaveGState(backingStore_);
      CGContextTranslateCTM(backingStore_, 2 * CGRectGetWidth(srcRect), CGRectGetHeight(srcRect));
      CGContextScaleCTM(backingStore_, -1, -1);
      CGContextClearRect(backingStore_, srcRect);
      CGContextSetAlpha(backingStore_, alpha);
      CGContextDrawImage(backingStore_, srcRect, srcImage);
      CGContextRestoreGState(backingStore_);
      
      // Flip down
      CGContextSaveGState(backingStore_);
      CGContextTranslateCTM(backingStore_, 0, CGRectGetHeight(srcRect));
      CGContextScaleCTM(backingStore_, 1, -1);
      CGContextClearRect(backingStore_, srcRect);
      CGContextSetAlpha(backingStore_, alpha);
      CGContextDrawImage(backingStore_, srcRect, srcImage);
      CGContextRestoreGState(backingStore_);
    }
    
    CGContextRestoreGState(backingStore_);
    CGImageRelease(baseImage);
    CGImageRelease(srcImage);
  }
}

- (Color *)colorAtPoint:(NSArray *)arguments {
  PointObject *ptObj = [[PointObject alloc] initWithArguments:arguments];
  NSPoint pt = [ptObj point];
  [ptObj release];
  
  if (NSPointInRect(pt, frame_)) {
    // Create a 1x1 image at that point
    unsigned long pixel = 0;
    unsigned int width = 1;
    unsigned int height = 1;
    CGContextRef temp = CGBitmapContextCreate(&pixel, width, height, 
                                              CGBitmapContextGetBitsPerComponent(backingStore_),
                                              4,
                                              CGBitmapContextGetColorSpace(backingStore_), 
                                              kCGImageAlphaPremultipliedLast);
    CGImageRef current = CGBitmapContextCreateImage(backingStore_);
    // The bits are flipped from the actual image
    CGImageRef subImage = CGImageCreateWithImageInRect(current, CGRectMake(floor(pt.x), NSHeight(frame_) - floor(pt.y), 1, 1));
    CGContextDrawImage(temp, CGRectMake(0, 0, 1, 1), subImage);
    CGImageRelease(subImage);
    CGImageRelease(current);
    CGContextRelease(temp);
    
    // The pixel is ABGR -- this might not be right on PPC...
    NSNumber *a = [NSNumber numberWithFloat:(float)((pixel >> 24) & 0xFF) / 255.0];
    NSNumber *b = [NSNumber numberWithFloat:(float)((pixel >> 16) & 0xFF) / 255.0];
    NSNumber *g = [NSNumber numberWithFloat:(float)((pixel >> 8) & 0xFF) / 255.0];
    NSNumber *r = [NSNumber numberWithFloat:(float)((pixel >> 0) & 0xFF) / 255.0];
    NSArray *colorArguments = [NSArray arrayWithObjects:r, g, b, a, nil];
    
    return [[[Color alloc] initWithArguments:colorArguments] autorelease];
  }
  
  return nil;
}
                    
- (NSString *)toString {
  return [self description];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"Layer: %@", 
          NSStringFromRect(frame_)];
}

@end
