/**
 * Copyright (c) 2010 Johnson Center for Simulation at Pine Technical College
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package QuickB2.objects.tangibles
{
	import As3Math.consts.*;
	import As3Math.general.*;
	import As3Math.geo2d.*;
	import Box2DAS.Collision.Shapes.*;
	import Box2DAS.Common.*;
	import Box2DAS.Dynamics.*;
	import flash.display.*;
	import QuickB2.*;
	import QuickB2.debugging.*;
	import QuickB2.events.*;
	import QuickB2.misc.*;
	import QuickB2.objects.*;
	import QuickB2.objects.joints.*;
	
	use namespace qb2_friend;
	
	/**
	 * ...
	 * @author Doug Koellmer
	 */
	public class qb2Body extends qb2ObjectContainer implements qb2IRigidObject
	{
		public function qb2Body()
		{
		}
		
		public function get b2_body():b2Body
			{  return _bodyB2;  }
		
		public override function get centerOfMass():amPoint2d
		{	
			if ( !_bodyB2 )
			{
				return super.centerOfMass;
			}
			else
			{
				var vec:V2 = _bodyB2.GetWorldCenter();
				return new amPoint2d(vec.x * worldPixelsPerMeter, vec.y * worldPixelsPerMeter);
			}
		}
		
		public function convertToGroup(preserveVelocities:Boolean = true):qb2Group
		{
			var oldParent:qb2ObjectContainer = _parent;
			
			var group:qb2Group = new qb2Group();
			group.copyTangibleProps(this, false);
			var explodes:Vector.<qb2Object> = this.explode(preserveVelocities, false);
			if ( explodes )
			{
				group.addObjects(explodes);
			}
			
			if ( oldParent )  oldParent.addObject(group);
			
			return group;
		}
		
		/*public function get localCenterOfMass():amPoint2d
		{
			if ( _bodyB2 )
			{
				var vec:V2 = _bodyB2.GetLocalCenter();
				return new amPoint2d(vec.x * worldPixelsPerMeter, vec.y * worldPixelsPerMeter);
			}
			else
			{
				var totMass:Number = 0;
				var totX:Number = 0, totY:Number = 0;
				for ( var i:int = 0; i < _objects.length; i++ )
				{
					if ( !(_objects[i] is qb2Tangible) )  continue;
					
					var physObject:qb2Tangible = _objects[i] as qb2Tangible;
					var ithMass:Number = physObject.mass;
					var ithCenter:amPoint2d = physObject.centerOfMass;
					
					if ( !ithCenter )  continue;
					
					totX += ithCenter.x * ithMass;
					totY += ithCenter.y * ithMass;
					totMass += ithMass;
				}
				
				return totMass ? new amPoint2d(totX / totMass, totY / totMass) : new amPoint2d(0, 0);
			}
		}*/
		
		qb2_friend override function make(theWorld:qb2World, ancestor:qb2ObjectContainer):void
		{
			_world = theWorld;
			
			//--- Only bodies owned by non-rigid containers (i.e. qb2Groups) have bodies.
			if ( !_ancestorBody )
			{
				rigid_makeBodyB2(theWorld);
			}
			
			//--- Here we temporarily make the body static so that its mass data won't be reset internally for each shape addition
			pushMassFreeze();
			{
				for ( var i:int = 0; i < _objects.length; i++ )
				{
					_objects[i].make(theWorld, ancestor);
				}
			}
			popMassFreeze();
			
			//--- Set the type back to what it should be...this strategy makes it so that b2Body::ResetMassData() is effectively only called once.
			//--- updateMassProps() isn't called because we're just interested in the internal b2Body's mass properties being updated.
			if ( _bodyB2 )
			{
				rigid_recomputeBodyB2Mass();
			}
			
			super.make(theWorld, ancestor); // just fires qb2ContainerEvents
		}
		
		qb2_friend override function destroy(ancestor:qb2ObjectContainer):void
		{
			if ( _bodyB2 )
			{
				rigid_destroyBodyB2();
			}
			
			for ( var i:int = 0; i < _objects.length; i++ )
			{
				_objects[i].destroy(ancestor);
			}
			
			super.destroy(ancestor);
		}
		
		protected override function propertyChanged(propertyName:String):void
		{
			rigid_propertyChanged(propertyName); // sets body properties if this body has a b2Body
		}
		
		protected override function flagsChanged(affectedFlags:uint):void
		{
			rigid_flagsChanged(affectedFlags); // sets body properties if this body has a b2Body
		}
		
		protected override function update():void
		{
			var numToPop:int = pushToEffectsStack();
			
			rigid_update();
			
			super.update();
			
			var updateLoopBit:uint = qb2_flags.JOINS_IN_UPDATE_CHAIN;
			for ( var i:int = 0; i < _objects.length; i++ )
			{
				var object:qb2Object = _objects[i];
				
				if ( !(object._flags & updateLoopBit) )  continue;
				
				object.relay_update(); // You can't call update directly because it's protected.
			}
			
			popFromEffectsStack(numToPop);
		}

		public override function translateBy(vector:amVector2d):qb2Tangible
			{  _position.translateBy(vector);  return this;  }

		public override function rotateBy(radians:Number, origin:amPoint2d = null):qb2Tangible 
			{  return setTransform(_position.rotateBy(radians, origin), rotation + radians) as qb2Tangible;  }

		public function setTransform(point:amPoint2d, rotationInRadians:Number):qb2IRigidObject
			{  return rigid_setTransform(point, rotationInRadians);  }

		public function updateActor():void
		{
			if ( _actor )
			{
				_actor.x = _position.x;  _actor.y = _position.y;
				_actor.rotation = rotation * TO_DEG;
			}
		}

		public function get numAttachedJoints():uint
			{  return _attachedJoints ? _attachedJoints.length : 0;  }

		public function getAttachedJointAt(index:uint):qb2Joint
			{  return _attachedJoints ? _attachedJoints[index] : null;  }
			
		public function get attachedMass():Number
			{  return rigid_attachedMass;  }

		public function get position():amPoint2d
			{  return _position;  }
		public function set position(newPoint:amPoint2d):void
			{  setTransform(newPoint, rotation);  }
			
		public function getMetricPosition():amPoint2d
		{
			const pixPer:Number = worldPixelsPerMeter;
			return new amPoint2d(_position.x / pixPer, _position.y / pixPer);
		}

		public function get linearVelocity():amVector2d
			{  return _linearVelocity;  }
		public function set linearVelocity(newVector:amVector2d):void
		{
			if ( _linearVelocity )  _linearVelocity.removeEventListener(amUpdateEvent.ENTITY_UPDATED, rigid_vectorUpdated);
			_linearVelocity = newVector;
			_linearVelocity.addEventListener(amUpdateEvent.ENTITY_UPDATED, rigid_vectorUpdated);
			rigid_vectorUpdated(null);
		}

		public function getNormal():amVector2d
			{  return amVector2d.newRotVector(0, -1, rotation);  }

		public function get rotation():Number
			{  return _rotation; }
		public function set rotation(value:Number):void
			{  setTransform(_position, value);  }

		public function get angularVelocity():Number
			{  return _angularVelocity;  }
		public function set angularVelocity(radsPerSec:Number):void
		{
			_angularVelocity = radsPerSec;
			if ( _bodyB2 )
			{
				_bodyB2.m_angularVelocity = radsPerSec;
				_bodyB2.SetAwake(true);
			}
		}
		
		public function asTangible():qb2Tangible
			{  return this as qb2Tangible;  }
			
		public override function toString():String 
			{  return qb2DebugTraceUtils.formatToString(this, "qb2Body");  }
	}
}