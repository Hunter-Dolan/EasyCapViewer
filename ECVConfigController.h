/* Copyright (c) 2009, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * The names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

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
#import <Cocoa/Cocoa.h>

// Controllers
#import "ECVCaptureController.h"

@interface ECVConfigController : NSWindowController
{
	@private
	IBOutlet NSMatrix *inputTypeMatrix;
	IBOutlet NSPopUpButton *sourcePopUp;
	IBOutlet NSPopUpButton *resolutionPopUp;
	IBOutlet NSPopUpButton *deinterlacePopUp;
	IBOutlet NSSlider *brightnessSlider;
	IBOutlet NSSlider *contrastSlider;
	IBOutlet NSSlider *hueSlider;
	IBOutlet NSSlider *saturationSlider;
	ECVCaptureController *_captureController;
}

- (IBAction)snapSlider:(id)sender;
- (IBAction)dismiss:(id)sender; // Uses the return code from [sender tag].

- (void)beginSheetForCaptureController:(ECVCaptureController *)c;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

@interface ECVCaptureController(ECVConfigOptional)

@property(readonly) NSArray *allVideoSources;
- (NSString *)localizedStringForVideoSource:(id)obj;
@property(assign) id videoSource;

@property(readonly) NSArray *allResolutions;
- (NSString *)localizedStringForResolution:(id)obj;
@property(assign) id resolution;

@property(assign) CGFloat brightness;
@property(assign) CGFloat contrast;
@property(assign) CGFloat hue;
@property(assign) CGFloat saturation;

@end