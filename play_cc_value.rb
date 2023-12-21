$MIDI_GLIDE_VALUE_MAX=127
def play_cc_value(cc_num, next_value, old_value, tparams: nil, note_length: nil)
  bpm = get_bpm
  bps = bpm.to_f / 60.0
  time_per_frame = 1.0 / $fps.to_f
  time_step_in_beats = time_per_frame * bps

  if tparams == nil then
    tparams = get_transition_params
  end
  
  if note_length == nil then
    note_length = get_note_length
  end
  
  time_points = (note_length.to_f / time_step_in_beats.to_f).to_i
  time_points_rest = note_length - (time_points * time_step_in_beats) # the rest of the time that is not covered by the time points

  prev_val = -1

  time_points.times do |tp|
    real_time = tp * time_step_in_beats
    normalized_time = real_time.to_f / note_length.to_f
    value_mix = best_function_in_the_world(x: normalized_time, f: tparams[:f], a: tparams[:a], p: tparams[:p], s: tparams[:s], t: tparams[:t], k: tparams[:k])
    cc_value = mix_values(old_value, value_mix, next_value)
    if cc_value != prev_val then
      midi_cc cc_num, cc_value
    end
    prev_val = cc_value
    sleep time_step_in_beats
  end
  sleep time_points_rest if time_points_rest > 0
end

##
# from - starting value
# mixer - value between 0 and 1
# to - ending value
# returns a value between from and to proportional to the mixer value
##
def mix_values(from, mixer, to)
  return from + (to - from) * mixer
end

##
# x - normalized time value between 0 (note start) and 1 (note end)
# f - controlls frequency. 0 < k < 127. lower f means wider wave (lower frequency)
# a - controlls amplitude. 0 < n < 127. lower a means lower amplitude
# p - controls the phase. 0 < p < 127
# s - controlls the flatness of the square. 0 < b < 12
# t - controlls the weight of the triangle function
# k - controlls the k factor of the underlying linear function
def best_function_in_the_world(x:, f:, a:, p:, s:, t:, k:)
  # convert midi values to something more usable
  k =  128.0 / (k.to_f + 1.0)
  f = f.to_f * k # multiply by k to make the frequency constant during change of k
  a = 10.0 / ((a.to_f + 1.0) * 20 / 127)
  p = (p.to_f / 127.0) * 2
  s = s.to_f / 7
  t = t.to_f / 127.0
  
  f = x * k + squatri((x - p) * f, s, t) / a
  return [[f, 1].min, 0].max
end

##
# Combination of the square and the triangle function.
# s - controlls the flatness of the square. 0 < b < 12
# t - controlls the weight of the triangle function. The higher the more triangle
def squatri(x, s, t)
  return (t * tri(x / Math::PI*2) + (1 - t) * square(x, s)) / 2
end

def tri(x)
  return 4 * (x - (x + 3.0/4.0).floor + 1.0 / 4.0 ).abs - 1
end

##
# s - the flatnes of the sqaure. the lower the more round. 0 < p < 12
##
def square(x, s)
  return Math.sqrt((1 + s**2).to_f/(1 + s**2 * Math.sin(x)**2).to_f)*Math.sin(x)
end
