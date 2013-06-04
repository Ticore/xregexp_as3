package com.ticore.xregexp {
	
	/*!
	 * XRegExp.build v0.1.0
	 * (c) 2012 Steven Levithan <http://xregexp.com/>
	 * MIT License
	 * Inspired by RegExp.create by Lea Verou <http://lea.verou.me/>
	 */
	
	/*!
	 * XRegExpAS3.build v0.1.0
	 * (c) 2013 Ticore Shih <http://ticore.blogspot.com/>
	 * MIT License
	 * Porting from XRegExp. create by Lea Verou <http://lea.verou.me/>
	 */
	public var Build:Function = (function(XRegExp:Function):* {
		
		var subparts:RegExp = /(\()(?!\?)|\\([1-9]\d*)|\\[\s\S]|\[(?:[^\\\]]|\\[\s\S])*]/g;
		var parts:RegExp = XRegExp.union([/\({{([\w$]+)}}\)|{{([\w$]+)}}/, subparts], "g");
		
			

		/**
		 * Strips a leading `^` and trailing unescaped `$`, if both are present.
		 * @private
		 * @param {String} pattern Pattern to process.
		 * @returns {String} Pattern with edge anchors removed.
		 */
		function deanchor(pattern:String):String {
			var startAnchor:RegExp = /^(?:\(\?:\))?\^/; // Leading `^` or `(?:)^` (handles /x cruft)
			var endAnchor:RegExp = /\$(?:\(\?:\))?$/; // Trailing `$` or `$(?:)` (handles /x cruft)
			if (endAnchor.test(pattern.replace(/\\[\s\S]/g, ""))) { // Ensure trailing `$` isn't escaped
				return pattern.replace(startAnchor, "").replace(endAnchor, "");
			}
			return pattern;
		}
		
		/**
		 * Converts the provided value to an XRegExp.
		 * @private
		 * @param {String|RegExp} value Value to convert.
		 * @returns {RegExp} XRegExp object with XRegExp syntax applied.
		 */
		function asXRegExp(value:*):RegExp {
			return XRegExp.isRegExp(value) ?
					(value.xregexp && !value.xregexp.isNative ? value : XRegExp(value.source)) :
					XRegExp(value);
		}
		
		/**
		 * Builds regexes using named subpatterns, for readability and pattern reuse. Backreferences in the
		 * outer pattern and provided subpatterns are automatically renumbered to work correctly. Native
		 * flags used by provided subpatterns are ignored in favor of the `flags` argument.
		 * @memberOf XRegExp
		 * @param {String} pattern XRegExp pattern using `{{name}}` for embedded subpatterns. Allows
		 *   `({{name}})` as shorthand for `(?<name>{{name}})`. Patterns cannot be embedded within
		 *   character classes.
		 * @param {Object} subs Lookup object for named subpatterns. Values can be strings or regexes. A
		 *   leading `^` and trailing unescaped `$` are stripped from subpatterns, if both are present.
		 * @param {String} [flags] Any combination of XRegExp flags.
		 * @returns {RegExp} Regex with interpolated subpatterns.
		 * @example
		 *
		 * var time = XRegExp.build('(?x)^ {{hours}} ({{minutes}}) $', {
		 *   hours: XRegExp.build('{{h12}} : | {{h24}}', {
		 *	 h12: /1[0-2]|0?[1-9]/,
		 *	 h24: /2[0-3]|[01][0-9]/
		 *   }, 'x'),
		 *   minutes: /^[0-5][0-9]$/
		 * });
		 * time.test('10:59'); // -> true
		 * XRegExp.exec('10:59', time).minutes; // -> '59'
		 */
		XRegExp.build = function (pattern:*, subs:Object, flags:String = ""):RegExp {
			var inlineFlags:* = /^\(\?([\w$]+)\)/.exec(pattern);
			var data:Object = {};
			var numCaps:int = 0; // Caps is short for captures
			var numPriorCaps:int;
			var numOuterCaps:int = 0;
			var outerCapsMap:Array = [0];
			var outerCapNames:Array;
			var sub:RegExp;
			var p:String;
	
			// Add flags within a leading mode modifier to the overall pattern's flags
			if (inlineFlags) {
				inlineFlags[1].replace(/./g, function (flag:String, ...args):* {
					flags += (flags.indexOf(flag) > -1 ? "" : flag); // Don't add duplicates
				});
			}
	
			for (p in subs) {
				if (subs.hasOwnProperty(p)) {
					// Passing to XRegExp enables extended syntax for subpatterns provided as strings
					// and ensures independent validity, lest an unescaped `(`, `)`, `[`, or trailing
					// `\` breaks the `(?:)` wrapper. For subpatterns provided as regexes, it dies on
					// octals and adds the `xregexp` property, for simplicity
					sub = asXRegExp(subs[p]);
					// Deanchoring allows embedding independently useful anchored regexes. If you
					// really need to keep your anchors, double them (i.e., `^^...$$`)
					data[p] = {pattern: deanchor(sub.source), names: sub.xregexp.captureNames || []};
				}
			}
	
			// Passing to XRegExp dies on octals and ensures the outer pattern is independently valid;
			// helps keep this simple. Named captures will be put back
			pattern = asXRegExp(pattern);
			outerCapNames = pattern.xregexp.captureNames || [];
			pattern = pattern.source.replace(parts, function ($0:*, $1:*, $2:*, $3:*, $4:*, ...args):String {
				var subName:String = $1 || $2;
				var capName:String;
				var intro:String;
				if (subName) { // Named subpattern
					if (!data.hasOwnProperty(subName)) {
						throw new ReferenceError("undefined property " + $0);
					}
					if ($1) { // Named subpattern was wrapped in a capturing group
						capName = outerCapNames[numOuterCaps];
						outerCapsMap[++numOuterCaps] = ++numCaps;
						// If it's a named group, preserve the name. Otherwise, use the subpattern name
						// as the capture name
						intro = "(?<" + (capName || subName) + ">";
					} else {
						intro = "(?:";
					}
					numPriorCaps = numCaps;
					return intro + data[subName].pattern.replace(subparts, function (match:*, paren:*, backref:*, ...args):String {
						if (paren) { // Capturing group
							capName = data[subName].names[numCaps - numPriorCaps];
							++numCaps;
							if (capName) { // If the current capture has a name, preserve the name
								return "(?<" + capName + ">";
							}
						} else if (backref) { // Backreference
							return "\\" + (+backref + numPriorCaps); // Rewrite the backreference
						}
						return match;
					}) + ")";
				}
				if ($3) { // Capturing group
					capName = outerCapNames[numOuterCaps];
					outerCapsMap[++numOuterCaps] = ++numCaps;
					if (capName) { // If the current capture has a name, preserve the name
						return "(?<" + capName + ">";
					}
				} else if ($4) { // Backreference
					return "\\" + outerCapsMap[+$4]; // Rewrite the backreference
				}
				return $0;
			});
	
			return XRegExp(pattern, flags);
		};
		
		
	})(XRegExp);
}