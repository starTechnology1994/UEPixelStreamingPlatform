// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"

// FPixelStreamingVideoInputPIEViewport only exists in UE 5.3+, it was not present in UE 5.2.
#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 3

#include "PixelStreamingVideoInputRHI.h"

class FViewport;

/*
 * An extension of the back buffer input that can handle PIE sessions. Primarily to be used in blueprints
 */
class PIXELSTREAMING_API FPixelStreamingVideoInputPIEViewport : public FPixelStreamingVideoInputRHI
{
public:
	static TSharedPtr<FPixelStreamingVideoInputPIEViewport> Create();
	virtual ~FPixelStreamingVideoInputPIEViewport();

	virtual FString ToString() override;

private:
	FPixelStreamingVideoInputPIEViewport() = default;

	void OnViewportRendered(FViewport* InViewport);

	FDelegateHandle DelegateHandle;
};

#endif // UE 5.3+
