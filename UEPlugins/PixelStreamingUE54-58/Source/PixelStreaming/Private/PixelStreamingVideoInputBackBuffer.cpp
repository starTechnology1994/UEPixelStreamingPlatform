// Copyright Epic Games, Inc. All Rights Reserved.

#include "PixelStreamingVideoInputBackBuffer.h"
#include "PixelStreamingPrivate.h"
#include "Settings.h"
#include "Utils.h"

#include "PixelCaptureInputFrameRHI.h"
#include "PixelCaptureBufferFormat.h"

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 8
#include "Slate/SlateViewportProvider.h"
#endif
#include "Framework/Application/SlateApplication.h"
TSharedPtr<FPixelStreamingVideoInputBackBuffer> FPixelStreamingVideoInputBackBuffer::Create()
{
	// this was added to fix packaging
	if (!FSlateApplication::IsInitialized())
	{
		return nullptr;
	}

	TSharedPtr<FPixelStreamingVideoInputBackBuffer> NewInput = TSharedPtr<FPixelStreamingVideoInputBackBuffer>(new FPixelStreamingVideoInputBackBuffer());
	TWeakPtr<FPixelStreamingVideoInputBackBuffer> WeakInput = NewInput;

	// Set up the callback on the game thread since FSlateApplication::Get() can only be used there
	UE::PixelStreaming::DoOnGameThread([WeakInput]() {
		if (TSharedPtr<FPixelStreamingVideoInputBackBuffer> Input = WeakInput.Pin())
		{
			FSlateRenderer* Renderer = FSlateApplication::Get().GetRenderer();
			Input->DelegateHandle = Renderer->OnBackBufferReadyToPresent().AddSP(Input.ToSharedRef(), &FPixelStreamingVideoInputBackBuffer::OnBackBufferReady);
		}
	});

	return NewInput;
}

FPixelStreamingVideoInputBackBuffer::~FPixelStreamingVideoInputBackBuffer()
{
	if (!IsEngineExitRequested())
	{
		UE::PixelStreaming::DoOnGameThread([HandleCopy = DelegateHandle]() {
			FSlateApplication::Get().GetRenderer()->OnBackBufferReadyToPresent().Remove(HandleCopy);
		});
	}
}

#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 8
void FPixelStreamingVideoInputBackBuffer::OnBackBufferReady(SWindow& SlateWindow, ISlateViewportProvider& ViewportProvider)
{
	OnFrame(FPixelCaptureInputFrameRHI(ViewportProvider.GetBackBufferResource()));
}
#elif ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 5
void FPixelStreamingVideoInputBackBuffer::OnBackBufferReady(SWindow& SlateWindow, const FTextureRHIRef& FrameBuffer)
{
	OnFrame(FPixelCaptureInputFrameRHI(FrameBuffer));
}
#else
void FPixelStreamingVideoInputBackBuffer::OnBackBufferReady(SWindow& SlateWindow, const FTexture2DRHIRef& FrameBuffer)
{
	OnFrame(FPixelCaptureInputFrameRHI(FrameBuffer));
}
#endif

FString FPixelStreamingVideoInputBackBuffer::ToString()
{
	return TEXT("the Back Buffer");
}