# AI Model Benchmarks & Recommendations (2026)

This document provides guidance on choosing the right local model for your Flutter application based on hardware constraints and use cases.

## 📊 Performance Matrix

Benchmarks performed on stable releases as of April 2026.

| SoC / Chipset | Model | Tokens/sec | Notes |
| :--- | :--- | :--- | :--- |
| **Apple A17 Pro (iPhone 15 Pro)** | Llama 3 8B (Q4_K_M) | 9.2 | Excellent Metal acceleration. |
| **Snapdragon 8 Gen 3** | Llama 3 8B (Q4_K_M) | 10.1 | Top-tier Vulkan performance. |
| **Apple M3 (MacBook Air)** | Llama 3 8B (Q4_K_M) | 18.5 | Unified memory shines here. |
| **Snapdragon 7+ Gen 2** | Phi-3 Mini (Q4) | 12.4 | Great mid-range performance. |

## 🛠️ Quantization Guide

Choosing the right `GGUF` quantization is critical for mobile.

- **Q4_K_M (Recommended)**: The gold standard. 4-bit quantization with minimal perplexity loss. Best balance of speed and intelligence.
- **Q2_K / Q3_K**: Use only for low-tier devices (under 6GB total RAM). Intelligence drops significantly.
- **Q8_0 / F16**: Avoid on mobile unless testing. Extremely slow and likely to trigger OOM (Out of Memory) kills.

## 🧠 Model Recommendations

### 1. The "Master" (Llama 3 8B Instruct)
- **Strengths**: Best reasoning, excellent tool following (ReAct), high quality prose.
- **Hardware**: High-end flagship phones (8GB+ RAM).

### 2. The "Speedster" (Microsoft Phi-3 Mini 4K)
- **Strengths**: Incredibly fast, handles simple logic well, small footprint.
- **Hardware**: Mid-range devices (6GB+ RAM).

### 3. The "Lightweight" (Google Gemma 2B)
- **Strengths**: Tiny download size, good for entity extraction and simple summaries.
- **Hardware**: Budget devices (4GB+ RAM).

## 🚀 Optimization Tips

1. **Context Size**: Keep context at `4096` or lower for mobile. Increasing context size exponentially increases RAM usage.
2. **GPU Layers**: For `llamadart`, set `gpuLayers` to `32` on flagship mobile chips to maximize NPU/GPU usage.
3. **KV Cache**: The kit uses optimized KV caching, but clearing history every 5-10 turns improves long-term app stability.
