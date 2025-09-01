-- === Cmd+C success/failure notifier ===
local last = hs.pasteboard.changeCount()

-- Centered alert + custom duration
local DURATION_OK   = 0.9   -- tweak
local DURATION_FAIL = 1.2   -- tweak

-- choose: "center" or "mouse"
local PLACEMENT = "center"   -- change to "center" if you prefer

local function flash(text, ok)
  local secs = ok and DURATION_OK or DURATION_FAIL
  if PLACEMENT == "mouse" then
    toastAtMouse(text, ok, secs)
  else
    -- centered alert path
    hs.alert.closeAll(0)
    local style = {
      textSize = 14,
      fillColor = ok and { green = 0.2, alpha = 0.9 } or { red = 0.7, alpha = 0.9 },
      strokeColor = { alpha = 0.0 },
      radius = 10
    }
    hs.alert.show(text, style, hs.mouse.getCurrentScreen(), secs)
    local name = ok and "Pop" or "Basso"
    local snd = hs.sound.getByName(name)
    if snd then snd:play() end
  end
end

-- after a Cmd+C, wait a tick to let the app update the clipboard, then test
local function checkAfterCopy()
  hs.timer.doAfter(0.15, function()
    local c = hs.pasteboard.changeCount()
    if c > last then
      last = c
      flash("✓ Copied", true)
    else
      flash("✗ Copy failed", false)
    end
  end)
end

-- event tap for keyDown of “C” with Cmd (no Opt/Ctrl); allow Shift
local ev = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  if e:getKeyCode() == hs.keycodes.map.c then
    local f = e:getFlags()
    if f.cmd and not f.alt and not f.ctrl then
      checkAfterCopy()
    end
  end
  return false  -- don't block the keystroke
end):start()

hs.alert.show("Cmd+C notifier loaded")

-- Tiny toast near the mouse using hs.canvas
local function toastAtMouse(text, ok, secs)
  local pos = hs.mouse.getAbsolutePosition()
  local w, h = 220, 44
  local x, y = pos.x - (w/2), pos.y + 24  -- under the cursor; make negative to show above

  local fill = ok and { green = 0.2, alpha = 0.95 } or { red = 0.7, alpha = 0.95 }

  local canvas = hs.canvas.new({ x = x, y = y, w = w, h = h })
  canvas:appendElements(
    {
      type = "rectangle",
      action = "fill",
      fillColor = fill,
      roundedRectRadii = { xRadius = 10, yRadius = 10 }
    },
    {
      type = "text",
      text = text,
      textSize = 14,
      textColor = { white = 1 },
      textAlignment = "center",
      frame = { x = 10, y = 8, w = w - 20, h = h - 16 }
    }
  )
  canvas:show()

  local name = ok and "Pop" or "Basso"
  local snd = hs.sound.getByName(name)
  if snd then snd:play() end

  hs.timer.doAfter(secs or 0.9, function()
    if canvas then canvas:delete() end
  end)
end
