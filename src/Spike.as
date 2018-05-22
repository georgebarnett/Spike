package 
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display3D.Context3DProfile;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.StageOrientationEvent;
	import flash.events.UncaughtErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLVariables;
	import flash.system.System;
	import flash.utils.setTimeout;
	
	import mx.utils.ObjectUtil;
	
	import database.LocalSettings;
	
	import events.SpikeEvent;
	
	import feathers.utils.ScreenDensityScaleFactorManager;
	
	import network.EmailSender;
	
	import starling.core.Starling;
	import starling.events.Event;
	import starling.events.ResizeEvent;
	import starling.utils.SystemUtil;
	
	import ui.AppInterface;
	
	import utils.Constants;
	import utils.Trace;
	
	[SWF(frameRate="60", backgroundColor="#20222a")]
	
	public class Spike extends Sprite 
	{
		private static const TIME_1_MINUTE:int = 60 * 1000;
		private var starling:Starling;
		private var scaler:ScreenDensityScaleFactorManager;	
		private var timeoutID:int = -1;
		private var lastCrashReportTimestamp:Number = 0;
		
		private static var _instance:Spike;
		
		public static function get instance():Spike
		{
			return _instance;
		}
		
		public function Spike() 
		{
			SystemUtil.initialize();
			
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			_instance = this;
			
			/* Global Exceptions Handling */
			loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
			
			/* Start Starling */
			timeoutID = setTimeout( function():void {
				SystemUtil.executeWhenApplicationIsActive(initStarling);
			}, 200 );
		}
		
		private function onUncaughtError(e:UncaughtErrorEvent):void
		{
			if (e.error is Error)
			{
				var error:Error = e.error as Error;
				sendError("<p>Error ID: " + error.errorID + "</p><p>Error Name: " + error.name + "</p><p> Error Message: " + error.message + "</p><p>Error Stack Trace: " + error.getStackTrace() + "</p>");
			}
			else
			{
				var errorEvent:ErrorEvent = e.error as ErrorEvent;
				sendError("<p>Error Event ID: " + errorEvent.errorID + "</p><p>Text: " + errorEvent.text + "</p><p>Type: " + errorEvent.type + "</p><p>Target: " + ObjectUtil.toString(errorEvent.target) + "</p><p>Current Target: " + ObjectUtil.toString(errorEvent.currentTarget));
			}
		}
		
		private function sendError(error:String):void
		{
			//Things we don't want to report
			if ( 
				error.indexOf("ioError") != -1 ||
				error.indexOf("Unexpected < encountered") != -1 ||
				error.indexOf("Unexpected T encountered") != -1 ||
				error.indexOf("PickerList/closeList()") != -1 ||
				error.indexOf("JSONParseError") != -1 ||
				error.indexOf("starling.display.graphics::Graphic/render()") != -1 ||
				error.indexOf("starling.rendering::VertexData/createVertexBuffer()") != -1 ||
				error.indexOf("RangeError: Error #1125 at BatchProcessor/getBatchAt() at starling.rendering::Painter/drawFromCache()") != -1
				)
			{
				return;
			}
			
			var now:Number = new Date().valueOf();
			
			//Don't send consecutive errors that might happen on onEnterFrame events. Not usefull and will save battery life and not SPAM our email
			if (now - lastCrashReportTimestamp < TIME_1_MINUTE)
				return;
			
			lastCrashReportTimestamp = now;
			
			error = "Spike Version: " + LocalSettings.getLocalSetting(LocalSettings.LOCAL_SETTING_APPLICATION_VERSION) + "\n\n" + error;
			
			//Create URL Request 
			var vars:URLVariables = new URLVariables();
			vars.mimeType = "text/html";
			vars.emailSubject = "Spike Uncaught Error";
			vars.emailBody = error;
			vars.userName = "";
			vars.userEmail = "bug@spike-app.com";
			
			//Send Email
			EmailSender.sendData
			(
				EmailSender.TRANSMISSION_URL_NO_ATTACHMENT,
				onLoadCompleteHandler,
				vars
			);
		}
		
		private function onLoadCompleteHandler(event:flash.events.Event):void 
		{ 
			var loader:URLLoader = URLLoader(event.target);
			loader.removeEventListener(flash.events.Event.COMPLETE, onLoadCompleteHandler);
			loader = null;
		}
		
		/**
		 * Initialization
		 */
		private function initStarling():void 
		{
			/* Initialize and start the Starling instance */
			starling = new Starling( AppInterface, stage, null, null, "auto", Context3DProfile.BASELINE_EXTENDED );
			starling.enableErrorChecking = false;
			starling.skipUnchangedFrames = true;
			starling.antiAliasing = 6;
			//Starling.current.showStatsAt("right", "bottom");
			//Starling.current.showStatsAt("left", "bottom");
			scaler = new ScreenDensityScaleFactorManager( starling );
			
			/* Initialize Constants */
			Constants.init( starling.stage.stageWidth, starling.stage.stageHeight, stage );
			Constants.isPortrait = starling.stage.stageWidth < starling.stage.stageHeight;
			starling.addEventListener( starling.events.Event.ROOT_CREATED, onStarlingReady );
			Starling.current.stage3D.addEventListener(flash.events.Event.CONTEXT3D_CREATE, onContextCreated, false, 50, true);
			Starling.current.stage.addEventListener(starling.events.Event.RESIZE, onStarlingResize);
			stage.addEventListener(StageOrientationEvent.ORIENTATION_CHANGING, onOrientationChanging);
			
			/* Handle Application Activation & Deactivation */
			NativeApplication.nativeApplication.addEventListener( flash.events.Event.ACTIVATE, onActivate );
			NativeApplication.nativeApplication.addEventListener( flash.events.Event.DEACTIVATE, onDeactivate );
		}
		
		/**
		 * Event Handlers
		 */
		private function onStarlingReady( event:starling.events.Event, root:AppInterface ):void 
		{
			/* Start Starling */
			SystemUtil.executeWhenApplicationIsActive( starling.start );
			
			/* Start Interface */
			SystemUtil.executeWhenApplicationIsActive( root.start );
		}
		
		private function onActivate( event:flash.events.Event ):void 
		{
			//Restart stage framerate
			if (stage != null)
				stage.frameRate = 60;
			
			if (Starling.current.nativeStage != null)
				Starling.current.nativeStage.frameRate = 60;
			
			if (starling != null)
			{
				//Start Starling
				NativeApplication.nativeApplication.executeInBackground = false;
				SystemUtil.executeWhenApplicationIsActive( starling.start );
			}
			else
			{
				initStarling();
				NativeApplication.nativeApplication.executeInBackground = false;
			}
			
			//Update Variables
			Constants.appInForeground = true;
			
			//Notify Services
			myTrace("dispatching event SpikeEvent.APP_IN_FOREGROUND");
			if (instance == null)
				_instance = this
			instance.dispatchEvent(new SpikeEvent(SpikeEvent.APP_IN_FOREGROUND));
		}
		
		private function onDeactivate( event:flash.events.Event ):void 
		{
			//Decrease framerate almost to a halt
			if (Starling.current.nativeStage != null)
				Starling.current.nativeStage.frameRate = 0.5;
			if (stage != null)
				stage.frameRate = 0.5;
			
			//Update Variables
			Constants.noLockEnabled = false;
			Constants.appInForeground = false;
			
			//Stop Starling 
			NativeApplication.nativeApplication.executeInBackground = true;
			if (starling != null)
				starling.stop( true );
			
			//Notify Services
			myTrace("dispatching event SpikeEvent.APP_IN_BACKGROUND");
			if (instance == null)
				_instance = this;
			instance.dispatchEvent(new SpikeEvent(SpikeEvent.APP_IN_BACKGROUND));

			//Call Garbage Collector
			System.pauseForGCIfCollectionImminent(0);
		}
		
		private function onStarlingResize(event:ResizeEvent):void 
		{
			Trace.myTrace("Spike.as", "Stage has been resized. Width: " + stage.stageWidth + ", Height: " + stage.stageHeight);
			
			if (starling != null)
			{
				starling.stop( true );
				
				Constants.stageWidth = starling.stage.stageWidth;
				Constants.stageHeight = starling.stage.stageHeight;
				
				Starling.current.viewPort.width  = stage.stageWidth;
				Starling.current.viewPort.height = stage.stageHeight;
				
				Constants.isPortrait = stage.stageWidth < stage.stageHeight;
				
				SystemUtil.executeWhenApplicationIsActive(starling.start);
			}
		}
		
		private function onOrientationChanging(e:StageOrientationEvent):void
		{
			Constants.currentOrientation = e.afterOrientation;
		}
		
		private function onContextCreated(event:flash.events.Event):void
		{
			Trace.myTrace("Spike.as", "onContextCreated! Event Debug: " + ObjectUtil.toString(event));
		}
		
		/**
		 * Utility Functions
		 */
		private static function myTrace(log:String):void {
			Trace.myTrace("Spike.as", log);
		}	
	}	
}
