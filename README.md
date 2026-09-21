# InfilSense UI Library v2

A modern, modular, high-performance floating UI library for Roblox with integrated drag detection, magnetic grid snapping, context menus, tooltips, and a command palette.

## Installation

```lua
local Library = loadstring(game:HttpGet("https://github.com/bkkpro1980/InfilSense-Lib-v2/releases/latest/download/build.lua"))()
```

## Features

- **Draggable Floating Windows**: Uses Roblox's native `UIDragDetector` with pure pixel offset and bounds clamping.
- **Magnetic Grid Snapping**: Built-in snapping constraint to keep windows neatly aligned.
- **Auto-Stacking Spawn**: Tabs automatically spawn minimized in a clean downward stack.
- **Micro-Animations**: Smooth exponential opening/closing transitions and icon animations.
- **Quick Commands Palette**: Triggerable via keybind (default `F2`). Supports exact/prefix aliases and arguments.
- **Right-Click Context Menus**: Assign custom keybinds or mark toggles for automatic startup.
- **Screen-Boundary Awareness**: Tooltips and flyout menus flip dynamically to stay on-screen.
- **Built-in Settings Tab**: Automatic management of UI visibility, Quick Commands keybind, grid snap, and layout reset.
- **Global Visibility Keybind**: All tabs can be shown/hidden with a rebindable keybind (default `Right Shift`), separate from the Quick Commands keybind (`F2`).

---

## Documentation

Documentation can be found [here](https://docs.infilsense.dpdns.org).

---

## Quick Start

```lua
local Library = loadstring(game:HttpGet("https://github.com/bkkpro1980/InfilSense-Lib-v2/releases/latest/download/build.lua"))()

local app = Library.new({
	Name = "My Script",
	SaveFolder = "MyConfigs",
	SaveId = "config"
})

local mainTab = app:CreateTab("Main")

mainTab:AddButton({
	Info = { Title = "Print Hello", Description = "Prints a test message." },
	Callback = function()
		print("Hello, world!")
	end
})
```

---

## API Reference

### `Library.new(config)`
Initializes the library instance and creates the root `ScreenGui`.

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `config.Name` | `string` | `"Unnamed"` | Name identifier of the application. |
| `config.SaveFolder` | `string` | `""` | Folder inside executor storage to save configurations. |
| `config.SaveId` | `string` | `"config"` | File name (without extension) for the JSON configuration. |

**Returns:** `App` object.

---

### App Methods

#### `app:CreateTab(name, defaultPosition)`
Creates a new draggable window tab. If it has a saved position, it restores it; otherwise, it stacks below existing tabs (or uses `defaultPosition` if provided).
- `name` (`string`, required): Title text displayed on the tab header.
- `defaultPosition` (`UDim2`, optional): Default position override for first spawn.
- **Returns:** `Tab` object.

#### `app:GetTab(name)`
Retrieves an existing `Tab` object by its title (such as the auto-created `"Settings"` tab).
- **Returns:** `Tab` object or `nil`.

#### `app:ToggleGui(forcedState)`
Toggles or sets the visibility of all draggable tabs.

---

### Tab Methods

#### `tab:AddButton(config)`
```lua
tab:AddButton({
	Info = { Title = "Button Title", Description = "Tooltip text" },
	InternalInfo = {
		UniqueCommandId = "unique_btn_id",	-- Required for binds/startup
		Toggle = false,						-- Set true for toggle mode
		Bindable = true,					-- Right-click keybind assignment
		StartupAvailable = true,			-- Right-click run on script start
		Aliases = { "btn", "b" }			-- Quick Commands aliases
	},
	Callback = function(state) end
})
```

#### `tab:AddSlider(config)`
```lua
tab:AddSlider({
	Info = { Title = "WalkSpeed", Description = "Adjusts movement speed" },
	InternalInfo = {
		UniqueCommandId = "walkspeed_slider",
		Aliases = { "ws", "speed" }
	},
	Min = 16,
	Max = 250,
	Default = 16,
	Step = 1,
	SliderType = "number",	-- "number" or "bool"
	Save = false,			-- Persist value to JSON
	Callback = function(value) end
})
```

#### `tab:AddInput(config)`
```lua
tab:AddInput({
	Info = { Title = "Set Message", Description = "Custom text input" },
	DefaultText = "Default text here",
	InternalInfo = {
		Toggle = false, -- Set true to enable toggle behavior
		UniqueCommandId = "custom_input",
		Aliases = { "msg" }
	},
	Callback = function(text) end
})
```

#### `tab:AddSelection(config)`
```lua
local dropdown = tab:AddSelection({
	Info = { Title = "Select Target", Description = "Selects active target" },
	SingleSelect = true,
	DefaultValue = "Option 1",
	InternalInfo = {
		UniqueCommandId = "target_select",
		Aliases = { "target" }
	},
	Callback = function(selectedOption) end
})

dropdown:AddOption({ Info = { Title = "Option 1" }, Value = "Option 1" })
dropdown:AddOption({ Info = { Title = "Option 2" }, Value = "Option 2" })
```

#### `tab:AddLabel(config)`
```lua
tab:AddLabel("Text label or section title")
-- Or with detailed properties:
tab:AddLabel({ Text = "Header Title", TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 14 })
```

---

## Quick Commands Usage

Press **`F2`** to open the search bar:
- **`[alias] [args]`**: Run any registered command (e.g., `ws 100`, `fov 90`, `noclip on`).
- **`Tab`**: Auto-complete to the top suggestion.
- **`Enter`**: Execute the top result immediately.

---

## Build

The UI library can be built using DarkLua v0.19.0 via this command:

```
darklua process src/uiLib_v2/main.lua build/build.lua
```

---

## License

This project is licensed under the **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)** Public License.

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC%20BY--SA%204.0-purple.svg)](https://creativecommons.org/licenses/by-sa/4.0/)

By using, downloading, or interacting with this repository, you agree to the following terms:
- **Attribution (BY):** You must give appropriate credit to the original creator and provide a link to this license.
- **ShareAlike (SA):** If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.