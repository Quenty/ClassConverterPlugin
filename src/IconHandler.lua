local ICON_SHEET = 'rbxassetid://129293660'

-- Credit: Stravant
-- luacheck: ignore

---- IconMap ----
-- Image size: 256px x 256px
-- Icon size: 16px x 16px
-- Padding between each icon: 2px
-- Padding around image edge: 1px
-- Total icons: 14 x 14 (196)
local ICON_INDEX = {
	['Accoutrement'] = 32; ['Animation'] = 60; ['AnimationTrack'] = 60; ['ArcHandles'] = 56; ['Backpack'] = 20; ['BillboardGui'] = 64; ['BindableEvent'] = 67;
	['BindableFunction'] = 66; ['BlockMesh'] = 8; ['BodyAngularVelocity'] = 14; ['BodyForce'] = 14; ['BodyGyro'] = 14; ['BodyPosition'] = 14; ['BodyThrust'] = 14;
	['BodyVelocity'] = 14; ['BoolValue'] = 4; ['BrickColorValue'] = 4; ['Camera'] = 5; ['CFrameValue'] = 4; ['CharacterMesh'] = 60; ['ClickDetector'] = 41; ['Color3Value'] = 4;
	['Configuration'] = 58; ['CoreGui'] = 46; ['CornerWedgePart'] = 1; ['CustomEvent'] = 4; ['CustomEventReceiver'] = 4; ['CylinderMesh'] = 8; ['Debris'] = 30; ['Decal'] = 7;
	['Dialog'] = 62; ['DialogChoice'] = 63; ['DoubleConstrainedValue'] = 4; ['Explosion'] = 36; ['Fire'] = 61; ['Flag'] = 38; ['FlagStand'] = 39; ['FloorWire'] = 4;
	['ForceField'] = 37; ['Frame'] = 48; ['GuiButton'] = 52; ['GuiMain'] = 47; ['Handles'] = 53; ['Hat'] = 45; ['Hint'] = 33; ['HopperBin'] = 22; ['Humanoid'] = 9;
	['ImageButton'] = 52; ['ImageLabel'] = 49; ['IntConstrainedValue'] = 4; ['IntValue'] = 4; ['JointInstance'] = 34; ['Keyframe'] = 60; ['Lighting'] = 13; ['LocalScript'] = 18;
	['MarketplaceService'] = 46; ['Message'] = 33; ['Model'] = 2; ['NetworkClient'] = 16; ['NetworkReplicator'] = 29; ['NetworkServer'] = 15; ['NumberValue'] = 4;
	['ObjectValue'] = 4; ['Pants'] = 44; ['ParallelRampPart'] = 1; ['Part'] = 1; ['PartPairLasso'] = 57; ['Platform'] = 35; ['Player'] = 12; ['PlayerGui'] = 46; ['Players'] = 21;
	['PointLight'] = 13; ['Pose'] = 60; ['PrismPart'] = 1; ['PyramidPart'] = 1; ['RayValue'] = 4; ['ReplicatedStorage'] = 0; ['RightAngleRampPart'] = 1; ['RocketPropulsion'] = 14;
	['ScreenGui'] = 47; ['Script'] = 6; ['Seat'] = 35; ['SelectionBox'] = 54; ['SelectionPartLasso'] = 57; ['SelectionPointLasso'] = 57; ['ServerScriptService'] = 0;
	['ServerStorage'] = 0; ['Shirt'] = 43; ['ShirtGraphic'] = 40; ['SkateboardPlatform'] = 35; ['Sky'] = 28; ['Smoke'] = 59; ['Sound'] = 11; ['SoundService'] = 31; ['Sparkles'] = 42;
	['SpawnLocation'] = 25; ['SpecialMesh'] = 8; ['SpotLight'] = 13; ['StarterGear'] = 20; ['StarterGui'] = 46; ['StarterPack'] = 20; ['Status'] = 2; ['StringValue'] = 4;
	['SurfaceSelection'] = 55; ['Team'] = 24; ['Teams'] = 23; ['Terrain'] = 65; ['TestService'] = 68; ['TextBox'] = 51; ['TextButton'] = 51; ['TextLabel'] = 50; ['Texture'] = 10;
	['TextureTrail'] = 4; ['Tool'] = 17; ['TouchTransmitter'] = 37; ['TrussPart'] = 1; ['Vector3Value'] = 4; ['VehicleSeat'] = 35; ['WedgePart'] = 1; ['Weld'] = 34; ['Workspace'] = 19;
}
local Icon do
	game:GetService('ContentProvider'):Preload(ICON_SHEET)
	local iconDehash do
		-- 14 x 14, 0-based input, 0-based output
		local f = math.floor
		function iconDehash(h)
			return f(h/14 % 14), f(h % 14)
		end
	end
	function Icon(_, className)
		local Index = ICON_INDEX[className] or 0
		local row, col = iconDehash(Index)
		local pad, border = 2, 1
		local iconSize = 16
		--
		--local imageLabel = Instance.new('ImageLabel')
		--imageLabel.Size = UDim2.new(0, iconSize, 0, iconSize)
		--imageLabel.BorderSizePixel = 0
		--imageLabel.BackgroundTransparency = 1
		--imageLabel.Image = ICON_SHEET
		--imageLabel.ImageRectSize = Vector2.new(iconSize, iconSize)
		--imageLabel.ImageRectOffset = Vector2.new(border + col*iconSize + pad*(col+1), border + row*iconSize + pad*(row+1))
		--
		--return imageLabel
		return
		{
			Image = ICON_SHEET;
			ImageRectSize = Vector2.new(iconSize, iconSize);
			ImageRectOffset = Vector2.new(border + col*iconSize + pad*(col+1), border + row*iconSize + pad*(row+1));
		}
	end
end

return {
	GetIcon = Icon;
	HasIcon = function(self, ClassName)
		return ICON_INDEX[ClassName]
	end;
}
