-- Map of reroll type to display name in the in-game UI
EllosRerollEverythingMod.RerollTypeToInGameName = {
  Hammer = "Daedalus Hammers",
  Chaos = "Chaos Boons",
  Hermes = "Hermes Boons",
  Boon = "Other God Boons",
  Pom = "Poms of Power",
  Shop = "Wells of Charon",
  SellTrait = "Purging Pools",
  Door = "Room Rewards"
}

-- Order to show the reroll types in the UI
EllosRerollEverythingMod.RerollTypeOrdering = {
  Hammer = 1,
  Chaos = 2,
  Hermes = 3,
  Boon = 4,
  Pom = 5,
  Shop = 6,
  SellTrait = 7,
  Door = 8,
}
RerollSettingsMenu = {}

-- Function to iterate through the reroll types in the order specified by EllosRerollEverythingMod.RerollTypeOrdering
function IterateSortedByRerollType(t)
  local i = {}
  for k in next, t do
    table.insert(i, k)
  end
  table.sort(i, function(key1, key2)
    return EllosRerollEverythingMod.RerollTypeOrdering[key1] > EllosRerollEverythingMod.RerollTypeOrdering[key2]
  end)
  return function()
    local k = table.remove(i)
    if k ~= nil then
      return k, t[k]
    end
  end
end

ModUtil.WrapBaseFunction("CreatePrimaryBacking", function ( baseFunc )
  if not IsScreenOpen( "RunClear" ) then
    local components = ScreenAnchors.TraitTrayScreen.Components
    components.RerollConfigButton = CreateScreenComponent({ Name = "ButtonDefault", Scale = 1.0, Group = "Combat_Menu_TraitTray", X = CombatUI.TraitUIStart + 105 + 300, Y = 930 })
    components.RerollConfigButton.OnPressedFunctionName = "OpenRerollSettingsScreen"
    CreateTextBox({ Id = components.RerollConfigButton.Id,
        Text = "Reroll Options",
        FontSize = 22,
        Color = Color.White,
        Font = "AlegreyaSansSCRegular",
        ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
        Justification = "Center",
        DataProperties =
        {
          OpacityWithOwner = true,
        },
      })
  end
  baseFunc()
end, EllosRerollEverythingMod)

function ModifyNumRerolls(screen, button)
  local numRerolls = ((EllosRerollEverythingMod.config.NumStartingRerolls or CurrentRun.NumRerolls) or 0)
  numRerolls = numRerolls + button.ModifyAmount
  numRerolls = math.max(numRerolls, 0)
  EllosRerollEverythingMod.config.NumStartingRerolls = numRerolls

  ModifyTextBox({ Id = button.TextLabelId, Text = tostring(numRerolls) })
  UpdateRerollUI( EllosRerollEverythingMod.config.NumStartingRerolls )
end

-- Update the BaseRerollCost for a reroll type
function ModifyRerollConfig(screen, button)
  local configToUpdate = EllosRerollEverythingMod.config[button.ConfigToUpdate]
  local baseRerollCostForType = configToUpdate[button.RerollType]

  -- Apply config modification
  baseRerollCostForType = baseRerollCostForType + button.ModifyAmount

  -- Clamp it to a minimum of -1 or 0 depending
  configToUpdate[button.RerollType] = math.max(baseRerollCostForType, -1)
  if button.ConfigToUpdate == "RerollIncrements" then
    configToUpdate[button.RerollType] = math.max(baseRerollCostForType, 0)
  end

  -- Update the text box
  ModifyTextBox({ Id = button.TextLabelId, Text = configToUpdate[button.RerollType] })

  -- If we are at the minimum, change the text to disabled
  if configToUpdate[button.RerollType] == -1 then
    ModifyTextBox({ Id = button.TextLabelId, ColorTarget = Color.MetaUpgradePointsInvalid, Text = "Disabled" })
  else
    ModifyTextBox({ Id = button.TextLabelId, ColorTarget = Color.White })
  end
end

function MakeAllRerollsFree(screen, button)
  for key, value in pairs(EllosRerollEverythingMod.config.BaseRerollCosts) do
    EllosRerollEverythingMod.config.BaseRerollCosts[key] = 0
  end
  for key, value in pairs(EllosRerollEverythingMod.config.RerollIncrements) do
    EllosRerollEverythingMod.config.RerollIncrements[key] = 0
  end

  updateRerollConfigTextBoxes(screen)
end

function DisableRerolls(screen, button)
  for key, value in pairs(EllosRerollEverythingMod.config.BaseRerollCosts) do
    EllosRerollEverythingMod.config.BaseRerollCosts[key] = -1
  end

  updateRerollConfigTextBoxes(screen)
end

function ResetRerollConfigToDefault(screen, button)
  EllosRerollEverythingMod.config = {
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

  updateRerollConfigTextBoxes(screen)
end

function updateRerollConfigTextBoxes(screen)
  for _, value in pairs(screen.TextBoxes) do
    local text = EllosRerollEverythingMod.config[value.ConfigType][value.RerollType]
    local color = Color.White
    if text == -1 then
      color = Color.MetaUpgradePointsInvalid
      text = "Disabled"
    end
    ModifyTextBox({ Id = value.Id, Text = text, ColorTarget = color})
  end
end

function UseRerollSettingsMenu( usee, args )
	PlayInteractAnimation( usee.ObjectId )
	UseableOff({ Id = usee.ObjectId })
	StopStatusAnimation( usee )
  EnableShopGamepadCursor()
	OpenRerollSettingsMenu()
	UseableOn({ Id = usee.ObjectId })
end

function OpenRerollSettingsScreen(screen, button)
	CloseAdvancedTooltipScreen()
	UseRerollSettingsMenu(CurrentRun.Hero)
end

function OpenRerollSettingsMenu( args )
  RerollSettingsMenu = {}
	local screen = RerollSettingsMenu
  screen.TextBoxes = {}
	screen.Components = {}
	local components = screen.Components
	screen.CloseAnimation = "QuestLogBackground_Out"

	OnScreenOpened({ Flag = screen.Name, PersistCombatUI = true })
	FreezePlayerUnit()
	SetConfigOption({ Name = "FreeFormSelectWrapY", Value = false })
	SetConfigOption({ Name = "FreeFormSelectStepDistance", Value = 8 })
	SetConfigOption({ Name = "FreeFormSelectSuccessDistanceStep", Value = 8 })

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu" })
	components.ShopBackgroundSplatter = CreateScreenComponent({ Name = "LevelUpBackground", Group = "Combat_Menu" })
	components.ShopBackground = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu" })

	SetAnimation({ DestinationId = components.ShopBackground.Id, Name = "QuestLogBackground_In", OffsetY = 30 })

	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0.090, 0.055, 0.157, 0.8} })

	PlaySound({ Name = "/SFX/Menu Sounds/FatedListOpen" })

	wait(0.2)

	-- Title
	CreateTextBox({ Id = components.ShopBackground.Id, Text = "Reroll Options", FontSize = 34, OffsetX = 0, OffsetY = -460, Color = Color.White, Font = "SpectralSCLightTitling", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center" })
	CreateTextBox({ Id = components.ShopBackground.Id, Text = "Roll  the  Dice;  Change  what  is  Fated", FontSize = 15, OffsetX = 0, OffsetY = -410, Width = 840, Color = {120, 120, 120, 255}, Font = "CrimsonTextItalic", ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 2}, Justification = "Center" })

  -- Options
  local offsetX = 0
	local offsetY = -250
  components.rerollRow = {}

  components.ColumnHeaders = CreateScreenComponent({ Name = "BlankObstacle", Scale = 1.0, Group = "Combat_Menu" })
  Attach({ Id = components.ColumnHeaders.Id, DestinationId = components.ShopBackground.Id, OffsetX = offsetX, OffsetY = offsetY})
  CreateTextBox({
    Id = components.ColumnHeaders.Id,
    Text = "Reroll Type",
    FontSize = 18,
    OffsetX = -535,
    OffsetY = -45,
    Color = {120, 120, 120, 255},
    Font = "AlegreyaSansSCBold",
    ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
    OutlineThickness = 12, OutlineColor = {0,0,0,1},
    Justification = "Left"})
  CreateTextBox({
    Id = components.ColumnHeaders.Id,
    Text = "Base Cost to Reroll",
    FontSize = 18,
    OffsetX = 0,
    OffsetY = -45,
    Color = {120, 120, 120, 255},
    Font = "AlegreyaSansSCBold",
    ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
    OutlineThickness = 12, OutlineColor = {0,0,0,1},
    Justification = "Left"})
  CreateTextBox({
    Id = components.ColumnHeaders.Id,
    Text = "Cost Increase Per Reroll",
    FontSize = 18,
    OffsetX = 340,
    OffsetY = -45,
    Color = {120, 120, 120, 255},
    Font = "AlegreyaSansSCBold",
    ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
    OutlineThickness = 12, OutlineColor = {0,0,0,1},
    Justification = "Left"})

  for rerollType, rerollAmount in IterateSortedByRerollType(EllosRerollEverythingMod.config.BaseRerollCosts) do
      local rerollRow = CreateScreenComponent({ Name = "BlankObstacle", Scale = 1.0, Group = "Combat_Menu" })
      components["RerollRow" .. rerollType] = rerollRow
      Attach({ Id = rerollRow.Id, DestinationId = components.ShopBackground.Id, OffsetX = offsetX, OffsetY = offsetY})

      -- First Column
      local leftArrowOffsetX = 85
      local leftArrow = CreateScreenComponent({ Name = "LevelUpArrowLeft", Scale = 1.0, Group = "Combat_Menu" })
      leftArrow.OnPressedFunctionName = "ModifyRerollConfig"
      leftArrow.ConfigToUpdate = "BaseRerollCosts"
      leftArrow.ModifyAmount = -1
      leftArrow.RerollType = rerollType
      leftArrow.TextLabelId = leftArrow.Id
      components[rerollType .. "Col1LeftArrow"] = leftArrow
      Attach({ Id = leftArrow.Id, DestinationId = rerollRow.Id, OffsetX = leftArrowOffsetX, OffsetY = 0 })

      local rightArrow = CreateScreenComponent({ Name = "LevelUpArrowRight", Scale = 1.0, Group = "Combat_Menu" })
      rightArrow.OnPressedFunctionName = "ModifyRerollConfig"
      rightArrow.ConfigToUpdate = "BaseRerollCosts"
      rightArrow.ModifyAmount = 1
      rightArrow.RerollType = rerollType
      rightArrow.TextLabelId = leftArrow.Id
      components[rerollType .. "Col1RightArrow"] = rightArrow
      Attach({ Id = rightArrow.Id, DestinationId = rerollRow.Id, OffsetX = leftArrowOffsetX + 35, OffsetY = 0 })
      CreateTextBox({
        Id = leftArrow.Id,
        Text = EllosRerollEverythingMod.config.BaseRerollCosts[rerollType],
        FontSize = 28,
        OffsetX = -35,
        Color = Color.White,
        Font = "AlegreyaSansSCBold",
        ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
        OutlineThickness = 12, OutlineColor = {0,0,0,1},
        Justification = "Right"})
      table.insert(screen.TextBoxes, {Id = leftArrow.Id, ConfigType = leftArrow.ConfigToUpdate, RerollType = rerollType})

      -- Second Column
      local leftArrowOffsetX = 460
      local leftArrow = CreateScreenComponent({ Name = "LevelUpArrowLeft", Scale = 1.0, Group = "Combat_Menu" })
      leftArrow.OnPressedFunctionName = "ModifyRerollConfig"
      leftArrow.ConfigToUpdate = "RerollIncrements"
      leftArrow.ModifyAmount = -1
      leftArrow.RerollType = rerollType
      leftArrow.TextLabelId = leftArrow.Id
      components[rerollType .. "Col2LeftArrow"] = leftArrow
      Attach({ Id = leftArrow.Id, DestinationId = rerollRow.Id, OffsetX = leftArrowOffsetX, OffsetY = 0 })

      local rightArrow = CreateScreenComponent({ Name = "LevelUpArrowRight", Scale = 1.0, Group = "Combat_Menu" })
      rightArrow.OnPressedFunctionName = "ModifyRerollConfig"
      rightArrow.ConfigToUpdate = "RerollIncrements"
      rightArrow.ModifyAmount = 1
      rightArrow.RerollType = rerollType
      rightArrow.TextLabelId = leftArrow.Id
      components[rerollType .. "Col2RightArrow"] = rightArrow
      Attach({ Id = rightArrow.Id, DestinationId = rerollRow.Id, OffsetX = leftArrowOffsetX + 35, OffsetY = 0 })
      CreateTextBox({
        Id = leftArrow.Id,
        Text = EllosRerollEverythingMod.config.RerollIncrements[rerollType],
        FontSize = 28,
        OffsetX = -35,
        Color = Color.White,
        Font = "AlegreyaSansSCBold",
        ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
        OutlineThickness = 12, OutlineColor = {0,0,0,1},
        Justification = "Right"})
      table.insert(screen.TextBoxes, {Id = leftArrow.Id, ConfigType = leftArrow.ConfigToUpdate, RerollType = rerollType})

      local rerollTypeText = EllosRerollEverythingMod.RerollTypeToInGameName[rerollType]
      CreateTextBox({
        Id = rerollRow.Id,
        Text = rerollTypeText,
        FontSize = 28,
        OffsetX = - 500 - 135,
        Color = {255, 235, 128, 255},
  			Font = "AlegreyaSansSCBold",
  			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
  			OutlineThickness = 12, OutlineColor = {0,0,0,1},
  			Justification = "Left"})

      offsetY = offsetY + 60
  end

  -- Starting Reroll Count
  local startingRerollCount = CreateScreenComponent({ Name = "BlankObstacle", Scale = 1.0, Group = "Combat_Menu" })
  components["StartingRerollCount"] = startingRerollCount
  Attach({ Id = startingRerollCount.Id, DestinationId = components.ShopBackground.Id, OffsetX = offsetX, OffsetY = offsetY})

  -- First Column
  local leftArrowOffsetX = 85
  local leftArrow = CreateScreenComponent({ Name = "LevelUpArrowLeft", Scale = 1.0, Group = "Combat_Menu" })
  leftArrow.OnPressedFunctionName = "ModifyNumRerolls"
  leftArrow.ModifyAmount = -1
  leftArrow.TextLabelId = leftArrow.Id
  components["StartingRerollCostCol1LeftArrow"] = leftArrow
  Attach({ Id = leftArrow.Id, DestinationId = startingRerollCount.Id, OffsetX = leftArrowOffsetX, OffsetY = 0 })

  local rightArrow = CreateScreenComponent({ Name = "LevelUpArrowRight", Scale = 1.0, Group = "Combat_Menu" })
  rightArrow.OnPressedFunctionName = "ModifyNumRerolls"
  rightArrow.ModifyAmount = 1
  rightArrow.TextLabelId = leftArrow.Id
  components["StartingRerollCostCol1RightArrow"] = rightArrow
  Attach({ Id = rightArrow.Id, DestinationId = startingRerollCount.Id, OffsetX = leftArrowOffsetX + 35, OffsetY = 0 })
  CreateTextBox({
    Id = leftArrow.Id,
    Text = ((EllosRerollEverythingMod.config.NumStartingRerolls or CurrentRun.NumRerolls) or 0),
    FontSize = 28,
    OffsetX = -35,
    Color = Color.White,
    Font = "AlegreyaSansSCBold",
    ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
    OutlineThickness = 12, OutlineColor = {0,0,0,1},
    Justification = "Right"})

  CreateTextBox({
    Id = startingRerollCount.Id,
    Text = "# of Starting Rerolls",
    FontSize = 28,
    OffsetX = - 500 - 135,
    Color = {255, 235, 128, 255},
    Font = "AlegreyaSansSCBold",
    ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3},
    OutlineThickness = 12, OutlineColor = {0,0,0,1},
    Justification = "Left"})

  -- Macros
  components.MakeAllRerollsFree = CreateScreenComponent({ Name = "ButtonDefault", Group = "Combat_Menu"})
  Attach({ Id = components.MakeAllRerollsFree.Id, DestinationId = components.ShopBackground.Id, OffsetX = offsetX - 300, OffsetY = offsetY + 100 })
  components.MakeAllRerollsFree.OnPressedFunctionName = "MakeAllRerollsFree"
  CreateTextBox({ Id = components.MakeAllRerollsFree.Id,
      Text = "Make All Rerolls Free",
      FontSize = 22,
      Color = Color.White,
      Font = "AlegreyaSansSCRegular",
      ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
      Justification = "Center"
    })

  components.ResetToDefault = CreateScreenComponent({ Name = "ButtonDefault", Group = "Combat_Menu"})
  Attach({ Id = components.ResetToDefault.Id, DestinationId = components.ShopBackground.Id, OffsetX = offsetX, OffsetY = offsetY + 100 })
  components.ResetToDefault.OnPressedFunctionName = "ResetRerollConfigToDefault"
  CreateTextBox({ Id = components.ResetToDefault.Id,
      Text = "Reset to Mod Defaults",
      FontSize = 22,
      Color = Color.White,
      Font = "AlegreyaSansSCRegular",
      ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
      Justification = "Center"
    })

  components.DisableRerolls = CreateScreenComponent({ Name = "ButtonDefault", Group = "Combat_Menu"})
  Attach({ Id = components.DisableRerolls.Id, DestinationId = components.ShopBackground.Id, OffsetX = offsetX + 300, OffsetY = offsetY + 100 })
  components.DisableRerolls.OnPressedFunctionName = "DisableRerolls"
  CreateTextBox({ Id = components.DisableRerolls.Id,
      Text = "Disable All Rerolls",
      FontSize = 22,
      Color = Color.White,
      Font = "AlegreyaSansSCRegular",
      ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
      Justification = "Center"
    })

  -- Close button
	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Scale = 0.7, Group = "Combat_Menu" })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackground.Id, OffsetX = -6, OffsetY = 456 })
	components.CloseButton.OnPressedFunctionName = "CloseRerollSettingsMenu"
	components.CloseButton.ControlHotkey = "Cancel"

	wait(0.1)

	screen.KeepOpen = true
	thread( HandleWASDInput, screen )
	HandleScreenInput( screen )
end

function CloseRerollSettingsMenu( screen, button )
	SetConfigOption({ Name = "FreeFormSelectWrapY", Value = false })
	SetConfigOption({ Name = "FreeFormSelectStepDistance", Value = 16 })
	SetConfigOption({ Name = "FreeFormSelectSuccessDistanceStep", Value = 8 })
	SetAnimation({ DestinationId = screen.Components.ShopBackground.Id, Name = screen.CloseAnimation })
	PlaySound({ Name = "/SFX/Menu Sounds/FatedListClose" })
  DisableShopGamepadCursor()
	CloseScreen( GetAllIds( screen.Components ), 0.1 )
	UnfreezePlayerUnit()
	screen.KeepOpen = false
	OnScreenClosed({ Flag = screen.Name })
  updateRerollCostsFromConfig()
end
