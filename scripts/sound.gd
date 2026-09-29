extends Node

var voices: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var next_voice := 0
var bite_cooldown := 0.0

func _ready() -> void:
	for index in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -16
		add_child(voice)
		voices.append(voice)
	for name in ["eat", "warn", "success", "fail", "break", "win", "splash"]:
		var notes: Array = {"eat":[660.0, 880.0], "warn":[330.0, 220.0], "success":[440.0, 660.0, 880.0], "fail":[220.0, 165.0], "break":[880.0, 220.0], "win":[440.0, 554.0, 660.0, 880.0], "splash":[170.0,130.0,85.0]}[name]
		var bytes := PackedByteArray()
		var duration := 0.075 if name == "eat" else 0.13
		var count := int(22050 * duration * notes.size())
		bytes.resize(count * 2)
		for sample in count:
			var time := float(sample) / 22050
			var frequency: float = notes[mini(int(time / duration), notes.size() - 1)]
			var phase := fmod(time, duration) / duration
			var wave := (1.0 if sin(TAU * frequency * time) > 0 else -1.0) * 0.16 * sin(PI * phase)
			if name=="splash": wave=sin(sample*78.233+sin(sample*0.7)*12)*0.23*exp(-time*8)
			bytes.encode_s16(sample * 2, int(wave * 32767))
		var stream := AudioStreamWAV.new()
		stream.mix_rate = 22050
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.data = bytes
		cues[name] = stream

func _process(delta: float) -> void:
	bite_cooldown = maxf(0, bite_cooldown - delta)

func play(name: String) -> void:
	# Headless verification has no audio device or mixer frames to drain playback.
	if DisplayServer.get_name() == "headless": return
	if name == "eat":
		if bite_cooldown > 0: return
		bite_cooldown = 0.10
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = cues[name]
	voice.play()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
