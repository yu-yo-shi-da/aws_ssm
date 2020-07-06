#!/bin/bash

echo "----------------------------"

while true; do
  echo "~/.aws/credentialsのprofileを指定してください。（defaultの場合指定なし可）"
  read profile
  if [ -z $input ] ; then
    profile="default"
    break
  elif grep "\[${profile}\]" ~/.aws/credentials > /dev/null; then
    break
  fi
done

echo "IAMユーザ名を入力してください。"
read username

while true; do
  echo "接続するEC2インスタンスのIDを入力してください。"
  read id
  if [[ ${id} =~ ^i-([a-zA-Z0-9A0-zZ9]{8}|[a-zA-Z0-9A0-zZ9]{17})$ ]]; then
    break
  fi
done



while true; do
  echo "2FAのコードを入力してください。"
  read token
  if [[ ${token} =~ ^[0-9]{6} ]]; then
    break
  fi
done

echo "Connecting to " ${id} "..."

# get mfa arn
mfa_arn=`aws iam list-virtual-mfa-devices --profile ${profile} | jq -r '.VirtualMFADevices[].SerialNumber' | grep ${username}`

if [ $? -eq 1 ]; then
  echo "profileの指定、またはIAMユーザ名に誤りがあります。"
  exit 1
fi

# get credentials
credentials=`aws sts get-session-token --serial-number ${mfa_arn} --token-code ${token} --profile ${profile} --output json`
if [ $? -eq 1 ]; then
  echo "2FAコードが期限切れの可能性があります。""
  exit 1
fi

# set environment
export AWS_ACCESS_KEY_ID=`echo ${credentials} | jq -r '.Credentials.AccessKeyId'`
export AWS_SECRET_ACCESS_KEY=`echo ${credentials} | jq -r '.Credentials.SecretAccessKey'`
export AWS_SESSION_TOKEN=`echo ${credentials} | jq -r '.Credentials.SessionToken'`

# start session
aws ssm start-session --target ${id}
