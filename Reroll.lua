ModUtil.RegisterMod("EllosRerollEverythingMod")

local config = {
  NumStartingRerolls = nil,
  BaseRerollCosts = { -- Cost of first reroll, set to -1 to disable reroll
    Hammer = 1, -- Hammers
    Chaos = 1, -- Chaos
    Hermes = 1, -- Hermes
    Boon = 1, -- Boons
    Pom = 1, -- Poms
    Shop = 1, -- Wells of Charon
    SellTrait = 1, -- Purging Pools
    Door = 1, -- Exit Doors
  },
  RerollIncrements = { -- Amount the reroll cost increases after each reroll
    Hammer = 1,
    Chaos = 1,
    Hermes = 1,
    Boon = 1,
    Pom = 1,
    Shop = 1,
    SellTrait = 1,
    Door = 0,
  }
}
EllosRerollEverythingMod.config = config

EllosRerollEverythingMod.LootNameToRerollType = {
  WeaponUpgrade = "Hammer",
  StackUpgrade = "Pom",
  HermesUpgrade = "Hermes",
  TrialUpgrade = "Chaos",
  ZeusUpgrade = "Boon",
  PoseidonUpgrade = "Boon",
  AthenaUpgrade = "Boon",
  AphroditeUpgrade = "Boon",
  AresUpgrade = "Boon",
  ArtemisUpgrade = "Boon",
  DionysusUpgrade = "Boon",
  DemeterUpgrade = "Boon",
  HermesUpgrade = "Boon",
  Store = "Shop",
  SellTraitScript = "SellTrait",
}

-- Helper to force update of the reroll costs
function updateRerollCostsFromConfig()
  ModUtil.MapSetTable(RerollCosts, EllosRerollEverythingMod.config.BaseRerollCosts)
  CurrentRun.CurrentRoom.SpentRerolls = {}
  --RerollCosts = DeepCopyTable(EllosRerollEverythingMod.config.BaseRerollCosts)
end

-- On first load, update the reroll costs
ModUtil.LoadOnce( function()
    updateRerollCostsFromConfig()
end)

-- If custom reroll increments are enabled, update the relevant code
ModUtil.BaseOverride("AttemptPanelReroll", function(screen, button)
	local cost = button.Cost
	if CurrentRun.NumRerolls < cost or cost < 0 then
		CannotRerollPanelPresentation( button )
		return
	end

	AddInputBlock({ Name = "AttemptPanelReroll" })
	HideTopMenuScreenTooltips({ Id = button.Id })
	CurrentRun.NumRerolls = CurrentRun.NumRerolls - cost
	CurrentRun.CurrentRoom.SpentRerolls = CurrentRun.CurrentRoom.SpentRerolls or {}

  ----------------------------------------------------------------------------
  -- EllosRerollEverythingMod edits start here
  ----------------------------------------------------------------------------
  local rerollType = "Boon"
  local lootName = button.RerollId
  if LootObjects[button.RerollId] ~= nil then
    lootName = LootObjects[button.RerollId].Name
  end
  rerollType = EllosRerollEverythingMod.LootNameToRerollType[lootName]

	IncrementTableValue( CurrentRun.CurrentRoom.SpentRerolls, button.RerollId, config.RerollIncrements[rerollType] )

	UpdateRerollUI( CurrentRun.NumRerolls )

	--RandomSynchronize( CurrentRun.NumRerolls )
  RandomSynchronize( math.random(100) ) -- TODO: Make this count up regardless of spent rerolls (in case cost = 0)
	InvalidateCheckpoint()
  ----------------------------------------------------------------------------
  -- EllosRerollEverythingMod edits end here
  ----------------------------------------------------------------------------

	if button.RerollFunctionName and _G[button.RerollFunctionName] then
		RerollPanelPresentation( screen, button )
		_G[button.RerollFunctionName](  )
	end
	RemoveInputBlock({ Name = "AttemptPanelReroll" })
end, EllosRerollEverythingMod)

-- BaseOverride is not ideal here, but it allows us to further break out
-- reroll types and fix an SGG bug that prevents 0 cost rerolls
ModUtil.BaseOverride("CreateBoonLootButtons", function(lootData, reroll)
	local components = ScreenAnchors.ChoiceScreen.Components
	local upgradeName = lootData.Name
	local upgradeChoiceData = LootData[upgradeName]
	local upgradeOptions = lootData.UpgradeOptions
	if upgradeOptions == nil then
		SetTraitsOnLoot( lootData )
		upgradeOptions = lootData.UpgradeOptions
	end

	if not lootData.StackNum then
		lootData.StackNum = 1
	end
	if not reroll then
		lootData.StackNum = lootData.StackNum + GetTotalHeroTraitValue("PomLevelBonus")
	end
	local tooltipData = {}

	local itemLocationY = 370
	local itemLocationX = ScreenCenterX - 355
	local firstOption = true
	local buttonOffsetX = 350

	if IsEmpty( upgradeOptions ) then
		table.insert(upgradeOptions, { ItemName = "FallbackMoneyDrop", Type = "Consumable", Rarity = "Common" })
	end

	local blockedIndexes = {}
	for i = 1, TableLength(upgradeOptions) do
		table.insert( blockedIndexes, i )
	end
	for i = 1, CalcNumLootChoices() do
		RemoveRandomValue( blockedIndexes )
	end

	-- Sort traits in the following order: Melee, Secondary, Rush, Range
	table.sort(upgradeOptions, function (x, y)
		local slotToInt = function( slot )
			if slot ~= nil then
				local slotType = slot.Slot

				if slotType == "Melee" then
					return 0
				elseif slotType == "Secondary" then
					return 1
				elseif slotType == "Ranged" then
					return 2
				elseif slotType == "Rush" then
					return 3
				elseif slotType == "Shout" then
					return 4
				end
			end
			return 99
		end
		return slotToInt(TraitData[x.ItemName]) < slotToInt(TraitData[y.ItemName])
	end)

	if TableLength( upgradeOptions ) > 1 then
		-- Only create the "Choose One" textbox if there's something to choose
		CreateTextBox({ Id = components.ShopBackground.Id, Text = "UpgradeChoiceMenu_SubTitle",
			FontSize = 30,
			OffsetX = -435, OffsetY = -318,
			Color = Color.White,
			Font = "AlegreyaSansSCRegular",
			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
			Justification = "Left"
		})
	end
	for itemIndex, itemData in ipairs( upgradeOptions ) do
		local itemBackingKey = "Backing"..itemIndex
		components[itemBackingKey] = CreateScreenComponent({ Name = "TraitBacking", Group = "Combat_Menu", X = ScreenCenterX, Y = itemLocationY })
		SetScaleY({ Id = components[itemBackingKey].Id, Fraction = 1.25 })
		local upgradeData = nil
		local upgradeTitle = nil
		local upgradeDescription = nil
		if itemData.Type == "Trait" then
			upgradeData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, Rarity = itemData.Rarity })
			local traitNum = GetTraitCount(CurrentRun.Hero, upgradeData)
			if HeroHasTrait(itemData.ItemName) then
				upgradeTitle = "TraitLevel_Upgrade"
				upgradeData.Title = upgradeData.Name
			else
				upgradeTitle = GetTraitTooltipTitle( TraitData[itemData.ItemName] )

				upgradeData.Title = GetTraitTooltipTitle( TraitData[itemData.ItemName] ) .."_Initial"
				if not HasDisplayName({ Text = upgradeData.Title }) then
					upgradeData.Title = GetTraitTooltipTitle( TraitData[itemData.ItemName] )
				end
			end

			if itemData.TraitToReplace ~= nil then
				upgradeData.TraitToReplace = itemData.TraitToReplace
				upgradeData.OldRarity = itemData.OldRarity
				local existingNum = GetTraitNameCount( CurrentRun.Hero, upgradeData.TraitToReplace )
				tooltipData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, FakeStackNum = existingNum, RarityMultiplier = upgradeData.RarityMultiplier})
				if existingNum > 1 then
					upgradeTitle = "TraitLevel_Exchange"
					tooltipData.Title = GetTraitTooltipTitle( TraitData[upgradeData.Name])
					tooltipData.Level = existingNum
				end
			elseif lootData.StackOnly then
				tooltipData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, FakeStackNum = lootData.StackNum, RarityMultiplier = upgradeData.RarityMultiplier})
				tooltipData.OldLevel = traitNum;
				tooltipData.NewLevel = traitNum + lootData.StackNum;
				tooltipData.Title = GetTraitTooltipTitle( TraitData[itemData.ItemName] )
				upgradeData.Title = tooltipData.Title
			else
				if upgradeData.Rarity == "Legendary" then
					if TraitData[upgradeData.Name].IsDuoBoon then
						CreateAnimation({ Name = "BoonEntranceDuo", DestinationId = components[itemBackingKey].Id })
					else
					CreateAnimation({ Name = "BoonEntranceLegendary", DestinationId = components[itemBackingKey].Id })
					end
				end

				tooltipData = upgradeData
			end
			SetTraitTextData( tooltipData )
			upgradeDescription = GetTraitTooltip( tooltipData , { Default = upgradeData.Title })

		elseif itemData.Type == "Consumable" then
			-- TODO(Dexter) Determinism

			upgradeData = GetRampedConsumableData(ConsumableData[itemData.ItemName], itemData.Rarity)
			upgradeTitle = upgradeData.Name
			upgradeDescription = GetTraitTooltip(upgradeData)

			if upgradeData.UseFunctionArgs ~= nil then
				if upgradeData.UseFunctionName ~= nil and upgradeData.UseFunctionArgs.TraitName ~= nil then
					local traitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = upgradeData.UseFunctionArgs.TraitName, Rarity = itemData.Rarity })
					SetTraitTextData( traitData )
					upgradeData.UseFunctionArgs.TraitName = nil
					upgradeData.UseFunctionArgs.TraitData = traitData
					tooltipData = MergeTables( tooltipData, traitData )
				elseif upgradeData.UseFunctionNames ~= nil then
					local hasTraits = false
					for i, args in pairs(upgradeData.UseFunctionArgs) do
						if args.TraitName ~= nil then
							hasTraits = true
							local processedTraitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = args.TraitName, Rarity = itemData.Rarity })
							SetTraitTextData( processedTraitData )
							tooltipData = MergeTables( tooltipData, processedTraitData )
							upgradeData.UseFunctionArgs[i].TraitName = nil
							upgradeData.UseFunctionArgs[i].TraitData = processedTraitData
						end
					end
					if not hasTraits then
						tooltipData = upgradeData
					end
				end
			else
				tooltipData = upgradeData
			end
		elseif itemData.Type == "TransformingTrait" then
			local blessingData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, Rarity = itemData.Rarity })
			local curseData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.SecondaryItemName, Rarity = itemData.Rarity })
			curseData.OnExpire =
			{
				TraitData = blessingData
			}
			upgradeTitle = "ChaosCombo_"..curseData.Name.."_"..blessingData.Name
			blessingData.Title = "ChaosBlessingFormat"

			SetTraitTextData( blessingData )
			SetTraitTextData( curseData )
			blessingData.TrayName = blessingData.Name.."_Tray"

			tooltipData = MergeTables( tooltipData, blessingData )
			tooltipData = MergeTables( tooltipData, curseData )
			tooltipData.Blessing = itemData.ItemName
			tooltipData.Curse = itemData.SecondaryItemName

			upgradeDescription = blessingData.Title
			upgradeData = DeepCopyTable( curseData )
			upgradeData.Icon = blessingData.Icon

			local extractedData = GetExtractData( blessingData )
			for i, value in pairs(extractedData) do
				local key = value.ExtractAs
				if key then
					upgradeData[key] = blessingData[key]
				end
			end
		end

		-- Setting button graphic based on boon type
		local purchaseButtonKey = "PurchaseButton"..itemIndex


		local iconOffsetX = -338
		local iconOffsetY = -2
		local exchangeIconPrefix = nil
		local overlayLayer = "Combat_Menu_Overlay_Backing"

		components[purchaseButtonKey] = CreateScreenComponent({ Name = "BoonSlot"..itemIndex, Group = "Combat_Menu", Scale = 1, X = itemLocationX + buttonOffsetX, Y = itemLocationY })
		if upgradeData.CustomRarityColor then
			components[purchaseButtonKey.."Patch"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX + 38, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Patch"].Id, Name = "BoonRarityPatch"})
			SetColor({ Id = components[purchaseButtonKey.."Patch"].Id, Color = upgradeData.CustomRarityColor })
		elseif itemData.Rarity ~= "Common" then
			components[purchaseButtonKey.."Patch"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX + 38, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Patch"].Id, Name = "BoonRarityPatch"})
			SetColor({ Id = components[purchaseButtonKey.."Patch"].Id, Color = Color["BoonPatch" .. itemData.Rarity] })
		end

		if Contains( blockedIndexes, itemIndex ) then
			itemData.Blocked = true
			overlayLayer = "Combat_Menu"
			UseableOff({ Id = components[purchaseButtonKey].Id })
			ModifyTextBox({ Ids = components[purchaseButtonKey].Id, BlockTooltip = true })
			CreateTextBox({ Id = components[purchaseButtonKey].Id,
			Text = "ReducedLootChoicesKeyword",
			OffsetX = textOffset, OffsetY = -30,
			Color = Color.Transparent,
			Width = 675,
			})
			thread( TraitLockedPresentation, { Components = components, Id = purchaseButtonKey, OffsetX = itemLocationX + buttonOffsetX, OffsetY = iconOffsetY + itemLocationY } )
		end

		if upgradeData.Icon ~= nil then
			components[purchaseButtonKey.."Icon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Icon"].Id, Name = upgradeData.Icon .. "_Large" })
			SetScale({ Id = components[purchaseButtonKey.."Icon"].Id, Fraction = 0.85 })
		end

		if upgradeData.TraitToReplace ~= nil then
			local yOffset = 70
			local xOffset = 700
			local blockedIconOffset = 0
			local textOffset = xOffset * -1 + 110
			if Contains( blockedIndexes, itemIndex ) then
				blockedIconOffset = -20
			end

			components[purchaseButtonKey.."ExchangeIcon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = overlayLayer, X = iconOffsetX + itemLocationX + buttonOffsetX + xOffset, Y = iconOffsetY + itemLocationY + yOffset + blockedIconOffset})
			SetAnimation({ DestinationId = components[purchaseButtonKey.."ExchangeIcon"].Id, Name = TraitData[upgradeData.TraitToReplace].Icon .. "_Small" })

			components[purchaseButtonKey.."ExchangeIconFrame"] = CreateScreenComponent({ Name = "BlankObstacle", Group = overlayLayer, X = iconOffsetX + itemLocationX + buttonOffsetX + xOffset, Y = iconOffsetY + itemLocationY + yOffset + blockedIconOffset})
			SetAnimation({ DestinationId = components[purchaseButtonKey.."ExchangeIconFrame"].Id, Name = "BoonIcon_Frame_".. itemData.OldRarity})

			exchangeIconPrefix = "{!Icons.TraitExchange} "

			CreateTextBox(MergeTables({
				Id = components[purchaseButtonKey.."ExchangeIcon"].Id,
				Text = "ReplaceTraitPrefix",
				OffsetX = textOffset,
				OffsetY = -12 - blockedIconOffset + (LocalizationData.UpgradeChoice.ExchangeText.LangOffsetY[GetLanguage({})] or 0),
				FontSize = 20,
				Color = {160, 160, 160, 255},
				Width = 675,
				Font = "AlegreyaSansSCRegular",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				VerticalJustification = "Top",
			}, LocalizationData.UpgradeChoice.ExchangeText))

			CreateTextBox(MergeTables({
				Id = components[purchaseButtonKey.."ExchangeIcon"].Id,
				Text = GetTraitTooltipTitle( TraitData[itemData.TraitToReplace ]),
				OffsetX = textOffset + 150,
				OffsetY = -12 - blockedIconOffset + (LocalizationData.UpgradeChoice.ExchangeText.LangOffsetY[GetLanguage({})] or 0),
				FontSize = 20,
				Color = Color["BoonPatch" .. itemData.OldRarity],
				Width = 675,
				Font = "AlegreyaSansSCRegular",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				VerticalJustification = "Top",
			}, LocalizationData.UpgradeChoice.ExchangeText))

		end

		components[purchaseButtonKey.."Frame"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX, Y = iconOffsetY + itemLocationY })
		if upgradeData.Frame then
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Frame"].Id, Name = "Frame_Boon_Menu_".. upgradeData.Frame})
			SetScale({ Id = components[purchaseButtonKey.."Frame"].Id, Fraction = 0.85 })
		else
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Frame"].Id, Name = "Frame_Boon_Menu_".. itemData.Rarity})
			SetScale({ Id = components[purchaseButtonKey.."Frame"].Id, Fraction = 0.85 })
		end
		-- Button data setup
		components[purchaseButtonKey].OnPressedFunctionName = "HandleUpgradeChoiceSelection"
		components[purchaseButtonKey].Data = upgradeData
		components[purchaseButtonKey].UpgradeName = upgradeName
		components[purchaseButtonKey].Type = itemData.Type
		components[purchaseButtonKey].LootData = lootData
		components[purchaseButtonKey].LootColor = upgradeChoiceData.LootColor
		components[purchaseButtonKey].BoonGetColor = upgradeChoiceData.BoonGetColor

		components[components[purchaseButtonKey].Id] = purchaseButtonKey
		-- Creates upgrade slot text
		SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = 675 })
		local selectionString = "UpgradeChoiceMenu_PermanentItem"
		local selectionStringColor = Color.Black

		if itemData.Type == "Trait" then
			local traitData = TraitData[itemData.ItemName]
			if traitData.Slot ~= nil then
				selectionString = "UpgradeChoiceMenu_"..traitData.Slot
			end
		elseif itemData.Type == "Consumable" then
			selectionString = upgradeData.UpgradeChoiceText or "UpgradeChoiceMenu_PermanentItem"
		end

		local textOffset = 115 - buttonOffsetX
		local exchangeIconOffset = 0
		local lineSpacing = 8
		local text = "Boon_"..tostring(itemData.Rarity)
		local overlayLayer = ""
		if upgradeData.CustomRarityName then
			text = upgradeData.CustomRarityName
		end
		local color = Color["BoonPatch" .. itemData.Rarity ]
		if upgradeData.CustomRarityColor then
			color = upgradeData.CustomRarityColor
		end

		CreateTextBox({ Id = components[purchaseButtonKey].Id, Text = text  ,
			FontSize = 27,
			OffsetX = textOffset + 630, OffsetY = -60,
			Width = 720,
			Color = color,
			Font = "AlegreyaSansSCLight",
			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
			Justification = "Right"
		})
		if exchangeIconPrefix then
			CreateTextBox({ Id = components[purchaseButtonKey].Id,
				Text = exchangeIconPrefix ,
				FontSize = 27,
				OffsetX = textOffset, OffsetY = -55,
				Color = color,
				Font = "AlegreyaSansSCLight",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				LuaKey = "TooltipData", LuaValue = tooltipData,
			})
			exchangeIconOffset = 40
			if upgradeData.Slot == "Shout" then
				lineSpacing = 4
			end
		end
		CreateTextBox({ Id = components[purchaseButtonKey].Id,
			Text = upgradeTitle,
			FontSize = 27,
			OffsetX = textOffset + exchangeIconOffset, OffsetY = -55,
			Color = color,
			Font = "AlegreyaSansSCLight",
			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
			Justification = "Left",
			LuaKey = "TooltipData", LuaValue = tooltipData,
		})

		-- Chaos curse/blessing traits need VariableAutoFormat disabled
		local autoFormat = "BoldFormatGraft"
		if upgradeDescription == "ChaosBlessingFormat" or itemData.Type == "TransformingTrait" then
			autoFormat = nil
		end

		CreateTextBoxWithFormat(MergeTables({ Id = components[purchaseButtonKey].Id,
			Text = upgradeDescription,
			OffsetX = textOffset, OffsetY = -30,
			Width = 675,
			Justification = "Left",
			VerticalJustification = "Top",
			LineSpacingBottom = lineSpacing,
			UseDescription = true,
			LuaKey = "TooltipData", LuaValue = tooltipData,
			Format = "BaseFormat",
			VariableAutoFormat = autoFormat,
			TextSymbolScale = 0.8,
		}, LocalizationData.UpgradeChoice.BoonLootButton))

		local needsQuestIcon = false
		if not GameState.TraitsTaken[upgradeData.Name] and HasActiveQuestForTrait( upgradeData.Name ) then
			needsQuestIcon = true
		elseif itemData.ItemName ~= nil and not GameState.TraitsTaken[itemData.ItemName] and HasActiveQuestForTrait( itemData.ItemName ) then
			needsQuestIcon = true
		end

		if needsQuestIcon then
			components[purchaseButtonKey.."QuestIcon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX + 92, Y = itemLocationY - 55 })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."QuestIcon"].Id, Name = "QuestItemFound" })
			-- Silent toolip
			CreateTextBox({ Id = components[purchaseButtonKey].Id, TextSymbolScale = 0, Text = "TraitQuestItem", Color = Color.Transparent, LuaKey = "TooltipData", LuaValue = tooltipData, })
		end

		if upgradeData.LimitedTime then
			-- Silent toolip
			CreateTextBox({ Id = components[purchaseButtonKey].Id, TextSymbolScale = 0, Text = "SeasonalItem", Color = Color.Transparent, LuaKey = "TooltipData", LuaValue = tooltipData, })
		end

		if firstOption then
			TeleportCursor({ OffsetX = itemLocationX + buttonOffsetX, OffsetY = itemLocationY, ForceUseCheck = true, })
			firstOption = false
		end

		itemLocationY = itemLocationY + 220
	end



	if IsMetaUpgradeSelected( "RerollPanelMetaUpgrade" ) then
		local cost = -1

    ----------------------------------------------------------------------------
    -- EllosRerollEverythingMod edits start here
    ----------------------------------------------------------------------------
		if lootData.BlockReroll == true then
			cost = -1
		else
      local rerollType = EllosRerollEverythingMod.LootNameToRerollType[lootData.Name] or "Boon"
			cost = RerollCosts[rerollType]
		end
		local baseCost = cost

		local name = "RerollPanelMetaUpgrade_ShortTotal"
		local tooltip = "MetaUpgradeRerollHint"
		if cost >= 0 then

			local increment = 0
			if CurrentRun.CurrentRoom.SpentRerolls then
				increment = CurrentRun.CurrentRoom.SpentRerolls[lootData.ObjectId] or 0
			end
			cost = cost + increment
		else
			name = "RerollPanel_Blocked"
			tooltip = "MetaUpgradeRerollBlockedHint"
		end
		local color = Color.White
		if CurrentRun.NumRerolls < cost or cost < 0 then
			color = Color.CostUnaffordable
		end

		if baseCost >= 0 then
			components["RerollPanel"] = CreateScreenComponent({ Name = "ShopRerollButton", Scale = 1.0, Group = "Combat_Menu" })
			Attach({ Id = components["RerollPanel"].Id, DestinationId = components.ShopBackground.Id, OffsetX = 0, OffsetY = 410 })
			components["RerollPanel"].OnPressedFunctionName = "AttemptPanelReroll"
			components["RerollPanel"].RerollFunctionName = "RerollBoonLoot"
			components["RerollPanel"].RerollColor = lootData.LootColor
			components["RerollPanel"].RerollId = lootData.ObjectId

			components["RerollPanel"].Cost = cost

			CreateTextBox({ Id = components["RerollPanel"].Id, Text = name, OffsetX = 28, OffsetY = -5,
			ShadowColor = {0,0,0,1}, ShadowOffset={0,3}, OutlineThickness = 3, OutlineColor = {0,0,0,1},
			FontSize = 28, Color = color, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
			SetInteractProperty({ DestinationId = components["RerollPanel"].Id, Property = "TooltipOffsetX", Value = 350 })
			CreateTextBox({ Id = components["RerollPanel"].Id, Text = tooltip, FontSize = 1, Color = Color.Transparent, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
		end
	end
  ----------------------------------------------------------------------------
  -- EllosRerollEverythingMod edits end here
  ----------------------------------------------------------------------------
end, EllosRerollEverythingMod)

-- Door Reroll check
ModUtil.BaseOverride("AttemptReroll", function(run, target)
	if target == nil or not target.CanBeRerolled then
		return
	end

	local rerollFunction = _G[target.RerollFunctionName]
	if rerollFunction == nil then
		return
	end

  local cost = RerollCosts.Door
  CurrentRun.CurrentRoom.SpentRerolls = CurrentRun.CurrentRoom.SpentRerolls or {}

  local increment = 0
  if CurrentRun.CurrentRoom.SpentRerolls then
    increment = CurrentRun.CurrentRoom.SpentRerolls["DoorSpentRerolls"] or 0
  end
  cost = cost + increment

  -- TODO: Handle the not enough rerolls case customly
  if run.NumRerolls < cost or cost < 0 then
    return
  end

	run.NumRerolls = run.NumRerolls - cost
  IncrementTableValue( CurrentRun.CurrentRoom.SpentRerolls, "DoorSpentRerolls", config.RerollIncrements.Door )
	UpdateRerollUI( run.NumRerolls )

	-- RandomSynchronize( run.NumRerolls )
  RandomSynchronize( math.random(100) )

	AddInputBlock({ Name = "AttemptReroll" })
	PreRerollPresentation( run, target )
	rerollFunction( run, target )
	PostRerollPresentation( run, target )

	InvalidateCheckpoint()

	RemoveInputBlock({ Name = "AttemptReroll" })
end, EllosRerollEverythingMod)

-- Wells of Charon
ModUtil.BaseOverride("CreateStoreButtons", function()

	local itemLocationStartY = ShopUI.ShopItemStartY
	local itemLocationYSpacer = ShopUI.ShopItemSpacerY
	local itemLocationMaxY = itemLocationStartY + 4 * itemLocationYSpacer

	local itemLocationStartX = ShopUI.ShopItemStartX
	local itemLocationXSpacer = ShopUI.ShopItemSpacerX
	local itemLocationMaxX = itemLocationStartX + 1 * itemLocationXSpacer

	local itemLocationTextBoxOffset = 380

	local itemLocationX = itemLocationStartX
	local itemLocationY = itemLocationStartY

	local components = CurrentRun.CurrentRoom.Store.Screen.Components

	local numButtons = StoreData.WorldShop.MaxOffers
	if numButtons == nil then
		numButtons = 0
		for i, groupData in pairs( StoreData.WorldShop.GroupsOf ) do
			numButtons = numButtons + groupData.Offers
		end
	end

	local firstUseable = false
	for itemIndex = 1, numButtons do
		local upgradeData = CurrentRun.CurrentRoom.Store.StoreOptions[itemIndex]

		local itemBackingSoldOutKey = "ItemBackingSoldOut"..itemIndex
		components[itemBackingSoldOutKey] = CreateScreenComponent({ Name = "BoonSlotInactive"..itemIndex, Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })

		if upgradeData ~= nil then
			if not upgradeData.Processed then
				if upgradeData.Type == "Trait" then
					upgradeData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = upgradeData.Name })
					if upgradeData.CostIncreasePerStack ~= nil then
						upgradeData.Cost = upgradeData.Cost + GetTraitCount(CurrentRun.Hero, upgradeData) * upgradeData.CostIncreasePerStack
					end
					upgradeData.Type = "Trait"
					SetTraitTextData( upgradeData )
				elseif upgradeData.Type == "Consumable" then
					upgradeData = GetRampedConsumableData( ConsumableData[upgradeData.Name] )
					upgradeData.Type = "Consumable"
				elseif upgradeData.Type == "Cosmetic" then
					upgradeData = DeepCopyTable( ConditionalItemData[upgradeData.Name] )
					upgradeData.Type = "Cosmetic"
				end

				local costMultiplier = 1 + ( GetNumMetaUpgrades( "ShopPricesShrineUpgrade" ) * ( MetaUpgradeData.ShopPricesShrineUpgrade.ChangeValue - 1 ) )
				costMultiplier = costMultiplier * GetTotalHeroTraitValue("StoreCostMultiplier", {IsMultiplier = true})
				if costMultiplier ~= 1 then
					upgradeData.Cost = round( upgradeData.Cost * costMultiplier )
				end

				upgradeData.Processed = true
			elseif upgradeData.Type == "Trait" then
				RecalculateStoreTraitDurations( upgradeData )
			end

			CurrentRun.CurrentRoom.Store.StoreOptions[itemIndex] = upgradeData
			local tooltipData = upgradeData


			local purchaseButtonKey = "PurchaseButton"..itemIndex
			components[purchaseButtonKey] = CreateScreenComponent({ Name = "BoonSlot"..itemIndex, Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = 665 })
			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "FreeFormSelectOffsetX", Value = -200 })

			if upgradeData.Icon ~= nil then
				local iconKey = "Icon"..itemIndex
				components[iconKey] = CreateScreenComponent({ Name = "BlankObstacle", X = itemLocationX - 343, Y = itemLocationY, Group = "Combat_Menu" })
				SetAnimation({ DestinationId = components[iconKey].Id , Name = upgradeData.Icon.."_Large" })
			end

			local itemBackingKey = "Backing"..itemIndex
			components[itemBackingKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX + itemLocationTextBoxOffset, Y = itemLocationY })

			local purchaseButtonTitleKey = "PurchaseButtonTitle"..itemIndex
			components[purchaseButtonTitleKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			CreateTextBoxWithFormat(MergeTables({ Id = components[purchaseButtonKey].Id,
				Text = GetTraitTooltip( upgradeData ),
				OffsetX = -245,
				OffsetY = -23,
				Format = "BaseFormat",
				UseDescription = true,
				VariableAutoFormat = "BoldFormatGraft",
				LuaKey = "TooltipData",
				LuaValue = tooltipData,
				Justification = "Left",
				VerticalJustification = "Top",
				LineSpacingBottom = 8,
				Width = "665" },LocalizationData.SellTraitScripts.ShopButton))


			local costString = "@GUI\\Icons\\Currency_Small"
			costString = upgradeData.Cost .. " " .. costString
			local costColor = Color.CostAffordableShop
			if CurrentRun.Money ~= nil and CurrentRun.Money < upgradeData.Cost then
				costColor = Color.CostUnaffordable
			end

			if upgradeData.HealthCost then
				costString = upgradeData.HealthCost .. " @GUI\\Icons\\Life_Small"
				if CurrentRun.Hero.Health > upgradeData.HealthCost then
					costColor = Color.CostAffordableShop
				else
					costColor = Color.CostUnaffordable
				end
			end

			local needsQuestIcon = false
			if upgradeData.Type == "Trait" then
				if not GameState.TraitsTaken[upgradeData.Name] and HasActiveQuestForTrait( upgradeData.Name ) then
					needsQuestIcon = true
				end
			elseif upgradeData.Type == "Consumable" then
				if not GameState.ItemInteractions[upgradeData.Name] and HasActiveQuestForItem( upgradeData.Name ) then
					needsQuestIcon = true
				end
			end
			if needsQuestIcon then
				components[purchaseButtonKey.."QuestIcon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX + 112, Y = itemLocationY - 55 })
				SetAnimation({ DestinationId = components[purchaseButtonKey.."QuestIcon"].Id, Name = "QuestItemFound" })
				-- Silent toolip
				CreateTextBox({ Id = components[purchaseButtonKey].Id, TextSymbolScale = 0, Text = "TraitQuestItem", Color = Color.Transparent, LuaKey = "TooltipData", LuaValue = tooltipData, })
			end

			components[purchaseButtonKey].OnPressedFunctionName = "HandleStorePurchase"
			if not firstUseable then
				TeleportCursor({ OffsetX = itemLocationX, OffsetY = itemLocationY, ForceUseCheck = true })
				firstUseable = true
			end

			CreateTextBox(MergeTables({ Id = components[purchaseButtonTitleKey].Id, Text = costString, OffsetX = 410, OffsetY = -50, FontSize = 28, Color = costColor, Font = "AlegreyaSansSCRegular", Justification = "Right" },LocalizationData.SellTraitScripts.ShopButton))

			CreateTextBox(MergeTables({ Id = components[purchaseButtonTitleKey].Id, Text = upgradeData.Name,
				FontSize = 25,
				OffsetX = -245, OffsetY = -50,
				Width = 720,
				Color = costColor,
				Font = "AlegreyaSansSCBold",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
			},LocalizationData.SellTraitScripts.ShopButton))

			components[purchaseButtonKey].Data = upgradeData
			components[purchaseButtonKey].WeaponName = currentWeapon
			components[purchaseButtonKey].Index = itemIndex
			components[purchaseButtonKey].TitleId = components[purchaseButtonTitleKey].Id

			if CurrentRun.CurrentRoom.Store.Buttons == nil then
				CurrentRun.CurrentRoom.Store.Buttons = {}
			end
			table.insert(CurrentRun.CurrentRoom.Store.Buttons, components[purchaseButtonKey])
		end
		itemLocationX = itemLocationX + itemLocationXSpacer
		if itemLocationX >= itemLocationMaxX then
			itemLocationX = itemLocationStartX
			itemLocationY = itemLocationY + itemLocationYSpacer
		end
	end

	if IsMetaUpgradeSelected("RerollPanelMetaUpgrade") then
		local increment = 0
    local cost = RerollCosts.Shop

    if CurrentRun.CurrentRoom.SpentRerolls then
      increment = CurrentRun.CurrentRoom.SpentRerolls[CurrentRun.CurrentRoom.Store.Screen.Name] or 0
    end
    cost = cost + increment

		local color = Color.White
		if CurrentRun.NumRerolls < cost or cost < 0 then
			color = Color.CostUnaffordable
		end

		if cost >= 0 then
			components["RerollPanel"] = CreateScreenComponent({ Name = "ShopRerollButton", Scale = 1.0, Group = "Combat_Menu" })
			Attach({ Id = components["RerollPanel"].Id, DestinationId = components.ShopBackground.Id, OffsetX = -200, OffsetY = 440 })
			components["RerollPanel"].OnPressedFunctionName = "AttemptPanelReroll"
			components["RerollPanel"].RerollFunctionName = "RerollStore"
			components["RerollPanel"].Cost = cost
			components["RerollPanel"].RerollColor = {48, 25, 83, 255}
			components["RerollPanel"].RerollId = CurrentRun.CurrentRoom.Store.Screen.Name
			CreateTextBox({ Id = components["RerollPanel"].Id, Text = "RerollPanelMetaUpgrade_ShortTotal", OffsetX = 28, OffsetY = -5,
			ShadowColor = {0,0,0,1}, ShadowOffset={0,3}, OutlineThickness = 3, OutlineColor = {0,0,0,1},
			FontSize = 28, Color = color, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
			SetInteractProperty({ DestinationId = components["RerollPanel"].Id, Property = "TooltipOffsetX", Value = 850 })
			CreateTextBox({ Id = components["RerollPanel"].Id, Text = "MetaUpgradeRerollHint", FontSize = 1, Color = Color.Transparent, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
		end
	end
end, EllosRerollEverythingMod)

-- Add our special use data to all use text data.  Only door rerolls will actually use it
ModUtil.WrapBaseFunction("GetUseData", function ( baseFunc, useTarget )
  local useData = baseFunc(useTarget)
  local cost = (RerollCosts.Door or 0) + (ModUtil.PathGet("CurrentRun.CurrentRoom.SpentRerolls.DoorSpentRerolls") or 0)
  useData = MergeTables(useData, {EllosRerollEverythingModDoorRerollCost = tostring(cost)})
  return useData
end, EllosRerollEverythingMod)

-- Set starting number of rerolls if it has been specified
ModUtil.WrapBaseFunction("StartNewRun", function ( baseFunc, currentRun )
  local run = baseFunc(currentRun)
  if config.NumStartingRerolls then
    run.NumRerolls = config.NumStartingRerolls
  end
  return run
end, EllosRerollEverythingMod)

-- Enable both fated persuation and authority
ModUtil.WrapBaseFunction("IsMetaUpgradeSelected", function ( baseFunc, metaUpgrade )
  if metaUpgrade == "RerollMetaUpgrade" or metaUpgrade == "RerollPanelMetaUpgrade" then
    return true
  end
  return baseFunc(metaUpgrade)
end, EllosRerollEverythingMod)
