set -x
set -e
# add cf command to provision cloudant with name cloudant-mqtt-watson and upload document
# cf create-service
#
# bx target -s dev

cd MqttWatsonEventProvider/ && cf push
# TODO, the mqtt-watson app doesn't receover well, the Cloudant Document with ID <uuid>/msgReceived has to be deleted before restarting/redeploying
cd ..
sleep 5
export provider_url="$(cf apps | grep mqtt-watson | awk '{print $6}' | tr -d ',' | xargs echo -n )"
# Clean up / Deploy again
# ./uninstall.sh openwhisk.ng.bluemix.net $(wsk property get --auth | awk '{print $3}') "wsk"
# wsk trigger delete subscription-event-trigger
./install.sh openwhisk.ng.bluemix.net "$(wsk property get --auth | awk '{print $3'})" "wsk" "http://${provider_url}/mqtt-watson"
sleep 5
echo "Create trigger that'll be invoked each time a message is received at given topic"
# wsk trigger delete subscription-event-trigger
# wsk package delete mqtt-watson
wsk trigger create mqttMsgReceived \
  --feed mqtt-watson/feed-action \
  --param topic "iot-2/type/${IOT_DEVICE_TYPE}/id/${IOT_DEVICE_ID}/evt/fromClient/fmt/json" \
  --param url "ssl://${IOT_ORG}.messaging.internetofthings.ibmcloud.com:8883" \
  --param username "${IOT_API_KEY}" \
  --param password "${IOT_AUTH_TOKEN}" \
  --param client "a:${IOT_ORG}:wskmqttsub_$(date +%s)"

echo "Create rule to invoke action when MQTT messages are received"
bx wsk rule create mqttRule mqttMsgReceived translateText

echo "parse app logs to determine if the feed is able to connect to MQTT broker"
cf logs mqtt-watson --recent
