# HealthOK Fact Report — On-Device LLM Stack for a Local-First Flutter Health App (2025)

> Search-infra note: both web_search attempts failed (authentication errors), so per protocol the report was finished from internal knowledge. **Zero URLs were seen; every claim is [U]** with stated confidence. Treat numbers as engineering estimates to re-benchmark on target devices.

## 1. Small LLM Candidates (2025)

| Model | Params | Approx RAM @4-bit* | Context | Commercial license | Notes |
|---|---|---|---|---|---|
| Qwen3 0.6B | 0.6B | ~0.45 GB | 32K | Apache 2.0 | Thinking/non-thinking modes |
| Qwen3 1.7B | 1.7B | ~1.05 GB | 32K | Apache 2.0 | Best instruction-following per byte in <2B class |
| Qwen3 4B | 4B | ~2.5 GB | 32K (131K YaRN) | Apache 2.0 | Near-frontier quality; heavy for budget phones |
| Llama 3.2 1B | 1.24B | ~0.75 GB | 128K claimed | Llama Community (≤700M MAU, AUP, branding) | Text-only; adequate, aging |
| Llama 3.2 3B | 3.21B | ~1.9 GB | 128K claimed | Llama Community | Better chat, RAM-heavy |
| Gemma 3 1B | 1B | ~0.75 GB | 32K | Gemma Terms | Text-only; strong for size |
| Gemma 3 4B | 4B | ~2.5 GB | 128K | Gemma Terms | Vision-capable; launch-day top chat Elo for its tier |
| Gemma 3n E2B | eff. 2B (raw ~5B) | ~2 GB resident w/ PLE offload | 128K | Gemma Terms | Phone-first; vision + **audio ASR**; .task/.litertlm |
| Gemma 3n E4B | eff. 4B (raw ~8B) | ~3 GB resident | 128K | Gemma Terms | Same, higher quality |
| Phi-4-mini | 3.8B | ~2.4 GB | 128K | MIT | Great reasoning/param; RAM overshoot |
| SmolLM2 135M–1.7B (+SmolLM3 3B) | — | 0.1–1 GB / ~1.8 GB | up to 64K | Apache 2.0 | Micro-experiments; 1.7B trails Qwen peers |

\* Q4_K_M-class weights only, small context; add 10–25% for KV cache + runtime overhead. [U high for params/licenses/context; U med for RAM figures]

Instruction-following reputation: Qwen3 ≥ Gemma 3 > Llama 3.2 at comparable size [U med]; caveat — Qwen3's default "thinking" mode emits long reasoning traces (latency/token cost); disable it for coach chat [U med]. Licenses: Apache 2.0 and MIT are frictionless for bundling; Llama Community imposes acceptable-use policy + attribution/branding terms; Gemma Terms permit commercial use with prohibited-use clauses and redistribution conditions [U high].

## 2. Inference Runtimes Reachable from Flutter

- **llama.cpp via dart:ffi** — the workhorse. Actual pub.dev wrappers: **`flutter_gemma`** (actively maintained 2024–2025; wraps Google AI Edge/MediaPipe rather than llama.cpp; loads `.task`/`.litertlm`; hundreds of likes — the de-facto choice) and **`llama_cpp_dart`** (dart:ffi bindings with prebuilt libs + example chat app; effectively single-maintainer, lags fast-churning upstream llama.cpp — pin a llama.cpp commit and vendor the build) [U high existence; U med maintenance detail]. Many teams instead compile llama.cpp themselves (Xcode for iOS, NDK for Android) behind a thin C API + FFI — full control, real maintenance burden [U med].
- **MediaPipe LLM Inference / Google AI Edge (LiteRT-LM)** — first-party Google stack; CPU + GPU delegates; Gemma-family models are first-class citizens shipped as `.task` (legacy) and `.litertlm` (2025) bundles; reachable from Flutter via `flutter_gemma` or platform channels [U high].
- **MLC LLM** — excellent perf (TVM-compiled Metal/Vulkan/OpenCL) but no turnkey Flutter plugin; embed via prebuilt static libs + FFI; project momentum visibly slowed through 2025 [U low-med].
- **ExecuTorch** — PyTorch's edge runtime with LLM examples (incl. Llama); production-grade infra, but DIY platform-channel integration from Flutter; no maintained wrapper [U med].
- **ONNX Runtime Mobile** — can run Phi-4-mini/SmolLM ONNX exports; decoder loop ergonomics weaker than llama.cpp; community `onnxruntime` Flutter plugin is sparse/stale [U low-med].
- **Apple Foundation Models (OS 26)** — Swift-only `FoundationModels` framework exposes Apple's ~3B on-device model (iPhone 15 Pro+/Apple-silicon iPads/Macs) with guided generation, tool calling, streaming, no per-token cost; usable from Flutter only via a Swift plugin shim; requires Apple Intelligence-enabled device/locale; governed by standard Apple developer terms [U med].
- **Android AICore / Gemini Nano** — third-party access is real but task-shaped: ML Kit GenAI APIs (summarize/proofread/rewrite/image-description) on Pixel/Galaxy-flagship-class devices via AICore; no general free-form prompting API; Flutter needs a platform channel; coverage too narrow to be primary [U med].

**Verdict:** two realistic Flutter paths today — llama.cpp/dart:ffi (portable, any model you can quantize) and MediaPipe/AI Edge via `flutter_gemma` (GPU-accelerated, vendor-maintained bundles). OS-level models are opportunistic enhancements, not foundations [U high].

## 3. Practical Performance (1–2B, Q4)

- Decode throughput, llama.cpp CPU: **iPhone A15**: 1B ≈ 15–25 tok/s; 3B ≈ 7–12 tok/s. **Snapdragon 7-series**: 1B ≈ 10–20 tok/s; 3B ≈ 5–10 tok/s. Flagship SD 8 Gen 3: ~20–30 tok/s on 3B Q4. Newer A17/A18 exceed 30 tok/s on 1B [U med].
- TTFT is prompt-bound: mobile pp512 ≈ 50–300 tok/s at this size → keep prompts <1K tokens or TTFT balloons to seconds; short-prompt TTFT ≈ 150–500 ms warm [U med].
- Memory: budget ~1 GB RSS for 1B Q4 (weights + KV + allocator), ~2.2–2.5 GB for 3B; mmap reduces resident pressure but not peak during decode [U med].
- Thermal/battery: sustained generation throttles within minutes (expect 20–40% tok/s drop); continuous decode drains several % battery per minute. Mitigate: cap outputs at ~150 tokens, debounce regenerations, prefer Wi-Fi-idle/charging windows for batch explanation jobs [U med].

## 4. Quantization Workflow

**GGUF (llama.cpp) path:**
1. Pull instruct safetensors from HF.
2. `python convert_hf_to_gguf.py <dir> --outfile m-f16.gguf --outtype f16`.
3. Optional: build an importance matrix (`llama-imatrix` on calibration text — health-chat style corpus) then `./llama-quantize m-f16.gguf m-q4km.gguf Q4_K_M`; Q8_0 for near-lossless A/B baselines. Q4_K_M typically costs <1% perplexity at these scales [U med].
4. Smoke-test with `llama-cli` (format adherence, refusal behavior), then ship per-ABI builds (Android arm64-v8a primary; iOS universal arm64). Vendor the exact llama.cpp commit used to produce bindings [U high for tool names; U med for details].

**MediaPipe/AI-Edge path:** use Google's AI Edge converter (CLI/Colab) to go HF checkpoint → multi-file TFLite → `.task` bundle (tokenizer bundled inside); the 2025 successor emits `.litertlm` for LiteRT-LM. Architecture support is narrowest outside the Gemma family — Gemma 3/3n ship as ready-made official bundles, which sidesteps both conversion risk and license ambiguity [U med].

## 5. On-Device Classical ML for Health

- **Activity recognition**: LiteRT (ex-TFLite) IMU-HAR models (CNN/LSTM over accelerometer windows) are <100 KB, sub-millisecond — trivially cheap next to any LLM [U high].
- **Pose / rep counting**: MediaPipe BlazePose (33 kp; lite/full/heavy) and MoveNet Lightning/Thunder (17 kp) run as LiteRT; MoveNet Lightning sustains ~real-time FPS on mid-range Android. Rep counting should be a deterministic state machine over joint-angle series (hip/knee thresholds) — no LLM in the loop [U high for model availability; U med for FPS].
- **Food image classification**: Food-101-trained MobileNetV3/EfficientNet-Lite int8 models are <10 MB, top-1 ~75–90% on benchmark distribution but noticeably worse on real meal photos; Nutrition5k (Google) enables portion/calorie research but no turnkey production model. Ship classifier + confirmation UI + manual portion entry; never auto-log calories silently [U med].
- **Tiny ASR**: whisper.cpp `tiny` (39M) achieves near-real-time transcription on recent phones (faster via WhisperKit/Core ML on iOS); Moonshine tiny (~27M, Apache) beats whisper tiny on short-clip latency; Qwen-audio-class models are impractical on phones. Short voice-log dictation is feasible; avoid always-on listening (battery) [U med].

## RECOMMENDATION — HealthOK MVP

**Primary: Qwen3-1.7B Instruct, Q4_K_M GGUF (~1.05 GB), served by llama.cpp through dart:ffi (pin + vendor a specific upstream commit; start from `llama_cpp_dart`, plan to own the bindings).**
Reasoning: (a) Apache 2.0 removes attribution/branding/legal review friction for consumer bundling; (b) best instruction-following-per-byte in its class → tighter coach replies with fewer tokens, which directly buys thermal and battery headroom; (c) fits the Snapdragon-7/iPhone-A15 RAM-and-speed envelope where 3–4B models stutter; (d) the deterministic scoring engines already own the math, so the LLM's job is bounded explanation/chat — cap context at 2–4K and outputs at ~150 tokens.

**Secondary track: Gemma 3n E2B via MediaPipe/AI Edge (`flutter_gemma`)** when MVP grows into photo food logging and voice input — its built-in vision+ASR and vendor-maintained GPU-accelerated bundles beat hand-assembling three separate pipelines. Keep the runtime abstraction (a thin `InferenceEngine` interface) so either backend can serve the same coach prompts.

**Avoid for MVP:** Phi-4-mini (RAM), MLC/ExecuTorch/ONNX (integration cost without a Flutter story), Apple Foundation Models / Gemini Nano as primary (device fragmentation; revisit later as opportunistic accelerators via platform channels). Re-benchmark tok/s, TTFT, and thermals on 2–3 real devices before freezing specs.

## Sources

None — both search attempts failed with authentication errors; no URLs were seen or verified. This report contains no [V]-labeled claims.
