package com.ticore.xregexp {

	/*!
	 * XRegExp v2.0.0
	 * (c) 2007-2012 Steven Levithan <http://xregexp.com/>
	 * MIT License
	 */
	
	/*!
	 * XRegExpAS3 v2.0.0
	 * (c) 2013 Ticore Shih <http://ticore.blogspot.com/>
	 * MIT License
	 * Porting from XRegExp. create by Steven Levithan <http://xregexp.com/>
	 */
	
	/**
	 * XRegExp provides augmented, extensible JavaScript regular expressions. You get new syntax,
	 * flags, and methods beyond what browsers support natively. XRegExp is also a regex utility belt
	 * with tools to make your client-side grepping simpler and more powerful, while freeing you from
	 * worrying about pesky cross-browser inconsistencies and the dubious `lastIndex` property. See
	 * XRegExp's documentation (http://xregexp.com/) for more details.
	 * @module xregexp
	 * @requires N/A
	 */
	public var XRegExp:* = (function():* {

		/*--------------------------------------
		 *  Private variables
		 *------------------------------------*/
		
		var ns:Namespace = new Namespace();

		var self:*;
		var addToken:*;
		var add:*;

		// Optional features; can be installed and uninstalled
		var features:* = {
				natives: false,
				extensibility: false
			};


		// Store native methods to use and restore ("native" is an ES3 reserved keyword)
		var nativ:* = {
				exec: RegExp.prototype.ns::exec,
				test: RegExp.prototype.ns::test,
				match: String.prototype.ns::match,
				replace: String.prototype.ns::replace,
				split: String.prototype.ns::split
			};


		// Storage for fixed/extended native methods
		var fixed:Object = {};

		// Storage for cached regexes
		var cache:Object = {};

		// Storage for addon tokens
		var tokens:Object = [];

		// Token scopes
		var defaultScope:String = "default";
		var classScope:String = "class";


		// Regexes that match native regex syntax
		var nativeTokens:Object = {
				// Any native multicharacter token in default scope (includes octals, excludes character classes)
				"default": /^(?:\\(?:0(?:[0-3][0-7]{0,2}|[4-7][0-7]?)?|[1-9]\d*|x[\dA-Fa-f]{2}|u[\dA-Fa-f]{4}|c[A-Za-z]|[\s\S])|\(\?[:=!]|[?*+]\?|{\d+(?:,\d*)?}\??)/,
				// Any native multicharacter token in character class scope (includes octals)
				"class": /^(?:\\(?:[0-3][0-7]{0,2}|[4-7][0-7]?|x[\dA-Fa-f]{2}|u[\dA-Fa-f]{4}|c[A-Za-z]|[\s\S]))/
			};


		// Any backreference in replacement strings
		var replacementToken:RegExp = /\$(?:{([\w$]+)}|(\d\d?|[\s\S]))/g;
		
		// Any character with a later instance in the string
		var duplicateFlags:RegExp = /([\s\S])(?=[\s\S]*\1)/g;
		
		// Any greedy/lazy quantifier
		var quantifier:RegExp = /^(?:[?*+]|{\d+(?:,\d*)?})\??/;
		
		
		// Check for correct `exec` handling of nonparticipating capturing groups
		var compliantExecNpcg:Boolean = nativ.exec.call(/()??/, "")[1] === undefined;
		
		// Check for flag y support (Firefox 3+)
		var hasNativeY:Boolean = RegExp.prototype.sticky !== undefined;
		
		// Used to kill infinite recursion during XRegExp construction
		var isInsideConstructor:Boolean = false;
		
		// Storage for known flags, including addon flags
		var registeredFlags:String = "gim" + (hasNativeY ? "y" : "");
		
		
		/*--------------------------------------
		 *  Private helper functions
		 *------------------------------------*/
		

		/**
		 * Attaches XRegExp.prototype properties and named capture supporting data to a regex object.
		 * @private
		 * @param {RegExp} regex Regex to augment.
		 * @param {Array} captureNames Array with capture names, or null.
		 * @param {Boolean} [isNative] Whether the regex was created by `RegExp` rather than `XRegExp`.
		 * @returns {RegExp} Augmented regex.
		 */

		function augment(regex:RegExp, captureNames:Array, isNative:Boolean = false):RegExp {
			// Can't auto-inherit these since the XRegExp constructor returns a nonprimitive value
			for (var p:String in self.prototype) {
				if (self.prototype.hasOwnProperty(p)) {
					regex[p] = self.prototype[p];
				}
			}
			regex["xregexp"] = {captureNames: captureNames, isNative: !!isNative};
			return regex;
		}
		


		/**
		 * Returns native `RegExp` flags used by a regex object.
		 * @private
		 * @param {RegExp} regex Regex to check.
		 * @returns {String} Native flags in use.
		 */
		function getNativeFlags(regex:RegExp):String {
			//return nativ.exec.call(/\/([a-z]*)$/i, String(regex))[1];
			return (regex.global     ? "g" : "") +
						(regex.ignoreCase ? "i" : "") +
						(regex.multiline  ? "m" : "") +
						(regex.extended   ? "x" : ""); // Proposed for ES6, included in AS3
						// + (regex.sticky     ? "y" : ""); // Proposed for ES6, included in Firefox 3+
		}
		
		

		/**
		 * Copies a regex object while preserving special properties for named capture and augmenting with
		 * `XRegExp.prototype` methods. The copy has a fresh `lastIndex` property (set to zero). Allows
		 * adding and removing flags while copying the regex.
		 * @private
		 * @param {RegExp} regex Regex to copy.
		 * @param {String} [addFlags] Flags to be added while copying the regex.
		 * @param {String} [removeFlags] Flags to be removed while copying the regex.
		 * @returns {RegExp} Copy of the provided regex, possibly with modified flags.
		 */

		function copy(regex:RegExp, addFlags:String = "", removeFlags:String = ""):RegExp {
			if (!self.isRegExp(regex)) {
				throw new TypeError("type RegExp expected");
			}
			var flags:* = nativ.replace.call(getNativeFlags(regex) + (addFlags || ""), duplicateFlags, "");
			if (removeFlags != null && removeFlags != "") {
				// Would need to escape `removeFlags` if this was public
				flags = nativ.replace.call(flags, new RegExp("[" + removeFlags + "]+", "g"), "");
			}
			if (regex["xregexp"] && !regex["xregexp"].isNative) {
				// Compiling the current (rather than precompilation) source preserves the effects of nonnative source flags
				regex = augment(self(regex.source, flags),
				regex["xregexp"].captureNames ? regex["xregexp"].captureNames.slice(0) : null);
			} else {
				// Augment with `XRegExp.prototype` methods, but use native `RegExp` (avoid searching for special tokens)
				regex = augment(new RegExp(regex.source, flags), null, true);
			}
			return regex;
		}
		
		
		
		/*
		 * Returns the last index at which a given value can be found in an array, or `-1` if it's not
		 * present. The array is searched backwards.
		 * @private
		 * @param {Array} array Array to search.
		 * @param {*} value Value to locate in the array.
		 * @returns {Number} Last zero-based index at which the item is found, or -1.
		 */

		function lastIndexOf(array:Array, value:*):int {
			var i:Number = array.length;
			if (Array.prototype.lastIndexOf) {
				return array.lastIndexOf(value); // Use the native method if available
			}
			while (i--) {
				if (array[i] === value) {
					return i;
				}
			}
			return -1;
		}
		
		
		
		/**
		 * Determines whether an object is of the specified type.
		 * @private
		 * @param {*} value Object to check.
		 * @param {String} type Type to check for, in lowercase.
		 * @returns {Boolean} Whether the object matches the type.
		 */
		/*/ 原地改用 as3 is operator 檢查
		function isType(value:*, type:String):Boolean {
			return Object.prototype.toString.call(value).toLowerCase() === "[object " + type + "]";
		}
		//*/
		
		
		
		/**
		 * Prepares an options object from the given value.
		 * @private
		 * @param {String|Object} value Value to convert to an options object.
		 * @returns {Object} Options object.
		 */
		function prepareOptions(value:Object):Object {
			value = value || {};
			// if (value === "all" || value.all) { // AS3 會報找不到屬性錯誤
			if (value === "all" || "all" in value) {
				value = {natives: true, extensibility: true};
			// } else if (isType(value, "string")) {
			} else if (value is String) {
				value = self.forEach(value, /[^\s,]+/, function (m:*):* {
					this[m] = true;
				}, {});
			}
			return value;
		}
		
		
		
		/**
		 * Runs built-in/custom tokens in reverse insertion order, until a match is found.
		 * @private
		 * @param {String} pattern Original pattern from which an XRegExp object is being built.
		 * @param {Number} pos Position to search for tokens within `pattern`.
		 * @param {String} scope Current regex scope. (Scope 應該是 String 才對)
		 * @param {Object} context Context object assigned to token handler functions.
		 * @returns {Object} Object with properties `output` (the substitution string returned by the
		 *   successful token handler) and `match` (the token's match array), or null.
		 */

		function runTokens(pattern:String, pos:int, scope:String, context:Object):Object {
			var i:int = tokens.length;
			var result:* = null;
			var match:*;
			var t:*;
			
			// trace();
			// trace("pattern:" , pattern);
			
			// Protect against constructing XRegExps within token handler and trigger functions
			isInsideConstructor = true;
			// Must reset `isInsideConstructor`, even if a `trigger` or `handler` throws
			try {
				while (i--) { // Run in reverse order
					t = tokens[i];
					if ((t.scope === "all" || t.scope === scope) && (!t.trigger || t.trigger.call(context))) {
						// trace(t.pattern);
						t.pattern.lastIndex = pos;
						match = fixed.exec.call(t.pattern, pattern); // Fixed `exec` here allows use of named backreferences, etc.
						
						// trace("match:", match);
						// trace("match.index:", match.index, pos);
						
						// if (match && match.index === pos) {
						// AS3 可能會拿到空陣列
						if (match && match.length > 0 && match.index === pos) {
							result = {
								output: t.handler.call(context, match, scope),
								match: match
							};
							break;
						}
					}
				}
			} catch (err:*) {
				throw err;
			} finally {
				isInsideConstructor = false;
			}
			return result;
		}
		
		
		
		/**
		 * Enables or disables XRegExp syntax and flag extensibility.
		 * @private
		 * @param {Boolean} on `true` to enable; `false` to disable.
		 */
		function setExtensibility(on:Boolean):void {
			self.addToken = addToken[on ? "on" : "off"];
			features.extensibility = on;
		}
		
		

		/**
		 * Enables or disables native method overrides.
		 * @private
		 * @param {Boolean} on `true` to enable; `false` to disable.
		 */
		function setNatives(on:Boolean):void {
			RegExp.prototype.exec = (on ? fixed : nativ).exec;
			RegExp.prototype.test = (on ? fixed : nativ).test;
			String.prototype.match = (on ? fixed : nativ).match;
			String.prototype.replace = (on ? fixed : nativ).replace;
			String.prototype.split = (on ? fixed : nativ).split;
			features.natives = on;
		}
		
		

		/*--------------------------------------
		 *  Constructor
		 *------------------------------------*/
		

		/**
		 * Creates an extended regular expression object for matching text with a pattern. Differs from a
		 * native regular expression in that additional syntax and flags are supported. The returned object
		 * is in fact a native `RegExp` and works with all native methods.
		 * @class XRegExp
		 * @constructor
		 * @param {String|RegExp} pattern Regex pattern string, or an existing `RegExp` object to copy.
		 * @param {String} [flags] Any combination of flags:
		 *   <li>`g` - global
		 *   <li>`i` - ignore case
		 *   <li>`m` - multiline anchors
		 *   <li>`n` - explicit capture
		 *   <li>`s` - dot matches all (aka singleline)
		 *   <li>`x` - free-spacing and line comments (aka extended)
		 *   <li>`y` - sticky (Firefox 3+ only)
		 *   Flags cannot be provided when constructing one `RegExp` from another.
		 * @returns {RegExp} Extended regular expression object.
		 * @example
		 *
		 * // With named capture and flag x
		 * date = XRegExp('(?<year>  [0-9]{4}) -?  # year  \n\
		 *                 (?<month> [0-9]{2}) -?  # month \n\
		 *                 (?<day>   [0-9]{2})     # day   ', 'x');
		 *
		 * // Passing a regex object to copy it. The copy maintains special properties for named capture,
		 * // is augmented with `XRegExp.prototype` methods, and has a fresh `lastIndex` property (set to
		 * // zero). Native regexes are not recompiled using XRegExp syntax.
		 * XRegExp(/regex/);
		 */
		self = function (pattern:*, flags:String = ""):RegExp {
			// if (self.isRegExp(pattern)) {
			if (pattern is RegExp) {
				if (flags !== null && flags !== "") {
					throw new TypeError("can't supply flags when constructing one RegExp from another");
				}
				return copy(pattern);
			}
			// Tokens become part of the regex construction process, so protect against infinite recursion
			// when an XRegExp is constructed within a token handler function
			if (isInsideConstructor) {
				throw new Error("can't call the XRegExp constructor within token definition functions");
			}
	
			var output:Array = [];
			var scope:String = defaultScope;
			var tokenContext:Object = {
					hasNamedCapture: false,
					captureNames: [],
					hasFlag: function (flag:String):Boolean {
						return flags.indexOf(flag) > -1;
					}
				};
			var pos:int = 0;
			var tokenResult:*;
			var match:*;
			var chr:*;
			pattern = pattern === null ? "" : String(pattern);
			flags = flags === null ? "" : String(flags);
	
			// AS3 match 不會回傳 null 而是空陣列
			if (nativ.match.call(flags, duplicateFlags).length != 0) {
				// Don't use test/exec because they would update lastIndex
				throw new SyntaxError("invalid duplicate regular expression flag");
			}
			// Strip/apply leading mode modifier with any combination of flags except g or y: (?imnsx)
			pattern = nativ.replace.call(pattern, /^\(\?([\w$]+)\)/, function ($0:*, $1:*):* {
				if (nativ.test.call(/[gy]/, $1)) {
					throw new SyntaxError("can't use flag g or y in mode modifier");
				}
				flags = nativ.replace.call(flags + $1, duplicateFlags, "");
				return "";
			});
			self.forEach(flags, /[\s\S]/, function (m:*):* {
				if (registeredFlags.indexOf(m[0]) < 0) {
					throw new SyntaxError("invalid regular expression flag " + m[0]);
				}
			});
	
			while (pos < pattern.length) {
				// Check for custom tokens at the current position
				tokenResult = runTokens(pattern, pos, scope, tokenContext);
				if (tokenResult) {
					output.push(tokenResult.output);
					pos += (tokenResult.match[0].length || 1);
				} else {
					// Check for native tokens (except character classes) at the current position
					match = nativ.exec.call(nativeTokens[scope], pattern.slice(pos));
					if (match) {
						output.push(match[0]);
						pos += match[0].length;
					} else {
						chr = pattern.charAt(pos);
						if (chr === "[") {
							scope = classScope;
						} else if (chr === "]") {
							scope = defaultScope;
						}
						// Advance position by one character
						output.push(chr);
						++pos;
					}
				}
			}
	
			return augment(new RegExp(output.join(""), nativ.replace.call(flags, /[^gimy]+/g, "")),
						   tokenContext.hasNamedCapture ? tokenContext.captureNames : null);
		};
		
		
		
		/*--------------------------------------
		 *  Public methods/properties
		 *------------------------------------*/
		
		// Installed and uninstalled states for `XRegExp.addToken`
		addToken = {
			on: function (regex:RegExp, handler:Function, options:Object = null):void {
				options = options || {};
				if (regex) {
					tokens.push({
						pattern: copy(regex, "g" + (hasNativeY ? "y" : "")),
						handler: handler,
						scope: options.scope || defaultScope,
						trigger: options.trigger || null
					});
				}
				// Providing `customFlags` with null `regex` and `handler` allows adding flags that do
				// nothing, but don't throw an error
				if (options.customFlags) {
					registeredFlags = nativ.replace.call(registeredFlags + options.customFlags, duplicateFlags, "");
				}
			},
			off: function ():void {
				throw new Error("extensibility must be installed before using addToken");
			}
		};

		/**
		 * Extends or changes XRegExp syntax and allows custom flags. This is used internally and can be
		 * used to create XRegExp addons. `XRegExp.install('extensibility')` must be run before calling
		 * this function, or an error is thrown. If more than one token can match the same string, the last
		 * added wins.
		 * @memberOf XRegExp
		 * @param {RegExp} regex Regex object that matches the new token.
		 * @param {Function} handler Function that returns a new pattern string (using native regex syntax)
		 *   to replace the matched token within all future XRegExp regexes. Has access to persistent
		 *   properties of the regex being built, through `this`. Invoked with two arguments:
		 *   <li>The match array, with named backreference properties.
		 *   <li>The regex scope where the match was found.
		 * @param {Object} [options] Options object with optional properties:
		 *   <li>`scope` {String} Scopes where the token applies: 'default', 'class', or 'all'.
		 *   <li>`trigger` {Function} Function that returns `true` when the token should be applied; e.g.,
		 *     if a flag is set. If `false` is returned, the matched string can be matched by other tokens.
		 *     Has access to persistent properties of the regex being built, through `this` (including
		 *     function `this.hasFlag`).
		 *   <li>`customFlags` {String} Nonnative flags used by the token's handler or trigger functions.
		 *     Prevents XRegExp from throwing an invalid flag error when the specified flags are used.
		 * @example
		 *
		 * // Basic usage: Adds \a for ALERT character
		 * XRegExp.addToken(
		 *   /\\a/,
		 *   function () {return '\\x07';},
		 *   {scope: 'all'}
		 * );
		 * XRegExp('\\a[\\a-\\n]+').test('\x07\n\x07'); // -> true
		 */
		self.addToken = addToken.off;

		/**
		 * Caches and returns the result of calling `XRegExp(pattern, flags)`. On any subsequent call with
		 * the same pattern and flag combination, the cached copy is returned.
		 * @memberOf XRegExp
		 * @param {String} pattern Regex pattern string.
		 * @param {String} [flags] Any combination of XRegExp flags.
		 * @returns {RegExp} Cached XRegExp object.
		 * @example
		 *
		 * while (match = XRegExp.cache('.', 'gs').exec(str)) {
		 *   // The regex is compiled once only
		 * }
		 */
		self.cache = function (pattern:String, flags:String):RegExp {
			var key:String = pattern + "/" + (flags || "");
			return cache[key] || (cache[key] = self(pattern, flags));
		};

		/**
		 * Escapes any regular expression metacharacters, for use when matching literal strings. The result
		 * can safely be used at any point within a regex that uses any flags.
		 * @memberOf XRegExp
		 * @param {String} str String to escape.
		 * @returns {String} String with regex metacharacters escaped.
		 * @example
		 *
		 * XRegExp.escape('Escaped? <.>');
		 * // -> 'Escaped\?\ <\.>'
		 */
		self.escape = function (str:String):String {
			return nativ.replace.call(str, /[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
		};

		/**
		 * Executes a regex search in a specified string. Returns a match array or `null`. If the provided
		 * regex uses named capture, named backreference properties are included on the match array.
		 * Optional `pos` and `sticky` arguments specify the search start position, and whether the match
		 * must start at the specified position only. The `lastIndex` property of the provided regex is not
		 * used, but is updated for compatibility. Also fixes browser bugs compared to the native
		 * `RegExp.prototype.exec` and can be used reliably cross-browser.
		 * @memberOf XRegExp
		 * @param {String} str String to search.
		 * @param {RegExp} regex Regex to search with.
		 * @param {Number} [pos=0] Zero-based index at which to start the search.
		 * @param {Boolean|String} [sticky=false] Whether the match must start at the specified position
		 *   only. The string `'sticky'` is accepted as an alternative to `true`.
		 * @returns {Array} Match array with named backreference properties, or null.
		 * @example
		 *
		 * // Basic use, with named backreference
		 * var match = XRegExp.exec('U+2620', XRegExp('U\\+(?<hex>[0-9A-F]{4})'));
		 * match.hex; // -> '2620'
		 *
		 * // With pos and sticky, in a loop
		 * var pos = 2, result = [], match;
		 * while (match = XRegExp.exec('<1><2><3><4>5<6>', /<(\d)>/, pos, 'sticky')) {
		 *   result.push(match[1]);
		 *   pos = match.index + match[0].length;
		 * }
		 * // result -> ['2', '3', '4']
		 */
		 self.exec = function (str:String, regex:RegExp, pos:int = 0, sticky:Boolean = false):Array {
		 	 var r2:RegExp = copy(regex, "g" + (sticky && hasNativeY ? "y" : ""), (sticky === false ? "y" : ""));
		 	 var match:Array;
		 	 r2.lastIndex = pos;
		 	 match = fixed.exec.call(r2, str); // Fixed `exec` required for `lastIndex` fix, etc.
		 	 if (sticky && match && match.index !== pos) {
		 	 	 match = null;
		 	 }
		 	 if (regex.global) {
		 	 	 regex.lastIndex = match ? r2.lastIndex : 0;
		 	 }
		 	 return match;
		 };

		/**
		 * Executes a provided function once per regex match.
		 * @memberOf XRegExp
		 * @param {String} str String to search.
		 * @param {RegExp} regex Regex to search with.
		 * @param {Function} callback Function to execute for each match. Invoked with four arguments:
		 *   <li>The match array, with named backreference properties.
		 *   <li>The zero-based match index.
		 *   <li>The string being traversed.
		 *   <li>The regex object being used to traverse the string.
		 * @param {*} [context] Object to use as `this` when executing `callback`.
		 * @returns {*} Provided `context` object.
		 * @example
		 *
		 * // Extracts every other digit from a string
		 * XRegExp.forEach('1a2345', /\d/, function (match, i) {
		 *   if (i % 2) this.push(+match[0]);
		 * }, []);
		 * // -> [2, 4]
		 */
		self.forEach = function (str:String, regex:RegExp, callback:Function, context:* = null):* {
			var pos:int = 0;
			var i:int = -1;
			var match:Array;
			while ((match = self.exec(str, regex, pos))) {
				callback.call(context, match, ++i, str, regex);
				pos = match.index + (match[0].length || 1);
			}
			return context;
		};

		/**
		 * Copies a regex object and adds flag `g`. The copy maintains special properties for named
		 * capture, is augmented with `XRegExp.prototype` methods, and has a fresh `lastIndex` property
		 * (set to zero). Native regexes are not recompiled using XRegExp syntax.
		 * @memberOf XRegExp
		 * @param {RegExp} regex Regex to globalize.
		 * @returns {RegExp} Copy of the provided regex with flag `g` added.
		 * @example
		 *
		 * var globalCopy = XRegExp.globalize(/regex/);
		 * globalCopy.global; // -> true
		 */
		self.globalize = function (regex:RegExp):RegExp {
			return copy(regex, "g");
		};

		/**
		 * Installs optional features according to the specified options.
		 * @memberOf XRegExp
		 * @param {Object|String} options Options object or string.
		 * @example
		 *
		 * // With an options object
		 * XRegExp.install({
		 *   // Overrides native regex methods with fixed/extended versions that support named
		 *   // backreferences and fix numerous cross-browser bugs
		 *   natives: true,
		 *
		 *   // Enables extensibility of XRegExp syntax and flags
		 *   extensibility: true
		 * });
		 *
		 * // With an options string
		 * XRegExp.install('natives extensibility');
		 *
		 * // Using a shortcut to install all optional features
		 * XRegExp.install('all');
		 */
		self.install = function (options:*):void {
			options = prepareOptions(options);
			if (!features.natives && options.natives) {
				setNatives(true);
			}
			if (!features.extensibility && options.extensibility) {
				setExtensibility(true);
			}
		};

		/**
		 * Checks whether an individual optional feature is installed.
		 * @memberOf XRegExp
		 * @param {String} feature Name of the feature to check. One of:
		 *   <li>`natives`
		 *   <li>`extensibility`
		 * @returns {Boolean} Whether the feature is installed.
		 * @example
		 *
		 * XRegExp.isInstalled('natives');
		 */
		self.isInstalled = function (feature:String):Boolean {
			return !!(features[feature]);
		};

		/**
		 * Returns `true` if an object is a regex; `false` if it isn't. This works correctly for regexes
		 * created in another frame, when `instanceof` and `constructor` checks would fail.
		 * @memberOf XRegExp
		 * @param {*} value Object to check.
		 * @returns {Boolean} Whether the object is a `RegExp` object.
		 * @example
		 *
		 * XRegExp.isRegExp('string'); // -> false
		 * XRegExp.isRegExp(/regex/i); // -> true
		 * XRegExp.isRegExp(RegExp('^', 'm')); // -> true
		 * XRegExp.isRegExp(XRegExp('(?s).')); // -> true
		 */
		self.isRegExp = function (value:*):Boolean {
			return value is RegExp;
		};

		/**
		 * Retrieves the matches from searching a string using a chain of regexes that successively search
		 * within previous matches. The provided `chain` array can contain regexes and objects with `regex`
		 * and `backref` properties. When a backreference is specified, the named or numbered backreference
		 * is passed forward to the next regex or returned.
		 * @memberOf XRegExp
		 * @param {String} str String to search.
		 * @param {Array} chain Regexes that each search for matches within preceding results.
		 * @returns {Array} Matches by the last regex in the chain, or an empty array.
		 * @example
		 *
		 * // Basic usage; matches numbers within <b> tags
		 * XRegExp.matchChain('1 <b>2</b> 3 <b>4 a 56</b>', [
		 *   XRegExp('(?is)<b>.*?</b>'),
		 *   /\d+/
		 * ]);
		 * // -> ['2', '4', '56']
		 *
		 * // Passing forward and returning specific backreferences
		 * html = '<a href="http://xregexp.com/api/">XRegExp</a>\
		 *         <a href="http://www.google.com/">Google</a>';
		 * XRegExp.matchChain(html, [
		 *   {regex: /<a href="([^"]+)">/i, backref: 1},
		 *   {regex: XRegExp('(?i)^https?://(?<domain>[^/?#]+)'), backref: 'domain'}
		 * ]);
		 * // -> ['xregexp.com', 'www.google.com']
		 */
		self.matchChain = function (str:String, chain:Array):Array {
			return (function recurseChain(values:Array, level:int):Array {
				var item:Object = chain[level].regex ? chain[level] : {regex: chain[level]};
				var matches:Array = [];
				var addMatch:Function = function (match:*, ...args):void {
						matches.push(item.backref ? (match[item.backref] || "") : match[0]);
					};
				for (var i:int = 0; i < values.length; ++i) {
					self.forEach(values[i], item.regex, addMatch);
				}
				return ((level === chain.length - 1) || !matches.length) ?
						matches :
						recurseChain(matches, level + 1);
			}([str], 0));
		};

		/**
		 * Returns a new string with one or all matches of a pattern replaced. The pattern can be a string
		 * or regex, and the replacement can be a string or a function to be called for each match. To
		 * perform a global search and replace, use the optional `scope` argument or include flag `g` if
		 * using a regex. Replacement strings can use `${n}` for named and numbered backreferences.
		 * Replacement functions can use named backreferences via `arguments[0].name`. Also fixes browser
		 * bugs compared to the native `String.prototype.replace` and can be used reliably cross-browser.
		 * @memberOf XRegExp
		 * @param {String} str String to search.
		 * @param {RegExp|String} search Search pattern to be replaced.
		 * @param {String|Function} replacement Replacement string or a function invoked to create it.
		 *   Replacement strings can include special replacement syntax:
		 *     <li>$$ - Inserts a literal '$'.
		 *     <li>$&, $0 - Inserts the matched substring.
		 *     <li>$` - Inserts the string that precedes the matched substring (left context).
		 *     <li>$' - Inserts the string that follows the matched substring (right context).
		 *     <li>$n, $nn - Where n/nn are digits referencing an existent capturing group, inserts
		 *       backreference n/nn.
		 *     <li>${n} - Where n is a name or any number of digits that reference an existent capturing
		 *       group, inserts backreference n.
		 *   Replacement functions are invoked with three or more arguments:
		 *     <li>The matched substring (corresponds to $& above). Named backreferences are accessible as
		 *       properties of this first argument.
		 *     <li>0..n arguments, one for each backreference (corresponding to $1, $2, etc. above).
		 *     <li>The zero-based index of the match within the total search string.
		 *     <li>The total string being searched.
		 * @param {String} [scope='one'] Use 'one' to replace the first match only, or 'all'. If not
		 *   explicitly specified and using a regex with flag `g`, `scope` is 'all'.
		 * @returns {String} New string with one or all matches replaced.
		 * @example
		 *
		 * // Regex search, using named backreferences in replacement string
		 * var name = XRegExp('(?<first>\\w+) (?<last>\\w+)');
		 * XRegExp.replace('John Smith', name, '${last}, ${first}');
		 * // -> 'Smith, John'
		 *
		 * // Regex search, using named backreferences in replacement function
		 * XRegExp.replace('John Smith', name, function (match) {
		 *   return match.last + ', ' + match.first;
		 * });
		 * // -> 'Smith, John'
		 *
		 * // Global string search/replacement
		 * XRegExp.replace('RegExp builds RegExps', 'RegExp', 'XRegExp', 'all');
		 * // -> 'XRegExp builds XRegExps'
		 */
		self.replace = function (str:String, search:*, replacement:*, scope:* = null):String {
			var isRegex:Boolean = self.isRegExp(search);
			var search2:* = search;
			var result:String;
			if (isRegex) {
				if (scope === undefined && search.global) {
					scope = "all"; // Follow flag g when `scope` isn't explicit
				}
				// Note that since a copy is used, `search`'s `lastIndex` isn't updated *during* replacement iterations
				search2 = copy(search, scope === "all" ? "g" : "", scope === "all" ? "" : "g");
			} else if (scope === "all") {
				search2 = new RegExp(self.escape(String(search)), "g");
			}
			result = fixed.replace.call(String(str), search2, replacement); // Fixed `replace` required for named backreferences, etc.
			if (isRegex && search.global) {
				search.lastIndex = 0; // Fixes IE, Safari bug (last tested IE 9, Safari 5.1)
			}
			return result;
		};

		/**
		 * Splits a string into an array of strings using a regex or string separator. Matches of the
		 * separator are not included in the result array. However, if `separator` is a regex that contains
		 * capturing groups, backreferences are spliced into the result each time `separator` is matched.
		 * Fixes browser bugs compared to the native `String.prototype.split` and can be used reliably
		 * cross-browser.
		 * @memberOf XRegExp
		 * @param {String} str String to split.
		 * @param {RegExp|String} separator Regex or string to use for separating the string.
		 * @param {Number} [limit] Maximum number of items to include in the result array.
		 * @returns {Array} Array of substrings.
		 * @example
		 *
		 * // Basic use
		 * XRegExp.split('a b c', ' ');
		 * // -> ['a', 'b', 'c']
		 *
		 * // With limit
		 * XRegExp.split('a b c', ' ', 2);
		 * // -> ['a', 'b']
		 *
		 * // Backreferences in result array
		 * XRegExp.split('..word1..', /([a-z]+)(\d+)/i);
		 * // -> ['..', 'word', '1', '..']
		 */
		self.split = function (str:String, separator:*, limit:int):Array {
			return fixed.split.call(str, separator, limit);
		};
		
		/**
		 * Executes a regex search in a specified string. Returns `true` or `false`. Optional `pos` and
		 * `sticky` arguments specify the search start position, and whether the match must start at the
		 * specified position only. The `lastIndex` property of the provided regex is not used, but is
		 * updated for compatibility. Also fixes browser bugs compared to the native
		 * `RegExp.prototype.test` and can be used reliably cross-browser.
		 * @memberOf XRegExp
		 * @param {String} str String to search.
		 * @param {RegExp} regex Regex to search with.
		 * @param {Number} [pos=0] Zero-based index at which to start the search.
		 * @param {Boolean|String} [sticky=false] Whether the match must start at the specified position
		 *   only. The string `'sticky'` is accepted as an alternative to `true`.
		 * @returns {Boolean} Whether the regex matched the provided value.
		 * @example
		 *
		 * // Basic use
		 * XRegExp.test('abc', /c/); // -> true
		 *
		 * // With pos and sticky
		 * XRegExp.test('abc', /c/, 0, 'sticky'); // -> false
		 */
		self.test = function (str:String, regex:RegExp, pos:int = 0, sticky:Boolean = false):Boolean {
			// Do this the easy way :-)
			return !!self.exec(str, regex, pos, sticky);
		};

		/**
		 * Uninstalls optional features according to the specified options.
		 * @memberOf XRegExp
		 * @param {Object|String} options Options object or string.
		 * @example
		 *
		 * // With an options object
		 * XRegExp.uninstall({
		 *   // Restores native regex methods
		 *   natives: true,
		 *
		 *   // Disables additional syntax and flag extensions
		 *   extensibility: true
		 * });
		 *
		 * // With an options string
		 * XRegExp.uninstall('natives extensibility');
		 *
		 * // Using a shortcut to uninstall all optional features
		 * XRegExp.uninstall('all');
		 */
		self.uninstall = function (options:Object):void {
			options = prepareOptions(options);
			if (features.natives && options.natives) {
				setNatives(false);
			}
			if (features.extensibility && options.extensibility) {
				setExtensibility(false);
			}
		};

		/**
		 * Returns an XRegExp object that is the union of the given patterns. Patterns can be provided as
		 * regex objects or strings. Metacharacters are escaped in patterns provided as strings.
		 * Backreferences in provided regex objects are automatically renumbered to work correctly. Native
		 * flags used by provided regexes are ignored in favor of the `flags` argument.
		 * @memberOf XRegExp
		 * @param {Array} patterns Regexes and strings to combine.
		 * @param {String} [flags] Any combination of XRegExp flags.
		 * @returns {RegExp} Union of the provided regexes and strings.
		 * @example
		 *
		 * XRegExp.union(['a+b*c', /(dogs)\1/, /(cats)\1/], 'i');
		 * // -> /a\+b\*c|(dogs)\1|(cats)\2/i
		 *
		 * XRegExp.union([XRegExp('(?<pet>dogs)\\k<pet>'), XRegExp('(?<pet>cats)\\k<pet>')]);
		 * // -> XRegExp('(?<pet>dogs)\\k<pet>|(?<pet>cats)\\k<pet>')
		 */
		self.union = function (patterns:Array, flags:String = ""):RegExp {
			var parts:RegExp = /(\()(?!\?)|\\([1-9]\d*)|\\[\s\S]|\[(?:[^\\\]]|\\[\s\S])*]/g;
			var numCaptures:int = 0;
			var numPriorCaptures:int;
			var captureNames:Array;
			var rewrite:Function = function (match:*, paren:*, backref:*, ...args):String {
					var name:String = captureNames[numCaptures - numPriorCaptures];
					if (paren) { // Capturing group
						++numCaptures;
						if (name) { // If the current capture has a name
							return "(?<" + name + ">";
						}
					} else if (backref) { // Backreference
						return "\\" + (+backref + numPriorCaptures);
					}
					return match;
				};
			var output:Array = [];
			var pattern:*;
			if (!(patterns is Array && patterns.length)) {
				throw new TypeError("patterns must be a nonempty array");
			}
			for (var i:int = 0; i < patterns.length; ++i) {
				pattern = patterns[i];
				if (self.isRegExp(pattern)) {
					numPriorCaptures = numCaptures;
					captureNames = (pattern.xregexp && pattern.xregexp.captureNames) || [];
					// Rewrite backreferences. Passing to XRegExp dies on octals and ensures patterns
					// are independently valid; helps keep this simple. Named captures are put back
					output.push(self(pattern.source).source.replace(parts, rewrite));
				} else {
					output.push(self.escape(pattern));
				}
			}
			return self(output.join("|"), flags);
		};

		/**
		 * The XRegExp version number.
		 * @static
		 * @memberOf XRegExp
		 * @type String
		 */
		 self.version = "2.0.0";
		
		
		

		/*--------------------------------------
		 *  Fixed/extended native methods
		 *------------------------------------*/

		/**
		 * Adds named capture support (with backreferences returned as `result.name`), and fixes browser
		 * bugs in the native `RegExp.prototype.exec`. Calling `XRegExp.install('natives')` uses this to
		 * override the native method. Use via `XRegExp.exec` without overriding natives.
		 * @private
		 * @param {String} str String to search.
		 * @returns {Array} Match array with named backreference properties, or null.
		 */
		fixed.exec = function (str:String):Array {
			var match:Array;
			var name:String;
			var r2:RegExp;
			var origLastIndex:int;
			var i:int;
			if (!this.global) {
				origLastIndex = this.lastIndex;
			}
			match = nativ.exec.apply(this, arguments);
			if (match) {
				// Fix browsers whose `exec` methods don't consistently return `undefined` for
				// nonparticipating capturing groups
				if (!compliantExecNpcg && match.length > 1 && lastIndexOf(match, "") > -1) {
					r2 = new RegExp(this.source, nativ.replace.call(getNativeFlags(this), "g", ""));
					// Using `str.slice(match.index)` rather than `match[0]` in case lookahead allowed
					// matching due to characters outside the match
					nativ.replace.call(String(str).slice(match.index), r2, function ():* {
						for (var i:int = 1; i < arguments.length - 2; ++i) {
							if (arguments[i] === undefined) {
								match[i] = undefined;
							}
						}
					});
				}
				// Attach named capture properties
				if (this.xregexp && this.xregexp.captureNames) {
					for (i = 1; i < match.length; ++i) {
						name = this.xregexp.captureNames[i - 1];
						if (name) {
							match[name] = match[i];
						}
					}
				}
				// Fix browsers that increment `lastIndex` after zero-length matches
				if (this.global && !match[0].length && (this.lastIndex > match.index)) {
					this.lastIndex = match.index;
				}
			}
			if (!this.global) {
				this.lastIndex = origLastIndex; // Fixes IE, Opera bug (last tested IE 9, Opera 11.6)
			}
			return match;
		};
		

		/**
		 * Fixes browser bugs in the native `RegExp.prototype.test`. Calling `XRegExp.install('natives')`
		 * uses this to override the native method.
		 * @private
		 * @param {String} str String to search.
		 * @returns {Boolean} Whether the regex matched the provided value.
		 */
		fixed.test = function (str:String):Boolean {
			// Do this the easy way :-)
			return !!fixed.exec.call(this, str);
		};
		

		/**
		 * Adds named capture support (with backreferences returned as `result.name`), and fixes browser
		 * bugs in the native `String.prototype.match`. Calling `XRegExp.install('natives')` uses this to
		 * override the native method.
		 * @private
		 * @param {RegExp} regex Regex to search with.
		 * @returns {Array} If `regex` uses flag g, an array of match strings or null. Without flag g, the
		 *   result of calling `regex.exec(this)`.
		 */
		fixed.match = function (regex:RegExp):Array {
			if (!self.isRegExp(regex)) {
				regex = new RegExp(regex); // Use native `RegExp`
			} else if (regex.global) {
				var result:Array = nativ.match.apply(this, arguments);
				regex.lastIndex = 0; // Fixes IE bug
				return result;
			}
			return fixed.exec.call(regex, this);
		};
		
		
		/**
		 * Adds support for `${n}` tokens for named and numbered backreferences in replacement text, and
		 * provides named backreferences to replacement functions as `arguments[0].name`. Also fixes
		 * browser bugs in replacement text syntax when performing a replacement using a nonregex search
		 * value, and the value of a replacement regex's `lastIndex` property during replacement iterations
		 * and upon completion. Note that this doesn't support SpiderMonkey's proprietary third (`flags`)
		 * argument. Calling `XRegExp.install('natives')` uses this to override the native method. Use via
		 * `XRegExp.replace` without overriding natives.
		 * @private
		 * @param {RegExp|String} search Search pattern to be replaced.
		 * @param {String|Function} replacement Replacement string or a function invoked to create it.
		 * @returns {String} New string with one or all matches replaced.
		 */
		fixed.replace = function (search:*, replacement:*):String {
			var isRegex:Boolean = self.isRegExp(search);
			var captureNames:Array;
			var result:String;
			var str:String;
			var origLastIndex:int;
			if (isRegex) {
				if (search.xregexp) {
					captureNames = search.xregexp.captureNames;
				}
				if (!search.global) {
					origLastIndex = search.lastIndex;
				}
			} else {
				search += "";
			}
			if (replacement is Function) {
				result = nativ.replace.call(String(this), search, function ():String {
					var args:Array = arguments;
					var i:int;
					if (captureNames) {
						// Change the `arguments[0]` string primitive to a `String` object that can store properties
						args[0] = new String(args[0]);
						// Store named backreferences on the first argument
						for (i = 0; i < captureNames.length; ++i) {
							if (captureNames[i]) {
								args[0][captureNames[i]] = args[i + 1];
							}
						}
					}
					// Update `lastIndex` before calling `replacement`.
					// Fixes IE, Chrome, Firefox, Safari bug (last tested IE 9, Chrome 17, Firefox 11, Safari 5.1)
					if (isRegex && search.global) {
						search.lastIndex = args[args.length - 2] + args[0].length;
					}
					return replacement.apply(null, args);
				});
			} else {
				str = String(this); // Ensure `args[args.length - 1]` will be a string when given nonstring `this`
				result = nativ.replace.call(str, search, function():String {
					var args:Array = arguments; // Keep this function's `arguments` available through closure
					return nativ.replace.call(String(replacement), replacementToken, function ($0:*, $1:*, $2:*, $3:*, $4:*):String {
						var n:int;
						// Named or numbered backreference with curly brackets
						if ($1) {
							/* XRegExp behavior for `${n}`:
							 * 1. Backreference to numbered capture, where `n` is 1+ digits. `0`, `00`, etc. is the entire match.
							 * 2. Backreference to named capture `n`, if it exists and is not a number overridden by numbered capture.
							 * 3. Otherwise, it's an error.
							 */
							// n = +$1; // Type-convert; drop leading zeros
							n = Number($1); // Type-convert; drop leading zeros
							if (n <= args.length - 3) {
								return args[n] || "";
							}
							n = captureNames ? lastIndexOf(captureNames, $1) : -1;
							if (n < 0) {
								throw new SyntaxError("backreference to undefined group " + $0);
							}
							return args[n + 1] || "";
						}
						// Else, special variable or numbered backreference (without curly brackets)
						if ($2 === "$") return "$";
						if ($2 === "&" || Number($2) === 0) return args[0]; // $&, $0 (not followed by 1-9), $00
						if ($2 === "`") return args[args.length - 1].slice(0, args[args.length - 2]);
						if ($2 === "'") return args[args.length - 1].slice(args[args.length - 2] + args[0].length);
						// Else, numbered backreference (without curly brackets)
						$2 = Number($2); // Type-convert; drop leading zero
						/* XRegExp behavior:
						 * - Backreferences without curly brackets end after 1 or 2 digits. Use `${..}` for more digits.
						 * - `$1` is an error if there are no capturing groups.
						 * - `$10` is an error if there are less than 10 capturing groups. Use `${1}0` instead.
						 * - `$01` is equivalent to `$1` if a capturing group exists, otherwise it's an error.
						 * - `$0` (not followed by 1-9), `$00`, and `$&` are the entire match.
						 * Native behavior, for comparison:
						 * - Backreferences end after 1 or 2 digits. Cannot use backreference to capturing group 100+.
						 * - `$1` is a literal `$1` if there are no capturing groups.
						 * - `$10` is `$1` followed by a literal `0` if there are less than 10 capturing groups.
						 * - `$01` is equivalent to `$1` if a capturing group exists, otherwise it's a literal `$01`.
						 * - `$0` is a literal `$0`. `$&` is the entire match.
						 */
						if (!isNaN($2)) {
							if ($2 > args.length - 3) {
								throw new SyntaxError("backreference to undefined group " + $0);
							}
							return args[$2] || "";
						}
						throw new SyntaxError("invalid token " + $0);
					});
				});
			}
			if (isRegex) {
				if (search.global) {
					search.lastIndex = 0; // Fixes IE, Safari bug (last tested IE 9, Safari 5.1)
				} else {
					search.lastIndex = origLastIndex; // Fixes IE, Opera bug (last tested IE 9, Opera 11.6)
				}
			}
			return result;
		};
		
		
		/**
		 * Fixes browser bugs in the native `String.prototype.split`. Calling `XRegExp.install('natives')`
		 * uses this to override the native method. Use via `XRegExp.split` without overriding natives.
		 * @private
		 * @param {RegExp|String} separator Regex or string to use for separating the string.
		 * @param {Number} [limit] Maximum number of items to include in the result array.
		 * @returns {Array} Array of substrings.
		 */
		fixed.split = function (separator:*, limit:int = -1):Array {
			if (!self.isRegExp(separator)) {
				return nativ.split.apply(this, arguments); // use faster native method
			}
			var str:String = String(this);
			var origLastIndex:int = separator.lastIndex;
			var output:Array = [];
			var lastLastIndex:int = 0;
			var lastLength:int;
			/* Values for `limit`, per the spec:
			 * If undefined: pow(2,32) - 1
			 * If 0, Infinity, or NaN: 0
			 * If positive number: limit = floor(limit); if (limit >= pow(2,32)) limit -= pow(2,32);
			 * If negative number: pow(2,32) - floor(abs(limit))
			 * If other: Type-convert, then use the above rules
			 */
			// limit = (limit === undefined ? -1 : limit) >>> 0;
			self.forEach(str, separator, function (match:Array):void {
				if ((match.index + match[0].length) > lastLastIndex) { // != `if (match[0].length)`
					output.push(str.slice(lastLastIndex, match.index));
					if (match.length > 1 && match.index < str.length) {
						Array.prototype.push.apply(output, match.slice(1));
					}
					lastLength = match[0].length;
					lastLastIndex = match.index + lastLength;
				}
			});
			if (lastLastIndex === str.length) {
				if (!nativ.test.call(separator, "") || lastLength) {
					output.push("");
				}
			} else {
				output.push(str.slice(lastLastIndex));
			}
			separator.lastIndex = origLastIndex;
			return output.length > limit ? output.slice(0, limit) : output;
		};
		
		
		
		/*--------------------------------------
		 *  Built-in tokens
		 *------------------------------------*/

		// Shortcut
		add = addToken.on;

		/* Letter identity escapes that natively match literal characters: \p, \P, etc.
		 * Should be SyntaxErrors but are allowed in web reality. XRegExp makes them errors for cross-
		 * browser consistency and to reserve their syntax, but lets them be superseded by XRegExp addons.
		 */
		add(/\\([ABCE-RTUVXYZaeg-mopqyz]|c(?![A-Za-z])|u(?![\dA-Fa-f]{4})|x(?![\dA-Fa-f]{2}))/,
			function (match:Array, scope:String):String {
				// \B is allowed in default scope only
				if (match[1] === "B" && scope === defaultScope) {
					return match[0];
				}
				throw new SyntaxError("invalid escape " + match[0]);
			},
			{scope: "all"});

		/* Empty character class: [] or [^]
		 * Fixes a critical cross-browser syntax inconsistency. Unless this is standardized (per the spec),
		 * regex syntax can't be accurately parsed because character class endings can't be determined.
		 */
		add(/\[(\^?)]/,
			function (match:Array, scope:String):String {
				// For cross-browser compatibility with ES3, convert [] to \b\B and [^] to [\s\S].
				// (?!) should work like \b\B, but is unreliable in Firefox
				return match[1] ? "[\\s\\S]" : "\\b\\B";
			});

		/* Comment pattern: (?# )
		 * Inline comments are an alternative to the line comments allowed in free-spacing mode (flag x).
		 */
		add(/(?:\(\?#[^)]*\))+/,
			function (match:Array, scope:String):String {
				// Keep tokens separated unless the following token is a quantifier
				return nativ.test.call(quantifier, match.input.slice(match.index + match[0].length)) ? "" : "(?:)";
			});
		
		/* Named backreference: \k<name>
		 * Backreference names can use the characters A-Z, a-z, 0-9, _, and $ only.
		 */
		add(/\\k<([\w$]+)>/,
			function (match:Array, scope:String):String {
				var index:int = isNaN(match[1]) ? (lastIndexOf(this.captureNames, match[1]) + 1) : +match[1];
				var endIndex:int = match.index + match[0].length;
				if (!index || index > this.captureNames.length) {
					throw new SyntaxError("backreference to undefined group " + match[0]);
				}
				// Keep backreferences separate from subsequent literal numbers
				return "\\" + index + (
					endIndex === match.input.length || isNaN(match.input.charAt(endIndex)) ? "" : "(?:)"
				);
			});
		
		/* Whitespace and line comments, in free-spacing mode (aka extended mode, flag x) only.
		 */
		add(/(?:\s+|#.*)+/,
			function (match:Array, scope:String):String {
				// Keep tokens separated unless the following token is a quantifier
				return nativ.test.call(quantifier, match.input.slice(match.index + match[0].length)) ? "" : "(?:)";
			},
			{
				trigger: function ():Boolean {
					return this.hasFlag("x");
				},
				customFlags: "x"
			});
		
		/* Dot, in dotall mode (aka singleline mode, flag s) only.
		 */
		add(/\./,
			function (match:Array, scope:String):String {
				return "[\\s\\S]";
			},
			{
				trigger: function ():Boolean {
					return this.hasFlag("s");
				},
				customFlags: "s"
			});
		
		
		

		/* Named capturing group; match the opening delimiter only: (?<name>
		 * Capture names can use the characters A-Z, a-z, 0-9, _, and $ only. Names can't be integers.
		 * Supports Python-style (?P<name> as an alternate syntax to avoid issues in recent Opera (which
		 * natively supports the Python-style syntax). Otherwise, XRegExp might treat numbered
		 * backreferences to Python-style named capture as octals.
		 */
		add(/\(\?P?<([\w$]+)>/,
			function (match:Array, scope:String):String {
				if (!isNaN(match[1])) {
					// Avoid incorrect lookups, since named backreferences are added to match arrays
					throw new SyntaxError("can't use integer as capture name " + match[0]);
				}
				this.captureNames.push(match[1]);
				this.hasNamedCapture = true;
				return "(";
			});
		
		/* Numbered backreference or octal, plus any following digits: \0, \11, etc.
		 * Octals except \0 not followed by 0-9 and backreferences to unopened capture groups throw an
		 * error. Other matches are returned unaltered. IE <= 8 doesn't support backreferences greater than
		 * \99 in regex syntax.
		 */
		add(/\\(\d+)/,
			function (match:Array, scope:String):String {
				if (!(scope === defaultScope && /^[1-9]/.test(match[1]) && +match[1] <= this.captureNames.length) &&
						match[1] !== "0") {
					throw new SyntaxError("can't use octal escape or backreference to undefined group " + match[0]);
				}
				return match[0];
			},
			{scope: "all"});
		
		/* Capturing group; match the opening parenthesis only.
		 * Required for support of named capturing groups. Also adds explicit capture mode (flag n).
		 */
		add(/\((?!\?)/,
			function (match:Array, scope:String):String {
				if (this.hasFlag("n")) {
					return "(?:";
				}
				this.captureNames.push(null);
				return "(";
			},
			{customFlags: "n"});
		 
		 
		 
		
		/*--------------------------------------
		 *  Expose XRegExp
		 *------------------------------------*/
		
 	   return self;
	})();

}
