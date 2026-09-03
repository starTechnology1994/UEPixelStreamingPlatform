// Copyright Epic Games, Inc. All Rights Reserved.

#include "PixelStreamingVideoInputRHI.h"
#include "PixelStreamingPrivate.h"
#include "Settings.h"
#include "PixelCaptureBufferFormat.h"
#include "PixelCaptureCapturerRHI.h"
#include "PixelCaptureCapturerRHIRDG.h"
#include "PixelCaptureCapturerRHIToI420CPU.h"
#include "PixelCaptureCapturerRHIToI420Compute.h"

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
TSharedPtr<FPixelCaptureCapturer> FPixelStreamingVideoInputRHI::CreateCapturer(int32 FinalFormat, float FinalScale)
#else
TSharedPtr<FPixelCaptureCapturer> FPixelStreamingVideoInputRHI::CreateCapturer(int32 FinalFormat, FIntPoint Resolution)
#endif
{
	switch (FinalFormat)
	{
		case PixelCaptureBufferFormat::FORMAT_RHI:
		{
			// "Safe Texture Copy" polls a fence to ensure a GPU copy is complete
			// the RDG pathway does not poll a fence so is more unsafe but offers
			// a significant performance increase
			if (UE::PixelStreaming::Settings::CVarPixelStreamingCaptureUseFence.GetValueOnAnyThread())
			{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
				return FPixelCaptureCapturerRHI::Create(FinalScale);
#else
				return FPixelCaptureCapturerRHI::Create({ .OutputResolution = Resolution });
#endif
			}
			else
			{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
				return FPixelCaptureCapturerRHIRDG::Create(FinalScale);
#else
				return FPixelCaptureCapturerRHIRDG::Create({ .OutputResolution = Resolution });
#endif
			}
		}
		case PixelCaptureBufferFormat::FORMAT_I420:
		{
			if (UE::PixelStreaming::Settings::CVarPixelStreamingVPXUseCompute.GetValueOnAnyThread())
			{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
				return FPixelCaptureCapturerRHIToI420Compute::Create(FinalScale);
#else
				return FPixelCaptureCapturerRHIToI420Compute::Create({ .OutputResolution = Resolution });
#endif
			}
			else
			{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
				return FPixelCaptureCapturerRHIToI420CPU::Create(FinalScale);
#else
				return FPixelCaptureCapturerRHIToI420CPU::Create({ .OutputResolution = Resolution });
#endif
			}
		}
		default:
			UE_LOG(LogPixelStreaming, Error, TEXT("Unsupported final format %d"), FinalFormat);
			return nullptr;
	}
}
