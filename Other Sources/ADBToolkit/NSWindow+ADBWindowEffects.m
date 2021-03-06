/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "NSWindow+ADBWindowEffects.h"

#pragma mark -
#pragma mark Private method declarations

@interface NSWindow (ADBWindowEffectsPrivate)
//Completes the ordering out from a fadeOutWithDuration: call.
- (void) _orderOutAfterFade;
@end


@implementation NSWindow (ADBWindowEffects)

- (void) fadeInWithDuration: (NSTimeInterval)duration
{
    //Don't bother fading in if we're already completely visible; just cancel any pending order-out.
	if (!self.isVisible || self.alphaValue < 1.0f)
    {
        //Hide ourselves completely if we weren't visible, before fading in.
        if (!self.isVisible) self.alphaValue = 0.0f;
        
        [self orderFront: self];
        
        [NSAnimationContext beginGrouping];
            [NSAnimationContext currentContext].duration = duration;
            [self.animator setAlphaValue: 1.0f];
        [NSAnimationContext endGrouping];
	}
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_orderOutAfterFade) object: nil];
}

- (void) fadeOutWithDuration: (NSTimeInterval)duration
{
	if (!self.isVisible) return;
	
	[NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration: duration];
    [self.animator setAlphaValue: 0.0f];
	[NSAnimationContext endGrouping];
	[self performSelector: @selector(_orderOutAfterFade) withObject: nil afterDelay: duration];
}

- (void) _orderOutAfterFade
{
	[self willChangeValueForKey: @"visible"];
	[self orderOut: self];
	[self didChangeValueForKey: @"visible"];
	
    //Restore our alpha value after we've finished ordering out.
	self.alphaValue = 1.0f;
}

@end



#ifdef USE_PRIVATE_APIS

@interface NSWindow (ADBPrivateAPIWindowEffectsReallyPrivate)
//Cleans up after a transition by releasing the specified handle.
- (void) _releaseTransitionHandle: (NSNumber *)handleNum;

//Used internally by applyCGSTransition:direction:duration: and related methods.
//Callback is called with callbackObj as the parameter immediately before the
//transition is invoked: this allows the callback to update the window state
//(or show/hide the window) for the end of the transition.
- (void) _applyCGSTransition: (CGSTransitionType)type
                   direction: (CGSTransitionOption)direction
                    duration: (NSTimeInterval)duration
                withCallback: (SEL)callback
              callbackObject: (id)callbackObj
                blockingMode: (NSAnimationBlockingMode)blockingMode;

//Takes the float value of the specified number and sets the window's alpha to it.
//Used for showing/hiding windows during a transition.
- (void) _setAlphaForTransition: (NSNumber *)alphaValue;
@end

@implementation NSWindow (ADBPrivateAPIWindowEffects)

#pragma mark -
#pragma mark High-level methods you might actually want to call

- (void) applyGaussianBlurWithRadius: (CGFloat)radius
{	
	[self addCGSFilterWithName: @"CIGaussianBlur"
				   withOptions: @{@"inputRadius": @(radius)}
				backgroundOnly: YES];
}

- (void) revealWithTransition: (CGSTransitionType)type
					direction: (CGSTransitionOption)direction
					 duration: (NSTimeInterval)duration
				 blockingMode: (NSAnimationBlockingMode)blockingMode
{
	CGFloat oldAlpha = self.alphaValue;
    self.alphaValue = 0.0f;
	[self orderFront: self];
    
	[self _applyCGSTransition: type
					direction: direction
					 duration: duration
				 withCallback: @selector(_setAlphaForTransition:)
			   callbackObject: @(oldAlpha)
				 blockingMode: blockingMode];
}

- (void) hideWithTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode
{
	CGFloat oldAlpha = self.alphaValue;
	[self _applyCGSTransition: type
					direction: direction
					 duration: duration
				 withCallback: @selector(_setAlphaForTransition:)
			   callbackObject: @(0.0f)
				 blockingMode: blockingMode];
	
	[self willChangeValueForKey: @"visible"];
	[self orderOut: self];
	[self didChangeValueForKey: @"visible"];
	
    self.alphaValue = oldAlpha;
}

- (void) _setAlphaForTransition: (NSNumber *)alphaValue
{
    self.alphaValue = alphaValue.floatValue;
}

#pragma mark -
#pragma mark Low-level effects

- (void) addCGSFilterWithName: (NSString *)filterName
				  withOptions: (NSDictionary *)filterOptions
			   backgroundOnly: (BOOL)backgroundOnly
{
	CGSConnection conn = _CGSDefaultConnection();
	
	if (conn)
	{
		CGSWindowFilterRef filter = NULL;
	
		//Create a CoreImage gaussian blur filter.
		CGSNewCIFilterByName(conn, (__bridge CFStringRef)filterName, &filter);
		
		if (filter)
		{
			CGSWindowID windowNumber = (CGSWindowID)self.windowNumber;
			int compositingType = (int)backgroundOnly;
			
			CGSSetCIFilterValuesFromDictionary(conn, filter, (__bridge CFDictionaryRef)filterOptions);
			
			CGSAddWindowFilter(conn, windowNumber, filter, compositingType);
			
			//Clean up after ourselves.
			CGSReleaseCIFilter(conn, filter);			
		}
	}
}

- (void) applyCGSTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode
{
	[self _applyCGSTransition: type
					direction: direction
					 duration: duration
				 withCallback: @selector(display)
			   callbackObject: nil
				 blockingMode: blockingMode];
}

- (void) _applyCGSTransition: (CGSTransitionType)type
				   direction: (CGSTransitionOption)direction
					duration: (NSTimeInterval)duration
				withCallback: (SEL)callback
			  callbackObject: (id)callbackObj
				blockingMode: (NSAnimationBlockingMode)blockingMode
{
	//If the application isn't active, then avoid applying the effect: it will look distractingly wrong anyway 
	if (![NSApp isActive] || [NSApp isHidden])
	{
		[self performSelector: callback withObject: callbackObj];
		return;
	}
	
	CGSConnection conn = _CGSDefaultConnection();
	
	if (conn)
	{
		CGSTransitionSpec spec;
		spec.unknown1 = 0;
		spec.type = type;
		spec.option = direction | CGSTransparentBackgroundMask;
		spec.wid = (CGSWindow)self.windowNumber;
		spec.backColour = NULL;
		
		int handle = 0;
		
		CGSNewTransition(conn, &spec, &handle);
		
		//Do any redrawing, now that Core Graphics has captured the previous window state.
		//The transition will switch from the previous window state to this new one.
		[self performSelector: callback withObject: callbackObj];
		
		if (handle)
		{
			CGSInvokeTransition(conn, handle, (float)duration);
			
			if (blockingMode == NSAnimationBlocking)
			{
				[NSThread sleepForTimeInterval: duration];
				CGSReleaseTransition(conn, handle);
			}
			else
			{
				//To avoid blocking the thread, call the cleanup function with a delay.
				[self performSelector: @selector(_releaseTransitionHandle:)
						   withObject: @(handle)
						   afterDelay: duration];
			}

		}
	}
}

- (void) _releaseTransitionHandle: (NSNumber *)handleNum
{
	CGSConnection conn = _CGSDefaultConnection();
	CGSReleaseTransition(conn, [handleNum intValue]);
}

@end
#endif
