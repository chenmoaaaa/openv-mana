#!/bin/bash

#适用centos7

#安装epel源
yum -y install wget
yum -y install epel-release

#启用epel
sed -i "s/enabled=0/enabled=1/" /etc/yum.repos.d/epel.repo

#安装openvpn
yum -y install openvpn-2.4.7-1.el7 easy-rsa-3.0.3-1.el7

#复制easy到openvpn
cp -rf /usr/share/easy-rsa/ /etc/openvpn/easy-rsa

#复制server.conf
cp -f /usr/share/doc/openvpn-2.4.7/sample/sample-config-files/server.conf /etc/openvpn/

#复制vars
cp -f /usr/share/doc/easy-rsa-3.0.3/vars.example /etc/openvpn/easy-rsa/3.0.3/vars

cd /etc/openvpn/easy-rsa/3.0.3/

#生成ta.key
openvpn --genkey --secret ta.key
#创建pki目录
./easyrsa init-pki
#生成证书
./easyrsa --batch build-ca nopass
#生成服务端证书
./easyrsa --batch build-server-full server nopass
#生成客户端端证书
./easyrsa --batch build-client-full client1 nopass
#生成gen
./easyrsa gen-dh

#管理证书位置
cp /etc/openvpn/easy-rsa/3.0.3/pki/ca.crt /etc/openvpn/
cp /etc/openvpn/easy-rsa/3.0.3/pki/issued/server.crt /etc/openvpn/
cp /etc/openvpn/easy-rsa/3.0.3/pki/dh.pem /etc/openvpn/dh2048.pem
cp /etc/openvpn/easy-rsa/3.0.3/pki/private/server.key /etc/openvpn/
cp /etc/openvpn/easy-rsa/3.0.3/ta.key /etc/openvpn/
cp /etc/openvpn/easy-rsa/3.0.3/pki/issued/client1.crt /etc/openvpn/client/
cp /etc/openvpn/easy-rsa/3.0.3/ta.key /etc/openvpn/client/
cp /etc/openvpn/easy-rsa/3.0.3/pki/ca.crt /etc/openvpn/client/
cp /etc/openvpn/easy-rsa/3.0.3/pki/private/client1.key /etc/openvpn/client/

#关闭firewalld
systemctl stop firewalld
systemctl disable firewalld

#安装iptables
yum install -y iptables-services 
systemctl enable iptables 
systemctl start iptables 

#清除规则
iptables -F
iptables -t nat -A POSTROUTING -s 10.8.0.0/16 ! -d 10.8.0.0/16 -j MASQUERADE
service iptables save

#启用转发
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -p

#永久转发
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

#配置服务端server.conf
cd /etc/openvpn
mkdir ccd
rm -f server.conf
curl -o server.conf https://raw.githubusercontent.com/yobabyshark/openv-mana/master/server.conf

#将openvpn客户端文件下载到client
curl -o /etc/openvpn/client/client.ovpn https://raw.githubusercontent.com/yobabyshark/openv-mana/master/client.ovpn

#将登录控制脚本下载
curl -o /etc/openvpn/checkpsw.sh https://raw.githubusercontent.com/yobabyshark/openv-mana/master/checkpsw.sh
chmod +x /etc/openvpn/checkpsw.sh

#修改client.ovpn文件ca
echo "<ca>" >> /etc/openvpn/client/client.ovpn
cat /etc/openvpn/client/ca.crt >> /etc/openvpn/client/client.ovpn
echo "</ca>" >> /etc/openvpn/client/client.ovpn

#修改client.ovpn文件tls
echo key-direction 1 >> /etc/openvpn/client/client.ovpn
echo "<tls-auth>" >> /etc/openvpn/client/client.ovpn
cat /etc/openvpn/client/ta.key >> /etc/openvpn/client/client.ovpn
echo "</tls-auth>" >> /etc/openvpn/client/client.ovpn

#下载客户端udp程序
#wget -P /etc/openvpn/client/ https://github.com/yobabyshark/onekeyopenvpn/raw/master/udp2raw.exe
#wget -P /etc/openvpn/client/ https://github.com/yobabyshark/onekeyopenvpn/raw/master/speederv2.exe

#下载客户端脚本
curl -o /etc/openvpn/client/client_pre.bat https://raw.githubusercontent.com/yobabyshark/openv-mana/master/client_pre.bat
curl -o /etc/openvpn/client/client_down.bat https://raw.githubusercontent.com/yobabyshark/openv-mana/master/client_down.bat

#修改client_pre脚本ip
serverip=$(curl icanhazip.com)
sed -i "s/103.102.45.151/$serverip/" /etc/openvpn/client/client_pre.bat

#下载udpspeeder和udp2raw （amd64版）
mkdir /usr/src/udp
cd /usr/src/udp
curl -o speederv2 https://raw.githubusercontent.com/yobabyshark/openv-mana/master/speederv2
curl -o udp2raw https://raw.githubusercontent.com/yobabyshark/openv-mana/master/udp2raw
chmod +x speederv2 udp2raw

#启动udpspeeder和udp2raw
nohup ./speederv2 -s -l0.0.0.0:9999 -r127.0.0.1:1194 -f2:4 --mode 0 --timeout 1 >speeder.log 2>&1 &
nohup ./udp2raw -s -l0.0.0.0:9898 -r 127.0.0.1:9999  --raw-mode faketcp  -a -k passwd >udp2raw.log 2>&1 &

#启动openvpn
systemctl start openvpn@server

#增加自启动脚本
cat > /etc/rc.d/init.d/openv<<-EOF
#!/bin/sh
#chkconfig: 2345 80 90
#description:openv
cd /usr/src/udp
nohup ./speederv2 -s -l0.0.0.0:9999 -r127.0.0.1:1194 -f2:4 --mode 0 --timeout 1 >speeder.log 2>&1 &
nohup ./udp2raw -s -l0.0.0.0:9898 -r 127.0.0.1:9999  --raw-mode faketcp  -a -k passwd >udp2raw.log 2>&1 &
systemctl start openvpn@server
EOF

#设置脚本权限
chmod +x /etc/rc.d/init.d/openv
chkconfig --add openv
chkconfig openv on

#配置用户
cd /etc/openvpn
ippool=(1 5 9 13 17 21 25 29 33 37 41 45 49 53 57 61 65 69 73 77 81 85 89 93 97 101)
echo "输入增加用户的数量:"
read -p "(请输入大于0小于25的整数):" tempnum
num=${tempnum}
for ((i=1;i<=${num};i++ ));
do
    uname="user"$(cat /dev/urandom | head -1 | md5sum | head -c 8)
    passwd="key"$(cat /dev/urandom | head -1 | md5sum | head -c 8)
    echo "${uname} ${passwd}" >> psw-file
    ip1="10.8.0."${ippool[i]}
    ip2="10.8.0."$((ippool[i]+1))
#    echo "${uname} $ip1 10000000000" >> traffic-limit
#    iptables -n -v -L -t filter|grep $ip1 && ifhave=0 || ifhave=1
#   if [ $ifhave -eq 1 ]; then
#        iptables -A FORWARD -m limit -d ${ip1} --limit 200/sec -j ACCEPT
#        iptables -A FORWARD -d ${ip1} -j DROP
#    fi
    echo "ifconfig-push ${ip1} ${ip2}" > ./ccd/${uname}
done
service iptables save
echo "以下为本次添加的用户信息，用户名和对应的密码："
cat psw-file 
