#!/bin/bash
ippool=（1 5 9 13 17 21 25 29 33 37 41 45 49 53 57 61 65 69 73 77 81 85 89 93 97 101）
echo "输入增加用户的数量:"
read -p "(请输入大于0的整数):" tempnum
num=${tempnum}
for ((i=1;i<=${num};i++ ));
do
       uname=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
       echo "${uname} suansuanru.site" > psw-file
       echo "ifconfig-push 10.8.0.ippool[i] 10.8.0.{ipppol[i]+1}" > ./ccd/${uname}
done
