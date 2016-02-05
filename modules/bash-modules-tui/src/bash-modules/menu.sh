#!/bin/bash
#
# Copyright (c) 2009-2011 Volodymyr M. Lisivka <vlisivka@gmail.com>, All Rights Reserved
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



[ "${__menu__DEFINED:-}" == "yes" ] || {
  __menu__DEFINED="yes"

  . import.sh terminal

  menu_summary() {
    echo "Simple full-screen menu for xterm compatible terminals."
  }



  __MENU_BOX_CHARACTERS='┌─┐│└─┘│'
  #__MENU_BOX_CHARACTERS='+-+|+=+#'

  # These characters are used to fill empty space in element of menu
  __MENU_SPACES="                                                                                                                      "

menu_keyboard_input_tokenizer() {

# Generated by bash-modules/keyboard_input_tokenizer.sh written by Volodymyr M. Lisivka <vlisivka@gmail.com>

while true; do
IFS=""
TOKENIZER_KEY_SEQUENCE=""
    read -t 1 -s -r -N 1 TOKENIZER_KEY || { if [ $? -gt 128 ]; then echo "TIMEOUT" || break ; continue ; else echo "EOF" ; break ; fi ; }
    TOKENIZER_KEY_SEQUENCE="$TOKENIZER_KEY_SEQUENCE$TOKENIZER_KEY"
    case "$TOKENIZER_KEY" in
      $'\n')
        echo newline || break
      ;;
      $'\cL')
        echo ctrl_l || break
      ;;
      $'\e')
        read -t 1 -s -r -N 1 TOKENIZER_KEY || { if [ $? -gt 128 ]; then echo "TIMEOUT" || break ; continue ; else echo "EOF" ; break ; fi ; }
        TOKENIZER_KEY_SEQUENCE="$TOKENIZER_KEY_SEQUENCE$TOKENIZER_KEY"
        case "$TOKENIZER_KEY" in
          $'\e')
            echo alt_escape || break
          ;;
          '[')
            read -t 1 -s -r -N 1 TOKENIZER_KEY || { if [ $? -gt 128 ]; then echo "TIMEOUT" || break ; continue ; else echo "EOF" ; break ; fi ; }
            TOKENIZER_KEY_SEQUENCE="$TOKENIZER_KEY_SEQUENCE$TOKENIZER_KEY"
            case "$TOKENIZER_KEY" in
              'A')
                echo up || break
              ;;
              'B')
                echo down || break
              ;;
            esac
          ;;
        esac
      ;;
      ' ')
        echo space || break
      ;;
      *)
        echo "$TOKENIZER_KEY" || break
      ;;
    esac
done

}


print_at() {
  local x="$1"
  local y="$2"
  shift 2

  echo -n $'\E'"[${y};${x}H$*"
}

#
# Draw vertical line at given column.
#
vline() {
  local x="$1"
  local from_y="$2"
  local to_y="$3"

  local y
  for((y=$from_y;y<=$to_y;y++))
  do
    print_at "$x" "$y" "${__MENU_BOX_CHARACTERS:3:1}"
  done
}

#
# Draw horizontal line at given row.
#
top_hline() {
  local y="$1"
  local from_x="$2"
  local to_x="$3"

  print_at "$from_x" "$y" "${__MENU_BOX_CHARACTERS:0:1}"

  local x
  for((x=$from_x+1;x<=$to_x-1;x++))
  do
    echo -n "${__MENU_BOX_CHARACTERS:1:1}"
  done
    echo -n "${__MENU_BOX_CHARACTERS:2:1}"
}
bottom_hline() {
  local y="$1"
  local from_x="$2"
  local to_x="$3"

  print_at "$from_x" "$y" "${__MENU_BOX_CHARACTERS:4:1}"

  local x
  for((x=$from_x+1;x<=$to_x-1;x++))
  do
    echo -n "${__MENU_BOX_CHARACTERS:5:1}"
  done
    echo -n "${__MENU_BOX_CHARACTERS:6:1}"
}

box() {
  local from_x="$1"
  local from_y="$2"
  local to_x="$3"
  local to_y="$4"

  vline "$from_x" "$(( from_y + 1 ))" "$(( to_y - 1 ))"
  vline "$to_x" "$(( from_y + 1 ))" "$(( to_y - 1 ))"

  top_hline "$from_y" "$from_x" "$to_x"
  bottom_hline "$to_y" "$from_x" "$to_x"
}

draw_item() {
  local x="$1"
  local y="$2"
  local i="$3"
  local ITEM="$4"

  print_at $(($x+2)) $(($y + $i+2)) "$ITEM"
}

refresh_menu() {
  local x="$1"
  local y="$2"
  local pos="$3"

  local i=0 ITEM
  for ITEM in "${MENU_ELEMENTS[@]}"
  do
    (( pos == i )) && echo -n "$T_BOLD_ON$T_REVERSE_ON"
    draw_item $x $y $i "$ITEM"
    (( pos == i )) && echo -n "$T_BOLD_OFF$T_REVERSE_OFF"
    let i=i+1
  done
}

menu_redraw_border() {
  local COLUMNS="$(tput cols)"
  local LINES="$(tput lines)"

  if [ "$x" == "center" ]
  then
    x=$(( COLUMNS/2 - max_length/2 ))
  fi

  if [ "$y" == "center" ]
  then
    y=$(( LINES/2 - ${#MENU_ELEMENTS[@]}/2 ))
  fi
  (( x < ( COLUMNS - max_length) )) || x=$(( COLUMNS - max_length ))
  (( y < ( LINES - ${#MENU_ELEMENTS[@]} ) )) || y=$(( LINES - ${#MENU_ELEMENTS[@]} ))
  (( x >= 0 )) || x=0
  (( y >= 0 )) || y=0

  box "$x" "$((y + 1 ))" $((x + max_length + 3)) $((y + ${#MENU_ELEMENTS[@]} + 2))
  print_at $x $y "$MENU_TITLE"
}

menu() {
  local x="$1"
  local y="$2"
  local MENU_TITLE="$3"
  shift 3

  local pos=0

  local max_length=0 ITEM
  for ITEM in "$@"
  do
    [ ${#ITEM} -gt $max_length ] && max_length=${#ITEM}
  done

  # Add spaces to each menu element
  local MENU_ELEMENTS=(  )
  for ITEM in "$@"
  do
    local trail_length=$(( max_length - ${#ITEM} ))
    MENU_ELEMENTS[${#MENU_ELEMENTS[@]}]="$ITEM${__MENU_SPACES:0:trail_length}"
  done

  menu_redraw_border
  refresh_menu $x $y $pos

  local REPLY
  while read REPLY
  do

    case "$REPLY" in
      up)
         pos=$(($pos-1))
         # If pos less than zero, then jump to end of list
         (( pos >= 0 )) || pos=$(( $# - 1 ))
      ;;
      down)
         pos=$(($pos+1))
         # If pos larger than list size, then jump to begining of list
         (( pos < $# )) || pos=0
      ;;

      # Selected item
      newline|space)
        MENU_MENU_SELECTED_ITEM_NUMBER="$pos"

        # Positional variables are starting from 1, so we need to
        # increase pos to be able to use $!{pos}
        let ++pos

        MENU_SELECTED_ITEM="${!pos}"
        return 0
      ;;

      # Exit from menu
      alt_escape|EOF)
        MENU_MENU_SELECTED_ITEM_NUMBER="-1"
        MENU_SELECTED_ITEM=""
        return 0
      ;;

      # Refresh menu
      ctrl_l)
        echo -n "$T_CLEAR_ALL"
        menu_redraw_border
      ;;

      ?)
        # TODO: search next menu item by first letter
        local I
        for((I=1; I<$#; I++))
        do
          [[ "${MENU_ELEMENTS[ (I+pos) % $# ]}" != "$REPLY"* ]] || {
            pos=$(( (I+pos) % $# ))
            break
          }
        done
      ;;
    esac

    refresh_menu "$x" "$y" "$pos"
  done
}

menu_usage() {

echo '

Example:

#!/bin/bash

set -ue

. import.sh log terminal menu

# Hide cursor and switch to alternate screen
switch_to_alternate_screen
echo -n "$T_CURSOR_OFF"

# Restore screen and cursor at exit
trap "switch_from_alternate_screen; echo -n \"\$T_CURSOR_ON\" " EXIT SIGHUP
echo -n "$T_CLEAR_ALL"

# Create temporary fifo file
TEMP_FIFO="$(mktemp -t "menu_example.XXXXXXXXXXXXXX.fifo")"
rm -f "$TEMP_FIFO"
mkfifo "$TEMP_FIFO" || {
  error "Cannot create fifo file."
  exit 1
}

menu_keyboard_input_tokenizer >"$TEMP_FIFO" 2>&1 </dev/stdin & sleep 0.01

<"$TEMP_FIFO" menu center center "Виберіть фрукт чи ягоду" "яблуко" "вишня" "апельсин" "груша" "слива" "виноград" "агрус" "свіжі помідори" "яблуко" "вишня" "апельсин" "груша" "слива" "виноград" "агрус" "свіжі помідори"

rm -f "$TEMP_FIFO"

# Make cursor visible again and return back to main screen
echo -n "$T_CLEAR_ALL"
switch_from_alternate_screen
echo -n "$T_CURSOR_ON"

info "Selected item number: $MENU_MENU_SELECTED_ITEM_NUMBER."
info "Selected item: $MENU_SELECTED_ITEM."
echo


'

}

}