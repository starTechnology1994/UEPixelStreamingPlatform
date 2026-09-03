// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "Containers/UnrealString.h"
#include "GenericPlatform/GenericWindowDefinition.h"
#include "RHIResources.h"

class SWindow;

namespace UE::EditorPixelStreaming
{
	enum class PIXELSTREAMINGEDITOR_API EStreamTypes : uint8
	{
		LevelEditorViewport = 0,
		Editor = 1,
		VCam UE_DEPRECATED(5.2, "EStreamTypes::VCam has been deprecated. Streaming from VCams should be started from the individual actor") = 2
	};

	FString ToString(EStreamTypes StreamType);
	const TCHAR* ToString(EWindowType Type);
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 5
	const FString HashWindow(SWindow& SlateWindow, const FTextureRHIRef& FrameBuffer);
#else
	const FString HashWindow(SWindow& SlateWindow, const FTexture2DRHIRef& FrameBuffer);
#endif
}