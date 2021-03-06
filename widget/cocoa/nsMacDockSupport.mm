/* -*- Mode: c++; tab-width: 2; indent-tabs-mode: nil; -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

#include "nsComponentManagerUtils.h"
#include "nsMacDockSupport.h"
#include "nsObjCExceptions.h"

NS_IMPL_ISUPPORTS2(nsMacDockSupport, nsIMacDockSupport, nsITaskbarProgress)

nsMacDockSupport::nsMacDockSupport()
: mAppIcon(nil)
, mProgressBackground(nil)
, mProgressState(STATE_NO_PROGRESS)
, mProgressFraction(0.0)
{
  mProgressTimer = do_CreateInstance(NS_TIMER_CONTRACTID);
}

nsMacDockSupport::~nsMacDockSupport()
{
  if (mAppIcon) {
    [mAppIcon release];
    mAppIcon = nil;
  }
  if (mProgressBackground) {
    [mProgressBackground release];
    mProgressBackground = nil;
  }
  if (mProgressTimer) {
    mProgressTimer->Cancel();
    mProgressTimer = nullptr;
  }
}

NS_IMETHODIMP
nsMacDockSupport::GetDockMenu(nsIStandaloneNativeMenu ** aDockMenu)
{
  *aDockMenu = nullptr;

  if (mDockMenu)
    return mDockMenu->QueryInterface(NS_GET_IID(nsIStandaloneNativeMenu),
                                     reinterpret_cast<void **>(aDockMenu));
  return NS_OK;
}

NS_IMETHODIMP
nsMacDockSupport::SetDockMenu(nsIStandaloneNativeMenu * aDockMenu)
{
  nsresult rv;
  mDockMenu = do_QueryInterface(aDockMenu, &rv);
  return rv;
}

NS_IMETHODIMP
nsMacDockSupport::ActivateApplication(bool aIgnoreOtherApplications)
{
  NS_OBJC_BEGIN_TRY_ABORT_BLOCK_NSRESULT;

  [[NSApplication sharedApplication] activateIgnoringOtherApps:aIgnoreOtherApplications];
  return NS_OK;

  NS_OBJC_END_TRY_ABORT_BLOCK_NSRESULT;
}

NS_IMETHODIMP
nsMacDockSupport::SetBadgeText(const nsAString& aBadgeText)
{
  NS_OBJC_BEGIN_TRY_ABORT_BLOCK_NSRESULT;

  NSDockTile *tile = [[NSApplication sharedApplication] dockTile];
  mBadgeText = aBadgeText;
  if (aBadgeText.IsEmpty())
    [tile setBadgeLabel: nil];
  else
    [tile setBadgeLabel:[NSString stringWithCharacters:mBadgeText.get() length:mBadgeText.Length()]];
  return NS_OK;

  NS_OBJC_END_TRY_ABORT_BLOCK_NSRESULT;
}

NS_IMETHODIMP
nsMacDockSupport::GetBadgeText(nsAString& aBadgeText)
{
  aBadgeText = mBadgeText;
  return NS_OK;
}

NS_IMETHODIMP
nsMacDockSupport::SetProgressState(nsTaskbarProgressState aState,
                                   PRUint64 aCurrentValue,
                                   PRUint64 aMaxValue)
{
  NS_ENSURE_ARG_RANGE(aState, 0, STATE_PAUSED);
  if (aState == STATE_NO_PROGRESS || aState == STATE_INDETERMINATE) {
    NS_ENSURE_TRUE(aCurrentValue == 0, NS_ERROR_INVALID_ARG);
    NS_ENSURE_TRUE(aMaxValue == 0, NS_ERROR_INVALID_ARG);
  }
  if (aCurrentValue > aMaxValue) {
    return NS_ERROR_ILLEGAL_VALUE;
  }

  mProgressState = aState;
  if (aMaxValue == 0) {
    mProgressFraction = 0;
  } else {
    mProgressFraction = (double)aCurrentValue / aMaxValue;
  }

  if (mProgressState == STATE_NORMAL || mProgressState == STATE_INDETERMINATE) {
    int perSecond = 30;
    mProgressTimer->InitWithFuncCallback(RedrawIconCallback, this, 1000 / perSecond,
      nsITimer::TYPE_REPEATING_SLACK);
    return NS_OK;
  } else {
    mProgressTimer->Cancel();
    return RedrawIcon();
  }
}

// static
void nsMacDockSupport::RedrawIconCallback(nsITimer* aTimer, void* aClosure)
{
  static_cast<nsMacDockSupport*>(aClosure)->RedrawIcon();
}

// Return whether to draw progress
bool nsMacDockSupport::InitProgress()
{
  if (mProgressState != STATE_NORMAL && mProgressState != STATE_INDETERMINATE) {
    return false;
  }

  if (!mAppIcon) {
    mProgressTimer = do_CreateInstance(NS_TIMER_CONTRACTID);
    mAppIcon = [[NSImage imageNamed:@"NSApplicationIcon"] retain];
    mProgressBackground = [mAppIcon copyWithZone:nil];

    NSSize sz = [mProgressBackground size];
    mProgressDrawInfo.version = 0;
    mProgressDrawInfo.min = 0;
    mProgressDrawInfo.value = 0;
    mProgressDrawInfo.max = PR_INT32_MAX;
    mProgressDrawInfo.bounds = CGRectMake(sz.width * 1/32, sz.height * 3/32,
                                          sz.width * 30/32, sz.height * 2/32);
    mProgressDrawInfo.attributes = kThemeTrackHorizontal;
    mProgressDrawInfo.enableState = kThemeTrackActive;
    mProgressDrawInfo.kind = kThemeLargeProgressBar;
    mProgressDrawInfo.trackInfo.progress.phase = 0;

    // Draw a light background, to visually distinguish the progress.
    HIRect bounds;
    HIThemeGetTrackBounds(&mProgressDrawInfo, &bounds);
    // Margins within track, empirically. FIXME: Don't hardcode?
    int mleft = 3, mtop = 3, mright = 3, mbot = 1;
    bounds.origin.x += mleft;
    bounds.origin.y += mbot;
    bounds.size.width -= mleft + mright;
    bounds.size.height -= mtop + mbot;

    [mProgressBackground lockFocus];
    [[NSColor whiteColor] set];
    NSRectFill(NSRectFromCGRect(bounds));
    [mProgressBackground unlockFocus];
  }
  return true;
}

nsresult
nsMacDockSupport::RedrawIcon()
{
  NS_OBJC_BEGIN_TRY_ABORT_BLOCK_NSRESULT;

  if (InitProgress()) {
    // TODO: - Share code with nsNativeThemeCocoa?
    //       - Implement ERROR and PAUSED states?
    NSImage *icon = [mProgressBackground copyWithZone:nil];

    bool isIndeterminate = (mProgressState != STATE_NORMAL);
    mProgressDrawInfo.value = PR_INT32_MAX * mProgressFraction;
    mProgressDrawInfo.kind = isIndeterminate ? kThemeLargeIndeterminateBar
                                             : kThemeLargeProgressBar;

    int stepsPerSecond = isIndeterminate ? 60 : 30;
    mProgressDrawInfo.trackInfo.progress.phase =
      uint8_t(PR_IntervalToMilliseconds(PR_IntervalNow()) * stepsPerSecond / 1000);

    [icon lockFocus];
    CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    HIThemeDrawTrack(&mProgressDrawInfo, NULL, ctx, kHIThemeOrientationNormal);
    [icon unlockFocus];
    [NSApp setApplicationIconImage:icon];
    [icon release];
  } else {
    [NSApp setApplicationIconImage:mAppIcon];
  }

  return NS_OK;
  NS_OBJC_END_TRY_ABORT_BLOCK_NSRESULT;
}
