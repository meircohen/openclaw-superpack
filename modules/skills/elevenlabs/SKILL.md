---
name: elevenlabs
description: Voice cloning and text-to-speech via ElevenLabs API. Use when user wants to clone a voice from audio samples, generate speech/audio from text, list available voices, or create voice content. Supports instant voice cloning from 1+ audio files and high-quality multilingual TTS.
read_when:
  - User asks to generate speech or voice audio
  - User mentions ElevenLabs or text-to-speech generation
---

# ElevenLabs Voice Cloning & TTS

## Setup
- API key stored in `~/.openclaw/.elevenlabs-env` as `ELEVENLABS_API_KEY`
- Script: `scripts/elevenlabs.sh` (relative to this skill directory)

## Commands

### List voices
```bash
bash scripts/elevenlabs.sh list-voices
```

### Clone a voice from audio
```bash
bash scripts/elevenlabs.sh clone-voice "Voice Name" /path/to/sample1.mp3 [/path/to/sample2.mp3]
```
- Accepts 1-25 audio files (mp3, wav, m4a)
- Best results: clean speech, no background noise, 1-3 minutes total
- Returns the new voice_id

### Generate speech (TTS)
```bash
bash scripts/elevenlabs.sh tts <voice_id_or_name> "Text to speak" /path/to/output.mp3
```
- Can use voice_id or voice name (case-insensitive lookup)
- Default model: `eleven_multilingual_v2`
- Override model: `--model eleven_turbo_v2_5`

### Delete a cloned voice
```bash
bash scripts/elevenlabs.sh delete-voice <voice_id>
```

### Get voice details
```bash
bash scripts/elevenlabs.sh voice-info <voice_id>
```

## Voice Cloning Workflow
1. Get audio samples of the target voice (record or use existing)
2. Clone: `bash scripts/elevenlabs.sh clone-voice "Name" sample.mp3`
3. Test: `bash scripts/elevenlabs.sh tts <returned_id> "Hello, this is a test" test.mp3`
4. Use the voice_id for all future TTS calls

## Audio Quality Tips
- Clean speech, minimal background noise
- Natural conversational tone (not reading robotically)
- 30 seconds minimum, 1-3 minutes ideal per sample
- Multiple diverse samples improve quality
- WAV or high-bitrate MP3 preferred
