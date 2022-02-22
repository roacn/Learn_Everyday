#!/bin/bash
# URL:https://github.com/roacn/build-actions
# Description:AutoUpdate for Openwrt
# Author: Ss.
# Please use the PVE command line to run the shell script.
# 个人Github地址（自行更改）
export Apidz="roacn/build-actions"
# release的tag名称（自行更改）
export Tag_Name="AutoUpdate-lxc"
# 固件搜索正则表达式（自行更改）
export Firmware_Regex="18\.06.*?rootfs.*?\.img\.gz"
export Github_API="https://api.github.com/repos/${Apidz}/releases/tags/${Tag_Name}"
export Release_Download_URL="https://github.com/${Apidz}/releases/download/${Tag_Name}"
export Openwrt_Path="/tmp/openwrt"
export Download_Path="/tmp/openwrt/download"
export Creatlxc_Path="/tmp/openwrt/creatlxc"
# pause
pause(){
    read -n 1 -p " Press any key to continue... " input
    if [[ -n ${input} ]]; then
        echo -e "\b\n"
    fi
}
# 字体颜色设置
TIME(){
[[ -z "$1" ]] && {
    echo -ne " "
} || {
    case $1 in
    r) export Color="\e[31;1m";;
    g) export Color="\e[32;1m";;
    b) export Color="\e[34;1m";;
    y) export Color="\e[33;1m";;
    z) export Color="\e[35;1m";;
    l) export Color="\e[36;1m";;
    esac
    [[ $# -lt 2 ]] && echo -e "\e[36m\e[0m ${1}" || echo -e "\e[36m\e[0m ${Color}${2}\e[0m"
    }
}
# 更新OpenWrt CT模板
release_chose(){
    releases=`egrep -o "${Firmware_Regex}" ${Download_Path}/Github_Tags | uniq`
    TIME g "Github云端固件"
    echo "${releases}"
    choicesnum=`echo "${releases}" | wc -l`
    while :; do
        read -t 30 -p " 请选择要下载的固件[n，默认n=1，即倒数第1行]：" release
        release=${release:-1}
        n0=`echo ${release} | sed 's/[0-9]//g'`
        if [[ ! -z $n0 ]]; then
            TIME r "输入错误，请输入数字！"
        elif [[ ${release} -eq 0 ]] || [[ ${release} -gt ${choicesnum} ]];then
            TIME r "输入超出范围，请重新输入！"
        else
            echo "${releases}" | tail -n ${release} | head -n 1 > ${Download_Path}/DOWNLOAD_URL
            TIME g "下载固件：$(cat ${Download_Path}/DOWNLOAD_URL)"
            break
        fi
    done
}
update_CT_Templates(){
    [[ ! -d ${Download_Path} ]] && mkdir -p ${Download_Path} || rm -rf ${Download_Path}/*
    TIME y "下载OpenWrt固件"
    TIME g "获取固件API信息..."
    wget -q ${Github_API} -O ${Download_Path}/Github_Tags > /dev/null 2>&1
    if [[ $? -ne 0 ]];then
        wget -q https://pd.zwc365.com/${Release_Download_URL}/Github_Tags -O ${Download_Path}/Github_Tags > /dev/null 2>&1
        if [[ $? -ne 0 ]];then
            wget -q https://ghproxy.com/${Release_Download_URL}/Github_Tags -O ${Download_Path}/Github_Tags > /dev/null 2>&1
            if [[ $? -ne 0 ]];then
                TIME r "获取固件API信息失败，请检测网络，或者网址是否正确！"
                echo
                exit 1
            else
                TIME g "获取固件API信息成功！"
            fi
        else
            TIME g "获取固件API信息成功！"
        fi
    else
        TIME g "获取固件API信息成功！"
    fi
    release_chose
    [ -s ${Download_Path}/DOWNLOAD_URL ] && {
    wget --progress=bar ${Release_Download_URL}/$(cat ${Download_Path}/DOWNLOAD_URL) -O ${Download_Path}/openwrt.rootfs.img.gz > /dev/null 2>&1
    if [[ $? -ne 0 ]];then
        wget --progress=bar https://pd.zwc365.com/${Release_Download_URL}/$(cat ${Download_Path}/DOWNLOAD_URL) -O ${Download_Path}/openwrt.rootfs.img.gz > /dev/null 2>&1
        if [[ $? -ne 0 ]];then
            wget --progress=bar https://ghproxy.com/${Release_Download_URL}/$(cat ${Download_Path}/DOWNLOAD_URL) -O ${Download_Path}/openwrt.rootfs.img.gz  > /dev/null 2>&1
            if [[ $? -ne 0 ]];then
                TIME r "获取固件失败，请检测网络，或者网址是否正确！"
                echo
                exit 1
            else
                TIME g "固件镜像：下载成功！"
            fi
        else
            TIME g "固件镜像：下载成功！"
        fi
    else
        TIME g "固件镜像：下载成功！"
    fi
    }
    imgsize=`ls -l ${Download_Path}/openwrt.rootfs.img.gz | awk '{print $5}'`
    TIME g "固件镜像：${imgsize}字节"
    echo
    TIME y "更新OpenWrt CT模板"
    TIME g "解包OpenWrt img镜像..."
    cd ${Download_Path} && gzip -d openwrt.rootfs.img.gz && unsquashfs openwrt.rootfs.img
    TIME g "CT模板：上传至/var/lib/vz/template/cache目录..."
    if [[ -f /var/lib/vz/template/cache/openwrt.rootfs.tar.gz ]]; then
        rm -f /var/lib/vz/template/cache/openwrt.rootfs.tar.gz
    fi
    cd ${Download_Path}/squashfs-root && tar zcf /var/lib/vz/template/cache/openwrt.rootfs.tar.gz ./* && cd ../.. && rm -rf ${Download_Path}
    TIME g "CT模板：上传成功！"
    ctsize=`ls -l /var/lib/vz/template/cache/openwrt.rootfs.tar.gz | awk '{print $5}'`    
    TIME g "CT模板：${ctsize}字节"
}
pct_id(){
    echo
    while :; do
        read -t 30 -p " 请输入 OpenWrt 容器ID[默认100]：" id || echo
        id=${id:-100}
        n1=`echo ${id} | sed 's/[0-9]//g'`
        if [[ ! -z $n1 ]]; then
            TIME r "输入错误，请重新输入！"
        elif [[ ${id} -lt 100 ]]; then
            TIME r "当前输入ID<100，请重新输入！"
        else
            break
        fi
    done
}
pct_hostname(){
    echo
    while :; do
        read -t 30 -p " 请输入 OpenWrt 容器名称[默认OpenWrt]：" hostname || echo
        hostname=${hostname:-OpenWrt}
        n2=`echo ${hostname} | sed 's/[a-zA-Z0-9]//g' | sed 's/[.-_]//g'`
        if [[ ! -z $n2 ]]; then
            TIME r "输入错误，请重新输入！"
        else
            break
        fi
    done
}
pct_rootfssize(){
    echo
    while :; do
        read -t 30 -p " 请输入 OpenWrt 分区大小[GB，默认2]：" rootfssize || echo
        rootfssize=${rootfssize:-2}
        n3=`echo ${rootfssize} | sed 's/[0-9]//g'`
        if [[ ! -z $n3 ]]; then
            TIME r "输入错误，请重新输入！"
        elif [[ ${rootfssize} == 0 ]]; then
            TIME r "不能为0，请重新输入！"
        else
            break
        fi
    done
}
pct_cores(){
    echo
    while :; do
        read -t 30 -p " 请输入 OpenWrt CPU核心数[默认4]：" cores || echo
        cores=${cores:-4}
        n4=`echo ${cores} | sed 's/[0-9]//g'`
        if [[ ! -z $n4 ]]; then
            TIME r "输入错误，请重新输入！"
        elif [[ ${cores} == 0 ]]; then
            TIME r "不能为0，请重新输入！"
        else
            break
        fi
    done
}
pct_memory(){
    echo
    while :; do
        read -t 30 -p " 请输入 OpenWrt 内存大小[MB，默认2048]：" memory || echo
        memory=${memory:-2048}
        n5=`echo ${memory} | sed 's/[0-9]//g'`
        if [[ ! -z $n5 ]]; then
            TIME r "输入错误，请重新输入！"
        elif [[ ${memory} == 0 ]]; then
            TIME r "不能为0，请重新输入！"
        else
            break
        fi
    done
}
pct_net(){
    echo
    while :; do
        read -t 30 -p " OpenWrt 是否有eth0与eth1[y/Y或n/N，默认y]：" net || echo
        net=${net:-y}
        case ${net} in
        y|Y)
            cat > ${Creatlxc_Path}/creat_openwrt <<-EOF
		pct create ${id} \\
		local:vztmpl/openwrt.rootfs.tar.gz \\
		--rootfs local-lvm:${rootfssize} \\
		--ostype unmanaged \\
		--hostname ${hostname} \\
		--arch amd64 \\
		--cores ${cores} \\
		--memory ${memory} \\
		--swap 0 \\
		--net0 bridge=vmbr0,name=eth0 \\
		--net1 bridge=vmbr1,name=eth1 \\
		--unprivileged 0 \\
		--features nesting=1
		EOF
            break
        ;;
        n|N)
            cat > ${Creatlxc_Path}/creat_openwrt <<-EOF
		pct create ${id} \\
		local:vztmpl/openwrt.rootfs.tar.gz \\
		--rootfs local-lvm:${rootfssize} \\
		--ostype unmanaged \\
		--hostname ${hostname} \\
		--arch amd64 \\
		--cores ${cores} \\
		--memory ${memory} \\
		--swap 0 \\
		--net0 bridge=vmbr0,name=eth0 \\
		--unprivileged 0 \\
		--features nesting=1
		EOF
            break
        ;;
        *)
            TIME r "输入错误，请重新输入！"
        ;;
        esac
    done
    if [[ -n `ls /dev/disk/by-id | grep "${id}--disk"` ]]; then
        cat > ${Creatlxc_Path}/destroy_openwrt <<-EOF
	pct destroy ${id} --destroy-unreferenced-disks 1 --purge 1 --force 1
	EOF
    fi
}
# 创建lxc容器
creat_lxc_openwrt1(){
    echo
    [[ ! -d ${Creatlxc_Path} ]] && mkdir -p ${Creatlxc_Path} || rm -rf ${Creatlxc_Path}/*
    TIME y "开始创建OpenWrt lxc容器"
    pct_id
    pct_hostname
    pct_rootfssize
    pct_cores
    pct_memory
    pct_net
}
creat_lxc_openwrt2(){
    if [[ -f ${Creatlxc_Path}/destroy_openwrt ]]; then
        TIME r "${id}容器已经存在！"
        while :; do
            read -t 30 -p " 是否删除${id}容器，然后继续？[y/Y或n/N，默认y]：" creatlxc || echo
            creatlxc=${creatlxc:-y}
            case ${creatlxc} in
            y|Y)
                echo
                TIME g "正在删除${id}容器..."
                bash ${Creatlxc_Path}/destroy_openwrt
                break
            ;;
            n|N)
                menu
                break
            ;;
            *)
                TIME r "输入错误，请重新输入！"
            ;;
            esac
        done
    fi
    [[ -f ${Creatlxc_Path}/creat_openwrt ]] && echo && TIME g "正在创建新容器..." && bash ${Creatlxc_Path}/creat_openwrt && echo && TIME g "lxc容器OpenWrt创建成功！" || TIME r "pct命令不存在或执行错误！"
}
# 清空文件
clean_files(){
    [[ -d ${Openwrt_Path} ]] && rm -rf ${Openwrt_Path}
}
# 主界面
menu(){
    clear
    #[[ ! -d ${Openwrt_Path} ]] && mkdir -p ${Openwrt_Path}
    echo
    TIME r "************OpenWrt自动升级脚本**************"
    TIME y "*      1. 更新CT模板 + 创建LXC容器          *"
    TIME g "*      2. 更新CT模板                        *"
    TIME g "*      3. 创建LXC容器                       *"
    TIME l "*      0. 退出                              *"
    TIME r "*********************************************"
    echo
    read -t 60 -p " 请输入操作选项[1]、[2]、[3]或[0]：" menuid
    menuid=${menuid:-0}
    case ${menuid} in
    1)
        update_CT_Templates
        creat_lxc_openwrt1
        echo
        creat_lxc_openwrt2
        echo
        TIME y "10s后即将清理残留文件..."
        sleep 10
        clean_files
        echo
        pause
        menu
    ;;
    2)
        update_CT_Templates
        echo
        pause
        menu
    ;;
    3)
        creat_lxc_openwrt1
        echo
        creat_lxc_openwrt2
        echo
        pause
        menu
    ;;
    0)
        clean_files
        clear
        exit 0
    ;;
    *)
        menu
    ;;
    esac
}
# 脚本运行！
cd /tmp
menu