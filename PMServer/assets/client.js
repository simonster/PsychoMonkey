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
				if(colorArray) this.ctx.fillStyle = this._colorToStyle(colorArray[i]);
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
				if(colorArray) this.ctx.strokeStyle = this._colorToStyle(colorArray[i]);
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
				if(colorArray) this.ctx.fillStyle = this._colorToStyle(colorArray[i]);
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
				if(colorArray) this.ctx.strokeStyle = this._colorToStyle(colorArray[i]);
				if(penWidth.length !== 1) this.ctx.lineWidth = penWidth[i];
				this.ctx.strokeRect(rect[0], rect[1], rect[2]-rect[0], rect[3]-rect[1]);
			}
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
				if(colorArray) this.ctx.fillStyle = this._colorToStyle(colorArray[i]);
				var dotSize = typeof size === "object" ? size[i] : size;
				if(dot_type === 0) {
					this.ctx.fillRect(x[i]-dotSize/2, y[i]-dotSize/2,
						x[i]+dotSize/2, y[i]+dotSize/2);
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
	"_transpose":function(array) {
		var newArray = [];
		for(var i=0; i<array[0].length; i++) {
			var newArrayX = [];
			for(var j=0; j<array.length; j++) {
				newArrayX.push(array[j][i]);
			}
			newArray.push(newArrayX);
		}
		return newArray;
	},
	"_makeOvalPath":function(rect) {
		var width = rect[2]-rect[0],
			height = rect[3]-rect[1];
		this.ctx.beginPath();
		this.ctx.translate(rect[0]+width/2, rect[1]+height/2);
		this.ctx.scale(width/2, height/2);
		this.ctx.arc(0, 0, 1, 0, Math.PI*2, false);
		this.ctx.closePath();
	},
	"_getColorArrayOrSetColor":function(color, style, defaultColor) {
		if(color === null || color === undefined) {
			this.ctx[style] = defaultColor;
			return undefined;
		}
		if(typeof color === "object" && typeof color[0] === "object") {
			return this._transpose(color);
		}
		this.ctx[style] = this._colorToStyle(color);
		return undefined;
	},
	"_getRectArray":function(rect) {
		if(!rect) {
			return [[0, 0, CONFIG.displaySize[0], CONFIG.displaySize[1]]];
		}
		if(typeof rect[0] === "object") {
			return this._transpose(rect);
		}
		return [rect];
	},
	"_colorToStyle":function(color) {
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
};

var OSD = function(div) {
};
OSD.prototype.update = function(info) {
};

var Client = function(canvas) {
	this.canvas = canvas;
	this.ctx = canvas.getContext("2d");
	this.ptb = new PTB(this.ctx);
	this._lastEyePosition = null;
	this._textures = {};
}
Client.prototype = {
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
		
		var performanceStrings = [];
		for(var i in info.performance) {
			var success = info.performance[i][0];
			var total = info.performance[i][1];
			if(total == 0) {
				var pct = 0;
			} else {
				var pct = Math.round(success/total*100);
			}
			performanceStrings.push(i+" "+success+"/"+total+" ("+pct+"%)");
		}
		document.getElementById("osd-performance").textContent = performanceStrings.join("\n");
	},
	
	/**
	 * Updates targets plotted over the canvas
	 */
	"TRG":function(payload) {
		if(!payload.targetRects) return;
		if(typeof payload.targetRects[0] !== "object") {
			payload.targetRects = [payload.targetRects];
		}
		for(var i=0; i<payload.targetRects.length; i++) {
			this.ptb[payload.targetIsOval[i] ? "FrameOval" : "FrameRect"]([255, 255, 0, 1],
				payload.targetRects[i]);
		}
	},
	
	/**
	 * Redraws the underlying image
	 */
	"DRW":function(directives) {
		var cw = this.canvas.width, ch = this.canvas.height;
		this.ctx.clearRect(0, 0, cw, ch);
		if(!(directives instanceof Array)) directives = [directives];
		for(var i=0; i<directives.length; i++) {
			var directive = directives[i];
			if(directive.command === "DrawTexture") {
				this.ctx.save();
				var textureIndex = typeof directive.arguments[0] === "object" ? directive.arguments[0][0] : directive.arguments[0],
					texture = this._textures[textureIndex],
					sourceRect = directive.arguments[1],
					destinationRect = directive.arguments[2],
					rotationAngle = directive.arguments[3],
					globalAlpha = directive.arguments[5];

				
				try {				
					if(!destinationRect) {
						var nw = texture.naturalWidth, nh = texture.naturalHeight;
						destinationRect = [cw/2-nw/2, ch/2-nh/2, cw/2+nw/2, cw/2+nh/2];
					}
					if(rotationAngle) this.ctx.rotate(rotationAngle*Math.PI/180);
					if(globalAlpha) this.ctx.globalAlpha = globalAlpha;
					
					if(sourceRect) {
						this.ctx.drawImage(texture, sourceRect[0], sourceRect[1],
							sourceRect[2]-sourceRect[0], sourceRect[3]-sourceRect[1],
							destinationRect[0], destinationRect[1],
							destinationRect[2]-destinationRect[0],
							destinationRect[3]-destinationRect[1]);
					} else {
						this.ctx.drawImage(texture, destinationRect[0], destinationRect[1],
							destinationRect[2]-destinationRect[0],
							destinationRect[3]-destinationRect[1]);
					}
				} finally {
					this.ctx.restore();
				}
			} else {
				this.ptb[directive.command].apply(this.ptb, directive.arguments);
			}
		}
	},
	
	/**
	 * Draws eye data
	 */
	"EYE":function(pos) {
		this.ctx.save();
		if(this._lastEyePosition) {
			this.ctx.fillColor = "rgb(0, 0, 255)";
			this.ctx.fillRect(this._lastEyePosition[0]-2, this._lastEyePosition[1]-2,
				this._lastEyePosition[0]+2, this._lastEyePosition[1]+2);
		}
		if(pos[0]-2 >= 0 && pos[1]-2 >= 0 && pos[0]+2 < this.canvas.width &&
				pos[1]+2 < this.canvas.height) {
			this.ctx.fillColor = "rgb(255, 0, 0)";
			this.ctx.fillRect(pos[0]-2, pos[1]-2, pos[0]+2, pos[1]+2);
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
	}
};

window.addEventListener("DOMContentLoaded", function(event) {
	var canvas = document.createElement("canvas");
	canvas.width = CONFIG.displaySize[0];
	canvas.height = CONFIG.displaySize[1];
	canvas.id = "pmcanvas";
	document.body.appendChild(canvas);
	document.getElementById("osd").style.height = CONFIG.OSDHeight/CONFIG.displaySize[1]*100+"%";
	
	var client = new Client(canvas);
	
	var ws = new WebSocket("ws://"+window.location.hostname+":20557/");
	ws.onmessage = function(event) {
		var data = event.data,
			code = data.substr(0, 3),
			payload = JSON.parse(data.substr(5));
		console.log(data);
		if(code in client) {
			client[code](payload);
		} else {
			console.error("Could not parse message: "+data);
		}
	};
}, false);