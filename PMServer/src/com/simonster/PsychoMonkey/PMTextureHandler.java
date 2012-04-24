package com.simonster.PsychoMonkey;

import java.io.IOException;
import java.net.URI;
import java.util.HashMap;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

public class PMTextureHandler implements HttpHandler {
	HashMap<Integer,byte[]> textures;
	
	public PMTextureHandler() {
		textures = new HashMap<Integer, byte[]>();
	}
	
	public void handle(HttpExchange exchange) throws IOException {
		try {
			// Validate URI
			URI uri = exchange.getRequestURI();
			String imageName = uri.getPath().substring(9);
			String imageSuffix = imageName.substring(imageName.length()-4);
			if(!imageSuffix.equals(".png")) {
				exchange.sendResponseHeaders(404, -1);
				return;
			}
			String imageBaseName = imageName.substring(0, imageName.length()-4);
			
			// Get the texture from the texture hash map
			int textureIndex = 0;
			try {
				textureIndex = new Integer(imageBaseName);
			} catch(NumberFormatException e) {
				exchange.sendResponseHeaders(404, -1);
				return;
			}
			byte[] texture = textures.get(textureIndex);
			if(texture == null) {
				exchange.sendResponseHeaders(404, -1);
				return;
			}
			
			// Write image to output stream
			exchange.getResponseHeaders().add("Content-Type", "image/png");
			exchange.sendResponseHeaders(200, texture.length);
			exchange.getResponseBody().write(texture);
		} finally {
			exchange.close();
		}
	}
}
