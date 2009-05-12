/*******************************************************************************
 * PushButton Engine
 * Copyright (C) 2009 PushButton Labs, LLC
 * For more information see http://www.pushbuttonengine.com
 * 
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package PBLabs.Engine.Core
{
   import PBLabs.Engine.Debug.Logger;
   
   import flash.utils.*;
   import flash.net.LocalConnection;
   import flash.events.StatusEvent;
   
   /**
    * This class generates a schema file for the application so it can be edited by
    * the PBEditor. Classes to generate schema data for are enumerated from the
    * TypeReference class. By default, this is only run when launched from the
    * PBEngineManager, which does so by adding '?generateSchema=1' to the url.
    */
   public class SchemaGenerator
   {
      /**
       * The singleton instance.
       */
      public static function get Instance():SchemaGenerator
      {
         if (_instance == null)
            _instance = new SchemaGenerator();
         
         return _instance;
      }
      
      private static var _instance:SchemaGenerator = null;
      
      public function SchemaGenerator()
      {
         // need these built in flash classes - there's probably more we should have
         AddClass("flash.geom.Point", getDefinitionByName("flash.geom.Point") as Class);
         AddClass("flash.geom.Rectangle", getDefinitionByName("flash.geom.Rectangle") as Class);
      }
      
      /**
       * Adds a class to be included in the schema. The TypeReference class automatically
       * adds classes it is given.
       */
      public function AddClass(className:String, classObject:Class):void
      {
         _classes[className.replace("::", ".")] = classObject;
      }
      
      /**
       * Generates the actual schema data by passing the describeType output over a
       * LocalConnection. The connection is named _SchemaConnection and supplies data
       * to the OnSchemaReceived method. This method should receive two parameters.
       * The first contains the type of message being sent, and the second contains
       * the data. Valid message types are:
       * 
       * <ul>
       * <li>START - Called before any other data is sent. No data is sent with this message.</li>
       * <li>ERROR - Called to indicate an error in sending data. The data contains the error message.</li>
       * <li>COMPONENT - Called to specify that the data contains the schema for a component.</li>
       * <li>TYPE - Called to specify that the data contains the schema for a regular type.</li>
       * <li>END - Called when all schema data has been sent. No data is sent with this message.</li>
       * </ul>
       */
      public function GenerateSchema():void
      {
         if (Global.IsShippingBuild)
            return;
         
         _connection = new LocalConnection();
         _connection.addEventListener(StatusEvent.STATUS, _OnConnectionStatus);
         _connection.send("_SchemaConnection", "OnSchemaReceived", "START", "");
         
         _failed = false;
         
         var dependentClasses:Dictionary = new Dictionary();
         for each (var classObject:Class in _classes)
         {
            var description:XML = describeType(classObject);
            var isComponent:Boolean = false;
            
            var parentInterfaces:XMLList = description.factory.child("implementsInterface");
            for each (var parentInterface:XML in parentInterfaces)
            {
               // anything implementing IEntityComponent is a component
               if (parentInterface.@type.toString() == "PBLabs.Engine.Entity::IEntityComponent")
               {
                  isComponent = true;
                  break;
               }
            }
            
            // if this throws an exception, it's because the description is larger than 40k
            try
            {
               Logger.Print(this, "Sending schema data for " + description.@name);
               _connection.send("_SchemaConnection", "OnSchemaReceived", isComponent ? "COMPONENT" : "TYPE", description.toString());
            }
            catch (error:Error)
            {
               _connection.send("_SchemaConnection", "OnSchemaReceived", "ERROR", "Schema data for " + description.@name + " is too big!");
               Logger.PrintError(this, "GenerateSchema", "Schema data for " + description.@name + " is too big!");
            }
         }
         
         _connection.send("_SchemaConnection", "OnSchemaReceived", "END", "");
      }
      
      private function _OnConnectionStatus(event:StatusEvent):void
      {
         // if things already failed, it doesn't need to be reported again
         if (_failed)
            return;
         
         switch (event.level)
         {
            case "error":
               _failed = true;
               break;
         }
         
         if (_failed)
            Logger.PrintError(this, "GenerateSchema", "Schema generation failed!");
      }
      
      private var _failed:Boolean = false;
      private var _classes:Dictionary = new Dictionary();
      private var _connection:LocalConnection;
   }
}