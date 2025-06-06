//===----------------------------------------------------------------------===//
//
// Part of CUDA Experimental in CUDA C++ Core Libraries,
// under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES.
//
//===----------------------------------------------------------------------===//

#ifndef _CUDAX__STREAM_INTERNAL_STREAMS
#define _CUDAX__STREAM_INTERNAL_STREAMS

#include <cuda/std/detail/__config>
#include <cuda_runtime_api.h>

#if defined(_CCCL_IMPLICIT_SYSTEM_HEADER_GCC)
#  pragma GCC system_header
#elif defined(_CCCL_IMPLICIT_SYSTEM_HEADER_CLANG)
#  pragma clang system_header
#elif defined(_CCCL_IMPLICIT_SYSTEM_HEADER_MSVC)
#  pragma system_header
#endif // no system header

#include <cuda/experimental/__stream/stream.cuh>

namespace cuda::experimental
{
//! @brief internal stream used for memory allocations, no real blocking work
//! should ever be pushed into it
inline ::cuda::stream_ref __cccl_allocation_stream()
{
  static ::cuda::experimental::stream __stream{};
  return __stream;
}

} // namespace cuda::experimental
#endif // _CUDAX__STREAM_INTERNAL_STREAMS
