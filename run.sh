#!/bin/bash

NODE=/sys/devices/system/node
MEM=/sys/devices/system/memory
BLOCKSIZE_16=$(cat /sys/devices/system/memory/block_size_bytes)
BLOCK=`ls $MEM | grep -c memory`
((BLOCKSIZE_temp=16#$BLOCKSIZE_16))
BLOCKSIZE_10=$BLOCKSIZE_temp
BLOCKSIZE_10_MB=$(printf "%d" $((BLOCKSIZE_temp/1024/1024)))
#echo "The current environment, MEM block size(16 hexadecimal):" $BLOCKSIZE_16
echo "The current environment, MEM block size:" $BLOCKSIZE_10_MB "MB"
echo "The total number of MEM block exposed in the current environment:" $BLOCK

#记录node节点信息
BLOCK_NODE0=`ls $NODE/node0 | grep -c memory`
BLOCK_NODE1=`ls $NODE/node1 | grep -c memory`

#计算各个节点上需要关闭多少block
INPUT_DRAM_MEM_BYTE=$1
INPUT_NVM_MEM_BYTE=$2
NODE0_SECTION_NEED=$(printf "%d" $((INPUT_DRAM_MEM_BYTE/BLOCKSIZE_10)))
NODE1_SECTION_NEED=$(printf "%d" $((INPUT_NVM_MEM_BYTE/BLOCKSIZE_10)))
NODE0_OFF=$(printf "%d" $((BLOCK_NODE0-NODE0_SECTION_NEED)))
NODE1_OFF=$(printf "%d" $((BLOCK_NODE1-NODE1_SECTION_NEED)))

if [ $INPUT_DRAM_MEM_BYTE -ne "0" ];
then
echo "Input DRAM mem size(BYTE): "$INPUT_DRAM_MEM_BYTE 
echo "Input NVM mem size(BYTE): "$INPUT_NVM_MEM_BYTE 
echo "After hot plug, online DRAM seciton num is: "$NODE0_SECTION_NEED
echo "After hot plug, online NVM seciton num is: "$NODE1_SECTION_NEED
echo "Need to offline DRAM seciton(block): "$NODE0_OFF
echo "Need to offline NVM section(block): "$NODE1_OFF
fi

#判断大小的情况，保证要关闭的section是一个大于0的数值
if [ $((NODE0_SECTION_NEED)) -gt $((BLOCK_NODE0)) ]; 
then
echo "There is not enough DRAM to meet the conditions."
cat $NODE/node0/meminfo | grep MemFree
exit
elif [ $((NODE1_SECTION_NEED)) -gt $((BLOCK_NODE1)) ];
then
echo "There is not enough NVM to meet the conditions."
cat $NODE/node1/meminfo | grep MemFree
exit
fi

RESET_DRAM(){
echo "Reset offline DRAM to online."
for ((cur = 0,access_num = 0;;cur += 1)); #当前指针一>直往下指
do
        #如果访问section个数等于最大section个数了,退出shell
        if [ $access_num -eq $BLOCK_NODE0 ];
        then
                #echo $access_num $BLOCK_NODE0
                echo "All of DRAM section is online now."
                exit
        fi
        dir_name=$NODE/node0/memory$cur
        if [ ! -d "$dir_name" ];
        then
                #对应标号的section不存在,让cur继续
                continue;
        else
                #找到对应目录
                ((access_num++));
                echo online > $dir_name/state
        fi
done
}

RESET_NVM(){
echo "Reset offline NVM to online."
for ((cur = 0,access_num = 0;;cur += 1)); #当前指针一>直往下指
do
        #如果访问section个数等于最大section个数了,退出shell
        if [ $access_num -eq $BLOCK_NODE1 ];
        then
                #echo $access_num $BLOCK_NODE0
                echo "All of NVM section is online now."
                exit
        fi
        dir_name=$NODE/node1/memory$cur
        if [ ! -d "$dir_name" ];
        then
                #对应标号的section不存在,让cur继续
                continue;
        else
                #找到对应目录
                ((access_num++));
                echo online > $dir_name/state
        fi
done
}

if [ $INPUT_DRAM_MEM_BYTE -eq "0" ];
then
RESET_DRAM
RESET_NVM
exit
fi

#这里要注意一个问题，对应block大小和真实序号有差别
for ((cur = 0,access_num = 0,off_num = 0;;cur += 1)); #当前指针一直往下指
do	
	#如果关闭section数满足要求了,退出
	if [ $off_num -eq $NODE0_OFF ];
	then
		break;
	fi
	#如果访问section个数等于最大section个数了,退出shell
	if [ $access_num -eq $BLOCK_NODE0 ];
	then
		#echo $access_num $BLOCK_NODE0 $off_num $NODE0_OFF
		echo "The number of DRAM section that can be turned off does not satisfy the conditions."
		RESET_DRAM
		exit
	fi
	dir_name=$NODE/node0/memory$cur
	if [ ! -d "$dir_name" ];
	then	
		#对应标号的section不存在,让cur继续
		continue;
	else
		#找到对应目录
		((access_num++));
		echo offline > $dir_name/state
		if [ $? -eq 0 ];
		then
			#处理成功，off_num加1
			((off_num++));
		fi
	fi
done

for ((cur = 0,access_num = 0,off_num = 0;;cur += 1)); #当前指针一直往下指
do	
	#如果关闭section数满足要求了,退出
	if [ $off_num -eq $NODE1_OFF ];
	then
		break;
	fi
	#如果访问section个数等于最大section个数了,退出shell
	if [ $access_num -eq $BLOCK_NODE1 ];
	then
		#echo $access_num $BLOCK_NODE0 $off_num $NODE0_OFF
		echo "The number of NVM section that can be turned off does not satisfy the conditions."
		RESET_DRAM
		RESET_NVM
		exit
	fi
	dir_name=$NODE/node1/memory$cur
	if [ ! -d "$dir_name" ];
	then	
		#对应标号的section不存在,让cur继续
		continue;
	else
		#找到对应目录
		((access_num++));
		echo offline > $dir_name/state
		if [ $? -eq 0 ];
		then
			#处理成功，off_num加1
			((off_num++));
		fi
	fi
done
