//
//  stream.h
//  
//
//  Created by Parav Nagarsheth on 12/6/23.
//

#ifndef STREAM_H
#define STREAM_H

#include <stdio.h>

#include "whisper.h"

//#include <cassert>
//#include <cstdio>
#include <string>
#include <thread>
#include <vector>
//#include <fstream>

#endif /* stream_h */


#ifdef __cplusplus
extern "C" {
#endif

const char * stream_get_text(struct whisper_context * whisper_ctx,
                             struct stream_context * stream_ctx,
                             struct stream_full_params stream_params,
                             struct whisper_full_params whisper_params,
                             const float * samples,
                             int n_samples);

struct stream_full_params stream_full_default_params();

struct stream_context * whisper_init_stream();

#ifdef __cplusplus
}
#endif
