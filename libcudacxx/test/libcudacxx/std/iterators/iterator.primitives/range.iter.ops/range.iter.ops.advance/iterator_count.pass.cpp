//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// SPDX-FileCopyrightText: Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES.
//
//===----------------------------------------------------------------------===//

// UNSUPPORTED: msvc-19.16

// ranges::advance(it, n)

#include <cuda/std/cassert>
#include <cuda/std/iterator>

#include "test_iterators.h"
#include "test_macros.h"

struct Abs
{
  template <class T>
  __host__ __device__ constexpr T operator()(T x) const noexcept
  {
    return x < 0 ? -x : x;
  };
};

template <bool Count, typename It>
__host__ __device__ constexpr void check(int* first, cuda::std::iter_difference_t<It> n, int* expected)
{
  using Difference   = cuda::std::iter_difference_t<It>;
  Difference const M = (expected - first); // expected travel distance (which may be negative)
  Abs abs{};
  unused(abs);
  unused(M);

  {
    It it(first);
    cuda::std::ranges::advance(it, n);
    assert(base(it) == expected);
    static_assert(cuda::std::is_same_v<decltype(cuda::std::ranges::advance(it, n)), void>);
  }

  // Count operations
  if constexpr (Count)
  {
    auto it = stride_counting_iterator(It(first));
    cuda::std::ranges::advance(it, n);
    if constexpr (cuda::std::random_access_iterator<It>)
    {
      assert(it.stride_count() <= 1);
    }
    else
    {
      assert(it.stride_count() == abs(M));
    }
  }
}

__host__ __device__ constexpr bool test()
{
  int range[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

  // Check advancing forward
  for (int n = 0; n != 10; ++n)
  {
    check<false, cpp17_input_iterator<int*>>(range, n, range + n);
    check<false, cpp20_input_iterator<int*>>(range, n, range + n);
    check<true, forward_iterator<int*>>(range, n, range + n);
    check<true, bidirectional_iterator<int*>>(range, n, range + n);
    check<true, random_access_iterator<int*>>(range, n, range + n);
    check<true, contiguous_iterator<int*>>(range, n, range + n);
    check<true, int*>(range, n, range + n);
    check<true, cpp17_output_iterator<int*>>(range, n, range + n);
  }

  // Check advancing backward
  for (int n = 0; n != 10; ++n)
  {
    check<true, bidirectional_iterator<int*>>(range + 9, -n, range + 9 - n);
    check<true, random_access_iterator<int*>>(range + 9, -n, range + 9 - n);
    check<true, contiguous_iterator<int*>>(range + 9, -n, range + 9 - n);
    check<true, int*>(range + 9, -n, range + 9 - n);
  }

  return true;
}

int main(int, char**)
{
  assert(test());
  static_assert(test());
  return 0;
}
