#!/bin/bash

set -e

echo "=== OpenClaw 初始化脚本 ==="

# 创建必要的目录并确保权限正确
mkdir -p /home/node/.openclaw/workspace

# 检查配置文件是否存在，如果不存在则生成
if [ ! -f /home/node/.openclaw/openclaw.json ]; then
    echo "生成配置文件..."
    
    # 从环境变量读取配置参数
    MODEL_ID="${MODEL_ID}"
    BASE_URL="${BASE_URL}"
    API_KEY="${API_KEY}"
    TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
    FEISHU_APP_ID="${FEISHU_APP_ID}"
    FEISHU_APP_SECRET="${FEISHU_APP_SECRET}"
    DINGTALK_CLIENT_ID="${DINGTALK_CLIENT_ID}"
    DINGTALK_CLIENT_SECRET="${DINGTALK_CLIENT_SECRET}"
    DINGTALK_ROBOT_CODE="${DINGTALK_ROBOT_CODE:-$DINGTALK_CLIENT_ID}"
    DINGTALK_CORP_ID="${DINGTALK_CORP_ID}"
    DINGTALK_AGENT_ID="${DINGTALK_AGENT_ID}"
    QQBOT_APP_ID="${QQBOT_APP_ID}"
    QQBOT_CLIENT_SECRET="${QQBOT_CLIENT_SECRET}"
    WECOM_TOKEN="${WECOM_TOKEN}"
    WECOM_ENCODING_AES_KEY="${WECOM_ENCODING_AES_KEY}"
    WORKSPACE="${WORKSPACE}"
    OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT}"
    OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND}"
    OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN}"
    
    # 生成配置文件
    cat > /home/node/.openclaw/openclaw.json <<EOF
{
  "meta": {
    "lastTouchedVersion": "2026.1.29",
    "lastTouchedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
  },
  "update": {
    "checkOnStart": false
  },
  "models": {
    "mode": "merge",
    "providers": {
      "default": {
        "baseUrl": "$BASE_URL",
        "apiKey": "$API_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "$MODEL_ID",
            "name": "$MODEL_ID",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "default/$MODEL_ID"
      },
      "imageModel": {
        "primary": "default/$MODEL_ID"
      },
      "workspace": "$WORKSPACE",
      "compaction": {
        "mode": "safeguard"
      },
      "elevatedDefault": "full",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions",
    "tts": {
      "edge": {
        "voice": "zh-CN-XiaoxiaoNeural"
      }
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "channels": {
EOF

    # 添加 Telegram 配置（如果提供了 token）
    FIRST_CHANNEL=true
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        cat >> /home/node/.openclaw/openclaw.json <<EOF
    "telegram": {
      "dmPolicy": "pairing",
      "botToken": "$TELEGRAM_BOT_TOKEN",
      "groupPolicy": "allowlist",
      "streamMode": "partial"
    }
EOF
        FIRST_CHANNEL=false
    fi

    # 添加飞书配置（如果提供了 APP_ID 和 APP_SECRET）
    if [ -n "$FEISHU_APP_ID" ] && [ -n "$FEISHU_APP_SECRET" ]; then
        if [ "$FIRST_CHANNEL" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
    "feishu": {
      "enabled": true,
      "connectionMode": "websocket",
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "requireMention": true,
      "appId": "$FEISHU_APP_ID",
      "appSecret": "$FEISHU_APP_SECRET"
    }
EOF
        FIRST_CHANNEL=false
    fi

    # 添加钉钉配置（如果提供了 CLIENT_ID 和 CLIENT_SECRET）
    if [ -n "$DINGTALK_CLIENT_ID" ] && [ -n "$DINGTALK_CLIENT_SECRET" ]; then
        if [ "$FIRST_CHANNEL" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
    "dingtalk": {
      "enabled": true,
      "clientId": "$DINGTALK_CLIENT_ID",
      "clientSecret": "$DINGTALK_CLIENT_SECRET",
      "robotCode": "$DINGTALK_ROBOT_CODE",
      "corpId": "$DINGTALK_CORP_ID",
      "agentId": "$DINGTALK_AGENT_ID",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "messageType": "markdown",
      "debug": false
    }
EOF
        FIRST_CHANNEL=false
    fi

    # 添加 QQ 机器人配置（如果提供了 APP_ID 和 CLIENT_SECRET）
    if [ -n "$QQBOT_APP_ID" ] && [ -n "$QQBOT_CLIENT_SECRET" ]; then
        if [ "$FIRST_CHANNEL" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
    "qqbot": {
      "enabled": true,
      "appId": "$QQBOT_APP_ID",
      "clientSecret": "$QQBOT_CLIENT_SECRET"
    }
EOF
        FIRST_CHANNEL=false
    fi

    # 添加企业微信配置（如果提供了必需参数）
    if [ -n "$WECOM_TOKEN" ] && [ -n "$WECOM_ENCODING_AES_KEY" ]; then
        if [ "$FIRST_CHANNEL" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
    "wxwork": {
      "enabled": true,
      "token": "$WECOM_TOKEN",
      "encodingAesKey": "$WECOM_ENCODING_AES_KEY"
    }
EOF
    fi

    # 关闭 channels 对象
    cat >> /home/node/.openclaw/openclaw.json <<EOF
  },
  "gateway": {
    "port": $OPENCLAW_GATEWAY_PORT,
    "mode": "local",
    "bind": "$OPENCLAW_GATEWAY_BIND",
    "controlUi": {
      "allowInsecureAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "$OPENCLAW_GATEWAY_TOKEN"
    }
  },
  "plugins": {
    "entries": {
EOF

    # 添加 Telegram 插件配置（如果提供了 token）
    FIRST_PLUGIN=true
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "telegram": {
        "enabled": true
      }
EOF
        FIRST_PLUGIN=false
    fi

    # 添加飞书插件配置（如果提供了 APP_ID 和 APP_SECRET）
    if [ -n "$FEISHU_APP_ID" ] && [ -n "$FEISHU_APP_SECRET" ]; then
        if [ "$FIRST_PLUGIN" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "feishu": {
        "enabled": true
      }
EOF
        FIRST_PLUGIN=false
    fi

    # 添加钉钉插件配置（如果提供了 CLIENT_ID 和 CLIENT_SECRET）
    if [ -n "$DINGTALK_CLIENT_ID" ] && [ -n "$DINGTALK_CLIENT_SECRET" ]; then
        if [ "$FIRST_PLUGIN" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "dingtalk": {
        "enabled": true
      }
EOF
        FIRST_PLUGIN=false
    fi

    # 添加 QQ 机器人插件配置（如果提供了 APP_ID 和 CLIENT_SECRET）
    if [ -n "$QQBOT_APP_ID" ] && [ -n "$QQBOT_CLIENT_SECRET" ]; then
        if [ "$FIRST_PLUGIN" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "qqbot": {
        "enabled": true
      }
EOF
        FIRST_PLUGIN=false
    fi

    # 添加企业微信插件配置（如果提供了必需参数）
    if [ -n "$WECOM_TOKEN" ] && [ -n "$WECOM_ENCODING_AES_KEY" ]; then
        if [ "$FIRST_PLUGIN" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "openclaw-plugin-wecom": {
        "enabled": true
      }
EOF
    fi

    # 关闭 entries 对象
    cat >> /home/node/.openclaw/openclaw.json <<EOF
    },
    "installs": {
EOF

    # 添加飞书插件安装信息（如果提供了 APP_ID 和 APP_SECRET）
    FIRST_INSTALL=true
    if [ -n "$FEISHU_APP_ID" ] && [ -n "$FEISHU_APP_SECRET" ]; then
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "feishu": {
        "source": "npm",
        "spec": "@m1heng-clawd/feishu",
        "installPath": "/home/node/.openclaw/extensions/feishu",
        "installedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
      }
EOF
        FIRST_INSTALL=false
    fi

    # 添加钉钉插件安装信息（如果提供了 CLIENT_ID 和 CLIENT_SECRET）
    if [ -n "$DINGTALK_CLIENT_ID" ] && [ -n "$DINGTALK_CLIENT_SECRET" ]; then
        if [ "$FIRST_INSTALL" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "dingtalk": {
        "source": "npm",
        "spec": "https://github.com/soimy/clawdbot-channel-dingtalk.git",
        "installPath": "/home/node/.openclaw/extensions/dingtalk",
        "installedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
      }
EOF
        FIRST_INSTALL=false
    fi

    # 添加 QQ 机器人插件安装信息（如果提供了 APP_ID 和 CLIENT_SECRET）
    if [ -n "$QQBOT_APP_ID" ] && [ -n "$QQBOT_CLIENT_SECRET" ]; then
        if [ "$FIRST_INSTALL" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "qqbot": {
        "source": "path",
        "sourcePath": "/home/node/.openclaw/qqbot",
        "installPath": "/home/node/.openclaw/extensions/qqbot",
        "installedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
      }
EOF
        FIRST_INSTALL=false
    fi

    # 添加企业微信插件安装信息（如果提供了必需参数）
    if [ -n "$WECOM_TOKEN" ] && [ -n "$WECOM_ENCODING_AES_KEY" ]; then
        if [ "$FIRST_INSTALL" = false ]; then
            echo "," >> /home/node/.openclaw/openclaw.json
        fi
        cat >> /home/node/.openclaw/openclaw.json <<EOF
      "openclaw-plugin-wecom": {
        "source": "npm",
        "spec": "https://github.com/sunnoy/openclaw-plugin-wecom.git",
        "installPath": "/home/node/.openclaw/extensions/openclaw-plugin-wecom",
        "installedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
      }
EOF
    fi

    # 关闭 installs 和 plugins 对象
    cat >> /home/node/.openclaw/openclaw.json <<EOF
    }
  }
}
EOF

    echo "✅ 配置文件已生成"
else
    echo "配置文件已存在，跳过生成"
fi

# 确保所有文件和目录的权限正确
chown -R node:node /home/node/.openclaw

echo "=== 初始化完成 ==="
echo "当前使用模型: default/$MODEL_ID"
echo "Gateway 端口: $OPENCLAW_GATEWAY_PORT"
echo "Gateway 绑定: $OPENCLAW_GATEWAY_BIND"

# 启动 OpenClaw Gateway（切换到 node 用户）
echo "=== 启动 OpenClaw Gateway ==="
exec gosu node env HOME=/home/node openclaw gateway --verbose
