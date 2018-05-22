package services
{
	import com.distriqt.extension.notifications.Notifications;
	import com.distriqt.extension.notifications.builders.NotificationBuilder;
	import com.distriqt.extension.notifications.events.NotificationEvent;
	import com.freshplanet.ane.AirBackgroundFetch.BackgroundFetch;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import database.BgReading;
	import database.BlueToothDevice;
	import database.Calibration;
	import database.CommonSettings;
	import database.Sensor;
	
	import events.BlueToothServiceEvent;
	import events.CalibrationServiceEvent;
	import events.NotificationServiceEvent;
	import events.SettingsServiceEvent;
	import events.SpikeEvent;
	import events.TransmitterServiceEvent;
	
	import feathers.controls.Alert;
	import feathers.controls.TextInput;
	import feathers.core.PopUpManager;
	import feathers.layout.HorizontalAlign;
	
	import model.ModelLocator;
	
	import starling.core.Starling;
	import starling.events.Event;
	
	import ui.popups.AlertManager;
	import ui.screens.display.LayoutFactory;
	
	import utils.BadgeBuilder;
	import utils.Trace;
	
	/**
	 * listens for bgreadings, at each bgreading user is asked to enter bg value<br>
	 * after two bgreadings, calibration.initialcalibration will be called and then this service will stop. 
	 */
	public class CalibrationService extends EventDispatcher
	{
		[ResourceBundle("calibrationservice")]
		[ResourceBundle("globaltranslations")]
		
		private static var _instance:CalibrationService = new CalibrationService();
		/**
		 * if notification launched for requesting initial calibration, this value will be true<br>
		 *
		 */
		private static var initialCalibrationRequested:Boolean;
		
		private static const MAXIMUM_WAIT_FOR_CALIBRATION_IN_SECONDS:int = 240; //4 minutes

		private static var calibrationValue:TextInput;

		private static var initialCalibrationActive:Boolean = false;
		
		private static const TIME_5_MINUTES:int = 5 * 60 * 1000;
		

		public static function get instance():CalibrationService {
			return _instance;
		}
		
		public function CalibrationService() {
			if (_instance != null) {
				throw new Error("CalibrationService class constructor can not be used");	
			}
		}
		
		public static function init():void {
			myTrace("init");
			TransmitterService.instance.addEventListener(TransmitterServiceEvent.BGREADING_EVENT, bgReadingReceived);
			NotificationService.instance.addEventListener(NotificationServiceEvent.NOTIFICATION_EVENT, notificationReceived);
			NotificationService.instance.addEventListener(NotificationServiceEvent.NOTIFICATION_SELECTED_EVENT, notificationReceived);
			CommonSettings.instance.addEventListener(SettingsServiceEvent.SETTING_CHANGED, commonSettingChanged);
			BluetoothService.instance.addEventListener(BlueToothServiceEvent.SENSOR_CHANGED_DETECTED, receivedSensorChanged);
			Spike.instance.addEventListener(SpikeEvent.APP_IN_FOREGROUND, appInForeGround);
			myTrace("finished init");
		}
		
		public static function appInForeGround(event:flash.events.Event = null):void {
			myTrace("in appInForeGround");
			if (initialCalibrationRequested) {
				myTrace("in appInForeGround, app has fired a notification for initialcalibration, but app was opened before notification was received - or appInForeGround is triggered faster than the notification event");
				initialCalibrationRequested = false;
				if (!initialCalibrationActive)
					requestInitialCalibration();
				Notifications.service.cancel(NotificationService.ID_FOR_REQUEST_CALIBRATION);
			}
		}
		
		private static function notificationReceived(event:NotificationServiceEvent):void {
			myTrace("in notificationReceived");
			if (event != null) {//not sure why checking, this would mean NotificationService received a null object, shouldn't happen
				var notificationEvent:NotificationEvent = event.data as NotificationEvent;
				if (notificationEvent.id == NotificationService.ID_FOR_REQUEST_CALIBRATION && initialCalibrationRequested && !initialCalibrationActive) {
					myTrace("in notificationReceived with ID_FOR_REQUEST_CALIBRATION && initialCalibrationRequested = true");
					initialCalibrationRequested = false;
					requestInitialCalibration();
				} else {
					myTrace("in notificationReceived with id = " + notificationEvent.id + ", and initialCalibrationRequested = " + initialCalibrationRequested);
				}
			}
		}
		
		/**
		 * opens dialogview to request calibration 
		 */
		private static function requestInitialCalibration():void 
		{
			myTrace("in requestInitialCalibration");
			
			if (Calibration.allForSensor().length >= 2)
				return;
			
			var latestReadings:Array = BgReading.latestBySize(2);
			if (latestReadings.length < 2) {
				myTrace("in requestInitialCalibration but latestReadings.length < 0, returning");
				return;
			}
			
			var latestReading:BgReading = (latestReadings[0]) as BgReading;
			if ((new Date()).valueOf() - latestReading.timestamp > MAXIMUM_WAIT_FOR_CALIBRATION_IN_SECONDS * 1000) 
			{
				myTrace("in requestInitialCalibration, but latest reading was more than MAXIMUM_WAIT_FOR_CALIBRATION_IN_SECONDS");
				myTrace("app was opened via notification, opening warning dialog");
				
				AlertManager.showSimpleAlert
				(
					ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_calibration_title"),
					ModelLocator.resourceManagerInstance.getString("calibrationservice","latest_reading_is_too_old"),
					60
				);
				
				return;
			}
			
			/* Create and Style Calibration Text Input */
			if (CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) == "true")
			{
				calibrationValue = LayoutFactory.createTextInput(false, true, 170, HorizontalAlign.CENTER);
				calibrationValue.maxChars = 3;
			}
			else
			{
				calibrationValue = LayoutFactory.createTextInput(false, false, 170, HorizontalAlign.CENTER, true);
				calibrationValue.maxChars = 4;
			}
			
			/* Create and Style Popup Window */
			var calibrationPopup:Alert = AlertManager.showActionAlert
			(
				ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_initial_calibration_title"),
				"",
				MAXIMUM_WAIT_FOR_CALIBRATION_IN_SECONDS,
				[
					{ label: ModelLocator.resourceManagerInstance.getString('globaltranslations','cancel_button_label').toUpperCase() },
					{ label: ModelLocator.resourceManagerInstance.getString('calibrationservice','calibration_add_button_title'), triggered: initialCalibrationValueEntered }
				],
				HorizontalAlign.JUSTIFY,
				calibrationValue
			);
			calibrationPopup.validate();
			calibrationValue.width = calibrationPopup.width - 20;
			calibrationPopup.gap = 0;
			calibrationPopup.headerProperties.maxHeight = 30;
			calibrationPopup.buttonGroupProperties.paddingTop = -10;
			calibrationPopup.buttonGroupProperties.gap = 10;
			calibrationPopup.buttonGroupProperties.horizontalAlign = HorizontalAlign.CENTER;
			calibrationValue.setFocus();
		}
		
		private static function bgReadingReceived(be:TransmitterServiceEvent):void {
			myTrace("in bgReadingReceived");

			var latestReadings:Array = BgReading.latestBySize(2);
			if (latestReadings.length < 2) {
				myTrace("in bgReadingReceived but latestReadings.length <2");
				return;
			}
			
			var latestReading:BgReading = (latestReadings[0]) as BgReading;
			if ((new Date()).valueOf() - latestReading.timestamp > MAXIMUM_WAIT_FOR_CALIBRATION_IN_SECONDS * 1000) 
			{
				//this can happen for example in case of blucon, if historical data is read which contains readings > 2 minutes old
				myTrace("in bgReadingReceived, reading is more than " + MAXIMUM_WAIT_FOR_CALIBRATION_IN_SECONDS + " seconds old, no further processing");
				return;
			}
			
			if (Sensor.getActiveSensor() == null) {
				myTrace("bgReadingReceived, but sensor is null, returning");
				return;
			}
			
			initialCalibrationActive = false;
			
			var warmupTimeInMs:Number = 2 * 3600 * 1000;
			if (BlueToothDevice.isTypeLimitter()) {
				warmupTimeInMs = 1 * 3600 * 1000;
			}
			
			//if there's already more than two calibrations, then there's no need anymore to request initial calibration
			if (Calibration.allForSensor().length < 2) 
			{
				myTrace("Calibration.allForSensor().length < 2");
				
				if ((new Date()).valueOf() - Sensor.getActiveSensor().startedAt < warmupTimeInMs) 
				{
					myTrace("CalibrationService : bgreading received but sensor age < " + warmupTimeInMs + " milliseconds, so ignoring");
				} 
				else 
				{
					//launch a notification
					//don't do it via the notificationservice, this could result in the notification being cleared but not recreated (NotificationService.updateAllNotifications)
					//the notification doesn't need to open any action, the dialog is create when the user opens the notification, or if the app is in the foreground, as soon as the notification is build. 
					//Only do this if be!= null, because if be == null, then it means this function was called after having entered an invalid number in the dialog, so user is using the app, no need for a notification
					if (be != null) 
					{
						myTrace("Launching notification ID_FOR_REQUEST_CALIBRATION");
						
						Notifications.service.notify(
							new NotificationBuilder()
							.setCount(BadgeBuilder.getAppBadge())
							.setId(NotificationService.ID_FOR_REQUEST_CALIBRATION)
							.setAlert(ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_initial_calibration_title"))
							.setTitle(ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_initial_calibration_title"))
							.setBody(ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_initial_calibration_notification_body"))
							.enableVibration(true)
							.enableLights(true)
							.build());
						
						initialCalibrationRequested = true;
					} 
					
					if (!initialCalibrationActive)
					{
						myTrace("opening dialog to request calibration");
						
						try
						{
							PopUpManager.removeAllPopUps(true);
						} 
						catch(error:Error) {}
						
						/* Create and Style Calibration Text Input */
						if (CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) == "true")
						{
							calibrationValue = LayoutFactory.createTextInput(false, true, 170, HorizontalAlign.CENTER);
							calibrationValue.maxChars = 3;
						}
						else
						{
							calibrationValue = LayoutFactory.createTextInput(false, false, 170, HorizontalAlign.CENTER, true);
							calibrationValue.maxChars = 4;
						}
						
						/* Create and Style Popup Window */
						var calibrationPopup:Alert = AlertManager.showActionAlert
							(
								ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_initial_calibration_title"),
								"",
								MAXIMUM_WAIT_FOR_CALIBRATION_IN_SECONDS,
								[
									{ label: ModelLocator.resourceManagerInstance.getString('globaltranslations','cancel_button_label').toUpperCase() },
									{ label: ModelLocator.resourceManagerInstance.getString('calibrationservice','calibration_add_button_title'), triggered: initialCalibrationValueEntered }
								],
								HorizontalAlign.JUSTIFY,
								calibrationValue
							);
						calibrationPopup.validate();
						calibrationValue.width = calibrationPopup.width - 20;
						calibrationPopup.gap = 0;
						calibrationPopup.headerProperties.maxHeight = 30;
						calibrationPopup.buttonGroupProperties.paddingTop = -10;
						calibrationPopup.buttonGroupProperties.gap = 10;
						calibrationPopup.buttonGroupProperties.horizontalAlign = HorizontalAlign.CENTER;
						calibrationValue.setFocus();
						calibrationPopup.addEventListener(starling.events.Event.CLOSE, onInitialCalibrationClosed);
						initialCalibrationActive = true;
					}
				}
			}
		}
		
		private static function onInitialCalibrationClosed(e:starling.events.Event):void
		{
			initialCalibrationActive = false;
		}
		
		private static function initialCalibrationValueEntered(e:starling.events.Event = null):void 
		{
			initialCalibrationActive = false;
			
			if (calibrationValue == null || calibrationValue.text == "" || calibrationValue.text == null || !BackgroundFetch.appIsInForeground())
				return;
			
			var latestReadings:Array = BgReading.latestBySize(2);
			if (latestReadings.length < 2) {
				myTrace("in initialCalibrationValueEntered but latestReadings.length < 2, looks like an error");
				return;
			}
			
			myTrace("in intialCalibrationValueEntered");
			
			var asNumber:Number = Number(calibrationValue.text.replace(",","."));
			
			if (isNaN(asNumber)) 
			{
				myTrace("in intialCalibrationValueEntered, user gave non numeric value, opening alert and requesting new value");
				
				//add the warning message
				AlertManager.showSimpleAlert
				(
					ModelLocator.resourceManagerInstance.getString("calibrationservice","invalid_value"),
					ModelLocator.resourceManagerInstance.getString("calibrationservice","value_should_be_numeric")
				);
				
				//and ask again a value
				bgReadingReceived(null);
			} 
			else 
			{
				if(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) != "true") 
				{
					asNumber = asNumber * BgReading.MMOLL_TO_MGDL; 	
				}
				
				myTrace("in intialCalibrationValueEntered, starting Calibration.initialCalibration");
				var now:Number = new Date().valueOf();
				Calibration.initialCalibration(asNumber, now - TIME_5_MINUTES, now, BlueToothDevice.isMiaoMiao() ? 36 : 5);
				var calibrationServiceEvent:CalibrationServiceEvent = new CalibrationServiceEvent(CalibrationServiceEvent.INITIAL_CALIBRATION_EVENT);
				_instance.dispatchEvent(calibrationServiceEvent);
			}
		}
		
		/**
		 * will create an alertdialog to ask for a calibration 
		 */
		private static function initialCalibrate():void 
		{
			myTrace("initialCalibrate");
			
			/* Create and Style Calibration Text Input */
			if (CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) == "true")
			{
				calibrationValue = LayoutFactory.createTextInput(false, true, 135, HorizontalAlign.CENTER);
				calibrationValue.maxChars = 3;
			}
			else
			{
				calibrationValue = LayoutFactory.createTextInput(false, false, 135, HorizontalAlign.CENTER, true);
				calibrationValue.maxChars = 4;
			}
			
			/* Create and Style Popup Window */
			var calibrationPopup:Alert = AlertManager.showActionAlert
				(
					ModelLocator.resourceManagerInstance.getString("calibrationservice","calibration_alert_title"),
					"",
					60,
					[
						{ label: ModelLocator.resourceManagerInstance.getString('globaltranslations','cancel_button_label').toUpperCase() },
						{ label: ModelLocator.resourceManagerInstance.getString('calibrationservice','calibration_add_button_title'), triggered: calibrationValueEntered }
					],
					HorizontalAlign.JUSTIFY,
					calibrationValue
				);
			calibrationPopup.validate();
			calibrationValue.width = calibrationPopup.width - 20;
			calibrationPopup.gap = 0;
			calibrationPopup.headerProperties.maxHeight = 30;
			calibrationPopup.buttonGroupProperties.paddingTop = -10;
			calibrationPopup.buttonGroupProperties.gap = 10;
			calibrationPopup.buttonGroupProperties.horizontalAlign = HorizontalAlign.CENTER;
			calibrationValue.setFocus();
		}
		
		/**
		 * if override = true, then a check will be done if there was a calibration in the last 60 minutes and if so the last calibration will be overriden<br>
		 * if override = false, then there's no calibration override, no matter the timing of the last calibration<br>
		 * <br>
		 * if addSnoozeOption = true, then an action will be added to the dialog which allows snoozing, the snoozeFunction should be non null and is called when the user choses that action
		 */
		public static function calibrationOnRequest(override:Boolean = true, addSnoozeOption:Boolean = false, snoozeFunction:Function = null):void 
		{
			myTrace(" in calibrationOnRequest");
			
			//start with removing any calibration request notification that might be there
			Notifications.service.cancel(NotificationService.ID_FOR_REQUEST_CALIBRATION);
			Notifications.service.cancel(NotificationService.ID_FOR_CALIBRATION_REQUEST_ALERT);
			
			//check if there's 2 readings the last 30 minutes
			var latestBGReadings:Array = BgReading.last30Minutes();
			if (latestBGReadings == null) return;
			var last2calibrations:Array = Calibration.latest(2);
			if (last2calibrations == null || last2calibrations.length == 0) return;
			
			if (BgReading.last30Minutes().length < 2) 
			{
				myTrace(" in calibrationOnRequest, BgReading.last30Minutes().length < 2");
				
				AlertManager.showSimpleAlert
				(
					ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_calibration_title"),
					ModelLocator.resourceManagerInstance.getString("calibrationservice","can_not_calibrate_right_now")
				);
			} 
			else //check if it's an override calibration
			{ 
				/* Create and Style Calibration Text Input */
				if (CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) == "true")
				{
					calibrationValue = LayoutFactory.createTextInput(false, true, 135, HorizontalAlign.CENTER);
					calibrationValue.maxChars = 3;
				}
				else
				{
					calibrationValue = LayoutFactory.createTextInput(false, false, 135, HorizontalAlign.CENTER, true);
					calibrationValue.maxChars = 4;
				}
				
				if (((new Date()).valueOf() - (Calibration.latest(2)[0] as Calibration).timestamp < (1000 * 60 * 60)) && override) 
				{
					AlertManager.showActionAlert
					(
						ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_calibration_title_with_override"),
						ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_bg_value_with_override"),
						60,
						[
							{ label: ModelLocator.resourceManagerInstance.getString('globaltranslations','cancel_button_label').toUpperCase() },
							{ label: ModelLocator.resourceManagerInstance.getString('globaltranslations','ok_alert_button_label'), triggered: onAcceptedCalibrateWithOverride }
						]
					);
					
					function onAcceptedCalibrateWithOverride():void
					{
						/* Create and Style Popup Window */
						var calibrationPopup:Alert = AlertManager.showActionAlert
						(
							ModelLocator.resourceManagerInstance.getString('calibrationservice','calibration_alert_title'),
							"",
							Number.NaN,
							[
								{ label: ModelLocator.resourceManagerInstance.getString('globaltranslations','cancel_button_label').toUpperCase() },
								{ label: ModelLocator.resourceManagerInstance.getString('calibrationservice','calibration_add_button_title'), triggered: calibrationDialogClosedWithOverride }
							],
							HorizontalAlign.JUSTIFY,
							calibrationValue
						);
						calibrationPopup.validate();
						calibrationValue.width = calibrationPopup.width - 20;
						calibrationPopup.gap = 0;
						calibrationPopup.headerProperties.maxHeight = 30;
						calibrationPopup.buttonGroupProperties.paddingTop = -10;
						calibrationPopup.buttonGroupProperties.gap = 10;
						calibrationPopup.buttonGroupProperties.horizontalAlign = HorizontalAlign.CENTER;
						calibrationValue.setFocus();
					}
					
					function calibrationDialogClosedWithOverride():void 
					{
						if (calibrationValue == null || calibrationValue.text == "" || calibrationValue.text == null || !BackgroundFetch.appIsInForeground())
							return;
						
						var asNumber:Number = Number((calibrationValue.text as String).replace(",","."));
						if (isNaN(asNumber)) 
						{
							AlertManager.showSimpleAlert
							(
								ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_calibration_title"),
								ModelLocator.resourceManagerInstance.getString("calibrationservice","value_should_be_numeric"),
								Number.NaN,
								onAskNewCalibration
							);
							
							function onAskNewCalibration():void
							{
								//and ask again a value
								calibrationOnRequest(override);
							}
						} 
						else 
						{
							if(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) != "true")
								asNumber = asNumber * BgReading.MMOLL_TO_MGDL; 	
							
							Calibration.clearLastCalibration();
							var newcalibration:Calibration = Calibration.create(asNumber).saveToDatabaseSynchronous();
							var calibrationServiceEvent:CalibrationServiceEvent = new CalibrationServiceEvent(CalibrationServiceEvent.NEW_CALIBRATION_EVENT);
							_instance.dispatchEvent(calibrationServiceEvent);
							
							myTrace("calibration override, new one = created : " + newcalibration.print("   "));
						}
					}
				} 
				else 
				{
					var alertButtonsList:Array = [];
					alertButtonsList.push({ label: ModelLocator.resourceManagerInstance.getString('globaltranslations','cancel_button_label').toUpperCase() });
					alertButtonsList.push({ label: ModelLocator.resourceManagerInstance.getString('calibrationservice','calibration_add_button_title'), triggered: calibrationDialogClosedWithoutOverride });
					if (addSnoozeOption)
					{
						alertButtonsList.push({ label: ModelLocator.resourceManagerInstance.getString("notificationservice","snooze_for_snoozin_alarm_in_notification_screen").toUpperCase(), triggered: calibrationDialogClosedWithSnooze });
						calibrationValue.width = 210;
					}
					
					var calibrationPopup:Alert = AlertManager.showActionAlert
					(
						ModelLocator.resourceManagerInstance.getString('calibrationservice','calibration_alert_title'),
						"",
						Number.NaN,
						alertButtonsList,
						HorizontalAlign.JUSTIFY,
						calibrationValue
					);
					
					calibrationPopup.validate();
					calibrationValue.width = calibrationPopup.width - 20;
					calibrationPopup.gap = 0;
					calibrationPopup.headerProperties.maxHeight = 30;
					calibrationPopup.buttonGroupProperties.paddingTop = -10;
					calibrationPopup.buttonGroupProperties.gap = 10;
					calibrationPopup.buttonGroupProperties.horizontalAlign = HorizontalAlign.CENTER;
					calibrationValue.setFocus();
					
					function calibrationDialogClosedWithoutOverride():void 
					{
						if (calibrationValue == null || calibrationValue.text == "" || calibrationValue.text == null || !BackgroundFetch.appIsInForeground())
							return;
						
						var asNumber:Number = Number((calibrationValue.text as String).replace(",","."));
						if (isNaN(asNumber)) 
						{
							AlertManager.showSimpleAlert
							(
								ModelLocator.resourceManagerInstance.getString("calibrationservice","enter_calibration_title"),
								ModelLocator.resourceManagerInstance.getString("calibrationservice","value_should_be_numeric"),
								Number.NaN,
								onAskNewCalibration
							);
							
							function onAskNewCalibration():void
							{
								//and ask again a value
								calibrationOnRequest(override);
							}
						} 
						else 
						{
							if(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) != "true")
								asNumber = asNumber * BgReading.MMOLL_TO_MGDL; 	
							
							var newcalibration:Calibration = Calibration.create(asNumber).saveToDatabaseSynchronous();
							_instance.dispatchEvent(new CalibrationServiceEvent(CalibrationServiceEvent.NEW_CALIBRATION_EVENT));
							
							myTrace("Calibration created : " + newcalibration.print("   "));
						}
					}
					
					function calibrationDialogClosedWithSnooze():void
					{
						myTrace("in calibrationOnRequest, subfunction calibrationDialogClosedWithSnooze");
						
						Starling.juggler.delayCall(snoozeFunction, 0.3);
					}
				}
			}
		}
		
		private static function calibrationValueEntered():void 
		{
			if (calibrationValue == null || calibrationValue.text == "" || calibrationValue.text == null || !BackgroundFetch.appIsInForeground())
				return;
			
			var asNumber:Number = Number(calibrationValue.text.replace(",","."));
			if (isNaN(asNumber)) 
			{
				//add the warning message
				AlertManager.showSimpleAlert
				(
					ModelLocator.resourceManagerInstance.getString("calibrationservice","invalid_value"),
					ModelLocator.resourceManagerInstance.getString("calibrationservice","value_should_be_numeric")
				);
				
				//and ask again a value
				initialCalibrate();
			} 
			else 
			{
				if(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) != "true") 
					asNumber = asNumber * BgReading.MMOLL_TO_MGDL; 	
				
				var calibration:Calibration = Calibration.create(asNumber).saveToDatabaseSynchronous();
				myTrace("Calibration created : " + calibration.print("   "));
			}
		}
		
		private static function commonSettingChanged(event:SettingsServiceEvent):void {
			if (event.data == CommonSettings.COMMON_SETTING_FSL_SENSOR_AGE) {
				var currentSensorAgeInMinutes:int = new Number(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_FSL_SENSOR_AGE));
				if (currentSensorAgeInMinutes > 14.5 * 24 * 60) {
					myTrace("in commonSettingChanged, sensorage more than 14.5 * 24 * 60 minutes, no further processing. Stop sensor if sensor is active");
					if (Sensor.getActiveSensor() != null) {
						//start sensor without user intervention 
						Sensor.stopSensor();
						giveSensorWarning("libre_14_dot_5_days_warning");
					}
				} else if (currentSensorAgeInMinutes > 14 * 24 * 60 && CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_LIBRE_SENSOR_14DAYS_WARNING_GIVEN) == "false") {
					myTrace("in commonSettingChanged, sensorage more than 14 * 24 * 60 minutes, give warning that sensor will expiry in half a day ");
					if (Sensor.getActiveSensor() != null) {
						giveSensorWarning("libre_14days_warning");
						CommonSettings.setCommonSetting(CommonSettings.COMMON_SETTING_LIBRE_SENSOR_14DAYS_WARNING_GIVEN,"true");
					}
				}
				if (currentSensorAgeInMinutes > 0 && Sensor.getActiveSensor() == null && !BlueToothDevice.isMiaoMiao() && BlueToothDevice.knowsFSLAge() && currentSensorAgeInMinutes < 14.5 * 24 * 60) {
					//not doing this for miaomiao because sensorstart for miaomiao is already handled in LibreAlarmReceiver
					myTrace("in commonSettingChanged, sensorage changed to smaller value, starting sensor");
					Sensor.startSensor(((new Date()).valueOf() - currentSensorAgeInMinutes * 60 * 1000));
				}
			}
		}
		
		private static function giveSensorWarning(warning:String):void {
			if (BackgroundFetch.appIsInForeground()) {
				AlertManager.showSimpleAlert
					(
						ModelLocator.resourceManagerInstance.getString("transmitterservice","warning"),
						ModelLocator.resourceManagerInstance.getString("transmitterservice",warning)
					);
			} else {
				var notificationBuilder:NotificationBuilder = new NotificationBuilder()
					.setId(NotificationService.ID_FOR_LIBRE_SENSOR_14DAYS)
					.setAlert(ModelLocator.resourceManagerInstance.getString("transmitterservice","warning"))
					.setTitle(ModelLocator.resourceManagerInstance.getString("transmitterservice","warning"))
					.setBody(ModelLocator.resourceManagerInstance.getString("transmitterservice",warning))
					.enableVibration(false)
					.setSound("");
				Notifications.service.notify(notificationBuilder.build());
			}
		}
		
		private static function receivedSensorChanged(be:BlueToothServiceEvent):void {
			if (Sensor.getActiveSensor() != null && BlueToothDevice.knowsFSLAge()) {
				myTrace("in receivedSensorChanged, Stopping the sensor"); 
				Sensor.stopSensor();
				CommonSettings.setCommonSetting(CommonSettings.COMMON_SETTING_FSL_SENSOR_AGE, "0");
				giveSensorWarning("new_fsl_sensor_detected");
			}
		}

		private static function myTrace(log:String):void {
			Trace.myTrace("CalibrationService.as", log);
		}
	}
}