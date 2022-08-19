#!/bin/bash
#
# Unused variables left for readability
# shellcheck disable=SC2059,SC2162,2082,SC2034,2004
# changeLog
#  1. 重构了脚本
#  2. 添加一键安装功能
#  3. 添加了回滚功能
#版本信息
clear
build_date="20220810"
build_version="v2.0.0"

#当前时间 格式：2022-00-10 14:36:31

NOW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
#!/bin/bash

function log()
{
   echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}



#当前时间
#echo "=========== $(date) ==========="

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
message_info_tag="${color_sky_blue_start}[Info]    ${NOW_DATE} ${color_end}"
message_warning_tag="${color_yellow_start}[Warning] ${NOW_DATE} ${color_end}"
message_error_tag="${color_red_start}[Error]   ${NOW_DATE} ${color_end}"
message_success_tag="${color_green_start}[Success] ${NOW_DATE} ${color_end}"
message_fail_tag="${color_red_start}[Failed]  ${NOW_DATE} ${color_end}"

#功能、版本信息描述输出
function fun_show_version_info(){
echo -e "${color_green_start}
#############################################################
# Update OpenSSH Script for CentOS 
#
# Online automatic download and installation
#
# Version: ${build_version}
# BuildDate: ${build_date}
# Author: hyx@dotease.cn
#
#############################################################
${color_end}"

echo -e "${message_info_tag} 当前SSH版本：$(ssh -V 2>&1 | awk -F ',' '{print $1}')" 
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

#当前时间戳
var_now_timestamp=""
#是否root权限执行
var_is_root_execute=false

#是否force执行
var_is_force_execute=false

#当前网络是否通外网
var_is_online=false
var_check_online_url="mirrors.aliyun.com"
var_check_online_retry_times="3"

#检测系统版本
SYSTEM_VERSION=$(sed -r 's/.* ([0-9]+)\..*/\1/' /etc/redhat-release)

#==================函数====================


# ping地址是否通
function fun_ping() {
    if ping -c 1 "$1" >/dev/null; then
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
        echo -e "${message_info_tag} 正在尝试检测外网:ping ${var_check_online_url}${color_red_start}${color_end}"
        var_is_online=$(fun_ping ${var_check_online_url})
        if [[ ${var_is_online} = true ]]; then
        echo -e "${message_success_tag} 检测外网成功!"
            break
        else
        echo -e "${message_fail_tag} 外网不通，ping ${var_check_online_url} fail."
        fi
    done
    if [[ ${var_is_online} = false ]]; then
        echo -e "${message_error_tag} 检测当前无外网环境,重试${$var_check_online_retry_times}次ping ${var_check_online_url}都失败,程序终止执行."
        exit 1
    fi
}

# 检测root权限
function fun_check_root(){
    if [[ "$(id -u)" != "0" ]]; then
    echo -e "${message_error_tag} 当前用户不是ROOT，无法执行，退出脚本"
    exit 1
    else
        var_is_root_execute=true
    fi
}


#检测依赖包
function fun_check_dependencies_packages(){
    echo -e "${message_info_tag} 检测当前环境是否满足安装要求"
    PACKAGES_LIST="openssl openssl-devel zlib zlib-devel gcc gcc-c++"
    for package in $PACKAGES_LIST; do
    if [[ "$(rpm -q "$package" > /dev/null ; echo $?)" -ne "0" ]]; then
        #rpm -q "$package"
        echo -e "${message_fail_tag} $package 未安装"
        touch /tmp/.sshUpdate_error.temp 
      else
        echo -e "${message_success_tag} $package 已安装"
    fi
    sleep 0.8
  done
    if [ -f "/tmp/.sshUpdate_error.temp" ]; then
        rm /tmp/.sshUpdate_error.temp && echo ""
        #echo -e "${message_error_tag} 部分依赖包未安装！"
        echo "运行以下命令安装依赖包: yum install -y $PACKAGES_LIST wget"
        echo "" && exit 1
    fi

}

#检测tmp是否有openssh安装包
function fun_check_tmp_openssh_package(){
    if [ -f "/tmp/$openssh_package" ]; then
    echo -e "${color_green_start} 检查通过 ${color_end} /tmp/$openssh_package"
    sleep 0.8
    else
    echo -e "[${color_yellow_start}  /tmp/$openssh_package 安装包不存在${color_end}"
    fi
}


#执行安装组件
function fun_install_dependencies_packages(){
 fun_check_network && yum install -y openssl openssl-devel zlib zlib-devel gcc gcc-c++ wget telnet
}


function fun_check_os_support(){
    if [ "$(command -v rpm)" ]; then
        echo "" >/dev/null
    else
        echo "此脚本仅支持CentOS/RHEL, 当前系统暂未支持"
        exit 1
    fi
}

function fun_show_current_ssh_version(){
 echo "当前SSH版本: $SSH_VERSION"
}

function fun_show_current_os_version(){
 cat /etc/redhat-release
}

function fun_check_local_file(){
 echo -e "${message_info_tag} 检查 /tmp 目录是否有 OpenSSH 源码包"
 if [ -f "/tmp/$openssh_package" ]; then
        sleep 0.8
        echo -e "${message_info_tag} 发现 /tmp/$openssh_package 源码包"
    else
        sleep 0.8
        echo -e "${message_warning_tag} 源码包 /tmp/$openssh_package 不存在！"
        echo ""
        typeset -u DOWNLOAD
        read -p "是否从网络下载？[Y/N]: " DOWNLOAD
        if [[ $DOWNLOAD == "Y" ]]; then
            if command -v wget >/dev/null 2>&1; then
                sleep 0.8
                    fun_download_package
            else
                echo -e "${message_error_tag} wget 未安装, 无法下载, 请安装 wget! "
                exit 1
            fi
        elif [[ $DOWNLOAD == "N" ]]; then
        echo "" && echo -e "${message_info_tag} 用户退出程序！" && echo "" && exit 1
        else
        echo "" && echo -e "${message_warning_tag} 输入错误！" && echo "" && exit 1
        exit 1
        fi
 fi
}

function fun_define_version(){
 echo "请输入您要安装的 OpenSSH 版本(直接输入版本号如: 8.8, 默认为 9.0): "
 read -r REQUEST
 if [ ! "$REQUEST" ]; then
    echo >/dev/null
 else
    openssh_version=openssh-"$REQUEST"p1
    #echo "$REQUEST"
 fi
 openssh_package="$openssh_version".tar.gz
}


function fun_download_package(){
 fun_check_network && \
 wget -q https://mirrors.aliyun.com/pub/OpenBSD/OpenSSH/portable/"$openssh_package" -O /tmp/"$openssh_package" && \
 echo -e "${message_success_tag} 下载成功 " ||
 echo -e "${message_fail_tag}  下载失败" 
}

function fun_backup(){
 echo -e "${message_info_tag} 正在备份原 OpenSSH"
 mv /etc/ssh/ /etc/ssh.bak."$(date "+%Y%m%d")" >/dev/null 2>&1
 cp /usr/sbin/sshd /usr/sbin/sshd."$(date "+%Y%m%d")" >/dev/null 2>&1
 cp /usr/bin/ssh /usr/bin/ssh."$(date "+%Y%m%d")" >/dev/null 2>&1
 cp /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd.service."$(date "+%Y%m%d")" >/dev/null 2>&1
 cp /etc/init.d/sshd /etc/init.d/sshd."$(date "+%Y%m%d")" >/dev/null 2>&1
}

function compile_file(){
 sleep 0.8 && tar -zxf /tmp/"$openssh_package" -C /tmp/ && cd /tmp/"$openssh_version" || exit
 echo -e "${message_info_tag} 正在解压 OpenSSH 源码包"
 echo -e "${message_info_tag} 正在构建 Makefile,此过程可能需要1-2分钟"
 ./configure --sysconfdir=/etc/ssh --with-ssl-dir="$OPENSSL_DIR" >/dev/null
 echo -e "${message_info_tag} 正在编译......"
 make -j"$CORE" >/dev/null 2>&1 &&
 echo -e "${message_info_tag} 正在安装......" &&
 make install >/dev/null 2>&1
 echo -e "${message_info_tag} 安装完成"
 sed -i "/#PermitRootLogin prohibit-password/aPermitRootLogin yes" /etc/ssh/sshd_config
 echo -e "${message_info_tag} 修改配置文件, 允许root登录" && sleep 0.8
}

function try_old_configure(){
 echo -e "${message_info_tag} 尝试使用旧版配置文件启动程序"
 cp /etc/ssh/sshd_config /etc/ssh/sshd_config.newBackup
 cp /etc/ssh.bak."$(date "+%Y%m%d")"/sshd_config /etc/ssh/
    #if [ "$SYSTEM_VERSION" -eq "6" ]; then
}

function fun_autoStart(){
 echo -e "${message_info_tag} 设置 OpenSSH 开机启动"
 cp -a contrib/redhat/sshd.init /etc/init.d/sshd >/dev/null 2>&1
 cp -a contrib/redhat/sshd.pam /etc/pam.d/sshd.pam >/dev/null 2>&1
 chmod +x /etc/init.d/sshd
    if [ "$SYSTEM_VERSION" -eq "6" ]; then
        chkconfig --add sshd >/dev/null 2>&1
        chkconfig sshd on >/dev/null 2>&1
        /etc/init.d/sshd.init start >/dev/null 2>&1
        service sshd restart >/dev/null 2>&1
        sleep 1
        echo -e "${message_info_tag} 启动 OpenSSH"
        service sshd status >/dev/null 2>&1 && echo -e "${message_success_tag} OpenSSH 状态正常" || echo -e "${message_error_tag} OpenSSH 状态异常，请检查"
    elif [ "$SYSTEM_VERSION" -eq "7" ]; then
        systemctl daemon-reload >/dev/null 2>&1 && sleep 1
        chkconfig --add sshd >/dev/null 2>&1
        systemctl enable sshd >/dev/null 2>&1
        chkconfig sshd on >/dev/null 2>&1
        \mv /usr/lib/systemd/system/sshd.service /opt/ >/dev/null 2>&1
        \mv /usr/lib/systemd/system/sshd.socket /opt/ >/dev/null 2>&1
        /etc/init.d/sshd.init start >/dev/null 2>&1
        systemctl restart sshd >/dev/null 2>&1
        systemctl daemon-reload >/dev/null 2>&1
        sleep 1
        echo -e "${message_info_tag} 启动 OpenSSH"
        systemctl status sshd >/dev/null 2>&1 && echo -e "${message_success_tag} OpenSSH 状态正常" || echo -e "${message_error_tag} OpenSSH 状态异常，请检查"
    fi
}

function fun_replace_program(){
 echo -e "${message_info_tag} 替换 OpenSSH 版本"
 \mv /usr/local/sbin/sshd /usr/sbin/ >/dev/null && \mv /usr/local/bin/ssh /usr/bin >/dev/null
 \cp /tmp/"$openssh_version"/ssh-keygen /usr/bin/
 #echo -e "${message_info_tag} 当前 OpenSSH 版本：$(ssh -V)" 
}

function fun_remove_source_pacakge(){
 echo -e "${message_info_tag} 清理 /tmp/$openssh_version* " 
 rm -rf /tmp/"$openssh_version"* 
 echo -e "${message_info_tag} 当前 SSH 版本：$(ssh -V 2>&1 | awk -F ',' '{print $1}'
)"
}

function fun_rollback(){
 echo -e "${message_info_tag} 正在检测..."
 if [ -f "/usr/bin/ssh.$(date "+%Y%m%d")" ]; then
        sleep 1
        echo -e "${message_info_tag} 检测到 1 个历史版本"
        echo -e "${message_info_tag} 历史版本为：" && /usr/bin/ssh."$(date "+%Y%m%d")" -V && echo ""
    else
        sleep 0.5
        echo -e "${message_info_tag} 未检测到历史版本，脚本退出"
        exit 1
 fi
 typeset -u REQUEST
 read -p "确认回滚版本 [Y/N]: " REQUEST
 if [[ $REQUEST == "Y" ]]; then
    #回滚
    echo -e "${message_info_tag} 正在恢复配置文件" ; sleep 0.5
    rm -rf /etc/ssh
    mv /etc/ssh.bak."$(date "+%Y%m%d")" /etc/ssh/ >/dev/null 2>&1
    echo -e "${message_info_tag} 正在恢复 sshd 程序" ; sleep 0.5
    mv /usr/sbin/sshd."$(date "+%Y%m%d")" /usr/sbin/sshd  >/dev/null 2>&1
    echo -e "${message_info_tag} 正在恢复 ssh 客户端" ; sleep 0.5
    mv /usr/bin/ssh."$(date "+%Y%m%d")" /usr/bin/ssh  >/dev/null 2>&1
    echo -e "${message_info_tag} 正在恢复 自启文件" ; sleep 0.5
    mv /usr/lib/systemd/system/sshd.service."$(date "+%Y%m%d")" /usr/lib/systemd/system/sshd.service  >/dev/null 2>&1
    mv /etc/init.d/sshd."$(date "+%Y%m%d")" /etc/init.d/sshd >/dev/null 2>&1
    echo -e "${message_info_tag} 恢复完成，尝试启动 SSH" ; sleep 0.5
    if [ "$SYSTEM_VERSION" -eq "6" ]; then
        service sshd restart >/dev/null 2>&1
        sleep 1
        echo -e "${message_info_tag} 启动 OpenSSH" ; sleep 0.5
        service sshd status >/dev/null 2>&1 && echo -e "${message_success_tag} OpenSSH 状态正常" || echo -e "${message_error_tag} OpenSSH 状态异常，请检查"
    elif [ "$SYSTEM_VERSION" -eq "7" ]; then
        systemctl daemon-reload >/dev/null 2>&1 && sleep 1
        systemctl enable sshd >/dev/null 2>&1
        systemctl restart sshd >/dev/null 2>&1
        systemctl status sshd >/dev/null 2>&1 && echo -e "${message_success_tag} OpenSSH 状态正常" || echo -e "${message_error_tag} OpenSSH 状态异常，请检查"
    fi
  elif [[ $REQUEST == "N" ]]; then
    echo "" && echo -e "${message_info_tag} 用户退出程序！" && echo "" && exit 1
  else
    echo "" && echo -e "${message_warning_tag} 输入错误！" && echo "" && exit 1
    exit 1
 fi

}

#start=$(date +%s)
##end=$(date +%s)
#take=$((end - start))
#echo -e "${message_info_tag} 程序运行耗时：$take 秒！"

# 主入口1 
function main_fun_run(){
    fun_show_version_info
    fun_check_root
    fun_check_dependencies_packages
    fun_define_version
    fun_check_os_support
    fun_check_local_file
    fun_backup
    compile_file
    fun_replace_program
    fun_autoStart
    fun_remove_source_pacakge
    exit 0
}

# 主入口2
function main_fun_check(){
    fun_show_version_info
    fun_check_dependencies_packages
    exit 0
}

# 主入口3
function main_fun_restore_settings(){
    fun_rollback
    #..
    #..
    sleep 0.1
}

# 主入口4
function main_fun_force_run(){
    #..
    #..
    sleep 0.5
}


# 根据输入参数执行对应函数
case "$1" in
    "-run")
        main_fun_run
    ;;
    "-check")
        main_fun_check
    ;;
    "-restore")
        main_fun_restore_settings
    ;;
    "-force")
        main_fun_force_run
    ;;
    *)
 echo -e "${color_blue_start}===自动升级OpenSSH脚本===${color_end}
 可选参数 (Parameters):
 UpdateSSH_RHEL.sh -run             检测环境并执行脚本
 UpdateSSH_RHEL.sh -check           仅检测环境(不执行安装)
 UpdateSSH_RHEL.sh -restore         回滚版本(恢复升级前的版本及配置)
 UpdateSSH_RHEL.sh -force           一键安装，自动安装依赖(需联网)
        "
    ;;
esac

echo -e "${message_info_tag}选择需要执行的功能"
echo -e "\n 1.执行升级脚本 \n 2.仅检测环境 \n 3.回滚版本(恢复升级前的版本及配置) \n 4.一键安装，自动安装依赖（需联网） \n 0.退出 \n"
read -p "请输入你的选择（输入数字）:" run_function

if [[ "${run_function}" == "1" ]]; then
    main_fun_run
    elif [[ "${run_function}" == "2" ]]; then
    main_fun_check
    elif [[ "${run_function}" == "3" ]]; then
    main_fun_restore_settings
    elif [[ "${run_function}" == "4" ]]; then
    main_fun_force_run
 else
    exit 0
fi