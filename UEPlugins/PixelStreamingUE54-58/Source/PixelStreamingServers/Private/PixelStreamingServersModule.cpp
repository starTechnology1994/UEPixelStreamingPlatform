// Copyright Epic Games, Inc. All Rights Reserved.

#include "PixelStreamingServersModule.h"

FPixelStreamingServersModule& FPixelStreamingServersModule::Get()
{
	return FModuleManager::LoadModuleChecked<FPixelStreamingServersModule>("PixelStreamingServers");
}

void FPixelStreamingServersModule::StartupModule()
{
	// Any startup logic require goes here.
}

IMPLEMENT_MODULE(FPixelStreamingServersModule, PixelStreamingServers)
