extends Node
## Proste dźwięki generowane w kodzie (autoload "Sfx").
## Prototyp bez plików audio: każdy dźwięk to krótka synteza PCM.
## Docelowo podmienić na pliki z audio/sfx/.

const MIX_RATE := 22050
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _ui_player: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	_streams = {
		&"plant": _synth(0.16, _wave_plant),
		&"harvest": _synth(0.22, _wave_harvest),
		&"water": _synth(0.4, _wave_water),
		&"fill": _synth(0.32, _wave_fill),
		&"snap": _synth(0.09, _wave_snap),
		&"deny": _synth(0.14, _wave_deny),
		&"chime": _synth(1.0, _wave_chime),
		&"hurt": _synth(0.25, _wave_hurt),
		&"zap": _synth(0.22, _wave_zap),
		&"stun": _synth(0.5, _wave_stun),
		&"roar": _synth(0.7, _wave_roar),
		&"bite": _synth(0.12, _wave_snap),
		&"pickup": _synth(0.18, _wave_pickup),
		&"scan": _synth(0.35, _wave_scan),
		&"eat": _synth(0.25, _wave_eat),
		&"throw": _synth(0.25, _wave_throw),
		&"alarm": _synth(1.2, _wave_alarm),
		&"evac": _synth(0.9, _wave_evac),
		&"boom": _synth(0.45, _wave_boom),
		&"craft": _synth(0.3, _wave_craft),
		&"land": _synth(0.6, _wave_land),
	}
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 6.0
		add_child(player)
		_players.append(player)
	_ui_player = AudioStreamPlayer.new()
	add_child(_ui_player)


## Odtwarza dźwięk w świecie. Bez pozycji = dźwięk interfejsu.
func play(id: StringName, position = null, pitch_jitter := 0.08) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	if position == null:
		_ui_player.stream = stream
		_ui_player.pitch_scale = 1.0
		_ui_player.play()
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.global_position = position
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


# --- Przebiegi (t = czas w sekundach, wynik -1..1) ---------------------------

func _wave_plant(t: float) -> float:
	return sin(TAU * 110.0 * t) * exp(-t * 22.0) * 0.8 + randf_range(-1, 1) * exp(-t * 45.0) * 0.25


func _wave_harvest(t: float) -> float:
	var phase := TAU * 900.0 * (1.0 - exp(-t * 14.0)) / 14.0
	return sin(phase) * exp(-t * 16.0) * 0.7


func _wave_water(t: float) -> float:
	return randf_range(-1, 1) * exp(-t * 7.0) * (0.55 + 0.45 * sin(TAU * 26.0 * t)) * 0.35


func _wave_fill(t: float) -> float:
	var phase := TAU * (260.0 * t + 700.0 * t * t)
	return sin(phase) * (1.0 - t / 0.32) * 0.4


func _wave_snap(t: float) -> float:
	return sin(TAU * 320.0 * t) * exp(-t * 55.0) * 0.6 + randf_range(-1, 1) * exp(-t * 90.0) * 0.5


func _wave_deny(t: float) -> float:
	return signf(sin(TAU * 140.0 * t)) * exp(-t * 18.0) * 0.18


func _wave_chime(t: float) -> float:
	var v := sin(TAU * 660.0 * t) * exp(-t * 4.0) * 0.35
	if t > 0.14:
		v += sin(TAU * 880.0 * (t - 0.14)) * exp(-(t - 0.14) * 4.0) * 0.3
	return v


func _wave_hurt(t: float) -> float:
	return sin(TAU * 90.0 * t) * exp(-t * 14.0) * 0.8 + randf_range(-1, 1) * exp(-t * 25.0) * 0.35


func _wave_zap(t: float) -> float:
	var phase := TAU * (1800.0 * t - 2600.0 * t * t)
	return signf(sin(phase)) * exp(-t * 10.0) * 0.18


func _wave_stun(t: float) -> float:
	return sin(TAU * (500.0 + 120.0 * sin(TAU * 9.0 * t)) * t) * exp(-t * 4.0) * 0.3


func _wave_roar(t: float) -> float:
	var f := 70.0 + 25.0 * sin(TAU * 7.0 * t)
	var saw := 2.0 * fmod(f * t, 1.0) - 1.0
	return (saw * 0.5 + randf_range(-1, 1) * 0.3) * minf(t * 10.0, 1.0) * exp(-t * 2.5) * 0.6


func _wave_pickup(t: float) -> float:
	var f := 660.0 if t < 0.07 else 990.0
	return sin(TAU * f * t) * exp(-t * 14.0) * 0.4


func _wave_scan(t: float) -> float:
	var phase := TAU * (400.0 * t + 2400.0 * t * t)
	return sin(phase) * (0.5 + 0.5 * sin(TAU * 30.0 * t)) * exp(-t * 5.0) * 0.3


func _wave_eat(t: float) -> float:
	var crunch := 1.0 if fmod(t, 0.08) < 0.03 else 0.2
	return randf_range(-1, 1) * crunch * exp(-t * 7.0) * 0.4


func _wave_throw(t: float) -> float:
	return randf_range(-1, 1) * sin(PI * t / 0.25) * 0.25


func _wave_alarm(t: float) -> float:
	var f := 520.0 if fmod(t, 0.4) < 0.2 else 390.0
	return sin(TAU * f * t) * 0.25 * (1.0 - t / 1.2)


func _wave_evac(t: float) -> float:
	var phase := TAU * (300.0 * t + 300.0 * t * t)
	return sin(phase) * minf(t * 5.0, 1.0) * (1.0 - t / 0.9) * 0.35


func _wave_boom(t: float) -> float:
	# Głuchy "puff": szum + niski ton, szybko gasnący.
	var env := exp(-t * 9.0)
	return (randf_range(-1, 1) * 0.6 + sin(TAU * 70.0 * t) * 0.6) * env * 0.5


func _wave_craft(t: float) -> float:
	# Dwa stuknięcia młotka i dzwoneczek.
	var knock := 0.0
	for start in [0.0, 0.1]:
		var local: float = t - start
		if local >= 0.0:
			knock += sin(TAU * 420.0 * local) * exp(-local * 40.0)
	var bell := sin(TAU * 1320.0 * t) * exp(-maxf(0.0, t - 0.18) * 12.0) * (1.0 if t > 0.18 else 0.0)
	return (knock * 0.4 + bell * 0.2)


func _wave_land(t: float) -> float:
	var env := exp(-t * 6.0)
	return (randf_range(-1, 1) * 0.5 + sin(TAU * 55.0 * t) * 0.7) * env * 0.55


func _synth(duration: float, sample: Callable) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var value := clampf(sample.call(float(i) / MIX_RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
