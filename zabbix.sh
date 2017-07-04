#!/bin/bash

#Zabbix 一键部署脚本

#安装zabbix3.2.3,依赖php-5.6.25


src_home=`pwd`
echo -n "正在配置iptables防火墙……"
/etc/init.d/iptables save >> /dev/null
chkconfig  iptables off
if [ $? -eq 0 ];then
	echo -n "Iptables防火墙初始化完毕！"
fi

echo -n "正在关闭SELinux……"
setenforce 0 > /dev/null 2>&1
sed -i '/^SELINUX=/s/=.*/=disabled/' /etc/selinux/config
if [ $? -eq 0 ];then
        echo -n "SELinux初始化完毕！"
fi

echo -n "正在安装nginx yum 源……"
yum -y install wget
wget http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm
rpm -ivh nginx-release-centos-6-0.el6.ngx.noarch.rpm
if [ $? -eq 0 ];then
        echo -n "Nginx yum 源 初始化完毕！"
fi


echo -n "正在安装epel-release yum 源……"
rpm -Uvh http://mirrors.ustc.edu.cn/fedora/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

if [ $? -eq 0 ];then
        echo -n "epel-release yum 源 初始化完毕！"
fi


echo -n "正在安装php-5.6.25的编译所需相关软件……"
yum -y install make gcc nginx  libmcrypt php-mcrypt mysql-server mysql-devel net-snmp-devel libcurl-devel php php-mysql php-bcmath php-mbstring php-gd php-xml bzip2-devel libmcrypt-devel libxml2-devel gd gd-devel libcurl*
if [ $? -eq 0 ];then
        echo -n "php-5.6.25依赖初始化完毕！"
fi


echo -n "正在添加zabbix用户……"
useradd -M -s /sbin/nologin zabbix && echo "OK"

echo -n "正在启动mysqld服务……"
service mysqld start

if [ $? -eq 0 ];then
        echo -n "Mysql启动完毕！"
fi


#echo -n "正在为mysql的root用户设置密码……"
#mysql_user_root_password="password"
#mysql_user_zabbix_password="zabbix"
#mysqladmin -uroot -p password $mysql_user_root_password
echo "正在执行mysql语句，创建zabbix数据库，授权zabbix访问数据库"

mysql -e "create database zabbix character set utf8;grant all privileges on zabbix.* to zabbix@'%' identified by 'zabbix';grant all privileges on zabbix.* to zabbix@'127.0.0.1' identified by 'zabbix';grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbix';flush privileges;"
#echo "正在执行mysql语句，创建zabbix数据库，授权zabbix访问数据库"
#mysql -uroot -p"$mysql_user_root_password" -e "create database zabbix character set utf8" && echo "创建zabbix数据库完成"
#mysql -uroot -p"$mysql_user_root_password" -e "grant all privileges on zabbix.* to zabbix@localhost identified by '$mysql_user_zabbix_password'" && echo "授权zabbix本地登录数据库"
#mysql -uroot -p"$mysql_user_root_password" -e "grant all privileges on zabbix.* to zabbix@'%' identified by '$mysql_user_zabbix_password'" && echo "授权任何主机本地登录数据库"


#zabbix一键部署第三方软件包的解压目录

echo -n "编译安装php-5.6.25....可能需要几分钟"
tar zxf ${src_home}/php-5.6.25.tar.gz
cd ${src_home}/php-5.6.25 && ./configure --prefix=/usr/local/php --with-config-file-path=/etc --enable-fpm   --with-libxml-dir --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir --with-iconv-dir --with-zlib-dir --with-mcrypt --enable-soap --enable-gd-native-ttf  --enable-mbstring --enable-exif  --with-pear --with-curl --enable-bcmath --with-gettext --with-mysqli --enable-sockets
cd ${src_home}/php-5.6.25 && make -j 4 && make install

cd
echo -n "正在配置启动php-fpm....请稍等"
/bin/cp ${src_home}/php-5.6.25/php.ini-production /etc/php.ini
cp ${src_home}/php-5.6.25/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
chmod 777 /etc/init.d/php-fpm
cd /usr/local/php/etc/ && cp php-fpm.conf.default php-fpm.conf
cd
service php-fpm start
if [ $? -eq 0 ];then
        echo -n "php-fpm启动完毕！"
fi


#zabbix编译安装

cd ${src_home}
echo -n "正在导入zabbix数据到mysql数据库中...."
tar zxf ${src_home}/zabbix-3.2.3.tar.gz

mysql -uzabbix -pzabbix zabbix < ${src_home}/zabbix-3.2.3/database/mysql/schema.sql
mysql -uzabbix -pzabbix zabbix < ${src_home}/zabbix-3.2.3/database/mysql/images.sql
mysql -uzabbix -pzabbix zabbix < ${src_home}/zabbix-3.2.3/database/mysql/data.sql

if [ $? -eq 0 ];then
        echo -n "zabbix数据导入启动完毕！"
fi


echo -n "正在安装zabbix编译依赖软件包....可能需要几分钟"
yum -y install net-snmp-devel curl-devel javacc java-1.8*

echo -n "编译安装Zabbix-server....可能需要几分钟"
cd ${src_home}/zabbix-3.2.3 && ./configure --prefix=/usr/local/zabbix --enable-server --enable-proxy --enable-agent  --with-net-snmp --with-libcurl --enable-java --with-mysql
make -j 4 && make install


echo -n "正在制作Zabbix-server启动脚本...."
echo -e "zabbix-agent 10050/tcp #ZabbixAgent\nzabbix-agent 10050/udp #Zabbix Agent\nzabbix-trapper 10051/tcp #ZabbixTrapper\nzabbix-trapper 10051/udp #Zabbix Trapper" >> /etc/services

cp ${src_home}/zabbix-3.2.3/misc/init.d/fedora/core/zabbix_server /etc/init.d/
cp ${src_home}/zabbix-3.2.3/misc/init.d/fedora/core/zabbix_agentd /etc/init.d/
cd
chmod 777 /etc/init.d/zabbix_*
sed -i '/BASEDIR=/s/$/\/zabbix/' /etc/init.d/zabbix_server
sed -i '/BASEDIR=/s/$/\/zabbix/' /etc/init.d/zabbix_agentd

echo -n "正在配置zabbix配置文件...."
cd /usr/local/zabbix/etc
sed '/# DBHost=localhost/a\DBHost=localhost' zabbix_server.conf -i
sed '/# DBPassword=/a\DBPassword=zabbix' zabbix_server.conf -i

sed '/# EnableRemoteCommands=0/a\EnableRemoteCommands=1' zabbix_agentd.conf -i
sed '/# ListenPort=10050/a\ListenPort=10050' zabbix_agentd.conf -i
sed '/# User=zabbix/a\User=zabbix' zabbix_agentd.conf -i
sed '/# AllowRoot=0/a\AllowRoot=1' zabbix_agentd.conf -i
sed '/# UnsafeUserParameters=0/a\UnsafeUserParameters=1' zabbix_agentd.conf -i
if [ $? -eq 0 ];then
        echo -n "zabbix配置完毕！"
fi

echo -n "正在启动zabbix_server and zabbix_agent...."
service zabbix_server start
service zabbix_agentd start
chkconfig zabbix_server on
chkconfig zabbix_agentd on

cd

echo -n "正在配置nginx反代zabbix...."

cp -r ${src_home}/zabbix-3.2.3/frontends/php /usr/share/nginx/html/zabbix
cd /etc/nginx/conf.d/ && mv default.conf default.conf.bak
cp ${src_home}/zabbix.conf /etc/nginx/conf.d/
echo -n "配置完成，正在启动nginx web server...."
service nginx start

if [ $? -eq 0 ];then
        echo -n "Nginx启动完毕！"
fi

echo -n "正在进行最后的zabbix Install ,php参数修改....."
sed '/^post_max_size =/s/=.*/= 16M/' /etc/php.ini -i
sed '/^max_execution_time =/s/=.*/= 300/' /etc/php.ini -i
sed '/^max_input_time =/s/=.*/= 300/' /etc/php.ini -i
sed -i '/^;date.timezone/a\date.timezone =  Asia/Shanghai' /etc/php.ini
sed -i '/^;always_populate_raw_post_data.*/a\always_populate_raw_post_data = -1' /etc/php.ini
sed -i '/^mysqli.default_socket =/s/=.*/= \/var\/lib\/mysql\/mysql.sock/' /etc/php.ini

echo -n "正在重新启动php服务....."
/etc/init.d/php-fpm restart

echo -n "正在初始化zabbix Server...."
cp ${src_home}/zabbix.conf.php /usr/share/nginx/html/zabbix/conf/

echo -n "正在做最后的Zabbix Server重启....."
/etc/init.d/zabbix_server restart
if [ $? -eq 0 ];then
        echo -n "Zabbix Server 启动完毕！"
fi

echo -n "正在解决zabbix server 乱码问题,请你耐心等待....."

cd /usr/share/nginx/html/zabbix/fonts && mv DejaVuSans.ttf DejaVuSans.ttf.bak
cp ${src_home}/msyh.ttf .
cd ../include/ && sed -i 's/DejaVuSans/msyh/g' defines.inc.php
cd

echo -n"正在解决nginx访问zabbix目录权限问题，请你耐心等待....."
chown -R nginx.nginx  /usr/share/nginx/html/zabbix/
chmod -R 755   /usr/share/nginx/html/zabbix/
service nginx restart

echo -n "恭喜你,Zabbix 部署到此完成，如有问题，请参照脚本单独解决！！！"

echo -e -n "后续的操作:1、通过http://ip/zabbix 访问你的zabbix Web页面,下一步....一直到底。2、你可能需要配置Nginx域名,通过域名访问Zabbix Server.... 3、你需要自己自定义或者使用系统自带模板，添加主机等等...."
