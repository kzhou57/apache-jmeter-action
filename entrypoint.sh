#!/bin/bash

TESTFILE_PATH=$1
OUTPUTREPORTSFOLDER=$2
LOGFILE='jmeter_log.log'
ADDITIONAL_ARGS="${@:3}"
echo "Using Test File Path $TESTFILE_PATH and Output Folder $OUTPUTREPORTSFOLDER with additional args $ADDITIONAL_ARGS"

# Export JAVA_HOME Variable within Entrypoint
export JAVA_HOME="/usr/lib/jvm/java-9-openjdk"

if [ -n "$DEPENDENCY_FOLDER" ]
then
  cp ${GITHUB_WORKSPACE}/${DEPENDENCY_FOLDER}/*.jar ${JMETER_HOME}/lib/
fi

if [ -n "$PLUGINS" ]
then
  echo "$PLUGINS" | tr "," "\n" | parallel -I% --jobs 5 "${JMETER_HOME}/bin/PluginsManagerCMD.sh install %"
fi

status=0

if [ ! -d "$TESTFILE_PATH" ]
then
  echo "Single file specified so only running one test"
  ARGS="-n -t $TESTFILE_PATH -l $LOGFILE -e -f -o $OUTPUTREPORTSFOLDER $ADDITIONAL_ARGS"
  echo "Running jmeter $ARGS"
  jmeter $ARGS
  status=$?
else
  echo "Folder specified - Running each JMX File In Folder : $TESTFILE_PATH"
  FORCE_DELETE_RESULT_FILE='-f'
  find $TESTFILE_PATH -name '*.jmx' -print0 |while read -r -d '' FILE
  do
    ARGS="-n -t $FILE -l $LOGFILE $FORCE_DELETE_RESULT_FILE $ADDITIONAL_ARGS"
    echo "Running jmeter $ARGS"
    jmeter $ARGS
    test_run=$?
    # If any of the previous tests haven't failed
    if [ "$test_run" == "0" ] && [ "$status" == "1" ]
    then
      status=1 # Set one of the tests failing
    fi
    echo "Test $FILE has exited with status code $test_run"
    # Clear the FORCE_DELETE_RESULT_FILE flag, so that the next test result file is appended to the previous one
    FORCE_DELETE_RESULT_FILE=''
  done
  # generate report
  ARGS="-g $LOGFILE -f -o $OUTPUTREPORTSFOLDER $ADDITIONAL_ARGS"
  echo "Generating report with jmeter $ARGS"
  jmeter $ARGS
fi

error=0 # Default error status code

[ $status -eq 0 ] && exit 0 || echo "JMeter exited with status code $status" && exit $status
