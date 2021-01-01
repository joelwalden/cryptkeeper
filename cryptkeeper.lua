-- cryptkeeper
-- manage and create crypts
-- for arcologies
-- v1.0.0 Joel Walden (@wardores)
-- https://llllllll.co/t/cryptkeeper/39781
--
--
-- e1 = select slot
-- k1 = load sample
-- k2 = alt
-- k3 = play
-- alt + k3 = toggle loop
-- e2 = start point (coarse)
-- alt + e2 = start point (fine)
-- e3 = end point (coarse)
-- alt + e3 = end point (fine)

fileselect = require("fileselect")
textentry = require("textentry")
ui = require('ui')

MAX_SLOT_LENGTH = 28
SLOT_RESERVED_SPACE = 30
SAVE_PREFIX = _path.dust .. "audio/crypts/"
TABS = ui.Tabs.new(1, {"1", "2", "3", "4", "5", "6", "7", "8", "S/L"})

slots = {}
active_slot = 1
position = 1
save_load = false
load_page = false
waveform_loaded = false
selecting = false
is_saved = false
loop = 0
alt = 0


function file_select(file)
  if file ~= "cancel" then
    slots[active_slot].file = file
    slots[active_slot].start_pos = buffer_offset()
    slots[active_slot].end_pos = nil
    load_file(file)
  end
  selecting = false
  is_saved = false
  redraw()
end

function load_file(file)
  softcut.buffer_clear_region_channel(1,buffer_offset(),MAX_SLOT_LENGTH)
  local ch, samples = audio.file_info(file)
  local length = samples/48000
  slots[active_slot].length = length <= MAX_SLOT_LENGTH and length or MAX_SLOT_LENGTH
  softcut.buffer_read_mono(file,0,buffer_offset(),slots[active_slot].length + 0.1,1,1)
  slots[active_slot].end_pos = buffer_offset() + (slots[active_slot].end_pos == nil and slots[active_slot].length or slots[active_slot].end_pos)
  reset()
  waveform_loaded = true
end

function reset()
  softcut.loop(1,loop)
  softcut.loop_start(1,slots[active_slot].start_pos)
  softcut.loop_end(1,slots[active_slot].end_pos)
  softcut.position(1,slots[active_slot].start_pos)
  softcut.fade_time(1,0)
  softcut.play(1,0)
  update_content(1,buffer_offset(),buffer_offset() + slots[active_slot].length,128)
end

local interval = 0
waveform_samples = {}
scale = 20

function on_render(ch, start, i, s)
  waveform_samples = s
  interval = i
  redraw()
end

function update_positions(i,pos)
  position = ((pos - buffer_offset()) / (slots[active_slot].length))
  if selecting == false then redraw() end
end

function update_content(buffer,winstart,winend,samples)
  softcut.render_buffer(buffer, winstart, winend - winstart, 128)
end

function update_start_pos(d)
  is_saved = false
  delta = is_alt() and d * .005 or d * .5
  slots[active_slot].start_pos = util.clamp(slots[active_slot].start_pos + delta, buffer_offset(), buffer_offset() + slots[active_slot].length)
  softcut.loop_start(1, slots[active_slot].start_pos)
  redraw()  
end

function update_end_pos(d)
  is_saved = false
  delta = is_alt() and d * .005 or d * .5
  slots[active_slot].end_pos = util.clamp(slots[active_slot].end_pos + delta, slots[active_slot].start_pos, buffer_offset() + slots[active_slot].length)
  softcut.loop_end(1, slots[active_slot].end_pos)
  redraw()  
end

function update_active(index)
  active_slot = index
  TABS:set_index(active_slot)
end

-- rendering functions

function render_clip_slots()
  TABS:redraw()
end

function render_help_text()
  screen.level(15)
  screen.move(60,30)
  screen.text_center("Long press K1")
  screen.move(60, 40)
  screen.text_center("to load sample")
end

function render_waveform_buffer()
  local x_pos = 0
  screen.level(4)
  screen.move(82,10)
  for i,s in ipairs(waveform_samples) do
    local height = util.round(math.abs(s) * scale)
    screen.move(util.linlin(0,128,10,120,x_pos), 35 - height)
    screen.line_rel(0, 2 * height)
    x_pos = x_pos + 1
  end
  screen.stroke()
end

function render_position_indicator()
  screen.level(7)
  screen.move(util.linlin(0,1,10,120,position),18)
  screen.line_rel(0,35)
  screen.stroke()
end

function render_start_end_indicators()
  screen.level(15)
  screen.move(util.linlin(buffer_offset(),buffer_offset()+slots[active_slot].length,10,120,slots[active_slot].start_pos), 18)
  screen.line_rel(0,35)
  screen.stroke()
  screen.move(util.linlin(buffer_offset(),buffer_offset()+slots[active_slot].length,10,120,slots[active_slot].end_pos), 18)
  screen.line_rel(0,35)
  screen.stroke()
end

-- / rendering functions

-- save/load functions

function save_crypt(name)
  if name ~= "cancel" or name ~= nil then
    local save_directory = SAVE_PREFIX .. name
    util.make_dir(save_directory)
    for k,v in ipairs(slots) do
      if v.file ~= nil then
        softcut.buffer_write_mono(save_directory .. "/" .. k .. ".wav", v.start_pos, (v.end_pos - v.start_pos), 1)
      end
    end
    is_saved = true
    save_load = false
    update_active(1)
    reset_load_waveform()
    redraw()
  end
end

function load_crypt(name)
  if name ~= nil then
    files = {}
    pwd = SAVE_PREFIX .. name
    crypts_in_directory = util.os_capture("cd " .. pwd .. "&& ls -- *.wav")
    for f in string.gmatch(crypts_in_directory, "[^%s]+") do
      slot = tonumber(string.match(f, "%d"))
      if slot < 9 then
        active_slot = slot
        file_select(pwd .. f)
      end
    end
    load_page = false
    save_load = false
    update_active(1)
    reset_load_waveform()
    redraw()
  end
end

function get_crypts()
  val = {}
  crypt_directories = util.os_capture("cd " .. SAVE_PREFIX .. " && ls -d -- */")
  for directory in string.gmatch(crypt_directories, "[^%s]+") do
    table.insert(val, directory)
  end
  return val
end

-- /save/load functions

function init()
  for i=1,8 do
    slots[i] = {}
    slots[i].file = nil
    slots[i].start_pos = buffer_offset()
    slots[i].end_pos = nil
    slots[i].length = 1
  end
  
  softcut.buffer_clear()
  softcut.enable(1,1)
  softcut.buffer(1,1)
  softcut.level(1,1.0)
  softcut.rate(1,1.0)
  
  audio.level_adc_cut(1)
  softcut.level_input_cut(1,2,1.0)
  softcut.level_input_cut(2,2,1.0)
  
  softcut.phase_quant(1,0.01)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  softcut.event_render(on_render)
  
  
  save_menu = ui.List.new(10,20,1,{"Save", "Load"})
  load_menu = ui.ScrollingList.new(10,20,1,get_crypts())
end

function redraw()
  screen.clear()
  render_clip_slots()
 
  if not save_load then
    if not waveform_loaded then
      render_help_text()
    else
      render_waveform_buffer()
      render_position_indicator()
      render_start_end_indicators()
    end
    if is_loop() then
      screen.move(120, 60)
      screen.text("L")
    end
    if is_saved then
      screen.move(10, 60)
      screen.text("saved")
    end
  else
    if not load_page then
      save_menu:redraw()
    else
      load_menu:redraw()
    end
  end
  screen.update()
end

function enc(n,d)
  if n == 1 then
    softcut.play(1,0)
    new_index = util.clamp(active_slot + d,1,9)
    update_active(new_index)
    if active_slot == 9 then
      save_load = true
    else
      save_load = false
      reset_load_waveform()
    end
    redraw()
  end
  if n == 2 then
    if not save_load then
      update_start_pos(d)
    else
      if not load_page then
        save_menu:set_index_delta(d, false)
        redraw()
      else
        load_menu:set_index_delta(d, true)
        redraw()
      end
    end
  end
  if n == 3 then
    if not save_load then
      update_end_pos(d)
    end
  end
end

function key(n,z)
  if n==1 and z==1 then
    selecting = true
    fileselect.enter(_path.dust .. "audio", file_select)
  end
  if n==2 then
    if not load_page then
      alt = z 
    elseif load_page then
      load_page = false
      redraw()
    end
  end
  if n==3 and z==1 then
    if not save_load then
      if is_alt() then
        loop = 1 - loop
        softcut.fade_time(1,0.1)
        softcut.loop(1,loop)
        redraw()
        if not is_loop() then
          reset()
        end
      else
        if waveform_loaded then
          reset()
          softcut.play(1,1)
        end
      end
    else
      if not load_page then
        if save_menu.index == 1 then
          textentry.enter(save_crypt)
        elseif save_menu.index == 2 then
          load_page = true
          redraw()
        end
      else
        load_crypt(load_menu.entries[load_menu.index])
      end
    end
  end
end

-- random shorcuts
function reset_load_waveform()
  waveform_loaded = slots[active_slot].file ~= nil
  if waveform_loaded then
    reset()
  end
end
function buffer_offset()
  return (active_slot - 1) * SLOT_RESERVED_SPACE + 1
end

function is_alt()
  return alt == 1
end

function is_loop()
  return loop == 1
end
