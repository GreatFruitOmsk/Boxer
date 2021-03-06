/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowControllerLion.h"
#import "BXDOSWindowControllerPrivate.h"
#import "ADBForwardCompatibility.h"
#import "BXSession.h"
#import "BXInputView.h"
#import "BXDOSWindow.h"

@implementation BXDOSWindowControllerLion

#pragma mark -
#pragma mark Window life cycle

- (void) windowDidLoad
{
	[super windowDidLoad];
	
    //Set the window's fullscreen behaviour for Lion
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    
    //Disable window restoration for DOS sessions
    //(This does not play nice with our application lifecycle)
    self.window.restorable = NO;
}

- (void) windowWillClose: (NSNotification *)notification
{
    [super windowWillClose: notification];
    
    //Workaround for a Lion bug whereby if the window close button is triggered
    //by a touch event that includes a resting touch, then the event system may
    //try to send touchesCancelled: events to a now-deallocated view.
    //Turning off touch events just before window close seems to prevent this
    //from happening, though the underlying bug is likely to get fixed in
    //a later Lion update.
    self.inputView.acceptsTouchEvents = NO;
}

#pragma mark -
#pragma mark Fullscreen transitions

- (void) windowWillEnterFullScreen: (NSNotification *)notification
{
    [super windowWillEnterFullScreen: notification];
    
    //Hide the status bar and program panel elements before entering fullscreen
    _statusBarShownBeforeFullScreen      = self.statusBarShown;
    _programPanelShownBeforeFullScreen   = self.programPanelShown;
    
    //Note: we call super instead of self to show/hide these elements during our
    //fullscreen transition, because we've overridden them ourselves to disable
    //showing/hiding when in fullscreen.
    [super setStatusBarShown: NO animate: NO];
    [super setProgramPanelShown: NO animate: NO];
}

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window
{
    [super windowDidFailToEnterFullScreen: window];
    [super setStatusBarShown: _statusBarShownBeforeFullScreen animate: NO];
    [super setProgramPanelShown: _programPanelShownBeforeFullScreen animate: NO];
}

- (void) windowWillExitFullScreen: (NSNotification *)notification
{
    [super windowWillExitFullScreen: notification];
    [super setStatusBarShown: _statusBarShownBeforeFullScreen animate: NO];
    [super setProgramPanelShown: _programPanelShownBeforeFullScreen animate: NO];
}

- (void) windowDidFailToExitFullScreen: (NSWindow *)window
{
    [super windowDidFailToExitFullScreen: window];
    [super setStatusBarShown: NO animate: NO];
    [super setProgramPanelShown: NO animate: NO];
}

- (NSApplicationPresentationOptions) window: (NSWindow *)window
       willUseFullScreenPresentationOptions: (NSApplicationPresentationOptions)proposedOptions
{
    return proposedOptions | NSApplicationPresentationAutoHideToolbar;
}


#pragma mark -
#pragma mark UI element toggles


//IMPLEMENTATION NOTE: Unlike in Snow Leopard, we cannot (currently) toggle the statusbar and program panel
//elements while in Lion fullscreen. So instead we save their intended state and apply that when returning
//from fullscreen mode.
//However, we do allow the toggles to go ahead while we're transitioning to/from fullscreen, because our
//own fullscreen notification handlers call these to set up the window.
- (BOOL) statusBarShown
{
    if (self.window.isFullScreen)
        return _statusBarShownBeforeFullScreen;
    else return super.statusBarShown;
}

- (BOOL) programPanelShown
{
    if (self.window.isFullScreen)
        return _programPanelShownBeforeFullScreen;
    else return super.programPanelShown;
}

- (void) setStatusBarShown: (BOOL)show animate: (BOOL)animate
{
    _statusBarShownBeforeFullScreen = show;
    
    if (!self.window.isFullScreen)
	{
		[super setStatusBarShown: show animate: animate];
	}
}

- (void) setProgramPanelShown: (BOOL)show animate: (BOOL)animate
{
	//Don't open the program panel if we're not running a gamebox
	if (show && !self.document.hasGamebox) return;
	
    _programPanelShownBeforeFullScreen = show;
	
    if (!self.window.isFullScreen)
	{
		[super setProgramPanelShown: show animate: animate];
	}
}

@end
