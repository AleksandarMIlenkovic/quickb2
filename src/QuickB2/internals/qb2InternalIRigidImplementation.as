package QuickB2.internals 
{
	import As3Math.general.amUpdateEvent;
	import As3Math.general.amUtils;
	import As3Math.geo2d.amPoint2d;
	import As3Math.geo2d.amVector2d;
	import Box2DAS.Common.b2Def;
	import Box2DAS.Common.V2;
	import Box2DAS.Dynamics.b2Body;
	import Box2DAS.Dynamics.b2BodyDef;
	import flash.utils.Dictionary;
	import QuickB2.*;
	import QuickB2.misc.qb2_flags;
	import QuickB2.misc.qb2_props;
	import QuickB2.objects.joints.qb2Joint;
	import QuickB2.objects.tangibles.qb2IRigidObject;
	import QuickB2.objects.tangibles.qb2PolygonShape;
	import QuickB2.objects.tangibles.qb2Tangible;
	import QuickB2.objects.tangibles.qb2World;
	import QuickB2.*;
	import As3Math.*;
	
	
	use namespace qb2_friend;
	use namespace am_friend;
	
	/**
	 * ...
	 * @author Doug Koellmer
	 */
	public class qb2InternalIRigidImplementation 
	{
		qb2_friend static const diffTol:Number = .0000000001;
		qb2_friend static const rotTol:Number  = .0000001;
		
		qb2_friend var _bodyB2:b2Body;
		qb2_friend var _attachedJoints:Vector.<qb2Joint> = null;
		qb2_friend var _linearVelocity:amVector2d = null;
		qb2_friend var _angularVelocity:Number = 0;
		qb2_friend var _position:amPoint2d = null;
		qb2_friend var _rotation:Number = 0;
		qb2_friend var _calledFromPointUpdated:Boolean = false;
		qb2_friend var _tang:qb2Tangible;
		
		public function qb2InternalIRigidImplementation(tang:qb2Tangible) 
		{
			init(tang);
		}
		
		private function init(tang:qb2Tangible):void
		{
			_tang = tang;
			_position = new amPoint2d();
			_position.addEventListener(amUpdateEvent.ENTITY_UPDATED, pointUpdated);
			_linearVelocity = new amVector2d();
			_linearVelocity.addEventListener(amUpdateEvent.ENTITY_UPDATED, vectorUpdated);
		}
		
		qb2_friend function setLinearVelocity(newVector:amVector2d):void
		{
			if ( _linearVelocity )  _linearVelocity.removeEventListener(amUpdateEvent.ENTITY_UPDATED, vectorUpdated);
			_linearVelocity = newVector;
			_linearVelocity.addEventListener(amUpdateEvent.ENTITY_UPDATED, vectorUpdated);
			vectorUpdated(null);
		}
		
		qb2_friend function setAngularVelocity(radsPerSec:Number):void
		{
			_angularVelocity = radsPerSec;
			if ( _tang._bodyB2 )
			{
				_tang._bodyB2.m_angularVelocity = radsPerSec;
				_tang._bodyB2.SetAwake(true);
			}
		}
		
		qb2_friend function flagsChanged(affectedFlags:uint):void
		{
			//--- Make actual changes to a simulating body if the property has an actual effect.
			if ( _tang._bodyB2 )
			{
				if ( affectedFlags & qb2_flags.IS_KINEMATIC )
				{
					recomputeBodyB2Mass();
					_tang.updateFrictionJoints();
				}
				
				if ( affectedFlags & qb2_flags.HAS_FIXED_ROTATION )
				{
					_tang._bodyB2.SetFixedRotation(_tang.hasFixedRotation );
					_tang._bodyB2.SetAwake(true);
					(_tang as qb2IRigidObject).angularVelocity = 0; // object won't stop spinning if we don't stop it manually, because now it has infinite intertia.
				}
				
				if ( affectedFlags & qb2_flags.IS_BULLET )
				{
					_tang._bodyB2.SetBullet(_tang.isBullet);
				}
				
				if ( affectedFlags & qb2_flags.ALLOW_SLEEPING )
				{
					_tang._bodyB2.SetSleepingAllowed(_tang.allowSleeping);
				}
			}
		}
		
		qb2_friend final function propertyChanged(propertyName:String):void
		{
			//--- Make actual changes to a simulating body if the property has an actual effect.
			if ( _tang._bodyB2 )
			{
				if ( propertyName == qb2_props.LINEAR_DAMPING )
				{
					_tang._bodyB2.m_linearDamping = _tang.linearDamping;
				}
				else if ( propertyName == qb2_props.ANGULAR_DAMPING )
				{
					_tang._bodyB2.m_angularDamping = _tang.angularDamping;
				}
			}
		}
		
		private static function shouldTransform(oldPos:amPoint2d, newPos:amPoint2d, oldRot:Number, newRot:Number):Boolean
		{
			//--- Return true if oldPos and newPos reference the same object, cause in this case it's likely that pointUpdated was invoked, and _position was changed.
			return !oldPos.equals(newPos, diffTol) || !amUtils.isWithin(oldRot, newRot - rotTol, newRot + rotTol);
		}
		
		qb2_friend function makeBodyB2(theWorld:qb2World):void
		{
			if ( theWorld.processingBox2DStuff )
			{
				theWorld.addDelayedCall(_tang, makeBodyB2, theWorld);
				return;
			}
			
			var conversion:Number = theWorld._pixelsPerMeter;
			
			//--- Populate body def.  
			var bodDef:b2BodyDef  = b2Def.body;
			bodDef.allowSleep     = _tang.allowSleeping;
			bodDef.fixedRotation  = _tang.hasFixedRotation;
			bodDef.bullet         = _tang.isBullet;
			bodDef.awake          = !_tang.sleepingWhenAdded;
			bodDef.linearDamping  = _tang.linearDamping;
			bodDef.angularDamping = _tang.angularDamping;
			//bodDef.type         = NOTE: type is taken care of in recomputeB2Mass, which will be called after this function some time.
			bodDef.position.x     = _position.x / conversion;
			bodDef.position.y     = _position.y / conversion;
			bodDef.angle          = _rotation;
			
			_bodyB2 = theWorld._worldB2.CreateBody(bodDef);
			_bodyB2.m_linearVelocity.x = _linearVelocity.x;
			_bodyB2.m_linearVelocity.y = _linearVelocity.y;
			_bodyB2.m_angularVelocity  = _angularVelocity;
			_bodyB2.SetUserData(_tang);
		}
		
		qb2_friend function destroyBodyB2():void
		{
			_bodyB2.SetUserData(null);
			
			var world:qb2World = _tang._world;
			
			if ( world.processingBox2DStuff )
			{
				world.addDelayedCall(_tang, world._worldB2.DestroyBody, _bodyB2);
			}
			else
			{
				world._worldB2.DestroyBody(_bodyB2);
			}
			
			_bodyB2 = null;
		}
		
		qb2_friend function recomputeBodyB2Mass():void
		{
			var thisIsKinematic:Boolean = _tang.isKinematic;
			
			//--- Box2D gets pissed sometimes if you change a body from dynamic to static/kinematic within a contact callback.
			//--- So whenever this happen's the call is delayed until after the physics step, which shouldn't affect the simulation really.
			var theWorld:qb2World = qb2World.worldDict[_bodyB2.m_world] as qb2World;
			var changingToZeroMass:Boolean = !_tang._mass || thisIsKinematic;
			if ( _bodyB2.GetType() == b2Body.b2_dynamicBody && changingToZeroMass && theWorld.processingBox2DStuff )
			{
				theWorld.addDelayedCall(null, this.recomputeBodyB2Mass);
				return;
			}
			
			_bodyB2.SetType(thisIsKinematic ? b2Body.b2_kinematicBody : (_tang._mass ? b2Body.b2_dynamicBody : b2Body.b2_staticBody));
			//_bodyB2.ResetMassData(); // this is called by SetType(), so was redundant, but i'm still afraid that commenting it out would break something, so it's here for now.
			
			//--- The mechanism by which we save some costly b2Body::ResetMassData() calls (by setting the body to static until all shapes are done adding),
			//--- causes the body's velocities to be zeroed out, so here we just set them back to what they were.
			if ( _bodyB2.m_type != b2Body.b2_staticBody )
			{
				_bodyB2.m_linearVelocity.x = _linearVelocity._x;
				_bodyB2.m_linearVelocity.y = _linearVelocity._y;
				_bodyB2.m_angularVelocity  = _angularVelocity;
			}
		}
		
		qb2_friend function update():void
		{
			if ( _bodyB2 )
			{
				//--- Clear forces.  This isn't done right after b2World::Step() with b2World::ClearForces(),
				//--- because we would have to go through the whole list of bodies twice.
				_bodyB2.m_force.x = _bodyB2.m_force.y = 0;
				_bodyB2.m_torque = 0;
				
				//--- Get new position/angle.
				const pixPerMeter:Number = _tang.worldPixelsPerMeter;
				var newRotation:Number = _bodyB2.GetAngle();
				var newPosition:amPoint2d = new amPoint2d(_bodyB2.GetPosition().x * pixPerMeter, _bodyB2.GetPosition().y * pixPerMeter);
				
				//--- Check if the new transform invalidates the bound box.
				if ( shouldTransform( _position, newPosition, _rotation, newRotation) )
				{
					if ( _tang is qb2PolygonShape ) // sloppy, but not doing this in qb2PolygonShape::update() saves a decent amount of double-checking
					{
						(_tang as qb2PolygonShape).updateFromLagPoints(newPosition, newRotation);
					}
				}
				
				//--- Update the transform, without invoking pointUpdated
				_position._x = newPosition._x;
				_position._y = newPosition._y;
				_rotation    = newRotation;
				
				//--- Update velocities, again without invoking callbacks.
				_linearVelocity._x = _bodyB2.m_linearVelocity.x;
				_linearVelocity._y = _bodyB2.m_linearVelocity.y;
				_angularVelocity   = _bodyB2.m_angularVelocity;
				
				(_tang as qb2IRigidObject).updateActor();
			}
		}
		
		qb2_friend function setTransform(point:amPoint2d, rotationInRadians:Number):qb2IRigidObject
		{
			var asRigid:qb2IRigidObject = _tang as qb2IRigidObject;
			
			/*if ( _calledFromPointUpdated || rigid_shouldTransform(_position, point, _rotation, rotationInRadians) )
			{
				invalidateBoundBox();
			}*/
			
			if ( point != _position ) // if e.g. rotateBy or pointUpdated() calls this function, 'point' and '_position' refer to the same point object, otherwise _position must be made to refer to the new object
			{
				if ( _position )  _position.removeEventListener(amUpdateEvent.ENTITY_UPDATED, pointUpdated);
				_position = point;
				_position.addEventListener(amUpdateEvent.ENTITY_UPDATED, pointUpdated);
			}
			
			_rotation = rotationInRadians;
			
			if ( _bodyB2 )
			{
				var world:qb2World = _tang._world;
				var pixPerMeter:Number = world.pixelsPerMeter;
				
				if ( world.processingBox2DStuff )
				{
					world.addDelayedCall(_tang, _bodyB2.SetTransform, new V2(point.x / pixPerMeter, point.y / pixPerMeter), rotationInRadians);
				}
				else
				{
					_bodyB2.SetTransform(new V2(point.x / pixPerMeter, point.y / pixPerMeter), rotationInRadians);
				}
			}
			
			asRigid.updateActor();
			
			_tang.wakeUp();
			
			if ( _tang._ancestorBody ) // (if this object is a child of some body whose only other ancestors are qb2Groups...)
			{
				_tang.pushMassFreeze(); // this is only done to prevent b2Body::ResetMassData() from being effectively called more than necessary by setting body type to static.
					_tang.flushShapes();
				_tang.popMassFreeze();
				
				//--- Skip the first object (this) in the tree because only parent object's mass properties will be affected.
				_tang.updateMassProps(0, 0, true); // we just assume that some kind of center of mass change took place here, even though it didnt *for sure* happen
				
				for (var i:int = 0; i < asRigid.numAttachedJoints; i++) 
				{
					var attachedJoint:qb2Joint = asRigid.getAttachedJointAt(i);
					attachedJoint.correctLocals();
				}
			}		
			
			return asRigid;
		}
		
		qb2_friend function vectorUpdated(evt:amUpdateEvent):void
		{
			if ( _bodyB2 )
			{
				_bodyB2.m_linearVelocity.x = _linearVelocity.x;
				_bodyB2.m_linearVelocity.y = _linearVelocity.y;
				_bodyB2.SetAwake(true);
			}
		}

		qb2_friend function pointUpdated(evt:amUpdateEvent):void
		{
			_calledFromPointUpdated = true;
				(_tang as qb2IRigidObject).setTransform(_position, _rotation);
			_calledFromPointUpdated = false;
		}
		
		qb2_friend function get attachedMass():Number
		{
			if ( !_attachedJoints )  return 0;
			
			var totalMass:Number = 0;
			var queue:Vector.<qb2IRigidObject> = new Vector.<qb2IRigidObject>();
			queue.unshift(_tang as qb2IRigidObject);
			var alreadyVisited:Dictionary = new Dictionary(true);
			while ( queue.length )
			{
				var rigid:qb2IRigidObject = queue.shift();
				
				if ( alreadyVisited[rigid] || !rigid.world )  continue;
				
				totalMass += rigid.mass;
				alreadyVisited[rigid] = true;
				
				for (var i:int = 0; i < rigid.numAttachedJoints; i++) 
				{
					var joint:qb2Joint = rigid.getAttachedJointAt(i);
					
					var otherObject:qb2Tangible = joint._object1 == rigid ? joint._object2 : joint._object1;
					
					if ( otherObject )  queue.unshift(otherObject as qb2IRigidObject);
				}
			}
			
			return totalMass - _tang.mass;
		}
	}
}