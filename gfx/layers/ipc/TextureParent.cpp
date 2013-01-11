/* -*- Mode: C++; tab-width: 20; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "mozilla/layers/TextureParent.h"
#include "mozilla/layers/Compositor.h"
#include "BufferHost.h"
#include "mozilla/layers/TextureFactoryIdentifier.h" // for TextureInfo

namespace mozilla {
namespace layers {

TextureParent::TextureParent(const TextureInfo& aInfo)
: mTextureInfo(aInfo)
{
}

TextureParent::~TextureParent()
{
    mTextureHost = nullptr;
}

void TextureParent::SetTextureHost(TextureHost* aHost)
{
    mTextureHost = aHost;
}

TextureHost* TextureParent::GetTextureHost() const
{
    return mTextureHost;
}


} // namespace
} // namespace
