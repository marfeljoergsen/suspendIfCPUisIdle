#!/usr/bin/env bash
# /etc/init.d/suspendIfCPUisIdle_INIT_SCRIPT.sh

# --- From: https://wiki.debian.org/LSBInitScripts
### BEGIN INIT INFO
# Provides:          suspendIfCPUisIdle_INIT.sh
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

#===============================================================
# To start at boot:
#===============================================================
# ==> First make executable + test start and stop:
#sudo chmod 755 /etc/init.d/suspendIfCPUisIdle_INIT.sh
#sudo /etc/init.d/suspendIfCPUisIdle_INIT.sh start
#sudo /etc/init.d/suspendIfCPUisIdle_INIT.sh stop
#
# ==> To register your script to be run at start-up and shutdown, run the following command:
#update-rc.d suspendIfCPUisIdle_INIT.sh defaults
# (the file "/etc/init.d/suspendIfCPUisIdle_INIT.sh" is then pointed to by symbolic links, from the different
#  runlevels, e.g. "/etc/rc5.d/S01suspendIfCPUisIdle_INIT.sh -> ../init.d/suspendIfCPUisIdle_INIT.sh")
#
# ==> If you ever want to remove the script from start-up, run the following command:
# sudo update-rc.d -f suspendIfCPUisIdle_INIT.sh remove 
#===============================================================

# ---=== THE FOLLOWING IS VERY IMPORTANT (CHECK scriptName)! ===---
# cp -i suspendIfCPUisIdle_INIT.sh /etc/init.d/
scriptName="suspendIfCPUisIdle.sh"

case "$1" in
  start)
    # PREFERABLY USE "pgrep -f ..." TO *DISALLOW* STARTING MORE THAN 1 TIME!!!
    echo "Starting \"$scriptName\""
    "/root/$scriptName" & disown
    ;;
  stop)
    echo "Stopping \"$scriptName\""
    #----- To kill process: "pgrep -f suspendIfCPUisIdle.sh" ==> "pkill -9 -f suspendIfCPUisIdle.sh"
    pkill -9 -f "$scriptName"
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac
exit 0

