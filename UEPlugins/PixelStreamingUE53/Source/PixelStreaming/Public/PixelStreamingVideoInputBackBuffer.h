// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "PixelStreamingVideoInputRHI.h"
#include "Widgets/SWindow.h"
#include "RHI.h"
#include "Delegates/IDelegateInstance.h"
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 8
#include "Slate/SlateViewportProvider.h"
#endif

/*
 * Use this if you want to send the UE backbuffer as video input.
 */
class PIXELSTREAMING_API FPixelStreamingVideoInputBackBuffer : public FPixelStreamingVideoInputRHI
{
public:
	static TSharedPtr<FPixelStreamingVideoInputBackBuffer> Create();
	virtual ~FPixelStreamingVideoInputBackBuffer();

	virtual FString ToString() override;
private:
	FPixelStreamingVideoInputBackBuffer() = default;

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 8
	void OnBackBufferReady(SWindow& SlateWindow, ISlateViewportProvider& ViewportProvider);
#elif ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 5
	void OnBackBufferReady(SWindow& SlateWindow, const FTextureRHIRef& FrameBuffer);
#else
	void OnBackBufferReady(SWindow& SlateWindow, const FTexture2DRHIRef& FrameBuffer);
#endif

	FDelegateHandle DelegateHandle;
};
