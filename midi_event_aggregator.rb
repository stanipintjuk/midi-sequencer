def wait_for_magic_keys()
  loop do
    event_name, _ = sync $midi_sequencer_midi_event_addr
    if (event_name == "magic_key") then
      break
    end
  end
end

def wait_for_note_key(return_magic_keys = false)
  loop do
    event, event_data = sync $midi_sequencer_midi_event_addr
    if (event == "magic_key" and return_magic_keys) then
      return "magic_key"
    elsif (event == "note_on") then
      if (return_magic_keys and event_data[0] == $magic_keys[0][1]) then
        # if the key is start of magic key sequence then wait a beat and see if it indeed is the magic sequence
        (8 * 3).times do
          event, event_data = get $midi_sequencer_midi_event_addr
          if (event == "magic_key" and return_magic_keys) then
            return "magic_key"
          end
          sleep 3.0 / (8.0 * 3)
        end
      end
      return event_data[0]
    end
  end
end

def wait_for_cc_value(cc_num, return_magic_keys = false)
  loop do
    event, event_data = sync $midi_sequencer_midi_event_addr
    if (event == "magic_key" and return_magic_keys) then
      return "magic_key"
    elsif (event == "control_change" and event_data[0] == cc_num) then
      return event_data[1]
    end
  end
end

def wait_for_cc_value_or_note_key(cc_num, return_magic_keys = false)
  loop do
    event = sync $midi_sequencer_midi_event_addr
    if (event[0] == "magic_key" and return_magic_keys) then
      return "magic_key"
    elsif (event[0] == "control_change" and event[1][0] == cc_num) then
      return event
    elsif (event[0] == "note_on") then
      return event
    end
  end
end


def run_midi_event_aggregator()
  live_loop :midi_note_on_event_listener do
    use_bpm 60
    note_on = sync "#{$midi_device_addr}/note_on"
    set $midi_sequencer_midi_event_addr, ["note_on", note_on]
  end
  
  live_loop :midi_note_off_event_listener do
    note_off = sync "#{$midi_device_addr}/note_off"
    set $midi_sequencer_midi_event_addr, ["note_off", note_off]
  end
  
  live_loop :midi_cc_event_listener do
    cc = sync "#{$midi_device_addr}/control_change"
    set $midi_sequencer_midi_event_addr, ["control_change", cc]
  end
  
  live_loop :magic_key_listener do
    magic_key_pressed = true
    $magic_keys.each.with_index do |magic_key, index|
      event, event_data = sync $midi_sequencer_midi_event_addr
      
      if (event != magic_key[0] || event_data[0] != magic_key[1]) then
        magic_key_pressed = false
        break
      end
    end
    
    if (magic_key_pressed) then
      set $midi_sequencer_midi_event_addr, ["magic_key", $magic_keys]
    end
  end
end

