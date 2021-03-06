##!/bin/bash
#
# Copyright (c) 2009-2013 Volodymyr M. Lisivka <vlisivka@gmail.com>, All Rights Reserved
#
# This file is part of bash-modules (http://trac.assembla.com/bash-modules/).
#
# bash-modules is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 2.1 of the License, or
# (at your option) any later version.
#
# bash-modules is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with bash-modules  If not, see <http://www.gnu.org/licenses/>.

#>>> unit - some useful functions for unit testing.

  . import.sh log arguments

#>>
#>> Functions:

#>>
#>> * unit::assertYes VALUE [MESSAGE]              Show error message, when VALUE is not equal to "yes".
unit::assertYes() {
  local VALUE="${1:-}"
  local MESSAGE="${2:-Value is not \"yes\".}"

  [ "${VALUE:-}" == "yes" ] || {
    log::error "ASSERT FAILED" "$MESSAGE"
    exit 1
  }
}

#>>
#>> * unit::assertNo VALUE [MESSAGE]               Show error message, when VALUE is not equal to "no".
unit::assertNo() {
  local VALUE="$1"
  local MESSAGE="${2:-Value is not \"no\".}"

  [ "$VALUE" == "no" ] || {
    log::error "ASSERT FAILED" "$MESSAGE"
    exit 1
  }
}

#>>
#>> * unit::assertNotEmpty VALUE [MESSAGE]         Show error message, when VALUE is empty.
unit::assertNotEmpty() {
  local VALUE="${1:-}"
  local MESSAGE="${2:-Value is empty.}"

  [ -n "${VALUE:-}" ] || {
    log::error "ASSERT FAILED" "$MESSAGE"
    exit 1
  }
}

#>>
#>> * unit::assertEqual VALUE1 VALUE2 [MESSAGE]    Show error message, when VALUEs are not equal.
unit::assertEqual() {
  local ACTUAL="${1:-}"
  local EXPECTED="${2:-}"
  local MESSAGE="${3:-Values are not equal.}"

  [ "${ACTUAL:-}" == "${EXPECTED:-}" ] || {
    log::error "ASSERT FAILED" "$MESSAGE Actual value: \"${ACTUAL:-}\", expected value: \"${EXPECTED:-}\"."
    exit 1
  }
}

#>>
#>> * unit::assertArraysAreEqual MESSAGE VALUES1... -- VALUES2... - show error message when arrays are not equal in size or content.
unit::assertArraysAreEqual() {
  local MESSAGE="${1:-Arrays are not equal.}" ; shift
  local ARGS=( $@ )

  local I LEN1=''
  for((I=0;I<${#ARGS[@]};I++))
  do
    [ "${ARGS[I]}" != "--" ] || {
      LEN1="$I"
      break
    }
  done

  [ -n "${LEN1:-}" ] || {
    error "Array separator is not found. Put \"--\" between two arrays."
    exit 1
  }

  local LEN2=$(($# - LEN1 - 1))
  local MIN=$(( (LEN1<LEN2) ? LEN1 : LEN2 ))

  for((I=0; I < MIN; I++)) {
    local ACTUAL="${ARGS[I]:-}"
    local EXPECTED="${ARGS[I + LEN1 + 1]:-}"

    [ "${ACTUAL:-}" == "${EXPECTED:-}" ] || {
      log::error "ASSERT FAILED" "$MESSAGE Actual size of array: $LEN1, expected size of array: $LEN2, position in array: $I, actual value: \"${ACTUAL:-}\", expected value: \"${EXPECTED:-}\"."$'\n'"$@"
      exit 1
    }
  }

  [ "$LEN1" -eq "$LEN2" ] || {
    log::error "ASSERT FAILED" "$MESSAGE Arrays are not equal in size. Actual size: $LEN1, expected size: $LEN2."$'\n'"$@"
    exit 1
  }
}

#>>
#>> * unit::assertNotEqual VALUE1 VALUE2 [MESSAGE] Show error message, when VALUEs are equal.
unit::assertNotEqual() {
  local VALUE1="${1:-}"
  local VALUE2="${2:-}"
  local MESSAGE="${3:-values are equal but must not.}"

  [ "${VALUE1:-}" != "${VALUE2:-}" ] || {
    log::error "ASSERT FAILED" "$MESSAGE Value: \"${VALUE1:-}\"."
    exit 1
  }
}

#>>
#>> * unit::assert MESSAGE TEST[...]               Evaluate test and show error message when it returns non-zero exit code.
unit::assert() {
  local MESSAGE="${1:-}"; shift

  eval "$@" || {
    log::error "ASSERT FAILED" "${MESSAGE:-}: $@"
    exit 1
  }
}

#>>
#>> * unit::fail [MESSAGE]                         Show error message.
unit::fail() {
  local MESSAGE="${1:-This point in test case must not be reached.}"; shift
  log::error "FAIL" "$MESSAGE $@"
  exit 1
}

#>>
#>> * unit::run_test_cases [OPTIONS] [--] [ARGUMENTS]   Execute all functions with
#>>    test* prefix in name in alphabetic order
#>>
#>>  OPTIONS:
#>>
#>>    -t | --test TEST_CASE   execute single test case
#>>    -q | --quiet            do not print informational messages and dots
#>>    --debug                 enable stack traces
#>>
#>>  After execution of run_test_cases, following variables will be assigned:
#>>    NUMBER_OF_TEST_CASES - total number of test cases executed
#>>    NUMBER_OF_FAILED_TEST_CASES - number of failed test cases
#>>    FAILED_TEST_CASES - names of functions of failed tests cases
#>>
#>>  All arguments, which are passed to run_test_cases, are passed then to
#>>  unit::setUp, unit::tearDown and test cases using ARGUMENTS array, so you
#>>  can parametrize your test cases. You can call run_test_cases more than
#>>  once with different arguments. Use "--" to strictly separate arguments
#>>  from options.
#>>
#>>  If you want to ignore some test case, just prefix them with
#>>  underscore, so unit::run_test_cases will not see them.
#>>
#>>  If you want to run few subsets of test cases in one file, define each
#>>  subset in it own subshell and execute unit::run_test_cases in each subshell.
#>>
#>>  Each test case is executed in it own subshell, so you can call "exit"
#>>  in test case or assign variables without any effect on subsequent test
#>>  cases.
unit::run_test_cases() {

  NUMBER_OF_TEST_CASES=0
  NUMBER_OF_FAILED_TEST_CASES=0
  FAILED_TEST_CASES=( )

  local __QUIET=no __TEST_CASES=(  )

  arguments::parse "-t|test)__TEST_CASES;A" "-q|--quiet)__QUIET;B" -- "$@" || {
    error "Cannot parse arguments. Command line: $@"
    return 1
  }

  # If no test cases are given via options
  [ "${#__TEST_CASES[@]}" -gt 0 ] || {
    # Then generate list of test cases using compgen
    # As alternative, declare -F | cut -d ' ' -f 3 | grep '^test' can be used
    __TEST_CASES=( $(compgen -A function test) )
  }

  local __TEST __EXIT_CODE=0

  ( set -ue ; FIRST_TEAR_DOWN=yes ; unit::tearDown "${ARGUMENTS[@]:+${ARGUMENTS[@]}}" ) || {
      __EXIT_CODE=$?
      log::error "FAIL" "tearDown before first test case is failed."
    }

  for __TEST in "${__TEST_CASES[@]:+${__TEST_CASES[@]}}"
  do
    let NUMBER_OF_TEST_CASES++ || :
    [ "$__QUIET" == "yes" ] || echo -n "."

    (
      set -ue
      __EXIT_CODE=0

      unit::setUp "${ARGUMENTS[@]:+${ARGUMENTS[@]}}" || {
        __EXIT_CODE=$?
        log::error "FAIL" "setUp before test case #$NUMBER_OF_TEST_CASES ($__TEST) failed."
      }

      ( set -ueo pipefail ; "$__TEST" "${ARGUMENTS[@]:+${ARGUMENTS[@]}}" ) || {
        __EXIT_CODE=$?
        log::error "FAIL" "Test case #$NUMBER_OF_TEST_CASES ($__TEST) failed."
      }

      ( set -ueo pipefail ; unit::tearDown "${ARGUMENTS[@]:+${ARGUMENTS[@]}}" ) || {
        __EXIT_CODE=$?
        log::error "FAIL" "Cleanup after test case #$NUMBER_OF_TEST_CASES ($__TEST) failed."
      }
      exit $__EXIT_CODE # Exit from subshell
    ) || {
      __EXIT_CODE=$?
      let NUMBER_OF_FAILED_TEST_CASES++ || :
      FAILED_TEST_CASES[${#FAILED_TEST_CASES[@]}]="$__TEST"
    }
  done

  [ "$__QUIET" == "yes" ] || echo
  if [ "$__EXIT_CODE" -eq 0 ]
  then
    [ "$__QUIET" == "yes" ] || log::info "OK" "Test cases total: $NUMBER_OF_TEST_CASES, failed: $NUMBER_OF_FAILED_TEST_CASES${FAILED_TEST_CASES[@]:+, failed methods: ${FAILED_TEST_CASES[@]}}."
  else
    log::error "FAIL" "Test cases total: $NUMBER_OF_TEST_CASES, failed: $NUMBER_OF_FAILED_TEST_CASES${FAILED_TEST_CASES[@]:+, failed methods: ${FAILED_TEST_CASES[@]}}."
  fi

  return $__EXIT_CODE
}

#>>
#>>  log::run_test_cases will also call log::setUp and log::tearDown functions before and
#>>  after each test case. By default, they do nothing. Override them to do
#>>  something useful.

#>>
#>>  * unit::setUp - can set variables which are available for following
#>>  test case and tearDown. It also can alter ARGUMENTS array. Test case
#>>  and tearDown are executed in their own subshell, so they cannot change
#>>  outer variables.
unit::setUp() {
  return 0
}

#>>
#>>  * unit::tearDown is called first, before first setUp of first test case, to
#>>  cleanup after possible failed run of previous test case. When it
#>>  called for first time, FIRST_TEAR_DOWN variable with value "yes" is
#>>  available.
unit::tearDown() {
  return 0
}


#>
#> Notes:
#>
#> All assert functions are exuting "exit" instead of returning error code.
#>
#> Typically, *equal* function expercted first value to be actual value
#> to check, and second value to expected value to check with.
