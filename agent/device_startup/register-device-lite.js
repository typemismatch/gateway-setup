var exec                = require('child_process').exec;
var fs                  = require('fs');
var async               = require('async');
var networkutils        = require("./networkUtils");
var ourIPAddress        = networkutils.getFirstAvailableNetworkAddress("enp3s0,wlp2s0");
var ourMACAddress       = networkutils.getFirstAvailableMACAddress("enp3s0,wlp2s0");
var deviceConfig        = JSON.parse(fs.readFileSync("device.config.json", 'utf8'));
var workingPath         = "/home/aws/gateway-setup/agent/device_startup/";
//var mraa                = require ('mraa');
//var LCD                 = require ('jsupm_i2clcd');

////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
//
// register-device-lite.js
//
// This is run at startup so that the device announces itself
// and its properties to the device repository, allowing
// easier discovery, and management (especially in terms of
// the DHCP-allocated IP address
//
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////

// Setup the FIRMATA Bridge
//mraa.addSubplatform(mraa.GENERIC_FIRMATA, "/dev/ttyACM0");

var awsIot = require('aws-iot-device-sdk');

var device = awsIot.device({
	"host": "data.iot.us-west-2.amazonaws.com",
	"port": 8883,
	"clientId": deviceConfig.thingName,
	"thingName": deviceConfig.thingName,
	"caPath": "/home/aws/gateway-setup/agent/device_startup/rootCA.pem",
	"certPath": "/home/aws/gateway-setup/agent/device_startup/certificate.pem",
	"keyPath": "/home/aws/gateway-setup/agent/device_startup/privateKey.pem",
  "region": "us-west-2"
});

function main()
{
  log("");
  log("");
  log("");
  log("**********************************************************");
  log("**");
  log("** Intel NUC - Device Registration");
  log("**");
  log("** Version 1.0 [May17]");
  log("**");
  log("** Device identified as " + ourMACAddress);
  log("**");
  log("**********************************************************");
  log("");
  log("");

  var bootTime = new Date().getTime();

  if ( ourIPAddress != "" )
  {
    async.forever(
      registerDevice.bind({bootTime:bootTime})
    );
  }
  else
  {
      log("No IP address available yet")
      log("Exiting with code 2");
      log("");
      process.exit(2);
  }
}

function registerDevice(next)
{
  log(new Date());

  log("Registering this Device -> " + ourIPAddress + " [" + ourMACAddress + "]");

  var data =
  {
    "local-ip" : ourIPAddress,
    "local-mac" : ourMACAddress,
    "mqtt_topic" : deviceConfig.thingTopic,
    "name" : deviceConfig.thingName,
    "thing_name" : deviceConfig.thingName,
    "last-seen" : new Date()
  };

	// Update our LCD
	/*try {
		var localLCD = new LCD.Jhd1313m1(512, 0x3E, 0x62);
		localLCD.clear();
		localLCD.setCursor(1,0);
		localLCD.write(ourIPAddress);
	  localLCD.setCursor(0,0);
		localLCD.write("I am " + deviceConfig.thingName + " on");
	} catch (e) {
		log("Could not initialize the LCD display. Error: " + e);
	}
*/

  device.publish(deviceConfig.thingTopic, JSON.stringify(data));
  setTimeout(()=>
        {
          next();
        }, 60000);
}

function log(message)
{
  console.log("register-device-lite:: " + message);
}

device.on('message', function(topic,message) {

	// There won't be a shadow for all devices so don't assume we have values
	console.log("Processing shadow data ...");
	console.log(message.toString());
	message = JSON.parse(message);
	try
	{
		var lastRunMessage = "";
		var lastRunDate = "";
		var reset = message.state.desired.reset;
		var downloadFile = message.state.desired.downloadFile;
		var run = message.state.desired.exec;
		if (reset)
		{
			console.log("Reset requested, running reset script.");
			// Execute the included reset.sh file
			exec('reset.sh' , function() {});
			lastRunMessage += "Resetting device.";
		}
		if (downloadFile != "")
		{
			console.log("Downloading requested file.");
			exec('wget -O ' + downloadFile, function() {});
			lastRunMessage += "Downloaded file: " + downloadFile;
		}
		if (exec != "")
		{
			console.log("Running commands ...");
			exec(run, function() {});
			lastRunMessage += "Executed the following: " + run;
		}
		lastRunDate = Date.now();
		var shadow = {
			"state" : {
				"desired" : {
					"lastRunMessage" : lastRunMessage,
					"lastRunDate" : lastRunDate,
					"reset" : false,
					"downloadFile" : "",
					"exec": ""
				},
				"reported" : {
					"lastRunMessage" : lastRunMessage,
					"lastRunDate" : lastRunDate,
					"reset" : false,
					"downloadFile" : "",
					"exec": ""
				}
			}
		}
		// Reset our shadow reporting back messages
		device.publish('$aws/things/' + deviceConfig.thingName + '/shadow/update', JSON.stringify(shadow));
	}
	catch (e) {
		console.log("No valid shadow found. Err: " + e.toString());
	}

});

device.on('connect', function() {
  console.log('Connected!');
  var message = {
    "agent-id": deviceConfig.thingName,
    "agent-status": "Online, waiting for IP discovery"
  };
  device.publish("nuc/agent", JSON.stringify(message));
  //subscribe to our shadow so we can run the reset agent
	device.subscribe('$aws/things/' + deviceConfig.thingName + '/shadow/get/accepted');
	device.publish('$aws/things/' + deviceConfig.thingName + '/shadow/get', "");
  setTimeout(()=>
        {
          console.log("Processing into main loop ...");
          main();
        }, 2000);
  console.log('Pushed awake message to gateway...');
});

main();
