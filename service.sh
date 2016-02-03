#!/bin/sh
#****************************************************************#
# ScriptName: service.sh
# Create Date: 2014-07-23 19:29
# Modify Date: 2014-07-23 19:29
#***************************************************************#
SERVICE_NAME="marvel"
PID_FILE="$SERVICE_NAME.pid"
BASE_DIR=$(dirname $1)
LIB_DIR=$BASE_DIR/lib
LIB_JARS=`ls $LIB_DIR|grep .jar|awk '{print "'$LIB_DIR'/"$0}'|tr "\n" ":"`
CLASSPATH=$LIB_JARS
#CLASSPATH="../lib/*.jar"

if [ -z "$JAVA_HOME" ]; then
  JAVA_HOME= /alidata1/admin/jdk1.7.0_79/
fi

JAVA_OPT_1="-server -Xms2g -Xmx2g -Xmn1g -XX:PermSize=128m -XX:MaxPermSize=320m"
JAVA_OPT_2="-XX:+UseConcMarkSweepGC -XX:+UseCMSCompactAtFullCollection -XX:CMSInitiatingOccupancyFraction=70 -XX:+CMSParallelRemarkEnabled -XX:SoftRefLRUPolicyMSPerMB=0 -XX:+CMSClassUnloadingEnabled -XX:SurvivorRatio=8 -XX:+DisableExplicitGC"
#JAVA_OPT_3="-verbose:gc -Xloggc:${HOME}/userservice_gc.log -XX:+PrintGCDetails"
JAVA_OPT_4="-XX:-OmitStackTraceInFastThrow"
JAVA_OPT_5="-Djava.ext.dirs=${JAVA_HOME}/jre/lib/ext"
#JAVA_OPT_6="-Xdebug -Xrunjdwp:transport=dt_socket,address=9555,server=y,suspend=n"
JAVA_OPT_7="-cp ${CLASSPATH}"
JAVA_OPT_8="-Dfile.encoding=utf-8"

JAVA_OPTS="${JAVA_OPT_1} ${JAVA_OPT_2} ${JAVA_OPT_3} ${JAVA_OPT_4} ${JAVA_OPT_5} ${JAVA_OPT_6} ${JAVA_OPT_7} ${JAVA_OPT_8}"

JAVA="$JAVA_HOME/bin/java"
#KEYWORD=" -jar lib/*.jar "
KEYWORD=" com.zhongan.es.marvel.bootstrap.Marvel"


# Returns 0 if the process with PID $1 is running.
function checkProcessIsRunning {
   local pid="$1"
   ps -ef | grep java | grep $pid | grep "$KEYWORD" | grep -q --binary -F java
   if [ $? -ne 0 ]; then return 1; fi
   return 0;
}

# Returns 0 when the service is running and sets the variable $pid to the PID.
function getServicePID {
   if [ ! -f $PID_FILE ]; then return 1; fi
   pid="$(<$PID_FILE)"
   checkProcessIsRunning $pid || return 1
   return 0; }

function startServiceProcess {
   touch $PID_FILE
   echo "lib dir =$LIB_DIR"
   echo "classpath = $CLASSPATH"
   rm -rf nohup.log
   nohup $JAVA $JAVA_OPTS $KEYWORD >> nohup.log 2>&1 & echo $! > $PID_FILE
   sleep 0.1
   pid="$(<$PID_FILE)"
   if checkProcessIsRunning $pid; then :; else
      echo "$SERVICE_NAME start failed, see nohup.log."
      return 1
   fi
   return 0;
}

function stopServiceProcess {
   STOP_DATE=`date +%Y%m%d%H%M%S`
   kill $pid || return 1
   for ((i=0; i<10; i++)); do
      checkProcessIsRunning $pid
      if [ $? -ne 0 ]; then
         rm -f $PID_FILE
         return 0
         fi
      sleep 1
      done
   echo "\n$SERVICE_NAME did not terminate within 10 seconds, sending SIGKILL..."
   kill -s KILL $pid || return 1
   local killWaitTime=15
   for ((i=0; i<10; i++)); do
      checkProcessIsRunning $pid
      if [ $? -ne 0 ]; then
         rm -f $PID_FILE
         return 0
         fi
      sleep 1
      done
   echo "Error: $SERVICE_NAME could not be stopped within 10 + 10 seconds!"
   return 1;
}

function startService {
   getServicePID
   if [ $? -eq 0 ]; then echo "$SERVICE_NAME is already running"; RETVAL=0; return 0; fi
   echo -n "Starting $SERVICE_NAME..."
   startServiceProcess
   if [ $? -ne 0 ]; then RETVAL=1; echo "failed"; return 1; fi
   COUNT=0
   while [ $COUNT -lt 1 ]; do
    for (( i=0;  i<60;  i=i+1 )) do
        STR=`grep "Marvel service started!" nohup.log`
        if [ ! -z "$STR" ]; then
            echo "PID=$pid\n"
            echo "Server start OK in $i seconds."
            break;
        fi
            echo -e ".\c"
            sleep 1
        done
        break
    done
echo "OK!"
#START_PIDS=`ps  --no-heading -C java -f --width 1000 | grep "$DEPLOY_HOME" |awk '{print $2}'`
#echo "PID: $START_PIDS"
#   echo "started PID=$pid"
   RETVAL=0
   return 0;
}

function stopService {
   getServicePID
   if [ $? -ne 0 ]; then echo -n "$SERVICE_NAME is not running"; RETVAL=0; echo ""; return 0; fi
   echo "Stopping $SERVICE_NAME... "
   stopServiceProcess
   if [ $? -ne 0 ]; then RETVAL=1; echo "failed"; return 1; fi
   echo "stopped PID=$pid"
   RETVAL=0
   return 0;
}

function checkServiceStatus {
   echo -n "Checking for $SERVICE_NAME: "
   if getServicePID; then
        echo "running PID=$pid"
        RETVAL=0
   else
        echo "stopped"
        RETVAL=3
   fi
   return 0;
}

function main {
   RETVAL=0
   case "$1" in
      start)
         startService
         ;;
      stop)
         stopService
         ;;
      restart)
         stopService && startService
         ;;
      status)
         checkServiceStatus
         ;;
      *)
         echo "Usage: $0 {start|stop|restart|status}"
         exit 1
         ;;
      esac
   exit $RETVAL
}

main $1
