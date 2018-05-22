package ui.screens
{
	import flash.system.System;
	
	import feathers.controls.DragGesture;
	import feathers.themes.BaseMaterialDeepGreyAmberMobileTheme;
	import feathers.themes.MaterialDeepGreyAmberMobileThemeIcons;
	
	import model.ModelLocator;
	
	import starling.display.DisplayObject;
	import starling.events.Event;
	
	import ui.AppInterface;
	import ui.screens.display.settings.alarms.AlarmsList;
	
	import utils.Constants;
	
	[ResourceBundle("alarmsettingsscreen")]

	public class AlarmsSettingsScreen extends BaseSubScreen
	{
		/* Display Objects */
		private var alarmsList:AlarmsList;
		
		public function AlarmsSettingsScreen() 
		{
			super();
			
			setupHeader();	
		}
		
		override protected function initialize():void 
		{
			super.initialize();
			
			setupContent();
			adjustMainMenu();
		}
		
		/**
		 * Functionality
		 */
		private function setupHeader():void
		{
			/* Set Header Title */
			title = ModelLocator.resourceManagerInstance.getString('alarmsettingsscreen','screen_title');
			
			/* Set Header Icon */
			icon = getScreenIcon(MaterialDeepGreyAmberMobileThemeIcons.alarmTexture);
			iconContainer = new <DisplayObject>[icon];
			headerProperties.rightItems = iconContainer;
		}
		
		private function setupContent():void
		{
			//Deactivate menu drag gesture 
			AppInterface.instance.drawers.openGesture = DragGesture.NONE;
			
			//Display Objects
			alarmsList = new AlarmsList();
			screenRenderer.addChild(alarmsList);
		}
		
		private function adjustMainMenu():void
		{
			AppInterface.instance.menu.selectedIndex = 3;
		}
		
		/**
		 * Event Listeners
		 */
		override protected function onBackButtonTriggered(event:Event):void
		{
			//Activate menu drag gesture
			AppInterface.instance.drawers.openGesture = DragGesture.EDGE;
			
			dispatchEventWith(Event.COMPLETE);
		}
		
		/**
		 * Utility
		 */
		override public function dispose():void
		{
			if (alarmsList != null)
			{
				alarmsList.removeFromParent();
				alarmsList.dispose();
				alarmsList = null;
			}
			
			super.dispose();
			
			System.pauseForGCIfCollectionImminent(0);
		}
		
		override protected function draw():void 
		{
			var layoutInvalid:Boolean = isInvalid( INVALIDATION_FLAG_LAYOUT );
			super.draw();
			icon.x = Constants.stageWidth - icon.width - BaseMaterialDeepGreyAmberMobileTheme.defaultPanelPadding;
		}
	}
}