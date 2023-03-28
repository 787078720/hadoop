#!/bin/bash

JDKLINK='http://download.oracle.com/otn-pub/java/jdk/8u191-b12/2787e4a523244c269598db4e85c51e0c/jdk-8u191-linux-x64.rpm'
HADOOPLINK='https://archive.apache.org/dist/hadoop/core/hadoop-2.7.7/hadoop-2.7.7.tar.gz'
localIP=$(ip a | grep ens33 | awk '$1~/^inet.*/{print $2}' | awk -F '/' '{print $1}')
ip_arrays=()

#初始化环境
installWget(){
	echo '初始化安装环境....'
	wget
	if [ $? -ne 1 ]; then
		echo '开始下载wget'
		yum -y install wget
	fi
}

#wget下载JDK进行安装
installJDK(){
	ls /usr/local | grep '^jdk.*[rpm]$'
	if [ $? -ne 0 ]; then
		echo '开始下载JDK.......'
		wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" $JDKLINK
		mv $(ls | grep 'jdk.*[rpm]$') /usr/local
	fi
	chmod 751 /usr/local/$(ls /usr/local | grep '^jdk.*[rpm]$')
	rpm -ivh /usr/local/$(ls /usr/local | grep '^jdk.*[rpm]$')
}

#JDK环境变量配置
pathJDK(){
	#PATH设置
	grep -q "export PATH=" /etc/profile
	if [ $? -ne 0 ]; then
		#末行插入
		echo 'export PATH=$PATH:$JAVA_HOME/bin'>>/etc/profile
	else
		#行尾添加
		sed -i '/^export PATH=.*/s/$/:\$JAVA_HOME\/bin/' /etc/profile
	fi
	

	grep -q "export JAVA_HOME=" /etc/profile
	if [ $? -ne 0 ]; then
		#导入配置
		filename="$(ls /usr/java | grep '^jdk.*[^rpm | gz]$' | sed -n '1p')"
		sed -i "/^export PATH=.*/i\export JAVA_HOME=\/usr\/java\/$filename" /etc/profile
		sed -i '/^export PATH=.*/i\export JRE_HOME=$JAVA_HOME/jre' /etc/profile
		sed -i '/^export PATH=.*/i\export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar' /etc/profile
		#echo "export JAVA_HOME=/usr/java/$filename">>/etc/profile
		#echo 'export JRE_HOME=$JAVA_HOME/jre'>>/etc/profile
		#echo 'export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar'>>/etc/profile
	else
		#替换原有配置
		filename="$(ls /usr/java | grep '^jdk.*[^rpm | gz]$' | sed -n '1p')"
		sed -i "s/^export JAVA_HOME=.*/export JAVA_HOME=\/usr\/java\/$filename/" /etc/profile
	fi
	source /etc/profile

}

#wget下载Hadoop进行解压(单机版)
wgetHadoop(){
	ls /usr/local | grep '^hadoop.*[gz]$'
	if [ $? -ne 0 ]; then
		echo '开始下载hadoop安装包...'
		wget $HADOOPLINK
		mv $(ls | grep 'hadoop.*gz$') /usr/local
	fi
	tar -zxvf /usr/local/$(ls | grep '^hadoop.*[gz]$')
	mv /usr/local/$(ls | grep '^hadoop.*[^gz]$') /usr/local/hadoop
}

#hadoop环境变量配置
pathHadoop(){
	#PATH设置
	grep -q "export PATH=" /etc/profile
	if [ $? -ne 0 ]; then
		#末行插入
		echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin'>>/etc/profile
	else
		#行尾添加
		sed -i '/^export PATH=.*/s/$/:\$HADOOP_HOME\/bin:\$HADOOP_HOME\/sbin/' /etc/profile
	fi
	#HADOOP_HOME设置
	grep -q "export HADOOP_HOME=" /etc/profile
	if [ $? -ne 0 ]; then
		#在PATH前面一行插入HADOOP_HOME
		sed -i '/^export PATH=.*/i\export HADOOP_HOME=\/usr\/local\/hadoop' /etc/profile
	else
		#修改文件内的HADOOP_HOME
		sed -i 's/^export HADOOP_HOME=.*/export HADOOP_HOME=\/usr\/local\/hadoop/' /etc/profile
	fi
	source /etc/profile
}

#添加hadoop用户并设置权限
hadoopUserAdd(){
	echo '正在创建hadoop用户....'
	useradd -p "YpAKqsb3BD.ng" hadoop
	# useradd hadoop
	# echo '请设置hadoop用户密码....'
	# passwd hadoop
	gpasswd -a hadoop root
	chmod 771 /usr
	chmod 771 /usr/local
	chown -R hadoop:hadoop /usr/local/hadoop
}

#单机版hadoop配置
installHadoop(){
	installWget
	wgetHadoop
	pathHadoop
	hadoopUserAdd
}

#伪分布式设置
setHadoop(){
echo '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>

	<property>
		<name>hadoop.tmp.dir</name>
		<value>file:/usr/local/hadoop/tmp</value>
		<description>指定hadoop运行时产生文件的存储路径</description>
	</property>
	<property>
		<name>fs.defaultFS</name>
		<value>hdfs://localhost:9000</value>
		<description>hdfs namenode的通信地址,通信端口</description>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/core-site.xml


echo '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->
<!-- 该文件指定与HDFS相关的配置信息。
需要修改HDFS默认的块的副本属性，因为HDFS默认情况下每个数据块保存3个副本，
而在伪分布式模式下运行时，由于只有一个数据节点，
所以需要将副本个数改为1；否则Hadoop程序会报错。 -->

<configuration>

	<property>
		<name>dfs.replication</name>
		<value>1</value>
		<description>指定HDFS存储数据的副本数目，默认情况下是3份</description>
	</property>
	<property>
		<name>dfs.namenode.name.dir</name>
		<value>file:/usr/local/hadoop/hadoopdata/namenode</value>
		<description>namenode存放数据的目录</description>
	</property>
	<property>
		<name>dfs.datanode.data.dir</name>
		<value>file:/usr/local/hadoop/hadoopdata/datanode</value>
		<description>datanode存放block块的目录</description>
	</property>
	<property>
		<name>dfs.permissions.enabled</name>
		<value>false</value>
		<description>关闭权限验证</description>
	</property>
	<property>
	 <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
	 <value>false</value>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/hdfs-site.xml
	
echo '<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->
<!-- 在该配置文件中指定与MapReduce作业相关的配置属性，需要指定JobTracker运行的主机地址-->

<configuration>

	<property>
		<name>mapreduce.framework.name</name>
		<value>yarn</value>
		<description>指定mapreduce运行在yarn上</description>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/mapred-site.xml

echo '<?xml version="1.0"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
<configuration>

<!-- Site specific YARN configuration properties -->

	<property>
		<name>yarn.nodemanager.aux-services</name>
		<value>mapreduce_shuffle</value>
		<description>mapreduce执行shuffle时获取数据的方式</description>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/yarn-site.xml

	echo 'localhost'>$HADOOP_HOME/etc/hadoop/slaves
	sed -i 's/export JAVA_HOME=.*/\#&/' $HADOOP_HOME/etc/hadoop/hadoop-env.sh
	sed -i "/#export JAVA_HOME=.*/a export JAVA_HOME=$JAVA_HOME" $HADOOP_HOME/etc/hadoop/hadoop-env.sh
	chown -R hadoop:hadoop $HADOOP_HOME

}

#完全分布式设置
setHadoop2(){
echo '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>

	<property>
		<name>hadoop.tmp.dir</name>
		<value>file:/usr/local/hadoop/tmp</value>
		<description>指定hadoop运行时产生文件的存储路径</description>
	</property>
	<property>
		<name>fs.defaultFS</name>
		<value>hdfs://'$1':9000</value>
		<description>hdfs namenode的通信地址,通信端口</description>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/core-site.xml

echo '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->
<!-- 该文件指定与HDFS相关的配置信息。
需要修改HDFS默认的块的副本属性，因为HDFS默认情况下每个数据块保存3个副本，
而在伪分布式模式下运行时，由于只有一个数据节点，
所以需要将副本个数改为1；否则Hadoop程序会报错。 -->

<configuration>

	<property>
		<name>dfs.replication</name>
		<value>3</value>
		<description>指定HDFS存储数据的副本数目，默认情况下是3份</description>
	</property>
	<property>
		<name>dfs.namenode.name.dir</name>
		<value>file:/usr/local/hadoop/hadoopdata/namenode</value>
		<description>namenode存放数据的目录</description>
	</property>
	<property>
		<name>dfs.datanode.data.dir</name>
		<value>file:/usr/local/hadoop/hadoopdata/datanode</value>
		<description>datanode存放block块的目录</description>
	</property>
	<property>
		<name>dfs.secondary.http.address</name>
		<value>'$2':50090</value>
		<description>secondarynamenode 运行节点的信息，和 namenode 不同节点</description>
	</property>
	<property>
		<name>dfs.permissions.enabled</name>
		<value>false</value>
		<description>关闭权限验证</description>
	</property>
	<property>
	 <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
	 <value>false</value>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/hdfs-site.xml

echo '<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->
<!-- 在该配置文件中指定与MapReduce作业相关的配置属性，需要指定JobTracker运行的主机地址-->

<configuration>

	<property>
		<name>mapreduce.framework.name</name>
		<value>yarn</value>
		<description>指定mapreduce运行在yarn上</description>
	<property>
  	  <name>mapreduce.jobhistory.address</name>
 	   <value>localhost:10020</value>
	</property>

<!-- 配置web端口 -->
	<property>
 	   <name>mapreduce.jobhistory.webapp.address</name>
 	   <value>localhost:19888</value>
	</property>

<!-- 配置正在运行中的日志在hdfs上的存放路径 -->
	<property>
 	   <name>mapreduce.jobhistory.intermediate-done-dir</name>
 	   <value>/history/done_intermediate</value>
	</property>

<!-- 配置运行过的日志存放在hdfs上的存放路径 -->
	<property>
 	   <name>mapreduce.jobhistory.done-dir</name>
   	 <value>/history/done</value>
	</property>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/mapred-site.xml

echo '<?xml version="1.0"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
<configuration>

<!-- Site specific YARN configuration properties -->
	<property>
		<name>yarn.resourcemanager.hostname</name>
		<value>'$1'</value>
		<description>yarn总管理器的IPC通讯地址</description>
	</property>
	<property>
	<name>yarn.log-aggregation-enable</name>
	<value>true</value>
	</property>
	<property>
		<name>yarn.nodemanager.aux-services</name>
		<value>mapreduce_shuffle</value>
		<description>mapreduce执行shuffle时获取数据的方式</description>
	</property>

</configuration>'>$HADOOP_HOME/etc/hadoop/yarn-site.xml
	rm -rf $HADOOP_HOME/etc/hadoop/slaves
	touch $HADOOP_HOME/etc/hadoop/slaves
	int=0
	while(( ${int}<${#ip_arrays[*]} ))
	do
		#echo "while is run"
		echo "${ip_arrays[$int]}">>$HADOOP_HOME/etc/hadoop/slaves
		if [ $? -ne 0 ]
		then
			echo '写入slaves配置失败'
			break
		fi
		let "int++"
	done
	sed -i 's/export JAVA_HOME=.*/\#&/' $HADOOP_HOME/etc/hadoop/hadoop-env.sh
	sed -i "/#export JAVA_HOME=.*/a export JAVA_HOME=$JAVA_HOME" $HADOOP_HOME/etc/hadoop/hadoop-env.sh
	chown -R hadoop:hadoop $HADOOP_HOME
}

#关闭防火墙
stopFirewalld(){
	systemctl stop firewalld
	systemctl disable firewalld
}

#IP校验,返回值0校验合法，1不合法。
checkIPAddr(){
	echo $1|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null; 
	#IP地址必须为全数字 
	if [ $? -ne 0 ] 
	then 
		return 1 
	fi 
	ipaddr=$1 
	a=`echo $ipaddr|awk -F . '{print $1}'`  #以"."分隔，取出每个列的值 
	b=`echo $ipaddr|awk -F . '{print $2}'` 
	c=`echo $ipaddr|awk -F . '{print $3}'` 
	d=`echo $ipaddr|awk -F . '{print $4}'` 
	for num in $a $b $c $d 
	do 
		if [ $num -gt 255 ] || [ $num -lt 0 ]    #每个数值必须在0-255之间 
		then 
			return 1 
		fi 
	done 
		return 0 
}

#控制台输入集群IP
ipInput(){
	#让用户选择IP输入方式
	flag=1
	echo '请输入子节点IP的录入方式'
	echo '录入的第一个节点默认为secondaryNameNode'
	echo 'NameNode也可以作为dataNode使用，但建议不要放在第一个录入'
	echo '1、字符串拼接，如: 192.168.10.110,192.168.10.108,192.168.10.102'
	echo '2、逐个录入，输入ip值为0可结束录入'
	echo '请输入选项[1-2]'
  	read aNum
	case $aNum in
		1)  
		int=0
		read -p "输入子节点IP以符号,拼接的字符串:" ipstr
		#对IFS变量 进行替换处理
		OLD_IFS="$IFS"
		IFS=","
		iparray=($ipstr)
		IFS="$OLD_IFS"	
		for ipvar in ${iparray[@]}
		do
		checkIPAddr $ipvar
		if [ $? -eq 0 ]
			then		
				ip_arrays[$int]=$ipvar
			else
				echo '输入的IP不合法,重新进行配置....'
				flag=0
				break
			fi
			let "int++"
		done
		;;
		2)  
		echo "本机IP地址为：$localIP"
		int=0
		echo '输入完成后，输入ip值为0可退出'
		while read -p "输入第`expr ${int} + 1`台的IP:" ip
		do		
			if [ "$ip" == "0" ]
			then
				break
			fi
			checkIPAddr $ip
			if [ $? -eq 0 ]
			then		
				ip_arrays[$int]=$ip
				#echo $int
			else
				echo '输入的IP不合法,重新进行配置....'
				flag=0
				break
			fi
			let "int++"
		done
		;;
		*)  echo '没有该选项，请重新输入!!!退出请按Ctrl+c'
			flag=0
		;;
	esac


	if [  $flag == 0 ]
	then
	ipInput
	fi

}

#scp设置免密登录
scpOutput(){
	int=0
	while(( ${int}<${#ip_arrays[*]} ))
	do
		if [ "${ip_arrays[${int}]}" == "$localIP" ]; then
			echo "第`expr ${int} + 1`台为本机，无需配置"
		else
		echo "第`expr ${int} + 1`台：${ip_arrays[${int}]}"
		scp -r ~/.ssh ${ip_arrays[$int]}:~/
		fi
	let "int++"
	done
	echo "免密登录配置成功"
}

#SSH免密登录
setSSH(){
	echo '---------------配置ssh免密登录----------------------'
	echo '------------一路回车即可生成秘钥--------------------'
	ssh-keygen -t rsa
	echo '----------秘钥生成完成，开始生成公钥----------------'
	echo '根据提示输入相应的信息'
	echo '----------------------------------------------------'
	echo 'Are you sure you want to continue connecting (yes/no)?'
	echo '------------------输入"yes"-------------------------'
	echo 'root@localhost s password:'
	echo '--------------输入用户密码--------------------'	
	ssh-copy-id localhost
}

#控制台选择本机角色
nameOrData(){
	echo '--------------------------'
	echo '1、namenode'
	echo '2、datanode'
	read -p '请选择本机的角色[1-2]:' n
	case $n in
		1)	return 0
		;;
		2)	return 1
		;;
		*)	echo '输入错误！！！'
			nameOrData
		;;
	esac
}

#配置hosts文件
setHosts(){
	echo '开始配置/etc/hosts文件'
	echo '本机IP地址为：'$localIP''
	#read -p '请输入本机主机名(hostname):' hostname
	hostname="master"
	echo -e ''$localIP'\t'$hostname''>>/etc/hosts
	#echo '根据提示输入其他主机名(hostname)'
	echo '-----------------------------------'
	int=0
	while(( ${int}<${#ip_arrays[*]} ))
	do
		echo 'IP：'${ip_arrays[$int]}''
		#read -p "请输入主机名：" hostname
		nownum=`expr $int + 1`
		hostname="slave"${nownum}
		echo -e ''${ip_arrays[$int]}'\t'$hostname''>>/etc/hosts
		echo '-----------------'$hostname'------------------'
		let "int++"
	done
}

#1、Java环境一键配置
javaInstall(){
	echo '开始检查本机环境'
      source /etc/profile
	java -version
	if [ $? -ne 0 ]; then
		installWget			
		echo '开始配置JDK，请耐心等待......'
		installJDK
		pathJDK
		java -version
		if [ $? -eq 0 ]; then
			echo 'JDK配置完成'
		else
			echo '安装失败，请重新尝试或手动安装'
		fi
	else
		pathJDK
		echo '已经配置该环境'
	fi
}
#2、Hadoop单机版一键安装
hadoopInstall(){
	javaInstall
	echo '开始检查本机环境'
	hadoop
	if [ $? -ne 0 ]; then
		installHadoop
		hadoop
		if [ $? -eq 0 ]; then
			echo 'hadoop单机版配置完成'
		else
			echo '安装失败，请重新尝试或手动安装'
		fi
	else
		echo '已经配置该环境'
	fi
}
#3、Hadoop伪分布式一键安装
hadoopInstall2(){
	javaInstall
	echo '开始检查本机环境'
	hadoop
	if [ $? -ne 0 ]; then
		installHadoop
		hadoop
		if [ $? -eq 0 ]; then
			echo 'hadoop单机版配置完成，开始配置伪分布式'
			setHadoop
			stopFirewalld
			echo '配置完成....使用hadoop用户初始化'
			su hadoop
		else
			echo '安装失败，请重新尝试或手动安装'
		fi
	else
		echo 'hadoop单机版已经安装，开始配置伪分布式'
		setHadoop
		stopFirewalld
		echo '配置完成....使用hadoop用户初始化'
		su hadoop
	fi
}
#NameNode 部署
namenodeinstall(){
#记录IP
		echo '输入datanode的IP'
		ipInput
		#namenode配置
		#1安装单机版hadoop
		hadoopInstall
		#2导入集群配置文件
		echo '开始导入配置文件'
		setHadoop2 ${localIP} ${ip_arrays[0]}
		echo '配置导入完成'
		#3关闭防火墙
		stopFirewalld
		echo '防火墙已关闭'
		#4压缩修改后的hadoop包，方便传输
		tar -zcvf /usr/local/temp-hadoop.tar.gz hadoop
		echo "修改配置后的hadoop安装包已压缩"
		#上传主机配置到datanode
		int=0
		while(( ${int}<${#ip_arrays[*]} ))
		do		
		if [ "${ip_arrays[${int}]}" == "$localIP" ]; then
			echo "第`expr ${int} + 1`台dataNode节点同时为nameNode节点，无需传送配置文件和安装包"
		else
			echo "开始给第`expr ${int} + 1`台dataNode节点传送配置文件和安装包"
			echo "IP为：${ip_arrays[${int}]}"
			echo "传送过程可能需手动输入远程主机root密码"
			#scp传送安装包
			scp $(pwd)/install-hadoop.sh ${ip_arrays[$int]}:/usr/local
			scp /usr/local/$(ls | grep 'jdk.*[rpm]$') ${ip_arrays[$int]}:/usr/local
			#传输hadoop压缩包
			#scp -r /usr/local/hadoop ${ip_arrays[$int]}:/usr/local
			scp -r /usr/local/temp-hadoop.tar.gz ${ip_arrays[$int]}:/usr/local
			echo "${ip_arrays[$int]}文件上传完成....."
		    echo '登录datanode主机执行该脚本继续完成datanode配置，脚本存储目录/usr/local'
			ssh "root@"${ip_arrays[$int]} ". /usr/local/install-hadoop.sh 9"
		fi
		let "int++"
		done
		#删除压缩包
		echo "删除hadoop压缩包"
		rm -f /usr/local/temp-hadoop.tar.gz
		#setHosts
		

		#hadoop初始化
		echo '执行hadoop初始化...'
		hdfs namenode -format
		echo '分布式集群搭建完成'

}
#DataNode部署
datanodeinstall(){
		#解压修改配置后hadoop安装包
		echo "解压修改配置后hadoop安装包"
		tar -zxvf /usr/local/temp-hadoop.tar.gz -C /usr/local/
		#删除压缩包
		echo "删除hadoop压缩包"
		rm -f /usr/local/temp-hadoop.tar.gz
		#安装Java
		javaInstall
		#配置Hadoop环境变量
		echo '配置环境变量'
		pathHadoop
		echo '环境变量配置完成'
		#添加用户
		hadoopUserAdd
		#关闭防火墙
		stopFirewalld
		echo '防火墙已关闭'
		source /etc/profile
		echo '测试安装情况.....'
		java -version
		if [ $? -ne 0 ]; then
			echo '请手动执行source /etc/profile'
			echo '执行java -version确认JDK安装情况'
		fi
		hadoop version
		if [ $? -ne 0 ]; then
			echo '请手动执行source /etc/profile'
			echo '执行hadoop version确认hadoop安装情况'
		fi
		echo 'datanode配置完成'
}
#4、Hadoop集群部署
hadoopInstall3(){
	nameOrData
	if [ $? -eq 0 ]
	then
	    #安装namenode
	    namenodeinstall
	elif [ $? -eq 1 ]
	then
		#安装datanode
		datanodeinstall
	else
		echo '发生错误！！！'
	fi
}
#6、集群设置SSH免密登录（使用hadoop用户操作）
setSSHS(){
	#本机设置免密
	echo '开始设置本机免密....'
	setSSH
	#输入其他电脑IP
	echo '开始设置其他主机....'
	echo '输入其他主机ip'
	ipInput
	#用scp将秘钥发到其他主机
	echo '开始发送秘钥到其他主机...'
	scpOutput
}

#一键删除hadoop集群
removeHadoop(){
	#停止hadoop服务
	echo "停止hadoop服务..."
	. /usr/local/hadoop/sbin/stop-all.sh
	#读取slaves文件中的IP
	echo "读取slaves的IP"
	mapfile myarr </usr/local/hadoop/etc/hadoop/slaves
	#删除本机hadoop文件夹
	echo "删除本机hadoop文件夹..."
	rm -rf /usr/local/hadoop/
	int=0
		while(( ${int}<${#myarr[*]} ))
		do		
			#删除datanode hadoop文件夹
			echo "删除"${myarr[$int]}" hadoop文件夹..."
			ssh "root@"${myarr[$int]} "rm -rf /usr/local/hadoop/"
			let "int++"
		done
	echo "hadoop集群删除成功"	
}

sparkandscala(){
   echo '开始安装scala'
   sleep 1
   tar -zxvf /usr/local/$(ls /usr/local | grep 'scala'.*tgz) -C /usr/local/
   echo 'export SCALA_HOME=/usr/local/scala-2.12.15' >> /etc/profile 
   echo 'export PATH=${SCALA_HOME}/bin:$PATH' >> /etc/profile 
   echo 'scala安装完成' 
   #安装解压
   echo '开始安装spark'
   tar -zxvf $(ls /usr/local | grep 'spark'.*tgz) 
   chmod 777 $(ls /usr/local | grep 'spark*' |grep -v tgz)
   echo 'export SPARK_HOME=$(ls /usr/local | grep 'spark*' |grep -v tgz)' >> /etc/profile 
   echo 'export PATH=${SPARK_HOME}/bin:$PATH' >> /etc/profile 
   read  -p  '输入主节点ip:'  ip
   #写配置文件
   echo 'export SCALA_HOME=/usr/local/'$(ls /usr/local | grep 'scala*' |grep -v tgz)'
   export JAVA_HOME=/usr/java/jdk1.8.0_191-amd64
   export SPARK_MASTER_IP='$ip'
   export SPARK_WORKER_MEMORY=1g
   export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/'  >>  /usr/local/$(ls /usr/local | grep 'spark*' |grep -v tgz)/conf/spark-env.sh
   read  -p  '输入slaves节点ip:'  ipp
   echo -e ${ip}'\n'${ipp} > spark-3.2.3-bin-hadoop2.7/conf/slaves
   source /etc/profile
 }
nodespark(){
   read  -p  '输入slaves节点ip:'  ipp
   scp -r /usr/local/scala-2.12.15 $ipp:/usr/local/
   scp -r /usr/local/spark-3.2.3-bin-hadoop2.7 $ipp:/usr/local/
   echo 'slaves节点安装完成' 
}
ZooKeeper(){
   tar -zxvf /usr/local/apache-zookeeper-3.5.gz -C /usr/local/
   cp  /usr/local/apache-zookeeper-3.5.7-bin/conf/zoo_sample.cfg /usr/local/apache-zookeeper-3.5.7-bin/conf/zoo.cfg
   mkdir /opt/data
   echo 'dataDir=/opt/data' >> /usr/local/apache-zookeeper-3.5.7-bin/conf/zoo.cfg
   source /etc/profile
   #sh /usr/local/apache-zookeeper-3.5.7-bin/bin/zkServer.sh start
 }
hbash(){
   tar -zxvf /usr/local/hbase-2.4.9-bin.tar.gz -C /usr/local/
   echo 'export JAVA_HOME=/usr/java/jdk1.8.0_191-amd64
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export HBASE_MANAGES_ZK=true
export HBASE_HOME=/usr/local/hbase-2.4.9' >> /usr/local/hbase-2.4.9/conf/hbase-env.sh
   #开始写入配置项
   sed -i '$d' /usr/local/hbase-2.4.9/conf/hbase-site.xml
   echo '<property>
                <name>hbase.rootdir</name>
                <value>hdfs://localhost:9000/hbase</value>
        </property>
</configuration>
' >> /usr/local/hbase-2.4.9/conf/hbase-site.xml
}
#控制台输入选项
consoleInput(){
	echo '1、Java环境一键配置'
	echo '2、Hadoop单机版一键安装'
	echo '3、Hadoop伪分布式一键安装'
	echo '4、Hadoop集群一键部署（在namenode主机上执行）'
	echo '5、Hadoop初始化（在namenode主机上执行）'
	echo '6、集群设置SSH免密登录'
	echo '7、启动Hadoop集群（在namenode主机上执行）'
	echo '8、停止Hadoop集群（在namenode主机上执行）'
	echo '9、DataNode部署（在datanode主机上执行）'
	echo '10、一键删除hadoop集群（在namenode主机上执行）'
    echo '11、安装scala和spark '
	echo '12、slaves机安装spark '
	echo '13、启动spark '
    echo '14、安装ZooKeeper'
    echo '15、安装hbash'
	echo '请输入选项[1-16]'
	aNum=$1
	#判断是否有输入参数
	if [ x"$1" = x ]
	then 
  		read aNum
	fi
	echo $aNum
	case $aNum in

  		1)  javaInstall
        	;;
         	2)  hadoopInstall
              ;;
              3)  hadoopInstall2
                  ;;
              4)  namenodeinstall
                  ;;
              5)  echo 'Hadoop初始化'
                  	hdfs namenode -format && source /etc/profile
                  ;;
              6)  setSSHS
                  ;;
              7)  echo '启动Hadoop集群'
                  . /usr/local/hadoop/sbin/start-all.sh 
                  ;;
              8)  echo '停止Hadoop集群'
                  . /usr/local/hadoop/sbin/stop-all.sh
                  ;;
              9)  datanodeinstall
                  ;;
              10)  removeHadoop
                   ;;
              11) sparkandscala
                   ;;
              12)  nodespark
                   ;;
              13)  echo '启动spark'
                  sh /usr/local/spark-3.2.3-bin-hadoop2.7/sbin/start-all.sh && sh /usr/local/hadoop/sbin/mr-jobhistory-daemon.sh start historyserver
                  ;;
              14) ZooKeeper
                   ;;
              15) hbash
                   ;;
                   *)  echo '没有该选项，请重新输入!!!退出请按Ctrl+c'
                   	consoleInput
                   ;;
                   esac
                   }
                   echo '------------------欢迎使用一键安装------------------'
                   echo '为保证安装过程顺利进行，请使用root用户执行该脚本，第一步先手动配置好各个节点的hosts'
                   echo '该脚本增加了本地安装包自动安装'
                   echo '如果需要脚本安装本地安装包，请将安装包放在/usr/local下'
                   echo 'hadoop安装包要求以hadoop开头的.tar.gz包'
                   echo 'JDK安装包要求以jdk开头的.rpm包'
                   echo '----------------------------------------------------'
                   consoleInput $1
