package buildhx.parsers;

import buildhx.writers.HaxeExternWriter;
import neko.io.File;
import buildhx.data.ClassDefinition;
import buildhx.data.ClassMethod;
import buildhx.data.ClassProperty;

class YUIDocParser extends SimpleParser 
{
	
	//var classes:Hash<ClassDefinition>;
	
	public function new (types:Hash <String>, definitions:Hash<ClassDefinition>) 
	{	
		super (types, definitions);
		
		if (definitions == null) {
			
			this.definitions = new Hash <ClassDefinition> ();
			
		} else {
			
			this.definitions = definitions;
			
		}
		
		if (types == null) {
			
			types = new Hash <String> ();
			
		}
		
		//classes = new Hash<ClassDefinition>();
		
		//TODO: match these to YUI Doc types
		types.set ("String", "String");
		types.set ("Number", "Float");
		types.set ("Function", "Dynamic");
		types.set ("Boolean", "Bool");
		types.set ("Object", "Dynamic");
		types.set ("undefined", "Void");
		types.set ("null", "Void");
		types.set ("", "Dynamic");
		types.set ("HTMLElement", "HtmlDom");
		types.set ("Mixed", "Dynamic");
		types.set ("Iterable", "Dynamic");
		types.set ("Array", "Array <Dynamic>");
		types.set ("RegExp", "EReg");
		
		this.types = types;
	
	}
	
	private function processFile (file:String, basePath:String):Void {
		
		BuildHX.print ("Processing " + file);
		
		var content = BuildHX.getFileContent (basePath + file);
		//var data = BuildHX.parseJSON (content);
		
		var data:YUIDocRoot = BuildHX.parseJSON (content);
		
		for (key in Reflect.fields(data.classes))
		{
			var cl:YUIClass = Reflect.field(data.classes, key);
		
			var claz = Reflect.field(data.classes, key);
			//trace("Class - "+cl.name);
			var classDef = new ClassDefinition();
			classDef.className = cl.name;
			
			
			if(Reflect.hasField(claz, "extends"))
			{
				//trace("extends "+ Reflect.field(claz, "extends"));
				classDef.parentClassName = Reflect.field(claz, "extends");
			}
			
			//classes.set(cl.name, classDef);
			definitions.set (cl.name, classDef);
			
		}
		
		var classItems:Array<YUIClassItem> = data.classitems;
		
		for(item in classItems)
		{
			var i:YUIClassItem = item;
			if(Reflect.hasField(item, "name"))
			{
				var access = i.access; //nowhere to assign this at the moment?
				if(access =="protected") access = "private";
				
				var itemType = i.itemtype;
				var ownerClass = Reflect.field(item, "class");
				//var classDef = classes.get(ownerClass);
				var classDef = definitions.get(ownerClass);
				//trace(i.clazz + "-> "+access + "  "+ itemType + " "+i.name);
				//trace(ownerClass + "-> "+access + "  "+ itemType + " "+i.name);
				
				var isStatic = false;
				
				if(Reflect.hasField(item, "static"))
				{
					isStatic = Std.parseInt(Reflect.field(item, "static")) == 1;
					//trace("isStatic "+isStatic);
				}
				
				if(itemType == "method")
				{
					var methodDef = new ClassMethod();
					methodDef.owner = ownerClass;
					methodDef.name = i.name;
					methodDef.accessModifier = access;
					
					if(Reflect.hasField(item, "params"))
					{
						var params:Array<YUIMethodParam> = i.params;
						//trace("i.params "+i.params);
						for(param in params)
						{
							//trace("param "+ param.name + ":" + param.type);
							methodDef.parameterNames.push(param.name);
							methodDef.parameterTypes.push(param.type);
							methodDef.parameterOptional.push(false);//cannot determine
						}
					}
					
					if(Reflect.hasField(item, "return"))
					{
						var returnObject:YUIReturnObject = Reflect.field(item, "return");
						//trace("returns "+returnObject.type);
						methodDef.returnType = returnObject.type;
					}
					else
					{
						methodDef.returnType = "Dynamic";
					}
					
					if(isStatic)
					{
						classDef.staticMethods.set(methodDef.name, methodDef);
					}
					else
					{
						classDef.methods.set(methodDef.name, methodDef);
					}
				
				}
				else if(itemType == "property")
				{
					var  propertyDef = new ClassProperty();
					propertyDef.owner = ownerClass;
					propertyDef.name = i.name;
					propertyDef.type = i.type;
					propertyDef.hasConflict = false;//?
					propertyDef.ignore = false;//?
					propertyDef.accessModifier = access;
					
					if(isStatic)
					{
						classDef.staticProperties.set(propertyDef.name, propertyDef);
					}
					else
					{
						classDef.properties.set(propertyDef.name, propertyDef);
					}
				}
			}
			
		}
	}
	
	public override function processFiles (files:Array <String>, basePath:String):Void 
	{	
		//expecting only one file called data.json but may be hidden files in dir (e.g., .DS_store)
		for (file in files) 
		{		
			if (file == "data.json") 
			{
				processFile (file, basePath);
				break;
			}
		}
	}
	
	private override function resolveClass (definition:ClassDefinition):Void {
		
		BuildHX.addImport (resolveImport (definition.parentClassName), definition);
		
		for (method in definition.methods) {
			
			if (method.owner == definition.className || method.owner.indexOf ("mixin") > -1) {
				BuildHX.addImport (resolveImport (method.returnType), definition);
				
				for (paramType in method.parameterTypes) {
					
					BuildHX.addImport (resolveImport (paramType), definition);
					
				}
				
			} else {
				
				method.ignore = true;
				
			}
			
		}
		
		for (property in definition.properties) {
			
			if (property.owner == definition.className || (definition.isConfigClass && property.owner == definition.className.substr (0, definition.className.length - "Config".length)) || property.owner.indexOf ("mixin") > -1) {
				
				BuildHX.addImport (resolveImport (property.type), definition);
				
			} else {
				
				property.ignore = true;
				
			}
			
		}
		
		for (method in definition.staticMethods) {
			
			if (method.owner == definition.className || method.owner.indexOf ("mixin") > -1) {
				
				BuildHX.addImport (resolveImport (method.returnType), definition);
				
				for (paramType in method.parameterTypes) {
					
					BuildHX.addImport (resolveImport (paramType), definition);
					
				}
				
			} else {
				
				method.ignore = true;
				
			}
			
		}
		
		for (property in definition.staticProperties) {
			
			if (property.owner == definition.className || property.owner.indexOf ("mixin") > -1) {
				
				BuildHX.addImport (resolveImport (property.type), definition);
				
			} else {
				
				property.ignore = true;
				
			}
			
		}
		
	}
	
	
	public override function resolveImport (type:String):String {
		
		var type = resolveType (type, false);
		
		if (type.indexOf ("Array <") > -1) {
			
			var indexOfFirstBracket = type.indexOf ("<");
			type = type.substr (indexOfFirstBracket + 1, type.indexOf (">") - indexOfFirstBracket - 1);
			
		}
		
		if (type == "HtmlDom") {
			
			type = "js.Dom";
			
		}
		
		if (type.indexOf (".") == -1) {
			
			return null;
			
		} else {
			
			return type;
			
		}
		
	}
	
	
	public override function resolveType (type:String, abbreviate:Bool = true):String {
		
		if (type == null) {
			
			return "Void";
			
		}
		
		if (type.indexOf ("|") > -1) {
			
			return "Dynamic";
			
		}
		
		var isArray = false;
		
		if (type.substr (-2) == "[]") {
			
			isArray = true;
			type = type.substr (0, type.length - 2);
			
		}
		
		var resolvedType:String = "";
		
		if (type.indexOf ("/") > -1) {
			
			resolvedType = "Dynamic";
			
		} else if (types.exists (type)) {
			
			resolvedType = types.get (type);
			
		} else {
			
			if (abbreviate) {
				
				resolvedType = BuildHX.resolveClassName (type);
				
			} else {
				
				resolvedType = BuildHX.resolvePackageNameDot (type) + BuildHX.resolveClassName (type);
				
			}
			
		}
		
		if (isArray) {
			
			return "Array <" + resolvedType + ">";
			
		} else {
			
			return resolvedType;
			
		}
		
	}
	
}

typedef YUIDocRoot =
{
	var project:Dynamic;
	var files:Dynamic;
	var modules:Dynamic;
	var classes:Dynamic; //list of classes (YUIClass)
	var classitems:Array<YUIClassItem>; //the details of each class (properties,methods)
}

typedef YUIClass =
{
	var name:String;
	var shortname:String;
	var classitems:Array<Dynamic>;
	var plugins:Array<Dynamic>;
	var extensions:Array<Dynamic>;
	var plugin_for:Array<Dynamic>;
	var extension_for:Array<Dynamic>;
	var file:String;
	var line:Int;
	var description:String;
	//var extends:String; //parent class
	var is_constructor:Int;
	var params:Array<Dynamic>;
}

typedef YUIClassItem = 
{
	var file:String;
	var line:Int;
	var description:String;
	var itemtype:String;//property
	var name:String; //of method/property
	var type:String; //a var of type Function, Number, String
	//var method:String;
	var params:Array<YUIMethodParam>; //when itemtype is a method
	//var return:YUIReturnObject; //optional
	//var class:String; //belongs to class
	var example:Array<String>;
	var access:String; //public/protected, default is public when not specified
	//var static:Int; //1 = static method or property
}

typedef YUIReturnObject = 
{
	var description:String;
	var type:String;
}

typedef YUIMethodParam =
{
	var name:String;
    var description:String;
    var type:String;
}