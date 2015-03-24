/*
 * PsychoMonkey
 * Copyright (C) 2012 Simon Kornblith
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
var canvas;

// Transpose an array of arrays
function transpose(array) {
	var newArray = [];
	for(var i=0; i<array[0].length; i++) {
		var newArrayX = [];
		for(var j=0; j<array.length; j++) {
			newArrayX.push(array[j][i]);
		}
		newArray.push(newArrayX);
	}
	return newArray;
}

// Repeat a value n times in an array
function repeat(x, n) {
	var out = [];
	for(var i = 0; i < n; i++) {
		out[i] = x;
	}
	return out;
}

// Convert an RGB array or scalar to CSS
function colorToStyle(color) {
	if(color === null || color === undefined) {
		return "white";
	} else if(typeof color !== "object") {
		return "rgb("+color+", "+color+", "+color+")";
	} else if(color.length === 1) {
		return "rgb("+color[0]+", "+color[0]+", "+color[0]+")";
	} else if(color.length === 3) {
		return "rgb("+color[0]+", "+color[1]+", "+color[2]+")";
	} else if(color.length === 4) {
		return "rgba("+color[0]+", "+color[1]+", "+color[2]+", "+color[3]+")";
	} else {
		throw new Error("Invalid color");
	}
}

var PTB = function(context) {
	this.ctx = context;
}
PTB.prototype = {
	"FillOval":function(color, rect) {
		this.ctx.save();
		try {
			var colorArray = this._getColorArrayOrSetColor(color, "fillStyle", "white");
			var rects = this._getRectArray(rect);
			for(var i=0; i<rects.length; i++) {
				if(colorArray) this.ctx.fillStyle = colorToStyle(colorArray[i]);
				this._makeOvalPath(rects[i]);
				this.ctx.fill();
			}
		} finally {
			this.ctx.restore();
		}
	},
	"FrameOval":function(color, rect, penWidth) {
		this.ctx.save();
		try {
			var colorArray = this._getColorArrayOrSetColor(color, "strokeStyle", "white");
			if(typeof penWidth !== "object") penWidth = [penWidth];
			if(penWidth.length === 1) this.ctx.lineWidth = penWidth ? penWidth : 1;
			var rects = this._getRectArray(rect);
			for(var i=0; i<rects.length; i++) {
				if(colorArray) this.ctx.strokeStyle = colorToStyle(colorArray[i]);
				if(penWidth.length !== 1) this.ctx.lineWidth = penWidth[i];
				this._makeOvalPath(rects[i]);
				this.ctx.stroke();
			}
		} finally {
			this.ctx.restore();
		}
	},
	"FillRect":function(color, rect) {
		this.ctx.save();
		try {
			var colorArray = this._getColorArrayOrSetColor(color, "fillStyle", "white");
			var rects = this._getRectArray(rect);
			for(var i=0; i<rects.length; i++) {
				var rect = rects[i];
				if(colorArray) this.ctx.fillStyle = colorToStyle(colorArray[i]);
				this.ctx.fillRect(rect[0], rect[1], rect[2]-rect[0], rect[3]-rect[1]);
			}
		} finally {
			this.ctx.restore();
		}
	},
	"FrameRect":function(color, rect, penWidth) {
		this.ctx.save();
		try {
			var colorArray = this._getColorArrayOrSetColor(color, "strokeStyle", "white");
			if(typeof penWidth !== "object") penWidth = [penWidth];
			if(penWidth.length === 1) this.ctx.lineWidth = penWidth ? penWidth : 1;
			var rects = this._getRectArray(rect);
			for(var i=0; i<rects.length; i++) {
				var rect = rects[i];
				if(colorArray) this.ctx.strokeStyle = colorToStyle(colorArray[i]);
				if(penWidth.length !== 1) this.ctx.lineWidth = penWidth[i];
				this.ctx.strokeRect(rect[0], rect[1], rect[2]-rect[0], rect[3]-rect[1]);
			}
		} finally {
			this.ctx.restore();
		}
	},
	"FillPoly":function(color, points) {
		this.ctx.save();
		try {
			this._getColorArrayOrSetColor(color, "fillStyle", "white");
			points = transpose(points);
			this.ctx.beginPath();
			this.ctx.moveTo(points[0][0], points[0][1]);
			for(var i = 1; i < points.length; i++) {
				this.ctx.lineTo(points[i][0], points[i][1]);
			}
			this.ctx.closePath();
			this.ctx.fill();
		} finally {
			this.ctx.restore();
		}
	},
	"FramePoly":function(color, points, penWidth) {
		this.ctx.save();
		try {
			this._getColorArrayOrSetColor(color, "strokeStyle", "white");
			this.ctx.penWidth = penWidth ? penWidth : 1;
			points = transpose(points);
			this.ctx.beginPath();
			this.ctx.moveTo(points[0][0], points[0][1]);
			for(var i = 1; i < points.length; i++) {
				this.ctx.lineTo(points[i][0], points[i][1]);
			}
			this.ctx.closePath();
		} finally {
			this.ctx.restore();
		}
	},
	"DrawDots":function(xy, size, color, center, dot_type) {
		this.ctx.save();
		try {
			if(!size) size = 1;
			if(!dot_type) dot_type = 0;
			
			var colorArray = this._getColorArrayOrSetColor(color, "fillStyle", "black");
			if(center) this.ctx.translate(center[0], center[1]);
			
			var x = typeof xy[0] === "object" ? xy[0] : [xy[0]],
				y = typeof xy[1] === "object" ? xy[1] : [xy[1]];
			for(var i=0; i<x.length; i++) {
				if(colorArray) this.ctx.fillStyle = colorToStyle(colorArray[i]);
				var dotSize = typeof size === "object" ? size[i] : size;
				if(dot_type === 0) {
					this.ctx.fillRect(x[i]-dotSize/2, y[i]-dotSize/2,
						dotSize, dotSize);
				} else {
					this.ctx.beginPath();
					this.ctx.arc(x[i], y[i], dotSize/2, 0, Math.PI*2, false);
					this.ctx.closePath();
					this.ctx.fill();
				}
			}
		} finally {
			this.ctx.restore();
		}
	},
	"_makeOvalPath":function(rect) {
		var width = rect[2]-rect[0],
			height = rect[3]-rect[1];
		this.ctx.save();
		try {
			this.ctx.beginPath();
			this.ctx.translate(rect[0]+width/2, rect[1]+height/2);
			this.ctx.scale(width/2, height/2);
			this.ctx.arc(0, 0, 1, 0, Math.PI*2, false);
			this.ctx.closePath();
		} finally {
			this.ctx.restore();
		}
	},
	"_getColorArrayOrSetColor":function(color, style, defaultColor) {
		if(color === null || color === undefined) {
			this.ctx[style] = defaultColor;
			return undefined;
		}
		if(typeof color === "object" && typeof color[0] === "object") {
			return transpose(color);
		}
		this.ctx[style] = colorToStyle(color);
		return undefined;
	},
	"_getRectArray":function(rect) {
		if(!rect) {
			return [[0, 0, CONFIG.displaySize[0], CONFIG.displaySize[1]]];
		}
		if(typeof rect[0] === "object") {
			return transpose(rect);
		}
		return [rect];
	}
};

var Client = function() {
	var ws = this.ws = new WebSocket("ws://"+window.location.hostname+":20557/"),
		client = this;
	ws.onmessage = function(event) {
		var data = event.data,
			code = data.substr(0, 3),
			payload = JSON.parse(data.substr(5));
		if(code in client) {
			client[code](payload);
		} else {
			console.error("Could not parse message: "+data);
		}
	};
	ws.onopen = function(event) {
		ws.send("PWD: "+document.getElementById("password-input").value);
	};
	ws.onclose = function() {
		document.getElementById("password").style.display = "";
		document.getElementById("password-input").focus();
	};
	
	this.canvas = canvas;
	this.ctx = canvas.getContext("2d");
	this.ptb = new PTB(this.ctx);
	this._lastEyePosition = this._currentTargets = null;
	this._currentDirectives = [];
	this._textures = {};
}
Client.prototype = {
	/**
	 * Responds to password message
	 */
	"PWD":function(accepted) {
		if(accepted) {
			document.getElementById("password").style.display = "none";
			var ws = this.ws;
			document.onkeypress = function(event) {
				var key;
				if(event.charCode) {
					key = String.fromCharCode(event.charCode).toUpperCase();
					if(key === " ") {
						key = "SPACE";
					}
				} else if(event.keyCode) {
					var keyCode = event.keyCode;
					switch (event.keyCode) {
						case event.DOM_VK_BACK_SPACE: 
						case event.DOM_VK_DELETE:
							key = "DELETE"; break;
						case event.DOM_VK_TAB:
							key = "TAB"; break;
						case event.DOM_VK_RETURN:
						case event.DOM_VK_ENTER:
							key = "RETURN"; break;
						case event.DOM_VK_ESCAPE:
							key = "ESCAPE"; break;
						case event.DOM_VK_PAGE_UP:
							key = "PAGEUP"; break;
						case event.DOM_VK_PAGE_DOWN:
							key = "PAGEDOWN"; break;
						case event.DOM_VK_END:
							key = "END"; break;
						case event.DOM_VK_HOME:
							key = "HOME"; break;
						case event.DOM_VK_LEFT:
							key = "LEFTARROW"; break;
						case event.DOM_VK_UP:
							key = "UPARROW"; break;
						case event.DOM_VK_RIGHT:
							key = "RIGHTARROW"; break;
						case event.DOM_VK_DOWN:
							key = "DOWNARROW"; break;
					}
				}
				
				if(key) {
					event.preventDefault();
					console.log("KEY: "+key);
					ws.send("KEY: "+key);
				}
			};
		} else {
			var passwordInput = document.getElementById("password-input");
			passwordInput.focus();
			passwordInput.value = "";
			passwordInput.style.background = "red";
			passwordInput.style.color = "black";
			this.ws.close();
		}
	},
	
	/**
	 * Updates the on-screen display
	 */
	"OSD":function(info) {
		document.getElementById("osd-state").textContent = info.state;
		
		var longestKey = 0,
			keyInfoStrings = [];
		for(var i in info.keyInfo) {
			if(i.length > longestKey) longestKey = i.length;
		}
		for(var i in info.keyInfo) {
			var str = i;
			while(str.length < longestKey) str += " ";
			str += " - "+info.keyInfo[i];
			keyInfoStrings.push(str);
		}
		document.getElementById("osd-keyInfo").textContent = keyInfoStrings.join("\n");
		
		var trialInfoStrings = [];
		for(var i in info.trialInfo) {
			var success = info.trialInfo[i][0];
			var total = info.trialInfo[i][1];
			if(total == 0) {
				var pct = 0;
			} else {
				var pct = Math.round(success/total*100);
			}
			trialInfoStrings.push(i+" "+success+"/"+total+" ("+pct+"%)");
		}
		document.getElementById("osd-performance").textContent = trialInfoStrings.join("\n");
	},
	
	/**
	 * Updates targets plotted over the canvas
	 */
	"TRG":function(payload) {
		this._currentTargets = payload;
		this.DRW(this._currentDirectives);
		this._drawTargets();
	},

	/**
	 * Draws a texture
	 */
	"_drawTexture":function(textureIndex, sourceRect, destinationRect, rotationAngle, globalAlpha) {
		this.ctx.save();
		var texture = this._textures[textureIndex];
		
		try {
			if(rotationAngle) this.ctx.rotate(rotationAngle*Math.PI/180);
			if(globalAlpha) this.ctx.globalAlpha = globalAlpha;
			
			if(sourceRect) {
				this.ctx.drawImage(texture, sourceRect[0], sourceRect[1],
					sourceRect[2]-sourceRect[0], sourceRect[3]-sourceRect[1],
					destinationRect[0], destinationRect[1],
					destinationRect[2]-destinationRect[0],
					destinationRect[3]-destinationRect[1]);
			} else if(destinationRect) {
				this.ctx.drawImage(texture, destinationRect[0], destinationRect[1],
					destinationRect[2]-destinationRect[0],
					destinationRect[3]-destinationRect[1]);
			} else {
				var nw = texture.naturalWidth, nh = texture.naturalHeight;
				this.ctx.drawImage(texture, cw/2-nw/2, ch/2-nh/2);
			}
		} finally {
			this.ctx.restore();
		}
	},
	
	/**
	 * Redraws the underlying image
	 */
	"DRW":function(directives) {
		var cw = this.canvas.width, ch = this.canvas.height;
		this.ctx.clearRect(0, 0, cw, ch);
		if(directives === null) return;
		this._currentDirectives = directives;
		for(var i=0; i<directives.length; i++) {
			var directive = directives[i],
				command = directive[0],
				args = directive.slice(1);
			if(command === "DrawTexture") {
				this._drawTexture(typeof args[0] === "object" ? args[0][0] : args[0], args[1], args[2], args[3], args[5]);
			} else if(command === "DrawTextures") {
				var IS_SCALAR = [true, false, false, true, true, true],
				    n = 1;
				console.log(args);
				for(var i = 0; i < IS_SCALAR.length; i++) {
					if(IS_SCALAR[i]) {
						if(typeof args[i] === "object" && args[i] !== null) {
							n = Math.max(n, args[i].length);
						}
					} else if(typeof args[i] === "object" && args[i] !== null && typeof args[i][0] === "object") {
						args[i] = transpose(args[i]);
						n = Math.max(n, args[i].length);
					}
				}
				for(var i = 0; i < IS_SCALAR.length; i++) {
					if(IS_SCALAR[i]) {
						if(typeof args[i] !== "object" || args[i] === null) {
							args[i] = repeat(args[i], n);
						}
					} else if(typeof args[i] !== "object" || args[i] === null || typeof args[i][0] !== "object") {
						args[i] = repeat(args[i], n);
					}
				}
				for(var i = 0; i < n; i++) {
					this._drawTexture(args[0][i], args[1][i], args[2][i], args[3][i], args[5][i]);
				}
			} else {
				this.ptb[command].apply(this.ptb, args);
			}
		}
		this._drawTargets();
	},
	
	/**
	 * Draws eye data
	 */
	"EYE":function(pos) {
		this.ctx.save();
		if(this._lastEyePosition
				&& (this._lastEyePosition[0] !== pos[0] || this._lastEyePosition[1] !== pos[1])) {
			this.ctx.fillStyle = "rgb(0, 0, 255)";
			this.ctx.fillRect(this._lastEyePosition[0]-2, this._lastEyePosition[1]-2, 4, 4);
		}
		if(pos[0]-2 >= 0 && pos[1]-2 >= 0 && pos[0]+2 < this.canvas.width &&
				pos[1]+2 < this.canvas.height) {
			this.ctx.fillStyle = "rgb(255, 0, 0)";
			this.ctx.fillRect(pos[0]-2, pos[1]-2, 4, 4);
			this._lastEyePosition = pos;
		}
		this.ctx.restore();
	},
	
	/**
	 * Preloads textures
	 */
	"TXT":function(textureIndices) {
		for(var i=0; i<textureIndices.length; i++) {
			var textureIndex = textureIndices[i];
			if(!this._textures[textureIndex]) {
				var img = document.createElement("img");
				img.src = "/texture/"+textureIndex+".png";
				document.getElementById("textures").appendChild(img);
				this._textures[textureIndex] = img;
			}
		}
	},
	
	/**
	 * Beeps for juice
	 * TODO: use a visual indicator instead/in addition
	 */
	"JCE":function(payload) {
		var audio = new Audio();
		if(audio.mozSetup) {
			audio.mozSetup(1, 44100);
			var samples = new Float32Array(Math.round(44100*payload.time));
			for(var i=0, l=samples.length; i<l; i++) {
				samples[i] = Math.sin(i*2*Math.PI/44100*3000);
			}
			var interval = window.setInterval(function() {
				audio.mozWriteAudio(samples);
				if(!(--payload.reps)) window.clearInterval(interval);
			}, (payload.between+payload.time)*1000);
		}
	},
	
	/**
	 * Draws targets to the screen
	 */
	"_drawTargets":function() {
		if(!this._currentTargets || !this._currentTargets.targetRects) return;
		if(typeof this._currentTargets.targetRects[0] !== "object") {
			this._currentTargets.targetRects = [this._currentTargets.targetRects];
		}
		for(var i=0; i<this._currentTargets.targetRects.length; i++) {
			var targetRect = this._currentTargets.targetRects[i],
				targetIsOval = this._currentTargets.targetIsOval;
			
			targetIsOval = targetIsOval[i] && (typeof targetIsOval[i] !== "object" || targetIsOval[i][0]);
			this.ptb[targetIsOval ? "FrameOval" : "FrameRect"]([255, 255, 0, 1], targetRect);
		}
	}
};

function onPassword() {
	new Client();
}

window.addEventListener("DOMContentLoaded", function(event) {	
	document.getElementById("password-input").focus();
	document.body.style.backgroundColor = colorToStyle(CONFIG.backgroundColor);
	
	canvas = document.createElement("canvas");
	canvas.width = CONFIG.displaySize[0];
	canvas.height = CONFIG.displaySize[1];
	canvas.id = "pmcanvas";
	document.getElementById("canvas-container").appendChild(canvas);
	document.getElementById("osd").style.height = 140/CONFIG.displaySize[1]*100+"%";
}, false);