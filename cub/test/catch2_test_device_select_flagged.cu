/******************************************************************************
 * Copyright (c) 2023, NVIDIA CORPORATION.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the NVIDIA CORPORATION nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL NVIDIA CORPORATION BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 ******************************************************************************/

#include <cub/device/device_select.cuh>

#include <thrust/count.h>
#include <thrust/partition.h>
#include <thrust/reverse.h>

#include <algorithm>

#include "catch2_test_launch_helper.h"
#include "catch2_test_helper.h"

template<class T, class FlagT>
static c2h::host_vector<T> get_reference(const c2h::device_vector<T>& in, const c2h::device_vector<FlagT>& flags) {
  struct selector {
    const T* ref_begin      = nullptr;
    const FlagT* flag_begin = nullptr;

    constexpr selector(const T* ref, const FlagT* flag) noexcept : ref_begin(ref), flag_begin(flag) {}

    bool operator()(const T& val) const {
      const auto pos = &val - ref_begin;
      return static_cast<bool>(flag_begin[pos]);
    }
  };

  c2h::host_vector<T> reference   = in;
  c2h::host_vector<FlagT> h_flags = flags;

  const selector pred{thrust::raw_pointer_cast(reference.data()),
                      thrust::raw_pointer_cast(h_flags.data())};
  const auto boundary = std::stable_partition(reference.begin(), reference.end(), pred);
  reference.erase(boundary, reference.end());
  return reference;
}

DECLARE_LAUNCH_WRAPPER(cub::DeviceSelect::Flagged, select_flagged);

// %PARAM% TEST_LAUNCH lid 0

using all_types = c2h::type_list<std::uint8_t,
                                 std::uint16_t,
                                 std::uint32_t,
                                 std::uint64_t,
                                 ulonglong2,
                                 ulonglong4,
                                 int,
                                 long2,
                                 c2h::custom_type_t<c2h::equal_comparable_t>>;

using types = c2h::type_list<std::uint8_t,
                             std::uint32_t,
                             ulonglong4,
                             c2h::custom_type_t<c2h::equal_comparable_t>>;

CUB_TEST("DeviceSelect::Flagged can run with empty input", "[device][select_flagged]", types)
{
  using type = typename c2h::get<0, TestType>;

  constexpr int num_items = 0;
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(num_items);
  c2h::device_vector<int> flags(num_items);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.begin(),
                 flags.begin(),
                 out.begin(),
                 d_num_selected_out,
                 num_items);

  REQUIRE(num_selected_out[0] == 0);
}

CUB_TEST("DeviceSelect::Flagged handles all matched", "[device][select_flagged]", types)
{
  using type = typename c2h::get<0, TestType>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items, 1);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.begin(),
                 flags.begin(),
                 out.begin(),
                 d_num_selected_out,
                 num_items);

  REQUIRE(num_selected_out[0] == num_items);
  REQUIRE(out == in);
}

CUB_TEST("DeviceSelect::Flagged handles no matched", "[device][select_flagged]", types)
{
  using type = typename c2h::get<0, TestType>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(0);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items, 0);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.begin(),
                 flags.begin(),
                 out.begin(),
                 d_num_selected_out,
                 num_items);

  REQUIRE(num_selected_out[0] == 0);
}

CUB_TEST("DeviceSelect::Flagged does not change input", "[device][select_flagged]", types)
{
  using type = typename c2h::get<0, TestType>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items);
  c2h::gen(CUB_SEED(1), flags, 0, 1);
  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  // copy input first
  c2h::device_vector<type> reference = in;

  select_flagged(in.begin(),
                 flags.begin(),
                 out.begin(),
                 d_num_selected_out,
                 num_items);

  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == in);
}

CUB_TEST("DeviceSelect::Flagged is stable", "[device][select_flagged]",
         c2h::type_list<c2h::custom_type_t<c2h::equal_comparable_t>>)
{
  using type = typename c2h::get<0, TestType>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items);
  c2h::gen(CUB_SEED(1), flags, 0, 1);
  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));
  const c2h::host_vector<type> reference = get_reference(in, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.begin(),
                 flags.begin(),
                 out.begin(),
                 d_num_selected_out,
                 num_items);

  out.resize(num_selected_out[0]);
  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == out);
}

CUB_TEST("DeviceSelect::Flagged works with iterators", "[device][select_flagged]", all_types)
{
  using type = typename c2h::get<0, TestType>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items);
  c2h::gen(CUB_SEED(1), flags, 0, 1);
  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));
  const c2h::host_vector<type> reference = get_reference(in, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.data(),
                 flags.begin(),
                 out.data(),
                 d_num_selected_out,
                 num_items);

  out.resize(num_selected_out[0]);
  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == out);
}

CUB_TEST("DeviceSelect::Flagged works with pointers", "[device][select_flagged]", types)
{
  using type = typename c2h::get<0, TestType>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items);
  c2h::gen(CUB_SEED(1), flags, 0, 1);

  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));
  const c2h::host_vector<type> reference = get_reference(in, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(thrust::raw_pointer_cast(in.data()),
                 thrust::raw_pointer_cast(flags.data()),
                 thrust::raw_pointer_cast(out.data()),
                 d_num_selected_out,
                 num_items);

  out.resize(num_selected_out[0]);
  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == out);
}

struct convertible_to_bool {
  int val_;

  convertible_to_bool() = default;
  __host__ __device__ convertible_to_bool(const int val) noexcept : val_(val) {}

  __host__ __device__ operator bool() const noexcept { return static_cast<bool>(val_); }
  __host__ __device__ friend bool operator==(const convertible_to_bool& lhs, const int& rhs) noexcept { return lhs.val_ == rhs; }
  __host__ __device__ friend bool operator==(const int& lhs, const convertible_to_bool& rhs) noexcept { return lhs == rhs.val_; }
};

CUB_TEST("DeviceSelect::Flagged works with flags that are convertible to bool", "[device][select_flagged]")
{
  using type = c2h::custom_type_t<c2h::equal_comparable_t>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<type> out(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> iflags(num_items);
  c2h::gen(CUB_SEED(1), iflags, 0, 1);

  c2h::device_vector<convertible_to_bool> flags = iflags;
  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));
  const c2h::host_vector<type> reference = get_reference(in, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.begin(),
                 flags.begin(),
                 out.begin(),
                 d_num_selected_out,
                 num_items);

  out.resize(num_selected_out[0]);
  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == out);
}

CUB_TEST("DeviceSelect::Flagged works with flags that alias input", "[device][select_flagged]")
{
  using type = int;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> out(num_items);

  c2h::device_vector<int> flags(num_items);
  c2h::gen(CUB_SEED(1), flags, 0, 1);
  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));
  const c2h::host_vector<type> reference = get_reference(flags, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(flags.begin(),
                 flags.begin(),
                 out.begin(),
                 d_num_selected_out,
                 num_items);

  out.resize(num_selected_out[0]);
  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == out);
}

CUB_TEST("DeviceSelect::Flagged works in place", "[device][select_if]", types)
{
  using type = typename c2h::get<0, TestType>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items);
  c2h::gen(CUB_SEED(1), flags, 0, 1);

  const c2h::host_vector<type> reference = get_reference(in, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.begin(),
                 flags.begin(),
                 d_num_selected_out,
                 num_items);

  in.resize(num_selected_out[0]);
  REQUIRE(reference == in);
}

CUB_TEST("DeviceSelect::Flagged works in place with flags that alias input", "[device][select_flagged]")
{
  using type = int;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<int> flags(num_items);

  c2h::gen(CUB_SEED(1), flags, 0, 1);

  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));
  const c2h::host_vector<type> reference = get_reference(flags, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(flags.begin(),
                 flags.begin(),
                 d_num_selected_out,
                 num_items);

  flags.resize(num_selected_out[0]);
  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == flags);
}

template<class T>
struct convertible_from_T {
  T val_;

  convertible_from_T() = default;
  __host__ __device__ convertible_from_T(const T& val) noexcept : val_(val) {}
  __host__ __device__ convertible_from_T& operator=(const T& val) noexcept {
    val_ = val;
  }
  // Converting back to T helps satisfy all the machinery that T supports
  __host__ __device__ operator T() const noexcept { return val_; }
};

CUB_TEST("DeviceSelect::Flagged works with a different output type", "[device][select_flagged]")
{
  using type = c2h::custom_type_t<c2h::equal_comparable_t>;

  const int num_items = GENERATE_COPY(take(2, random(1, 1000000)));
  c2h::device_vector<type> in(num_items);
  c2h::device_vector<convertible_from_T<type>> out(num_items);
  c2h::gen(CUB_SEED(2), in);

  c2h::device_vector<int> flags(num_items);
  c2h::gen(CUB_SEED(1), flags, 0, 1);

  const int num_selected = static_cast<int>(thrust::count(c2h::device_policy, flags.begin(), flags.end(), 1));
  const c2h::host_vector<type> reference = get_reference(in, flags);

  // Needs to be device accessible
  c2h::device_vector<int> num_selected_out(1, 0);
  int *d_num_selected_out = thrust::raw_pointer_cast(num_selected_out.data());

  select_flagged(in.data(),
                 flags.begin(),
                 out.data(),
                 d_num_selected_out,
                 num_items);

  out.resize(num_selected_out[0]);
  REQUIRE(num_selected == num_selected_out[0]);
  REQUIRE(reference == out);
}
