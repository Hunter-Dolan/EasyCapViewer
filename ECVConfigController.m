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
#import "ECVConfigController.h"

@implementation ECVConfigController

#pragma mark -ECVConfigController

- (IBAction)snapSlider:(id)sender
{
	if(ABS([sender doubleValue] - 0.5f) < 0.03f) [sender setDoubleValue:0.5f];
}
- (IBAction)dismiss:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

#pragma mark -

- (void)beginSheetForCaptureController:(ECVCaptureController *)c
{
	NSParameterAssert(c);
	(void)[self window]; // Load.

	_captureController = c;
	[inputTypeMatrix selectCellWithTag:[_captureController videoFormat]];
	for(NSButtonCell *const cell in [inputTypeMatrix cells]) [cell setEnabled:[_captureController supportsVideoFormat:[cell tag]]];

	[sourcePopUp removeAllItems];
	if([_captureController respondsToSelector:@selector(allVideoSources)]) for(id const source in _captureController.allVideoSources) {
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[_captureController localizedStringForVideoSource:source] action:NULL keyEquivalent:@""] autorelease];
		[item setRepresentedObject:source];
		[[sourcePopUp menu] addItem:item];
	}
	[sourcePopUp setEnabled:[_captureController respondsToSelector:@selector(videoSource)]];
	if([sourcePopUp isEnabled]) [sourcePopUp selectItemAtIndex:[sourcePopUp indexOfItemWithRepresentedObject:_captureController.videoSource]];

	[resolutionPopUp removeAllItems];
	if([_captureController respondsToSelector:@selector(allResolutions)]) for(id const resolution in _captureController.allResolutions) {
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[_captureController localizedStringForResolution:resolution] action:NULL keyEquivalent:@""] autorelease];
		[item setRepresentedObject:resolution];
		[[resolutionPopUp menu] addItem:item];
	}
	[resolutionPopUp setEnabled:[_captureController respondsToSelector:@selector(resolution)]];
	if([resolutionPopUp isEnabled]) [resolutionPopUp selectItemAtIndex:[resolutionPopUp indexOfItemWithRepresentedObject:_captureController.resolution]];

	[deinterlacePopUp selectItemWithTag:_captureController.deinterlacingMode];

	[brightnessSlider setEnabled:[_captureController respondsToSelector:@selector(brightness)]];
	[contrastSlider setEnabled:[_captureController respondsToSelector:@selector(contrast)]];
	[hueSlider setEnabled:[_captureController respondsToSelector:@selector(hue)]];
	[saturationSlider setEnabled:[_captureController respondsToSelector:@selector(saturation)]];
	[brightnessSlider setDoubleValue:[brightnessSlider isEnabled] ? _captureController.brightness : 0.5f];
	[contrastSlider setDoubleValue:[contrastSlider isEnabled] ? _captureController.contrast : 0.5f];
	[hueSlider setDoubleValue:[hueSlider isEnabled] ? _captureController.hue : 0.5f];
	[saturationSlider setDoubleValue:[saturationSlider isEnabled] ? _captureController.saturation : 0.5f];
	[self snapSlider:brightnessSlider];
	[self snapSlider:contrastSlider];
	[self snapSlider:hueSlider];
	[self snapSlider:saturationSlider];

	(void)[self retain];
	if(c.fullScreen) {
		[self sheetDidEnd:[self window] returnCode:[NSApp runModalForWindow:[self window]] contextInfo:NULL];
	} else {
		[NSApp beginSheet:[self window] modalForWindow:[c window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	}
}
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if(NSOKButton == returnCode) {
		BOOL const playing = _captureController.playing;
		if(playing) _captureController.playing = NO;
		_captureController.videoFormat = [inputTypeMatrix selectedTag];
		_captureController.deinterlacingMode = [deinterlacePopUp selectedTag];
		if([_captureController respondsToSelector:@selector(setVideoSource:)]) _captureController.videoSource = [[sourcePopUp selectedItem] representedObject];
		if([_captureController respondsToSelector:@selector(setResolution:)]) _captureController.resolution = [[resolutionPopUp selectedItem] representedObject];
		if([_captureController respondsToSelector:@selector(setBrightness:)]) _captureController.brightness = [brightnessSlider doubleValue];
		if([_captureController respondsToSelector:@selector(setContrast:)]) _captureController.contrast = [contrastSlider doubleValue];
		if([_captureController respondsToSelector:@selector(setHue:)]) _captureController.hue = [hueSlider doubleValue];
		if([_captureController respondsToSelector:@selector(setSaturation:)]) _captureController.saturation = [saturationSlider doubleValue];
		if(playing) _captureController.playing = YES;
	}
	[[self window] close];
	[self autorelease];
}

#pragma mark -NSObject

- (id)init
{
	return [super initWithWindowNibName:@"ECVConfig"];
}

@end
