#!/bin/bash

AUTOUPDATE=${AUTOUPDATE:-Y}
SENDTYPE=${SENDTYPE:-null}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN:-null}
TELEGRAM_USERID=${TELEGRAM_USERID:-null}
WXSENDKEY=${WXSENDKEY:-null}
BUTTON_URL=${BUTTON_URL:-null}
LOGININFO=${LOGININFO:-N}
export TELEGRAM_TOKEN TELEGRAM_USERID BUTTON_URL

# 使用 jq 提取 JSON 数组，并将其加载为 Bash 数组
# 从 URL 获取 JSON 并提取 accounts 数组
json_data=$(curl -s -f "${HOSTS_URL}") || { echo "Failed to fetch HOSTS_URL" >&2; exit 1; }

hosts_info=()
while IFS= read -r line; do
  hosts_info+=("$line")
done < <(echo "$json_data" | jq -c '.accounts[]')

summary=""
for info in "${hosts_info[@]}"; do

  user=$(echo $info | jq -r ".username")
  pass=$(echo $info | jq -r ".password")
  panelnum=$(echo $info | jq -r ".panelnum")
  # 如果 host/port 未直接提供，可根据需要构造（示例逻辑）
  host="s${panelnum}.serv00.com"  # 示例：根据 panelnum 动态生成 host
  port=22                              # 示例：固定 SSH 端口
  
  if [[ "$AUTOUPDATE" == "Y" ]]; then
    script="/home/$user/serv00-play/keepalive.sh autoupdate ${SENDTYPE} \"${TELEGRAM_TOKEN}\" \"${TELEGRAM_USERID}\" \"${WXSENDKEY}\" \"${BUTTON_URL}\" \"${pass}\""
  else
    script="/home/$user/serv00-play/keepalive.sh noupdate ${SENDTYPE} \"${TELEGRAM_TOKEN}\" \"${TELEGRAM_USERID}\" \"${WXSENDKEY}\" \"${BUTTON_URL}\" \"${pass}\""
  fi
  output=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "bash -s" <<<"$script")

  echo "output:$output"

  if echo "$output" | grep -q "keepalive.sh"; then
    echo "登录成功"
    msg="🟢主机 ${host}, 用户 ${user}， 登录成功!\n"
  else
    echo "登录失败"
    msg="🔴主机 ${host}, 用户 ${user}， 登录失败!\n"
    chmod +x ./tgsend.sh
    export PASS=$pass
    ./tgsend.sh "Host:$host, user:$user, 登录失败，请检查!"
  fi
  summary=$summary$(echo -n $msg)
done

if [[ "$LOGININFO" == "Y" ]]; then
  chmod +x ./tgsend.sh
  ./tgsend.sh "$summary"
fi
