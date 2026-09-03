// Copyright Epic Games, Inc. All Rights Reserved.

#include "PixelStreamingVideoInput.h"
#include "Settings.h"
#include "FrameBufferMultiFormat.h"
#include "PixelCaptureBufferFormat.h"
#include "PixelStreamingTrace.h"

uint32 FPixelStreamingVideoInput::NextStreamId = 1;

FPixelStreamingVideoInput::FPixelStreamingVideoInput()
	: StreamId(NextStreamId++)
{
	CreateFrameCapturer();
}

void FPixelStreamingVideoInput::AddOutputFormat(int32 Format)
{
	PreInitFormats.Add(Format);
	FrameCapturer->AddOutputFormat(Format);
}

void FPixelStreamingVideoInput::OnFrame(const IPixelCaptureInputFrame& InputFrame)
{
	TRACE_CPUPROFILER_EVENT_SCOPE_ON_CHANNEL_STR("PixelStreaming Video Input Frame", PixelStreamingChannel);
	if (LastFrameWidth != -1 && LastFrameHeight != -1)
	{
		if (InputFrame.GetWidth() != LastFrameWidth || InputFrame.GetHeight() != LastFrameHeight)
		{
			CreateFrameCapturer();
		}
	}

	Ready = true;
	
	LastFrameWidth = InputFrame.GetWidth();
	LastFrameHeight = InputFrame.GetHeight();

	FrameCapturer->Capture(InputFrame);
}

rtc::scoped_refptr<webrtc::VideoFrameBuffer> FPixelStreamingVideoInput::GetFrameBuffer()
{
#if WEBRTC_5414
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	return rtc::make_ref_counted<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(FrameCapturer, StreamId, FIntPoint(LastFrameWidth, LastFrameHeight));
#else
	return rtc::make_ref_counted<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(FrameCapturer, StreamId);
#endif
#else
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	return new rtc::RefCountedObject<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(FrameCapturer, StreamId, FIntPoint(LastFrameWidth, LastFrameHeight));
#else
	return new rtc::RefCountedObject<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(FrameCapturer, StreamId);
#endif
#endif
}

rtc::scoped_refptr<webrtc::VideoFrameBuffer> FPixelStreamingVideoInput::GetEmptyFrameBuffer()
{
#if WEBRTC_5414
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	return rtc::make_ref_counted<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(nullptr, StreamId, FIntPoint(LastFrameWidth, LastFrameHeight));
#else
	return rtc::make_ref_counted<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(nullptr, StreamId);
#endif
#else
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	return new rtc::RefCountedObject<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(nullptr, StreamId, FIntPoint(LastFrameWidth, LastFrameHeight));
#else
	return new rtc::RefCountedObject<UE::PixelStreaming::FFrameBufferMultiFormatLayered>(nullptr, StreamId);
#endif
#endif
}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
TSharedPtr<IPixelCaptureOutputFrame> FPixelStreamingVideoInput::RequestFormat(int32 Format, TOptional<FIntPoint> Resolution)
{
	if (FrameCapturer != nullptr)
	{
		if (!Resolution.IsSet())
		{
			Resolution = { LastFrameWidth, LastFrameHeight };
		}
		return FrameCapturer->RequestFormat(Format, *Resolution);
	}
	return nullptr;
}
#else
TSharedPtr<IPixelCaptureOutputFrame> FPixelStreamingVideoInput::RequestFormat(int32 Format, int32 LayerIndex)
{
	if (FrameCapturer != nullptr)
	{
		return FrameCapturer->RequestFormat(Format, LayerIndex);
	}
	return nullptr;
}
#endif

void FPixelStreamingVideoInput::CreateFrameCapturer()
{
	if (FrameCapturer != nullptr)
	{
		FrameCapturer->OnDisconnected();
		FrameCapturer->OnComplete.Remove(CaptureCompleteHandle);
		FrameCapturer = nullptr;
	}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 7
	FrameCapturer = FPixelCaptureCapturerMultiFormat::Create(this);
#else
	TArray<float> LayerScaling;

	for (auto& Layer : UE::PixelStreaming::Settings::SimulcastParameters.Layers)
	{
		LayerScaling.Add(1.0f / Layer.Scaling);
	}
	LayerScaling.Sort([](float ScaleA, float ScaleB) { return ScaleA < ScaleB; });

	FrameCapturer = FPixelCaptureCapturerMultiFormat::Create(this, LayerScaling);
#endif
	CaptureCompleteHandle = FrameCapturer->OnComplete.AddRaw(this, &FPixelStreamingVideoInput::OnCaptureComplete);

	for (auto& Format : PreInitFormats)
	{
		FrameCapturer->AddOutputFormat(Format);
	}
}

void FPixelStreamingVideoInput::OnCaptureComplete()
{
	OnFrameCaptured.Broadcast();
}

FString FPixelStreamingVideoInput::ToString()
{
	return TEXT("a Video Input");
}

uint32 FPixelStreamingVideoInput::GetUniqueStreamId()
{
	return NextStreamId++;
}
