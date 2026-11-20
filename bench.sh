#!/bin/bash
# Runs inside the codespace; writes results and pushes them back to the repo.
cd /workspaces/compute-test || exit 1
OUT=results/bench.txt
mkdir -p results
{
  echo "=== CODESPACE BENCH $(date -u +%FT%TZ) ==="
  echo "nproc: $(nproc)"
  grep -m1 "model name" /proc/cpuinfo || true
  free -h | head -2
  df -h / /workspaces 2>/dev/null | tail -2
  echo "--- ffmpeg ---"
  if ! command -v ffmpeg >/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq ffmpeg >/dev/null 2>&1
  fi
  ffmpeg -version 2>/dev/null | head -1 || echo "ffmpeg install FAILED"
} > "$OUT" 2>&1

if command -v ffmpeg >/dev/null; then
  /usr/bin/time -f "ENCODE_WALL=%e USER=%U SYS=%S" \
    ffmpeg -y -v error -f lavfi -i testsrc2=duration=30:size=1920x1080:rate=30 \
    -c:v libx264 -preset medium -crf 23 /tmp/cs-bench.mp4 2>> "$OUT"
  ls -la /tmp/cs-bench.mp4 >> "$OUT"
fi

{
  echo "--- faster-whisper smoke test ---"
  pip install -q faster-whisper 2>&1 | tail -1
  python3 - <<'PYEOF'
import time, urllib.request, os
try:
    url = "https://github.com/openai/whisper/raw/main/tests/jfk.flac"
    urllib.request.urlretrieve(url, "/tmp/jfk.flac")
    from faster_whisper import WhisperModel
    t0=time.time(); m = WhisperModel("tiny", device="cpu", compute_type="int8"); t1=time.time()
    segs, info = m.transcribe("/tmp/jfk.flac")
    txt = " ".join(s.text for s in segs); t2=time.time()
    print(f"WHISPER model_load={t1-t0:.1f}s transcribe_11s_audio={t2-t1:.1f}s text={txt[:80]!r}")
except Exception as e:
    print("WHISPER FAILED:", repr(e)[:300])
PYEOF
  echo "=== DONE ==="
} >> "$OUT" 2>&1

git add results/bench.txt >/dev/null 2>&1
git -c user.email=bench@codespace -c user.name=bench commit -m "codespace bench results" >/dev/null 2>&1
git push >/dev/null 2>&1 && echo "pushed" >> "$OUT" || echo "push FAILED" >> "$OUT"
