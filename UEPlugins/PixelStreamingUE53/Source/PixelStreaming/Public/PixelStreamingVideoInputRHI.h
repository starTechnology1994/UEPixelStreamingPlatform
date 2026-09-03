// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "PixelStreamingVideoInput.h"

/*
 * A Generic video input for RHI frames
 */
class PIXELSTREAMING_API FPixelStreamingVideoInputRHI : public FPixelStreamingVideoInput
{
public:
	FPixelStreamingVideoInputRHI() = default;
	virtual ~FPixelStreamingVideoInputRHI() = default;

protected:
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	// UE 5.7+ refactored the capturer creation API to take an output resolution instead of a scale.
	virtual TSharedPtr<FPixelCaptureCapturer> CreateCapturer(int32 FinalFormat, FIntPoint Resolution) override;
#else
	virtual TSharedPtr<FPixelCaptureCapturer> CreateCapturer(int32 FinalFormat, float FinalScale) override;
#endif
};
