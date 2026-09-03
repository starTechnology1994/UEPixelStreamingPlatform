// Copyright Epic Games, Inc. All Rights Reserved.

using System;
using System.IO;
using System.Collections.Generic;
using EpicGames.Core;

namespace UnrealBuildTool.Rules
{
	public class PixelStreamingBlueprintEditor : ModuleRules
	{
		public PixelStreamingBlueprintEditor(ReadOnlyTargetRules Target) : base(Target)
		{
#if UE_5_8_OR_LATER
			bRequiresPlatformSDK = true;
#endif
			
			var EngineDir = Path.GetFullPath(Target.RelativeEnginePath);

			PublicIncludePaths.AddRange(
				new string[] {
				});

			PrivateIncludePaths.AddRange(
				new string[] {
				});

			PublicDependencyModuleNames.AddRange(
				new string[] {
				});

			PrivateDependencyModuleNames.AddRange(
				new string[] {
					"AssetDefinition",
					"Core",
					"CoreUObject",
					"SlateCore",
					"PixelStreaming",
					"PixelStreamingBlueprint",
					"PixelStreamingEditor",
					"UnrealEd"
				});
		}
	}
}
