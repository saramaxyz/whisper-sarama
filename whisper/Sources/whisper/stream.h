//
//  stream.hpp
//  
//
//  Created by Parav Nagarsheth on 12/6/23.
//

#ifndef STREAM_H
#define STREAM_H

#include <stdio.h>

#include "common-sdl.h"
#include "common.h"
#include "whisper.h"

#include <cassert>
#include <cstdio>
#include <string>
#include <thread>
#include <vector>
#include <fstream>

#endif /* stream_hpp */

std::string to_timestamp(int64_t t) {
    int64_t sec = t/100;
    int64_t msec = t - sec*100;
    int64_t min = sec/60;
    sec = sec - min*60;

    char buf[32];
    snprintf(buf, sizeof(buf), "%02d:%02d.%03d", (int) min, (int) sec, (int) msec);

    return std::string(buf);
}

// command-line parameters
struct whisper_params {
    int32_t n_threads  = std::min(4, (int32_t) std::thread::hardware_concurrency());
    int32_t step_ms    = 3000;
    int32_t length_ms  = 10000;
    int32_t keep_ms    = 200;
    int32_t capture_id = -1;
    int32_t max_tokens = 32;
    int32_t audio_ctx  = 0;

    float vad_thold    = 0.6f;
    float freq_thold   = 100.0f;

    bool speed_up      = false;
    bool translate     = false;
    bool no_fallback   = false;
    bool print_special = false;
    bool no_context    = true;
    bool no_timestamps = false;
    bool tinydiarize   = false;
    bool save_audio    = false; // save audio to wav file
    bool use_gpu       = true;

    std::string language  = "en";
    std::string model     = "models/ggml-base.en.bin";
    std::string fname_out;
};


