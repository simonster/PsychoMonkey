package com.simonster.PsychoMonkey;

import java.awt.color.ColorSpace;
import java.awt.image.BufferedImage;
import java.awt.image.ComponentColorModel;
import java.awt.image.DataBufferByte;
import java.awt.image.WritableRaster;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;

import javax.imageio.ImageIO;

import org.java_websocket.WebSocket;
import org.java_websocket.WebSocketServer;
import org.java_websocket.handshake.ClientHandshake;

import com.sun.net.httpserver.HttpServer;

public class PMServer extends WebSocketServer {
	static final int WS_PORT = 20557;
	static final int HTTP_PORT = 28781;
	
	private Set<WebSocket> clientSockets;
	private volatile String osdMessage = "";
	private volatile String drawMessage = "";
	private volatile String targetMessage = "";
	private volatile String textureMessage = "";
	private volatile String keysPressed = "";
	private PMConfigHandler configHandler;
	private PMTextureHandler textureHandler;
	
	public PMServer(String configJson) throws IOException {
		// Start web socket server
		super(new InetSocketAddress(WS_PORT));
		clientSockets = new CopyOnWriteArraySet<WebSocket>();
		this.start();
		
		// Start HTTP server
		HttpServer server = HttpServer.create(new InetSocketAddress(HTTP_PORT), -1);
		textureHandler = new PMTextureHandler();
		configHandler = new PMConfigHandler(configJson);
		server.createContext("/texture/", textureHandler);
		server.createContext("/config.js", configHandler);
		server.createContext("/", new PMStaticHandler());
		server.setExecutor(null);
		server.start();
	}

	public void onClose(WebSocket socket, int arg1, String arg2, boolean arg3) {
		clientSockets.remove(socket);
	}

	public void onError(WebSocket socket, Exception e) {
		e.printStackTrace();
	}

	public void onMessage(WebSocket socket, String message) {
		// TODO Auto-generated method stub
		if(message.substring(0, 5).equals("KEY: ")) {
			keysPressed += message.substring(5, 6);
		}
	}

	public void onOpen(WebSocket socket, ClientHandshake arg1) {
		clientSockets.add(socket);
		try {
			if(osdMessage != "") socket.send(osdMessage);
			if(textureMessage != "") socket.send(textureMessage);
			if(drawMessage != "") socket.send(drawMessage);
			if(targetMessage != "") socket.send(targetMessage);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	/**
	 * Checks whether a key has been pressed on a client.
	 * @return The key if a key was pressed, otherwise an empty string.
	 */
	public String getPressedKeys() {
		if(keysPressed != "") {
			String key = keysPressed;
			keysPressed = "";
			return key;
		}
		return "";
	}
	
	/**
	 * Redraws the on-screen display with specified status data
	 */
	public void updateStatus(String data) {
		osdMessage = "OSD: "+data;
		broadcastMessage(osdMessage);
	}
	
	/**
	 * Redraws targets with the specified data
	 */
	public void updateTargets(String data) {
		targetMessage = "TRG: "+data;
		broadcastMessage(targetMessage);
	}
	
	/**
	 * Redraws the display with specified data
	 */
	public void updateDisplay(String data) {
		drawMessage = "DRW: "+data;
		broadcastMessage(drawMessage);
	}
	
	/**
	 * Updates the eye position shown
	 */
	public void updateEyePosition(int x, int y) {
		broadcastMessage("EYE: ["+x+","+y+"]");
	}
	
	/**
	 * Converts a texture to a PNG and puts it on in the server store
	 * @param textureIndex Index of the texture
	 * @param imageData Texture contents as an array
	 * @throws IOException 
	 */
	public void addTexture(int textureIndex, byte imageData[][][]) throws IOException {
		int width = imageData[0].length;
		int height = imageData.length;
		
		// Convert imageData to a BufferedImage
		int[] pixelInformationSize = {8, 8, 8};
		ComponentColorModel model = new ComponentColorModel(ColorSpace.getInstance(ColorSpace.CS_sRGB),  
				pixelInformationSize, false, false, ComponentColorModel.OPAQUE, 0);  
		WritableRaster raster = model.createCompatibleWritableRaster(width, height);
		byte[] bufferBytes = ((DataBufferByte) raster.getDataBuffer()).getData();
		for(int y=0; y<height; y++) {
			for(int x=0; x<width; x++) {
				for(int c=0; c<3; c++) {
					bufferBytes[(y*width+x)*3+c] = imageData[y][x][c];  
				}
			}
		}
		BufferedImage img = new BufferedImage(model, raster, false, null);
		
		// Convert png to byte array and store it
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		ImageIO.write(img, "png", out);
		textureHandler.textures.put(textureIndex, out.toByteArray());
		
		// Update texture message
		String keys = "";
		for(Integer key: textureHandler.textures.keySet()) {
			keys += key.toString()+",";
		}
		textureMessage = "TXT: ["+keys.substring(0, keys.length()-1)+"]";
		broadcastMessage(textureMessage);
	}
	
	/**
	 * Removes a texture from the server store
	 * @param textureIndex
	 */
	public void removeTexture(int textureIndex) {
		textureHandler.textures.remove(textureIndex);
	}
	
	/**
	 * Broadcasts a message to all open WebSockets
	 * @param message
	 */
	private void broadcastMessage(String message) {
		for(WebSocket socket : clientSockets) {
			try {
				socket.send(message);
			} catch(Exception e) {
				e.printStackTrace();
			}
		}
	}
}
