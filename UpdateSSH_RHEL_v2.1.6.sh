#!/bin/bash
#
# Unused variables left for readability
# shellcheck disable=SC2059,SC2162,2082,SC2034,2004,SC2120,SC2145,SC2116,SC2010,SC2002,SC2046

clear
build_date="20220818"
build_version="v2.1.6"

#当前时间 格式：2022-01-01 11:11:11
NOW_DATE=$(date "+%Y-%m-%d %H:%M:%S")

function LOG_DATE()
{
   echo "$(date '+%Y-%m-%d %H:%M:%S') $@"
}

#定义字体颜色
color_black_start="\033[30m"
color_red_start="\033[31m"
color_green_start="\033[32m"
color_yellow_start="\033[33m"
color_blue_start="\033[34m"
color_purple_start="\033[35m"
color_sky_blue_start="\033[36m"
color_white_start="\033[37m"
color_end="\033[0m"
#提示信息级别定义
message_info_tag(){
    echo -e "${color_sky_blue_start}[Info]    $(date '+%Y-%m-%d %H:%M:%S') ${color_end} $@"
}
message_warning_tag(){
    echo -e "${color_yellow_start}[Warning] $(date '+%Y-%m-%d %H:%M:%S') ${color_end} $@"
}
message_error_tag(){
    echo -e "${color_red_start}[Error]   $(date '+%Y-%m-%d %H:%M:%S') ${color_end} $@"
}
message_success_tag(){
    echo -e "${color_green_start}[Success] $(date '+%Y-%m-%d %H:%M:%S') ${color_end} $@"
}
message_fail_tag(){
    echo -e "${color_red_start}[Failed]  $(date '+%Y-%m-%d %H:%M:%S') ${color_end} $@"
}

#功能、版本信息描述输出
function fun_show_version_info(){
    echo -e "${color_green_start}
    ##################################################################################################
    # Update OpenSSH for CentOS 6/7                                                                  
    #                                                                                                
    # Version: ${build_version}                                                                      
    # BuildDate: ${build_date}                                                                       
    # Author: hyx@dotease.cn                                                                         
    # 脚本说明文档 : https://www.notion.so/poov/UpdateSSH-b0fe6f9512624485b6346432d36b516e           
    # 可选脚本运行参数 (Options):                                                                         
    # UpdateSSH_RHEL_${build_version}.sh -run             检测环境并执行脚本                                                      
    # UpdateSSH_RHEL_${build_version}.sh -check           仅检测环境 (不执行安装)                      
    # UpdateSSH_RHEL_${build_version}.sh -rollback        回滚版本 (恢复升级前的版本及配置)             
    # UpdateSSH_RHEL_${build_version}.sh -force           一键安装，自动安装依赖 (需联网及 yum 可用)    
    # UpdateSSH_RHEL_${build_version}.sh -changelog       查看更新日志                                
    ##################################################################################################
    ${color_end}"
    echo -e "$(message_info_tag) 当前SSH版本：$(ssh -V 2>&1 | awk -F ',' '{print $1}')"
    SSH_VERSION=$(ssh -V 2>&1 | awk -F ',' '{print $1}')
}

#全局变量定义

#OPENSSL目录
OPENSSL_DIR=$(openssl version -a | grep OPENSSLDIR | awk '{print $2}' | sed s/\"//g)

#日志储存目录
LOG_FILE_PATH="/tmp/"
# 日志文件名
LOG_FILE_NAME="log-info.log"

#openSSH默认安装包定义
openssh_version="openssh-9.0p1"

#升级所需的最低的 openssl 版本
OPENSSL_REQUIRE_VERSION="1.0.1"

#当前时间戳
var_now_timestamp=""

#是否root权限执行
var_is_root_execute=false

#是否force执行
var_is_force_execute=false

#默认是否检测模式
var_check_flag=false

#当前网络是否通外网
var_is_online=false
var_check_online_url="mirrors.aliyun.com"
var_check_online_retry_times="3"

#检测系统版本
SYSTEM_VERSION=$(sed -r 's/.* ([0-9]+)\..*/\1/' /etc/redhat-release)

#默认 非强制安装
INSTALL_FORCE=false

#预清理，避免误报
rm -rf /tmp/.sshUpdate_error.flag > /dev/null 2>&1
rm -rf /tmp/.openssh_old_Version  > /dev/null 2>&1

#=================更新日志=====================================
main_fun_changelog(){
echo -e "${color_green_start}
ChangeLog
    2.1.6   (2022.8.19)
        优化 yum 安装依赖包的步骤。

    2.1.5   (2022.8.18)
       增加了检测 openssl 的功能，低于要求版本将无法升级
       自 SSH 7.4 起, 要求 openssl 版本不得低于 1.0.1 

    2.1.4   (2022.8.17)
       编译时添加 PAM 模块
       修复了在 CentOS 6.8 版本中的回滚操作后，有概率重启SSH失败

    2.1.3   (2022.8.16)
        修复部分异常处理

    2.1.2   (2022.8.14)
        增加了源码包解压验证，识别源码包是否受损

    2.1.1   (2022.8.12)   
        发现了SELinux 会导致回滚失败，增加了 SELinux 检测

2.0     (2022.8.10)
       重构了脚本
       添加一键安装功能
       添加了回滚功能

    1.4.7   (2022.6.7)
        优化多线程编译
        
    1.4.6   (2022.6.1)
        优化操作系统版本获取方式

${color_end}"
exit 0
}
#==================函数====================

# ping地址是否通
function fun_ping() {
    if ping -c 1 "$1" >/dev/null 2>&1; then
        # ping通
        echo true
    else
        # 不通
        echo false
    fi
}

#检测是否通外网
function fun_check_network(){
    for((i=1;i<=$var_check_online_retry_times;i++)); do
        echo -e "$(message_info_tag) 检测是否能连接互联网: ping ${var_check_online_url}${color_red_start}${color_end}"
        var_is_online=$(fun_ping ${var_check_online_url})
        if [[ ${var_is_online} = true ]]; then
        echo -e "$(message_success_tag) 连接互联网成功"
            break
        else
        echo -e "$(message_fail_tag) 无法连接互联网，ping ${var_check_online_url} 失败."
        fi
    done
    if [[ ${var_is_online} = false ]]; then
        echo -e "$(message_error_tag) 本机无法上网，程序终止执行."
        exit 1
    fi
}

# 检测root权限
function fun_check_root(){
    if [[ "$(id -u)" != "0" ]]; then
    echo -e "$(message_error_tag) 当前用户不是 root，无法执行"
    exit 1
    else
        var_is_root_execute=true
    fi
}

#检测依赖包
function fun_check_dependencies_packages(){
    echo -e "$(message_info_tag) 检测当前环境是否满足安装要求"
    PACKAGES_LIST="openssl openssl-devel zlib zlib-devel gcc gcc-c++ pam-devel"
    rm -rf /tmp/.sshUpdate_error.flag >/dev/null 2>&1
    for package in $PACKAGES_LIST; do
        if [[ "$(rpm -q "$package" > /dev/null ; echo $?)" -ne "0" ]]; then
            #rpm -q "$package"
            echo -e "$(message_fail_tag) 未安装 $package"
            echo "$package" >> /tmp/.sshUpdate_error.flag
            #touch /tmp/.sshUpdate_error.flag
         else
            echo -e "$(message_success_tag) 已安装 $package"
        fi
        sleep 0.5
    done
    if [ -f "/tmp/.sshUpdate_error.flag" ]; then
            echo -e "$(message_error_tag) 部分依赖包未安装，无法升级"
            if [[ "$var_check_flag" = "false" ]];then
            fun_install_dependencies_packages
            fi
     else
        echo -e "$(message_success_tag) 满足安装要求"
    fi
}

#检测当前 openssl 版本
function fun_check_openssl_version(){
    CURRENT_VERSION=$(openssl version | awk '{print $2}' | cut -b -6)
    echo -e "$(message_info_tag) 当前 openssl 版本为：$CURRENT_VERSION"
    #最低要求的版本 > 当前版本,则证明版本不满足要求
    if [[ "$OPENSSL_REQUIRE_VERSION" > "$CURRENT_VERSION" ]];then
        echo -e "$(message_error_tag) 当前 openssl 版本不满足升级要求, openssl 版本最低要求为 $OPENSSL_REQUIRE_VERSION"
        exit 1
    fi
}

#执行安装组件
function fun_install_dependencies_packages(){
 uninstall_package=$(cat /tmp/.sshUpdate_error.flag | tr '\n' ' ')
 if [[ $INSTALL_FORCE = 'false' ]];then
            typeset -u REQUEST
            stty  erase  ^h
            read -p "是否使用 yum 安装以上依赖包 [Y/N]: " REQUEST
            if [[ $REQUEST == "Y" ]]; then
                echo -e "$(message_info_tag) 正在安装依赖包..."
                yum install -y $uninstall_package wget telnet
                INSTALL_STATUS=$(echo $?)
                if [ "$INSTALL_STATUS" -eq "0" ];then
                    fun_check_dependencies_packages
                  else
                    echo -e "$(message_error_tag) 自动安装失败，yum 不可用"
                    exit 1
                fi
              else
                
                echo -e "$(message_info_tag) 运行以下命令安装依赖包: yum install -y $uninstall_package wget"
                echo "" && exit 1
            fi
    elif [[ $INSTALL_FORCE = 'true' ]];then
            #fun_check_network
            echo -e "$(message_info_tag) 正在安装依赖包..."
            yum install -y $uninstall_package
            #yum install -y openssl openssl-devel zlib zlib-devel gcc gcc-c++ pam-devel wget telnet
            INSTALL_STATUS=$(echo $?)
            if [ "$INSTALL_STATUS" -eq "0" ];then
                fun_check_dependencies_packages
              else
                echo -e "$(message_error_tag) 自动安装失败，yum 安装异常"
                exit 1
            fi
 fi
}

#检测是不是红帽系
function fun_check_os_support(){
    if [ "$(command -v rpm)" ]; then
        echo "" >/dev/null
    else
        echo "此脚本仅支持CentOS/RHEL, 当前系统暂未支持"
        exit 1
    fi
}

#显示当前 SSH 版本
function fun_show_current_ssh_version(){
 echo "当前SSH版本: $SSH_VERSION"
}

#显示当前系统版本
function fun_show_current_os_version(){
 cat /etc/redhat-release
}

#定义需要升级的版本
function fun_define_version(){
 stty  erase  ^h
 read -p "请输入您要安装的 OpenSSH 版本(直接输入版本号如: 8.8, 默认为 9.0): " REQUEST
 if [ ! "$REQUEST" ]; then
    echo >/dev/null
 else
    openssh_version=openssh-"$REQUEST"p1
    #echo "$REQUEST"
 fi
}

#检查本地 /tmp 目录有没有源码包
function fun_check_local_file(){
 echo -e "$(message_info_tag) 检查 /tmp 目录是否有 OpenSSH 源码包"
 #定义版本
 openssh_package="$openssh_version".tar.gz
 if [ -f "/tmp/$openssh_package" ]; then
        sleep 0.8
        echo -e "$(message_info_tag) 发现 /tmp/$openssh_package 源码包"
    else
        sleep 0.8
        echo -e "$(message_warning_tag) 源码包 /tmp/$openssh_package 不存在！"
        if [ ! "$DOWNLOAD" ]; then
            typeset -u DOWNLOAD
            stty  erase  ^h
            read -p "是否从网络下载源码包并安装？[Y/N]: " DOWNLOAD
            if [[ $DOWNLOAD == "Y" ]]; then
                if command -v wget >/dev/null 2>&1; then
                    sleep 0.8
                    fun_download_package
                  else
                    echo -e "$(message_error_tag) wget 未安装, 无法下载, 请安装 wget "
                    exit 1
                fi
              elif [[ $DOWNLOAD == "N" ]]; then
                echo "" && echo -e "$(message_info_tag) 用户退出" && echo "" && exit 1
              else
                echo "" && echo -e "$(message_warning_tag) 输入错误" && echo "" && exit 1
                exit 1
            fi
         else
            fun_download_package
        fi
 fi
}

#从阿里云下载源码包
function fun_download_package(){
 fun_check_network
 cd /tmp || exit 
 wget -q https://mirrors.aliyun.com/pub/OpenBSD/OpenSSH/portable/"$openssh_package"
    if [ -f "/tmp/$openssh_package" ]; then
        echo -e "$(message_success_tag) 下载源码包成功 "
      else
        echo -e "$(message_fail_tag) 下载源码包失败"
        exit 1
    fi
}

#备份原来的 OpenSSH
function fun_backup(){
 echo -e "$(message_info_tag) 备份当前 OpenSSH"
 mv /etc/ssh/ /etc/ssh.bak."$(date "+%Y%m%d%H%M").$SSH_VERSION" >/dev/null 2>&1
 cp /usr/sbin/sshd /usr/sbin/sshd."$(date "+%Y%m%d%H%M").$SSH_VERSION" >/dev/null 2>&1
 cp /usr/bin/ssh /usr/bin/ssh."$(date "+%Y%m%d%H%M").$SSH_VERSION" >/dev/null 2>&1
 cp /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd.service."$(date "+%Y%m%d%H%M").$SSH_VERSION" >/dev/null 2>&1
 cp /etc/init.d/sshd /etc/init.d/sshd."$(date "+%Y%m%d%H%M").$SSH_VERSION" >/dev/null 2>&1
}

#编译文件
function compile_file(){
 tar -zxf /tmp/"$openssh_package" -C /tmp/ >/dev/null 2>&1
 if [  ! -d "/tmp/$openssh_version" ];then
        echo -e "$(message_fail_tag) 解压失败，请检查源码包或重新上传源码包"
        exit 1
    else
        echo -e "$(message_info_tag) 解压成功源码包成功"
 fi
 cd /tmp/"$openssh_version" || exit
 fun_backup
 echo -e "$(message_info_tag) 构建 Makefile. 请稍候"
 ./configure --sysconfdir=/etc/ssh --with-ssl-dir="$OPENSSL_DIR" --with-pam >/dev/null
 echo -e "$(message_info_tag) 正在编译"
 make -j"$CORE" >/dev/null 2>&1 &&
 echo -e "$(message_info_tag) 正在安装" &&
 make install >/dev/null 2>&1 
 echo -e "$(message_success_tag) 安装完成"
 sed -i "/#PermitRootLogin prohibit-password/aPermitRootLogin yes" /etc/ssh/sshd_config
 echo -e "$(message_info_tag) 修改配置文件, 允许 root 登录" && sleep 0.8
}

#尝试使用旧的 OpenSSH 配置文件启动
function try_old_configure(){
 echo -e "$(message_info_tag) 尝试使用旧版配置文件启动程序"
 #先备份新的sshd配置文件
 cp /etc/ssh/sshd_config /etc/ssh/sshd_config.newBackup
 #恢复旧的配置文件
 cp /etc/ssh.bak."$(date "+%Y%m%d")"/sshd_config /etc/ssh/
    if [ "$SYSTEM_VERSION" -eq "6" ]; then
        service sshd restart >/dev/null 2>&1
        service sshd status >/dev/null 2>&1
        STATUS=$(echo $?)
        if [ "$STATUS" -eq 0 ];then
            echo -e "$(message_success_tag) 使用旧配置启动正常"
          else
            echo -e "$(message_error_tag) 使用旧配置启动异常，恢复新配置文件"
            mv /etc/ssh/sshd_config.newBackup /etc/ssh/sshd_config
            service sshd restart >/dev/null 2>&1 ;sleep 1
            service sshd status >/dev/null 2>&1 && echo -e "$(message_success_tag) OpenSSH 状态正常" || echo -e "$(message_error_tag) OpenSSH 状态异常，请检查"
        fi
     elif [ "$SYSTEM_VERSION" -eq "7" ]; then
        systemctl restart sshd >/dev/null 2>&1
                STATUS=$(echo $?)
        if [ "$STATUS" -eq 0 ];then
            echo -e "$(message_success_tag) 使用旧配置启动正常"
          else
            echo -e "$(message_error_tag) 使用旧配置启动异常，恢复新配置文件"
            mv /etc/ssh/sshd_config.newBackup /etc/ssh/sshd_config
            systemctl restart sshd >/dev/null 2>&1 ; sleep 1
            systemctl status sshd >/dev/null 2>&1 && echo -e "$(message_success_tag) OpenSSH 状态正常" || echo -e "$(message_error_tag) OpenSSH 状态异常，请检查"
    fi  fi
}

#配置 OpenSSH 开机自启
function fun_autoStart(){
 echo -e "$(message_info_tag) 设置 OpenSSH 开机启动"
 cp -a contrib/redhat/sshd.init /etc/init.d/sshd >/dev/null 2>&1
 cp -a contrib/redhat/sshd.pam /etc/pam.d/sshd.pam >/dev/null 2>&1
 chmod +x /etc/init.d/sshd
    if [ "$SYSTEM_VERSION" -eq "6" ]; then
        chkconfig --add sshd >/dev/null 2>&1
        chkconfig sshd on >/dev/null 2>&1
        /etc/init.d/sshd.init start >/dev/null 2>&1
        service sshd restart >/dev/null 2>&1
        sleep 1
        echo -e "$(message_info_tag) 启动 OpenSSH"
        service sshd status >/dev/null 2>&1 && echo -e "$(message_success_tag) OpenSSH 状态正常" || echo -e "$(message_error_tag) OpenSSH 状态异常，请检查"
    elif [ "$SYSTEM_VERSION" -eq "7" ]; then
        systemctl daemon-reload >/dev/null 2>&1 && sleep 1
        chkconfig --add sshd >/dev/null 2>&1
        systemctl enable sshd >/dev/null 2>&1
        chkconfig sshd on >/dev/null 2>&1
        \mv /usr/lib/systemd/system/sshd.service /opt/ >/dev/null 2>&1
        \mv /usr/lib/systemd/system/sshd.socket /opt/ >/dev/null 2>&1
        /etc/init.d/sshd.init start >/dev/null 2>&1
        systemctl restart sshd >/dev/null 2>&1
        systemctl daemon-reload >/dev/null 2>&1 ; sleep 1
        systemctl restart sshd >/dev/null 2>&1
        sleep 1
        echo -e "$(message_info_tag) 启动 OpenSSH"
        systemctl status sshd >/dev/null 2>&1 && echo -e "$(message_success_tag) OpenSSH 状态正常" || echo -e "$(message_error_tag) OpenSSH 状态异常，请检查"
    fi
}

#使用新版本 OpenSSH 替换旧版本
function fun_replace_program(){
 echo -e "$(message_info_tag) 替换 OpenSSH 版本"
 \mv /usr/local/sbin/sshd /usr/sbin/ >/dev/null && \mv /usr/local/bin/ssh /usr/bin >/dev/null
 \cp /tmp/"$openssh_version"/ssh-keygen /usr/bin/
 #echo -e "$(message_info_tag) 当前 OpenSSH 版本：$(ssh -V)"
}

#清理 /tmp 目录的源码包
function fun_remove_source_pacakge(){
 echo -e "$(message_info_tag) 清理 /tmp/$openssh_version* "
 rm -rf /tmp/"$openssh_version"*
 echo -e "$(message_info_tag) 当前 SSH 版本：$(ssh -V 2>&1 | awk -F ',' '{print $1}')"
 echo " 
 Update Complete!
  "
}

#回滚到旧的版本
function rollback_check_old_version(){
 echo -e "$(message_info_tag) 检测是否存在备份记录..."
 ls /usr/sbin | grep "sshd.[0-9].*OpenSSH.*" | awk -F '.' '{print $2"."$3"."$4}' > /tmp/.openssh_old_Version
 if [  "$(cat /tmp/.openssh_old_Version | wc -l)" -ne 0 ]; then
        sleep 1
        n=1
        echo -e "$(message_info_tag) 检测到 $(cat /tmp/.openssh_old_Version | wc -l) 个备份记录"
        echo ""
        while read line
            do
                echo "  $n. $line"
                n=$((n+1))
        done < /tmp/.openssh_old_Version
        echo ""
    else
        sleep 0.5
        echo -e "$(message_info_tag) 未检测到历史版本，脚本退出"
        exit 1
 fi
}

#检查 SELinux 是否关闭
function check_selinux(){
 #不关闭SELinux会导致无法启动
 SELINUX_STATUS=$(getenforce)
 SELINUX_CONFIG=$(cat /etc/selinux/config  | grep -v "^#" | grep SELINUX= |awk -F '=' '{print $2}')
 if [ "$SELINUX_STATUS" == 'Enforcing' ];then
    echo -e "$(message_error_tag) SELinux 未关闭，建议关闭SELinux，否则可能导致启动出错！"
    exit 1
 fi
 if [ "$SELINUX_CONFIG" == 'enforcing' ];then
    echo -e "$(message_warning_tag) SELinux 为临时关闭，建议永久关闭！" 
 fi
}

function rollback_input_version(){
 stty  erase  ^h
 read -p "需要恢复到哪个版本？(输入数字) " NUMBER
    #判断输入的是否为数字
    if [ -n "$(echo "$NUMBER" | sed -n "/^[0-9]\+$/p")" ];then
        echo "" > /dev/null
      else
        echo -e "$(message_error_tag) 输入错误，请输入正确的数字"
        exit 1
    fi
    #输入 0 就退出
    if [ "$NUMBER" == '0' ];then
        echo -e "$(message_error_tag) 输入错误，请输入正确的数字"
        exit 1
    fi
    #判断要恢复的版本是否存在
    cat /tmp/.openssh_old_Version  | head -"$NUMBER" | tail -1 > /dev/null 2>&1
    if [ "$NUMBER" -le $(cat /tmp/.openssh_old_Version | wc -l) ];then
        ROLLBACK_VERSION=$(cat /tmp/.openssh_old_Version  | head -"$NUMBER" | tail -1)
      else
        echo -e "$(message_error_tag) 输入错误，请输入正确的数字"
        exit 1
    fi
}

function fun_rollback_action(){
    #开始回滚
    #if [ "$SYSTEM_VERSION" -eq "6" ]; then
    #    service sshd stop >/dev/null 2>&1
    #elif [ "$SYSTEM_VERSION" -eq "7" ]; then
    #    systemctl stop sshd >/dev/null 2>&1
    #fi
    echo -e "$(message_info_tag) 正在恢复配置文件" ; sleep 0.5
    rm -rf /etc/ssh
    mv /etc/ssh.bak."$ROLLBACK_VERSION" /etc/ssh >/dev/null 2>&1

    echo -e "$(message_info_tag) 正在恢复 sshd 程序" ; sleep 0.5
    mv /usr/sbin/sshd."$ROLLBACK_VERSION" /usr/sbin/sshd  >/dev/null 2>&1

    echo -e "$(message_info_tag) 正在恢复 ssh 客户端" ; sleep 0.5
    mv /usr/bin/ssh."$ROLLBACK_VERSION" /usr/bin/ssh  >/dev/null 2>&1

    echo -e "$(message_info_tag) 正在恢复 自启文件" ; sleep 0.5
    mv /usr/lib/systemd/system/sshd.service."$ROLLBACK_VERSION" /usr/lib/systemd/system/sshd.service  >/dev/null 2>&1
    mv /etc/init.d/sshd."$ROLLBACK_VERSION" /etc/init.d/sshd >/dev/null 2>&1

    echo -e "$(message_info_tag) 恢复完成，尝试启动 SSH" ; sleep 1
    if [ "$SYSTEM_VERSION" -eq "6" ]; then
        service sshd restart >/dev/null 2>&1
        sleep 1
        echo -e "$(message_info_tag) 启动 OpenSSH" ; sleep 0.5
        service sshd status >/dev/null 2>&1 && echo -e "$(message_success_tag) OpenSSH 启动正常" || echo -e "$(message_error_tag) OpenSSH 状态异常，请检查"
        echo -e "$(message_info_tag) 当前SSH版本：$(ssh -V 2>&1 | awk -F ',' '{print $1}')"
        exit 0
    elif [ "$SYSTEM_VERSION" -eq "7" ]; then
        systemctl daemon-reload >/dev/null 2>&1 && sleep 1
        systemctl restart sshd >/dev/null 2>&1
        systemctl status sshd >/dev/null 2>&1 && echo -e "$(message_success_tag) OpenSSH 启动正常" || echo -e "$(message_error_tag) OpenSSH 状态异常，请检查"
        echo -e "$(message_info_tag) 当前SSH版本：$(ssh -V 2>&1 | awk -F ',' '{print $1}')"
        exit 0
    fi
}

#start=$(date +%s)
##end=$(date +%s)
#take=$((end - start))
#echo -e "$(message_info_tag) 程序运行耗时：$take 秒！"

# 主入口1
function main_fun_run(){
    fun_show_version_info
    fun_check_root
    check_selinux
    fun_check_openssl_version
    fun_check_dependencies_packages
    fun_define_version
    fun_check_os_support
    fun_check_local_file
    compile_file
    fun_replace_program
    fun_autoStart
    fun_remove_source_pacakge
    exit 0
}

# 主入口2
function main_fun_check(){
    var_check_flag=ture
    fun_show_version_info
    fun_check_root
    fun_check_os_support
    check_selinux
    fun_check_openssl_version
    fun_check_dependencies_packages
    exit 0
}

# 主入口3
function main_fun_rollback(){
    check_selinux
    rollback_check_old_version
    rollback_input_version
    fun_rollback_action
}

# 主入口4
function main_fun_force_run(){
    DOWNLOAD=true
    INSTALL_FORCE=true
    fun_show_version_info
    fun_check_root
    check_selinux
    fun_check_openssl_version
    fun_check_dependencies_packages
    fun_check_os_support
    fun_check_local_file
    compile_file
    fun_replace_program
    fun_autoStart
    fun_remove_source_pacakge
    exit 0
}

# 根据输入参数执行对应函数
case "$1" in
    "-run")
        main_fun_run
    ;;
    "-check")
        main_fun_check
    ;;
    "-rollback")
        main_fun_rollback
    ;;
    "-force")
        main_fun_force_run
    ;;
    "-changelog")
        main_fun_changelog
    ;;
    *)
    ;;
esac

#echo -e "$(message_info_tag)当前OpenSSH最新版本为：$(curl -s https://mirrors.aliyun.com/pub/OpenBSD/OpenSSH/portable/README |head -1 | awk '{print $2}' | awk -F '#' '{print $2}')"
echo -e "$(message_info_tag)选择需要执行的功能"
echo -e "\n   1.开始升级 \n   2.检测环境 (检查当前环境是否满足安装要求) \n   3.回滚版本 (恢复以前的版本及配置) \n   7.一键安装 (需要联网且确保 yum 可用) \n   0.退出 \n"
stty  erase  ^h
read -p "请输入你的选择（输入数字）:" run_function

if [[ "${run_function}" == "1" ]]; then
    main_fun_run
    elif [[ "${run_function}" == "2" ]]; then
    main_fun_check
    elif [[ "${run_function}" == "3" ]]; then
    main_fun_rollback
    elif [[ "${run_function}" == "7" ]]; then
    main_fun_force_run
 else
    exit 0
fi