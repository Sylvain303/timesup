#!/bin/bash
#
# Intrusive visual alarm scheduled for xfce
#
# Usage: timesup TIME|now
#
#  TIME  start at the given schedule format HH:MM
#  now   timesup now!
#  next  report for $DELAY_MIN minutes
#
# Behavior:
#
# At the given time, it countdowns some alerts.
# When the countdown is over it displays a visible annoying message.
# After a $LOCK_DELAY_SEC it locks the screen.
#
# If the argument is 'now' it starts the countdown immediately.

$COUNTDOWN=20
$LOCK_DELAY_SEC=20

$ICON=dialog-information
#ICON=dialog-error

$COUNTDOWN_MESG="Il reste %d secondes"
$LOCK_MESG="Voulez vous repousser le lock ?"
$DISABLE_LOCK="Il vous reste %d sec…"
$STOP_MESG="FIN"
$NB_STOP=4
$DELAY_MIN=1

# functions definitions =================================================
# Usage: check_args "$@"
def check_args()
    if [[ $# -lt 1 ]]
    then
        echo "error: timesup argument"
        exit 1
    fi

    # 3 kind of argument
    SKIP_AT=0
    case "$1" in
        now)
            SKIP_AT=1
            ;;
        next)
            # compute now +delay
            AT_TIME=$(next_time $DELAY_MIN)
            ;;
        *)
            # will match a timespec HH:MM
            AT_TIME=$1
            ;;
    esac
end

schedule_delayed_alarm() {
    local at_time="$1"

    # timespec validation
    local regexp='^[0-9]{2}:([0-9]{2})?$'
    if [[ ! "$at_time" =~ $regexp ]]
    then
        echo "format error: HH:MM"
        exit 1
    fi

    # allow param shortcut HH:
    if [[ "${BASH_REMATCH[1]}" == "" ]]
    then
        at_time="${at_time}00"
    fi

    if [[ -z "$me" ]]
    then
        echo "error: \$me is empty"
        exit 1
    fi

    # can use at -m to recieve a debug mail
    echo "$me now" | at -m $at_time
}

countdown_loop() {
    local s
    local txt
    local countdown=$1
    # countdown loop
    for s in $(seq $countdown -1 1)
    do
        txt=$(printf "$COUNTDOWN_MESG" $s)
        notify-send "Time's up!" "$txt" --icon=$ICON --expire-time=200
        sleep 1.5
    done
}

# Usage: display_stop_message $nb_stop
display_stop_message() {
    # STOP message
    # almost all screen wide
    local s=" =================================================================================================================================================================================== "
    local i
    local nb_stop=$1

    for i in $(seq 1 $nb_stop)
    do
        notify-send "Time's up!" "${s}$STOP_MESG${s}" \
            --icon=dialog-error --expire-time=20000
    done
}

# Usage: dialog_box_delaying_lock $lock_delay_sec
dialog_box_delaying_lock() {
    local lock_delay_sec=$1
    printf >&2 -- "display_stop_message lock_delay_sec=$lock_delay_sec"
    local text=$(printf "$DISABLE_LOCK" $lock_delay_sec)
    # at don't export DISPLAY so graphical app wont work.
    export DISPLAY=:0
    timeout $lock_delay_sec \
        zenity --question --title="$LOCK_MESG" --text="$text"
    local res=$?
    echo $res
}

# Usage: next_time $delay_min
next_time() {
    local delay_min=$1
    date '+%R' -d "now +$delay_min minutes"
}

# Usage: main "$@"
main() {
    check_args "$@"

    # schedule delayed alarm
    if [[ $SKIP_AT -eq 0 ]]
    then
        schedule_delayed_alarm $AT_TIME
        exit 0
    fi

    # NOW !
    countdown_loop $COUNTDOWN

    display_stop_message $NB_STOP

    # the dialog_box_delaying_lock should introduce the delay
    local res=$(dialog_box_delaying_lock $LOCK_DELAY_SEC)
    if [[ $res -ne 0 ]]
    then
        # lock screen
        xflock4
    else
        schedule_delayed_alarm $(next_time $DELAY_MIN)
    fi
}

# ============================================= main script code

# when sourced $me has no significant value
me=$(readlink -f $0)

# sourcing code detection, if code is sourced for debug purpose,
# main is not executed.
[[ $0 != "$BASH_SOURCE" ]] && sourced=1 || sourced=0
if  [[ $sourced -eq 0 ]]
then
    # pass positional argument as is
    main "$@"
fi
