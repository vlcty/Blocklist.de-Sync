#!/bin/bash

##
## Configuration
##

# Files which should be downloaded
TO_DOWNLOAD[0]="http://lists.blocklist.de/lists/ftp.txt"
#TO_DOWNLOAD[1]="http://lists.blocklist.de/lists/bots.txt"
#TO_DOWNLOAD[2]="http://lists.blocklist.de/lists/ssh.txt"
TO_DOWNLOAD[1]="http://lists.blocklist.de/lists/bruteforcelogin.txt"
TO_DOWNLOAD[2]="http://lists.blocklist.de/lists/apache.txt"

# Other settings; Edit if necesarry
CHAINNAME="blocklist-de"
ACTION="REJECT" # Can be DROP
PRINT_REPORT=1

########## Do not edit anything below this line ##########

#
## Needed variables
#
started=`date`
version="1.0.0"
amountDownloaded=0
amountAfterSortAndUnique=0
amountInserted=0
amountDeleted=-1

fileUnfiltered="/tmp/blocklist-ips-unfiltered.txt"
fileFiltered="/tmp/blocklist-ips-filtered.txt"

#
## Download every file and concat to one file
#
for currentFile in "${TO_DOWNLOAD[@]}"
do
    wget -qO - $currentFile >> $fileUnfiltered
done

#
## Sort and filter
#
cat $fileUnfiltered | sort | uniq > $fileFiltered

amountDownloaded=`cat $fileUnfiltered | wc -l`
amountAfterSortAndUnique=`cat $fileFiltered | wc -l`

#
## Create chain if it does not exist
#
iptables --new-chain $CHAINNAME >/dev/null 2>&1

# Insert rule (if necesarry) into INPUT chain so the chain above will also be used
if [ `iptables -L INPUT | grep $CHAINNAME | wc -l` -eq 0 ]
then

	# Insert rule because it is not present
	iptables -I INPUT -j $CHAINNAME

fi

#
## Insert all IPs from the downloaded list if there is no rule stored
#
while read currentIP
do

    # Check via command
    iptables -C $CHAINNAME -s $currentIP -j $ACTION >/dev/null 2>&1

    # Now we have to check the exit code of iptables via $?
    #
    # 0 = rule exists and don't has to be stored again
    # 1 = rule does not exist and has to be stored

    if [ $? -eq 1 ]
    then

        # Append the IP
        iptables -A $CHAINNAME -s $currentIP -j $ACTION >/dev/null 2>&1

        # Increment the counter
        amountInserted=$((amountInserted + 1))

    fi

done < $fileFiltered

## Now we delete the IPs which are stored in iptables but not anymore in the list
while read currentIP
do
    # Check if the ip is in the downloaded list
    if [ `cat $fileFiltered | grep $currentIP | wc -l` -eq 0 ]
    then
        # Delete the rule by its rulenumber
        # Because changing the action would result in errors
        iptables -D $CHAINNAME -s $currentIP -j $ACTION >/dev/null 2>&1

    # Increment the counter
    amountDeleted=$((amountDeleted + 1))

fi

done <<< "`iptables -n -L blocklist-de | awk '{print $4}'`"

## Print report
if [ $PRINT_REPORT -eq 1 ]
then
    echo "--- Blockliste.de :: Update-Report"
    echo ""
    echo "Script Version:     $version"
    echo "Started:            $started"
    echo "Finished:           `date`"
    echo ""
    echo "--> Downloaded IPs: $amountDownloaded"
    echo "--> Unique IPs:     $amountAfterSortAndUnique"
    echo "--> Inserted:       $amountInserted"
    echo "--> Deleted:        $amountDeleted"
fi

#
## Cleanup
#
rm -f /tmp/blocklist-ips-unfiltered.txt
rm -f /tmp/blocklist-ips-filtered.txt