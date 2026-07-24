--!nonstrict
--// Sentinel UI Library

if getgenv and getgenv().Library and getgenv().Library.Unload then
	pcall(function()
		getgenv().Library:Unload()
	end)
end

local cloneref = cloneref or clonereference or function(instance)
	return instance
end
local Services = setmetatable({}, {
	__index = function(self, name)
		local success, result = pcall(game.GetService, game, name)
		if success then
			local service = cloneref(result)
			rawset(self, name, service)
			return service
		end
		warn("Invalid Service: " .. tostring(name))
	end,
})

local UserInputService = Services.UserInputService
local RunService = Services.RunService
local TweenService = Services.TweenService
local Players = Services.Players
local TextService = Services.TextService

local getgenv = getgenv or function()
	return shared
end
local protectgui = protectgui or function() end
local gethui = gethui or function()
	return Services.CoreGui
end
local setclipboard = setclipboard or function() end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Mouse = cloneref(LocalPlayer:GetMouse())
local OriginalMouseIconEnabled = UserInputService.MouseIconEnabled

local PIXEL_FONT = "rbxassetid://12187371840"
local DEFAULT_FONT = "Jura"
local FONT = Font.fromEnum(Enum.Font[DEFAULT_FONT])

local Scheme = {
	Border = Color3.fromRGB(0, 0, 0),
	Outline = Color3.fromRGB(10, 10, 10),
	Accent = Color3.fromRGB(195, 33, 72),
	Body = Color3.fromRGB(20, 20, 20),
	Inline = Color3.fromRGB(30, 30, 30),
	FontColor = Color3.fromRGB(200, 200, 200),
	DimColor = Color3.fromRGB(170, 170, 170),
	Dark = Color3.fromRGB(8, 8, 8),
	DarkBorder = Color3.fromRGB(19, 19, 19),
	Element = Color3.fromRGB(38, 38, 38),
	ElementBorder = Color3.fromRGB(56, 56, 56),
	ElementFill = Color3.fromRGB(22, 22, 22),
	Pop = Color3.fromRGB(50, 50, 50),
	White = Color3.fromRGB(255, 255, 255),
	Divider = Color3.fromRGB(32, 32, 38),
	-- semantic warning colors; deliberately not in MasterShades so they stay constant across theme swaps
	Red = Color3.fromRGB(225, 65, 65),
	Orange = Color3.fromRGB(235, 145, 40),

	MainColor = Color3.fromRGB(38, 38, 38),
	AccentColor = Color3.fromRGB(195, 33, 72),
	BackgroundColor = Color3.fromRGB(20, 20, 20),
	OutlineColor = Color3.fromRGB(56, 56, 56),
}

local ColorProps = {
	BackgroundColor3 = true,
	TextColor3 = true,
	BorderColor3 = true,
	ScrollBarImageColor3 = true,
	ImageColor3 = true,
	PlaceholderColor3 = true,
	Color = true,
}

local MasterShades = {
	{ "Accent", "AccentColor", 0, 0, 0 },
	{ "FontColor", "FontColor", 0, 0, 0 },
	{ "DimColor", "FontColor", -30, -30, -30 },
	{ "Body", "BackgroundColor", 0, 0, 0 },
	{ "Dark", "BackgroundColor", -12, -12, -12 },
	{ "Inline", "BackgroundColor", 10, 10, 10 },
	{ "Outline", "BackgroundColor", -10, -10, -10 },
	{ "ElementFill", "BackgroundColor", 2, 2, 2 },
	{ "DarkBorder", "BackgroundColor", -1, -1, -1 },
	{ "Element", "MainColor", 0, 0, 0 },
	{ "Pop", "MainColor", 12, 12, 12 },
	{ "Border", "OutlineColor", -56, -56, -56 },
	{ "ElementBorder", "OutlineColor", 0, 0, 0 },
	{ "Divider", "OutlineColor", -24, -24, -18 },
}
local function byteOf(channel)
	return math.floor(channel * 255 + 0.5)
end
local function deriveScheme()
	for _, d in MasterShades do
		local master = Scheme[d[2]]
		if typeof(master) == "Color3" then
			Scheme[d[1]] = Color3.fromRGB(
				math.clamp(byteOf(master.R) + d[3], 0, 255),
				math.clamp(byteOf(master.G) + d[4], 0, 255),
				math.clamp(byteOf(master.B) + d[5], 0, 255)
			)
		end
	end
end

local Library = {
	Version = "1.0.0",
	Scheme = Scheme,
	Toggled = false,
	Unloaded = false,
	IsRobloxFocused = true,

	ToggleKeybind = Enum.KeyCode.RightControl,
	ShowCustomCursor = false,
	NotifySide = "Left",

	TweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

	Toggles = {},
	Options = {},

	Registry = {},
	Signals = {},
	UnloadSignals = {},

	Tabs = {},
	ActiveTab = nil,

	KeybindRows = {},

	SearchIndex = {},
	SearchBoxes = {},
	Searching = false,

	ScreenGui = nil,
	ShowCursorBinding = string.sub(tostring({}), 8),
}

local Templates = {
	Frame = { BorderSizePixel = 0 },
	ScrollingFrame = { BorderSizePixel = 0 },
	ImageLabel = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	TextLabel = { BorderSizePixel = 0, FontFace = FONT, RichText = false, TextSize = 12 },
	TextButton = { BorderSizePixel = 0, FontFace = FONT, AutoButtonColor = false, TextSize = 12 },
	TextBox = { BorderSizePixel = 0, FontFace = FONT, TextSize = 12, ClearTextOnFocus = false },
	UIListLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
}

local function FillInstance(instance, props)
	local themeProps = Library.Registry[instance]
	for key, value in props do
		if key == "Parent" then
			continue
		end
		if ColorProps[key] and typeof(value) == "string" then
			themeProps = themeProps or {}
			themeProps[key] = value
			value = Scheme[value]
		end
		instance[key] = value
	end
	if themeProps then
		Library.Registry[instance] = themeProps
	end
end

local function New(class, props)
	local instance = Instance.new(class)
	if Templates[class] then
		FillInstance(instance, Templates[class])
	end
	if props then
		FillInstance(instance, props)
		if props.Parent then
			instance.Parent = props.Parent
		end
	end
	return instance
end

function Library:AddToRegistry(instance, properties)
	Library.Registry[instance] = properties
end

function Library:RemoveFromRegistry(instance)
	Library.Registry[instance] = nil
end

function Library:UpdateColorsUsingRegistry()
	deriveScheme()
	for instance, properties in Library.Registry do
		for property, key in properties do
			local value = Scheme[key]
			if value ~= nil then
				pcall(function()
					instance[property] = value
				end)
			end
		end
	end
end

function Library:SetAccent(color)
	Scheme.AccentColor = color
	Library:UpdateColorsUsingRegistry()
end

function Library:SetFont(font)
	if type(font) == "string" then
		if font == "Sentinel" then
			font = Font.new(PIXEL_FONT)
		else
			local ok, resolved = pcall(function()
				return Font.fromEnum(Enum.Font[font])
			end)
			font = ok and resolved or nil
		end
	elseif typeof(font) == "EnumItem" then
		font = Font.fromEnum(font)
	end
	if typeof(font) ~= "Font" then
		return
	end
	Library.Font = font
	Templates.TextLabel.FontFace = font
	Templates.TextButton.FontFace = font
	Templates.TextBox.FontFace = font
	if not Library.ScreenGui then
		return
	end
	for _, inst in Library.ScreenGui:GetDescendants() do
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			pcall(function()
				inst.FontFace = font
			end)
		end
	end
end

function Library:SetFontSize(size)
	size = math.clamp(math.floor(tonumber(size) or 12), 6, 48)
	Library.FontSize = size
	Templates.TextLabel.TextSize = size
	Templates.TextButton.TextSize = size
	Templates.TextBox.TextSize = size
	if not Library.ScreenGui then
		return
	end
	for _, inst in Library.ScreenGui:GetDescendants() do
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			pcall(function()
				inst.TextSize = size
			end)
		end
	end
end

local function IsMouseInput(input, includeM2)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or (includeM2 == true and input.UserInputType == Enum.UserInputType.MouseButton2)
		or input.UserInputType == Enum.UserInputType.Touch
end
local function IsClickInput(input, includeM2)
	return IsMouseInput(input, includeM2)
		and input.UserInputState == Enum.UserInputState.Begin
		and Library.IsRobloxFocused
end
local function IsHoverInput(input)
	return (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		and input.UserInputState == Enum.UserInputState.Change
end
local function IsDragInput(input)
	return IsMouseInput(input)
		and (input.UserInputState == Enum.UserInputState.Begin or input.UserInputState == Enum.UserInputState.Change)
		and Library.IsRobloxFocused
end

local function Round(value, rounding)
	rounding = rounding or 0
	if rounding == 0 then
		return math.floor(value + 0.5)
	end
	local mult = 10 ^ rounding
	return math.floor(value * mult + 0.5) / mult
end

local function Trim(text)
	return text:match("^%s*(.-)%s*$")
end

local DISABLED_TEXT_FADE = 0.6
local DISABLED_FILL_FADE = 0.65

-- recolor by scheme key and repoint the registry so the color survives theme swaps
local function SetSchemeText(label, key, fallbackKey)
	key = key or fallbackKey
	local color = Scheme[key]
	if color == nil then
		return
	end
	label.TextColor3 = color
	local reg = Library.Registry[label]
	if not reg then
		reg = {}
		Library.Registry[label] = reg
	end
	reg.TextColor3 = key
end

-- greys via transparency only (never color props) so it can't fight the theme registry; fully reversible
local function MakeDisableable(handle, fades, setInteractive)
	handle.Disabled = handle.Disabled == true
	function handle:SetDisabled(state)
		state = state and true or false
		self.Disabled = state
		for _, f in fades do
			pcall(function()
				f[1][f[2]] = state and f[3] or f[4]
			end)
		end
		if setInteractive then
			setInteractive(not state)
		end
	end
end

local function MakeRecolorable(handle, label, defaultKey)
	handle.TextLabel = label
	handle.DefaultTextKey = defaultKey or "FontColor"
	function handle:SetTextColorKey(key)
		SetSchemeText(label, key, self.DefaultTextKey)
	end
end

function Library:GiveSignal(connection)
	local t = typeof(connection)
	if connection and (t == "RBXScriptConnection" or t == "RBXScriptSignal") then
		table.insert(Library.Signals, connection)
	end
	return connection
end

function Library:SafeCallback(func, ...)
	if typeof(func) ~= "function" then
		return
	end
	local args = { ... }
	local ok, err = pcall(function()
		return func(table.unpack(args))
	end)
	if not ok then
		warn("[Sentinel] callback error: " .. tostring(err))
	end
end

function Library:MouseIsOverFrame(frame, position)
	local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
	return position.X >= pos.X
		and position.X <= pos.X + size.X
		and position.Y >= pos.Y
		and position.Y <= pos.Y + size.Y
end

function Library:Validate(table_, template)
	if typeof(table_) ~= "table" then
		table_ = {}
	end
	for key, value in template do
		if typeof(key) == "number" then
			continue
		end
		if typeof(value) == "table" then
			table_[key] = Library:Validate(table_[key], value)
		elseif table_[key] == nil then
			table_[key] = value
		end
	end
	return table_
end

local KeyShortNames = {
	[Enum.KeyCode.LeftControl] = "lc",
	[Enum.KeyCode.RightControl] = "rc",
	[Enum.KeyCode.LeftShift] = "ls",
	[Enum.KeyCode.RightShift] = "rs",
	[Enum.KeyCode.LeftAlt] = "la",
	[Enum.KeyCode.RightAlt] = "ra",
	[Enum.KeyCode.Space] = "space",
	[Enum.UserInputType.MouseButton1] = "mb1",
	[Enum.UserInputType.MouseButton2] = "mb2",
	[Enum.UserInputType.MouseButton3] = "mb3",
}
function Library:GetKeyString(key)
	if KeyShortNames[key] then
		return KeyShortNames[key]
	end
	if typeof(key) == "EnumItem" then
		return key.Name:lower()
	end
	return tostring(key):lower()
end

local function MakeWindowShell(parent, size, position, titleText)
	local Outline = New("Frame", {
		Parent = parent,
		BackgroundColor3 = "Outline",
		BorderColor3 = "Border",
		Position = position or UDim2.fromOffset(0, 0),
		Size = size,
	})
	local Accent = New("Frame", {
		Parent = Outline,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
	})
	local Body = New("Frame", {
		Parent = Accent,
		BackgroundColor3 = "Body",
		BorderColor3 = "Border",
		BackgroundTransparency = 0.76,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
	})
	New("UIPadding", {
		Parent = Body,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	})
	local Title
	if titleText then
		Title = New("TextLabel", {
			Parent = Body,
			Name = "Title",
			Text = titleText,
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.fromOffset(0, 2),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Interactable = false,
		})
	end
	return { Outline = Outline, Accent = Accent, Body = Body, Title = Title }
end

local function MakePanel(parent, size, position)
	local Outline = New("Frame", {
		Parent = parent,
		BackgroundColor3 = "Outline",
		BorderColor3 = "Border",
		Size = size,
		Position = position or UDim2.fromOffset(0, 0),
	})
	local Inline = New("Frame", {
		Parent = Outline,
		BackgroundColor3 = "Inline",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 2,
	})
	local Body = New("Frame", {
		Parent = Inline,
		BackgroundColor3 = "Body",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
	})
	return Outline, Inline, Body
end

local function ParentUI(ui)
	pcall(protectgui, ui)
	local ok = pcall(function()
		ui.Parent = gethui()
	end)
	if not (ok and ui.Parent) then
		ui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local ScreenGui = New("ScreenGui", {
	Name = "\0" .. string.rep(" ", 6),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ResetOnSpawn = false,
	DisplayOrder = 999,
})
ParentUI(ScreenGui)
Library.ScreenGui = ScreenGui

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(instance)
	if Library.Registry[instance] then
		Library.Registry[instance] = nil
	end
end))

-- Drawing-based cursor in true screen space; the tip (PointA) lands exactly on the OS cursor
local Cursor, CursorOutline
do
	if Drawing then
		Cursor = Drawing.new("Triangle")
		Cursor.Filled = true
		Cursor.Thickness = 1
		Cursor.Color = Color3.fromRGB(255, 255, 255)
		Cursor.Visible = false
		Cursor.ZIndex = 11000
		CursorOutline = Drawing.new("Triangle")
		CursorOutline.Filled = false
		CursorOutline.Thickness = 1
		CursorOutline.Color = Color3.fromRGB(0, 0, 0)
		CursorOutline.Visible = false
		CursorOutline.ZIndex = 11001
	end
end
Library.Cursor = Cursor

local function drawCursor(visible)
	if not Cursor then
		return
	end
	if visible then
		local m = UserInputService:GetMouseLocation()
		local a = Vector2.new(m.X, m.Y)
		local b = Vector2.new(m.X + 14, m.Y + 5)
		local c = Vector2.new(m.X + 5, m.Y + 14)
		Cursor.PointA, Cursor.PointB, Cursor.PointC = a, b, c
		if CursorOutline then
			CursorOutline.PointA, CursorOutline.PointB, CursorOutline.PointC = a, b, c
		end
	end
	Cursor.Visible = visible
	if CursorOutline then
		CursorOutline.Visible = visible
	end
end

function Library:MakeDraggable(ui, dragFrame, isMainWindow)
	local startPos, framePos
	local dragging = false
	local changed

	dragFrame.InputBegan:Connect(function(input)
		if not IsClickInput(input) then
			return
		end
		startPos = input.Position
		framePos = ui.Position
		dragging = true
		changed = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if changed then
					changed:Disconnect()
					changed = nil
				end
			end
		end)
	end)

	Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
		if (isMainWindow and not Library.Toggled) or not (ScreenGui and ScreenGui.Parent) then
			dragging = false
			return
		end
		if dragging and IsHoverInput(input) then
			local delta = input.Position - startPos
			ui.Position = UDim2.new(
				framePos.X.Scale,
				framePos.X.Offset + delta.X,
				framePos.Y.Scale,
				framePos.Y.Offset + delta.Y
			)
		end
	end))
end

-- drag a corner handle to resize `ui`, clamped to min/max; returns a clamped setSize(w, h)
function Library:MakeResizable(ui, handle, minSize, maxSize)
	minSize = minSize or Vector2.new(120, 80)
	maxSize = maxSize or Vector2.new(800, 600)

	local function setSize(w, h)
		w = math.clamp(w, minSize.X, maxSize.X)
		h = math.clamp(h, minSize.Y, maxSize.Y)
		ui.Size = UDim2.fromOffset(w, h)
		return w, h
	end

	local startPos, startSize
	local resizing = false
	local changed

	handle.InputBegan:Connect(function(input)
		if not IsClickInput(input) then
			return
		end
		startPos = input.Position
		startSize = ui.Size
		resizing = true
		changed = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				resizing = false
				if changed then
					changed:Disconnect()
					changed = nil
				end
			end
		end)
	end)

	Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
		if not (ScreenGui and ScreenGui.Parent) then
			resizing = false
			return
		end
		if resizing and IsHoverInput(input) then
			local delta = input.Position - startPos
			setSize(startSize.X.Offset + delta.X, startSize.Y.Offset + delta.Y)
		end
	end))

	return setSize
end

local CurrentMenu
function Library:AddContextMenu(holder, size, offset, list)
	local Menu
	if list then
		Menu = New("ScrollingFrame", {
			Parent = ScreenGui,
			BackgroundTransparency = 1,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = typeof(size) == "function" and size() or size,
			Visible = false,
			ZIndex = 50,
		})
	else
		Menu = New("Frame", {
			Parent = ScreenGui,
			BackgroundTransparency = 1,
			Size = typeof(size) == "function" and size() or size,
			Visible = false,
			ZIndex = 50,
		})
	end

	local Table = { Active = false, Holder = holder, Menu = Menu, Signal = nil, Size = size }

	local function reposition()
		local o = typeof(offset) == "function" and offset() or offset
		Menu.Position = UDim2.fromOffset(
			math.floor(holder.AbsolutePosition.X + o[1]),
			math.floor(holder.AbsolutePosition.Y + o[2])
		)
	end

	function Table:Open()
		if CurrentMenu == Table then
			return
		elseif CurrentMenu then
			CurrentMenu:Close()
		end
		CurrentMenu = Table
		Table.Active = true
		Menu.Size = typeof(Table.Size) == "function" and Table.Size() or Table.Size
		reposition()
		Menu.Visible = true
		Table.Signal = holder:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
	end

	function Table:Close()
		if CurrentMenu ~= Table then
			return
		end
		Menu.Visible = false
		if Table.Signal then
			Table.Signal:Disconnect()
			Table.Signal = nil
		end
		Table.Active = false
		CurrentMenu = nil
	end

	function Table:Toggle()
		if Table.Active then
			Table:Close()
		else
			Table:Open()
		end
	end

	function Table:SetSize(newSize)
		Table.Size = newSize
		Menu.Size = typeof(newSize) == "function" and newSize() or newSize
	end

	return Table
end

Library:GiveSignal(UserInputService.InputBegan:Connect(function(input)
	if Library.Unloaded then
		return
	end
	if IsClickInput(input, true) and CurrentMenu then
		local pos = input.Position
		if
			not (
				Library:MouseIsOverFrame(CurrentMenu.Menu, pos)
				or Library:MouseIsOverFrame(CurrentMenu.Holder, pos)
			)
		then
			CurrentMenu:Close()
		end
	end
end))

local TooltipFrame = New("Frame", {
	Parent = ScreenGui,
	BackgroundColor3 = "Dark",
	BorderColor3 = "DarkBorder",
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	ZIndex = 60,
})
New("UIPadding", {
	Parent = TooltipFrame,
	PaddingTop = UDim.new(0, 1),
	PaddingBottom = UDim.new(0, 1),
	PaddingLeft = UDim.new(0, 1),
	PaddingRight = UDim.new(0, 1),
})
local TooltipInner = New("Frame", {
	Parent = TooltipFrame,
	BackgroundColor3 = "Element",
	BorderColor3 = "ElementBorder",
	BorderSizePixel = 1,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.fromOffset(0, 0),
	ZIndex = 60,
})
New("UIPadding", {
	Parent = TooltipInner,
	PaddingTop = UDim.new(0, 2),
	PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 4),
})
local TooltipLabel = New("TextLabel", {
	Parent = TooltipInner,
	Text = "",
	TextColor3 = "FontColor",
	TextStrokeTransparency = 0,
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.fromOffset(0, 14),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 61,
})
local CurrentHover
function Library:AddTooltip(infoStr, hoverInstance)
	if typeof(infoStr) ~= "string" then
		return
	end
	local tip = { Signals = {} }
	local function doHover()
		if CurrentHover == hoverInstance or (CurrentMenu and Library:MouseIsOverFrame(CurrentMenu.Menu, Mouse)) then
			return
		end
		if not (Library.Toggled and Library:MouseIsOverFrame(hoverInstance, Mouse)) then
			return
		end
		CurrentHover = hoverInstance
		TooltipLabel.Text = infoStr
		while
			Library.Toggled
			and Library:MouseIsOverFrame(hoverInstance, Mouse)
			and not (CurrentMenu and Library:MouseIsOverFrame(CurrentMenu.Menu, Mouse))
		do
			TooltipFrame.Visible = true
			TooltipFrame.Position = UDim2.fromOffset(Mouse.X + 14, Mouse.Y + 12)
			RunService.RenderStepped:Wait()
		end
		TooltipFrame.Visible = false
		CurrentHover = nil
	end
	table.insert(tip.Signals, hoverInstance.MouseEnter:Connect(doHover))
	table.insert(tip.Signals, hoverInstance.MouseMoved:Connect(doHover))
	table.insert(
		tip.Signals,
		hoverInstance.MouseLeave:Connect(function()
			if CurrentHover == hoverInstance then
				TooltipFrame.Visible = false
				CurrentHover = nil
			end
		end)
	)
	function tip:Destroy()
		for _, c in tip.Signals do
			if c.Connected then
				c:Disconnect()
			end
		end
	end
	Library:OnUnload(function()
		tip:Destroy()
	end)
	return tip
end

local NotifyHolder, NotifyLayout
local function notifyOnLeft()
	-- lenient: "Left"/"left"/"LeftSide" all count as left, anything else is right
	return tostring(Library.NotifySide):lower():sub(1, 1) == "l"
end
local function positionNotifyHolder()
	if not NotifyHolder then
		return
	end
	local left = notifyOnLeft()
	NotifyHolder.AnchorPoint = Vector2.new(left and 0 or 1, 0)
	NotifyHolder.Position = left and UDim2.fromOffset(16, 16) or UDim2.new(1, -16, 0, 16)
	NotifyLayout.HorizontalAlignment = left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
end
function Library:SetNotifySide(side)
	Library.NotifySide = side
	positionNotifyHolder()
end
function Library:Notify(info, time)
	local title, body, persist
	local richText = false
	if typeof(info) == "table" then
		title = info.Title
		body = info.Description
		persist = info.Persist == true
		richText = info.RichText == true
		if info.Time ~= nil then
			time = info.Time
		end
	else
		title = tostring(info)
	end
	-- a lone Description (no Title) renders as the single line
	if title == nil and body ~= nil then
		title, body = body, nil
	end
	title = title or ""

	if time == nil then
		time = 3
	end
	if type(time) ~= "number" or time <= 0 then
		persist = true
	end

	if not NotifyHolder then
		NotifyHolder = New("Frame", {
			Parent = ScreenGui,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 260, 1, -32),
			ZIndex = 200,
		})
		NotifyLayout = New("UIListLayout", {
			Parent = NotifyHolder,
			Padding = UDim.new(0, 8),
		})
	end
	positionNotifyHolder()
	local onLeft = notifyOnLeft()

	local outer = New("Frame", {
		Parent = NotifyHolder,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, 248, 0, 0),
		ZIndex = 200,
	})
	New("UIPadding", {
		Parent = outer,
		PaddingTop = UDim.new(0, 1),
		PaddingBottom = UDim.new(0, 1),
		PaddingLeft = UDim.new(0, 1),
		PaddingRight = UDim.new(0, 1),
	})
	local inner = New("Frame", {
		Parent = outer,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		-- centered so the 2px slack splits 1px/1px (even dark frame) instead of all landing on the right edge
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, -2, 0, 0),
		ZIndex = 200,
	})
	local content = New("Frame", {
		Parent = inner,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 201,
	})
	New("UIListLayout", { Parent = content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) })
	New("UIPadding", {
		Parent = content,
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 9),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	local titleLabel = New("TextLabel", {
		Parent = content,
		Text = title,
		TextColor3 = "FontColor",
		TextStrokeTransparency = 0,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 14,
		RichText = richText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LayoutOrder = 1,
		ZIndex = 201,
	})

	local bodyLabel
	if body and body ~= "" then
		bodyLabel = New("TextLabel", {
			Parent = content,
			Text = body,
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 12),
			TextSize = 12,
			RichText = richText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			LayoutOrder = 2,
			ZIndex = 201,
		})
	end

	-- anchored to the notify side's edge so the bar empties toward the nearest screen edge
	local bar = New("Frame", {
		Parent = inner,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		AnchorPoint = Vector2.new(onLeft and 0 or 1, 1),
		Position = onLeft and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 202,
	})

	local handle = { Object = outer, Inner = inner, AccentBar = bar, TitleLabel = titleLabel, BodyLabel = bodyLabel }

	if not persist then
		local drain = TweenService:Create(
			bar,
			TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
			{ Size = UDim2.new(0, 0, 0, 2) }
		)
		local function dismiss()
			pcall(function()
				drain:Cancel()
			end)
			pcall(function()
				outer:Destroy()
			end)
		end
		Library:GiveSignal(drain.Completed:Connect(dismiss))
		Library:OnUnload(function()
			pcall(function()
				drain:Cancel()
			end)
		end)
		drain:Play()
		handle.Tween = drain
	end

	return handle
end

local Funcs = {}
local BaseAddons = {}

local function applyTooltip(handle, info, instance)
	if info.Tooltip then
		Library:AddTooltip(info.Tooltip, instance)
	end
end

local function indexElement(self, row, text)
	if not (row and self and self.Record) then
		return
	end
	local entry = {
		Text = tostring(text or ""):lower(),
		Row = row,
		Reveal = self.Reveal,
		Tab = self.Tab,
		Record = self.Record,
		Column = self.Column,
		Dimmed = false,
	}
	table.insert(Library.SearchIndex, entry)
	table.insert(self.Record.Entries, entry)
	return entry
end

function Funcs:AddLabel(info, doesWrap)
	if typeof(info) == "string" then
		info = { Text = info, DoesWrap = doesWrap }
	end
	info = Library:Validate(info, { Text = "Label", DoesWrap = false, Visible = true })

	local Holder = New("Frame", {
		Parent = self.Container,
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 12),
		AutomaticSize = info.DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		Visible = info.Visible,
	})
	local TextLabel = New("TextLabel", {
		Parent = Holder,
		Text = info.Text,
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		Size = info.DoesWrap and UDim2.new(1, 0, 0, 12) or UDim2.fromOffset(0, 12),
		AutomaticSize = info.DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = info.DoesWrap,
	})

	local Label = { Text = info.Text, Type = "Label", TextLabel = TextLabel, Holder = Holder, AddonContainer = nil }
	Label.SearchEntry = indexElement(self, Holder, info.Text)

	local Right = New("Frame", {
		Parent = Holder,
		Name = "RightContainer",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0, 1),
		Size = UDim2.fromOffset(0, 12),
	})
	New("UIListLayout", {
		Parent = Right,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
	})
	Label.AddonContainer = Right

	function Label:SetText(text)
		Label.Text = text
		TextLabel.Text = text
	end
	function Label:SetVisible(v)
		Holder.Visible = v
	end

	MakeRecolorable(Label, TextLabel, "DimColor")
	MakeDisableable(Label, {
		{ TextLabel, "TextTransparency", DISABLED_TEXT_FADE, 0 },
	})

	applyTooltip(Label, info, TextLabel)
	setmetatable(Label, { __index = BaseAddons })
	return Label
end

function Funcs:AddDivider()
	local Holder = New("Frame", {
		Parent = self.Container,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 5),
	})
	New("Frame", {
		Parent = Holder,
		BackgroundColor3 = "Divider",
		BorderColor3 = "Border",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
	})
	return { Type = "Divider", Holder = Holder }
end

function Funcs:AddButton(info, func)
	if typeof(info) == "string" then
		info = { Text = info, Func = func }
	end
	info = Library:Validate(info, { Text = "Button", Func = function() end, DoubleClick = false, Disabled = false })

	local Holder = New("Frame", {
		Parent = self.Container,
		Name = "Button",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
	})
	New("UIListLayout", {
		Parent = Holder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
	})

	local Button = { Type = "Button", Holder = Holder }
	local bases = {}

	local function makeSub(subInfo)
		local Wrapper = New("Frame", {
			Parent = Holder,
			BackgroundColor3 = "Border",
			BorderColor3 = "DarkBorder",
			Size = UDim2.fromScale(1, 1),
		})
		New("UIFlexItem", { Parent = Wrapper, FlexMode = Enum.UIFlexMode.Fill })
		local Base = New("TextButton", {
			Parent = Wrapper,
			Text = subInfo.Text,
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0,
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
		})

		local Sub = { Text = subInfo.Text, Func = subInfo.Func, Base = Base }
		table.insert(bases, Base)
		local lastClick = 0
		Base.MouseButton1Click:Connect(function()
			if subInfo.Disabled then
				return
			end
			if subInfo.DoubleClick then
				local now = os.clock()
				if now - lastClick > 0.4 then
					lastClick = now
					Base.Text = "are you sure?"
					return
				end
				Base.Text = subInfo.Text
			end
			Library:SafeCallback(Sub.Func)
		end)
		Base.MouseEnter:Connect(function()
			Base.BackgroundColor3 = Library.Scheme.ElementBorder
		end)
		Base.MouseLeave:Connect(function()
			Base.BackgroundColor3 = Library.Scheme.Element
			if subInfo.DoubleClick then
				Base.Text = subInfo.Text
			end
		end)
		function Sub:SetText(text)
			Sub.Text = text
			Base.Text = text
		end
		applyTooltip(Sub, subInfo, Base)
		return Sub
	end

	local main = makeSub(info)
	indexElement(self, Holder, info.Text)
	Button.SetText = function(_, text)
		main:SetText(text)
	end

	MakeRecolorable(Button, main.Base, "DimColor")
	local buttonFades = {}
	for _, b in bases do
		table.insert(buttonFades, { b, "TextTransparency", DISABLED_TEXT_FADE, 0 })
		table.insert(buttonFades, { b, "BackgroundTransparency", DISABLED_FILL_FADE, 0 })
	end
	MakeDisableable(Button, buttonFades, function(on)
		for _, b in bases do
			b.Interactable = on
		end
	end)
	if info.Disabled then
		Button:SetDisabled(true)
	end

	function Button:AddButton(subInfo, subFunc)
		if typeof(subInfo) == "string" then
			subInfo = { Text = subInfo, Func = subFunc }
		end
		subInfo = Library:Validate(subInfo, { Text = "Button", Func = function() end, DoubleClick = false, Disabled = false })
		return makeSub(subInfo)
	end

	return Button
end

function Funcs:AddToggle(idx, info)
	info = Library:Validate(info, {
		Text = "Toggle",
		Default = false,
		Callback = function() end,
		Changed = function() end,
		Disabled = false,
		Visible = true,
	})

	local Toggle = {
		Value = info.Default and true or false,
		Type = "Toggle",
		Text = info.Text,
		Callback = info.Callback,
		Changed = info.Changed,
		Addons = {},
		OnChangedFns = {},
	}

	local Holder = New("TextButton", {
		Parent = self.Container,
		Name = "Toggle",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Visible = info.Visible,
	})

	local Box = New("TextButton", {
		Parent = Holder,
		Text = "",
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.fromOffset(10, 10),
	})
	local Inner = New("Frame", {
		Parent = Box,
		BackgroundColor3 = "ElementFill",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
	})
	local Fill = New("Frame", {
		Parent = Inner,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		Size = UDim2.fromScale(1, 1),
		Visible = Toggle.Value,
	})

	local Label = New("TextLabel", {
		Parent = Holder,
		Name = "Text",
		Text = info.Text,
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	local Right = New("Frame", {
		Parent = Holder,
		Name = "RightContainer",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0, 1),
		Size = UDim2.fromScale(0, 1),
	})
	New("UIListLayout", {
		Parent = Right,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
	})
	Toggle.AddonContainer = Right
	Toggle.TextLabel = Label
	Toggle.Holder = Holder
	Toggle.SearchEntry = indexElement(self, Holder, info.Text)

	function Toggle:Display()
		Fill.Visible = Toggle.Value
	end
	function Toggle:OnChanged(func)
		table.insert(Toggle.OnChangedFns, func)
		Library:SafeCallback(func, Toggle.Value)
	end
	function Toggle:SetValue(value)
		Toggle.Value = value and true or false
		Toggle:Display()
		Library:SafeCallback(Toggle.Changed, Toggle.Value)
		Library:SafeCallback(Toggle.Callback, Toggle.Value)
		for _, func in Toggle.OnChangedFns do
			Library:SafeCallback(func, Toggle.Value)
		end
	end
	function Toggle:GetValue()
		return Toggle.Value
	end
	function Toggle:SetText(text)
		Toggle.Text = text
		Label.Text = text
	end
	function Toggle:SetVisible(v)
		Holder.Visible = v
	end

	local function flip()
		if Toggle.Disabled then
			return
		end
		Toggle:SetValue(not Toggle.Value)
	end
	Holder.MouseButton1Click:Connect(flip)
	Box.MouseButton1Click:Connect(flip)

	MakeRecolorable(Toggle, Label, "DimColor")
	-- no setInteractive: the flip guard blocks clicks, but staying Interactable keeps the tooltip working
	MakeDisableable(Toggle, {
		{ Label, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ Fill, "BackgroundTransparency", DISABLED_FILL_FADE, 0 },
	})
	if info.Disabled then
		Toggle:SetDisabled(true)
	end

	Toggle:Display()
	applyTooltip(Toggle, info, Holder)
	Library.Toggles[idx] = Toggle
	setmetatable(Toggle, { __index = BaseAddons })
	return Toggle
end

function Funcs:AddInput(idx, info)
	info = Library:Validate(info, {
		Text = "",
		Default = "",
		Placeholder = "type here...",
		Numeric = false,
		Finished = false,
		ClearTextOnFocus = false,
		Callback = function() end,
		Changed = function() end,
		Visible = true,
	})

	local Input = {
		Value = info.Default or "",
		Type = "Input",
		Callback = info.Callback,
		Changed = info.Changed,
		OnChangedFns = {},
	}

	if info.Text and info.Text ~= "" then
		Funcs.AddLabel(self, { Text = info.Text })
	end

	local Holder = New("Frame", {
		Parent = self.Container,
		Name = "Textbox",
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Size = UDim2.new(1, 0, 0, 16),
		Visible = info.Visible,
	})
	local Box = New("TextBox", {
		Parent = Holder,
		Text = info.Default or "",
		PlaceholderText = info.Placeholder,
		PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
		TextColor3 = "FontColor",
		TextStrokeTransparency = 0.5,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		ClearTextOnFocus = info.ClearTextOnFocus,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	New("UIPadding", { Parent = Box, PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })

	Input.Holder = Holder
	Input.TextBox = Box
	indexElement(self, Holder, info.Text)

	function Input:OnChanged(func)
		table.insert(Input.OnChangedFns, func)
		Library:SafeCallback(func, Input.Value)
	end
	local function fire()
		Library:SafeCallback(Input.Changed, Input.Value)
		Library:SafeCallback(Input.Callback, Input.Value)
		for _, func in Input.OnChangedFns do
			Library:SafeCallback(func, Input.Value)
		end
	end
	function Input:SetValue(text)
		text = tostring(text)
		if info.Numeric then
			text = text:gsub("[^%d%.%-]", "")
		end
		Input.Value = text
		Box.Text = text
		fire()
	end
	function Input:GetValue()
		return Input.Value
	end

	Box:GetPropertyChangedSignal("Text"):Connect(function()
		if info.Numeric then
			local cleaned = Box.Text:gsub("[^%d%.%-]", "")
			if cleaned ~= Box.Text then
				Box.Text = cleaned
				return
			end
		end
		if not info.Finished then
			Input.Value = Box.Text
			fire()
		end
	end)
	Box.FocusLost:Connect(function()
		Input.Value = Box.Text
		fire()
	end)

	MakeRecolorable(Input, Box, "FontColor")
	MakeDisableable(Input, {
		{ Box, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ Box, "BackgroundTransparency", DISABLED_FILL_FADE, 0 },
	}, function(on)
		Box.TextEditable = on
	end)

	applyTooltip(Input, info, Holder)
	Library.Options[idx] = Input
	return Input
end

function Funcs:AddSlider(idx, info)
	info = Library:Validate(info, {
		Text = "Slider",
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Prefix = "",
		Suffix = "",
		Callback = function() end,
		Changed = function() end,
		Visible = true,
	})

	local Slider = {
		Value = info.Default,
		Min = info.Min,
		Max = info.Max,
		Rounding = info.Rounding,
		Prefix = info.Prefix,
		Suffix = info.Suffix,
		Type = "Slider",
		Text = info.Text,
		Callback = info.Callback,
		Changed = info.Changed,
		OnChangedFns = {},
	}

	local Holder = New("TextLabel", {
		Parent = self.Container,
		Name = "Slider",
		Text = info.Text,
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = info.Visible,
	})

	local Bar = New("TextButton", {
		Parent = Holder,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(1, -26, 0, 8),
	})
	New("Frame", {
		Parent = Bar,
		BackgroundColor3 = "ElementFill",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
	})
	local Fill = New("Frame", {
		Parent = Bar,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(0, 0, 1, -4),
		ZIndex = 2,
	})
	local ValueLabel = New("TextLabel", {
		Parent = Bar,
		Text = "0",
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		TextSize = 12,
	})

	local Minus = New("TextButton", {
		Parent = Bar,
		Text = "-",
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(-7, 4),
		Size = UDim2.fromOffset(8, 8),
	})
	local Plus = New("TextButton", {
		Parent = Bar,
		Text = "+",
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 7, 0, 4),
		Size = UDim2.fromOffset(8, 8),
	})

	Slider.Holder = Holder
	indexElement(self, Holder, info.Text)

	function Slider:Display()
		local frac = (Slider.Max - Slider.Min) == 0 and 0 or (Slider.Value - Slider.Min) / (Slider.Max - Slider.Min)
		frac = math.clamp(frac, 0, 1)
		Fill.Size = UDim2.new(frac, frac > 0 and -4 or 0, 1, -4)
		ValueLabel.Text = string.format("%s%s%s", Slider.Prefix, tostring(Slider.Value), Slider.Suffix)
	end
	function Slider:OnChanged(func)
		table.insert(Slider.OnChangedFns, func)
		Library:SafeCallback(func, Slider.Value)
	end
	function Slider:SetValue(value)
		value = math.clamp(Round(value, Slider.Rounding), Slider.Min, Slider.Max)
		Slider.Value = value
		Slider:Display()
		Library:SafeCallback(Slider.Changed, Slider.Value)
		Library:SafeCallback(Slider.Callback, Slider.Value)
		for _, func in Slider.OnChangedFns do
			Library:SafeCallback(func, Slider.Value)
		end
	end
	function Slider:GetValue()
		return Slider.Value
	end
	function Slider:SetMin(v)
		Slider.Min = v
		Slider:SetValue(Slider.Value)
	end
	function Slider:SetMax(v)
		Slider.Max = v
		Slider:SetValue(Slider.Value)
	end

	local step = Slider.Rounding == 0 and 1 or 10 ^ -Slider.Rounding
	Minus.MouseButton1Click:Connect(function()
		Slider:SetValue(Slider.Value - step)
	end)
	Plus.MouseButton1Click:Connect(function()
		Slider:SetValue(Slider.Value + step)
	end)

	local dragging = false
	local function moveTo(x)
		local rel = (x - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X
		Slider:SetValue(Slider.Min + math.clamp(rel, 0, 1) * (Slider.Max - Slider.Min))
	end
	Bar.InputBegan:Connect(function(input)
		if not IsClickInput(input) then
			return
		end
		dragging = true
		moveTo(input.Position.X)
	end)
	Bar.InputEnded:Connect(function(input)
		if IsMouseInput(input) then
			dragging = false
		end
	end)
	Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
		if dragging and IsHoverInput(input) then
			moveTo(input.Position.X)
		end
	end))

	MakeRecolorable(Slider, Holder, "DimColor")
	MakeDisableable(Slider, {
		{ Holder, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ ValueLabel, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ Minus, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ Plus, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ Fill, "BackgroundTransparency", DISABLED_FILL_FADE, 0 },
	}, function(on)
		Bar.Interactable = on
		Minus.Interactable = on
		Plus.Interactable = on
	end)

	Slider:Display()
	applyTooltip(Slider, info, Holder)
	Library.Options[idx] = Slider
	return Slider
end

function Funcs:AddDropdown(idx, info)
	info = Library:Validate(info, {
		Text = "Dropdown",
		Values = {},
		Default = nil,
		Multi = false,
		MaxVisibleDropdownItems = 8,
		Callback = function() end,
		Changed = function() end,
		Visible = true,
	})

	if idx == "FontFace" and not info.Multi then
		local function ensure(name, atFront)
			for _, v in info.Values do
				if v == name then
					return
				end
			end
			table.insert(info.Values, atFront and 1 or #info.Values + 1, name)
		end
		ensure("Sentinel", true)
		ensure(DEFAULT_FONT, false)
		info.Default = DEFAULT_FONT
	end

	local Dropdown = {
		Values = info.Values,
		Value = info.Multi and {} or nil,
		Multi = info.Multi,
		Type = "Dropdown",
		Text = info.Text,
		Callback = info.Callback,
		Changed = info.Changed,
		MaxVisibleDropdownItems = info.MaxVisibleDropdownItems,
		OnChangedFns = {},
	}

	local Holder = New("Frame", {
		Parent = self.Container,
		Name = "Dropdown",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Visible = info.Visible,
	})
	local TitleLabel = New("TextLabel", {
		Parent = Holder,
		Text = info.Text,
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local DisplayOuter = New("Frame", {
		Parent = Holder,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 16),
	})
	local Button = New("TextButton", {
		Parent = DisplayOuter,
		Text = "---",
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	New("UIPadding", { Parent = Button, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 12) })
	New("TextLabel", {
		Parent = Button,
		Text = "+",
		TextColor3 = "DimColor",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 2, 0.5, 0),
		Size = UDim2.fromOffset(8, 12),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	Dropdown.Holder = Holder
	indexElement(self, Holder, info.Text)

	local Menu = Library:AddContextMenu(DisplayOuter, function()
		return UDim2.fromOffset(DisplayOuter.AbsoluteSize.X, 0)
	end, function()
		return { 0, DisplayOuter.AbsoluteSize.Y + 1 }
	end, 1)

	local ListOuter = New("Frame", {
		Parent = Menu.Menu,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
	})
	New("UIPadding", {
		Parent = ListOuter,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	})
	local ListInner = New("Frame", {
		Parent = ListOuter,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
	})
	New("UIPadding", {
		Parent = ListInner,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	})
	local ItemList = New("Frame", {
		Parent = ListInner,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
	})
	New("UIListLayout", { Parent = ItemList, Padding = UDim.new(0, 2) })
	New("UIPadding", { Parent = ItemList, PaddingBottom = UDim.new(0, 4) })
	Dropdown.ListBacking = ListOuter

	local ItemButtons = {}

	function Dropdown:GetActiveValues()
		if Dropdown.Multi then
			local out = {}
			for value, state in Dropdown.Value do
				if state then
					table.insert(out, value)
				end
			end
			table.sort(out)
			return out
		end
		return Dropdown.Value
	end

	function Dropdown:Display()
		local text
		if Dropdown.Multi then
			local active = Dropdown:GetActiveValues()
			text = #active > 0 and table.concat(active, ", ") or "---"
		else
			text = Dropdown.Value ~= nil and tostring(Dropdown.Value) or "---"
		end
		Button.Text = text
		for value, btn in ItemButtons do
			local selected
			if Dropdown.Multi then
				selected = Dropdown.Value[value] == true
			else
				selected = Dropdown.Value == value
			end
			btn.TextColor3 = selected and Library.Scheme.FontColor or Library.Scheme.DimColor
			btn.BackgroundTransparency = selected and 0 or 1
		end
	end

	function Dropdown:OnChanged(func)
		table.insert(Dropdown.OnChangedFns, func)
		Library:SafeCallback(func, Dropdown.Value)
	end
	local function fire()
		Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
		Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
		for _, func in Dropdown.OnChangedFns do
			Library:SafeCallback(func, Dropdown.Value)
		end
	end

	function Dropdown:RecalculateListSize()
		local count = #Dropdown.Values
		local visible = math.min(count, Dropdown.MaxVisibleDropdownItems)
		local height = visible * 16 + 8
		Menu:SetSize(UDim2.fromOffset(DisplayOuter.AbsoluteSize.X, height))
	end

	function Dropdown:BuildDropdownList()
		for _, btn in ItemButtons do
			btn:Destroy()
		end
		table.clear(ItemButtons)
		for _, value in Dropdown.Values do
			local Item = New("TextButton", {
				Parent = ItemList,
				Text = tostring(value),
				TextColor3 = "DimColor",
				TextStrokeTransparency = 0.5,
				BackgroundColor3 = "Pop",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 51,
			})
			New("UIPadding", { Parent = Item, PaddingLeft = UDim.new(0, 5) })
			ItemButtons[value] = Item
			Item.MouseButton1Click:Connect(function()
				if Dropdown.Multi then
					Dropdown.Value[value] = not Dropdown.Value[value]
				else
					Dropdown.Value = value
					Menu:Close()
				end
				Dropdown:Display()
				fire()
			end)
		end
		Dropdown:RecalculateListSize()
	end

	function Dropdown:SetValue(value)
		if Dropdown.Multi then
			Dropdown.Value = {}
			if typeof(value) == "table" then
				for k, v in value do
					if type(k) == "number" then
						Dropdown.Value[v] = true
					elseif v then
						Dropdown.Value[k] = true
					end
				end
			end
		else
			Dropdown.Value = value
		end
		Dropdown:Display()
		fire()
	end
	function Dropdown:GetValue()
		return Dropdown.Value
	end
	function Dropdown:SetValues(values)
		Dropdown.Values = values
		Dropdown:BuildDropdownList()
		Dropdown:Display()
	end

	Button.MouseButton1Click:Connect(function()
		Dropdown:RecalculateListSize()
		Menu:Toggle()
	end)

	Dropdown:BuildDropdownList()

	if info.Default ~= nil then
		if Dropdown.Multi then
			local def = typeof(info.Default) == "table" and info.Default or { info.Default }
			for _, v in def do
				local val = typeof(v) == "number" and Dropdown.Values[v] or v
				if val ~= nil then
					Dropdown.Value[val] = true
				end
			end
		else
			local val = typeof(info.Default) == "number" and Dropdown.Values[info.Default] or info.Default
			Dropdown.Value = val
		end
	end

	MakeRecolorable(Dropdown, TitleLabel, "DimColor")
	MakeDisableable(Dropdown, {
		{ TitleLabel, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ Button, "TextTransparency", DISABLED_TEXT_FADE, 0 },
		{ Button, "BackgroundTransparency", DISABLED_FILL_FADE, 0 },
	}, function(on)
		Button.Interactable = on
	end)

	Dropdown:Display()
	applyTooltip(Dropdown, info, Holder)
	Library.Options[idx] = Dropdown
	return Dropdown
end

local SpecialInputs = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
}
local MouseStrings = {
	MB1 = Enum.UserInputType.MouseButton1,
	MB2 = Enum.UserInputType.MouseButton2,
	MB3 = Enum.UserInputType.MouseButton3,
}
local MouseInputToString = {
	[Enum.UserInputType.MouseButton1] = "MB1",
	[Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}
local function ResolveKey(key)
	if typeof(key) == "EnumItem" then
		return key
	end
	if type(key) == "string" then
		if MouseStrings[key] then
			return MouseStrings[key]
		end
		if key == "None" or key == "" then
			return nil
		end
		local ok, code = pcall(function()
			return Enum.KeyCode[key]
		end)
		if ok then
			return code
		end
	end
	return nil
end
local function CanonicalKeyName(bind)
	if bind == nil then
		return "None"
	end
	if MouseInputToString[bind] then
		return MouseInputToString[bind]
	end
	if typeof(bind) == "EnumItem" then
		return bind.Name
	end
	return "None"
end

function BaseAddons:AddKeyPicker(idx, info)
	info = Library:Validate(info, {
		Text = "KeyPicker",
		Default = "None",
		Mode = "Toggle",
		Modes = { "Always", "Toggle", "Hold" },
		SyncToggleState = false,
		NoUI = false,
		Callback = function() end,
		ChangedCallback = function() end,
		Changed = function() end,
	})

	local container = self.AddonContainer
	assert(container, "KeyPicker can only be attached to a Toggle or Label.")

	local KeyPicker = {
		Value = info.Default,
		Mode = info.Mode,
		Modifiers = {},
		Toggled = false,
		Type = "KeyPicker",
		Text = info.Text ~= "KeyPicker" and info.Text or (self.Text or "KeyPicker"),
		Callback = info.Callback,
		ChangedCallback = info.ChangedCallback,
		Changed = info.Changed,
		OnChangedFns = {},
	}

	local function keyLabel()
		return "[" .. (KeyPicker.Value == "None" and "none" or Library:GetKeyString(KeyPicker.Bind or KeyPicker.Value)) .. "]"
	end

	local Picker = New("TextButton", {
		Parent = container,
		Name = "KeybindButton",
		Text = "[none]",
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 16, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local ModeMenu = Library:AddContextMenu(Picker, UDim2.fromOffset(62, 0), function()
		return { Picker.AbsoluteSize.X + 2, 0 }
	end, 1)
	local ModeOuter = New("Frame", {
		Parent = ModeMenu.Menu,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
	})
	local ModeInner = New("Frame", {
		Parent = ModeOuter,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 50,
	})
	New("UIListLayout", { Parent = ModeInner, Padding = UDim.new(0, 1) })
	KeyPicker.Bind = ResolveKey(info.Default)

	for _, mode in info.Modes do
		local btn = New("TextButton", {
			Parent = ModeInner,
			Text = mode,
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Pop",
			BackgroundTransparency = mode == KeyPicker.Mode and 0 or 1,
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 51,
		})
		btn.MouseButton1Click:Connect(function()
			KeyPicker.Mode = mode
			for _, child in ModeInner:GetChildren() do
				if child:IsA("TextButton") then
					child.BackgroundTransparency = child.Text == mode and 0 or 1
				end
			end
			ModeMenu:Close()
			KeyPicker:Update()
		end)
	end

	function KeyPicker:Display()
		Picker.Text = keyLabel()
	end
	function KeyPicker:GetState()
		if KeyPicker.Value == "None" or not KeyPicker.Bind then
			return false
		end
		if KeyPicker.Mode == "Always" then
			return true
		elseif KeyPicker.Mode == "Toggle" then
			return KeyPicker.Toggled
		elseif KeyPicker.Mode == "Hold" then
			if SpecialInputs[KeyPicker.Bind] then
				return UserInputService:IsMouseButtonPressed(KeyPicker.Bind)
			end
			return UserInputService:IsKeyDown(KeyPicker.Bind)
		end
		return false
	end
	function KeyPicker:OnChanged(func)
		table.insert(KeyPicker.OnChangedFns, func)
	end
	function KeyPicker:SetValue(data)
		local key = data
		if type(data) == "table" then
			key = data[1]
			if data[2] then
				KeyPicker.Mode = data[2]
			end
		end
		local bind = ResolveKey(key)
		KeyPicker.Bind = bind
		KeyPicker.Value = CanonicalKeyName(bind)
		KeyPicker:Display()
		KeyPicker:Update()
		Library:SafeCallback(KeyPicker.ChangedCallback, KeyPicker.Value, KeyPicker.Bind)
	end

	local syncToggle = (info.SyncToggleState and self.Type == "Toggle") and self or nil

	local function fireState()
		local state = KeyPicker:GetState()
		Library:SafeCallback(KeyPicker.Callback, state)
		for _, func in KeyPicker.OnChangedFns do
			Library:SafeCallback(func, state)
		end
		Library:UpdateKeybindRow(KeyPicker)
	end

	function KeyPicker:Update()
		Library:UpdateKeybindRow(KeyPicker)
		if KeyPicker.Mode == "Always" then
			fireState()
		end
	end

	local picking = false
	Picker.MouseButton1Click:Connect(function()
		picking = true
		Picker.Text = "[...]"
	end)
	Picker.MouseButton2Click:Connect(function()
		ModeMenu:Toggle()
	end)

	Library:GiveSignal(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if Library.Unloaded or KeyPicker.Disabled then
			return
		end
		if picking then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					KeyPicker:SetValue("None")
				else
					KeyPicker:SetValue(input.KeyCode)
				end
				picking = false
			elseif SpecialInputs[input.UserInputType] then
				KeyPicker:SetValue(input.UserInputType)
				picking = false
			end
			return
		end

		if gameProcessed or not KeyPicker.Bind or KeyPicker.Value == "None" then
			return
		end
		local matched = (input.KeyCode == KeyPicker.Bind) or (input.UserInputType == KeyPicker.Bind)
		if not matched then
			return
		end
		if KeyPicker.Mode == "Toggle" then
			KeyPicker.Toggled = not KeyPicker.Toggled
			if syncToggle then
				syncToggle:SetValue(KeyPicker.Toggled)
			else
				fireState()
			end
		elseif KeyPicker.Mode == "Hold" or KeyPicker.Mode == "Press" then
			-- Press: one-shot action fired on key-down (GetState stays false, no toggle state)
			fireState()
		end
	end))
	Library:GiveSignal(UserInputService.InputEnded:Connect(function(input)
		if Library.Unloaded or KeyPicker.Disabled or KeyPicker.Mode ~= "Hold" or not KeyPicker.Bind then
			return
		end
		if (input.KeyCode == KeyPicker.Bind) or (input.UserInputType == KeyPicker.Bind) then
			fireState()
		end
	end))

	MakeRecolorable(KeyPicker, Picker, "DimColor")
	MakeDisableable(KeyPicker, {
		{ Picker, "TextTransparency", DISABLED_TEXT_FADE, 0 },
	}, function(on)
		Picker.Interactable = on
	end)

	if syncToggle then
		syncToggle:OnChanged(function()
			KeyPicker.Toggled = syncToggle.Value
			Library:UpdateKeybindRow(KeyPicker)
		end)
	end

	KeyPicker:SetValue(info.Default)
	Library.Options[idx] = KeyPicker
	if not info.NoUI then
		Library:AddKeybindRow(KeyPicker)
	end
	if self.SearchEntry and KeyPicker.Text then
		self.SearchEntry.Text = self.SearchEntry.Text .. " " .. tostring(KeyPicker.Text):lower()
	end
	return self
end

local function HSVToColor(h, s, v)
	return Color3.fromHSV(h, s, v)
end

function BaseAddons:AddColorPicker(idx, info)
	info = Library:Validate(info, {
		Default = Color3.new(1, 1, 1),
		Transparency = 0,
		Title = "Color",
		Callback = function() end,
		Changed = function() end,
	})

	local container = self.AddonContainer
	assert(container, "ColorPicker can only be attached to a Toggle or Label.")

	local ColorPicker = {
		Value = info.Default,
		Transparency = info.Transparency,
		Title = info.Title,
		Type = "ColorPicker",
		Callback = info.Callback,
		Changed = info.Changed,
		OnChangedFns = {},
	}
	local H, S, V = info.Default:ToHSV()
	ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = H, S, V

	local Display = New("TextButton", {
		Parent = container,
		Name = "ColorpickerButton",
		Text = "",
		BackgroundColor3 = "Border",
		BorderColor3 = "DarkBorder",
		Size = UDim2.fromOffset(16, 10),
		ZIndex = 3,
	})
	local Swatch = New("Frame", {
		Parent = Display,
		BackgroundColor3 = info.Default,
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 4,
	})

	local Menu = Library:AddContextMenu(Display, UDim2.fromOffset(142, 146), function()
		return { -126, 14 }
	end, false)
	local Shell = MakeWindowShell(Menu.Menu, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), info.Title)
	Shell.Outline.ZIndex = 50

	local SatOuter = New("Frame", {
		Parent = Shell.Body,
		BackgroundColor3 = "Outline",
		BorderColor3 = "DarkBorder",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 1, -50),
		ZIndex = 51,
	})
	local SatMap = New("TextButton", {
		Parent = SatOuter,
		Text = "",
		BackgroundColor3 = HSVToColor(H, 1, 1),
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 51,
	})
	ColorPicker.SatMap = SatMap
	local SatGradientWhite = New("Frame", {
		Parent = SatMap,
		BackgroundColor3 = "White",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 51,
	})
	New("UIGradient", {
		Parent = SatGradientWhite,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local SatGradientBlack = New("Frame", {
		Parent = SatMap,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 51,
	})
	New("UIGradient", {
		Parent = SatGradientBlack,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})
	local SatCursor = New("Frame", {
		Parent = SatMap,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = "White",
		BorderColor3 = "Border",
		Size = UDim2.fromOffset(3, 3),
		ZIndex = 52,
	})

	local HueOuter = New("Frame", {
		Parent = Shell.Body,
		BackgroundColor3 = "Outline",
		BorderColor3 = "DarkBorder",
		Position = UDim2.new(0, 0, 1, -32),
		Size = UDim2.new(1, 0, 0, 10),
		ZIndex = 51,
	})
	local HueBar = New("TextButton", {
		Parent = HueOuter,
		Text = "",
		BackgroundColor3 = "White",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 51,
	})
	New("UIGradient", {
		Parent = HueBar,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
	})
	local HueCursor = New("Frame", {
		Parent = HueBar,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(204, 41, 41),
		BorderColor3 = Color3.fromRGB(108, 22, 22),
		Size = UDim2.new(0, 1, 1, 0),
		ZIndex = 52,
	})

	local RgbaOuter = New("Frame", {
		Parent = Shell.Body,
		BackgroundColor3 = "Outline",
		BorderColor3 = "DarkBorder",
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 51,
	})
	local RgbaBox = New("TextBox", {
		Parent = RgbaOuter,
		Text = "",
		PlaceholderText = "r, g, b, a",
		PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundColor3 = "Inline",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 51,
	})

	function ColorPicker:Display()
		ColorPicker.Value = HSVToColor(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
		Swatch.BackgroundColor3 = ColorPicker.Value
		SatMap.BackgroundColor3 = HSVToColor(ColorPicker.Hue, 1, 1)
		SatCursor.Position = UDim2.fromScale(ColorPicker.Sat, 1 - ColorPicker.Vib)
		HueCursor.Position = UDim2.fromScale(ColorPicker.Hue, 0)
		local c = ColorPicker.Value
		RgbaBox.Text = string.format(
			"%d, %d, %d, %d",
			math.floor(c.R * 255 + 0.5),
			math.floor(c.G * 255 + 0.5),
			math.floor(c.B * 255 + 0.5),
			math.floor((1 - ColorPicker.Transparency) * 255 + 0.5)
		)
	end
	function ColorPicker:OnChanged(func)
		table.insert(ColorPicker.OnChangedFns, func)
		Library:SafeCallback(func, ColorPicker.Value)
	end
	local function fire()
		Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value)
		Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
		for _, func in ColorPicker.OnChangedFns do
			Library:SafeCallback(func, ColorPicker.Value)
		end
	end
	function ColorPicker:SetValueRGB(color, transparency)
		ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = color:ToHSV()
		ColorPicker.Transparency = transparency or ColorPicker.Transparency
		ColorPicker:Display()
		fire()
	end
	function ColorPicker:GetValue()
		return ColorPicker.Value
	end

	Display.MouseButton1Click:Connect(function()
		Menu:Toggle()
	end)

	local satDrag = false
	local function moveSat(pos)
		local rx = math.clamp((pos.X - SatMap.AbsolutePosition.X) / SatMap.AbsoluteSize.X, 0, 1)
		local ry = math.clamp((pos.Y - SatMap.AbsolutePosition.Y) / SatMap.AbsoluteSize.Y, 0, 1)
		ColorPicker.Sat = rx
		ColorPicker.Vib = 1 - ry
		ColorPicker:Display()
		fire()
	end
	SatMap.InputBegan:Connect(function(input)
		if IsClickInput(input) then
			satDrag = true
			moveSat(input.Position)
		end
	end)
	SatMap.InputEnded:Connect(function(input)
		if IsMouseInput(input) then
			satDrag = false
		end
	end)

	local hueDrag = false
	local function moveHue(pos)
		ColorPicker.Hue = math.clamp((pos.X - HueBar.AbsolutePosition.X) / HueBar.AbsoluteSize.X, 0, 1)
		ColorPicker:Display()
		fire()
	end
	HueBar.InputBegan:Connect(function(input)
		if IsClickInput(input) then
			hueDrag = true
			moveHue(input.Position)
		end
	end)
	HueBar.InputEnded:Connect(function(input)
		if IsMouseInput(input) then
			hueDrag = false
		end
	end)

	Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
		if not IsHoverInput(input) then
			return
		end
		if satDrag then
			moveSat(input.Position)
		elseif hueDrag then
			moveHue(input.Position)
		end
	end))

	RgbaBox.FocusLost:Connect(function()
		local nums = {}
		for token in RgbaBox.Text:gmatch("%-?%d+") do
			table.insert(nums, tonumber(token))
		end
		if #nums >= 3 then
			local color = Color3.fromRGB(
				math.clamp(nums[1], 0, 255),
				math.clamp(nums[2], 0, 255),
				math.clamp(nums[3], 0, 255)
			)
			local transparency = ColorPicker.Transparency
			if nums[4] then
				transparency = 1 - math.clamp(nums[4], 0, 255) / 255
			end
			ColorPicker:SetValueRGB(color, transparency)
		else
			ColorPicker:Display()
		end
	end)

	ColorPicker:Display()
	Library.Options[idx] = ColorPicker
	return self
end

local function MakeGroupbox(side, name, tab)
	local Outline, Inline, Body = MakePanel(side, UDim2.new(1, 0, 0, 0))
	Outline.AutomaticSize = Enum.AutomaticSize.Y
	Body.AutomaticSize = Enum.AutomaticSize.Y

	local Content = New("Frame", {
		Parent = Body,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	New("UIListLayout", { Parent = Content, Padding = UDim.new(0, 8) })
	New("UIPadding", {
		Parent = Content,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})

	local titleLabel
	if name then
		titleLabel = New("TextLabel", {
			Parent = Content,
			Text = name,
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = -1,
		})
	end

	local Groupbox = { Container = Content, Holder = Outline, Type = "Groupbox", Tab = tab, Column = side }
	Groupbox.Reveal = function()
		if tab then
			tab:Show()
		end
	end
	Groupbox.Record = { Chrome = { Outline, Inline, Body, titleLabel }, Entries = {}, Tab = tab, Dimmed = false }
	table.insert(Library.SearchBoxes, Groupbox.Record)
	return setmetatable(Groupbox, { __index = Funcs })
end

local function MakeTabbox(side, tab)
	local Outline, Inline, Body = MakePanel(side, UDim2.new(1, 0, 0, 0))
	Outline.AutomaticSize = Enum.AutomaticSize.Y
	Body.AutomaticSize = Enum.AutomaticSize.Y

	New("UIPadding", {
		Parent = Body,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})

	local Header = New("Frame", {
		Parent = Body,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
	})
	New("UIListLayout", {
		Parent = Header,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local Pages = New("Frame", {
		Parent = Body,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	local Tabbox = { Tabs = {}, ActiveTab = nil, Holder = Outline, Body = Body }
	Tabbox.Record = { Chrome = { Outline, Inline, Body }, Entries = {}, Tab = tab, Owner = Tabbox, Dimmed = false }
	table.insert(Library.SearchBoxes, Tabbox.Record)

	function Tabbox:AddTab(name)
		local SelectButton = New("TextButton", {
			Parent = Header,
			Text = name,
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local Underline = New("Frame", {
			Parent = SelectButton,
			BackgroundColor3 = "Accent",
			BorderColor3 = "Border",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
			Visible = false,
		})

		local Content = New("Frame", {
			Parent = Pages,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = false,
		})
		New("UIListLayout", { Parent = Content, Padding = UDim.new(0, 8) })
		New("UIPadding", {
			Parent = Content,
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
		})

		local SubTab = { Container = Content, Button = SelectButton, Tab = tab, Record = Tabbox.Record, Column = side }
		SubTab.Reveal = function()
			if tab then
				tab:Show()
			end
			SubTab:Show()
		end
		setmetatable(SubTab, { __index = Funcs })

		function SubTab:Show()
			for _, other in Tabbox.Tabs do
				other.Container.Visible = false
				other.Button.TextColor3 = Library.Scheme.DimColor
				other.Underline.Visible = false
			end
			Content.Visible = true
			SelectButton.TextColor3 = Library.Scheme.FontColor
			-- a lone section is always "active"; its underline conveys nothing, so only show it with 2+
			Underline.Visible = #Tabbox.Tabs > 1
			Tabbox.ActiveTab = SubTab
		end
		SubTab.Underline = Underline

		SelectButton.MouseButton1Click:Connect(function()
			SubTab:Show()
		end)

		table.insert(Tabbox.Tabs, SubTab)
		if not Tabbox.ActiveTab then
			SubTab:Show()
		end
		-- this section may have taken the count from 1 -> 2; refresh the active underline accordingly
		if Tabbox.ActiveTab then
			Tabbox.ActiveTab.Underline.Visible = #Tabbox.Tabs > 1
		end
		return SubTab
	end

	return Tabbox
end

local DIM_FACTOR = 0.62
local DimProps = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency", "ImageTransparency" }
local DimState = {}

local function dimInstance(inst, on)
	if on then
		if DimState[inst] then
			return
		end
		local snap = {}
		for _, prop in DimProps do
			local ok, value = pcall(function()
				return inst[prop]
			end)
			if ok and type(value) == "number" then
				snap[prop] = value
				pcall(function()
					inst[prop] = value + (1 - value) * DIM_FACTOR
				end)
			end
		end
		DimState[inst] = snap
	else
		local snap = DimState[inst]
		if not snap then
			return
		end
		for prop, value in snap do
			pcall(function()
				inst[prop] = value
			end)
		end
		DimState[inst] = nil
	end
end

local function dimTree(root, on)
	if not root then
		return
	end
	dimInstance(root, on)
	for _, child in root:GetChildren() do
		dimTree(child, on)
	end
end

local function dimChrome(record, on)
	record.Dimmed = on
	for _, inst in record.Chrome do
		dimInstance(inst, on)
	end
end

function Library:ResetSearch()
	for _, entry in Library.SearchIndex do
		dimTree(entry.Row, false)
		entry.Dimmed = false
	end
	for _, record in Library.SearchBoxes do
		dimChrome(record, false)
	end
	-- intentionally do NOT restore the pre-search tab/sections; leave the user where they are
	Library.Searching = false
end

-- scroll a matched element's column to it; deferred so a just-revealed tab has settled its layout first
local SEARCH_SCROLL_PAD = 8
local function scrollEntryIntoView(entry)
	if not entry then
		return
	end
	local row = entry.Row
	local column = entry.Column
	if not column and row then
		column = row:FindFirstAncestorOfClass("ScrollingFrame")
	end
	if not (row and column) then
		return
	end
	local function apply()
		local rowPos, rowSize = row.AbsolutePosition, row.AbsoluteSize
		local colPos, colSize = column.AbsolutePosition, column.AbsoluteSize
		if not (rowPos and rowSize and colPos and colSize) then
			return
		end
		local canvas = column.CanvasPosition or Vector2.new(0, 0)
		local rowTop = (rowPos.Y - colPos.Y) + canvas.Y
		-- already fully within the visible window: leave the scroll where it is
		if rowTop >= canvas.Y and (rowTop + rowSize.Y) <= (canvas.Y + colSize.Y) then
			return
		end
		local target = math.max(0, rowTop - SEARCH_SCROLL_PAD)
		column.CanvasPosition = Vector2.new(canvas.X, target)
	end
	if task and task.defer then
		task.defer(apply)
	else
		apply()
	end
end

function Library:UpdateSearch(query, enterPressed)
	query = tostring(query or ""):gsub("^%s*(.-)%s*$", "%1"):lower()

	if query == "" then
		Library:ResetSearch()
		return
	end

	Library.Searching = true

	local firstMatch, activeFirstMatch = nil, nil
	for _, entry in Library.SearchIndex do
		local matched = entry.Text:find(query, 1, true) ~= nil
		entry.Dimmed = not matched
		dimTree(entry.Row, not matched)
		if matched then
			firstMatch = firstMatch or entry
			if entry.Tab == Library.ActiveTab and not activeFirstMatch then
				activeFirstMatch = entry
			end
		end
	end

	for _, record in Library.SearchBoxes do
		local anyMatch = false
		for _, entry in record.Entries do
			if not entry.Dimmed then
				anyMatch = true
				break
			end
		end
		dimChrome(record, not anyMatch)
	end

	-- surface the same match the jump policy targets, then scroll its column to it
	local target
	if firstMatch and ((not activeFirstMatch) or enterPressed) then
		if firstMatch.Reveal then
			firstMatch.Reveal()
		end
		target = firstMatch
	elseif activeFirstMatch then
		target = activeFirstMatch
	end
	if target then
		scrollEntryIntoView(target)
	end
end

function Library:CreateWindow(windowInfo)
	windowInfo = Library:Validate(windowInfo, {
		Title = "Sentinel",
		Footer = "",
		Size = UDim2.fromOffset(582, 502),
		Position = UDim2.fromOffset(100, 100),
		ToggleKeybind = Enum.KeyCode.RightControl,
		ShowCustomCursor = false,
		NotifySide = "Left",
		Resizable = false,
		Center = false,
	})

	Library.ToggleKeybind = windowInfo.ToggleKeybind
	Library.ShowCustomCursor = windowInfo.ShowCustomCursor
	Library.NotifySide = windowInfo.NotifySide

	local Shell = MakeWindowShell(ScreenGui, windowInfo.Size, windowInfo.Position, windowInfo.Title)
	local MainOutline = Shell.Outline
	MainOutline.Visible = false

	if windowInfo.Center then
		local view = workspace.CurrentCamera.ViewportSize
		MainOutline.Position = UDim2.fromOffset(
			math.floor((view.X - windowInfo.Size.X.Offset) / 2),
			math.floor((view.Y - windowInfo.Size.Y.Offset) / 2)
		)
	end

	local DragHandle = New("TextButton", {
		Parent = Shell.Body,
		Text = "",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -165, 0, 16),
		ZIndex = 5,
	})
	Library:MakeDraggable(MainOutline, DragHandle, true)

	if windowInfo.Footer and windowInfo.Footer ~= "" then
		New("TextLabel", {
			Parent = Shell.Body,
			Text = windowInfo.Footer,
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 2),
			Size = UDim2.new(0, 100, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Right,
			Interactable = false,
		})
	end

	local SearchOuter = New("Frame", {
		Parent = Shell.Body,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -36, 0, 1),
		Size = UDim2.fromOffset(120, 14),
		ZIndex = 6,
	})
	local SearchBox = New("TextBox", {
		Parent = SearchOuter,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
		TextColor3 = "FontColor",
		TextStrokeTransparency = 0.5,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		ClearTextOnFocus = false,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		ZIndex = 6,
	})
	New("UIPadding", { Parent = SearchBox, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 4) })
	Library.SearchBox = SearchBox

	Library:GiveSignal(SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		Library:UpdateSearch(SearchBox.Text)
	end))
	Library:GiveSignal(SearchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			Library:UpdateSearch(SearchBox.Text, true)
		end
	end))

	local AccentRegion = New("Frame", {
		Parent = Shell.Body,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 1, -18),
	})
	local TabOutline = New("Frame", {
		Parent = AccentRegion,
		BackgroundColor3 = "Outline",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
	})
	New("UIPadding", {
		Parent = TabOutline,
		PaddingTop = UDim.new(0, 1),
		PaddingBottom = UDim.new(0, 1),
		PaddingLeft = UDim.new(0, 1),
		PaddingRight = UDim.new(0, 1),
	})

	local TabStrip = New("Frame", {
		Parent = TabOutline,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 19),
	})
	New("UIListLayout", {
		Parent = TabStrip,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 1),
	})

	local ContentArea = New("Frame", {
		Parent = TabOutline,
		BackgroundColor3 = "Inline",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 1, -20),
	})

	local Window = { Tabs = {} }

	function Window:Toggle(value)
		if typeof(value) == "boolean" then
			Library.Toggled = value
		else
			Library.Toggled = not Library.Toggled
		end
		MainOutline.Visible = Library.Toggled

		if Library.Toggled then
			local binding = Library.ShowCursorBinding
			pcall(RunService.UnbindFromRenderStep, RunService, binding)
			RunService:BindToRenderStep(binding, Enum.RenderPriority.Last.Value, function()
				local show = Library.ShowCustomCursor and Cursor ~= nil
				UserInputService.MouseIconEnabled = not show
				drawCursor(show)
				if not (Library.Toggled and ScreenGui and ScreenGui.Parent) then
					UserInputService.MouseIconEnabled = OriginalMouseIconEnabled
					drawCursor(false)
					RunService:UnbindFromRenderStep(binding)
				end
			end)
		else
			TooltipFrame.Visible = false
			if CurrentMenu then
				CurrentMenu:Close()
			end
		end
	end
	function Library:Toggle(value)
		Window:Toggle(value)
	end

	function Window:ChangeTitle(title)
		Shell.Title.Text = title
	end

	function Window:AddTab(name)
		local TabButtonHolder = New("Frame", {
			Parent = TabStrip,
			Name = "TabInline",
			BackgroundColor3 = "Inline",
			BorderColor3 = "Border",
			Size = UDim2.new(0, 100, 1, 0),
			ZIndex = -1,
		})
		New("UIFlexItem", { Parent = TabButtonHolder, FlexMode = Enum.UIFlexMode.Fill })
		local TabButton = New("TextButton", {
			Parent = TabButtonHolder,
			Name = "TabBackground",
			Text = name,
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0,
			BackgroundColor3 = "Body",
			BorderColor3 = "Border",
			Position = UDim2.fromOffset(1, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 2,
		})

		local Container = New("Frame", {
			Parent = ContentArea,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
		})
		New("UIPadding", {
			Parent = Container,
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		})
		New("UIListLayout", {
			Parent = Container,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
		})

		local function makeSide()
			local _, _, body = MakePanel(Container, UDim2.new(0.5, 0, 1, 0))
			New("UIFlexItem", { Parent = body.Parent.Parent, FlexMode = Enum.UIFlexMode.Fill })
			local Scroll = New("ScrollingFrame", {
				Parent = body,
				BackgroundTransparency = 1,
				BorderColor3 = "Border",
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = "Accent",
				TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
				BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			})
			New("UIListLayout", { Parent = Scroll, Padding = UDim.new(0, 8) })
			New("UIPadding", {
				Parent = Scroll,
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			})
			return Scroll
		end

		local LeftSide = makeSide()
		local RightSide = makeSide()

		local Tab = {
			Name = name,
			Container = Container,
			Button = TabButton,
			ButtonHolder = TabButtonHolder,
			LeftSide = LeftSide,
			RightSide = RightSide,
			Groupboxes = {},
		}

		function Tab:Show()
			for _, other in Window.Tabs do
				other.Container.Visible = false
				other.ButtonHolder.BackgroundColor3 = Library.Scheme.Inline
				other.Button.BackgroundTransparency = 0
			end
			Container.Visible = true
			TabButtonHolder.BackgroundColor3 = Library.Scheme.Accent
			TabButton.BackgroundTransparency = 0.76
			Library.ActiveTab = Tab
		end

		function Tab:AddLeftGroupbox(boxName)
			return MakeGroupbox(LeftSide, boxName, Tab)
		end
		function Tab:AddRightGroupbox(boxName)
			return MakeGroupbox(RightSide, boxName, Tab)
		end
		function Tab:AddLeftTabbox()
			return MakeTabbox(LeftSide, Tab)
		end
		function Tab:AddRightTabbox()
			return MakeTabbox(RightSide, Tab)
		end

		TabButton.MouseButton1Click:Connect(function()
			Tab:Show()
		end)

		table.insert(Window.Tabs, Tab)
		Library.Tabs[name] = Tab
		if #Window.Tabs == 1 then
			Tab:Show()
		end
		return Tab
	end

	Library.Window = Window
	return Window
end

function Library:SetWatermarkVisibility(visible)
	if not Library.Watermark then
		local shell = MakeWindowShell(ScreenGui, UDim2.fromOffset(100, 24), UDim2.fromOffset(16, 16))
		shell.Outline.AutomaticSize = Enum.AutomaticSize.X
		shell.Body.AutomaticSize = Enum.AutomaticSize.X
		local label = New("TextLabel", {
			Parent = shell.Body,
			Text = "",
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 12),
			Position = UDim2.fromOffset(0, 2),
			TextXAlignment = Enum.TextXAlignment.Left,
			Interactable = false,
		})
		Library.Watermark = shell.Outline
		Library.WatermarkLabel = label
		Library:MakeDraggable(shell.Outline, shell.Body)
	end
	Library.Watermark.Visible = visible
end
function Library:SetWatermark(text)
	Library:SetWatermarkVisibility(true)
	Library.WatermarkLabel.Text = text
end

function Library:CreatePlayerList()
	local shell = MakeWindowShell(ScreenGui, UDim2.fromOffset(354, 282), UDim2.fromOffset(620, 16), "playerlist")
	Library:MakeDraggable(shell.Outline, shell.Body)

	local _, _, body = MakePanel(shell.Body, UDim2.new(1, 0, 1, -18), UDim2.fromOffset(0, 18))
	local Scroll = New("ScrollingFrame", {
		Parent = body,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "Accent",
	})
	New("UIListLayout", { Parent = Scroll, Padding = UDim.new(0, 4) })
	New("UIPadding", {
		Parent = Scroll,
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	})

	local PlayerList = { Holder = shell.Outline, Rows = {} }

	function PlayerList:SetPlayers(entries)
		for _, row in PlayerList.Rows do
			row:Destroy()
		end
		table.clear(PlayerList.Rows)
		for _, entry in entries do
			local Row = New("Frame", {
				Parent = Scroll,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14),
			})
			New("UIListLayout", {
				Parent = Row,
				FillDirection = Enum.FillDirection.Horizontal,
			})
			New("UIPadding", { Parent = Row, PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) })
			local function col(text, withDivider)
				local lbl = New("TextLabel", {
					Parent = Row,
					Text = text,
					TextColor3 = Color3.fromRGB(180, 180, 180),
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(0, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				New("UIStroke", { Parent = lbl })
				if withDivider then
					New("Frame", {
						Parent = lbl,
						BackgroundColor3 = "Divider",
						BorderColor3 = "Border",
						Position = UDim2.fromOffset(-10, 0),
						Size = UDim2.fromOffset(1, 12),
					})
				end
				New("UIFlexItem", { Parent = lbl, FlexMode = Enum.UIFlexMode.Fill })
			end
			col(entry.Name or "?")
			col(entry.Status or "None", true)
			col(entry.Team or "Neutral", true)
			table.insert(PlayerList.Rows, Row)
		end
	end

	function PlayerList:SetVisible(v)
		shell.Outline.Visible = v
	end

	function PlayerList:Refresh()
		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)
		local entries = {}
		for _, player in players do
			table.insert(entries, {
				Name = player.Name,
				Status = "None",
				Team = (player.Team and player.Team.Name) or "Neutral",
			})
		end
		PlayerList:SetPlayers(entries)
	end

	Library:GiveSignal(Players.PlayerAdded:Connect(function()
		PlayerList:Refresh()
	end))
	Library:GiveSignal(Players.PlayerRemoving:Connect(function()
		task.defer(function()
			PlayerList:Refresh()
		end)
	end))
	PlayerList:Refresh()

	Library.PlayerList = PlayerList
	return PlayerList
end

-- standalone draggable + corner-resizable chat/log window (not a groupbox component)
function Library:CreateChatLog(info)
	info = Library:Validate(info or {}, {
		Title = "chat",
		MaxLines = 100,
		Width = 300,
		Height = 180,
		Visible = false,
	})

	local shell = MakeWindowShell(ScreenGui, UDim2.fromOffset(info.Width, info.Height), UDim2.fromOffset(300, 300), info.Title)
	shell.Outline.Visible = info.Visible and true or false

	-- drag only via the header strip, so the scroll area + resize handle stay free input regions
	local Header = New("Frame", {
		Parent = shell.Body,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 5,
	})
	Library:MakeDraggable(shell.Outline, Header)

	local _, _, body = MakePanel(shell.Body, UDim2.new(1, 0, 1, -18), UDim2.fromOffset(0, 18))
	local Scroll = New("ScrollingFrame", {
		Parent = body,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "Accent",
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
	})
	New("UIListLayout", { Parent = Scroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) })
	New("UIPadding", {
		Parent = Scroll,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 3),
	})

	-- bottom-right resize grip; Active so it sinks input (doesn't scroll/drag underneath)
	local ResizeHandle = New("Frame", {
		Parent = shell.Outline,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -1, 1, -1),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 20,
		Active = true,
	})

	local ChatLog = {
		Holder = shell.Outline,
		Scroll = Scroll,
		Header = Header,
		ResizeHandle = ResizeHandle,
		Lines = {},
		MaxLines = math.max(1, math.floor(info.MaxLines)),
		_counter = 0,
	}

	local setSize = Library:MakeResizable(shell.Outline, ResizeHandle, Vector2.new(160, 90), Vector2.new(720, 540))

	-- pinned only when the user is already at/near the bottom; if they scrolled up, leave them
	local function isAtBottom()
		local ok, atBottom = pcall(function()
			local canvas = Scroll.AbsoluteCanvasSize
			local window = Scroll.AbsoluteWindowSize or Scroll.AbsoluteSize
			local maxScroll = math.max(0, canvas.Y - window.Y)
			return Scroll.CanvasPosition.Y >= maxScroll - 4
		end)
		return (not ok) or atBottom
	end
	local function pinBottom()
		local function apply()
			pcall(function()
				Scroll.CanvasPosition = Vector2.new(0, 1e7)
			end)
		end
		if task and task.defer then
			task.defer(apply)
		else
			apply()
		end
	end

	function ChatLog:Add(text)
		text = tostring(text)
		local pinned = isAtBottom()
		local order = self._counter
		self._counter = order + 1
		local label = New("TextLabel", {
			Parent = Scroll,
			Name = "Line",
			Text = text,
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			LayoutOrder = order,
		})
		table.insert(self.Lines, { Text = text, Label = label })
		while #self.Lines > self.MaxLines do
			local oldest = table.remove(self.Lines, 1)
			if oldest and oldest.Label then
				pcall(function()
					oldest.Label:Destroy()
				end)
			end
		end
		if pinned then
			pinBottom()
		end
		return label
	end

	function ChatLog:Clear()
		for _, line in self.Lines do
			if line.Label then
				pcall(function()
					line.Label:Destroy()
				end)
			end
		end
		table.clear(self.Lines)
		self._counter = 0
	end

	function ChatLog:SetLines(lines)
		self:Clear()
		if type(lines) == "table" then
			for _, text in lines do
				self:Add(text)
			end
		end
	end

	function ChatLog:GetLines()
		local out = {}
		for i, line in self.Lines do
			out[i] = line.Text
		end
		return out
	end

	-- resize by a delta from the current size (clamped); the corner handle drives the same setSize
	function ChatLog:Resize(dx, dy)
		return setSize(shell.Outline.Size.X.Offset + (dx or 0), shell.Outline.Size.Y.Offset + (dy or 0))
	end

	function ChatLog:SetVisible(v)
		shell.Outline.Visible = v and true or false
	end
	function ChatLog:Show()
		self:SetVisible(true)
	end
	function ChatLog:Hide()
		self:SetVisible(false)
	end

	Library.ChatLog = ChatLog
	return ChatLog
end

-- standalone, domain-neutral macro-creator window: an editable step sequence the consumer drives off GetSequence()
function Library:CreateMacroCreator(info)
	info = info or {}
	local onSave, onLoad, onDelete, onClear, onSelect = info.OnSave, info.OnLoad, info.OnDelete, info.OnClear, info.OnSelect
	info = Library:Validate(info, {
		Title = "macro creator",
		Width = 320,
		Height = 364,
		Visible = false,
	})

	local shell = MakeWindowShell(ScreenGui, UDim2.fromOffset(info.Width, info.Height), UDim2.fromOffset(330, 120), info.Title)
	shell.Outline.Visible = info.Visible and true or false

	local Header = New("Frame", {
		Parent = shell.Body,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 5,
	})
	Library:MakeDraggable(shell.Outline, Header)

	local CloseBtn = New("TextButton", {
		Parent = shell.Body,
		Text = "X",
		TextColor3 = "FontColor",
		TextStrokeTransparency = 0.5,
		TextSize = 16,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 8,
	})

	-- name + saved-macro picker so the window is a self-contained editor (load/delete an existing macro)
	local NameBox = New("TextBox", {
		Parent = shell.Body,
		Text = "",
		PlaceholderText = "macro name",
		PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
		TextColor3 = "FontColor",
		TextStrokeTransparency = 0.5,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		ClearTextOnFocus = false,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, -18, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	})
	New("UIPadding", { Parent = NameBox, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 4) })

	local SavedRow = New("Frame", {
		Parent = shell.Body,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 15),
		ZIndex = 6,
	})
	New("UIListLayout", {
		Parent = SavedRow,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 3),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local SavedOuter = New("Frame", {
		Parent = SavedRow,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Size = UDim2.new(0, 0, 0, 15),
		ZIndex = 6,
	})
	New("UIFlexItem", { Parent = SavedOuter, FlexMode = Enum.UIFlexMode.Fill })
	local SavedBtn = New("TextButton", {
		Parent = SavedOuter,
		Text = "saved macros",
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		AutoButtonColor = false,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
	})
	New("UIPadding", { Parent = SavedBtn, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 12) })
	New("TextLabel", {
		Parent = SavedBtn,
		Text = "+",
		TextColor3 = "DimColor",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 2, 0.5, 0),
		Size = UDim2.fromOffset(8, 12),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
	})
	local function savedActionBtn(text, width)
		return New("TextButton", {
			Parent = SavedRow,
			Text = text,
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			AutoButtonColor = false,
			Size = UDim2.new(0, width, 0, 15),
			ZIndex = 7,
		})
	end
	local LoadBtn = savedActionBtn("Load", 40)
	local DeleteBtn = savedActionBtn("Delete", 50)

	local Toolbar = New("Frame", {
		Parent = shell.Body,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 6,
	})
	New("UIListLayout", {
		Parent = Toolbar,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 3),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local function toolButton(text, width)
		return New("TextButton", {
			Parent = Toolbar,
			Text = text,
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			AutoButtonColor = false,
			Size = UDim2.new(0, width, 0, 15),
			ZIndex = 7,
		})
	end
	local AddBtn = toolButton("+ Add", 50)
	local SaveBtn = toolButton("Save", 44)
	local ClearBtn = toolButton("Clear", 44)

	local _, _, listBody = MakePanel(shell.Body, UDim2.new(1, 0, 1, -72), UDim2.fromOffset(0, 72))
	local Scroll = New("ScrollingFrame", {
		Parent = listBody,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "Accent",
	})
	New("UIListLayout", { Parent = Scroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	New("UIPadding", {
		Parent = Scroll,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 3),
	})

	-- add-step popup: a small floating menu of every registered type, toggled by the Add button
	local Menu = New("Frame", {
		Parent = shell.Outline,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		BorderSizePixel = 1,
		Position = UDim2.fromOffset(5, 91),
		Size = UDim2.fromOffset(112, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 40,
	})
	local MenuInner = New("Frame", {
		Parent = Menu,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 41,
	})
	New("UIListLayout", { Parent = MenuInner, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) })
	New("UIPadding", {
		Parent = MenuInner,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	})

	local ResizeHandle = New("Frame", {
		Parent = shell.Outline,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -1, 1, -1),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 50,
		Active = true,
	})

	local Macro = {
		Holder = shell.Outline,
		Scroll = Scroll,
		Header = Header,
		NameBox = NameBox,
		ResizeHandle = ResizeHandle,
		Steps = {},
		StepTypes = {},
		_order = {},
		OnSave = onSave,
		OnLoad = onLoad,
		OnDelete = onDelete,
		OnClear = onClear,
		OnSelect = onSelect,
	}

	local setSize = Library:MakeResizable(shell.Outline, ResizeHandle, Vector2.new(230, 210), Vector2.new(560, 560))

	local savedNames, selectedName = {}, nil
	local SavedMenu = Library:AddContextMenu(SavedOuter, function()
		return UDim2.fromOffset(SavedOuter.AbsoluteSize.X, 0)
	end, function()
		return { 0, SavedOuter.AbsoluteSize.Y + 1 }
	end, 1)
	local SListOuter = New("Frame", {
		Parent = SavedMenu.Menu,
		BackgroundColor3 = "Dark",
		BorderColor3 = "DarkBorder",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
	})
	New("UIPadding", { Parent = SListOuter, PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) })
	local SListInner = New("Frame", {
		Parent = SListOuter,
		BackgroundColor3 = "Element",
		BorderColor3 = "ElementBorder",
		BorderSizePixel = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
	})
	local SItemList = New("Frame", {
		Parent = SListInner,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
	})
	New("UIListLayout", { Parent = SItemList, Padding = UDim.new(0, 2) })
	New("UIPadding", { Parent = SItemList, PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) })
	local function buildSavedMenu()
		for _, c in SItemList:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for _, name in ipairs(savedNames) do
			local item = New("TextButton", {
				Parent = SItemList,
				Text = name,
				TextColor3 = "DimColor",
				TextStrokeTransparency = 0.5,
				BackgroundColor3 = "Pop",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 51,
			})
			New("UIPadding", { Parent = item, PaddingLeft = UDim.new(0, 5) })
			item.MouseButton1Click:Connect(function()
				selectedName = name
				SavedBtn.Text = name
				NameBox.Text = name
				SavedMenu:Close()
				if Macro.OnSelect then
					Library:SafeCallback(Macro.OnSelect, name)
				end
			end)
		end
		SavedMenu:SetSize(UDim2.fromOffset(SavedOuter.AbsoluteSize.X, math.min(#savedNames, 8) * 16 + 8))
	end
	SavedBtn.MouseButton1Click:Connect(function()
		if #savedNames == 0 then
			return
		end
		buildSavedMenu()
		SavedMenu:Toggle()
	end)

	local KEY_NONE = "None"
	local activeCapture
	Library:GiveSignal(UserInputService.InputBegan:Connect(function(input)
		if activeCapture and input.UserInputType == Enum.UserInputType.Keyboard then
			local name = input.KeyCode == Enum.KeyCode.Escape and KEY_NONE or input.KeyCode.Name
			activeCapture(name)
			activeCapture = nil
		end
	end))

	-- field editor; writes straight back into step.data[field.Key] on edit. no hardcoded font.
	local function makeEditor(parent, field, step)
		local kind = field.Kind
		if kind == "number" or kind == "text" then
			local box = New("TextBox", {
				Parent = parent,
				Text = tostring(step.data[field.Key] ~= nil and step.data[field.Key] or (field.Default ~= nil and field.Default or "")),
				PlaceholderText = field.Placeholder or "",
				PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
				TextColor3 = "FontColor",
				TextStrokeTransparency = 0.5,
				BackgroundColor3 = "Element",
				BorderColor3 = "ElementBorder",
				BorderSizePixel = 1,
				ClearTextOnFocus = false,
				Size = UDim2.new(0, field.Width or 44, 0, 14),
				ZIndex = 12,
			})
			box.FocusLost:Connect(function()
				if kind == "number" then
					local n = tonumber(box.Text)
					if n == nil then
						n = field.Default or 0
					end
					step.data[field.Key] = n
					box.Text = tostring(n)
				else
					step.data[field.Key] = box.Text
				end
			end)
			return box
		elseif kind == "choice" then
			local options = field.Options or { "a", "b" }
			step.data[field.Key] = step.data[field.Key] or field.Default or options[1]
			local btn = New("TextButton", {
				Parent = parent,
				Text = tostring(step.data[field.Key]),
				TextColor3 = "FontColor",
				TextStrokeTransparency = 0.5,
				BackgroundColor3 = "Element",
				BorderColor3 = "ElementBorder",
				BorderSizePixel = 1,
				AutoButtonColor = false,
				Size = UDim2.new(0, field.Width or 44, 0, 14),
				ZIndex = 12,
			})
			btn.MouseButton1Click:Connect(function()
				local idx = table.find(options, step.data[field.Key]) or 0
				local nextOpt = options[(idx % #options) + 1]
				step.data[field.Key] = nextOpt
				btn.Text = tostring(nextOpt)
			end)
			return btn
		elseif kind == "key" then
			step.data[field.Key] = step.data[field.Key] or field.Default or KEY_NONE
			local btn = New("TextButton", {
				Parent = parent,
				Text = "[" .. tostring(step.data[field.Key]) .. "]",
				TextColor3 = "FontColor",
				TextStrokeTransparency = 0.5,
				BackgroundColor3 = "Element",
				BorderColor3 = "ElementBorder",
				BorderSizePixel = 1,
				AutoButtonColor = false,
				Size = UDim2.new(0, field.Width or 58, 0, 14),
				ZIndex = 12,
			})
			btn.MouseButton1Click:Connect(function()
				btn.Text = "[...]"
				activeCapture = function(name)
					step.data[field.Key] = name
					btn.Text = "[" .. name .. "]"
				end
			end)
			return btn
		end
	end

	local function indexOf(s)
		for i, st in ipairs(Macro.Steps) do
			if st == s then
				return i
			end
		end
		return nil
	end
	local function renumber()
		for i, st in ipairs(Macro.Steps) do
			st.Row.LayoutOrder = i
			if st._index then
				st._index.Text = i .. "."
			end
		end
	end

	local function buildMenu()
		for _, c in MenuInner:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for order, name in ipairs(Macro._order) do
			local cfg = Macro.StepTypes[name]
			local b = New("TextButton", {
				Parent = MenuInner,
				Text = cfg.Label or name,
				TextColor3 = cfg.Color or "FontColor",
				TextStrokeTransparency = 0.5,
				BackgroundColor3 = "Element",
				BorderColor3 = "ElementBorder",
				BorderSizePixel = 1,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 15),
				LayoutOrder = order,
				ZIndex = 42,
			})
			b.MouseButton1Click:Connect(function()
				Macro:AddStep(name)
				Menu.Visible = false
			end)
		end
	end

	local function makeRow(step)
		local row = New("Frame", {
			Parent = Scroll,
			Name = "Step",
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			Size = UDim2.new(1, 0, 0, 18),
		})
		step.Row = row
		step._index = New("TextLabel", {
			Parent = row,
			Name = "Index",
			Text = "",
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(3, 0),
			Size = UDim2.fromOffset(16, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
		})
		local left = New("Frame", {
			Parent = row,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(1, -74, 1, 0),
			ZIndex = 11,
		})
		New("UIListLayout", {
			Parent = left,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		local cfg = Macro.StepTypes[step.type] or { Label = step.type }
		New("TextLabel", {
			Parent = left,
			Name = "Type",
			Text = cfg.Label or step.type,
			TextColor3 = cfg.Color or "FontColor",
			TextStrokeTransparency = 0,
			BackgroundTransparency = 1,
			-- min width so every type label reserves the same column → the editable fields line up
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(70, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
		})
		for _, field in ipairs(cfg.Fields or {}) do
			makeEditor(left, field, step)
		end
		local right = New("Frame", {
			Parent = row,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(50, 16),
			ZIndex = 11,
		})
		New("UIListLayout", {
			Parent = right,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		local function actBtn(text, order)
			return New("TextButton", {
				Parent = right,
				Text = text,
				TextColor3 = "FontColor",
				TextStrokeTransparency = 0.5,
				TextSize = 12,
				BackgroundColor3 = "Dark",
				BorderColor3 = "DarkBorder",
				BorderSizePixel = 1,
				AutoButtonColor = false,
				Size = UDim2.fromOffset(15, 14),
				LayoutOrder = order,
				ZIndex = 12,
			})
		end
		actBtn("▲", 1).MouseButton1Click:Connect(function()
			Macro:MoveStep(step, -1)
		end)
		actBtn("▼", 2).MouseButton1Click:Connect(function()
			Macro:MoveStep(step, 1)
		end)
		actBtn("X", 3).MouseButton1Click:Connect(function()
			Macro:RemoveStep(step)
		end)
		return row
	end

	function Macro:RegisterStepType(name, config)
		config = config or {}
		if not self.StepTypes[name] then
			table.insert(self._order, name)
		end
		self.StepTypes[name] = config
		buildMenu()
		return self
	end

	function Macro:AddStep(typeKey, data)
		local cfg = self.StepTypes[typeKey]
		if not cfg then
			return nil
		end
		local step = { type = typeKey, data = {} }
		for _, field in ipairs(cfg.Fields or {}) do
			if data and data[field.Key] ~= nil then
				step.data[field.Key] = data[field.Key]
			else
				step.data[field.Key] = field.Default
			end
		end
		if data then
			for k, v in data do
				if k ~= "type" and step.data[k] == nil then
					step.data[k] = v
				end
			end
		end
		makeRow(step)
		table.insert(self.Steps, step)
		renumber()
		return step
	end

	function Macro:RemoveStep(ref)
		local i = type(ref) == "number" and ref or indexOf(ref)
		if not i then
			return
		end
		local step = self.Steps[i]
		if step and step.Row then
			pcall(function()
				step.Row:Destroy()
			end)
		end
		table.remove(self.Steps, i)
		renumber()
	end

	function Macro:MoveStep(ref, delta)
		local i = type(ref) == "number" and ref or indexOf(ref)
		if not i then
			return
		end
		local j = i + delta
		if j < 1 or j > #self.Steps then
			return
		end
		self.Steps[i], self.Steps[j] = self.Steps[j], self.Steps[i]
		renumber()
	end

	function Macro:GetSequence()
		local out = {}
		for _, st in ipairs(self.Steps) do
			local s = { type = st.type }
			for k, v in st.data do
				s[k] = v
			end
			table.insert(out, s)
		end
		return out
	end

	function Macro:Clear()
		for _, st in ipairs(self.Steps) do
			if st.Row then
				pcall(function()
					st.Row:Destroy()
				end)
			end
		end
		table.clear(self.Steps)
		renumber()
		NameBox.Text = ""
		selectedName = nil
		SavedBtn.Text = "saved macros"
		if self.OnClear then
			Library:SafeCallback(self.OnClear)
		end
	end

	function Macro:SetSequence(list)
		self:Clear()
		if type(list) == "table" then
			for _, s in ipairs(list) do
				if type(s) == "table" and s.type then
					self:AddStep(s.type, s)
				end
			end
		end
	end

	function Macro:GetName()
		return NameBox.Text
	end
	function Macro:SetName(name)
		NameBox.Text = tostring(name or "")
	end
	function Macro:SetSavedList(names)
		savedNames = names or {}
		if #savedNames == 0 then
			SavedBtn.Text = "saved macros"
			selectedName = nil
		end
		buildSavedMenu()
	end

	function Macro:Save()
		if self.OnSave then
			Library:SafeCallback(self.OnSave, self:GetSequence())
		end
	end
	function Macro:Load(name)
		name = name or selectedName or NameBox.Text
		if self.OnLoad then
			local seq = self.OnLoad(name)
			if type(seq) == "table" then
				-- SetSequence->Clear wipes the name/selection; restore the loaded macro's identity so it shows + Save overwrites it
				local loaded = NameBox.Text ~= "" and NameBox.Text or name
				self:SetSequence(seq)
				if loaded ~= "" then
					NameBox.Text = loaded
					selectedName = loaded
					SavedBtn.Text = loaded
					if self.OnSelect then
						Library:SafeCallback(self.OnSelect, loaded)
					end
				end
			end
		end
	end
	function Macro:Delete(name)
		name = name or selectedName or NameBox.Text
		if name ~= "" and self.OnDelete then
			Library:SafeCallback(self.OnDelete, name)
		end
	end

	function Macro:SetVisible(v)
		shell.Outline.Visible = v and true or false
		if not v then
			Menu.Visible = false
		end
	end
	function Macro:Show()
		self:SetVisible(true)
	end
	function Macro:Hide()
		self:SetVisible(false)
	end
	function Macro:Toggle()
		self:SetVisible(not shell.Outline.Visible)
	end
	function Macro:Resize(dx, dy)
		return setSize(shell.Outline.Size.X.Offset + (dx or 0), shell.Outline.Size.Y.Offset + (dy or 0))
	end

	CloseBtn.MouseButton1Click:Connect(function()
		Macro:Hide()
	end)
	AddBtn.MouseButton1Click:Connect(function()
		Menu.Visible = not Menu.Visible
	end)
	SaveBtn.MouseButton1Click:Connect(function()
		Macro:Save()
	end)
	LoadBtn.MouseButton1Click:Connect(function()
		Macro:Load()
	end)
	DeleteBtn.MouseButton1Click:Connect(function()
		Macro:Delete()
	end)
	ClearBtn.MouseButton1Click:Connect(function()
		Macro:Clear()
	end)

	Macro:RegisterStepType("wait", { Label = "Wait", Color = Color3.fromRGB(255, 170, 0), Fields = { { Key = "duration", Kind = "number", Default = 0.1, Width = 38 } } })
	Macro:RegisterStepType("keypress", { Label = "Key Press", Color = Color3.fromRGB(68, 221, 255), Fields = { { Key = "key", Kind = "key", Default = "None" } } })
	Macro:RegisterStepType("click", { Label = "Click", Color = Color3.fromRGB(80, 255, 120), Fields = { { Key = "button", Kind = "choice", Options = { "left", "right" }, Default = "left", Width = 40 } } })
	Macro:RegisterStepType("comment", { Label = "Comment", Color = Color3.fromRGB(150, 150, 150), Fields = { { Key = "text", Kind = "text", Default = "", Width = 130 } } })

	if not Macro.OnSave then
		SaveBtn.Visible = false
	end
	if not Macro.OnLoad then
		LoadBtn.Visible = false
	end
	if not Macro.OnDelete then
		DeleteBtn.Visible = false
	end

	Library.MacroCreator = Macro
	return Macro
end

-- standalone, domain-neutral waypoint-path editor: a point is a position + consumer-named kind, every edit routes through callbacks
function Library:CreatePathEditor(info)
	info = info or {}
	local cb = {
		Read = info.Read,
		OnField = info.OnField,
		OnKind = info.OnKind,
		OnMove = info.OnMove,
		OnDelete = info.OnDelete,
		OnRecapture = info.OnRecapture,
		OnInsert = info.OnInsert,
		OnAppend = info.OnAppend,
		OnAppendAction = info.OnAppendAction,
		OnSave = info.OnSave,
		OnCondition = info.OnCondition,
		OnRefresh = info.OnRefresh,
		OnClose = info.OnClose,
	}
	local kinds = info.Kinds or {}
	-- optional per-point condition: consumer supplies Vars/Ops, the editor renders an "if" sub-line
	local condCfg = info.Condition
	local condVars = (condCfg and condCfg.Vars) or {}
	local condOps = (condCfg and condCfg.Ops) or { ">=", "<=" }
	local condUnit = (condCfg and condCfg.Unit) or ""
	local condDefault = (condCfg and condCfg.Default) or 0
	info = Library:Validate(info, {
		Title = "path editor",
		Width = 520,
		Height = 344,
		Visible = false,
	})

	local kindByKey, kindOrder = {}, {}
	for _, k in ipairs(kinds) do
		kindByKey[k.key] = k
		table.insert(kindOrder, k.key)
	end
	local function nextKind(key)
		if #kindOrder == 0 then
			return key
		end
		local i = table.find(kindOrder, key) or 0
		return kindOrder[(i % #kindOrder) + 1]
	end
	local function prevKind(key)
		if #kindOrder == 0 then
			return key
		end
		local i = table.find(kindOrder, key) or 1
		return kindOrder[((i - 2) % #kindOrder) + 1]
	end
	local BASE_TITLE = info.Title

	local shell = MakeWindowShell(ScreenGui, UDim2.fromOffset(info.Width, info.Height), UDim2.fromOffset(360, 130), info.Title)
	shell.Outline.Visible = info.Visible and true or false

	local Header = New("Frame", {
		Parent = shell.Body,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 5,
	})
	Library:MakeDraggable(shell.Outline, Header)

	local CloseBtn = New("TextButton", {
		Parent = shell.Body,
		Text = "X",
		TextColor3 = "FontColor",
		TextStrokeTransparency = 0.5,
		TextSize = 16,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 8,
	})

	local Toolbar = New("Frame", {
		Parent = shell.Body,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 6,
	})
	New("UIListLayout", {
		Parent = Toolbar,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 3),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local function toolButton(text, width)
		return New("TextButton", {
			Parent = Toolbar,
			Text = text,
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			AutoButtonColor = false,
			Size = UDim2.new(0, width, 0, 15),
			ZIndex = 7,
		})
	end
	local AddBtn = toolButton("+ Add @ Me", 74)
	local ActionBtn = cb.OnAppendAction and toolButton("+ Action", 58) or nil
	local RefreshBtn = toolButton("Refresh", 54)
	local SaveBtn = toolButton("Save", 44)

	-- one static legend so the terse row glyphs are self-explanatory (no per-row tooltips to leak)
	New("TextLabel", {
		Parent = shell.Body,
		Text = "+ insert at you   @ move here   \xE2\x96\xB2\xE2\x96\xBC reorder   X delete   (click type to change)",
		TextColor3 = "DimColor",
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 36),
		Size = UDim2.new(1, -4, 0, 12),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 6,
	})

	local _, _, listBody = MakePanel(shell.Body, UDim2.new(1, 0, 1, -52), UDim2.fromOffset(0, 52))
	local Scroll = New("ScrollingFrame", {
		Parent = listBody,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "Accent",
	})
	New("UIListLayout", { Parent = Scroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	New("UIPadding", {
		Parent = Scroll,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 3),
	})

	local ResizeHandle = New("Frame", {
		Parent = shell.Outline,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -1, 1, -1),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 50,
		Active = true,
	})

	local PathEditor = {
		Holder = shell.Outline,
		Scroll = Scroll,
		Header = Header,
		Title = shell.Title,
		ResizeHandle = ResizeHandle,
		Rows = {},
	}

	local setSize = Library:MakeResizable(shell.Outline, ResizeHandle, Vector2.new(504, 180), Vector2.new(620, 620))

	-- inline field editor (number/text); commits straight back through OnField on FocusLost
	local function makeEditor(parent, field, index)
		local box = New("TextBox", {
			Parent = parent,
			Text = tostring(field.Value ~= nil and field.Value or (field.Default ~= nil and field.Default or "")),
			PlaceholderText = field.Placeholder or "",
			PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			ClearTextOnFocus = false,
			Size = UDim2.new(0, field.Width or 44, 0, 14),
			ZIndex = 12,
		})
		box.FocusLost:Connect(function()
			local value = box.Text
			if field.Kind == "number" then
				local n = tonumber(box.Text)
				if n == nil then
					n = field.Default or 0
				end
				value = n
				box.Text = tostring(n)
			end
			PathEditor:SetField(index, field.Key, value)
		end)
		return box
	end

	-- the "if <var> <op> <value>" sub-line; cycle buttons mutate point.condition in place via OnCondition
	local function makeConditionLine(row, point, index)
		local cond = point.condition
		local line = New("Frame", {
			Parent = row,
			Name = "Condition",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 2,
		})
		New("UIListLayout", {
			Parent = line,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		New("UIPadding", { Parent = line, PaddingLeft = UDim.new(0, 26) })
		New("TextLabel", {
			Parent = line,
			Text = "if",
			TextColor3 = "Accent",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 14),
			ZIndex = 12,
		})
		local function cycleBtn(options, key, width)
			local btn = New("TextButton", {
				Parent = line,
				Text = tostring(cond[key]),
				TextColor3 = "FontColor",
				TextStrokeTransparency = 0.5,
				BackgroundColor3 = "Element",
				BorderColor3 = "ElementBorder",
				BorderSizePixel = 1,
				AutoButtonColor = false,
				Size = UDim2.fromOffset(width, 14),
				ZIndex = 12,
			})
			btn.MouseButton1Click:Connect(function()
				if #options == 0 then
					return
				end
				local at = table.find(options, cond[key]) or 0
				cond[key] = options[(at % #options) + 1]
				btn.Text = tostring(cond[key])
				PathEditor:SetCondition(index, cond)
			end)
			btn.MouseButton2Click:Connect(function()
				if #options == 0 then
					return
				end
				local at = table.find(options, cond[key]) or 1
				cond[key] = options[((at - 2) % #options) + 1]
				btn.Text = tostring(cond[key])
				PathEditor:SetCondition(index, cond)
			end)
			return btn
		end
		cycleBtn(condVars, "var", 92)
		cycleBtn(condOps, "op", 32)
		local valBox = New("TextBox", {
			Parent = line,
			Text = tostring(cond.value or 0),
			TextColor3 = "FontColor",
			TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			ClearTextOnFocus = false,
			Size = UDim2.fromOffset(34, 14),
			ZIndex = 12,
		})
		valBox.FocusLost:Connect(function()
			local n = tonumber(valBox.Text) or cond.value or 0
			cond.value = n
			valBox.Text = tostring(n)
			PathEditor:SetCondition(index, cond)
		end)
		if condUnit ~= "" then
			New("TextLabel", {
				Parent = line,
				Text = condUnit,
				TextColor3 = "DimColor",
				TextStrokeTransparency = 0.5,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 14),
				ZIndex = 12,
			})
		end
		return line
	end

	local function makeRow(point, index)
		local kindKey = point.kind
		local kindCfg = kindByKey[kindKey]
		if not kindCfg then
			kindCfg = (kindOrder[1] and kindByKey[kindOrder[1]]) or { label = tostring(kindKey), color = "FontColor", fields = {} }
		end

		-- a fixed 18px "Main" line + an optional 16px "Condition" line; AutomaticSize.Y wraps both
		local row = New("Frame", {
			Parent = Scroll,
			Name = "Point",
			BackgroundColor3 = "Element",
			BorderColor3 = "ElementBorder",
			BorderSizePixel = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
		})
		New("UIListLayout", { Parent = row, SortOrder = Enum.SortOrder.LayoutOrder })
		row.MouseEnter:Connect(function()
			row.BackgroundColor3 = Library.Scheme.Pop
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundColor3 = Library.Scheme.Element
		end)

		local main = New("Frame", {
			Parent = row,
			Name = "Main",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
		})
		-- fixed-offset columns (index | type | coords | fields | buttons) so the edit fields line up
		New("TextLabel", {
			Parent = main,
			Name = "Index",
			Text = index .. ".",
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.fromOffset(20, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
		})
		local TypeBtn = New("TextButton", {
			Parent = main,
			Name = "Type",
			Text = kindCfg.label or kindKey,
			TextColor3 = kindCfg.color or "FontColor",
			TextStrokeTransparency = 0,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.fromOffset(44, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
		})
		TypeBtn.MouseButton1Click:Connect(function()
			PathEditor:SetKind(index, nextKind(kindKey))
		end)
		TypeBtn.MouseButton2Click:Connect(function()
			PathEditor:SetKind(index, prevKind(kindKey))
		end)
		local positional = kindCfg.Positional ~= false
		New("TextLabel", {
			Parent = main,
			Name = "Coords",
			Text = positional and string.format("(%d, %d, %d)", Round(point.x or 0), Round(point.y or 0), Round(point.z or 0)) or "",
			TextColor3 = "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(72, 0),
			Size = UDim2.fromOffset(100, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 11,
		})
		local hasArea = positional and point.area and point.area ~= ""
		New("TextLabel", {
			Parent = main,
			Name = "Area",
			RichText = true,
			Text = hasArea and ("<b>" .. point.area .. "</b>") or (positional and "-" or ""),
			TextColor3 = hasArea and "Accent" or "DimColor",
			TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(176, 0),
			Size = UDim2.fromOffset(112, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 11,
		})
		local fieldHolder = New("Frame", {
			Parent = main,
			Name = "Fields",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(292, 0),
			Size = UDim2.new(1, -404, 1, 0),
			ZIndex = 11,
		})
		New("UIListLayout", {
			Parent = fieldHolder,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		for _, field in ipairs(kindCfg.fields or {}) do
			makeEditor(fieldHolder, {
				Key = field.Key,
				Kind = field.Kind,
				Default = field.Default,
				Width = field.Width,
				Placeholder = field.Placeholder,
				Value = point[field.Key],
			}, index)
		end

		local right = New("Frame", {
			Parent = main,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(104, 16),
			ZIndex = 11,
		})
		New("UIListLayout", {
			Parent = right,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		local function actBtn(text, order)
			return New("TextButton", {
				Parent = right,
				Text = text,
				TextColor3 = "FontColor",
				TextStrokeTransparency = 0.5,
				TextSize = 12,
				BackgroundColor3 = "Dark",
				BorderColor3 = "DarkBorder",
				BorderSizePixel = 1,
				AutoButtonColor = false,
				Size = UDim2.fromOffset(15, 14),
				LayoutOrder = order,
				ZIndex = 12,
			})
		end
		actBtn("+", 1).MouseButton1Click:Connect(function()
			PathEditor:Insert(index)
		end)
		actBtn("@", 2).MouseButton1Click:Connect(function()
			PathEditor:Recapture(index)
		end)
		actBtn("\xE2\x96\xB2", 3).MouseButton1Click:Connect(function()
			PathEditor:Move(index, -1)
		end)
		actBtn("\xE2\x96\xBC", 4).MouseButton1Click:Connect(function()
			PathEditor:Move(index, 1)
		end)
		actBtn("X", 5).MouseButton1Click:Connect(function()
			PathEditor:Delete(index)
		end)
		if condCfg then
			local condBtn = actBtn("?", 6)
			if point.condition then
				condBtn.TextColor3 = Library.Scheme.Accent
			end
			condBtn.MouseButton1Click:Connect(function()
				if point.condition then
					PathEditor:SetCondition(index, nil)
				else
					PathEditor:SetCondition(index, { var = condVars[1], op = condOps[1], value = condDefault })
				end
				PathEditor:Refresh()
			end)
		end

		if condCfg and point.condition then
			makeConditionLine(row, point, index)
		end

		table.insert(PathEditor.Rows, row)
		return row
	end

	-- defer so AutomaticCanvasSize has settled before we read row/canvas extents; index nil means jump to the bottom
	local function scrollToIndex(index)
		local function apply()
			pcall(function()
				local row = index and PathEditor.Rows[index]
				if not row then
					Scroll.CanvasPosition = Vector2.new(0, 1e7)
					return
				end
				local maxScroll = math.max(0, Scroll.AbsoluteCanvasSize.Y - (Scroll.AbsoluteWindowSize or Scroll.AbsoluteSize).Y)
				local rel = row.AbsolutePosition.Y - Scroll.AbsolutePosition.Y + Scroll.CanvasPosition.Y
				Scroll.CanvasPosition = Vector2.new(0, math.clamp(rel, 0, maxScroll))
			end)
		end
		if task and task.defer then
			task.defer(apply)
		else
			apply()
		end
	end

	function PathEditor:Refresh()
		for _, r in self.Rows do
			pcall(function()
				r:Destroy()
			end)
		end
		table.clear(self.Rows)
		local points = {}
		if cb.Read then
			local ok, res = pcall(cb.Read)
			if ok and type(res) == "table" then
				points = res
			end
		end
		for i, p in ipairs(points) do
			makeRow(p, i)
		end
		if shell.Title then
			local n = #points
			shell.Title.Text = n > 0 and (BASE_TITLE .. "  (" .. n .. ")") or BASE_TITLE
		end
	end

	-- field commits don't restructure the row, so no rebuild (the consumer updates its own view)
	function PathEditor:SetField(index, key, value)
		if cb.OnField then
			Library:SafeCallback(cb.OnField, index, key, value)
		end
	end
	-- cond is { var, op, value } or nil to clear; the ? toggle drives its own Refresh, field edits don't
	function PathEditor:SetCondition(index, cond)
		if cb.OnCondition then
			Library:SafeCallback(cb.OnCondition, index, cond)
		end
	end
	function PathEditor:SetKind(index, key)
		if cb.OnKind then
			Library:SafeCallback(cb.OnKind, index, key)
		end
		self:Refresh()
	end
	function PathEditor:Move(index, delta)
		if cb.OnMove then
			Library:SafeCallback(cb.OnMove, index, delta)
		end
		self:Refresh()
	end
	function PathEditor:Delete(index)
		if cb.OnDelete then
			Library:SafeCallback(cb.OnDelete, index)
		end
		self:Refresh()
	end
	function PathEditor:Recapture(index)
		if cb.OnRecapture then
			Library:SafeCallback(cb.OnRecapture, index)
		end
		self:Refresh()
	end
	function PathEditor:Insert(index)
		if cb.OnInsert then
			Library:SafeCallback(cb.OnInsert, index)
		end
		self:Refresh()
		scrollToIndex(index + 1)
	end
	function PathEditor:Append()
		if cb.OnAppend then
			Library:SafeCallback(cb.OnAppend)
		end
		self:Refresh()
		scrollToIndex(nil)
	end
	function PathEditor:AppendAction()
		if cb.OnAppendAction then
			Library:SafeCallback(cb.OnAppendAction)
		end
		self:Refresh()
		scrollToIndex(nil)
	end
	function PathEditor:Save()
		if not cb.OnSave then
			return
		end
		local ok, res = pcall(cb.OnSave)
		return ok and res
	end
	-- the Refresh button reloads from the consumer's source of truth (discarding unsaved edits); plain :Refresh() only re-renders
	function PathEditor:Reload()
		if cb.OnRefresh then
			Library:SafeCallback(cb.OnRefresh)
		end
		self:Refresh()
	end

	function PathEditor:SetVisible(v)
		shell.Outline.Visible = v and true or false
	end
	function PathEditor:Show()
		self:SetVisible(true)
	end
	function PathEditor:Hide()
		self:SetVisible(false)
	end
	function PathEditor:Toggle()
		self:SetVisible(not shell.Outline.Visible)
	end
	function PathEditor:Resize(dx, dy)
		return setSize(shell.Outline.Size.X.Offset + (dx or 0), shell.Outline.Size.Y.Offset + (dy or 0))
	end

	CloseBtn.MouseButton1Click:Connect(function()
		PathEditor:Hide()
		if cb.OnClose then
			Library:SafeCallback(cb.OnClose)
		end
	end)
	AddBtn.MouseButton1Click:Connect(function()
		PathEditor:Append()
	end)
	if ActionBtn then
		ActionBtn.MouseButton1Click:Connect(function()
			PathEditor:AppendAction()
		end)
	end
	RefreshBtn.MouseButton1Click:Connect(function()
		PathEditor:Reload()
	end)
	SaveBtn.MouseButton1Click:Connect(function()
		PathEditor:Save()
	end)
	if not cb.OnSave then
		SaveBtn.Visible = false
	end

	PathEditor:Refresh()
	Library.PathEditor = PathEditor
	return PathEditor
end

function Library:CreateAutoBlockBuilder(info)
	info = info or {}
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local LocalPlayer = Players.LocalPlayer

	local onSave, onDelete, onToggleLog, onClearLogs, onSelect, onVisibleChanged =
		info.OnSave, info.OnDelete, info.OnToggleLog, info.OnClearLogs, info.OnSelect, info.OnVisibleChanged
	info = Library:Validate(info, {
		Title = "auto block builder",
		Width = 720,
		Height = 380,
		Visible = false,
	})

	local shell = MakeWindowShell(ScreenGui, UDim2.fromOffset(info.Width, info.Height), UDim2.fromOffset(300, 120), info.Title)
	shell.Outline.Visible = info.Visible and true or false
	shell.Outline.ZIndex = 0

	local Header = New("Frame", { Parent = shell.Body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), ZIndex = 5 })
	Library:MakeDraggable(shell.Outline, Header)

	local CloseBtn = New("TextButton", {
		Parent = shell.Body, Text = "X", TextColor3 = "FontColor", TextStrokeTransparency = 0.5,
		TextSize = 16, BackgroundTransparency = 1, AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(16, 16), ZIndex = 8,
	})

	local content = New("Frame", { Parent = shell.Body, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -22), ZIndex = 4 })

	local function panelColumn(sizeXScale, posXScale, gapL, gapR)
		local _, _, body = MakePanel(content, UDim2.new(sizeXScale, gapR, 1, 0), UDim2.new(posXScale, gapL, 0, 0))
		New("UIPadding", { Parent = body, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
		return body
	end
	local leftBody = panelColumn(0.27, 0, 0, -3)
	local midBody = panelColumn(0.44, 0.27, 3, -6)
	local rightBody = panelColumn(0.29, 0.71, 3, -3)

	local function label(parent, text, pos, size, colorKey, align)
		return New("TextLabel", {
			Parent = parent, Text = text, TextColor3 = colorKey or "FontColor", BackgroundTransparency = 1,
			TextStrokeTransparency = 0.5, Position = pos, Size = size, TextSize = 12,
			TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
		})
	end
	local function button(parent, text, pos, size)
		local b = New("TextButton", {
			Parent = parent, Text = text, TextColor3 = "FontColor", TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Element", BorderColor3 = "ElementBorder", BorderSizePixel = 1, AutoButtonColor = false,
			Position = pos, Size = size, TextSize = 12, ZIndex = 7,
		})
		b.MouseEnter:Connect(function() b.BackgroundColor3 = Library.Scheme.Pop end)
		b.MouseLeave:Connect(function() b.BackgroundColor3 = Library.Scheme.Element end)
		return b
	end
	local function input(parent, placeholder, pos, size)
		local box = New("TextBox", {
			Parent = parent, Text = "", PlaceholderText = placeholder, PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
			TextColor3 = "FontColor", TextStrokeTransparency = 0.5, BackgroundColor3 = "Element", BorderColor3 = "ElementBorder",
			BorderSizePixel = 1, ClearTextOnFocus = false, Position = pos, Size = size, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
		})
		New("UIPadding", { Parent = box, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 4) })
		return box
	end
	local function checkbox(parent, text, pos, default, onChanged, size)
		local holder = New("Frame", { Parent = parent, BackgroundTransparency = 1, Position = pos, Size = size or UDim2.new(1, 0, 0, 14), ZIndex = 6 })
		local box = New("Frame", { Parent = holder, BackgroundColor3 = "Dark", BorderColor3 = "DarkBorder", BorderSizePixel = 1, Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(0, 1), ZIndex = 7 })
		local inner = New("Frame", { Parent = box, BackgroundColor3 = "ElementFill", BorderSizePixel = 0, Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), ZIndex = 7 })
		local fill = New("Frame", { Parent = inner, BackgroundColor3 = "Accent", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = default and true or false, ZIndex = 8 })
		label(holder, text, UDim2.fromOffset(18, 0), UDim2.new(1, -18, 1, 0))
		local st = { value = default and true or false }
		local click = New("TextButton", { Parent = holder, Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
		click.MouseButton1Click:Connect(function()
			st.value = not st.value
			fill.Visible = st.value
			if onChanged then onChanged(st.value) end
		end)
		function st.set(v)
			st.value = v and true or false
			fill.Visible = st.value
		end
		return st
	end
	local function slider(parent, labelText, pos, min, max, default, rounding, suffix, onChanged)
		local st = { value = default }
		local holder = New("Frame", { Parent = parent, BackgroundTransparency = 1, Position = pos, Size = UDim2.new(1, 0, 0, 14), ZIndex = 6 })
		local lbl = label(holder, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(72, 14))
		local barOutline = New("Frame", { Parent = holder, BackgroundColor3 = "Dark", BorderColor3 = "DarkBorder", BorderSizePixel = 1, Position = UDim2.new(0, 76, 0, 2), Size = UDim2.new(1, -76, 0, 10), ZIndex = 7 })
		local fill = New("Frame", { Parent = barOutline, BackgroundColor3 = "Accent", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 8 })
		local function roundv(v)
			if rounding and rounding > 0 then
				local m = 10 ^ rounding
				return math.floor(v * m + 0.5) / m
			end
			return math.floor(v + 0.5)
		end
		local function display()
			local frac = (max - min) == 0 and 0 or (st.value - min) / (max - min)
			frac = math.clamp(frac, 0, 1)
			fill.Size = UDim2.new(frac, 0, 1, 0)
			lbl.Text = string.format("%s: %s%s", labelText, tostring(st.value), suffix or "")
		end
		local function setValue(v, fire)
			v = math.clamp(roundv(v), min, max)
			local changed = v ~= st.value
			st.value = v
			display()
			if changed and fire and onChanged then onChanged(v) end
		end
		local dragging = false
		local function moveTo(x)
			local rel = (x - barOutline.AbsolutePosition.X) / barOutline.AbsoluteSize.X
			setValue(min + math.clamp(rel, 0, 1) * (max - min), true)
		end
		barOutline.InputBegan:Connect(function(i) if IsClickInput(i) then dragging = true moveTo(i.Position.X) end end)
		barOutline.InputEnded:Connect(function(i) if IsMouseInput(i) then dragging = false end end)
		Library:GiveSignal(UserInputService.InputChanged:Connect(function(i)
			if dragging and IsHoverInput(i) then moveTo(i.Position.X) end
		end))
		display()
		function st.set(v) setValue(v, false) end
		function st.get() return st.value end
		return st
	end

	local ResizeHandle = New("Frame", {
		Parent = shell.Outline, BackgroundColor3 = "Accent", BorderColor3 = "Border",
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -1, 1, -1), Size = UDim2.fromOffset(10, 10), ZIndex = 50, Active = true,
	})
	local setSize = Library:MakeResizable(shell.Outline, ResizeHandle, Vector2.new(560, 300), Vector2.new(960, 620))

	local ABB = {
		Holder = shell.Outline, Header = Header, ResizeHandle = ResizeHandle,
		OnSave = onSave, OnDelete = onDelete, OnToggleLog = onToggleLog, OnClearLogs = onClearLogs, OnSelect = onSelect,
		OnVisibleChanged = onVisibleChanged,
	}

	local mode = "detected"
	local detected = {}
	local savedBlocks = {}
	local function tabButton(text, pos, size)
		return New("TextButton", {
			Parent = leftBody, Text = text, TextColor3 = "FontColor", TextStrokeTransparency = 0.5,
			BackgroundColor3 = "Element", BorderColor3 = "ElementBorder", BorderSizePixel = 1, AutoButtonColor = false,
			Position = pos, Size = size, TextSize = 12, ZIndex = 7,
		})
	end
	local filterBox = input(leftBody, "filter player (all)", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 15))
	function ABB:GetFilter()
		return filterBox.Text
	end
	local suggestFrame = New("Frame", {
		Parent = leftBody, BackgroundColor3 = "Dark", BorderColor3 = "DarkBorder", BorderSizePixel = 1,
		Position = UDim2.fromOffset(0, 15), Size = UDim2.new(1, 0, 0, 0), Visible = false, ZIndex = 40,
	})
	New("UIListLayout", { Parent = suggestFrame, SortOrder = Enum.SortOrder.LayoutOrder })
	local function hide_suggest()
		suggestFrame.Visible = false
		for _, c in suggestFrame:GetChildren() do
			if c:IsA("TextButton") then c:Destroy() end
		end
	end
	local function refresh_suggest()
		hide_suggest()
		local q = filterBox.Text:lower()
		if q == "" then return end
		local shown = 0
		for _, p in Players:GetPlayers() do
			if shown >= 5 then break end
			if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
				shown += 1
				local pname = p.Name
				local b = New("TextButton", {
					Parent = suggestFrame, Text = " " .. p.DisplayName .. " [" .. p.Name .. "]", TextColor3 = "FontColor",
					TextStrokeTransparency = 0.5, BackgroundColor3 = "Element", BorderColor3 = "ElementBorder", BorderSizePixel = 1,
					AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, ZIndex = 41,
				})
				b.MouseButton1Click:Connect(function()
					filterBox.Text = pname
					hide_suggest()
				end)
			end
		end
		if shown > 0 then
			suggestFrame.Size = UDim2.new(1, 0, 0, shown * 16)
			suggestFrame.Visible = true
		end
	end
	filterBox:GetPropertyChangedSignal("Text"):Connect(refresh_suggest)
	filterBox.FocusLost:Connect(function()
		task.wait(0.15)
		hide_suggest()
	end)
	local detTab = tabButton("Detected", UDim2.new(0, 0, 0, 18), UDim2.new(0.5, -1, 0, 15))
	local savTab = tabButton("Saved", UDim2.new(0.5, 1, 0, 18), UDim2.new(0.5, -1, 0, 15))
	local logLocalOn = false
	local logBtn = button(leftBody, "Log LocalPlayer: OFF", UDim2.new(0, 0, 0, 36), UDim2.new(1, 0, 0, 15))
	local _, _, listBody = MakePanel(leftBody, UDim2.new(1, 0, 1, -72), UDim2.fromOffset(0, 54))
	local scroll = New("ScrollingFrame", {
		Parent = listBody, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = "Accent", ZIndex = 6,
	})
	New("UIListLayout", { Parent = scroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	local clearBtn = button(leftBody, "Clear Logs", UDim2.new(0, 0, 1, -15), UDim2.new(1, 0, 0, 15))
	clearBtn.TextColor3 = Library.Scheme.Red

	local nameLabel = label(midBody, "-", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14), "FontColor", Enum.TextXAlignment.Center)
	local idLabel = label(midBody, "", UDim2.fromOffset(0, 15), UDim2.new(1, 0, 0, 12), "DimColor", Enum.TextXAlignment.Center)
	local viewport = New("ViewportFrame", {
		Parent = midBody, BackgroundColor3 = "Dark", BorderColor3 = "DarkBorder", BorderSizePixel = 1,
		Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -96), ZIndex = 6,
		Ambient = Color3.fromRGB(210, 210, 210), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.5, -1, -0.5),
	})
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local vpCam = Instance.new("Camera")
	vpCam.Parent = viewport
	viewport.CurrentCamera = vpCam
	local orbitPad = New("TextButton", {
		Parent = midBody, Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
		Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -96), ZIndex = 7,
	})
	local orbitYaw, orbitPitch, orbitDist = 0, 0, 8
	local dragging, lastMouse = false, nil
	local durLabel = label(midBody, "", UDim2.new(0, 0, 1, -64), UDim2.new(1, -2, 0, 12), "FontColor", Enum.TextXAlignment.Right)
	local paused = false
	local speedPct = 100
	local currentRig, currentTrack, currentAnimator, currentSound, rigSource

	local function ensureRig(force)
		local src = LocalPlayer.Character
		if not src then
			return currentAnimator
		end
		if currentRig and currentRig.Parent and rigSource == src and not force then
			return currentAnimator
		end
		if currentRig then
			pcall(function() currentRig:Destroy() end)
		end
		currentRig, currentTrack, currentAnimator = nil, nil, nil
		rigSource = src
		pcall(function()
			src.Archivable = true
			for _, d in src:GetDescendants() do
				d.Archivable = true
			end
		end)
		local ok, rig = pcall(function() return src:Clone() end)
		if not ok or not rig then
			return nil
		end
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local hrp = rig:FindFirstChild("HumanoidRootPart")
		for _, d in rig:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") then
				pcall(function() d:Destroy() end)
			elseif d:IsA("BasePart") then
				d.CanCollide = false
				d.Anchored = d == hrp
				d.LocalTransparencyModifier = 0
			end
		end
		if hrp then
			rig.PrimaryPart = hrp
		end
		rig.Parent = world
		currentRig = rig
		currentAnimator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)) or nil
		pcall(function()
			local _, size = rig:GetBoundingBox()
			orbitDist = math.max(size.X, size.Y, size.Z) * 1.4 + 3
			local base = hrp or rig.PrimaryPart
			if base then
				local look = base.CFrame.LookVector
				orbitYaw = math.atan2(look.X, look.Z)
				orbitPitch = 0
			end
		end)
		return currentAnimator
	end

	local speedSlider = slider(midBody, "Speed %", UDim2.new(0, 0, 1, -50), 0, 300, 100, 0, "", function(v)
		speedPct = v
		if currentTrack then pcall(function() currentTrack:AdjustSpeed(paused and 0 or v / 100) end) end
	end)
	local frameSlider = slider(midBody, "Frame", UDim2.new(0, 0, 1, -34), 0, 100, 0, 0, "", function(v)
		if currentTrack and currentTrack.Length and currentTrack.Length > 0 then
			pcall(function()
				currentTrack.TimePosition = (v / 100) * currentTrack.Length
				if currentAnimator then currentAnimator:StepAnimations(0) end
			end)
		end
	end)
	checkbox(midBody, "Pause", UDim2.new(0, 0, 1, -16), false, function(on)
		paused = on
		if currentTrack then pcall(function() currentTrack:AdjustSpeed(on and 0 or speedPct / 100) end) end
	end, UDim2.new(0.5, -2, 0, 14))
	local resetBtn = button(midBody, "Reset", UDim2.new(0.5, 2, 1, -16), UDim2.new(0.5, -2, 0, 14))
	resetBtn.MouseButton1Click:Connect(function()
		speedPct = 100
		speedSlider.set(100)
		frameSlider.set(0)
		pcall(ensureRig, true)
	end)

	local function updateCamera()
		local base = currentRig and (currentRig.PrimaryPart or currentRig:FindFirstChild("HumanoidRootPart"))
		if not base then
			return
		end
		local center = base.Position + Vector3.new(0, 0.5, 0)
		local dir = CFrame.fromEulerAnglesYXZ(orbitPitch, orbitYaw, 0) * Vector3.new(0, 0, orbitDist)
		vpCam.CFrame = CFrame.new(center + dir, center)
	end
	Library:GiveSignal(RunService.RenderStepped:Connect(function(dt)
		if not shell.Outline.Visible then
			return
		end
		ensureRig()
		if currentAnimator and currentTrack then
			pcall(function() currentAnimator:StepAnimations(paused and 0 or dt * (speedPct / 100)) end)
		end
		updateCamera()
	end))
	local hovering = false
	orbitPad.MouseEnter:Connect(function() hovering = true end)
	orbitPad.MouseLeave:Connect(function() hovering = false end)
	orbitPad.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			lastMouse = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if lastMouse then
				orbitYaw -= (pos.X - lastMouse.X) * 0.01
				orbitPitch = math.clamp(orbitPitch - (pos.Y - lastMouse.Y) * 0.01, -1.4, 1.4)
			end
			lastMouse = pos
		elseif hovering and input.UserInputType == Enum.UserInputType.MouseWheel then
			orbitDist = math.clamp(orbitDist - input.Position.Z * (orbitDist * 0.12), 2, 300)
		end
	end))
	Library:GiveSignal(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	local nameBox = input(rightBody, "Name", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 15))
	local delaySlider = slider(rightBody, "Delay", UDim2.fromOffset(0, 20), 0, 200, 15, 0, "", nil)
	local holdSlider = slider(rightBody, "Hold", UDim2.fromOffset(0, 38), 0, 500, 50, 0, "", nil)
	local rangeSlider = slider(rightBody, "Range", UDim2.fromOffset(0, 56), 0, 150, 30, 0, "", nil)
	local toolBox = input(rightBody, "Tool (equip on block)", UDim2.fromOffset(0, 76), UDim2.new(1, 0, 0, 15))
	local BLOCK_MODES = { "normal", "vim", "semiblatant" }
	local BLOCK_MODE_LABEL = { normal = "Normal", vim = "VIM", semiblatant = "Semi-Blatant" }
	local currentMode = "normal"
	local modeBtn = button(rightBody, "Block: Normal", UDim2.fromOffset(0, 96), UDim2.new(1, 0, 0, 15))
	modeBtn.MouseButton1Click:Connect(function()
		local i = table.find(BLOCK_MODES, currentMode) or 1
		currentMode = BLOCK_MODES[(i % #BLOCK_MODES) + 1]
		modeBtn.Text = "Block: " .. BLOCK_MODE_LABEL[currentMode]
	end)
	local manaShieldChk = checkbox(rightBody, "Mana Shield", UDim2.fromOffset(0, 116), false, nil)
	local enabledChk = checkbox(rightBody, "Enabled", UDim2.fromOffset(0, 136), true, nil)
	local saveBtn = button(rightBody, "Save Block", UDim2.fromOffset(0, 156), UDim2.new(1, 0, 0, 15))
	local deleteBtn = button(rightBody, "Delete Block", UDim2.fromOffset(0, 174), UDim2.new(1, 0, 0, 15))

	local currentId, currentKind

	function ABB:PreviewAnimation(id, name, kind)
		nameLabel.Text = name or "-"
		idLabel.Text = id or ""
		durLabel.Text = ""
		if currentTrack then
			pcall(function() currentTrack:Stop() end)
			currentTrack = nil
		end
		local animator = ensureRig()
		if kind == "sound" then
			pcall(function()
				if currentSound then currentSound:Destroy() end
				local s = Instance.new("Sound")
				s.SoundId = id
				s.Parent = viewport
				currentSound = s
				s:Play()
			end)
			return
		end
		if not animator or not id or id == "" then
			return
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if not ok or not track then
			return
		end
		currentTrack = track
		track.Looped = true
		pcall(function() track:Play() end)
		pcall(function() track:AdjustSpeed(paused and 0 or speedPct / 100) end)
		task.spawn(function()
			for _ = 1, 30 do
				if track.Length and track.Length > 0 then break end
				task.wait(0.1)
			end
			durLabel.Text = string.format("%.2fs", track.Length or 0)
		end)
	end

	function ABB:LivePlay(id, name, kind)
		if paused or kind ~= "anim" or mode == "saved" then
			return
		end
		ABB:PreviewAnimation(id, name, kind)
	end

	local editingName
	local function selectSignal(name, id, kind)
		currentId = id
		currentKind = kind or "anim"
		editingName = nil
		if nameBox.Text == "" then nameBox.Text = name or "" end
		frameSlider.set(0)
		ABB:PreviewAnimation(id, name, currentKind)
		Library:SafeCallback(ABB.OnSelect, id, name, currentKind)
	end

	local function makeRow(title, subtitle, kind, onClick)
		local isSound = kind == "sound"
		local accent = isSound and Color3.fromRGB(120, 225, 140) or Color3.fromRGB(120, 170, 255)
		local row = New("TextButton", {
			Parent = scroll, Text = "", AutoButtonColor = false,
			BackgroundColor3 = "Element", BorderColor3 = "ElementBorder", BorderSizePixel = 1,
			Size = UDim2.new(1, 0, 0, 28), ZIndex = 7,
		})
		New("Frame", { Parent = row, BackgroundColor3 = accent, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), ZIndex = 8 })
		New("TextLabel", {
			Parent = row, Text = title, TextColor3 = "FontColor", TextStrokeTransparency = 0.5,
			BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 2), Size = UDim2.new(1, -44, 0, 13),
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 12, ZIndex = 8,
		})
		New("TextLabel", {
			Parent = row, Text = subtitle, TextColor3 = "DimColor",
			BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 15), Size = UDim2.new(1, -13, 0, 11),
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 11, ZIndex = 8,
		})
		New("TextLabel", {
			Parent = row, Text = isSound and "SND" or "ANM", TextColor3 = accent, BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 2), Size = UDim2.fromOffset(30, 12),
			TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11, ZIndex = 8,
		})
		row.MouseEnter:Connect(function() row.BackgroundColor3 = Library.Scheme.Pop end)
		row.MouseLeave:Connect(function() row.BackgroundColor3 = Library.Scheme.Element end)
		row.MouseButton1Click:Connect(onClick)
	end
	local function clearRows()
		for _, c in scroll:GetChildren() do
			if c:IsA("TextButton") then c:Destroy() end
		end
	end
	local function rebuild()
		clearRows()
		if mode == "saved" then
			for _, b in savedBlocks do
				local num = tostring(b.id):match("%d+") or tostring(b.id)
				makeRow(b.name or "block", (b.kind == "sound" and "SND " or "ANM ") .. num, b.kind, function()
					ABB:SetForm(b)
				end)
			end
		else
			for _, e in detected do
				makeRow(e.name, tostring(e.id):match("%d+") or tostring(e.id), e.kind, function()
					selectSignal(e.name, e.id, e.kind)
				end)
			end
		end
	end
	local function setMode(m)
		mode = m
		detTab.BackgroundColor3 = m == "detected" and Library.Scheme.Pop or Library.Scheme.Element
		savTab.BackgroundColor3 = m == "saved" and Library.Scheme.Pop or Library.Scheme.Element
		logBtn.Visible = m == "detected"
		clearBtn.Visible = m == "detected"
		rebuild()
	end
	detTab.MouseButton1Click:Connect(function() setMode("detected") end)
	savTab.MouseButton1Click:Connect(function() setMode("saved") end)

	local seen = {}
	function ABB:AddLog(name, id, kind)
		kind = kind or "anim"
		local num = tostring(id):match("%d+") or tostring(id)
		local key = kind .. ":" .. num
		if seen[key] then return end
		seen[key] = true
		name = name or (kind == "sound" and "Sound" or "Animation")
		table.insert(detected, { name = name, id = id, kind = kind })
		if mode == "detected" then
			local atBottom = (scroll.CanvasPosition.Y + scroll.AbsoluteWindowSize.Y) >= (scroll.AbsoluteCanvasSize.Y - 8)
			makeRow(name, num, kind, function() selectSignal(name, id, kind) end)
			if atBottom then
				task.defer(function()
					scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
				end)
			end
		end
	end
	function ABB:ClearLogs()
		table.clear(seen)
		table.clear(detected)
		if mode == "detected" then clearRows() end
		Library:SafeCallback(ABB.OnClearLogs)
	end
	function ABB:SetSavedBlocks(list)
		savedBlocks = list or {}
		if mode == "saved" then rebuild() end
	end
	setMode("detected")

	local function getForm()
		return {
			name = nameBox.Text,
			id = currentId or "",
			kind = currentKind or "anim",
			delay = delaySlider.get(),
			hold = holdSlider.get(),
			range = rangeSlider.get(),
			tool = toolBox.Text,
			mode = currentMode,
			manaShield = manaShieldChk.value,
			frame = frameSlider.get(),
			enabled = enabledChk.value,
			editing = editingName,
		}
	end
	function ABB:SetForm(b)
		b = b or {}
		nameBox.Text = b.name or ""
		editingName = b.name
		currentId = b.id
		currentKind = b.kind or "anim"
		delaySlider.set(b.delay or 15)
		holdSlider.set(b.hold or 50)
		rangeSlider.set(b.range or 30)
		toolBox.Text = b.tool or ""
		currentMode = b.mode or "normal"
		modeBtn.Text = "Block: " .. (BLOCK_MODE_LABEL[currentMode] or "Normal")
		manaShieldChk.set(b.manaShield == true)
		frameSlider.set(tonumber(b.frame) or 0)
		enabledChk.set(b.enabled ~= false)
		if b.id then ABB:PreviewAnimation(b.id, b.name, currentKind) end
	end

	logBtn.MouseButton1Click:Connect(function()
		logLocalOn = not logLocalOn
		logBtn.Text = "Log LocalPlayer: " .. (logLocalOn and "ON" or "OFF")
		logBtn.TextColor3 = logLocalOn and Color3.fromRGB(120, 255, 120) or Library.Scheme.FontColor
		Library:SafeCallback(ABB.OnToggleLog, logLocalOn)
	end)
	clearBtn.MouseButton1Click:Connect(function() ABB:ClearLogs() end)
	saveBtn.MouseButton1Click:Connect(function() Library:SafeCallback(ABB.OnSave, getForm()) end)
	deleteBtn.MouseButton1Click:Connect(function() Library:SafeCallback(ABB.OnDelete, nameBox.Text) end)
	CloseBtn.MouseButton1Click:Connect(function() ABB:Hide() end)

	function ABB:SetVisible(v)
		shell.Outline.Visible = v and true or false
		if v then pcall(ensureRig, true) end
		Library:SafeCallback(ABB.OnVisibleChanged, shell.Outline.Visible)
	end
	function ABB:IsVisible() return shell.Outline.Visible end
	function ABB:Show() self:SetVisible(true) end
	function ABB:Hide() self:SetVisible(false) end
	function ABB:Toggle() self:SetVisible(not shell.Outline.Visible) end
	function ABB:Resize(dx, dy) return setSize(shell.Outline.Size.X.Offset + (dx or 0), shell.Outline.Size.Y.Offset + (dy or 0)) end

	Library.AutoBlockBuilder = ABB
	return ABB
end

-- standalone auto-sizing draggable status panel; the consumer feeds it text rows
function Library:CreateStatusList(info)
	info = Library:Validate(info or {}, {
		Title = "status",
		Visible = true,
		HideInactive = false,
	})

	-- layered border chrome, all AutomaticSize so the box grows to fit its content
	local Outline = New("Frame", {
		Parent = ScreenGui,
		BackgroundColor3 = "Outline",
		BorderColor3 = "Border",
		Position = UDim2.fromOffset(16, 440),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	New("UIPadding", {
		Parent = Outline,
		PaddingTop = UDim.new(0, 1),
		PaddingBottom = UDim.new(0, 1),
		PaddingLeft = UDim.new(0, 1),
		PaddingRight = UDim.new(0, 1),
	})
	local Accent = New("Frame", {
		Parent = Outline,
		BackgroundColor3 = "Accent",
		BorderColor3 = "Border",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	New("UIPadding", {
		Parent = Accent,
		PaddingTop = UDim.new(0, 1),
		PaddingBottom = UDim.new(0, 1),
		PaddingLeft = UDim.new(0, 1),
		PaddingRight = UDim.new(0, 1),
	})
	local Body = New("Frame", {
		Parent = Accent,
		BackgroundColor3 = "Body",
		BorderColor3 = "Border",
		BackgroundTransparency = 0.76,
		Size = UDim2.fromOffset(0, 0),
	})
	New("UIPadding", {
		Parent = Body,
		-- thinner border on the right/bottom/left (match the top); the title bar stays as-is
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	})
	New("UIListLayout", { Parent = Body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })

	-- width is set in _relayout (= widest of title/rows) so the title and rows share one width (even border)
	local Title = New("TextLabel", {
		Parent = Body,
		Name = "Title",
		Text = info.Title,
		TextColor3 = "FontColor",
		TextStrokeTransparency = 0,
		BackgroundTransparency = 1,
		TextSize = 12,
		Size = UDim2.fromOffset(0, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = -1,
	})

	-- solid filled surface the rows sit on (MainColor, theme-tracked); width matches the title's
	local Content = New("Frame", {
		Parent = Body,
		BackgroundColor3 = "MainColor",
		BorderColor3 = "Border",
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = 0,
	})
	New("UIListLayout", { Parent = Content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	New("UIPadding", {
		Parent = Content,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 3),
	})

	Library:MakeDraggable(Outline, Body)

	-- invisible drag hitbox pinned to the bottom-right; scale-anchored so it never inflates the AutomaticSize chain
	local Handle = New("TextButton", {
		Parent = Outline,
		Name = "ResizeGrip",
		Text = "",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -1, 1, -1),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 6,
	})

	local BASE_TITLE_TEXT, BASE_ROW_TEXT = 12, 13
	local BASE_TITLE_H, BASE_ROW_H = 14, 16
	local CONTENT_PAD = 3
	local MIN_SCALE, MAX_SCALE = 0.6, 3
	local MAX_BOX_W = 700 -- safety ceiling: a bad text measurement can never blow the box to full width

	local StatusList = {
		Holder = Outline,
		Body = Body,
		Content = Content,
		Title = Title,
		Items = {},
		HideInactive = info.HideInactive and true or false,
		_wantVisible = info.Visible and true or false,
		_counter = 0,
		Scale = 1,
	}

	local function textWidth(label)
		local ok, w = pcall(function()
			return label.TextBounds.X
		end)
		return (ok and w) or 0
	end

	-- Title + Content both get innerW (widest of title/rows, base-measured then scaled) for an even border
	function StatusList:_relayout()
		local scale = self.Scale
		Title.TextSize = BASE_TITLE_TEXT
		local titleBaseW = math.ceil(textWidth(Title))
		local rowsBaseW = 0
		for _, item in self.Items do
			item.Label.TextSize = BASE_ROW_TEXT
			rowsBaseW = math.max(rowsBaseW, math.ceil(textWidth(item.Label)))
		end
		local titleText = math.floor(BASE_TITLE_TEXT * scale + 0.5)
		local rowText = math.floor(BASE_ROW_TEXT * scale + 0.5)
		local titleH = math.ceil(BASE_TITLE_H * scale)
		local rowH = math.ceil(BASE_ROW_H * scale)
		local n = #self.Items
		local contentW = n > 0 and (math.ceil(rowsBaseW * scale) + CONTENT_PAD * 2) or 0
		local innerW = math.clamp(math.max(math.ceil(titleBaseW * scale), contentW), 0, MAX_BOX_W)
		Title.TextSize = titleText
		Title.Size = UDim2.new(0, innerW, 0, titleH)
		for _, item in self.Items do
			item.Label.TextSize = rowText
			item.Label.Size = UDim2.new(1, 0, 0, rowH)
		end
		local contentH = n > 0 and (4 + n * rowH + (n - 1) * 2) or 0
		Content.Size = UDim2.new(0, innerW, 0, contentH)
		Body.Size = UDim2.new(0, innerW + 4, 0, titleH + contentH + 6)
	end

	function StatusList:SetScale(s)
		self.Scale = math.clamp(tonumber(s) or self.Scale, MIN_SCALE, MAX_SCALE)
		self:_relayout()
		if self.OnScaleChanged then
			Library:SafeCallback(self.OnScaleChanged, self.Scale)
		end
	end
	function StatusList:GetScale()
		return self.Scale
	end

	-- continuous corner resize: scale tracks the cursor proportionally to the live box span
	do
		local startPos, startScale, startSpan
		local resizing = false
		local changed
		Handle.InputBegan:Connect(function(input)
			if not IsClickInput(input) then
				return
			end
			startPos = input.Position
			startScale = StatusList.Scale
			local size = Outline.AbsoluteSize
			startSpan = math.max(1, size.X + size.Y)
			resizing = true
			changed = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
					if changed then
						changed:Disconnect()
						changed = nil
					end
				end
			end)
		end)
		Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
			if not (ScreenGui and ScreenGui.Parent) then
				resizing = false
				return
			end
			if resizing and IsHoverInput(input) then
				local delta = input.Position - startPos
				StatusList:SetScale(startScale * (1 + (delta.X + delta.Y) / startSpan))
			end
		end))
	end

	function StatusList:_refreshVisibility()
		if self.HideInactive and #self.Items == 0 then
			Outline.Visible = false
		else
			Outline.Visible = self._wantVisible
		end
	end

	function StatusList:AddItem(text, color)
		local order = self._counter
		self._counter = order + 1
		local label = New("TextLabel", {
			Parent = Content,
			Name = "Item",
			Text = tostring(text),
			TextColor3 = color or "FontColor", -- explicit Color3 = literal override; nil = theme-tracked
			TextStrokeTransparency = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		})
		local item = { Label = label }
		function item:SetText(t)
			label.Text = tostring(t)
		end
		function item:SetColor(c)
			label.TextColor3 = c
		end
		function item:Remove()
			pcall(function()
				label:Destroy()
			end)
			for i, it in StatusList.Items do
				if it == item then
					table.remove(StatusList.Items, i)
					break
				end
			end
			StatusList:_relayout()
			StatusList:_refreshVisibility()
		end
		table.insert(self.Items, item)
		self:_relayout()
		self:_refreshVisibility()
		return item
	end

	function StatusList:Clear()
		for _, item in self.Items do
			if item.Label then
				pcall(function()
					item.Label:Destroy()
				end)
			end
		end
		table.clear(self.Items)
		self._counter = 0
		self:_relayout()
		self:_refreshVisibility()
	end

	function StatusList:SetVisible(v)
		self._wantVisible = v and true or false
		self:_refreshVisibility()
	end
	function StatusList:SetHideInactive(v)
		self.HideInactive = v and true or false
		self:_refreshVisibility()
	end

	StatusList:_relayout()
	StatusList:_refreshVisibility()
	Library.StatusList = StatusList
	return StatusList
end

local KeybindShell, KeybindScroll
local function ensureKeybindList()
	if KeybindShell then
		return
	end
	KeybindShell = MakeWindowShell(ScreenGui, UDim2.fromOffset(240, 200), UDim2.fromOffset(16, 200), "binds")
	Library:MakeDraggable(KeybindShell.Outline, KeybindShell.Body)
	local _, _, body = MakePanel(KeybindShell.Body, UDim2.new(1, 0, 1, -18), UDim2.fromOffset(0, 18))
	KeybindScroll = New("ScrollingFrame", {
		Parent = body,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "Accent",
	})
	New("UIListLayout", { Parent = KeybindScroll, Padding = UDim.new(0, 4) })
	New("UIPadding", {
		Parent = KeybindScroll,
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	})
end

function Library:AddKeybindRow(keyPicker)
	ensureKeybindList()
	local Row = New("Frame", {
		Parent = KeybindScroll,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
	})
	New("UIListLayout", { Parent = Row, FillDirection = Enum.FillDirection.Horizontal })
	New("UIPadding", { Parent = Row, PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) })
	local function col(text, divider)
		local lbl = New("TextLabel", {
			Parent = Row,
			Text = text,
			TextColor3 = Color3.fromRGB(180, 180, 180),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		New("UIStroke", { Parent = lbl })
		if divider then
			New("Frame", {
				Parent = lbl,
				BackgroundColor3 = "Divider",
				BorderColor3 = "Border",
				Position = UDim2.fromOffset(-10, 0),
				Size = UDim2.fromOffset(1, 12),
			})
		end
		New("UIFlexItem", { Parent = lbl, FlexMode = Enum.UIFlexMode.Fill })
		return lbl
	end
	local nameCol = col(keyPicker.Text, false)
	local keyCol = col("", true)
	local modeCol = col("", true)
	local stateCol = col("", true)
	Library.KeybindRows[keyPicker] = { Name = nameCol, Key = keyCol, Mode = modeCol, State = stateCol }
	Library:UpdateKeybindRow(keyPicker)
end

function Library:UpdateKeybindRow(keyPicker)
	local row = Library.KeybindRows[keyPicker]
	if not row then
		return
	end
	row.Name.Text = keyPicker.Text
	row.Key.Text = keyPicker.Value == "None" and "none" or Library:GetKeyString(keyPicker.Bind or keyPicker.Value)
	row.Mode.Text = keyPicker.Mode:lower()
	row.State.Text = tostring(keyPicker:GetState())
end

function Library:SetKeybindFrameVisible(visible)
	if KeybindShell and KeybindShell.Outline then
		KeybindShell.Outline.Visible = visible
	end
end

function Library:OnUnload(callback)
	table.insert(Library.UnloadSignals, callback)
end

function Library:Unload()
	if Library.Unloaded then
		return
	end

	for _, callback in Library.UnloadSignals do
		Library:SafeCallback(callback)
	end

	for index = #Library.Signals, 1, -1 do
		local connection = table.remove(Library.Signals, index)
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	pcall(function()
		RunService:UnbindFromRenderStep(Library.ShowCursorBinding)
	end)

	UserInputService.MouseIconEnabled = OriginalMouseIconEnabled

	-- Drawing objects aren't GUI, so ScreenGui:Destroy() won't clean them
	pcall(function()
		if Cursor then
			Cursor:Remove()
		end
		if CursorOutline then
			CursorOutline:Remove()
		end
	end)

	if ScreenGui then
		ScreenGui:Destroy()
	end

	Library.Unloaded = true
	table.clear(Library.Toggles)
	table.clear(Library.Options)
	table.clear(Library.Registry)
	table.clear(Library.Tabs)
	table.clear(Library.KeybindRows)
	table.clear(Library.SearchIndex)
	table.clear(Library.SearchBoxes)
	table.clear(DimState)
	Library.Searching = false
	getgenv().Library = nil
end

Library:GiveSignal(UserInputService.WindowFocused:Connect(function()
	Library.IsRobloxFocused = true
end))
Library:GiveSignal(UserInputService.WindowFocusReleased:Connect(function()
	Library.IsRobloxFocused = false
end))

Library:GiveSignal(UserInputService.InputBegan:Connect(function(input)
	if Library.Unloaded or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Library.ToggleKeybind and Library.Window then
		Library.Window:Toggle()
	end
end))

getgenv().Library = Library
return Library
