package com.simonster.PsychoMonkey;

import java.awt.color.ColorSpace;
import java.awt.image.BufferedImage;
import java.awt.image.ComponentColorModel;
import java.awt.image.DataBufferByte;
import java.awt.image.WritableRaster;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;

import javax.imageio.ImageIO;

import org.java_websocket.WebSocket;
import org.java_websocket.WebSocketServer;
import org.java_websocket.handshake.ClientHandshake;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;

public class PMServer extends WebSocketServer {
	static final int WS_PORT = 20557;
	static final int HTTP_PORT = 28781;
	static ObjectMapper objectMapper = new ObjectMapper();
	
	private Set<WebSocket> clientSockets;
	private Set<String> keysPressed;
	private volatile String osdMessage = "";
	private volatile String drawMessage = "";
	private volatile String targetMessage = "";
	private volatile String textureMessage = "";
	private String password;
	private PMConfigHandler configHandler;
	private PMTextureHandler textureHandler;
	private HttpServer httpServer;
	
	public PMServer(String[] keys, Object[] values, String password) throws IOException {
		// Start web socket server
		super(new InetSocketAddress(WS_PORT));
		clientSockets = new CopyOnWriteArraySet<WebSocket>();
		keysPressed = new CopyOnWriteArraySet<String>();
		this.start();
		
		// Start HTTP server
		httpServer = HttpServer.create(new InetSocketAddress(HTTP_PORT), -1);
		textureHandler = new PMTextureHandler();
		configHandler = new PMConfigHandler(objectMapper.writeValueAsString(constructMap(keys, values)));
		httpServer.createContext("/texture/", textureHandler);
		httpServer.createContext("/config.js", configHandler);
		httpServer.createContext("/", new PMStaticHandler());
		httpServer.setExecutor(null);
		httpServer.start();
		
		this.password = password;
	}

	public void onClose(WebSocket socket, int arg1, String arg2, boolean arg3) {
		clientSockets.remove(socket);
	}

	public void onError(WebSocket socket, Exception e) {
		e.printStackTrace();
	}

	public void onMessage(WebSocket socket, String message) {
		String messageCode = message.substring(0, 5);
		if(clientSockets.contains(socket)) {
			if(messageCode.equals("KEY: ")) {
				keysPressed.add(message.substring(5));
			}
		} else {
			if(messageCode.equals("PWD: ")) {
				if(message.substring(5).equals(this.password)) {
					clientSockets.add(socket);
					try {
						socket.send("PWD: true");
						if(osdMessage != "") socket.send(osdMessage);
						if(textureMessage != "") socket.send(textureMessage);
						if(drawMessage != "") socket.send(drawMessage);
						if(targetMessage != "") socket.send(targetMessage);
					} catch (Exception e) {
						e.printStackTrace();
					}
				} else {
					try {
						socket.send("PWD: false");
					} catch (Exception e) {
						e.printStackTrace();
					}
				}
			}
		}
	}

	public void onOpen(WebSocket socket, ClientHandshake arg1) {}
	
	/**
	 * Checks whether a key has been pressed on a client.
	 * @return The key if a key was pressed, otherwise an empty string.
	 */
	public String[] getPressedKeys() {
		if(!keysPressed.isEmpty()) {
			String[] keysPressedArray = keysPressed.toArray(new String[0]);
			keysPressed.clear();
			return keysPressedArray;
		}
		return null;
	}
	
	/**
	 * Redraws the on-screen display with specified status data
	 * @throws JsonProcessingException 
	 */
	public void updateStatus(String state, Map<String,String> keyInfo, Map<String,int[]> trialInfo) throws JsonProcessingException {
		osdMessage = "OSD: {\"state\":"+objectMapper.writeValueAsString(state)+
			", \"keyInfo\":"+objectMapper.writeValueAsString(keyInfo)+
			", \"trialInfo\":"+objectMapper.writeValueAsString(trialInfo)+"}";
		broadcastMessage(osdMessage);
	}
	
	/**
	 * Redraws targets with the specified data
	 * @throws JsonProcessingException 
	 */
	public void updateTargets(int[][] targetRects, int[] targetIsOval) throws JsonProcessingException {
		targetMessage = "TRG: {\"targetRects\":"+objectMapper.writeValueAsString(targetRects)+
				", \"targetIsOval\":"+objectMapper.writeValueAsString(targetIsOval)+"}";
		broadcastMessage(targetMessage);
	}
	
	/**
	 * Redraws the display with specified data
	 * @throws JsonProcessingException 
	 */
	public void updateDisplay(Object data) throws JsonProcessingException {
		drawMessage = "DRW: "+objectMapper.writeValueAsString(data);
		broadcastMessage(drawMessage);
	}
	
	/**
	 * Updates the eye position shown
	 */
	public void updateEyePosition(int x, int y) {
		broadcastMessage("EYE: ["+x+","+y+"]");
	}
	
	/**
	 * Sends a message notifying that juice was given
	 */
	public void juiceGiven(double time, double between, int reps) {
		broadcastMessage("JCE: {\"time\":"+time+", \"between\":"+between+", \"reps\":"+reps+"}");
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
		
		storeTexture(textureIndex, new BufferedImage(model, raster, false, null));
	}
	
	/**
	 * Converts a texture to a PNG and puts it on in the server store
	 * @param textureIndex Index of the texture
	 * @param imageData Texture contents as an array
	 * @throws IOException 
	 */
	public void addTexture(int textureIndex, byte imageData[][]) throws IOException {
		int width = imageData[0].length;
		int height = imageData.length;
		
		// Convert imageData to a BufferedImage
		int[] pixelInformationSize = {8};
		ComponentColorModel model = new ComponentColorModel(ColorSpace.getInstance(ColorSpace.CS_GRAY),  
				pixelInformationSize, false, false, ComponentColorModel.OPAQUE, 0);  
		WritableRaster raster = model.createCompatibleWritableRaster(width, height);
		byte[] bufferBytes = ((DataBufferByte) raster.getDataBuffer()).getData();
		for(int y=0; y<height; y++) {
			for(int x=0; x<width; x++) {
				bufferBytes[y*width+x] = imageData[y][x];
			}
		}
		
		storeTexture(textureIndex, new BufferedImage(model, raster, false, null));
	}
	
	/**
	 * Store texture so that it can be saved
	 * @param textureIndex Texture index to store at
	 * @param img Image to store
	 * @throws IOException 
	 */
	private void storeTexture(int textureIndex, BufferedImage img) throws IOException {
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
	
	/**
	 * Stops the server
	 */
	public void stop() throws IOException {
		super.stop();
		httpServer.stop(0);
	 }
	
	/**
	 * Creates a Map from a set of strings and values
	 */
	public HashMap<String, Object> constructMap(String[] keys, Object[] values) {
		HashMap<String, Object> map = new HashMap<String, Object>(keys.length);
		for(int i=0; i<keys.length; i++) {
			map.put(keys[i], values[i]);
		}
		return map;
	}
}
