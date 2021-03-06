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

#import "ColorizingTextView.h"
#import "Controller.h"
#import "DocumentController.h"
#import "DrawingDocument.h"
#import "Exporter.h"
#import "Installer.h"
#import "Logging.h"
#import "Renderer.h"

NSString *DrawingDocumentNewImageNotification = @"DrawingDocumentNewImageNotification";

static NSString *kIdleMsg = @"Idle";
static NSTimeInterval kSucessfulRenderDuration = 5.0;
static NSString *kRenderFormat = @"tiff";

@implementation DrawingDocument
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)setStatus:(NSString *)msg {
  [status_ setStringValue:msg];
}

//------------------------------------------------------------------------------
- (void)setStatus:(NSString *)msg duration:(NSTimeInterval)duration {
  [self setStatus:msg];
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setStatus:) object:kIdleMsg];
  [self performSelector:@selector(setStatus:) withObject:kIdleMsg afterDelay:duration];
}

//------------------------------------------------------------------------------
- (void)startProgress {
  NSRect progressRect = [progress_ frame];
  NSRect statusRect = [status_ frame];
  
  statusRect.size.width -= NSMaxX(progressRect);
  statusRect.origin.x += NSMaxX(progressRect);
  [status_ setFrame:statusRect];
  [progress_ startAnimation:self];
}

//------------------------------------------------------------------------------
- (void)updateProgress {
  NSString *statusMsg = nil;
  
  if ([renderer_ isRendering]) {
    statusMsg = [NSString stringWithFormat:@"Rendering... (%.1f s)",
                 [renderer_ elapsedTime]];
    [status_ setStringValue:statusMsg];
  } else if (image_) {
    statusMsg = [NSString stringWithFormat:@"Render time: %.1f s",
                 [renderer_ elapsedTime]];
    [self setStatus:statusMsg duration:kSucessfulRenderDuration];
  }
}

//------------------------------------------------------------------------------
- (void)endProgress {
  NSRect progressRect = [progress_ frame];
  NSRect statusRect = [status_ frame];
  
  [progress_ stopAnimation:self];
  statusRect.size.width += NSMaxX(progressRect);
  statusRect.origin.x -= NSMaxX(progressRect);
  [status_ setFrame:statusRect];
  
  [progressTimer_ invalidate];
  [progressTimer_ release];
  progressTimer_ = nil;
  [self updateProgress];
}

//------------------------------------------------------------------------------
- (void)rendererFinished:(NSNotification *)note {
  NSDictionary *userInfo = [note userInfo];
	NSArray *screenImagePair = [[userInfo objectForKey:RendererOutputKey] componentsSeparatedByString:@":"];
  NSString *error = [userInfo objectForKey:RendererErrorKey];
  NSString *log = [userInfo objectForKey:RendererLogKey];
  Logging *logging = [[NSApp delegate] logging];
  
  if ([error length]) {
    int line = [[userInfo objectForKey:RendererErrorLineKey] intValue];
    [text_ temporarilyHighlightLine:line color:[[self class] errorHighlightColor]];
    error = [NSString stringWithFormat:@"%@ (Line: %d)", error, line];
    [logging addErrorMsg:error];
    [self setStatus:[NSString stringWithFormat:@"Error on line %d", line]];
  }
  
  if ([log length]) {
    NSString *trimmed = [log stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [logging addLogMsg:trimmed];
  }
  
  if (![error length]) {
    log = [NSString stringWithFormat:@"Rendered: %@ (%d ms, seed: %@)",
           [self name],
           (int)([[userInfo objectForKey:RendererTimeKey] floatValue] * 1000),
           [userInfo objectForKey:RendererSeedKey]];
           [logging addLogMsg:log];
  }

  // If we're exporting, leave our image alone
  if (!isExporting_) {
    CGImageRelease(image_);
    image_ = nil;
    
    NSString *imagePath = screenImagePair.count > 1 ? [screenImagePair objectAtIndex:1] : nil;
    if ([imagePath length] && ![error length]) {
      NSData *data = [NSData dataWithContentsOfFile:imagePath options:0 error:nil];
      
      if (data) {
        CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
        
        if (CGImageSourceGetCount(source) > 0) {
          [imagePath_ release];
          imagePath_ = [imagePath retain];
          image_ = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        }
        
        CFRelease(source);
      } else {
        NSLog(@"Unable to load image at %@", imagePath);
      }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DrawingDocumentNewImageNotification object:self];
  }
  
  isExporting_ = NO;
  [self endProgress];
}

//------------------------------------------------------------------------------
- (NSString *)name {
  NSString *pathName = [[[self fileURL] path] lastPathComponent];
  
  return [pathName length] ? pathName : @"Untitled";
}

//------------------------------------------------------------------------------
- (void)renderFrontmost {
  NSWindow *window = [self windowForSheet];
  
  if ([window isKeyWindow])
    [self render:nil];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSDocument ||
//------------------------------------------------------------------------------
- (NSString *)windowNibName {
  return @"DrawingDocument";
}

//------------------------------------------------------------------------------
- (void)close {
  // Cleanup things before the dealloc
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [renderer_ cancelRender];
  [renderer_ release];
  renderer_ = nil;
  [source_ release];
  source_ = nil;
  CGImageRelease(image_);
  image_ = nil;
  [imagePath_ release];
  imagePath_ = nil;
  [super close];
}

//------------------------------------------------------------------------------
- (void)windowControllerDidLoadNib:(NSWindowController *)controller {
  // If there's no source specified (e.g., Untitled), use our built-in file
  // as the source.
  if (!source_) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *builtInPath = [bundle pathForResource:@"Built-in" ofType:@"tds"];
    source_ = [[NSString alloc] initWithContentsOfFile:builtInPath encoding:NSUTF8StringEncoding
                                                 error:nil];
    [self setFileType:@"tds"];
  }  

  // Set the data of the file
  [text_ setString:source_];
  [source_ release];
  source_ = nil;
  
  // No spell checking
  [text_ setContinuousSpellCheckingEnabled:NO];

  // Add a colorizer
  [text_ addReservedWords:[NSArray arrayWithObjects:
  @"abstract", @"boolean", @"break", @"byte", @"case", @"catch", @"char",
  @"class", @"const", @"continue", @"debugger", @"default", @"delete", @"do",
  @"double", @"else", @"enum", @"export", @"extends", @"false", @"final",
  @"finally", @"float", @"for", @"function", @"goto", @"if", @"implements",
  @"import", @"in", @"instanceof", @"int", @"interface", @"long", @"native",
  @"new", @"null", @"package", @"private", @"protected", @"public", @"return",
  @"short", @"static", @"super", @"switch", @"synchronized", @"this", @"throw",
  @"throws", @"transient", @"true", @"try", @"typeof", @"var", @"void",
  @"volatile", @"while", @"with", nil]];
  [text_ setReservedColor:[NSColor blueColor]];
  
  // Add our specific keywords
  [text_ addUserDefinedWords:[NSArray arrayWithObjects:
                              @"desktop", @"menubar", @"compositor",
                              @"Color", @"ColorSet", @"Filter", @"Gradient", @"GravityPoint", 
                              @"Image",
                              @"Layer", @"Particles", @"Pattern", @"Plasma", @"Point",
                              @"Randomizer", @"Rect", @"Simulator", @"Text",
                              nil]];
  [text_ setUserDefinedColor:[NSColor colorWithCalibratedRed:0.25 green:0.55 blue:0.25 alpha:1]];
  
  [text_ setBlockCommentStart:@"/*" end:@"*/"];
  [text_ setLineComment:@"//"];
  [text_ setCommentColor:[NSColor colorWithCalibratedRed:0.75 green:0.0 blue:0 alpha:1]];
  [text_ setAutomaticallyIndents:YES];
  [text_ colorize];
  
  // Setup tab stops every two spaces
  NSTextStorage *storage = [text_ textStorage];
  int textLength = [storage length];
  NSDictionary *currentAttributes = [storage attributesAtIndex:0 effectiveRange:nil];
  NSFont *font = [currentAttributes objectForKey:NSFontAttributeName];
  float tabWidth = [font pointSize];
  NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
  NSMutableArray *stops = [NSMutableArray array];
  for (int i = 0; i < 15; ++i) {
    NSTextTab *tab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:(float)i * tabWidth];
    [stops addObject:tab];
    [tab release];
  }
  
  // Apply it to the default paragraph as well as the current text
  [style setTabStops:stops];
  [text_ setDefaultParagraphStyle:style];
  NSDictionary *attrs = [NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName];
  [storage addAttributes:attrs range:NSMakeRange(0, textLength)];
//  [text_ setTypingAttributes:currentAttributes];
  [style release];

  [text_ setAllowsUndo:YES];
  [self setStatus:@"Idle."];
  [super windowControllerDidLoadNib:controller];
  
  // Do a check in a short amount of time to see if we are the front window.
  // Do this with a delay because we may be opening multiple windows and we only
  // want to render the front window
  [self performSelector:@selector(renderFrontmost) withObject:nil afterDelay:0.3];
}

//------------------------------------------------------------------------------
- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)error {
  NSData *data = [[text_ string] dataUsingEncoding:NSUTF8StringEncoding];

	return data;
}

//------------------------------------------------------------------------------
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)error {
  source_ = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

  return [source_ length] ? YES : NO;
}

//------------------------------------------------------------------------------
- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
  BOOL result = [super revertToContentsOfURL:absoluteURL ofType:typeName error:outError];
  
  if (result) {
    [text_ setString:source_];
    [text_ colorize];
  }
  
  return result;
}

//------------------------------------------------------------------------------
- (BOOL)hasUndoManager {
  return YES;
}

//------------------------------------------------------------------------------
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)note {
  return [self undoManager];
}

//------------------------------------------------------------------------------
- (BOOL)prepareSavePanel:(NSSavePanel *)panel {
  // Suggest that we save in the last place that something was loaded
  NSURL *folderURL = [NSURL fileURLWithPath:[DocumentController recommendedStorageFolder]
                                isDirectory:YES];
  [panel setDirectoryURL:folderURL];
  [panel setExtensionHidden:NO];
  [panel setCanSelectHiddenExtension:NO];
  [panel setAllowedFileTypes:[NSArray arrayWithObject:@"tds"]];
  [panel setAllowsOtherFileTypes:NO];
  
  return YES;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Actions ||
//------------------------------------------------------------------------------
- (IBAction)render:(id)sender {
  if ([renderer_ isRendering]) {
    NSLog(@"Waiting for render...");
    return;
  }
  
  [self startProgress];

  unsigned long seed = [Renderer randomSeedFromDevice];
  
  if (!renderer_) {
    renderer_ = [[Renderer alloc] initWithReference:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rendererFinished:)
                                                 name:RendererDidFinish object:renderer_];
  }
  
  [renderer_ setSource:[text_ string] name:[self name] seed:seed];
  [renderer_ setType:@"jpeg"];
  [renderer_ setDestination:nil];
  [renderer_ setMaximumSize:NSZeroSize];
  [renderer_ renderInBackgroundAndNotify];

  // Fire an update timer
  progressTimer_ = [[NSTimer scheduledTimerWithTimeInterval:0.5 target:self 
                                                   selector:@selector(updateProgress) userInfo:nil repeats:YES] retain];
  [[NSRunLoop currentRunLoop] addTimer:progressTimer_ forMode:NSRunLoopCommonModes];
  [progressTimer_ fire];
}

//------------------------------------------------------------------------------
- (IBAction)cancelRender:(id)sender {
  [renderer_ cancelRender];
  [self updateProgress];
  [self setStatus:@"Cancelled Render"];
  [progressTimer_ invalidate];
  [progressTimer_ release];
  progressTimer_ = nil;
}

//------------------------------------------------------------------------------
- (IBAction)install:(id)sender {
  NSString *baseName = [Exporter nextBaseName];
  NSString *destDir = [Exporter imageDirectory];
  NSString *path = [destDir stringByAppendingPathComponent:baseName];
  NSDictionary *screenImageDict = [Exporter partitionAndWriteImage:[self image] path:path
																															type:kRenderFormat];
  [Installer installDesktopImagesFromScreenImageDict:screenImageDict];
}

//------------------------------------------------------------------------------
- (void)exportPanelEnded:(NSSavePanel *)panel code:(NSInteger)code context:(void *)context {
  if (code != NSOKButton)
    return;
  
  [self startProgress];
  isExporting_ = YES;
  
  unsigned long seed = [Renderer randomSeedFromDevice];
  
  if (!renderer_) {
    renderer_ = [[Renderer alloc] initWithReference:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rendererFinished:)
                                                 name:RendererDidFinish object:renderer_];
  }
  
  NSSize size = NSMakeSize(1024, 768);
  [renderer_ setSource:[text_ string] name:[self name] seed:seed];
  [renderer_ setDestination:[[panel URL] path]];
  [renderer_ setMaximumSize:size];
  [renderer_ setDisableMenubarRendering:YES];
  [renderer_ renderInBackgroundAndNotify];
  
  [self updateProgress];
}  

- (IBAction)exportSample:(id)sender {
  if ([renderer_ isRendering]) {
    NSLog(@"Waiting for render...");
    return;
  }

  NSSavePanel *panel = [NSSavePanel savePanel];
  [panel setNameFieldLabel:@"Export Sample"];
  [panel setAllowedFileTypes:[Renderer allowedTypes]];
  [panel setCanSelectHiddenExtension:YES];

  NSWindow *window = [[[self windowControllers] objectAtIndex:0] window];
  NSString *baseName = [[self displayName] stringByDeletingPathExtension];
  NSString *name = [NSString stringWithFormat:@"%@.jpeg", baseName];
  [panel setNameFieldStringValue:name];
  [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
    [self exportPanelEnded:panel code:result context:nil];
  }];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
+ (NSColor *)errorHighlightColor {
  return [NSColor colorWithDeviceRed:1 green:0.5 blue:0.5 alpha:1];
}

//------------------------------------------------------------------------------
- (CGImageRef)image {
  return image_;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSResponder ||
//------------------------------------------------------------------------------
- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)item {
  SEL action = [item action];
  BOOL isRendering = [renderer_ isRendering];
  
  if (action == @selector(render:))
    return !isRendering;

  if (action == @selector(cancelRender:))
    return isRendering;
  
  return [super validateUserInterfaceItem:item];
}

@end
