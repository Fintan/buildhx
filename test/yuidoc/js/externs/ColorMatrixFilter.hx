package ;

@:native ("ColorMatrixFilter")
extern class ColorMatrixFilter {

	private function initialize (matrix:Void):Dynamic;
	public function applyFilter (ctx:Void, x:Void, y:Void, width:Void, height:Void, targetCtx:Void, targetX:Void, targetY:Void):Dynamic;
	public function clone ():ColorMatrixFilter;
	public function toString ():String;

}