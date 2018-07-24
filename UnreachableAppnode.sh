#!/bin/bash
export BIN={INSTALL_HOME}
export TIBCO_HOME={INSTALL_HOME}}
export BW_HOME=${TIBCO_HOME}/bw/6.4
export BW_BIN=${BW_HOME}/bin
export LOGDIR={LOGDIR}


File_mail={INSTALL_HOME}/tmp/appnode_Unreachable_status_Mail_$(whoami).txt
File_debug={INSTALL_HOME}/tmp/appnode_Unreachable_status_debug_$(whoami).txt
Process_List={INSTALL_HOME}/tmp/process_list_$(whoami).txt
TMP_AN_REPORT_DIR={INSTALL_HOME}/tmp/appnodesreport_${LOGNAME}
MACHINE_NAME=`hostname`
HTTP_PORT=`cat ${BW_HOME}/config/bwagent.ini|grep bw.agent.http.port|awk -F"=" '{print $2}'`
EMAIL_SEND=0

echo "#################################################################PROGRAME BEGIN#################################################################" >>${File_debug}
echo "`date +"%m-%d-%Y-%T"` - Programe Starting now to check for each running appnode process" >>${File_debug}
echo "`date +"%m-%d-%Y-%T"` - Machine Name is $MACHINE_NAME" >>${File_debug}
echo "`date +"%m-%d-%Y-%T"` - HTTP PORT is $HTTP_PORT" >>${File_debug}

cat {INSTALL_HOME}/AppNodeStatusCheck/web-part1.html > ${File_mail}

[ -d ${TMP_AN_REPORT_DIR} ] || mkdir ${TMP_AN_REPORT_DIR}

`ps -fu $LOGNAME|grep -v bwappnode.log|grep -v bwappnode.tra|grep -v grep|grep appnode > ${Process_List}`
sed -i 's/pts\/[0-99]//g' ${Process_List}
IFS=$'\n'
for i in `cat ${Process_List}`;
do
	PID=`echo $i|awk -F' ' '{print $2}'`
	DOMAIN=`echo $i|awk -F"/" '{print $8}'`
	APPSPACE=`echo $i|awk -F"/" '{print $10}'`
	APPNODE=`echo $i|awk -F"/" '{print $11}'`
	REST_URL=http://${MACHINE_NAME}:${HTTP_PORT}/bw/v1/domains/${DOMAIN}/appspaces/${APPSPACE}/appnodes/${APPNODE}
	cd ${BW_BIN}
	
	echo "`date +"%m-%d-%Y-%T"` - Executing command to check status of DOMAIN - $DOMAIN, APPSPACE - $APPSPACE, APPNODE - $APPNODE" >>${File_debug}
        echo "`date +"%m-%d-%Y-%T"` - curl -s --URL http://${MACHINE_NAME}:${HTTP_PORT}/bw/v1/domains/${DOMAIN}/appspaces/${APPSPACE}/appnodes/${APPNODE} -o ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}.txt" >>${File_debug}
        
	curl -s --URL http://${MACHINE_NAME}:${HTTP_PORT}/bw/v1/domains/${DOMAIN}/appspaces/${APPSPACE}/appnodes/${APPNODE} -o ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}.txt >>/dev/null
	APPNODE_STATUS=`grep -Po '"state":.*?[^\\\]"' ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}.txt|awk -F":" '{print $2}'|sed 's/"//g'`
        
	echo "`date +"%m-%d-%Y-%T"` - Status of DOMAIN - $DOMAIN, APPSPACE - $APPSPACE, APPNODE - $APPNODE is $APPNODE_STATUS" >>${File_debug}
	
	case $APPNODE_STATUS in
		Running)
			
			echo "`date +"%m-%d-%Y-%T"` - Status is $APPNODE_STATUS, Skipping to next appnode" >>${File_debug}
			printf "\n" >>${File_debug}
			;;
		Starting)
                        echo "`date +"%m-%d-%Y-%T"` - Status is $APPNODE_STATUS, Skipping to next appnode" >>${File_debug}
                        printf "\n" >>${File_debug}
                        ;;

                Stopping)
                        EMAIL_SEND=1
                        ACTION_PERFORMED=Killed
                        echo "`date +"%m-%d-%Y-%T"` - Appnode found in stopping state, executing kill operation on $PID" >>${File_debug}
                        kill -9 $PID
                        curl -s --URL http://${MACHINE_NAME}:${HTTP_PORT}/bw/v1/domains/${DOMAIN}/appspaces/${APPSPACE}/appnodes/${APPNODE} -o ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}_new.txt >>/dev/null
                        CURRENT_APPNODE_STATUS=`grep -Po '"state":.*?[^\\\]"' ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}_new.txt|awk -F":" '{print $2}'|sed 's/"//g'`
                        echo "`date +"%m-%d-%Y-%T"` - Status of appnode $APPNODE after kill is $CURRENT_APPNODE_STATUS" >>${File_debug}
                        echo "<tr><td>$MACHINE_NAME</td><td>$LOGNAME</td><td>$DOMAIN</td><td>$APPSPACE</td><td>$APPNODE</td><td>$PID</td><td>$APPNODE_STATUS</td><td>$ACTION_PERFORMED</td><td>$CURRENT_APPNODE_STATUS</td><td><a href="$REST_URL">Status</a></td></tr>" >> ${File_mail}
                        printf "\n" >>${File_debug}
                        ;;
                Unreachable)
                        EMAIL_SEND=1
                        ACTION_PERFORMED=Informed
                        echo "<tr><td>$MACHINE_NAME</td><td>$LOGNAME</td><td>$DOMAIN</td><td>$APPSPACE</td><td>$APPNODE</td><td>$PID</td><td>$APPNODE_STATUS</td><td>$ACTION_PERFORMED</td><td>NA</td><td><a href="$REST_URL">Status</a></td></tr>" >> ${File_mail}
                        printf "\n" >> ${File_debug}
                        ;;
                Degraded)
                        EMAIL_SEND=1
                        ACTION_PERFORMED=Informed
                        echo "<tr><td>$MACHINE_NAME</td><td>$LOGNAME</td><td>$DOMAIN</td><td>$APPSPACE</td><td>$APPNODE</td><td>$PID</td><td>$APPNODE_STATUS</td><td>$ACTION_PERFORMED</td><td>NA</td><td><a href="$REST_URL">Status</a></td></tr>" >> ${File_mail}
                        printf "\n" >> ${File_debug}
                        ;;
                Out-of-Sync)
                        EMAIL_SEND=1
                        ACTION_PERFORMED=Informed
                        echo "<tr><td>$MACHINE_NAME</td><td>$LOGNAME</td><td>$DOMAIN</td><td>$APPSPACE</td><td>$APPNODE</td><td>$PID</td><td>$APPNODE_STATUS</td><td>$ACTION_PERFORMED</td><td>NA</td><td><a href="$REST_URL">Status</a></td></tr>" >> ${File_mail}
                        printf "\n" >> ${File_debug}
                        ;;

		Stopped)
                        EMAIL_SEND=1
                        ACTION_PERFORMED=Killed
                        echo "`date +"%m-%d-%Y-%T"` - Appnode found in stopped state, executing kill operation on $PID" >>${File_debug}
                        kill -9 $PID
                        curl -s --URL http://${MACHINE_NAME}:${HTTP_PORT}/bw/v1/domains/${DOMAIN}/appspaces/${APPSPACE}/appnodes/${APPNODE} -o ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}_new.txt >>/dev/null
                        CURRENT_APPNODE_STATUS=`grep -Po '"state":.*?[^\\\]"' ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}_new.txt|awk -F":" '{print $2}'|sed 's/"//g'`
                        echo "`date +"%m-%d-%Y-%T"` - Status of appnode $APPNODE after kill is $CURRENT_APPNODE_STATUS" >>${File_debug}
                        echo "<tr><td>$MACHINE_NAME</td><td>$LOGNAME</td><td>$DOMAIN</td><td>$APPSPACE</td><td>$APPNODE</td><td>$PID</td><td>$APPNODE_STATUS</td><td>$ACTION_PERFORMED</td><td>$CURRENT_APPNODE_STATUS</td><td><a href="$REST_URL">Status</a></td></tr>" >> ${File_mail}
                        printf "\n" >>${File_debug}
                        ;;

		*)
			EMAIL_SEND=1
			ACTION_PERFORMED=Informed
			echo "`date +"%m-%d-%Y-%T"` -Status of APPNODE $APPNODE is unknown and recorded as $APPNODE_STATUS" >> ${File_debug}
			Error_Message=`grep -Po '"message":.*?[^\\\]"' ${TMP_AN_REPORT_DIR}/${DOMAIN}_${APPSPACE}_${APPNODE}.txt`
			echo "`date +"%m-%d-%Y-%T"` - Error_Message is -" >> ${File_debug}
			echo "$Error_Message" >> ${File_debug}
			echo "<tr><td>$MACHINE_NAME</td><td>$LOGNAME</td><td>$DOMAIN</td><td>$APPSPACE</td><td>$APPNODE</td><td>$PID</td><td>$APPNODE_STATUS</td><td>$ACTION_PERFORMED</td><td>NA</td><td><a href="$REST_URL">Status</a></td></tr>" >> ${File_mail}
			printf "\n" >> ${File_debug}
			
	esac
	
done

cat {INSTALL_HOME}/AppNodeStatusCheck/web-part2.html >> ${File_mail}

if [ $EMAIL_SEND -eq 1 ]
        then
                (
                echo To: EAI@company.com
                echo Cc: prem.sri@comapny.com
                echo From: EAI_SUPPORT
                echo "Content-Type: text/html;"
                echo Subject: AppNode Status  Exception found on `hostname`
                cat ${File_mail}
                ) | /usr/sbin/sendmail -t

fi
