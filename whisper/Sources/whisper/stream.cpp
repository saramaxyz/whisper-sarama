//
//  stream.cpp
//  
//
//  Created by Parav Nagarsheth on 12/6/23.
//

#include "stream.h"
#include "whisper.h"


struct stream_context {
  std::vector<float> pcmf32;
  std::vector<float> pcmf32_old;
  std::vector<float> pcmf32_new;
  std::vector<whisper_token> prompt_tokens;
  std::vector<std::string> transcript;
  int32_t n_iter = 0;

  stream_context()
    : pcmf32((1e-3*30000.0)*WHISPER_SAMPLE_RATE, 0.0f),
      pcmf32_new((1e-3*30000.0)*WHISPER_SAMPLE_RATE, 0.0f)
  {}
};

// command-line parameters

struct stream_context * whisper_init_stream() {
    stream_context * ctx = new stream_context;
    if (!ctx) {
        return nullptr;
    }
    return ctx;
}

struct stream_full_params stream_full_default_params() {
    struct stream_full_params params = {
        /*int32_t n_threads  =*/ std::min(4, (int32_t) std::thread::hardware_concurrency()),
        /*int32_t step_ms    =*/ 3000,
        /*int32_t length_ms  =*/ 10000,
        /*int32_t keep_ms    =*/ 200,
        /*int32_t capture_id =*/ -1,
        /*int32_t max_tokens =*/ 32,
        /*int32_t audio_ctx  =*/ 0,

        /*float vad_thold    =*/ 0.6f,
        /*float freq_thold   =*/ 100.0f,

        /*bool speed_up      =*/ false,
        /*bool translate     =*/ false,
        /*bool no_fallback   =*/ false,
        /*bool print_special =*/ false,
        /*bool no_context    =*/ true,
        /*bool no_timestamps =*/ false,
        /*bool tinydiarize   =*/ false,
        /*bool save_audio    =*/ false, // save audio to wav file
        /*bool use_gpu       =*/ true,
    };

  return params;
}

const char * stream_get_text(struct whisper_context * whisper_ctx,
                             struct stream_context * stream_ctx,
                             struct stream_full_params stream_params,
                             struct whisper_full_params whisper_params,
                             const float * samples,
                             int n_samples) {
  
  stream_ctx->pcmf32_new.assign(samples, samples+n_samples);
  const int n_samples_new = stream_ctx->pcmf32_new.size();
  
  const int n_samples_step = (1e-3*stream_params.step_ms  )*WHISPER_SAMPLE_RATE;
  const int n_samples_len  = (1e-3*stream_params.length_ms)*WHISPER_SAMPLE_RATE;
  const int n_samples_keep = (1e-3*stream_params.keep_ms  )*WHISPER_SAMPLE_RATE;
  
  const int n_new_line = std::max(1, stream_params.length_ms / stream_params.step_ms - 1); // number of steps to print new line
  
  // take up to params.length_ms audio from previous iteration
  const int n_samples_take = std::min((int) stream_ctx->pcmf32_old.size(), std::max(0, n_samples_keep + n_samples_len - n_samples_new));
  
  stream_ctx->pcmf32.resize(n_samples_new + n_samples_take);
  
  for (int i = 0; i < n_samples_take; i++) {
    stream_ctx->pcmf32[i] = stream_ctx->pcmf32_old[stream_ctx->pcmf32_old.size() - n_samples_take + i];
  }
  
  memcpy(stream_ctx->pcmf32.data() + n_samples_take, stream_ctx->pcmf32_new.data(), n_samples_new*sizeof(float));
  
  stream_ctx->pcmf32_old = stream_ctx->pcmf32;
  
//  if (whisper_full(whisper_ctx, whisper_params, stream_ctx->pcmf32.data(), stream_ctx->pcmf32.size()) != 0) {
//    fprintf(stderr, "%s: failed to process audio\n", argv[0]);
//    return 6;
//  }
  if (whisper_full(whisper_ctx, whisper_params, stream_ctx->pcmf32.data(), stream_ctx->pcmf32.size()) != 0) {
      return nullptr;
  }
  // Update transcript
  std::string transcript;
  const int n_segments = whisper_full_n_segments(whisper_ctx);
  for (int i = 0; i < n_segments; ++i) {
    const char* text = whisper_full_get_segment_text(whisper_ctx, i);
    transcript += std::string(text);
  }
//  WHISPER_LOG_INFO("%s: %s", __func__, transcript.c_str());
  if (!stream_ctx->transcript.empty()) {
    stream_ctx->transcript.back() = transcript;
  } else {
    stream_ctx->transcript.push_back(transcript);
  }

  stream_ctx->n_iter++;
  if (stream_ctx->n_iter % n_new_line == 0) {
    // Handle word boundary issues
    stream_ctx->transcript.push_back("");
    stream_ctx->pcmf32_old = std::vector<float>(stream_ctx->pcmf32.end() - n_samples_keep, stream_ctx->pcmf32.end());
    if (!stream_params.no_context) {
      stream_ctx->prompt_tokens.clear();
      
      const int n_segments = whisper_full_n_segments(whisper_ctx);
      for (int i = 0; i < n_segments; ++i) {
        const int token_count = whisper_full_n_tokens(whisper_ctx, i);
        for (int j = 0; j < token_count; ++j) {
          stream_ctx->prompt_tokens.push_back(whisper_full_get_token_id(whisper_ctx, i, j));
        }
      }
    }
  }
  std::string combined;
  for (const auto& str : stream_ctx->transcript) {
      combined += str;
  }
  char* cstr = new char[combined.length() + 1];
  std::strcpy(cstr, combined.c_str());
  return cstr;
}

//GGML_ATTRIBUTE_FORMAT(2, 3)
//static void whisper_log_internal(ggml_log_level level, const char * format, ...) {
//    va_list args;
//    va_start(args, format);
//    char buffer[1024];
//    int len = vsnprintf(buffer, 1024, format, args);
//    if (len < 1024) {
//        g_state.log_callback(level, buffer, g_state.log_callback_user_data);
//    } else {
//        char* buffer2 = new char[len+1];
//        vsnprintf(buffer2, len+1, format, args);
//        buffer2[len] = 0;
//        g_state.log_callback(level, buffer2, g_state.log_callback_user_data);
//        delete[] buffer2;
//    }
//    va_end(args);
//}

