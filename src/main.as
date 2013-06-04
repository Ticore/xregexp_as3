package {
	import com.ticore.xregexp.Build;
	import com.ticore.xregexp.MatchRecursive;
	import com.ticore.xregexp.Prototype;
	import com.ticore.xregexp.UnicodeBase;
	import com.ticore.xregexp.UnicodeBlock;
	import com.ticore.xregexp.UnicodeCategories;
	import com.ticore.xregexp.UnicodeProperties;
	import com.ticore.xregexp.UnicodeScripts;
	import com.ticore.xregexp.XRegExp;
	
	import flash.display.Sprite;
	
	import mx.utils.ObjectUtil;

	public class main extends Sprite {
		
		
		public function main() {
			
			/*/
			testBasic();
			testUnicode();
			testMatchRecursive();
			testBuild();
			testPrototype();
			testUnicode();
			
			//*/
			
			testBasic();
			
		}
		
		
		
		public function testBasic():void{
			
			// Using named capture and flag x (free-spacing and line comments)
			var date:Object = XRegExp(
				'(?<year>  [0-9]{4} ) -?  # year  \n' +
				'(?<month> [0-9]{2} ) -?  # month \n' +
				'(?<day>   [0-9]{2} )     # day     ', 'x');
			
			
			trace( XRegExp.exec('2012-06-10', date).year ); // 2012
			
			trace( XRegExp.replace('2012-06-10', date, '${month}/${day}/${year}') ); // 06/10/2012
			
			
			
			// You can also pass forward and return specific backreferences
			var html:String =
								'<a href="http://xregexp.com/api/">XRegExp</a>' +
								'<a href="http://www.google.com/">Google</a>';
			
			trace( XRegExp.matchChain(html, [
				{ regex: /<a href="([^"]+)"("){0}>/i, backref: 1 },
				{ regex: XRegExp('(?i)^https?://(?<domain>[^/?#]+)'), backref: 'domain' }
			]) ); // -> ['xregexp.com', 'www.google.com']
			
			
			// Extract every other digit from a string using XRegExp.forEach
			trace( XRegExp.forEach('1a2345', /\d/, function(match:*, i:*):* {
			    if (i % 2) this.push(+match[0]);
			}, []) ); // -> [2, 4]
			
			
			// Get numbers within <b> tags using XRegExp.matchChain
			trace( XRegExp.matchChain('1 <b>2</b> 3 <b>4 a 56</b>', [
			    XRegExp('(?is)<b>.*?</b>'),
			    /\d+/
			]) ); // -> ['2', '4', '56']
			
			
			// Merge strings and regexes into a single pattern, safely rewriting backreferences
			trace( XRegExp.union(['a+b*c', /(dog)\1/, /(cat)\1/], 'i') );
			// /a\+b\*c|(dog)\1|(cat)\2/i
		}
		
		
		
		public function testUnicode():void{
			String(UnicodeBase);
			String(UnicodeCategories);
			String(UnicodeScripts);
			String(UnicodeBlock);
			String(UnicodeProperties);
			
			var unicodeWord:* = XRegExp("^\\p{L}+$");
			trace( unicodeWord.test("日本語") ); // true
			trace( unicodeWord.test("Русский") ); // true
			trace( unicodeWord.test("العربية") ); // true
			
			trace(XRegExp("^\\p{Katakana}+$").test("カタカナ")); // true
			trace(XRegExp("^\\p{Katakana}+$").test("你好")); // false
			trace(XRegExp("^\\p{Han}+$").test("你好")); // true
			
			trace( XRegExp('\\p{Sc}\\p{N}+').test("$10,009.81") ); // true , Sc: currency symbol, N: number
			trace( XRegExp('\\p{N}+').test("１２３４") ); // true , N: number
		}
		
		
		
		public function testMatchRecursive():void{
			String(MatchRecursive);
			
			var str:String;
			var result:*;
			
			str = '(t((e))s)t()(ing)';
			
			trace(XRegExp.matchRecursive(str, '\\(', '\\)', 'g')) // ['t((e))s', '', 'ing']
			
			
			// Extended information mode with valueNames
			str = 'Here is <div> <div>an</div></div> example';
			result = XRegExp.matchRecursive(str, '<div\\s*>', '</div>', 'gi', {
				valueNames: ['between', 'left', 'match', 'right']
			});
			
			trace(ObjectUtil.toString(result));
			/* [
				{name: 'between', value: 'Here is ',       start: 0,  end: 8},
				{name: 'left',    value: '<div>',          start: 8,  end: 13},
				{name: 'match',   value: ' <div>an</div>', start: 13, end: 27},
				{name: 'right',   value: '</div>',         start: 27, end: 33},
				{name: 'between', value: ' example',       start: 33, end: 41}
			] */
			
			
			// Omitting unneeded parts with null valueNames, and using escapeChar
			str = '...{1}\\{{function(x,y){return y+x;}}';
			result = XRegExp.matchRecursive(str, '{', '}', 'g', {
				valueNames: ['literal', null, 'value', null],
				escapeChar: '\\'
			});
			
			trace(ObjectUtil.toString(result));
			/* [
				{name: 'literal', value: '...', start: 0, end: 3},
				{name: 'value',   value: '1',   start: 4, end: 5},
				{name: 'literal', value: '\\{', start: 6, end: 8},
				{name: 'value',   value: 'function(x,y){return y+x;}', start: 9, end: 35}
			] */
			
			
			// Sticky mode via flag y
			str = '<1><<<2>>><3>4<5>';
			trace(XRegExp.matchRecursive(str, '<', '>', 'gy'));
			// ['1', '<<2>>', '3']
			trace(XRegExp.matchRecursive(str, '<', '>', 'g'));
			// ['1', '<<2>>', '3', '5']
		}
		
		
		
		public function testBuild():void{
			String(Build);
			
			var time:RegExp = XRegExp.build('(?x)^ {{hours}} ({{minutes}}) $', {
					hours: XRegExp.build('{{h12}} : | {{h24}}', {
					h12: /1[0-2]|0?[1-9]/,
					h24: /2[0-3]|[01][0-9]/
				}, 'x'),
				minutes: /^[0-5][0-9]$/
			});
			
			trace(time.test('10:59')); // true
			trace(XRegExp.exec('10:59', time).minutes); // '59'
		}
		
		
		
		public function testPrototype():void{
			String(Prototype);
			
			// New XRegExp regexes now gain a collection of useful methods: apply, call, forEach, globalize, xexec, and xtest.
			
			// To demonstrate the call method, let's first create the function we'll be using...
			function filter(array:Array, fn:*):Array {
				var res:Array = [];
				array.forEach(function (el:*, ...args):void {
					if (fn.call(null, el)) res.push(el);
				});
				return res;
			}
			// Now we can filter arrays using functions and regexes
			trace(filter(['a', 'ba', 'ab', 'b'], XRegExp('^a'))); // -> ['a', 'ab']
			
			
			// Native RegExp objects copied by XRegExp are augmented with any XRegExp.prototype methods.
			// The following lines therefore work equivalently:
			
			/*/
			trace(XRegExp('[a-z]', 'ig').xexec('abc'));
			trace(XRegExp(/[a-z]/ig).xexec('abc'));
			trace(XRegExp.globalize(/[a-z]/i).xexec('abc'));
			//*/
			
			var re:*;
			
			re = XRegExp('[a-z]', 'ig');
			re.xexec('abc');
			trace(re.lastIndex); // 1
			
			re = XRegExp(/[a-z]/ig);
			re.xexec('abc');
			trace(re.lastIndex); // 1
			
			re = XRegExp.globalize(/[a-z]/i);
			re.xexec('abc');
			trace(re.lastIndex); // 1
			
		}
	}
}
