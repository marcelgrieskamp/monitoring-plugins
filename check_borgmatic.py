#!/usr/bin/python3
# 
# Copyright (c) 2020 chris2k20
# (https://github.com/chris2k20/check_borgmatic)
#
# Python3 Nagios/Icinga2 plugin for borgmatic to check the last successful backup
# 
# ./check_borgmatic.py -c <seconds> -w <seconds>
#

version = "0.1"

# Imports
import subprocess
import json
import datetime
import sys
import argparse

# default crit, warn
warn_sec = 86400 # 1 day
crit_sec = 86400*3 # 3 days
# the following settings must fit with your sudoers entry:
borgmatic_bin = "sudo borgmatic"
borgmatic_parameters = "--list --successful --last 1 --json"

# init the parser
parser = argparse.ArgumentParser(description='nagios/icinga2 plugin for borgmatic to check the last successful backup.')
parser.add_argument("-V", "--version", help="show program version", action="store_true")
parser.add_argument("-c", "--critical", type=int, metavar='seconds', help="critical time since last backup (in seconds)")
parser.add_argument("-w", "--warning", type=int, metavar='seconds', help="warning time since last backup (in seconds)")
# read arguments from the cmd line
args = parser.parse_args()
# check for --version
if args.version:
  print("check_borgmatic.py - Version:", version)
  sys.exit(0)
# check for --critical
if args.critical:
  crit_sec = int(args.critical)
# check for --warning
if args.warning:
  warn_sec = int(args.warning)

# Plugin start
# Try to get Data from borgmatic 
try:
  output = subprocess.check_output(borgmatic_bin+" "+borgmatic_parameters, shell=True)
except:
  print("UNKOWN - can not get data from borgmatic!")
  sys.exit(3)

try:
  output_string = output.decode('utf-8') # Decode using utf-8 encoding
  data = json.loads(output_string) # load json
except:
  print("UNKOWN - can decode borgmatic data!")
  sys.exit(3)
 
if not data[0]['archives']:
  print("CRITICAL - no successful backup found!")
  sys.exit(2)

last_backup_name = data[0]['archives'][0]['name'] 
last_backup_time_str = data[0]['archives'][0]['time']

last_backup_time = datetime.datetime.strptime(last_backup_time_str, '%Y-%m-%dT%H:%M:%S.%f')

time_now = datetime.datetime.now()

# calculate delta
time_past = time_now - last_backup_time
time_past_sec = round(time_past.total_seconds())

# Check data: seconds
if time_past_sec < warn_sec:
  print("OK - last borgmatic backup: %s (age: %s) with name %s | 'lastbackup_s'=%s" % (last_backup_time, time_past, last_backup_name, time_past_sec))  
  sys.exit(0)
elif time_past_sec > warn_sec and time_past_sec < crit_sec:
  print("WARNING - last borgmatic backup: %s (age: %s) with name %s | 'lastbackup_s'=%s" % (last_backup_time, time_past, last_backup_name, time_past_sec))  
  sys.exit(1)
elif time_past_sec > crit_sec:
  print("CRITICAL - last borgmatic backup: %s (age: %s) with name %s | 'lastbackup_s'=%s" % (last_backup_time, time_past, last_backup_name, time_past_sec))   
  sys.exit(2)
else:
  print("UNKOWN - last borgmatic backup: %s (age: %s) with name %s | 'lastbackup_s'=%s" % (last_backup_time, time_past, last_backup_name, time_past_sec))
  sys.exit(3)
