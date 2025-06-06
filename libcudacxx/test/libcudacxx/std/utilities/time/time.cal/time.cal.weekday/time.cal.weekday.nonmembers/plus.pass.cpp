//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// <chrono>
// class weekday;

// constexpr weekday operator+(const days& x, const weekday& y) noexcept;
//   Returns: weekday(int{x} + y.count()).
//
// constexpr weekday operator+(const weekday& x, const days& y) noexcept;
//   Returns:
//      weekday{modulo(static_cast<long long>(unsigned{x}) + y.count(), 7)}
//   where modulo(n, 7) computes the remainder of n divided by 7 using Euclidean division.
//   [Note: Given a divisor of 12, Euclidean division truncates towards negative infinity
//   and always produces a remainder in the range of [0, 6].
//   Assuming no overflow in the signed summation, this operation results in a weekday
//   holding a value in the range [0, 6] even if !x.ok(). —end note]
//   [Example: Monday + days{6} == Sunday. —end example]

#include <cuda/std/cassert>
#include <cuda/std/chrono>
#include <cuda/std/type_traits>

#include "../../euclidian.h"
#include "test_macros.h"

template <typename M, typename Ms>
__host__ __device__ constexpr bool testConstexpr()
{
  M m{1};
  Ms offset{4};
  if (m + offset != M{5})
  {
    return false;
  }
  if (offset + m != M{5})
  {
    return false;
  }
  //  Check the example
  if (M{1} + Ms{6} != M{0})
  {
    return false;
  }
  return true;
}

int main(int, char**)
{
  using weekday = cuda::std::chrono::weekday;
  using days    = cuda::std::chrono::days;

  static_assert(noexcept(cuda::std::declval<weekday>() + cuda::std::declval<days>()));
  static_assert(cuda::std::is_same_v<weekday, decltype(cuda::std::declval<weekday>() + cuda::std::declval<days>())>);

  static_assert(noexcept(cuda::std::declval<days>() + cuda::std::declval<weekday>()));
  static_assert(cuda::std::is_same_v<weekday, decltype(cuda::std::declval<days>() + cuda::std::declval<weekday>())>);

  static_assert(testConstexpr<weekday, days>(), "");

  for (unsigned i = 0; i <= 6; ++i)
  {
    for (unsigned j = 0; j <= 6; ++j)
    {
      weekday wd1 = weekday{i} + days{j};
      weekday wd2 = days{j} + weekday{i};
      assert(wd1 == wd2);
      assert((wd1.c_encoding() == euclidian_addition<unsigned, 0, 6>(i, j)));
      assert((wd2.c_encoding() == euclidian_addition<unsigned, 0, 6>(i, j)));
    }
  }

  return 0;
}
