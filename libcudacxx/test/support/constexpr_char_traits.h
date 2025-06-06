// -*- C++ -*-
//===-------------------- constexpr_char_traits ---------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _CONSTEXPR_CHAR_TRAITS
#define _CONSTEXPR_CHAR_TRAITS

#include <cuda/std/cassert>

#include <string>

#include "test_macros.h"

template <class _CharT>
struct constexpr_char_traits
{
  typedef _CharT char_type;
  typedef int int_type;
  typedef std::streamoff off_type;
  typedef std::streampos pos_type;
  typedef std::mbstate_t state_type;

  static constexpr void assign(char_type& __c1, const char_type& __c2) noexcept
  {
    __c1 = __c2;
  }

  static constexpr bool eq(char_type __c1, char_type __c2) noexcept
  {
    return __c1 == __c2;
  }

  static constexpr bool lt(char_type __c1, char_type __c2) noexcept
  {
    return __c1 < __c2;
  }

  static constexpr int compare(const char_type* __s1, const char_type* __s2, size_t __n);
  static constexpr size_t length(const char_type* __s);
  static constexpr const char_type* find(const char_type* __s, size_t __n, const char_type& __a);
  static constexpr char_type* move(char_type* __s1, const char_type* __s2, size_t __n);
  static constexpr char_type* copy(char_type* __s1, const char_type* __s2, size_t __n);
  static constexpr char_type* assign(char_type* __s, size_t __n, char_type __a);

  static constexpr int_type not_eof(int_type __c) noexcept
  {
    return eq_int_type(__c, eof()) ? ~eof() : __c;
  }

  static constexpr char_type to_char_type(int_type __c) noexcept
  {
    return char_type(__c);
  }

  static constexpr int_type to_int_type(char_type __c) noexcept
  {
    return int_type(__c);
  }

  static constexpr bool eq_int_type(int_type __c1, int_type __c2) noexcept
  {
    return __c1 == __c2;
  }

  static constexpr int_type eof() noexcept
  {
    return int_type(EOF);
  }
};

template <class _CharT>
constexpr int constexpr_char_traits<_CharT>::compare(const char_type* __s1, const char_type* __s2, size_t __n)
{
  for (; __n; --__n, ++__s1, ++__s2)
  {
    if (lt(*__s1, *__s2))
    {
      return -1;
    }
    if (lt(*__s2, *__s1))
    {
      return 1;
    }
  }
  return 0;
}

template <class _CharT>
constexpr size_t constexpr_char_traits<_CharT>::length(const char_type* __s)
{
  size_t __len = 0;
  for (; !eq(*__s, char_type(0)); ++__s)
  {
    ++__len;
  }
  return __len;
}

template <class _CharT>
constexpr const _CharT* constexpr_char_traits<_CharT>::find(const char_type* __s, size_t __n, const char_type& __a)
{
  for (; __n; --__n)
  {
    if (eq(*__s, __a))
    {
      return __s;
    }
    ++__s;
  }
  return 0;
}

template <class _CharT>
constexpr _CharT* constexpr_char_traits<_CharT>::move(char_type* __s1, const char_type* __s2, size_t __n)
{
  char_type* __r = __s1;
  if (__s1 < __s2)
  {
    for (; __n; --__n, ++__s1, ++__s2)
    {
      assign(*__s1, *__s2);
    }
  }
  else if (__s2 < __s1)
  {
    __s1 += __n;
    __s2 += __n;
    for (; __n; --__n)
    {
      assign(*--__s1, *--__s2);
    }
  }
  return __r;
}

template <class _CharT>
constexpr _CharT* constexpr_char_traits<_CharT>::copy(char_type* __s1, const char_type* __s2, size_t __n)
{
  assert(__s2 < __s1 || __s2 >= __s1 + __n);
  char_type* __r = __s1;
  for (; __n; --__n, ++__s1, ++__s2)
  {
    assign(*__s1, *__s2);
  }
  return __r;
}

template <class _CharT>
constexpr _CharT* constexpr_char_traits<_CharT>::assign(char_type* __s, size_t __n, char_type __a)
{
  char_type* __r = __s;
  for (; __n; --__n, ++__s)
  {
    assign(*__s, __a);
  }
  return __r;
}

#endif // _CONSTEXPR_CHAR_TRAITS
