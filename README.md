# OpenWhisk MQTT Package for Watson IoT
==========================

This package provides a mechanism to trigger OpenWhisk actions when messages are received on an MQTT topic in the Watson IoT Platform. It sets up a Cloud Foundry application that can be configured to listen to one or more topics on a persistent connection, then invokes the registered actions as a feed action.

You can consume it as a shared service for testing by using `/krook@us.ibm.com_dev/mqtt-watson/feed-action`.

This code is based on the MQTT package originally created by [James Thomas](http://jamesthom.as/blog/2016/06/15/openwhisk-and-mqtt/).

```
openwhisk-package-mqtt-watson/
├── actions
│   └── ...
├── CONTRIBUTING.md
├── feeds
│      └── feed-action.js
├── install.sh
├── LICENSE.txt
├── README.md
├── tests
│   ├── credentials.json
│   ├── credentials.json.enc
│   └── src
│      └── MqttWatsonTests.scala
├── tools
│   └── travis
│       └── build.sh
├── MqttWatsonEventProvider
│      ├── index.js
│      ├── manifest.yml
│      ├── package.json
│      └── lib
│          ├── feed-controller.js
│          ├── mqtt-subscription-manager.js
│          └── trigger-store.js
└── uninstall.sh
```

## Architecture
TODO: Diagram here.

## Package contents
| Entity | Type | Parameters | Description |
| --- | --- | --- | --- |
| `/namespace/mqtt-watson` | package | - | OpenWhisk Package for Watson IoT MQTT |
| `/namespace/mqtt-watson/feed-action.js` | action | [details](#hello-world) | Subscribes to a Watson IoT MQTT topic |

### Feeds
The main feed action in this package is `feed-action.js`. When a trigger is associated to this action, it causes the action to subscribe to an MQTT topic as an application (not a device) so that it can receive messages that will in turn trigger your custom actions.

###### Parameters
| **Parameter** | **Type** | **Required** | **Description**| **Options** | **Default** | **Example** |
| ------------- | ---- | -------- | ------------ | ------- | ------- |------- |
| url | *string* | yes |  URL to Watson IoT MQTT feed | - | - | "ssl://a-123xyz.messaging.internetofthings.ibmcloud.com:8883" |
| topic | *string* | yes |  Topic subscription | - | - | "iot-2/type/+/id/+/evt/+/fmt/json" |
| username | *string* | yes |  Application user name | - | - | "a-123xyz" |
| password | *string* | yes |  Application password | - | - | "+-derpbog" |
| client | *string* | yes |  Application client id | - | - | "a:12e45g:mqttapp" |

## Watson MQTT Package Installation

### Bluemix Installation
First you need to install the `wsk` CLI, follow the instructions at https://new-console.ng.bluemix.net/openwhisk/cli

`./install.sh openwhisk.ng.bluemix.net $AUTH_KEY $WSK_CLI $PROVIDER_ENDPOINT`

`./uninstall.sh openwhisk.ng.bluemix.net $API_HOST $AUTH_KEY $WSK_CLI`

where:
- **$AUTH_KEY** is the OpenWhisk Authentication key (Run `wsk property get` to obtain it)
- **$WSK_CLI** is the path of OpenWhisk command interface binary
- **$PROVIDER_ENDPOINT** is the endpoint of the event provider service running as a Cloud Foundry application on Bluemix. It's a fully qualified URL including the path to the resource. i.e. http://host:port/mqtt-watson

### Local Installation:
Local installation requires running the OpenWhisk environment locally prior to installing the package. To run OpenWhisk locally follow the instructions at https://github.com/openwhisk/openwhisk/blob/master/tools/vagrant/README.md.    

`./install.sh $API_HOST $AUTH_KEY $WSK_CLI $PROVIDER_ENDPOINT`

`./uninstall.sh $API_HOST $AUTH_KEY $WSK_CLI`

where:
- **$API_HOST** is where OpenWhisk is deployed
- **$AUTH_KEY** is the OpenWhisk Authentication key (Run `wsk property get` to obtain it)
- **$WSK_CLI** is the path of OpenWhisk command interface binary
- **$PROVIDER_ENDPOINT** is the endpoint of the event provider service running as a Node.js application. It's a fully qualified URL including the path to the resource. i.e. http://host:port/mqtt-watson

This will create a new package called **mqtt-watson** as well as feed action within the package.


## Watson IoT MQTT Service (Event Provider) Deployment

In order to support integration with the Watson IoT environment there needs to be an event generating service that fires a trigger in the OpenWhisk environment when messages are received. This service connects to a particular MQTT topic and then invokes the triggers that are registered for that topic. It has its own Cloudant/CouchDB database to persist the topic-to-trigger subscription information. You will need to initialize this database prior to using this service.

There are two options to deploy the service:

### Bluemix Deployment:
This service can be hosted as a Cloud Foundry application. To deploy on IBM Bluemix:

1. Create a Cloudant service on Bluemix, name it `cloudant-mqtt-watson` and create a database with name `topic_listeners`.
2. Create a view for that Cloudant database, by creating a new design document with this content. It will provide a way to query for the subscriptions.
```
{
  "_id": "_design/subscriptions",
  "views": {
    "host_topic_counts": {
      "reduce": "_sum",
      "map": "function (doc) {\n  emit(doc.url + '#' + doc.topic, 1);\n}"
    },
    "host_topic_triggers": {
      "map": "function (doc) {\n  emit(doc.url + '#' + doc.topic, {trigger: doc._id, openWhiskUsername: doc.openWhiskUsername, openWhiskPassword: doc.openWhiskPassword});\n}"
    },
    "all": {
      "map": "function (doc) {\n  emit(doc._id, doc.url + '#' + doc.topic);\n}"
    },
    "host_triggers": {
      "map": "function (doc) {\n  emit(doc.url, {trigger: doc._id, openWhiskUsername: doc.openWhiskUsername, openWhiskPassword: doc.openWhiskPassword});\n}"
    }
  }
}
```
3. Change the name and host fields in the manifest.yml to be unique. Bluemix requires routes to be globally unique.
4. Run `cf push`

### Local Deployment:
This service can also run as a Node.js app on your local machine.

1. Install a local CouchDB, for how to install a CouchDB locally, please follow instruction at https://developer.ibm.com/open/2016/05/23/setup-openwhisk-use-local-couchdb/

2. Create a database with name `topic_listeners` in the CouchDB. Then create the subscriptions design document as shown above.

3. Run the following command, `node index.js $CLOUDANT_USERNAME $CLOUDANT_PASSWORD $OPENWHISK_AUTH_KEY`

Note: Local deployment of this service requires extra configuration if it's to be run with the Bluemix OpenWhisk.

## Usage of Watson MQTT package
To use this trigger feed, you need to pass all of the required parameters (refer to the table above)

```
$WSK_CLI trigger create subscription-event-trigger \
    -f mqtt-watson/feed-action \
    -p topic "$WATSON_TOPIC" \
    -p url "ssl://$WATSON_TEAM_ID.messaging.internetofthings.ibmcloud.com:8883" \
    -p username "$WATSON_USERNAME" \
    -p password "$WATSON_PASSWORD" \
    -p client "$WATSON_CLIENT"
```

For example:
```
$WSK_CLI trigger create subscription-event-trigger \
    -f mqtt-watson/feed-action \
    -p topic "iot-2/type/+/id/+/evt/+/fmt/json" \
    -p url "ssl://12e45g.messaging.internetofthings.ibmcloud.com:8883" \
    -p username "a-123xyz" \
    -p password "+-derpbog" \
    -p client "a:12e45g:mqttapp"
```

To use trigger feed to delete the trigger.

`$WSK_CLI trigger delete subscription-event-trigger`

## Associate Watson MQTT trigger and action by using rule
 1. Create a new trigger, using the example above.

 2. Write a 'hello-action.js' file that reacts to the trigger events with action code below:
 ```
 function main(params) {
    // Read the MQTT inbound message JSON, removing newlines.
    var service = JSON.parse(params.body.replace(/\r?\n|\r/g, ''));
    var serial = service.serial || "xxxxxx";
    var reading = service.reading || 100;
    return { payload: 'Device with serial: ' + serial + '!'+ ' emitted a reading: ' + reading };
 }
 ```
 Upload the action:
 `$WSK_CLI action create hello-action hello-action.js`

 3. Create the rule that associate the trigger and the action:
 `$WSK_CLI rule create --enable handle-topic-message-rule subscription-event-trigger hello-action`

 4. After posting a message to the MQTT topic that triggers events you have subscribed to, you can verify the action was invoked by checking the most recent activations:

 `$WSK_CLI activation list --limit 1 hello`

 ```
 activations
 f9d41bd2589943efa4f36c5cf1f55b44             hello
 ```

 `$WSK_CLI activation result f9d41bd2589943efa4f36c5cf1f55b44`

 ```
 {
     "payload": "Device with serial: 123456 emitted a reading: 15"
 }
 ```
## How to do tests
The integration test could only be performed with a local OpenWhisk deployment:

   1. Copy your test files into `openwhisk/tests/src/packages`   
   2. `vagrant ssh` to your local vagrant environment      
   3. Navigate to the openwhisk directory   
   4. Run this command - `gradle :tests:test --tests "packages.CLASS_NAME`   

To execute all tests, run `gradle :tests:test`

## Contributing
Please refer to [CONTRIBUTING.md](CONTRIBUTING.md)

## License
Copyright 2016 IBM Corporation

Licensed under the [MIT license](LICENSE.txt).

Unless required by applicable law or agreed to in writing, software distributed under the license is distributed on an "as is" basis, without warranties or conditions of any kind, either express or implied. See the license for the specific language governing permissions and limitations under the license.
