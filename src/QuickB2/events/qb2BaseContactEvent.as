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

package QuickB2.events 
{
	import As3Math.geo2d.*;
	import Box2DAS.Collision.b2WorldManifold;
	import Box2DAS.Common.V2;
	import Box2DAS.Dynamics.b2World;
	import Box2DAS.Dynamics.Contacts.*;
	import QuickB2.*;
	import QuickB2.objects.tangibles.qb2World;
	use namespace qb2_friend;
	
	/**
	 * ...
	 * @author Doug Koellmer
	 */
	public class qb2BaseContactEvent extends qb2Event
	{
		public function qb2BaseContactEvent(type:String)
		{
			super(type);
			
			if ( (this as Object).constructor == qb2BaseContactEvent )  throw qb2_errors.ABSTRACT_CLASS_ERROR;
		}
		
		public function get contactPoint():amPoint2d
			{  refreshContactInfo();  return _contactPoint;  }
		qb2_friend var _contactPoint:amPoint2d;
		
		public function get contactNormal():amVector2d
			{  refreshContactInfo();  return _contactNormal;  }
		qb2_friend var _contactNormal:amVector2d;
		
		public function get contactWidth():Number
			{  refreshContactInfo();  return _contactWidth;  }
		qb2_friend var _contactWidth:Number = 0;
		
		qb2_friend var _world:qb2World = null;
		
		private static const worldMani:b2WorldManifold = new b2WorldManifold();
		
		private function refreshContactInfo():void
		{
			//--- Get contact points and normals.
			var pixelsPerMeter:Number = _world.pixelsPerMeter;
			worldMani.points.length = 0;
			worldMani.normal = null;
			_contactB2.GetWorldManifold(worldMani);
			var pnt:V2 = worldMani.GetPoint();
			var point:amPoint2d = pnt && !isNaN(pnt.x) && !isNaN(pnt.y) ? new amPoint2d(pnt.x * pixelsPerMeter, pnt.y * pixelsPerMeter) : null;
			var normal:amVector2d = worldMani.normal && !isNaN(worldMani.normal.x) && !isNaN(worldMani.normal.y)? new amVector2d(worldMani.normal.x, worldMani.normal.y) : null;
			var numPoints:int = _contactB2.m_manifold.pointCount;
			var width:Number = 0;
			if ( numPoints > 1 )
			{
				var diffX:Number = worldMani.points[0].x - worldMani.points[1].x;
				var diffY:Number = worldMani.points[0].y - worldMani.points[1].y;
				width = Math.sqrt(diffX * diffX + diffY * diffY) * pixelsPerMeter;
			}
			
			_contactPoint  = point;
			_contactNormal = normal;
			_contactWidth  = width;
		}
		
		public function get b2_contact():b2Contact
			{  return _contactB2;  }
		qb2_friend var _contactB2:b2Contact;
		
		public function disableContact():void
		{
			checkForError();
			_contactB2.Disable();
		}
		public function enableContact():void
		{
			checkForError();
			_contactB2.SetEnabled(true);
		}
		
		private function checkForError():void
		{
			if ( type != qb2ContactEvent.PRE_SOLVE && type != qb2SubContactEvent.SUB_PRE_SOLVE )
				throw new Error("Contacts can only be enabled/disabled for \"pre-solve\" events.");
		}
			
		public function get isEnabled():Boolean
			{  return _contactB2.IsEnabled();  }
			
		public function get isSolid():Boolean
			{  return _contactB2.IsSolid();  }
			
		public function get isTouching():Boolean
			{  return _contactB2.IsTouching();  }
			
		public function get frictionEnabled():Boolean
			{  return !_contactB2.frictionDisabled;  }
		public function set frictionEnabled(bool:Boolean):void
			{  _contactB2.frictionDisabled = !bool;  }
	}
}