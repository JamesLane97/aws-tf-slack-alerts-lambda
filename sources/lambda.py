#!/usr/bin/python3.11
import urllib3
import json, os

http = urllib3.PoolManager()
ENV = os.environ["ENV"]
SLACK_WEBHOOK_URI = os.environ["SLACK_WEBHOOK_URI"]
SLACK_DISPLAY_USERNAME = os.environ["SLACK_DISPLAY_USERNAME"]
SLACK_CHANNEL = os.environ["SLACK_CHANNEL"]

def handler(event, context):
    sns_message = event["Records"][0]["Sns"]["Message"]

    # Check if message in an Alarm
    if ("AlarmArn" in sns_message) and ("AlarmName" in sns_message):
        if ENV == "DEBUG" or type(sns_message) == dict:
            sns_message_dict = sns_message
        else:
            sns_message_dict = json.loads(sns_message)
        """
        Format the alarm SNS message as a Slack message
        """
        MSG_TEXT = (
        f"*Alarm:* {sns_message_dict['AlarmName']}\n"
        f"*Description*\n"
        f"{sns_message_dict['AlarmDescription']}\n"
        f"*Details*\n"
        f"Alarm raised by: *{sns_message_dict['Trigger']['Namespace']}*, in account: *{sns_message_dict['AWSAccountId']}*, *{sns_message_dict['Region']}* region.\n"
        f"Metric failing the alarm: *{sns_message_dict['Trigger']['MetricName']}*\n"
        f"State: {sns_message_dict['NewStateValue']} with Reason: {sns_message_dict['NewStateReason']}\n"
        f"Timestamp: {sns_message_dict['StateChangeTime']}\n"
        )
    # Check if message in not an Alarm
    elif ("Event Source" in sns_message) and (sns_message['Event Source'].lower() == 'db-instance'):
        if ENV == "DEBUG" or type(sns_message) == dict:
            sns_message_dict = sns_message
        else:
            sns_message_dict = json.loads(sns_message)
        """
        Format the alarm SNS message as a Slack message
        """
        MSG_TEXT = (
        f"*Event Source:* {sns_message_dict['Event Source']}\n"
        f"*Event Time:* {sns_message_dict['Event Time']}\n"
        f"*Identifier Link:* [{sns_message_dict['Source ID']}]({sns_message_dict['Identifier Link']})\n"
        f"*Source ID:* {sns_message_dict['Source ID']}\n"
        f"*Source ARN:* {sns_message_dict['Source ARN']}\n"
        f"*Event ID:* {sns_message_dict['Event ID']}{' - ' + sns_message_dict['Event ID'] if sns_message_dict['Event ID'] != sns_message_dict['Identifier Link'] else ''}\n"
        f"*Event Message:* {sns_message_dict['Event Message']}\n"
        )
    # Check if message came from ECS Service Action
    elif ("detail-type" in sns_message) and (sns_message['detail-type'] == 'ECS Service Action'):
        if ENV == "DEBUG" or type(sns_message) == dict:
            sns_message_dict = sns_message
        else:
            sns_message_dict = json.loads(sns_message)
        MSG_TEXT = (
            f"*ECS Service Action:* {sns_message_dict['detail-type']} - {sns_message_dict['detail']['eventName']}\n"
            f"\n"
            f"*Details*\n"
            f"Event Type: *{sns_message_dict['detail']['eventType']}*\n"
            f"Cluster ARN: *{sns_message_dict['detail']['clusterArn']}*\n"
            f"Created At: *{sns_message_dict['detail']['createdAt']}*\n"
            f"Resources: {', '.join(sns_message_dict['resources'])}\n"
        )
        if 'reason' in sns_message_dict['detail']:
            MSG_TEXT += f"Reason: *{sns_message_dict['detail']['reason']}*"

    # Message came from elsewhere, just pass it through
    else:
        MSG_TEXT = f"{sns_message}"

    MSG = {
        "channel": SLACK_CHANNEL,
        "username": SLACK_DISPLAY_USERNAME,
        "text": MSG_TEXT,
        "icon_emoji": ":rotating_light:",
    }

    encoded_msg = json.dumps(MSG).encode("utf-8")
    resp = http.request("POST", SLACK_WEBHOOK_URI, body=encoded_msg)
    print(
        {
            "message": MSG,
            "event": event,
            "status_code": resp.status,
            "response": resp.data,
        }
    )