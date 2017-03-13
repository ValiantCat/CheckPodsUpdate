
<!-- toc -->

<!-- index-menu -->


# 需求原因

>  做了半年的组件化了，原本的项目由一个集中式的仓库开发被拆分为几十个基础组件，还有各种业务组件。仓库在逻辑上分离也给开发和测试带来了很多好处。当然也有不好的地方。业务方的同事对这方面更为敏感，由于开发的时候壳工程有原来的依赖十几个第三方Pod变成了现在依赖将近上百个Pod，频繁的install 或者 update，偶尔会意外造成某些库更新，这些更新可能是不稳定的，而且QA由于不知道这些修改，会导致突然有些bug出现，有时候会造成不必要的沟(Si)通(Bi)。
> 所以业务方的同学提了一个模糊的需求: 我能不能在每次install 或者update的时候自动检测到第三方Pod的更新，来给我提示，让我重新check这些Pod是否真的需要更新或者是不稳定的版本。`之所以说是模糊的，可能确实由于我们确实也不太知道我们需要怎么做，只是有痛点。`
> 
> 不过既然有了痛点，就要去解决。先做出来一般之后在修改。

# 尝试方案

> 我收到这个需求的时候，也确实有点懵逼，因为可能最初只是一点抱怨，说的也不明确，我刚开始也没什么思路。不过仔细想了想之后发现，可以把需求整理为2个核心目标。

1. 检测更新
2. 通知开发者有变化 

##  检测更新

作为一个iOS开发者我们要熟悉我们使用的工具，我们知道Pod如何来绑定版本的变化，使用的是当前工作目录的`Podfile.lock`文件，那么我在每次Pod更新前，我用脚本去分析下新旧文件，如果更新了则是有库发送了变化，再去通知开发者。
说起来简单，不过我这种shell 0基础选手怎么办，当然是学了
这里找到了[shell30分钟入门教程](http://www.runoob.com/linux/linux-shell.html )
说起来30分钟不过我这种笨人学了3个小时才练习完，不过shell脚本确实非常实用，推荐读者去学习下，在平时的开发中确实能帮到自己。

学完shell之后，我写了个脚本要求开发者使用我的脚本进行Pod install 或者 update等。不能再直接终端执行这个命令 。

![install](http://ompeszjl2.bkt.clouddn.com/%E8%87%AA%E5%8A%A8%E6%A3%80%E6%B5%8B%E7%AC%AC%E4%B8%89%E6%96%B9Pod%E5%B0%8F%E5%B7%A5%E5%85%B7/1.png)
代码逻辑如下
```sh

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
```

###  备份逻辑

到这一步我们就可以去做备份功能了。
Q: 为什么备份？
A: 每次执行Pod命令 `CocoaPod`都会进行原地修改，设计到三个东西 `*.xcworkspace` `Podfile.lock` `Pods/` ，回忆一下以往执行命令的时候，你执行pod命令的时候可能还报过错，但是发现整个的几千个文件瞬间都发送变化了，真是非常恶心。有了备份之后我们还可以在pod执行错误的时候恢复这三个东西的原来面目，不用我们每次再用sourcetree去重置文件。

Pod 命令执行完有两种情况 
1. 执行成功   ----> 检测更新 --> 删除备份
2. 执行失败------> 恢复文件，删除备份--->并报错

下面是基本的代码逻辑
```sh
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
```

### 检测更新 

```sh
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
```


## 通知开发者

 目前我做的是直接打开文件来给开发者看


```sh

  open -a Atom     ${diffchangeFile}

  if [  $? != 0 ]
  then
    open -a Xcode ${diffchangeFile}
  fi

  if [  $? != 0 ]
  then
    open  ${diffchangeFile}
  fi

```


## 完整演示

这是一个失败的演示:

![checkErr](http://ompeszjl2.bkt.clouddn.com/%E8%87%AA%E5%8A%A8%E6%A3%80%E6%B5%8B%E7%AC%AC%E4%B8%89%E6%96%B9Pod%E5%B0%8F%E5%B7%A5%E5%85%B7/checkError.gif)

这是一个成功的演示

![checkSuccess](http://ompeszjl2.bkt.clouddn.com/%E8%87%AA%E5%8A%A8%E6%A3%80%E6%B5%8B%E7%AC%AC%E4%B8%89%E6%96%B9Pod%E5%B0%8F%E5%B7%A5%E5%85%B7/checkSuccss.gif)

## 后记

> 后面拿着给业务方的同学看了，业务方感叹效率，觉得做的很快，不过还有几点不足(其实就是不满意喽),。
1.  我们这么大的团队(30iOS 左右)靠开发者主动使用脚本这个约束并不是特别好，如果有新人入职不知道怎么办，有时候着急忘记了怎么办。
2. 开发者万一没有仔细看log'怎么办，我们需要一个留存的证据 ，比如邮件，这样在出bug的时候就嘿嘿嘿的甩锅给他喽。

后面的话和安卓的朋友一起沟通说可以放在server端去做，我们使用的CR平台是gerrit，gerrit能检测到开发者merge代码。可以在这个时候去做，检测 并且可以直接利用邮件系统发给开发组的全组同学，大大降低出现风险的机会。
不过作为一次学习的记录还是总结一下分享给大家。
[原文地址 ](https://www.valiantcat.cn/index.php/2017/03/13/30.html/)



