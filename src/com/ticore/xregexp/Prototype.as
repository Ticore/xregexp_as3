package com.ticore.xregexp {
	
	/*!
	 * XRegExp Prototype Methods v1.0.0
	 * (c) 2012 Steven Levithan <http://xregexp.com/>
	 * MIT License
	 */
	
	/*!
	 * XRegExpAS3 Prototype Methods v1.0.0
	 * (c) 2013 Ticore Shih <http://ticore.blogspot.com/>
	 * MIT License
	 * Porting from XRegExp. create by Steven Levithan <http://xregexp.com/>
	 */
	
	/**
	 * Adds a collection of methods to `XRegExp.prototype`. RegExp objects copied by XRegExp are also
	 * augmented with any `XRegExp.prototype` methods. Hence, the following work equivalently:
	 *
	 * XRegExp('[a-z]', 'ig').xexec('abc');
	 * XRegExp(/[a-z]/ig).xexec('abc');
	 * XRegExp.globalize(/[a-z]/i).xexec('abc');
	 */
	public var Prototype:Function = (function(XRegExp:Function):* {
		

		/**
		 * Copy properties of `b` to `a`.
		 * @private
		 * @param {Object} a Object that will receive new properties.
		 * @param {Object} b Object whose properties will be copied.
		 */
		function extend(a:Object, b:Object):* {
			for (var p:String in b) {
				if (b.hasOwnProperty(p)) {
					a[p] = b[p];
				}
			}
			//return a;
		}
		
		extend(XRegExp.prototype, {
		
			/**
			 * Implicitly calls the regex's `test` method with the first value in the provided arguments array.
			 * @memberOf XRegExp.prototype
			 * @param {*} context Ignored. Accepted only for congruity with `Function.prototype.apply`.
			 * @param {Array} args Array with the string to search as its first value.
			 * @returns {Boolean} Whether the regex matched the provided value.
			 * @example
			 *
			 * XRegExp('[a-z]').apply(null, ['abc']); // -> true
			 */
			apply: function (context:*, args:Array):Boolean {
				return this.test(args[0]);
			},
			
			/**
			 * Implicitly calls the regex's `test` method with the provided string.
			 * @memberOf XRegExp.prototype
			 * @param {*} context Ignored. Accepted only for congruity with `Function.prototype.call`.
			 * @param {String} str String to search.
			 * @returns {Boolean} Whether the regex matched the provided value.
			 * @example
			 *
			 * XRegExp('[a-z]').call(null, 'abc'); // -> true
			 */
			call: function (context:*, str:String):Boolean {
				return this.test(str);
			},
			
			/**
			 * Implicitly calls {@link #XRegExp.forEach}.
			 * @memberOf XRegExp.prototype
			 * @example
			 *
			 * XRegExp('\\d').forEach('1a2345', function (match, i) {
			 *   if (i % 2) this.push(+match[0]);
			 * }, []);
			 * // -> [2, 4]
			 */
			forEach: function (str:String, callback:Function, context:* = null):* {
				return XRegExp.forEach(str, this, callback, context);
			},
			
			/**
			 * Implicitly calls {@link #XRegExp.globalize}.
			 * @memberOf XRegExp.prototype
			 * @example
			 *
			 * var globalCopy = XRegExp('regex').globalize();
			 * globalCopy.global; // -> true
			 */
			globalize: function ():RegExp {
				return XRegExp.globalize(this);
			},
			
			/**
			 * Implicitly calls {@link #XRegExp.exec}.
			 * @memberOf XRegExp.prototype
			 * @example
			 *
			 * var match = XRegExp('U\\+(?<hex>[0-9A-F]{4})').xexec('U+2620');
			 * match.hex; // -> '2620'
			 */
			xexec: function (str:String, pos:int = 0, sticky:Boolean = false):Array {
				return XRegExp.exec(str, this, pos, sticky);
			},
			
			/**
			 * Implicitly calls {@link #XRegExp.test}.
			 * @memberOf XRegExp.prototype
			 * @example
			 *
			 * XRegExp('c').xtest('abc'); // -> true
			 */
			xtest: function (str:String, pos:int = 0, sticky:Boolean = false):Boolean {
				return XRegExp.test(str, this, pos, sticky);
			}
		
		});
		
	})(XRegExp);
}