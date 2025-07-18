#!/bin/bash
 
output_file=../tmp.txt
sortedfile=cluster.txt
resource_list=resource_list.txt
expected_votes=
resource_array=resource_array.txt
messages_2_process=/mnt/e/work/projects/scripts/checkcluster/messages.txt
ha_log=ha-log.txt
report_dir=$1

## removed due to array
#ha_log=/mnt/f/work/Customers/Woolworths/00373903-reboot/azlsolscpp002_20221030_hb_report_log/azlsolscpp002/ha-log.txt

#echo "Start Messages into Arrary"
readarray -t  ar_messages < $messages_2_process
#echo "The following messages snippets ${ar_messages[@]} will be searched from the file: $messages_2_process"


#echo "End read messages to process"



function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

function process_msg(){ ## used to process arrays entries lines with spaces in them 
 var2=${ar_messages[$n]}
}

function confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Do you want to read the outpout now? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
	less ../$sortedfile
          
            ;;
        *)
            echo "Sorted output file has been placed in $sortedfile"
            ;;
    esac
}

#finds all resources and adds them to the array for processing  (15SP3)
function get_resources () {
cd $report_dir
#echo $report_dir
tac  crm_mon.txt | sed -e '/Active Resources:/q'  | tac  | sed -e '/Failed Resource Actions:/q' > $resource_list # finds the line active resources from the end of the cmon.txt
grep -v Resource  $resource_list | grep -v Active | cut -d "(" -f 1 | sed 's/^ *//' | cut -d " " -f 2  > $resource_array
readarray -t ar_resources < $resource_array
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "The cluster logs contain the following resources to be analyzed: ${ar_resources[@]}"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
ar_combined=(${ar_resources[@]} ${ar_messages[@]})
echo "The following messages snippets ${ar_combined[@]} will be searched"
}

function get_corosync_votes () {
node_arraylength=${#ar_nodes[@]}
#echo $arraylength
echo "Cluster under investigation contains ${#ar_nodes[*]} nodes: ${ar_nodes[@]}"  
for (( i=0; i<${node_arraylength}; i++ ));
	do
		
		#cd  $report_dir #change to report direcotry
		cd  ${ar_nodes[$i]} #change to node direcotry
		expected_votes=$(grep expected_votes corosync.conf | cut -d ":" -f 2)
		if [ $expected_votes -lt ${#ar_nodes[*]} ]
			then 
			echo Error: ${ar_nodes[$i]} corosync.conf contains incorrect expected votes count of $expected_votes must to be modified to ${#ar_nodes[*]}!!! 
		fi
		if [ $expected_votes -gt ${#ar_nodes[*]} ]
			then 
			echo Error: ${ar_nodes[$i]} corosync.conf contains incorrect expected votes count of $expected_votes must to be modified to ${#ar_nodes[*]}!!! 
		fi
		cd ..
	done
}

function get_nodes () {
#Get Cluster NOdes and put them in an array
##report_dir=/mnt/f/work/Customers/Woolworths/00373903-reboot/azlsolscpp002_20221030_hb_report_log
#debug echo $report_dir
#cd  $report_dir
readarray -t ar_nodes < <(ls -d */)
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Found following ${#ar_nodes[*]} nodes: ${ar_nodes[@]}"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Report directory is: $report_dir"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

}

function check_specific_resource () {
#Request any resources for checking 
echo -n "What Resources should be checked (only 1)?"
read rsc1
ar_messages+=($rsc1)
}

#remove outputfile
rm ../$output_file $output_file $sortedfile $resource_array $resource_list

#MAIN 
#call functiong et_resources
clear
get_resources
get_nodes
get_corosync_votes
check_specific_resource


#get array length
node_arraylength=${#ar_nodes[@]}
echo $arraylength

## Process cluwter logs for messages 
#for i in "${nodes[@]}"
for (( i=0; i<${node_arraylength}; i++ ));
	do
	#change to node direcotry
	#cd  $report_dir
	#debug pwd
	cd  ${ar_nodes[$i]}
	pwd
	echo "Start finding log entries on: ${ar_nodes[$i]}" 
	
	#check for cluster messages:
	#get message array length
	ar_messages_length=${#ar_messages[@]}
	echo "Check $ar_messages_length lines for cluster messages "
	#process messages array 
		for (( n=0; n<${ar_messages_length}; n++ ));
			do
			#debug echo "Find \""${ar_messages[$n]}"\" in  $ha_log on node ${ar_nodes[$i]}"
#			process_msg
			#echo $var2
			grep "$var2" $ha_log 
			#pause
			#grep "$var2" $ha_log >> $output_file	
			
				case ${#ar_messages[$n]} in
				*"warning: Processing failed monitor"*) #process any lines that need previos 10 lines
				grep -A10"$var2" $ha_log | grep -A 7 Forcing >> $outputfile
				;;
				*"notice: Clearing failure"*)
				grep -A5 "$var2" $ha_log >> $outputfile #process any lines that need previos 5 lines
				;;
				*"Stonith failed"*)
				grep -B 3 "$var2"} $ha_log >> $outputfile #process any lines that need next 3 lines 
				;;
				*)
				process_msg
				grep  "$var2" $ha_log >> $output_file	
								;;
				esac
				
		done

# <<--replaced by array
# check for SAPSRV start 
#grep "sapstartsrv is not running for instance" $ha_log >> $outputfile
## check for aborted cluster operations 
#grep  "aborted by operation" $ha_log >> $outputfile
## check for failing monitor operations with a force move 
#grep -A 10 "warning: Processing failed monitor" $ha_log | grep -A 7 Forcing >>$outputfile
## check for expired failures
#grep -A 5 "notice: Clearing failure" $ha_log >>$outputfile
## check for max connections
#grep  "Failed to create session: Maximum number of sessions (8192)" $ha_log >>$outputfile
## check unknown shutdown fence
#grep  "will be fenced" $ha_log >>$outputfile
#echo " Check for fencing messages on ${nodes[$i]}"
#grep  "state is now lost" $ha_log >>$outputfile
#grep  "TOTEM" $ha_log >>$outputfile
#stonith fails 
#echo " Check for Stonith"
#grep -B 3 "Stonith failed" $ha_log >>$outputfile
#check pacemaker 
#echo "Pacemaker messages"
#grep "pacemaker-controld" $ha_log >>$outputfile
#check input resources 
## end replaced by array -->>

#grep $rsc1 $ha_log >>$outputfile
echo "End finding log entries on: ${ar_nodes[$i]}"
echo 
echo 
echo " End ${nodes[$i]}" >> $output_file
cd ..
pwd
done

#process output file 

sort -o $sortedfile tmp.txt  
uniq -u $sortedfile
mv  $sortedfile ../$sortedfile
confirm
#less $sortedfile

