//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// SPDX-FileCopyrightText: Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES.
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCUDACXX___TYPE_TRAITS_IS_UNION_H
#define _LIBCUDACXX___TYPE_TRAITS_IS_UNION_H

#include <cuda/std/detail/__config>

#if defined(_CCCL_IMPLICIT_SYSTEM_HEADER_GCC)
#  pragma GCC system_header
#elif defined(_CCCL_IMPLICIT_SYSTEM_HEADER_CLANG)
#  pragma clang system_header
#elif defined(_CCCL_IMPLICIT_SYSTEM_HEADER_MSVC)
#  pragma system_header
#endif // no system header

#include <cuda/std/__type_traits/integral_constant.h>
#include <cuda/std/__type_traits/remove_cv.h>

_LIBCUDACXX_BEGIN_NAMESPACE_STD

#if defined(_CCCL_BUILTIN_IS_UNION) && !defined(_LIBCUDACXX_USE_IS_UNION_FALLBACK)

template <class _Tp>
struct _CCCL_TYPE_VISIBILITY_DEFAULT is_union : public integral_constant<bool, _CCCL_BUILTIN_IS_UNION(_Tp)>
{};

template <class _Tp>
inline constexpr bool is_union_v = _CCCL_BUILTIN_IS_UNION(_Tp);

#else

template <class _Tp>
struct __cccl_union : public false_type
{};
template <class _Tp>
struct _CCCL_TYPE_VISIBILITY_DEFAULT is_union : public __cccl_union<remove_cv_t<_Tp>>
{};

template <class _Tp>
inline constexpr bool is_union_v = is_union<_Tp>::value;

#endif // defined(_CCCL_BUILTIN_IS_UNION) && !defined(_LIBCUDACXX_USE_IS_UNION_FALLBACK)

_LIBCUDACXX_END_NAMESPACE_STD

#endif // _LIBCUDACXX___TYPE_TRAITS_IS_UNION_H
