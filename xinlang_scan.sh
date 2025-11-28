#! /bin/bash
# description: checklist脚本

# 仅支持debian系统

#版本号
VERSION='1.0.1'

# 配置信息路径
DEVICE_UPDATE="/data/local/device_update"

# 定义变量
## 物理机层
DEVICE_IP=""                # 物理机IP

## 容器层
VM_NUM=""                   # 虚机数量
VM_STATUS=""                # 虚机启动状态(1, 正常;0 ,异常)，比如，3个容器：1:1:1


# 获取物理IP和mac地址
function getDeviceIp() {
    DEVICE_IP=$(ifconfig br0|sed  -rn '2s/^[^0-9]+([0-9.]+) .*$/\1/p')
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
function getEMMCLifeTime() {
    # 获取eMMC的寿命信息
    if [ -f /sys/devices/platform/fe330000.sdhci/mmc_host/mmc1/mmc1:0001/life_time ]; then
       EMMCLifeTime=$(cat /sys/devices/platform/fe330000.sdhci/mmc_host/mmc1/mmc1:0001/life_time)
    else
       EMMCLifeTime="N/A"
    fi
}

function getEMMCPreEolInfo() {
    # 获取eMMC的预EOL信息
    if [ -f /sys/devices/platform/fe330000.sdhci/mmc_host/mmc1/mmc1:0001/pre_eol_info ]; then
        EMMCPreEolInfo=$(cat /sys/devices/platform/fe330000.sdhci/mmc_host/mmc1/mmc1:0001/pre_eol_info)
    else
        EMMCPreEolInfo="N/A"
    fi
}

function getData() {

     getDeviceIp
     getVmNum
     getVmStatus
     getEMMCLifeTime
     getEMMCPreEolInfo

    echo "$DEVICE_IP,$VM_NUM,$VM_STATUS,$EMMCLifeTime,$EMMCPreEolInfo"

}


function main() {
    getData
}

main
