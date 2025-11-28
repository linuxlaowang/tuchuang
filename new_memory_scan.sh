#! /bin/bash
# description: checklist脚本
# author:wyl
# 过滤出的“null” 代表的是虚机无隔离配置项
# 过滤出的“wucfg” 代表的是物理机 无总内存配置项
# 仅支持debian系统

#版本号
VERSION='1.0.1'

# 配置信息路径
DEVICE_UPDATE="/data/local/device_update"

# 定义变量
## 物理机层
DEVICE_IP=""                # 物理机IP
# 定义关联数组，顺序不规定。通过key去找值
#declare -A cloudphone_memory
# 定义索引数组，适合严格按照顺序插入
declare -a cloudphone_memory=()
#容器层
VM_NUM=""                   # 虚机数量
VM_STATUS=""                # 虚机启动状态(1, 正常;0 ,异常)，比如，3个容器：1:1:1
MEM_LIMIT=""                # 内存限制,按照容器顺序，逗号分隔，比如，3个容器，内存隔离为3000M：30000:30000:30000
TOTALMEM=""                 # 总内存
ARV_TOTAL=""                # 平均内存
MEM_RESULT=""               # 内存使用情况(1, 正常;0 ,异常)，


# 获取物理IP和mac地址
function getDeviceIp() {
    #DEVICE_IP=$(ifconfig br0|sed  -rn '2s/^[^0-9]+([0-9.]+) .*$/\1/p')
    DEVICE_IP=$(ifconfig | grep -w "inet" | grep -v "127.0.0.1" | awk '{print $2}' | head -n 1)
}

# 获取虚机数量
function getVmNum() {
    VM_NUM=$(ps -ef | grep lxc-start|grep -v grep|wc -l)
}

# 获取虚机状态
function getVmStatus() {
    local STATUS=""
    for i in $(lxc-ls -f|grep -v STATE|awk '{print $2}'); do
        if [ "$i" == "RUNNING" ]; then
            STATUS=$(echo "${STATUS}:1")
        else
            STATUS=$(echo "${STATUS}:0")
        fi
    done
    VM_STATUS=$(echo $STATUS|sed 's/^://')
}



function getMemoryScan() {
    local conf="/lib/systemd/system/manage-main.service"
    local total unit valuebak unitbak line avg mem result="" vm

    # 读取 MemoryLimit 行
	line=$(grep ^MemoryLimit "$conf" 2>/dev/null | tail -n 1) || { TOTALMEM="wucfg";return; }
    if [[ "$line" =~ ([0-9]+)([MG]) ]]; then
        total="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
        [[ "$unit" == "G" ]] && total=$((total * 1024))
    else
        TOTALMEM="wucfg"
        return
    fi

    TOTALMEM=$total  # 设置外部变量

    # 容器名转数组（兼容一行多个）
    #read -ra vms <<< "$(lxc-ls)"   注释，lxc-ls 在交互式与非交互式输出格式不一致
    vms=($(lxc-ls))
    local count=${#vms[@]}
if [ $count -eq 0 ]; then
   # echo "count 为 0，退出函数"
    return  # 退出当前函数，脚本继续执行后续内容
fi
#    COUNT=$(lxc-ls | wc -w)
    ARV_TOTAL=$((TOTALMEM / count))
    local index=0

    # 遍历容器
    for i in  ${vms[@]}; do

         mem_line=$(grep ^lxc.cgroup.memory.limit_in_bytes /data/lxc_container/container_$i.conf |tail -n 1| awk -F= '{print $2}' | tr -d " ")
        # 匹配数字和单位（M或G）
           if [[ -n "$mem_line" && "$mem_line" =~ ^([0-9]+)([MG])$ ]]; then
              valuebak="${BASH_REMATCH[1]}"
              unitbak="${BASH_REMATCH[2]}"
            # 转换为统一的MB单位
            if [[ "$unitbak" == "G" ]]; then
                mem=$((valuebak * 1024))  # 1G = 1024M
            else
                mem="$valuebak"  # 已经是M单位
            fi
           else
             mem="$mem_line"
          fi
         cloudphone_memory["$index"]=${mem:-null}
        if [[ -z "$mem" ]]; then
            MEM_RESULT+=":null"
        elif (( mem < ARV_TOTAL )); then
            MEM_RESULT+=":1"
        else
            MEM_RESULT+=":0"
        fi
        ((index++))
    done

    MEM_RESULT="${MEM_RESULT#:}"  # 去掉前导冒号
}



function getData() {

     getDeviceIp
     getVmNum
     getVmStatus
     getMemoryScan

    echo "$DEVICE_IP,$VM_NUM,$VM_STATUS,$TOTALMEM,$ARV_TOTAL,${cloudphone_memory[@]},$MEM_RESULT"

}

function main() {
    getData
}

main

