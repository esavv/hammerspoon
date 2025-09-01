-- === Cmd+C success/failure notifier ===
local last = hs.pasteboard.changeCount()

-- Toast constants
local TOAST_DURATION = 1.0
local TOAST_COLOR_OK = { green = 0.2, alpha = 0.95 }
local TOAST_COLOR_FAIL = { red = 0.7, alpha = 0.95 }
local TOAST_TEXT_COLOR = { white = 1 }
local TOAST_SOUND_OK = "Tink"
local TOAST_SOUND_FAIL = "Basso"
local TOAST_OK_W, TOAST_OK_H = 80, 28
local TOAST_FAIL_W, TOAST_FAIL_H = 100, 28

-- debug logger
local log = hs.logger.new("copy", "debug")

-- forward declare for mouse toast defined below so "mouse" placement works
local toastAtMouse

local function flash(text, ok)
  local secs = TOAST_DURATION
  toastAtMouse(text, ok, secs)
end

-- after a Cmd+C, wait a tick to let the app update the clipboard, then test
local function checkAfterCopy()
  hs.timer.doAfter(0.15, function()
    local okCheck, err = pcall(function()
      local current = hs.pasteboard.changeCount()
      local changed = current > last
      if changed then
        last = current
        flash("✓ Copied", true)
      else
        flash("✗ Copy failed", false)
      end
    end)
    if not okCheck and log then log.e("timer check error: " .. tostring(err)) end
  end)
end

-- event tap for keyDown of “C” with Cmd (no Opt/Ctrl); allow Shift
local ev = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  local okTap, err = pcall(function()
    if e:getKeyCode() == hs.keycodes.map.c then
      local f = e:getFlags()
      if f.cmd and not f.alt and not f.ctrl then
        checkAfterCopy()
      end
    end
  end)
  if not okTap and log then log.e("eventtap error: " .. tostring(err)) end
  return false  -- don't block the keystroke
end):start()

hs.alert.show("Cmd+C notifier loaded")

-- Watchdog: detect Secure Input and keep the event tap healthy
local secureInputLast = hs.eventtap.isSecureInputEnabled()
local watchdogTimer = hs.timer.doEvery(5, function()
  local secure = hs.eventtap.isSecureInputEnabled()
  local enabled = ev:isEnabled()

  if secure then
    if not secureInputLast then
      -- only notify on transition into Secure Input
      flash("🔒 Secure Input active", false)
      if log then log.w("Secure Input active") end
    end
  else
    if secureInputLast and log then log.i("Secure Input cleared") end
    if not enabled then
      ev:start()
      if log then log.w("event tap restarted by watchdog") end
      flash("↻ Restored copy watcher", true)
    end
  end

  secureInputLast = secure
end)

-- Tiny toast near the mouse using hs.canvas
toastAtMouse = function(text, ok, secs)
  local pos = hs.mouse.getAbsolutePosition()
  local w = ok and TOAST_OK_W or TOAST_FAIL_W
  local h = ok and TOAST_OK_H or TOAST_FAIL_H
  local x, y = pos.x - (w/2), pos.y + 16  -- under the cursor; make negative to show above

  local fill = ok and TOAST_COLOR_OK or TOAST_COLOR_FAIL

  local canvas = hs.canvas.new({ x = x, y = y, w = w, h = h })
  canvas:appendElements(
    {
      type = "rectangle",
      action = "fill",
      fillColor = fill,
      roundedRectRadii = { xRadius = 8, yRadius = 8 }
    },
    {
      type = "text",
      text = text,
      textSize = 12,
      textColor = TOAST_TEXT_COLOR,
      textAlignment = "center",
      frame = { x = 8, y = 6, w = w - 16, h = h - 12 }
    }
  )
  canvas:show()

  local name = ok and TOAST_SOUND_OK or TOAST_SOUND_FAIL
  local snd = hs.sound.getByName(name)
  if snd then snd:play() end

  hs.timer.doAfter(secs or TOAST_DURATION, function()
    if canvas then canvas:delete() end
  end)
end
