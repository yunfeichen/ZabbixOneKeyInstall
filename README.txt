#此脚本用于一键部署zabbix3.0.4 Server,需要你的主机可以访问外网，有很多依赖使用yum安装.

#运行此脚本如果中途报错，请使用者手动参照脚本解决，或者复制粘贴.

#web server基于nginx 并非apache,nginx 做的ip访问与映射,使用者后期可以换为域名访问，也可以使用另一台nginx 反代做外网访问.

#此脚本跑完，使用者可能需要访问web服务，next...next....next一直到最后.

#对于zabbix web 切换中文乱码的问题,作者使用微软雅黑字体替换.

#zabbix 默认登录的用户名为大写:Admin 密码:zabbix.

