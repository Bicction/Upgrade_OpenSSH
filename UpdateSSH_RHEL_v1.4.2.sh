#!/bin/bash
#-----------------------------------
# Hou hyx@dotease.cn
# date 2022.6.7
# 2022.6.1 修改系统版本获取方式
# 2022.6.4 优化多线程编译
#
#默认SSH压缩包名称
openssh_version="openssh-9.0p1"
typeset -u REQUEST && typeset -u DOWNLOAD
SYSTEM_VERSION=$(sed -r 's/.* ([0-9]+)\..*/\1/' /etc/redhat-release)
CORE="$(grep -c "cpu cores" /proc/cpuinfo)"
echo "请输入您要安装的 OpenSSH 版本(直接输入版本号如: 8.8, 默认为 9.0): "
read -r REQUEST
if [ ! "$REQUEST" ]; then
    echo >/dev/null
else
    openssh_version=openssh-"$REQUEST"p1
    #echo "$REQUEST"
fi
openssh_package="$openssh_version".tar.gz
#检查函数
CHECK() {
    #检查系统是否符合要求
    if [ "$(command -v rpm)" ]; then
        echo "" >/dev/null
    else
        echo "此脚本仅支持CentOS/RHEL, 当前系统暂未支持"
        exit 1
    fi
    echo ""
    echo "当前SSH版本:  "
    ssh -V
    echo ""
    echo "当前系统版本: "
    cat /etc/redhat-release
    echo ""
    #检查依赖包是否安装
    LIST="openssl openssl-devel zlib zlib-devel gcc gcc-c++"
    for package in $LIST; do
        sleep 0.8
        VALUE=$(
            rpm -q "$package" >/dev/null
            echo $?
        )
        VERSION=$(rpm -q "$package" | head -1)
        if [[ $VALUE -eq "0" ]]; then
            echo -e "[\033[32m 检查通过 \033[0m] $VERSION"
        else
            echo -e "[\033[31m 检查失败 \033[0m] $package: 不存在"
            touch /tmp/.sshUpdate_error.temp
        fi
    done
    if [ -f "/tmp/.sshUpdate_error.temp" ]; then
        rm /tmp/.sshUpdate_error.temp && echo ""
        echo -e "\033[31m部分依赖包未安装, 退出程序\033[0m"
        echo "运行以下命令安装依赖包: yum install -y $LIST"
        echo "" && exit 1
    fi
    #检查SSH安装包是否存在
    if [ -f "/tmp/$openssh_package" ]; then
        sleep 0.8
        echo -e "[\033[32m 检查通过 \033[0m] /tmp/$openssh_package"
    else
        sleep 0.8
        echo -e "[\033[33m Warning \033[0m]  /tmp/$openssh_package 安装包不存在"
        echo -e "[\033[33m Warning \033[0m]  下载地址: https://mirrors.aliyun.com/pub/OpenBSD/OpenSSH/portable/$openssh_package \033[0m"
        echo -e "[\033[33m Warning \033[0m]  请将 OpenSSH 安装包($openssh_package) 上传到 /tmp 目录下, 或尝试从网络下载 \033[0m"
        echo "" && sleep 0.8
        echo "是否从网络下载？[Y/N]: "
        read -r DOWNLOAD
        #从阿里云下载安装包
        if [[ $DOWNLOAD == "Y" ]]; then
            if command -v wget >/dev/null 2>&1; then
                sleep 0.8
                echo -e "[\033[34mInformation\033[0m] 正在检测网络"
                ping mirrors.aliyun.com -c 4 >/dev/null 2>&1
                if [[ $(echo $?) -eq "0" ]]; then
                    echo -e "[\033[34mInformation\033[0m] 网络连接正常"
                else
                    echo -e "[\033[31m Error  \033[0m]    网络异常，请手动访问链接进行下载: https://mirrors.aliyun.com/pub/OpenBSD/OpenSSH/portable/$openssh_package" && sleep 2
                fi
                wget -q https://mirrors.aliyun.com/pub/OpenBSD/OpenSSH/portable/"$openssh_package"
                mv "$openssh_package" /tmp >/dev/null 2>&1
                if [ -f "/tmp/$openssh_package" ]; then
                    echo -e "[\033[34mInformation\033[0m] 下载成功" && sleep 0.8
                    echo -e "[\033[34mInformation\033[0m] 安装包 $openssh_package 已移动至 /tmp"
                else
                    echo -e "[\033[31m Error  \033[0m]    下载失败，程序退出"
                    sleep 1
                    exit 2
                fi
            else
                echo ""
                echo -e "[\033[31m  Error  \033[0m] wget 未安装, 无法下载, 请安装 wget! "
                sleep 0.8
                echo -e "[\033[31m  Error  \033[0m] 安装 wget 命令: yum install -y wget"
                echo -e "[\033[31m  Error  \033[0m] 程序退出"
                echo "" && sleep 0.8 && exit 1
            fi
        elif [[ $DOWNLOAD == "N" ]]; then
            echo "" && echo -e "[\033[34mInformation\033[0m] 退出程序！" && echo "" && exit 1
        fi
    fi
}
#升级函数
RUN() {
    start=$(date +%s)
    #确定openssl位置
    sleep 0.8 && OPENSSL_DIR=$(openssl version -a | grep OPENSSLDIR | awk '{print $2}' | sed s/\"//g)
    echo "" && sleep 0.8
    mv /etc/ssh/ /etc/ssh.bak."$(date "+%Y%m%d")" >/dev/null 2>&1
    cp /usr/sbin/sshd /usr/sbin/sshd."$(date "+%Y%m%d")" >/dev/null 2>&1
    cp /usr/bin/ssh /usr/bin/ssh."$(date "+%Y%m%d")" >/dev/null 2>&1
    cp /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd.service."$(date "+%Y%m%d")" >/dev/null 2>&1
    cp /etc/init.d/sshd /etc/init.d/sshd."$(date "+%Y%m%d")" >/dev/null 2>&1
    echo -e "[\033[34mInformation\033[0m] 正在备份原 OpenSSH"
    sleep 0.8 && tar -zxf /tmp/"$openssh_package" -C /tmp/ && cd /tmp/"$openssh_version" || exit
    echo -e "[\033[34mInformation\033[0m] 正在解压新 OpenSSH"
    echo -e "[\033[34mInformation\033[0m] 正在构建 Makefile, 请等待"
    ./configure --sysconfdir=/etc/ssh --with-ssl-dir="$OPENSSL_DIR" >/dev/null
    echo -e "[\033[34mInformation\033[0m] 正在编译......"
    make -j"$CORE" >/dev/null 2>&1 &&
        echo -e "[\033[34mInformation\033[0m] 正在安装......" &&
        make install >/dev/null 2>&1
    echo -e "[\033[34mInformation\033[0m] 安装完成"
    sleep 0.8 && sed -i "/#PermitRootLogin prohibit-password/aPermitRootLogin yes" /etc/ssh/sshd_config
    echo -e "[\033[34mInformation\033[0m] 修改配置文件, 允许root登录" && sleep 0.8
    \mv /usr/local/sbin/sshd /usr/sbin/ >/dev/null && \mv /usr/local/bin/ssh /usr/bin >/dev/null
    \cp /tmp/"$openssh_version"/ssh-keygen /usr/bin/
    echo -e "[\033[34mInformation\033[0m] 替换 OpenSSH 版本"
    #sleep 0.8
    if [ "$SYSTEM_VERSION" -eq "6" ]; then
        echo -e "[\033[34mInformation\033[0m] 设置 OpenSSH 开机启动"
        cp -a contrib/redhat/sshd.init /etc/init.d/sshd >/dev/null 2>&1
        cp -a contrib/redhat/sshd.pam /etc/pam.d/sshd.pam >/dev/null 2>&1
        chmod +x /etc/init.d/sshd
        chkconfig --add sshd >/dev/null 2>&1
        chkconfig sshd on >/dev/null 2>&1
        /etc/init.d/sshd.init start >/dev/null 2>&1
        service sshd restart >/dev/null 2>&1
        echo -e "[\033[34mInformation\033[0m] 启动 OpenSSH"
        service sshd status >/dev/null 2>&1 && echo -e "[\033[34mInformation\033[0m] OpenSSH 状态正常" || echo "OpenSSH 状态异常，请检查"
    elif [ "$SYSTEM_VERSION" -eq "7" ]; then
        echo -e "[\033[34mInformation\033[0m] 设置 OpenSSH 开机启动"
        cp -a contrib/redhat/sshd.init /etc/init.d/sshd >/dev/null 2>&1
        cp -a contrib/redhat/sshd.pam /etc/pam.d/sshd.pam >/dev/null 2>&1
        chmod +x /etc/init.d/sshd
        systemctl daemon-reload >/dev/null 2>&1 && sleep 1
        chkconfig --add sshd >/dev/null 2>&1
        systemctl enable sshd >/dev/null 2>&1
        chkconfig sshd on >/dev/null 2>&1
        \mv /usr/lib/systemd/system/sshd.service /opt/ >/dev/null 2>&1
        \mv /usr/lib/systemd/system/sshd.socket /opt/ >/dev/null 2>&1
        /etc/init.d/sshd.init start >/dev/null 2>&1
        systemctl restart sshd >/dev/null 2>&1
        systemctl daemon-reload >/dev/null 2>&1
        echo -e "[\033[34mInformation\033[0m] 启动 OpenSSH"
        systemctl status sshd >/dev/null 2>&1 && echo -e "[\033[34mInformation\033[0m] OpenSSH 状态正常" || echo "OpenSSH 状态异常，请检查"
    fi
    echo "" && echo "当前 OpenSSH 版本：" && ssh -V && echo ""
    rm -rf /tmp/"$openssh_version"* && echo "清理 /tmp/$openssh_version* " && echo ""
    end=$(date +%s)
    take=$((end - start))
    echo "程序运行耗时：$take 秒！"
}

ROLLBACK(){
sleep 1
#···
#···
rm -rf /etc/ssh
cp -R /etc/ssh.bak."$(date "+%Y%m%d")" /etc/ssh 
mv -f /usr/sbin/sshd."$(date "+%Y%m%d")" /usr/sbin/sshd
}
#-----------------------------------------------------------------------------------------------------------
clear
echo -e "\033[46;30m 您即将安装/升级 $openssh_version \033[0m"
sleep 0.8 && echo "" && echo "检查环境中······"
#environment check
CHECK
echo "" && echo "安装过程中请勿断开终端，如安装失败，请及时联系技术支持，是否继续执行？ [Y/N]: "
read -r REQUEST
if [[ $REQUEST == "Y" ]]; then
    #开始执行
    RUN
elif [[ $REQUEST == "N" ]]; then
    echo -e "[\033[34mInformation\033[0m] 退出程序"
    echo ""
    sleep 0.8
else
    echo -e "[\033[34mInformation\033[0m] 输入错误"
    echo ""
fi
