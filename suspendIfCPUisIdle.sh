#!/usr/bin/env bash

#===============================================================
# To start at boot:
#===============================================================
# --- USE THE INIT_SCRIPT ASSOCIATED WITH THIS SCRIPT ---
#     (From: https://wiki.debian.org/LSBInitScripts)
#----- To kill process: "pgrep -f suspendIfCPUisIdle.sh" ==> "pkill -9 -f suspendIfCPUisIdle.sh"

MAX_TIMES=40
AVG_CPU_THRESHOLD=6
MAX_CPU_THRESHOLD=10
sleepDelay="1m"
#sleepDelay="2"

logFile="/root/suspendIfCPUisIdle_LOG_FILE.txt"
echo " " >> $logFile 2>&1
echo " " >> $logFile 2>&1
echo " " >> $logFile 2>&1
echo "------------------------------------------------------------" >> $logFile 2>&1
echo " ********** Starting $0: $(date) **********" >> $logFile 2>&1
echo "------------------------------------------------------------" >> $logFile 2>&1
echo "MAX_TIMES=$MAX_TIMES ; sleepDelay=$sleepDelay" >> $logFile 2>&1
echo "THRESHOLD VALUES: AVG_CPU=$AVG_CPU_THRESHOLD ; MAX_CPU=$MAX_CPU_THRESHOLD" >> $logFile 2>&1
echo "------------------------------------------------------------" >> $logFile 2>&1

testLinuxKernelIsRecent() {
    local numCols=$(head -1 /proc/stat |wc -w)
    if [ "$numCols" -lt 11 ]; then
        echo "---" >> $logFile 2>&1
        echo "The file /proc/stat doesn't seem to have enough columns." >> $logFile 2>&1
        echo "It should have at least 11 - it only has: $(head -1 /proc/stat |wc -w)..." >> $logFile 2>&1
        echo "This indicates the Linux kernel version is too old." >> $logFile 2>&1
        echo "Trying to continue anyway..." >> $logFile 2>&1
        echo "---" >> $logFile 2>&1
        #exit 1
    fi
    return "$numCols"
}

AllIsBelow() {
    local threshold="$1" # Save first argument in a variable
    shift # Shift all arguments to the left (original $1 gets lost)
    local array=("$@") # Rebuild the array with rest of arguments
    local length=${#array[@]}
    # Debug:
    initMsg="$(date +%R) L=$length ; threshold=$threshold ; CPU-load: ${array[@]}"

    local allBelow=true
    for i in "${array[@]}"; do
        #echo "TEST: $i" >> $logFile 2>&1
        if [ "$i" -ge "$threshold" ]; then
            allBelow=false
            break;
        fi
    done

    if $allBelow; then
        echo "$initMsg | --> CPU load is below threshold: $threshold"; >> $logFile 2>&1
        true;
    else
        echo "$initMsg | CPU is working: $i >= $threshold" >> $logFile 2>&1
        false;
    fi
}

# this function is used to get the infos about the cpu
getCpuScores() {
    CPU=(`cat /proc/stat | grep ^cpu$1`)
}

# this function is used to get the percentage of utilization of a cpu
getPercentageOfCpu() {
    unset CPU[0]
    local idle=${CPU[4]}
    local total=0
    for val in "${CPU[@]:0:4}"; do
        let "total=$total+$val"
    done
    let "diff_idle=$idle-${PREV_IDLES[$1]}"
    let "diff_total=$total-${PREV_TOTALS[$1]}"
    let "diff_usage=(1000*($diff_total-$diff_idle)/$diff_total+5)/10"
    PERCENTAGES[$1]=$diff_usage
    PREV_IDLES[$1]=$idle
    PREV_TOTALS[$1]=$total
}

# Initialize needed variables
PREV_TOTAL=0
PREV_IDLE=0
# this is to get the number of cpu (there are 11 columns)...
CPUS=(`cat /proc/stat | grep -P '^cpu[0-9]+'`)
#----------------------------------------------------------------
# Column info: http://www.linuxhowtos.org/manpages/5/proc.htm
#----------------------------------------------------------------
# (1) Time spent in user mode.
# (2) Time spent in user mode with low priority (nice).
# (3) Time spent in system mode.
# (4) Time spent in the idle task. This value should be USER_HZ times
#     the second entry in the /proc/uptime pseudo-file.
# (5) Time waiting for I/O to complete (since Linux 2.5.41). This value is not reliable...
# (6) Time servicing interrupts.
# (7) Time servicing softirqs (since Linux 2.6.0-test4).
# (8) Stolen time, which is the time spent in other operating systems
#     when running in a virtualized environment (since Linux 2.6.11).
# (9) Time spent running a virtual CPU for guest operating systems
#     under the control of the Linux kernel (since Linux 2.6.24).
# (10) Time spent running a niced guest (virtual CPU for guest
#      operating systems under the control of the Linux kernel, since Linux
#      2.6.33).
#----------------------------------------------------------------
#cpu0 30426 142 839 167547 74 328 314 0 0 0
#cpu1 30177 73 1090 166595 67 1512 226 0 0 0
#cpu2 31485 70 900 166711 57 309 124 0 0 0
#.... etc
# --- Divide number of fields with 11 columns, to get number of CPUs:


# First, check if Linux kernel is recent:
testLinuxKernelIsRecent
numCols="$?"
echo "Number of columns in /proc/stat: $numCols" >> $logFile 2>&1 # Fix for Synology - older kernels...

lengthArray=${#CPUS[@]}
numberOfCpus=$((lengthArray/numCols))
echo "numberOfCpus=$numberOfCpus" >> $logFile 2>&1
echo " " >> $logFile 2>&1

i=0
PREV_TOTALS=()
PREV_IDLES=()
PERCENTAGES=()
# we instantiate the arrays and set their values to 0
while [ $i -lt $numberOfCpus ]; do
    PREV_TOTALS+=(0)
    PREV_IDLES+=(0)
    PERCENTAGES+=(0)
    i=$((i+1))
done
#echo "PREV_TOTALS (array): ${PREV_TOTALS[@]}" # NB: Has numberOfCpu's + 1 columns! >> $logFile 2>&1
#echo "PREV_IDLES (array): ${PREV_IDLES[@]}" # NB: Has numberOfCpu's + 1 columns! >> $logFile 2>&1
#echo "PERCENTAGES (array): ${PERCENTAGES[@]}" # NB: Has numberOfCpu's + 1 columns! >> $logFile 2>&1
#  PREV_TOTALS (array): 0 0 0 0 0 0 0 0 0 0 0 0
#  PREV_IDLES (array): 0 0 0 0 0 0 0 0 0 0 0 0
#  PERCENTAGES (array): 0 0 0 0 0 0 0 0 0 0 0 0


#=============================================
#  MAIN LOOP: GET THE MEAN USAGE OF THE CPU
#=============================================
MAXCPUARRAY=()
AVGCPUARRAY=()
while true; do
    # we get the mean of the cpu usage
    CPU=(`cat /proc/stat | grep '^cpu '`) # Get the total CPU statistics.
    #echo "CPU=${CPU[@]}" >> $logFile 2>&1
    unset CPU[0]                          # Discard the "cpu" prefix.
    #echo "CPU=${CPU[@]}" >> $logFile 2>&1
    #CPU=cpu 426169 2240 13325 2561501 805 7599 2141 0 0 0
    #CPU=426169 2240 13325 2561501 805 7599 2141 0 0 0
    IDLE=${CPU[4]} # take 4th column value: "2561501" in this example...
    #echo "IDLE=$IDLE" >> $logFile 2>&1
    #IDLE=1326541

    # Calculate the total CPU time.
    TOTAL=0
    #echo "--> ${CPU[@]:0:4}" >> $logFile 2>&1
    for VALUE in "${CPU[@]:0:4}"; do
        let "TOTAL=$TOTAL+$VALUE"
    done

    # Calculate the CPU usage since we last checked.
    let "DIFF_IDLE=$IDLE-$PREV_IDLE"
    let "DIFF_TOTAL=$TOTAL-$PREV_TOTAL"
    let "DIFF_USAGE=(1000*($DIFF_TOTAL-$DIFF_IDLE)/$DIFF_TOTAL+5)/10"
    #echo "DIFF_IDLE:$DIFF_IDLE" >> $logFile 2>&1
    #echo "DIFF_TOTAL:$DIFF_TOTAL" >> $logFile 2>&1
    #echo "DIFF_USAGE:$DIFF_USAGE" >> $logFile 2>&1
    #1:1415435
    #2:1544146
    #3:8

    # Remember the total and idle CPU times for the next check.
    PREV_TOTAL="$TOTAL"
    PREV_IDLE="$IDLE"
    #echo "PREV_TOTAL=$PREV_TOTAL" >> $logFile 2>&1
    #echo "PREV_IDLE=$PREV_IDLE" >> $logFile 2>&1
    #PREV_TOTAL=1693457
    #PREV_IDLE=1556091

    # GET THE MAX USAGE BETWEEN ALL THE CPUS
    # --------------------------------------
    # first we get the percentage of utilization for each cpu
    i=0
    while [ $i -lt $numberOfCpus ]; do
        # we get the cpu score to be able to calculate the percentage of utilization
        getCpuScores $i
        # then we calculate the percentage of the cpu and put it in an array
        getPercentageOfCpu $i
        i=$((i+1))
    done

    # then we get the max
    MAX=${PERCENTAGES[0]}
    cpu=0

    i=0
    while [ $i -lt $numberOfCpus ]; do
        if [ ${PERCENTAGES[$i]} -gt $MAX ]; then
            MAX=${PERCENTAGES[$i]}
            cpu=$i
        fi
        i=$((i+1))
    done

    # finally we display the avg cpu usage and the max cpu usage
    #echo -en "\rCPU: $DIFF_USAGE%  CPU$cpu: $MAX% \b\b" >> $logFile 2>&1

    # Store MAX CPU-utilization/consumption in a vector (remove first elem, if limit reached):
    # Add current CPU max and AVERAGE-values to arrays:
    MAXCPUARRAY+=("$MAX")
    AVGCPUARRAY+=("$DIFF_USAGE")
    #echo -e "\n{AVGCPUARRAY[@]}=${AVGCPUARRAY[@]} ; {MAXCPUARRAY[@]}=${MAXCPUARRAY[@]}" >> $logFile 2>&1

    array_len=${#MAXCPUARRAY[@]} # they're both same length
    if [ $array_len -eq $MAX_TIMES ]; then
        echo '--- TESTING IF PROXMOX SERVER SHOULD SUSPEND... ---' >> $logFile 2>&1
    fi
    if [ $array_len -le $MAX_TIMES ]; then
        echo -e "$(date +%R) | {AVGCPUARRAY[@]}=${AVGCPUARRAY[@]} ; {MAXCPUARRAY[@]}=${MAXCPUARRAY[@]}" >> $logFile 2>&1
    else
        MAXCPUARRAY=("${MAXCPUARRAY[@]:1}") #removed the 1st element
        AVGCPUARRAY=("${AVGCPUARRAY[@]:1}") #removed the 1st element

        # === Check if it's time to suspend ===
        if AllIsBelow "$AVG_CPU_THRESHOLD" "${AVGCPUARRAY[@]}"; then
        echo "$(date +%R) --> Average CPU-utilization is low..." >> $logFile 2>&1
            if AllIsBelow "$MAX_CPU_THRESHOLD" "${MAXCPUARRAY[@]}"; then
                echo "$(date +%R) *** AVG and MAX CPU-load values are below threshold ***" >> $logFile 2>&1
                if true; then # turn on using true here...
                    echo "*** $(date) Resetting and running \"sync && systemctl suspend\" ***" >> $logFile 2>&1
                    # === Reset counters, start all over: ===
                    MAXCPUARRAY=()
                    AVGCPUARRAY=()
                    sync ; sleep 4; sync ; systemctl suspend; sleep 30
                    echo "*** $(date) Up and running again... ***" >> $logFile 2>&1
                fi
            fi
        fi
    fi

    # Wait before next poll (default unit is a number in seconds, while
    #   sleep "2m" = 2 minutes, "2h"=2 hours, "2d"=2 days):
    #sleep 1
    #sleep 2m
    sleep "$sleepDelay"
done
