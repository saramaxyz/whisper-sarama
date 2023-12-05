# whisper-sarama

Demo app to demonstrate whisper running on iOS with CoreML encoder and GGML/Metal based decoder. The decoder uses Metal kernels to allow KV cache optimizations.

1. Open the project in Xcode
2. Run the demo on an iOS device
3. Use the record button to record audio and transcribe it

## Speed
Transcription speeds dramatically improve after 2-3 warmup runs.
