#!/bin/bash
oriPodLockName="Podfile.lock"
oriPodsDIR="Pods"
backPodLockName="backPodfile.lock"
backPodsDIR="backPodsDIR"
logFile=`date "+%Y_%m_%d_%H_%M_%S"`
logFile="${logFile}PodErrMsg.txt"
currentDIR=`pwd`
currentworkSpace=""
backworkSpaceDIR="backworkSpaceDIR.xcworkspace"
diffchangeFile=`date "+%Y_%m_%d_%H_%M_%S"`
diffchangeFile="${diffchangeFile}diffChange.txt"
function getcurrentWorkSpace() {
  workspacePostFix=".xcworkspace"
  for file_a in ${currentDIR}/*
  do
    result=$(echo $file_a | grep "${workspacePostFix}")
    if [[ "$result" != "" ]]
    then
      currentworkSpace=$result
    fi
  done
}
getcurrentWorkSpace

function beforePod() {

  #先复制一份原始的lock文件 和 Pods文件夹
  echo "正在备份资源"
  cp  ${oriPodLockName} ${backPodLockName}  >> ${logFile}
  cp -a ${oriPodsDIR}   ${backPodsDIR}  >> ${logFile}
  cp -a ${currentworkSpace} ${backworkSpaceDIR} >> ${logFile}
}
function afterPod() {
  echo "资源后续清理"
  rm ${backPodLockName}  >> ${logFile}
  rm -rf ${backPodsDIR} >> ${logFile}
  rm -rf ${backworkSpaceDIR} >> ${logFile}
}
function recoverPod() {
  echo "正在恢复原始文件"
  mv -f ${backPodLockName} ${oriPodLockName}

  rm -rf ${oriPodsDIR} >> ${logFile}
  cp -a ${backPodsDIR}   ${oriPodsDIR}  >> ${logFile}
  rm -rf ${backPodsDIR} >> ${logFile}
  # mv -f ${backPodsDIR} ${oriPodsDIR}
  rm -rf ${currentworkSpace} >> ${logFile}
  cp -a ${backworkSpaceDIR}   ${currentworkSpace}  >> ${logFile}
  rm -rf ${backworkSpaceDIR} >> ${logFile}

}
function diffchange() {
  echo "-------------------------------当前发生变更的pod库---------------------------------" >> ${diffchangeFile}
  echo "--------------------------------------------------------------------------------" >> ${diffchangeFile}
  for (( i = 0; i < 3; i++ )); do
    echo ""
  done
  ### something
  diff ${oriPodLockName} ${backPodLockName}  -H >> ${diffchangeFile}
  echo "-----------------------------当前发生变更的第三方文件统计----------------------------" >> ${diffchangeFile}
  echo "--------------------------------------------------------------------------------" >> ${diffchangeFile}
  for (( i = 0; i < 3; i++ )); do
    echo ""
  done
  diff ${backPodsDIR} ${oriPodsDIR} -r -B -a | diffstat >> ${diffchangeFile}


  echo "-------------------------当前发生变更的第三方文件变化详细统计-------------------------" >> ${diffchangeFile}
  echo "--------------------------------------------------------------------------------" >> ${diffchangeFile}
  for (( i = 0; i < 3; i++ )); do
    echo ""
  done
  diff ${backPodsDIR} ${oriPodsDIR} -r -B -b >> ${diffchangeFile}

  open -a Atom     ${diffchangeFile}

  if [  $? != 0 ]
  then
    open -a Xcode ${diffchangeFile}
  fi

  if [  $? != 0 ]
  then
    open  ${diffchangeFile}
  fi

}
function install() {

  echo "请输入Pod command 相关参数 "
  echo "1 ： install"
  echo "2 ： update"
  echo "3 ： install --verbose --no-repo-update"
  echo "4 ： update --verbose --no-repo-update"
  echo "5 ： 自定义参数"
  podcommandParam="install"
  while  read podCommandInputParam
  do
    case ${podCommandInputParam} in
      1)
      podcommandParam="install"
      break
      ;;
      2)
      podcommandParam="update"
      break
      ;;
      3)
      podcommandParam="install --verbose --no-repo-update"
      break
      ;;
      4)
      podcommandParam="update --verbose --no-repo-update"
      break
      ;;
      5)
      echo "请输入自定义参数"
      read podcommandParam
      break
      ;;
      *)
      echo "输入有错请重新输入"
      ;;
    esac

  done


  echo "您选择的是-------${podcommandParam}"
  beforePod
  echo "正在使用Pod命令"

  pod ${podcommandParam} 2>> ${logFile}
  if [ $? != 0  ]
  then
    recoverPod
    echo "Pod 命令执行失败 请检查是错误信息"
    open  ${logFile}
    exit 1
  fi

  diffchange

  afterPod
}


install
