升级OpenSSH要求：(可运行脚本自动安装)
  1. 安装 openssl、openssl-devel
  2. 安装 zlib、zlib-devel
  3. 安装 gcc gcc-c++ 编译器
  4. 安装 pam-devel 模块
  6. openssl 版本不得低于 1.0.1  (https://www.openssh.com/releasenotes.html#7.4)


使用方法：
  
  脚本参数：
  
            -run        检测并运行脚本
            -check      检测环境
            -rollback   回滚版本
            -force      一键安装
  
