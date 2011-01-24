﻿package 
{
	import As3Math.consts.TO_DEG;
	import As3Math.consts.TO_RAD;
	import As3Math.geo2d.*;
	import com.bit101.components.*;
	import demos.*;
	import flash.display.*;
	import flash.events.*;
	import flash.text.TextFieldAutoSize;
	import flash.utils.*;
	import QuickB2.debugging.*;
	import QuickB2.events.qb2UpdateEvent;
	import QuickB2.loaders.proxies.qb2ProxyBody;
	import QuickB2.objects.*;
	import QuickB2.objects.tangibles.*;
	import QuickB2.stock.*;
	
	/**
	 * ...
	 * @author Doug Koellmer
	 */
	[Frame(factoryClass="QuickB2.misc.qb2Preloader")]
	public class Main extends Sprite 
	{
		//--- The physics world, kinda like what the stage is for the flash display hierarchy.
		private var world:qb2World = new qb2World();
		
		//--- Keep track of what demo we're on.
		private var currDemo:Demo;
		private var currIndex:int = 0;
		
		//--- All the gui stuff.
		private var _nextButton:PushButton, _prevButton:PushButton, _refreshButton:PushButton;
		private var _codeBlocks:CodeBlocks;
		private var _debugPanel:qb2DebugPanel;
		private var _noteLabel:Label;
		
		//--- Some stuff to control the camera if a demo wants it.
		public const cameraPoint:amPoint2d = new amPoint2d();
		public const cameraTargetPoint:amPoint2d = new amPoint2d();
		private var _cameraRotation:Number = 0;
		private var _cameraTargetRotation:Number = 0;
		private var rotationContainer:Sprite = new Sprite();
		
		//--- All the demo classes to cycle through.
		private static const demoClasses:Vector.<Class> = Vector.<Class>
		([
			CarDriving, RigidCar, StockSofts, JelloCar, StockRigids, StressTest,
			BubblePop, Cup, Actors, ShapeTransformation, Drawing, Joints, Distance
		]);
		
		private var _demos:Vector.<Demo> = new Vector.<Demo>();
		
		public function Main()
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}

		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			_singleton = this;
			
			stage.addChild(rotationContainer);
			stage.removeChild(this);
			rotationContainer.addChild(this);
			cameraPoint.set(stage.stageWidth / 2, stage.stageHeight / 2);
			cameraTargetPoint.copy(cameraPoint);
			
			//--- First provide an InteractiveObject for debug dragging
			//--- and a sprite for drawing into using the Graphics context.
			//--- An empty actor is provided for any demos featuring DisplayObject's.
			world.debugDragSource = this;
			world.actor = addChild(new Sprite());
			world.debugDrawContext = (addChild(new Sprite()) as Sprite).graphics;
			world.realtimeUpdate = true;
			world.maximumRealtimeStep = 1.0 / 10.0 // make it so a simulation step is never longer than this.
			world.gravity.y = 10;
			world.defaultPositionIterations = 10;
			world.defaultVelocityIterations = 10;
			world.start(); // sets up an ENTER_FRAME loop automatically.  Manual 'step()' method can also be used.
			world.addEventListener(qb2UpdateEvent.POST_UPDATE, update);
			
			//--- Make various depth-specific things be drawn relative to the demo's space initially.
			qb2DebugDrawSettings.boundBoxStartDepth = qb2DebugDrawSettings.boundBoxEndDepth = 2;
			qb2DebugDrawSettings.centroidStartDepth = qb2DebugDrawSettings.centroidEndDepth = 2;
			qb2DebugDrawSettings.boundCircleStartDepth = qb2DebugDrawSettings.boundCircleEndDepth = 2;
			qb2DebugDrawSettings.dynamicOutlineColor = qb2DebugDrawSettings.staticOutlineColor = 0x000000;
			
			//--- Add some walls that will dynamically adjust to window size.
			world.addObject(_stageWalls = new qb2StageWalls(stage));
			world.lastObject().participatesInDebugDrawing = false;  // the walls can be distracting on window resizes, so don't draw 'em.
			
			//--- Layout the gui and stage, load the first demo, and listen for future stage changes.
			buildGui();
			stageResized();
			buttonClicked();
			stage.addEventListener(Event.RESIZE, stageResized);
		}
		
		public function get cameraRotation():Number
			{  return _cameraRotation * TO_RAD;  }
		public function set cameraRotation(value:Number):void
			{  _cameraRotation = value * TO_DEG;  }
		
		public function get cameraTargetRotation():Number
			{  return _cameraTargetRotation * TO_RAD;  }
		public function set cameraTargetRotation(value:Number):void
		{
			value = value * TO_DEG
			var modulus:Number = value >= 0 ? 360 : -360;
			var newValue:Number = value % modulus + 360;
			
			if ( Math.abs(_cameraRotation - newValue) > 180 )
			{
				if( _cameraRotation - newValue < 0 )
					_cameraRotation += 360;
				else
					cameraRotation -= 360;
			}
	
			_cameraTargetRotation = newValue;
		}
	
		private var distanceCut:Number  = .05;
		private var snapDistance:Number = .2;
		private var snapRotation:Number = .01;
		
		private function update(evt:qb2UpdateEvent):void
		{
			//--- Move the camera asymtotically closer to the target point until a certain snap tolerance is reached.
			if ( cameraPoint.distanceTo(cameraTargetPoint) <= snapDistance )
			{
				cameraPoint.copy(cameraTargetPoint);
			}
			else
			{
				var vec:amVector2d = cameraTargetPoint.minus(cameraPoint);
				vec.scaleBy(distanceCut);
				cameraPoint.translateBy(vec);
			}
			
			if ( _cameraRotation != _cameraTargetRotation )
			{
				var rotMove:Number = _cameraTargetRotation - _cameraRotation;
				if ( Math.abs(rotMove) < snapRotation )
				{
					_cameraRotation = _cameraTargetRotation;
				}
				else
				{
					rotMove *= distanceCut;
					_cameraRotation += rotMove;
				}
			}
			
			this.x = -cameraPoint.x;
			this.y = -cameraPoint.y;
			//rotationContainer.rotation = _cameraRotation;
		}
		
		public function get stageWalls():qb2StageWalls
			{  return _stageWalls;  }
		private var _stageWalls:qb2StageWalls = null;
		
		/// Let other classes get some info like stage width easier through this.
		public static function get singleton():Main
			{  return _singleton;  }
		private static var _singleton:Main;
		
		private function buttonClicked(evt:Event = null):void
		{
			//--- See which demo we should be on.
			var newIndex:int = currIndex;
			if ( evt && evt.currentTarget != _refreshButton )
			{
				newIndex += evt.currentTarget == _prevButton ? -1 : 1;
				newIndex = newIndex < 0 ? demoClasses.length-1 : newIndex >= demoClasses.length ? 0 : newIndex;
			}
			
			var refresh:Boolean = evt && evt.currentTarget == _refreshButton || _demos.length == 0;
			
			switchDemo(newIndex, refresh);
		}
		
		/// Exposed method for CodeBlocks as well as for internal use.
		public function switchDemo(newIndex:uint, refresh:Boolean):void
		{
			if ( newIndex == currIndex && !refresh )  return;
			
			currIndex = newIndex;
			
			_prevButton.enabled = currIndex > 0;
			_nextButton.enabled = currIndex < demoClasses.length - 1;
			
			if ( currDemo )  world.removeObject(currDemo);
			var nextDemo:Demo = !refresh && _demos.length > currIndex ? _demos[currIndex] : new demoClasses[currIndex]();
			world.addObject(currDemo = nextDemo);
			
			var fileName:String = getQualifiedClassName(currDemo).split("::")[1] + ".as";
			if ( _demos.length <= currIndex )
			{
				_demos.push(currDemo);
				CodeBlocks.singleton.addBlock( "../src/demos/" + fileName);
			}
			else
			{
				_demos[currIndex] = currDemo;
				CodeBlocks.singleton.highlightTab(fileName);
			}
			
			//--- Just make the world refresh stuff if it's paused and the user switches demos.
			if ( !world.running )
			{
				world.step();
			}
		}
		
		private function buildGui():void
		{
			//--- A general use panel for changing some debug draw settings and reporting some stats.
			//--- This thing gets all the info and hooks it needs automatically from deep in the depths of QuickB2.
			 addChildAt(_debugPanel = new qb2DebugPanel(), 0);
			
			//--- Add navigation buttons.
			_prevButton = new PushButton(this, 0, 0, "PREVIOUS DEMO", buttonClicked);
			_nextButton = new PushButton(this, 0, 0, "NEXT DEMO", buttonClicked);
			_refreshButton = new PushButton(this, 0, 0, "REFRESH", buttonClicked);
			_prevButton.addEventListener(MouseEvent.CLICK, buttonClicked);
			_nextButton.addEventListener(MouseEvent.CLICK, buttonClicked);
			_refreshButton.addEventListener(MouseEvent.CLICK, buttonClicked);
			_prevButton.width = _nextButton.width = _refreshButton.width = _debugPanel.width;
			this.setChildIndex(_prevButton, 0);
			this.setChildIndex(_nextButton, 0);
			this.setChildIndex(_refreshButton, 0);
			
			Style.fontSize = 10;
			Style.LABEL_TEXT = 0xffffff;
			_noteLabel = new Label(this, 0, 0, "NOTE: Turn off lines for\nincreased performance.");
			_noteLabel.draw();
			_noteLabel.textField.autoSize = TextFieldAutoSize.CENTER;
			Style.fontSize = 8;
			Style.LABEL_TEXT = 0x666666;
			this.setChildIndex(_noteLabel, 0);
			
			//--- This class handles the displaying of the actual code used to create the demos, including what you're reading now!
			addChildAt(_codeBlocks = new CodeBlocks(), 0);
		}
		
		private function stageResized(evt:Event = null):void
		{
			//--- Layout the various gui elements according to screen size.
			var buffer:Number = 20;
			_debugPanel.x = stage.stageWidth - _debugPanel.width - buffer;
			_debugPanel.y = buffer;
			_refreshButton.x = _debugPanel.x + _debugPanel.width/2 - _refreshButton.width/2;
			_refreshButton.y = _debugPanel.y + _debugPanel.height + buffer;
			_prevButton.x = _refreshButton.x;
			_prevButton.y = _refreshButton.y + _refreshButton.height + buffer;
			_nextButton.x = _refreshButton.x;
			_nextButton.y = _prevButton.y + _prevButton.height + buffer;
			_noteLabel.x = _nextButton.x + _nextButton.width / 2 - _noteLabel.width / 2;
			_noteLabel.y = _nextButton.y + _nextButton.height + buffer / 3;
			
			//--- Let the blocks of code resize themselves.
			_codeBlocks.resize(stage.stageWidth - _debugPanel.width - buffer * 2, stage.stageHeight);
			
			rotationContainer.x = stage.stageWidth / 2;
			rotationContainer.y = stage.stageHeight / 2;
			
			if ( !(currDemo is CarDriving) )
			{
				this.cameraPoint.set( stage.stageWidth / 2, stage.stageHeight / 2);
				this.cameraTargetPoint.copy(this.cameraPoint);
			}
		}
	}	
}