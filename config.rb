$device = "crave" # change this to the desired output device.
$port = 1 # change this to the desired output port

# The "magic sequence" is used to control the sequencer. Pick something that is not likely to be played.
$magic_keys = [["note_on", 48], ["note_on", 50], ["note_on", 52], ["note_off", 52], ["note_off", 50], ["note_off", 48]]

$fps = 30 # "Frames" per second. How many times per second the CC values should change

$input_cc_num = 5 # The CC that the user will use to set the CC values during sequencing.
$output_cc_num = 1 # The CC that will get the sequencers output
