--*******************************************************************************
-- MIT License
--
-- Copyright (c) 2024 (Jip) Willem Wijnia
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--*******************************************************************************

CreateUserFeedback = true -- change true to false to turn off feedback

local Keys = {

    -- main interactions

    ['W'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").MoveToLeft()',
        category = 'camera'
    },

    ['SHIFT-W'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").QueueMoveToLeft()',
        category = 'camera'
    },

    ['E'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").MoveToRight()',
        category = 'camera'
    },

    ['SHIFT-E'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").QueueMoveToRight()',
        category = 'camera'
    },

    ['S'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").TrackLeft()',
        category = 'camera'
    },

    ['Shift-S'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").QueueTrackLeft()',
        category = 'camera'
    },

    ['D'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").TrackRight()',
        category = 'camera'
    },

    ['Shift-D'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").QueueTrackRight()',
        category = 'camera'
    },

    ['X'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").SnapToLeft()',
        category = 'camera'
    },

    ['C'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").SnapToRight()',
        category = 'camera'
    },

    -- camera smoothing (interpolation)

    ['Q'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").SetAccelerationMode("Linear")',
        category = 'camera'
    },

    ['A'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").SetAccelerationMode("FastInSlowOut")',
        category = 'camera'
    },

    ['Z'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").SetAccelerationMode("SlowInOut")',
        category = 'camera'
    },

    -- lock/unlock input

    ['CTRl-Q'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").LockInput()',
        category = 'camera'
    },

    ['CTRL-D'] = {
        action = 'UI_Lua import("/mods/fa-casting-cinematics/src/Actions.lua").UnlockInput()',
        category = 'camera'
    },
}

--- Some sanity checks on when (not) to apply the hotkeys.
---@return boolean
function ShouldApplyKeys()
    -- session is in sandbox mode
    if SessionGetScenarioInfo().options.Victory == 'sandbox' then
        return true
    end

    -- Session is a replay
    if SessionIsReplay() then
        return true
    end

    -- Session has only one command source
    if table.getn(SessionGetCommandSourceNames()) == 1 then
        return true
    end

    -- User is an observer
    if GetFocusArmy() == -1 then
        return true
    end

    return false
end

function ApplyDefaultKeyLayout()
    local userKeys = import("/lua/keymap/keymapper.lua").GetKeyMappings()

    -- we overwrite existing user keys with our own key maps. This lasts for the entire session,
    -- only restarting the game can undo this. It does not affect your preference file.
    local combinedKeyMap = table.combine(userKeys, Keys)

    -- apply the keys
    IN_ClearKeyMap()
    IN_AddKeyMapTable(combinedKeyMap)

    print("Applied hotkeys for casting")
end

-------------------------------------------------------------------------------
--#region Debugging

-- This section provides a hot-reload like functionality when debugging this
-- module. It requires the `/EnableDiskWatch` program argument.
--
-- The code is not required for normal operation.

--- Called by the module manager when this module is reloaded
---@param newModule any
function __moduleinfo.OnReload(newModule)
    -- do nothing
end

--- Called by the module manager when this module becomes dirty.
function __moduleinfo.OnDirty()
    -- re-apply hotkeys
end

--#endregion
