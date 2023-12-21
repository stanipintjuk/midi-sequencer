$midi_device_addr = "/midi:#{$device}:#{$port}"

$midi_sequencer_addr = "/sequencer#{$midi_device_addr}"
$midi_sequencer_notes_addr = "#{$midi_sequencer_addr}/notes"
$midi_sequencer_midi_event_addr = "#{$midi_sequencer_addr}/midi_event"

$read_cc_addr = "#{$midi_device_addr}/control_change"
