// Copyright Epic Games, Inc. All Rights Reserved.

#include "PixelStreamingVideoInputI420.h"
#include "PixelStreamingPrivate.h"

#include "PixelCaptureBufferFormat.h"
#include "PixelCaptureCapturerI420.h"
#include "PixelCaptureCapturerI420ToRHI.h"

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
TSharedPtr<FPixelCaptureCapturer> FPixelStreamingVideoInputI420::CreateCapturer(int32 FinalFormat, float FinalScale)
#else
TSharedPtr<FPixelCaptureCapturer> FPixelStreamingVideoInputI420::CreateCapturer(int32 FinalFormat, FIntPoint Resolution)
#endif
{
	switch (FinalFormat)
	{
		case PixelCaptureBufferFormat::FORMAT_RHI:
		{
			return FPixelCaptureCapturerI420ToRHI::Create();
		}
		case PixelCaptureBufferFormat::FORMAT_I420:
		{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
			return MakeShared<FPixelCaptureCapturerI420>();
#else
			return FPixelCaptureCapturerI420::Create();
#endif
		}
		default:
			UE_LOG(LogPixelStreaming, Error, TEXT("Unsupported final format %d"), FinalFormat);
			return nullptr;
	}
}
