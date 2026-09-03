// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "PixelStreamingVideoInput.h"

/*
 * A Generic video input for NV12 frames
 */
class PIXELSTREAMING_API FPixelStreamingVideoInputNV12 : public FPixelStreamingVideoInput
{
public:
	FPixelStreamingVideoInputNV12() = default;
	virtual ~FPixelStreamingVideoInputNV12() = default;

protected:
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	// UE 5.7+ refactored the capturer creation API to take an output resolution instead of a scale.
	virtual TSharedPtr<FPixelCaptureCapturer> CreateCapturer(int32 FinalFormat, FIntPoint Resolution) override;
#else
	virtual TSharedPtr<FPixelCaptureCapturer> CreateCapturer(int32 FinalFormat, float FinalScale) override;
#endif
};
