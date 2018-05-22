package services
{
	import com.distriqt.extension.networkinfo.NetworkInfo;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	
	import database.LocalSettings;
	
	import events.SpikeEvent;
	
	import model.ModelLocator;
	
	import ui.popups.AlertManager;
	
	import utils.SpikeJSON;
	import utils.Trace;
	
	[ResourceBundle('globaltranslations')]
	
	public class RemoteAlertService
	{
		// Constants
		private static const TIME_24H:int = 24 * 60 * 60 * 1000;
		private static const REMOTE_ALERT_URL:String = "https://spike-app.com/app/global_alert.json";
		
		//Variables 
		private static var initialStart:Boolean = true;
		private static var awaitingLoadResponse:Boolean = false;
		
		public function RemoteAlertService()
		{
			throw new Error("RemoteAlertService class constructor can not be used");	
		}
		
		//Start Engine
		public static function init():void
		{
			myTrace("RemoteAlertService initiated!");
			
			//Setup Event Listeners
			createEventListeners();
		}
		
		/**
		 * Functionality
		 */
		private static function createEventListeners():void
		{
			//Register event listener for app in foreground
			Spike.instance.addEventListener(SpikeEvent.APP_IN_FOREGROUND, onApplicationActivated);
		}
		
		private static function getRemoteAlert():void
		{
			myTrace("in getRemoteAlert");
			
			if (!NetworkInfo.networkInfo.isReachable())
			{
				myTrace("No internet connection. Aborting");
				return;
			}
			
			//Create and configure loader and url request
			var request:URLRequest = new URLRequest(REMOTE_ALERT_URL);
			request.method = URLRequestMethod.GET;
			var loader:URLLoader = new URLLoader(); 
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			
			//Make connection and define listener
			loader.addEventListener(flash.events.Event.COMPLETE, onResponseReceived);
			loader.addEventListener(IOErrorEvent.IO_ERROR, onResponseReceived);
			awaitingLoadResponse = true;
			
			try 
			{
				loader.load(request);
			}
			catch (error:Error) 
			{
				myTrace("Unable to load Spike Remote Alert API: " + error.getStackTrace().toString());
			}
		}
		
		private static function canDoCheck():Boolean
		{
			/**
			 * Uncomment next line and comment the other one for testing
			 * We are hardcoding a timestamp of more than 1 day ago for testing purposes otherwise the update popup wont fire 
			 */
			//var lastUpdateCheckStamp:Number = 1511014007853;
			var lastRemoteAlertCheckStamp:Number = Number(LocalSettings.getLocalSetting(LocalSettings.LOCAL_SETTING_REMOTE_ALERT_LAST_CHECK_TIMESTAMP));
			var currentTimeStamp:Number = (new Date()).valueOf();
			
			//If it has been more than 1 day since the last check for emote alerts or it's the first time the app checks for remote alerts
			if(currentTimeStamp - lastRemoteAlertCheckStamp > TIME_24H)
			{
				myTrace("App can check for remote alerts");
				return true;
			}
			
			myTrace("App can not check for new remote alerts");
			return false;
		}
		
		/**
		 * Event Listeners
		 */
		protected static function onResponseReceived(event:flash.events.Event):void
		{
			if (awaitingLoadResponse) 
			{
				myTrace("in onResponseReceived");
				awaitingLoadResponse = false;
			} 
			else
				return;
			
			if (!event.target) 
			{
				myTrace("no event.target");
				return;
			}
			
			//Parse response and validate presence of mandatory objects 
			var loader:URLLoader = URLLoader(event.target);
			if (!loader.data) 
			{
				myTrace("no loader.data");
				return;
			}
			
			if (String(loader.data).indexOf ("id") == -1)
			{
				myTrace("server response empty");
				return;
			}
			
			//var data:Object = JSON.parse(loader.data as String);
			var data:Object = SpikeJSON.parse(loader.data as String);
			if (data.id == null) 
			{
				myTrace("no data.id");
				return;
			} 
			else if (data.message == null) 
			{
				myTrace("no data.message");
				return;
			}
			
			//Update database
			LocalSettings.setLocalSetting(LocalSettings.LOCAL_SETTING_REMOTE_ALERT_LAST_CHECK_TIMESTAMP, String((new Date()).valueOf()));
			
			var lastIDCheck:Number = Number(LocalSettings.getLocalSetting(LocalSettings.LOCAL_SETTING_REMOTE_ALERT_LAST_ID));
			var currentIDCheck:Number = Number(data.id);
			var possibleVersion:String = String(data.message).substr(0, 5);
			
			if (lastIDCheck >= currentIDCheck)
			{
				myTrace("this alert has already been shown to the user");
				return;
			}
			else if ((String(data.message).indexOf(LocalSettings.getLocalSetting(LocalSettings.LOCAL_SETTING_APPLICATION_VERSION)) != -1 || (possibleVersion.charAt(1).indexOf(".") != -1 && versionAIsSmallerThanB(possibleVersion, LocalSettings.getLocalSetting(LocalSettings.LOCAL_SETTING_APPLICATION_VERSION)))) && String(data.message).indexOf("TestFlight") != -1)
			{
				//It's an update alert but user already has the latest versio
				//Update Database so this alert is not shown anymore.
				LocalSettings.setLocalSetting(LocalSettings.LOCAL_SETTING_REMOTE_ALERT_LAST_ID, String(currentIDCheck));
			}
			else
			{
				//Show the alert to the user
				AlertManager.showSimpleAlert
				(
					ModelLocator.resourceManagerInstance.getString('globaltranslations', "info_alert_title"),
					data.message
				);
				
				//Update Database
				LocalSettings.setLocalSetting(LocalSettings.LOCAL_SETTING_REMOTE_ALERT_LAST_ID, String(currentIDCheck));
			}
		}
		
		protected static function onApplicationActivated(event:flash.events.Event = null):void
		{
			//App is in foreground. Let's see if we can make a remote alert check
			//but not the very first start of the app, otherwise there's too many pop ups
			if (initialStart) 
			{
				initialStart = false;
				myTrace("in onApplicationActivated, initialStart = true, not doing remote alert check at app startup");
				return;
			}
			
			if(canDoCheck())
				getRemoteAlert();
		}
		
		/**
		 * Utility
		 */
		private static function versionAIsSmallerThanB(versionA:String, versionB:String):Boolean 
		{
			var versionaSplitted:Array = versionA.split(".");
			var versionbSplitted:Array = versionB.split(".");
			if (new Number(versionaSplitted[0]) < new Number(versionbSplitted[0]))
				return true;
			if (new Number(versionaSplitted[0]) > new Number(versionbSplitted[0]))
				return false;
			if (new Number(versionaSplitted[1]) < new Number(versionbSplitted[1]))
				return true;
			if (new Number(versionaSplitted[1]) > new Number(versionbSplitted[1]))
				return false;
			if (new Number(versionaSplitted[2]) < new Number(versionbSplitted[2]))
				return true;
			if (new Number(versionaSplitted[2]) > new Number(versionbSplitted[2]))
				return false;
			return false;
		}
		
		private static function myTrace(log:String):void 
		{
			Trace.myTrace("RemoteAlertService.as", log);
		}
	}
}