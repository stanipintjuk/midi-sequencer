run_midi_event_aggregator

## playback control function getters and setters
# assuming input value is between 0 and 127
##

def set_transition_param(param, value)
  tparams = get_transition_params
  tparams = tparams.to_h
  tparams[param] = value
  set $midi_sequencer_addr + "/transition_params", tparams
end

def get_transition_params()
  (get $midi_sequencer_addr + "/transition_params") || {:f => 0, :a => 0, :p => 0, :s => 0, :t => 0, :k => 10}
end

def set_note_length(value)
  # reduces the 128 possible midi values to 8 possible values
  lengths = [0.125, 0.25, 0.5, 1, 2, 4, 8, 16]
  i = (((value.to_f / 128.to_f) * 8).to_i)
  set $midi_sequencer_addr + "/note_length", lengths[i]
end

def get_note_length()
  return (get $midi_sequencer_addr + "/note_length") || 1
end

def set_bpm(value)
  set $midi_sequencer_addr + "/bpm", (value + 1) * 2
end

def get_bpm()
  return (get $midi_sequencer_addr + "/bpm") || 110
end


def clear_sequence()
  set $midi_sequencer_notes_addr, nil
end

# Sequencer has 8 steps 48 - 60 (no half notes)
def record_sequence()
  loop do
    puts "Recording sequence"
    puts "current sequence: #{get $midi_sequencer_notes_addr}"
    
    # select step (as a note)
    puts "waiting for key from #{$midi_device_addr}}"
    selected_step = nil
    key = wait_for_note_key true
    if key == "magic_key" then
      puts "got cancel key. Exiting recorder"
      return
    end
    
    selected_step = key
    
    puts "selected step: #{selected_step}"
    
    # loop until user enters done sequence and keep updating the cc value (for user feedback)
    input_cc_value = nil
    loop do
      puts "in tuning stage"
      event, event_data = wait_for_cc_value_or_note_key $input_cc_num, true
      if event == "magic_key" then
        puts "Got cancel key. Saving the currently set tune"
        return
      elsif event == "note_on" then
        selected_step = event_data[0]
        step_cc_value = get_step selected_step
        midi_cc $output_cc_num, step_cc_value
      else
        input_cc_value = event_data[1]
        midi_cc $output_cc_num, input_cc_value
        save_step selected_step, input_cc_value
      end
    end
  end
end

def get_step(step)
  sequence = (get $midi_sequencer_notes_addr) || {}
  sequence = sequence.to_h
  return sequence[step] || 0
end

def save_step(step, cc_value)
  sequence = (get $midi_sequencer_notes_addr) || {}
  sequence = sequence.to_h
  sequence[step] = cc_value
  set $midi_sequencer_notes_addr, sequence
end

def sync_midi_device(play)
  with_real_time do
    stop_playing = false
    
    in_thread do
      wait_for_magic_keys
      stop_playing = true
    end
    
    in_thread do
      first_run = true
      loop do
        bpm = get_bpm
        use_bpm bpm
        if stop_playing then
          midi_stop
          stop
        end
        midi_continue if first_run && play
        midi_clock_beat
        first_run = false
        sleep 0.5
      end
    end
  end
end


# play the sequence
def play_sequence(playback_controls: true)
  sync_midi_device (playback_controls == false)
  old_cc_value = 0
  stop_playing = false
  
  # playback controls.
  # 49 - control tparams[:f]
  # 51 - control tparams[:a]
  # 54 - control tparams[:p]
  # 56 - control tparams[:s]
  # 58 - control tparams[:t]
  # 61 - control tparams[:k]
  # 63 - control note length
  # 65 - control bpm
  in_thread do
    control_value = 49
    loop do
      event, event_data = wait_for_cc_value_or_note_key $input_cc_num, true
      if event == "magic_key" then
        puts "Got cancel key. Stopping playback"
        stop_playing = true
        stop
      end
      
      if (playback_controls) then
        if event == "note_on" then
          control_value = event_data[0]
        else
          if control_value == 49 then
            set_transition_param :f, event_data[1]
          elsif control_value == 51 then
            set_transition_param :a, event_data[1]
          elsif control_value == 54 then
            set_transition_param :p, event_data[1]
          elsif control_value == 56 then
            set_transition_param :s, event_data[1]
          elsif control_value == 58 then
            set_transition_param :t, event_data[1]
          elsif control_value == 61 then
            set_transition_param :k, event_data[1]
          elsif control_value == 63 then
            set_note_length event_data[1]
          elsif control_value == 65 then
            set_bpm event_data[1]
          end
        end
      end
    end
  end
  
  loop do
    sequence = get $midi_sequencer_notes_addr
    sequence = sequence.to_h
    
    if (sequence == nil) then
      puts "is nil"
      break
    end
    puts "sequence: #{sequence}"
    puts "sequence.sort: #{sequence.sort}"
    sequence.sort.each do |step, cc_value|
      bpm = get_bpm
      use_bpm bpm
      
      if stop_playing then
        midi_stop
        return
      end
      
      puts "playing step #{step} with value #{cc_value}"
      play_cc_value $output_cc_num, cc_value, old_cc_value # TODO: spelar fel sekvens???
      old_cc_value = cc_value
    end
  end
end

def notify(notify_name)
  with_bpm 60 do
    nl = 1.to_f
    tparams = {:f => 0, :a => 0, :p => 0, :s => 0, :t => 0, :k => 127}
    tparams_no_glide = {:f => 0, :a => 0, :p => 0, :s => 0, :t => 0, :k => 0}
    
    if notify_name == "idle" then
      play_cc_value $output_cc_num, 0, 127, tparams: tparams, note_length: nl
    elsif notify_name == "menu" then
      play_cc_value $output_cc_num, 127, 64, tparams: tparams, note_length: nl
      play_cc_value $output_cc_num, 0, 127, tparams: tparams_no_glide, note_length: nl
    elsif notify_name == "recording" then
      play_cc_value $output_cc_num, 0, 127, tparams: tparams, note_length: nl / 2
      play_cc_value $output_cc_num, 0, 127, tparams: tparams, note_length: nl / 2
    elsif notify_name == "clear" then
      play_cc_value $output_cc_num, 100, 127, tparams: tparams, note_length: nl / 2
      play_cc_value $output_cc_num, 127, 100, tparams: tparams, note_length: nl / 2
      play_cc_value $output_cc_num, 100, 0, tparams: tparams, note_length: nl / 2
    end
  end
end

## Halt until the magic keys are pressed
# magic keys are pressed the following 48, 50, 52
live_loop :midi_sequencer_menu do
  current_bpm = get_bpm
  use_bpm current_bpm
  
  notify "idle"
  puts "Sequencer idle state. Waiting for magic keys"
  wait_for_magic_keys
  puts "got magic keys"
  
  # menu items
  notify "menu"
  puts "Menu: 48 - record sequence, 50 - play sequence with controls, 52 - play sequence, 53 - clear sequence"
  key = wait_for_note_key
  puts "Got #{key}"
  if (key == 48) then
    notify "recording"
    record_sequence
  elsif (key == 50)
    play_sequence playback_controls: true
  elsif (key == 52)
    play_sequence playback_controls: false
  elsif (key == 53)
    notify "clear"
    clear_sequence
  end
  sleep 0.5
  
end

