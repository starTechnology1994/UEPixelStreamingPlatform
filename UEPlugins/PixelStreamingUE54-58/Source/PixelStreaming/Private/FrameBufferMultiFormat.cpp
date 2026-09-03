// Copyright Epic Games, Inc. All Rights Reserved.

#include "FrameBufferMultiFormat.h"

namespace UE::PixelStreaming
{
	FFrameBufferMultiFormatBase::FFrameBufferMultiFormatBase(TSharedPtr<FPixelCaptureCapturerMultiFormat> InFrameCapturer, uint32 InStreamId)
		: FrameCapturer(InFrameCapturer)
		, StreamId(InStreamId)
	{
	}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	FFrameBufferMultiFormatLayered::FFrameBufferMultiFormatLayered(TSharedPtr<FPixelCaptureCapturerMultiFormat> InFrameCapturer, uint32 InStreamId, FIntPoint SourceResolution)
		: FFrameBufferMultiFormatBase(InFrameCapturer, InStreamId)
		, SourceResolution(SourceResolution)
	{
	}
#else
	FFrameBufferMultiFormatLayered::FFrameBufferMultiFormatLayered(TSharedPtr<FPixelCaptureCapturerMultiFormat> InFrameCapturer, uint32 InStreamId)
		: FFrameBufferMultiFormatBase(InFrameCapturer, InStreamId)
	{
	}
#endif

	int FFrameBufferMultiFormatLayered::width() const
	{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
		return SourceResolution.X;
#else
		return FrameCapturer ? FrameCapturer->GetWidth(GetNumLayers() - 1) : -1;
#endif
	}

	int FFrameBufferMultiFormatLayered::height() const
	{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
		return SourceResolution.Y;
#else
		return FrameCapturer ? FrameCapturer->GetHeight(GetNumLayers() - 1) : -1;
#endif
	}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7
	int FFrameBufferMultiFormatLayered::GetNumLayers() const
	{
		return FrameCapturer ? FrameCapturer->GetNumLayers() : -1;
	}
#endif

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	rtc::scoped_refptr<FFrameBufferMultiFormat> FFrameBufferMultiFormatLayered::GetLayer(FIntPoint Resolution) const
	{
#if WEBRTC_5414
		return rtc::make_ref_counted<FFrameBufferMultiFormat>(FrameCapturer, StreamId, Resolution);
#else
		return new rtc::RefCountedObject<FFrameBufferMultiFormat>(FrameCapturer, StreamId, Resolution);
#endif
	}
#else
	rtc::scoped_refptr<FFrameBufferMultiFormat> FFrameBufferMultiFormatLayered::GetLayer(int LayerIndex) const
	{
#if WEBRTC_5414
		return rtc::make_ref_counted<FFrameBufferMultiFormat>(FrameCapturer, StreamId, LayerIndex);
#else
		return new rtc::RefCountedObject<FFrameBufferMultiFormat>(FrameCapturer, StreamId, LayerIndex);
#endif
	}
#endif

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	FFrameBufferMultiFormat::FFrameBufferMultiFormat(TSharedPtr<FPixelCaptureCapturerMultiFormat> InFrameCapturer, uint32 InStreamId, FIntPoint Resolution)
		: FFrameBufferMultiFormatBase(InFrameCapturer, InStreamId)
		, Resolution(Resolution)
	{
	}
#else
	FFrameBufferMultiFormat::FFrameBufferMultiFormat(TSharedPtr<FPixelCaptureCapturerMultiFormat> InFrameCapturer, uint32 InStreamId, int InLayerIndex)
		: FFrameBufferMultiFormatBase(InFrameCapturer, InStreamId)
		, LayerIndex(InLayerIndex)
	{
	}
#endif

	int FFrameBufferMultiFormat::width() const
	{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
		return Resolution.X;
#else
		return FrameCapturer ? FrameCapturer->GetWidth(LayerIndex) : -1;
#endif
	}

	int FFrameBufferMultiFormat::height() const
	{
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
		return Resolution.Y;
#else
		return FrameCapturer ? FrameCapturer->GetHeight(LayerIndex) : -1;
#endif
	}

	IPixelCaptureOutputFrame* FFrameBufferMultiFormat::RequestFormat(int32 Format) const
	{
		// ensure this frame buffer will always refer to the same frame
		if (TSharedPtr<IPixelCaptureOutputFrame>* CachedFrame = CachedFormat.Find(Format))
		{
			return CachedFrame->Get();
		}

		if (!FrameCapturer)
		{
			return nullptr;
		}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
		TSharedPtr<IPixelCaptureOutputFrame> Frame = FrameCapturer->WaitForFormat(Format, Resolution);
#else
		TSharedPtr<IPixelCaptureOutputFrame> Frame = FrameCapturer->WaitForFormat(Format, LayerIndex);
#endif
		CachedFormat.Add(Format, Frame);
		return Frame.Get();
	}
} // namespace UE::PixelStreaming
