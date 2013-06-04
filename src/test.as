package {
	import flash.display.Sprite;

	public class test extends Sprite {
		public function test() {
			
			var ns:Namespace = new Namespace();
			trace("x".match(/([\s\S])(?=[\s\S]*\1)/g).length);
			
			trace(String.prototype.ns::match.call("x", /([\s\S])(?=[\s\S]*\1)/g));
		}
	}
}
