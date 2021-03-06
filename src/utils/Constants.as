package utils
{
	import flash.display.Stage;
	
	import feathers.controls.Button;
	
	import starling.core.Starling;
	import starling.textures.SubTexture;
	
	public class Constants 
	{
		public static var applicationStorageDirectory:String;
		
		public static const IPAD_WIDTH:int = 512;
		public static const IPAD_HEIGHT:int = 384;
		public static const READING_OFFSET:int = 0.5 * 60 * 1000;
		
		private static var _scaleFactor:Number;
		private static var _stageWidth:int;
		private static var _stageHeight:int;
		private static var _appStage:Stage;
		private static var _noLockEnabled:Boolean;
		public static var appInForeground:Boolean = true;
		public static var deviceModel:String;
		public static var isPortrait:Boolean = true;
		public static var currentOrientation:String = "default";
		
		/* Tutorial */
		public static var mainMenuButton:Button;
		public static var settingsIcon:SubTexture;
		
		public static function init( stageWidth:int, stageHeight:int, stage:Stage ):void 
		{
			_stageWidth = stageWidth;
			_stageHeight = stageHeight;
			_scaleFactor = Starling.contentScaleFactor;
			_appStage = stage;
			_noLockEnabled = false;
		}
		
		public static function get stageWidth():int 
		{
			return _stageWidth;
		}
		
		public static function set stageWidth(value:int):void
		{
			_stageWidth = value;
		}
		
		public static function get stageHeight():int 
		{
			return _stageHeight;
		}
		
		public static function set stageHeight(value:int):void
		{
			_stageHeight = value;
		}
		
		public static function get scaleFactor():int 
		{
			return _scaleFactor;
		}

		public static function get appStage():Stage
		{
			return _appStage;
		}

		public static function get noLockEnabled():Boolean
		{
			return _noLockEnabled;
		}

		public static function set noLockEnabled(value:Boolean):void
		{
			_noLockEnabled = value;
		}
	}
}