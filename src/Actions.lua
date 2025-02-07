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

local Config = import("/mods/fa-casting-cinematics/src/Config.lua")

--- Utility function to retrieve the camera of a world view
---@param worldview WorldView
local function GetCameraOfWorldview(worldview)
    return GetCamera(worldview._cameraName)
end

--- Utility function that approaches the pitch of a camera at a given zoom
---@param zoom number
---@return number
local function GetCameraPitch(zoom)
    return (1 - 20 / zoom) * 1.5708
end

--- Creates a decal to assist the viewer in understanding what is happening.
---@param position Vector
---@param path FilePath
---@param scale number
---@param duration number
---@return UserDecal
CreateTemporaryDecal = function(position, path, scale, duration)
    local UserDecal = import("/lua/user/userdecal.lua").UserDecal
    local decal = UserDecal()
    decal:SetTexture(path)
    decal:SetScale({ scale, 1, scale })
    decal:SetPosition(position)

    local start = GetSystemTimeSeconds()
    local current = start

    ForkThread(
        function()
            while current - duration < start do
                WaitFrames(1)
            end

            decal:Destroy()
        end
    )

    return decal
end

---@param decal UserDecal
---@param position Vector
---@param scale number
---@param duration number
---@return thread
AnimateScaleAtPosition = function(decal, position, scale, duration)
    -- original position
    local ox, oy, oz = position[1], position[2], position[3]

    -- cached tables for performance
    local vPosition = { ox, oy, oz }
    local vScale = { scale, 1, scale }

    local start = GetSystemTimeSeconds()
    local current = start

    local fork = ForkThread(
    -- fade-out-like animation
        function()
            while not IsDestroyed(decal) and current - duration < start do
                local diff = (current - start) / duration
                local altScale = scale * (1 - diff * diff * diff * diff)

                vPosition[1] = ox + 0.5 * altScale
                vPosition[2] = oy
                vPosition[3] = oz + 0.5 * altScale
                decal:SetPosition(vPosition)

                vScale[1] = altScale
                vScale[3] = altScale
                decal:SetScale(vScale)

                current = GetSystemTimeSeconds()
                WaitFrames(1)
            end

            decal:Destroy()
        end
    )

    return fork
end

---@param decal UserDecal
---@param userUnit UserUnit
---@param scale number
---@param duration number
---@return thread
AnimateScaleAtUserUnit = function(decal, userUnit, scale, duration)
    -- original position
    local ox, oy, oz = unpack(userUnit:GetInterpolatedPosition())

    -- cached tables for performance
    local vPosition = { ox, oy, oz }
    local vScale = { scale, 1, scale }

    local start = GetSystemTimeSeconds()
    local current = start

    local fork = ForkThread(
    -- fade-out-like animation
        function()
            while not IsDestroyed(decal) and current - duration < start do
                local diff = (current - start) / duration
                local altScale = scale * (1 - diff * diff * diff * diff)

                local cPosition = userUnit:GetInterpolatedPosition()
                vPosition[1] = cPosition[1] + 0.5 * altScale
                vPosition[2] = cPosition[2]
                vPosition[3] = cPosition[3] + 0.5 * altScale
                decal:SetPosition(vPosition)

                vScale[1] = altScale
                vScale[3] = altScale
                decal:SetScale(vScale)

                current = GetSystemTimeSeconds()
                WaitFrames(1)
            end

            decal:Destroy()
        end
    )

    return fork
end

--- Determines the smoothing behavior of the camera
---@param mode UserCameraAccelerationModes
SetAccelerationMode = function(mode)
    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    if not (WorldViewManager.viewLeft and WorldViewManager.viewRight) then
        print("Requires split screen, aborting")
        return
    end

    -- determine what worldview has our focus
    local mouseCoordinates = GetMouseScreenPos()
    local worldViewFocus = WorldViewManager.GetTopmostWorldViewAt(mouseCoordinates[1], mouseCoordinates[2])
    local worldViewOther = WorldViewManager.viewLeft == worldViewFocus and WorldViewManager.viewRight or
        WorldViewManager.viewLeft --[[@as WorldView]]

    -- retrieve camera properties of the worldview that does not have our focus
    local cameraOther = GetCameraOfWorldview(worldViewOther)
    cameraOther:SetAccMode(mode)

    print("Mode set to: " .. mode)
end

--- Locks the input of a world view to prevent accidental interactions
LockInput = function()
    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    local mouseCoordinates = GetMouseScreenPos()
    local worldViewFocus = WorldViewManager.GetTopmostWorldViewAt(mouseCoordinates[1], mouseCoordinates[2])
    worldViewFocus:LockInput(GetCameraOfWorldview(worldViewFocus))
end

--- Unlocks the input of a world view.
UnlockInput = function()
    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    local mouseCoordinates = GetMouseScreenPos()
    local worldViewFocus = WorldViewManager.GetTopmostWorldViewAt(mouseCoordinates[1], mouseCoordinates[2])
    worldViewFocus:UnlockInput()
end

--- Gradually moves the world view to the target entity and then proceeds to track it.
Track = function(worldview, userUnit, duration)
    local camera = GetCameraOfWorldview(worldview)
    local cameraSettings = camera:SaveSettings()
    camera:TrackEntities({ userUnit:GetEntityId() }, cameraSettings.Zoom, duration)

    if Config.CreateUserFeedback then
        -- help the user understand what is happening
        local userDecalScale = 20
        local userDecalTexture = "/textures/selection_bracket_player_sm.dds"
        local userDecal = CreateTemporaryDecal(
            userUnit:GetPosition(),
            userDecalTexture,
            userDecalScale,
            duration
        )
        AnimateScaleAtUserUnit(userDecal, userUnit, userDecalScale, duration)
    end
end

--- Applies the `Track` functionality to the left world view using the unit that the mouse is hovering over.
TrackLeft = function(duration)
    duration = duration or 4

    local info = GetRolloverInfo()
    if not info then
        return
    end

    local WorldViewManager = import("/lua/ui/game/worldview.lua")
    local worldview = WorldViewManager.viewLeft or WorldViewManager.viewRight --[[@as WorldView]]

    Track(worldview, info.userUnit, duration)
end

--- Applies the `Track` functionality to the left world view using the unit that the mouse is hovering over.
QueueTrackLeft = function(duration)
    duration = duration or 4

    local info = GetRolloverInfo()
    if not info then
        return
    end

    local WorldViewManager = import("/lua/ui/game/worldview.lua")
    local worldview = WorldViewManager.viewLeft or WorldViewManager.viewRight --[[@as WorldView]]
    local camera = GetCameraOfWorldview(worldview)

    ForkThread(
        function()
            WaitFor(camera)
            Track(worldview, info.userUnit, duration)
        end
    )
end

--- Applies the `Track` functionality to the left world view using the unit that the mouse is hovering over. Falls back to the left world view.
TrackRight = function(duration)
    duration = duration or 4

    local info = GetRolloverInfo()
    if not info then
        return
    end

    local WorldViewManager = import("/lua/ui/game/worldview.lua")
    local worldview = WorldViewManager.viewRight or WorldViewManager.viewLeft --[[@as WorldView]]

    Track(worldview, info.userUnit, duration)
end

--- Applies the `Track` functionality to the right world view using the unit that the mouse is hovering over. Falls back to the left world view. Is applied after the current camera navigation is finished.
QueueTrackRight = function(duration)
    duration = duration or 4

    local info = GetRolloverInfo()
    if not info then
        return
    end

    local WorldViewManager = import("/lua/ui/game/worldview.lua")
    local worldview = WorldViewManager.viewRight or WorldViewManager.viewLeft --[[@as WorldView]]
    local camera = GetCameraOfWorldview(worldview)

    ForkThread(
        function()
            WaitFor(camera)
            Track(worldview, info.userUnit, duration)
        end
    )
end

--- Gradually moves the world view to the world coordinates over the given duration.
---@param worldview WorldView
---@param worldCoordinates Vector
---@param duration number
MoveTo = function(worldview, worldCoordinates, duration)
    local camera = GetCameraOfWorldview(worldview)
    local cameraSettings = camera:SaveSettings()
    camera:MoveTo(worldCoordinates, { cameraSettings.Heading, cameraSettings.Pitch, 0 }, cameraSettings.Zoom, duration)

    if Config.CreateUserFeedback then
        -- help the user understand what is happening
        local userDecalScale = 20
        local userDecalTexture = "/textures/selection_bracket_player_sm.dds"
        local userDecal = CreateTemporaryDecal(
            worldCoordinates,
            userDecalTexture,
            userDecalScale, duration
        )
        AnimateScaleAtPosition(userDecal, worldCoordinates, userDecalScale, duration)
    end
end

--- Applies the `MoveTo` functionality to the left world view using the world coordinates of the mouse.
---@param duration? number
MoveToLeft = function(duration)
    duration = duration or 4

    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    -- move the camera of the left world view, fallback to the right world view
    local worldview = WorldViewManager.viewLeft or WorldViewManager.viewRight --[[@as WorldView]]
    local worldCoordinates = GetMouseWorldPos()
    MoveTo(worldview, worldCoordinates, duration)
end

--- Applies the `MoveTo` functionality to the left world view using the world coordinates of the mouse. Is applied after the current camera navigation is finished.
---@param duration? number
QueueMoveToLeft = function(duration)
    duration = duration or 4

    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    -- move the camera of the left world view, fallback to the right world view
    local worldview = WorldViewManager.viewLeft or WorldViewManager.viewRight --[[@as WorldView]]
    local camera = GetCameraOfWorldview(worldview)
    local worldCoordinates = GetMouseWorldPos()

    ForkThread(
        function()
            WaitFor(camera)
            MoveTo(worldview, worldCoordinates, duration)
        end
    )
end

--- Applies the `MoveTo` functionality to the left world view using the world coordinates of the mouse. Falls back to the left world view.
---@param duration? number
MoveToRight = function(duration)
    duration = duration or 4

    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    -- move the camera of the right world view, fallback to the left world view
    local worldview = WorldViewManager.viewRight or WorldViewManager.viewLeft --[[@as WorldView]]
    local worldCoordinates = GetMouseWorldPos()

    MoveTo(worldview, worldCoordinates, duration)
end

--- Applies the `MoveTo` functionality to the left world view using the world coordinates of the mouse. Falls back to the left world view. Is applied after the current camera navigation is finished.
---@param duration? number
QueueMoveToRight = function(duration)
    duration = duration or 4

    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    -- move the camera of the left world view, fallback to the right world view
    local worldview = WorldViewManager.viewRight or WorldViewManager.viewLeft --[[@as WorldView]]
    local camera = GetCameraOfWorldview(worldview)
    local worldCoordinates = GetMouseWorldPos()

    ForkThread(
        function()
            WaitFor(camera)
            MoveTo(worldview, worldCoordinates, duration)
        end
    )
end

--- Snaps the world view to the world coordinates.
---@param worldview WorldView
---@param worldCoordinates Vector
---@param duration number
SnapTo = function(worldview, worldCoordinates, duration)
    local camera = GetCameraOfWorldview(worldview)
    local cameraSettings = camera:SaveSettings()
    camera:SnapTo(worldCoordinates, { cameraSettings.Heading, cameraSettings.Pitch, 0 }, cameraSettings.Zoom)

    if Config.CreateUserFeedback then
        -- help the user understand what is happening
        local userDecalScale = 5
        local userDecalTexture = "/textures/selection_bracket_player_sm.dds"
        local userDecal = CreateTemporaryDecal(
            worldCoordinates,
            userDecalTexture,
            userDecalScale, duration
        )
        AnimateScaleAtPosition(userDecal, worldCoordinates, userDecalScale, duration)
    end
end

--- Applies the `SnapTo` functionality to the left world view using the world coordinates of the mouse.
SnapToLeft = function(duration)
    duration = duration or 1

    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    -- move the camera of the left world view, fallback to the right world view
    local worldview = WorldViewManager.viewLeft or WorldViewManager.viewRight --[[@as WorldView]]
    local worldCoordinates = GetMouseWorldPos()
    SnapTo(worldview, worldCoordinates, duration)
end

--- Applies the `SnapTo` functionality to the right world view using the world coordinates of the mouse. Falls back to the left world view.
SnapToRight = function(duration)
    duration = duration or 1

    local WorldViewManager = import("/lua/ui/game/worldview.lua")

    -- move the camera of the left world view, fallback to the right world view
    local worldview = WorldViewManager.viewLeft or WorldViewManager.viewRight --[[@as WorldView]]
    local worldCoordinates = GetMouseWorldPos()
    SnapTo(worldview, worldCoordinates, duration)
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
    import("/mods/fa-casting-cinematics/src/Config.lua").ApplyDefaultKeyLayout()
end

--#endregion
