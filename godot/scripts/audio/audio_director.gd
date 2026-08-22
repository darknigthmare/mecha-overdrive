class_name AudioDirector
extends Node

## Real-time procedural mix. The game ships without copyrighted music or audio
## files; engine, ambience, rhythm bed and feedback are synthesized locally.

const MIX_RATE := 22050.0

var speed_ratio := 0.0
var boost_amount := 0.0
var damage_ratio := 0.0
var chassis_tone := 1.0
var master_gain := 0.72
var music_gain := 0.46
var sfx_gain := 0.8
var engine_gain := 0.72
var muted := false

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase_engine := 0.0
var _phase_motor := 0.0
var _phase_music := 0.0
var _sample_clock := 0.0
var _events: Array[Dictionary] = []


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralMix"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.28
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func configure(settings: Dictionary) -> void:
	master_gain = clampf(float(settings.get("master_volume", settings.get("volume", 0.72))), 0.0, 1.0)
	music_gain = clampf(float(settings.get("music_volume", 0.46)), 0.0, 1.0)
	sfx_gain = clampf(float(settings.get("sfx_volume", 0.8)), 0.0, 1.0)
	engine_gain = clampf(float(settings.get("engine_volume", 0.72)), 0.0, 1.0)
	muted = bool(settings.get("muted", false))


func set_motion(next_speed_ratio: float, boosting: bool, next_damage_ratio: float, tone: float = 1.0) -> void:
	speed_ratio = clampf(next_speed_ratio, 0.0, 1.6)
	boost_amount = move_toward(boost_amount, 1.0 if boosting else 0.0, 0.08)
	damage_ratio = clampf(next_damage_ratio, 0.0, 1.0)
	chassis_tone = clampf(tone, 0.62, 1.55)


func play_event(event_name: String) -> void:
	var preset := {
		"pickup": [880.0, 0.2, 0.35],
		"boost": [135.0, 0.38, 0.5],
		"impact": [72.0, 0.22, 0.7],
		"shield": [520.0, 0.5, 0.32],
		"emp": [94.0, 0.46, 0.55],
		"finish": [660.0, 0.95, 0.42],
		"count": [330.0, 0.16, 0.25],
		"go": [760.0, 0.4, 0.42],
	}.get(event_name, [440.0, 0.14, 0.22])
	_events.append({"frequency": preset[0], "remaining": preset[1], "duration": preset[1], "gain": preset[2], "phase": 0.0})


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for _index in range(frames):
		_playback.push_frame(_sample_frame())


func _sample_frame() -> Vector2:
	var engine_hz := (42.0 + speed_ratio * 118.0 + boost_amount * 38.0) * chassis_tone
	_phase_engine = fmod(_phase_engine + engine_hz / MIX_RATE, 1.0)
	_phase_motor = fmod(_phase_motor + engine_hz * 2.013 / MIX_RATE, 1.0)
	_phase_music = fmod(_phase_music + 55.0 / MIX_RATE, 1.0)
	_sample_clock += 1.0 / MIX_RATE

	var saw := _phase_engine * 2.0 - 1.0
	var motor := sin(_phase_motor * TAU) * 0.5 + saw * 0.32
	motor *= (0.055 + speed_ratio * 0.07 + boost_amount * 0.035) * engine_gain
	motor *= 1.0 - damage_ratio * 0.2

	var beat_phase := fmod(_sample_clock * 2.4, 1.0)
	var kick := sin(_phase_music * TAU) * exp(-beat_phase * 15.0) * 0.12
	var pulse := sin(_phase_music * TAU * 1.5) * (0.018 if beat_phase < 0.5 else 0.009)
	var music := (kick + pulse) * music_gain

	var event_mix := 0.0
	for event in _events:
		var duration: float = event.duration
		var remaining: float = event.remaining
		var envelope := clampf(remaining / maxf(0.001, duration), 0.0, 1.0)
		event.phase = fmod(float(event.phase) + float(event.frequency) / MIX_RATE, 1.0)
		event_mix += sin(float(event.phase) * TAU) * envelope * float(event.gain) * sfx_gain
		event.remaining = remaining - 1.0 / MIX_RATE
	_events = _events.filter(func(event: Dictionary) -> bool: return float(event.remaining) > 0.0)

	var sample := clampf((motor + music + event_mix) * master_gain * (0.0 if muted else 1.0), -0.92, 0.92)
	return Vector2(sample, sample)
