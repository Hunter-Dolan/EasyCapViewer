/* Copyright (c) 2009, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
// Views
#import "ECVVideoView.h"

// Other Sources
#import "ECVRectEdgeMask.h"

@protocol ECVCropCellDelegate;

@interface ECVCropCell : NSCell <ECVVideoViewCell>
{
	@private
	IBOutlet NSObject<ECVCropCellDelegate> *delegate;
	NSRect _cropRect;
	NSRect _tempCropRect;
	NSBitmapImageRep *_handleRep;
	GLuint _handleTextureName;
}

- (id)initWithOpenGLContext:(NSOpenGLContext *)context;
@property(assign) NSObject<ECVCropCellDelegate> *delegate;
@property(nonatomic, assign) NSRect cropRect;

- (NSRect)maskRectWithCropRect:(NSRect)crop frame:(NSRect)frame;
- (NSRect)frameForHandlePosition:(ECVRectEdgeMask)pos maskRect:(NSRect)mask inFrame:(NSRect)frame;
- (ECVRectEdgeMask)handlePositionForPoint:(NSPoint)point withMaskRect:(NSRect)mask inFrame:(NSRect)frame view:(NSView *)aView;
- (NSCursor *)cursorForHandlePosition:(ECVRectEdgeMask)pos;

@end

@protocol ECVCropCellDelegate <NSObject>
@optional
- (void)cropCellDidFinishCropping:(ECVCropCell *)sender;
@end
