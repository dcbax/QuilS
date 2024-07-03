#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo -e "\033[31m此脚本需要以root用户权限运行。\033[0m"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    echo "请复制此命令在根目录运行 chmod +x QuilS.sh && ./QuilS.sh"
    exit 1
fi

# 定义脚本保存路径
SCRIPT_PATH="$HOME/QuilS.sh"

# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="quili"
    local profile_file="$HOME/.profile"

    # 检查快捷键是否已经设置
    if ! grep -q "$alias_name" "$profile_file"; then
        echo "设置快捷键 '$alias_name' 到 $profile_file"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$profile_file"
        # 添加提醒用户激活快捷键的信息
        echo -e "\033[32m快捷键 '$alias_name' 已设置。请运行 'source $profile_file' 来激活快捷键，或重新登录。\033[0m"
    else
        echo "快捷键 '$alias_name' 已经设置在 $profile_file。"
        echo "如果快捷键不起作用，请尝试运行 'source $profile_file' 或重新登录。"
    fi
}


# 更新并升级Ubuntu软件包
function update_upgrade() {
    echo -e "\033[33m=========================== 安装过程有弹窗 按回车或按提示输入 Y ============================\033[0m"
    sleep 3
    sudo apt update && sudo apt -y upgrade 
    echo -e "\033[32mUbuntu软件包已更新并升级\033[0m"
    
    # 开启BBR加速
    wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh -y
    lsmod | grep bbr
    echo "返回：tcp_bbr 20480 2表示BBR开启成功"
}

# 安装必要的组件
function install_necessary_components() {
    sudo apt install git bison screen binutils gcc make bsdmainutils -y
    echo -e "\033[32m必要的组件已安装⏳\033[0m"
    
    # 增加swap交换空间
    sudo swapon --show
    echo "增加swap交换空间,建议是内存的2倍⏳"
    read -p "请输入要增加的swap空间大小（例如2G、4G、8G等）: " swap_size
    sudo mkdir -p /swap
    sudo fallocate -l "$swap_size" /swap/swapfile
    sudo chmod 600 /swap/swapfile
    sudo mkswap /swap/swapfile
    sudo swapon /swap/swapfile
    echo "/swap/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab
    sudo swapon --show
    echo -e "\033[32mSwap空间已增加并配置成功\033[0m"
}

# 安装Go
function install_gvm() {
    wget https://go.dev/dl/go1.22.4.linux-amd64.tar.gz
    sudo tar -xvf go1.22.4.linux-amd64.tar.gz || { echo -e "\033[31mFailed to extract Go! Exiting...\033[0m"; exit 1; }
    sudo mv go /usr/local || { echo -e "\033[31mFailed to move Go! Exiting...\033[0m"; exit 1; }
    sudo rm go1.22.4.linux-amd64.tar.gz || { echo -e "\033[31mFailed to remove downloaded archive! Exiting...\033[0m"; exit 1; }

    echo -e "\033[32mSetting Go environment variables...\033[0m"
    sleep 5

    # 设置Go环境变量
    if ! grep -q 'GOROOT=/usr/local/go' ~/.bashrc; then
        echo 'GOROOT=/usr/local/go' >> ~/.bashrc
    fi

    if ! grep -q "GOPATH=$HOME/go" ~/.bashrc; then
        echo "GOPATH=$HOME/go" >> ~/.bashrc
    fi

    if ! grep -q 'PATH=$GOPATH/bin:$GOROOT/bin:$PATH' ~/.bashrc; then
        echo 'PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.bashrc
    fi

    echo -e "\033[32mSourcing .bashrc to apply changes\033[0m"
    source ~/.bashrc
    sleep 5

    # 检查Go版本
    go version
    sleep 5

    # 安装gRPCurl
    echo -e "\033[32mInstalling gRPCurl...\033[0m"
    sleep 1
    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
}

# 构建并配置服务
function build_and_setup_service() {
# Step 5:Determine the ExecStart line based on the architecture
# Get the current user's home directory
HOME=$(eval echo ~$HOME_DIR)

# Use the home directory in the path
NODE_PATH="$HOME/ceremonyclient/node"
EXEC_START="$NODE_PATH/release_autorun.sh"

# Step 6:Create Ceremonyclient Service
echo "⏳ 节点加进系统服务Creating Ceremonyclient Service"
sleep 2  # Add a 2-second delay

# Check if the file exists before attempting to remove it
if [ -f "/lib/systemd/system/ceremonyclient.service" ]; then
    # If the file exists, remove it
    rm /lib/systemd/system/ceremonyclient.service
    echo "ceremonyclient.service file removed."
else
    # If the file does not exist, inform the user
    echo "ceremonyclient.service file does not exist. No action taken."
fi

sudo tee /lib/systemd/system/ceremonyclient.service > /dev/null <<EOF
[Unit]
Description=Ceremony Client Go App Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=$NODE_PATH
ExecStart=$EXEC_START

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ceremonyclient

# Step 7: Start the ceremonyclient service
echo "✅节点已添加进系统服务 将以服务运行Starting Ceremonyclient Service"
sleep 1  # Add a 1-second delay
sudo service ceremonyclient start


    echo -e "\033[32m====================================== 安装完成✅ ========================================\033[0m"
}

# 节点安装与运行
function install_node() {
    echo "Adjusting network buffer sizes..."
    if ! grep -q "^net.core.rmem_max=600000000$" /etc/sysctl.conf; then
        echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.rmem_max=600000000" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi
    if ! grep -q "^net.core.wmem_max=600000000$" /etc/sysctl.conf; then
        echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.wmem_max=600000000" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi
    sudo sysctl -p

    echo "sysctl配置已重新加载"

    echo "⏳下载挖矿节点 Ceremonyclient"
    sleep 1
    git clone https://github.com/quilibriumnetwork/ceremonyclient
    echo "⏳更新挖矿节点"
    cd ~/ceremonyclient/node && git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git && git pull && git checkout release
    echo -e "\033[32m====================================== 安装完成✅ =========================================\033[0m"
    echo -e "\033[33m============================== 准备跳转到screen窗口运行节点✅ =============================\033[0m"
    sleep 2
    echo -e "\033[33m============================== 若不直接运行节点在此按 ctrl+C ✅ =============================\033[0m"
    sleep 3

    cd ceremonyclient/node
    chmod +x release_autorun.sh
    screen -dmS Quili bash -c './release_autorun.sh' && screen -r Quili
}

# 查看服务版本状态
function check_ceremonyclient_service_status() {
    systemctl status ceremonyclient
}

# 查看服务版本节点日志
function view_logs() {
    sudo journalctl -f -u ceremonyclient.service
}

# 查看常规版本节点日志
function check_service_status() {
    screen -r Quili
}

# 查看在运行中的screen
function list_screen_sessions() {
    screen -list
}

# 杀死screen进程
function kill_screen_sessions() {
    pkill screen
}

# 启动节点
function start_node() {
    cd ~/ceremonyclient/node
    chmod +x release_autorun.sh
    screen -dmS Quili bash -c './release_autorun.sh' && screen -r Quili
}

# 提供给用户的菜单选项
PS3='请选择一个操作: '
options=("1. 更新并升级Ubuntu软件包" "2. 安装必要的组件" "3. 安装Go" "4. 安装节点并以screen运行" "5. 构建并配置服务" "6. 查看服务状态" "7. 查看服务日志" "8. 查看节点日志" "9. 查看运行中的screen" "10. 杀死screen进程" "11. 退出" "12. 启动节点")
while true; do
    echo -e "\033[33m按 ctrl+C 退出菜单。\033[0m"
    select opt in "${options[@]}"
    do
        case $opt in
            "1. 更新并升级Ubuntu软件包")
                update_upgrade
                break
                ;;
            "2. 安装必要的组件")
                install_necessary_components
                break
                ;;
            "3. 安装Go")
                install_gvm
                break
                ;;
            "4. 安装节点并以screen运行")
                install_node
                break
                ;;
            "5. 构建并配置服务")
                build_and_setup_service
                break
                ;;
            "6. 查看服务状态")
                check_ceremonyclient_service_status
                break
                ;;
            "7. 查看服务日志")
                view_logs
                break
                ;;
            "8. 查看节点日志")
                check_service_status
                break
                ;;
            "9. 查看运行中的screen")
                list_screen_sessions
                break
                ;;
            "10. 杀死screen进程")
                kill_screen_sessions
                break
                ;;
            "11. 退出")
                exit 0
                ;;
            "12. 启动节点")
                start_node
                ;;
            *) echo -e "\033[31m无效选项，请重试。\033[0m";;
        esac
    done
done
